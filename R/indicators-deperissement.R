# ============================================================
# indicators-deperissement.R — R5 dieback indicator
# ------------------------------------------------------------
# Implements guard-rail G5 of spec 008 (suivi sanitaire) :
# the R5 dieback index is a confidence-weighted measure of how
# much of each forest management unit is covered by FORDEAD
# anomaly clusters. Weighting comes from the ONF/DSF 2024
# detection accuracy (see `FORDEAD_CONFIDENCE_WEIGHTS` in
# R/fordead_postprocess.R).
#
# Per-UGF logic:
#   * If the unit's spruce + fir share is below `min_resineux`,
#     R5 is set to NA with status "skipped_no_resineux"
#     (the FORDEAD calibration only covers EPC + SAP).
#   * If `fordead_results` is NULL or empty, R5 is NA with
#     status "skipped_no_fordead".
#   * Otherwise the unit's R5 is the area-weighted sum of the
#     FORDEAD clusters whose centroid falls inside it,
#     divided by the unit area, capped at 1, then expressed
#     as a 0-100 score for radar consumption.
# ============================================================


#' Compute the R5 dieback indicator
#'
#' Adds an `R5` column (0-100 score, higher = more dieback) and a
#' diagnostic `r5_status` column (`"calculated"`,
#' `"skipped_no_resineux"`, `"skipped_no_fordead"`) to the input
#' forest units. The score is the confidence-weighted fraction of
#' the unit area covered by FORDEAD anomaly clusters, capped at
#' 1 and rescaled to 0-100 to align with the rest of the radar.
#'
#' By default, only classes `3-forte` and `4-sol-nu` contribute
#' (G1 in spec 008 — classes 1-faible and 2-moyenne carry
#' 50% / 33% false-positive rates per the ONF/DSF 2024 report).
#' Set `include_low_classes = TRUE` to include them, in which
#' case the per-class weights from `FORDEAD_CONFIDENCE_WEIGHTS`
#' apply.
#'
#' @param units An `sf` of forest management units, with at
#'   least a species column (one of `essence_dominante`,
#'   `essence`, `species_label`, `species`, `essence_principale`).
#' @param fordead_results The list returned by
#'   [run_fordead_dieback()]. Only `fordead_results$alerts_sf`
#'   is consumed here. `NULL` (default) means R5 is set to NA
#'   for every unit with status `"skipped_no_fordead"`.
#' @param weights Named numeric vector. Per-class weights used
#'   to combine the cluster surfaces. Default
#'   [`FORDEAD_CONFIDENCE_WEIGHTS`].
#' @param min_resineux Numeric in `[0, 1]`. Minimum spruce + fir
#'   share required to compute R5 on a unit. Below this
#'   threshold, R5 is `NA` with status `"skipped_no_resineux"`.
#'   Default 0.3.
#' @param include_low_classes Logical. When `FALSE` (default),
#'   only classes `3-forte` and `4-sol-nu` are considered (G1).
#' @param resineux_col Optional character. Name of a column on
#'   `units` carrying a per-unit conifer share in `[0, 1]`. When
#'   absent, the share is derived from the dominant species
#'   column via [`.is_epicea()`] / [`.is_sapin_pectine()`]
#'   (then 1 if the unit is dominated by spruce or fir, else 0).
#'
#' @return The input `units` with two added columns: `R5`
#'   (numeric, 0-100, NA where skipped) and `r5_status`
#'   (character).
#'
#' @export
indicateur_r5_deperissement <- function(units,
                                         fordead_results     = NULL,
                                         weights             = FORDEAD_CONFIDENCE_WEIGHTS,
                                         min_resineux        = 0.3,
                                         include_low_classes = FALSE,
                                         resineux_col        = NULL) {
  if (!inherits(units, "sf")) {
    cli::cli_abort("{.arg units} must be an sf object.")
  }
  if (nrow(units) == 0L) {
    units$R5 <- numeric(0)
    units$r5_status <- character(0)
    return(units)
  }

  units$R5 <- NA_real_
  units$r5_status <- "skipped_no_fordead"

  if (is.null(fordead_results) ||
      is.null(fordead_results$alerts_sf) ||
      nrow(fordead_results$alerts_sf) == 0L) {
    return(units)
  }

  alerts <- fordead_results$alerts_sf
  required <- c("confidence_class", "area_m2")
  miss <- setdiff(required, names(alerts))
  if (length(miss)) {
    cli::cli_abort(
      "{.arg fordead_results$alerts_sf} is missing required column{?s}: {.val {miss}}.")
  }

  alerts_m <- sf::st_transform(alerts, 2154)
  units_m  <- sf::st_transform(units, 2154)

  if (!include_low_classes) {
    alerts_m <- alerts_m[alerts_m$confidence_class %in% c("3-forte", "4-sol-nu"), ]
  }

  unit_areas <- as.numeric(sf::st_area(units_m))

  resineux_share <- .resolve_resineux_share(units_m, resineux_col)

  no_alerts_left <- nrow(alerts_m) == 0L

  for (i in seq_len(nrow(units_m))) {
    if (is.na(resineux_share[i]) || resineux_share[i] < min_resineux) {
      units$r5_status[i] <- "skipped_no_resineux"
      next
    }
    if (no_alerts_left) {
      units$R5[i] <- 0
      units$r5_status[i] <- "calculated"
      next
    }
    in_ugf <- sf::st_intersects(alerts_m, units_m[i, ], sparse = FALSE)[, 1]
    if (!any(in_ugf)) {
      units$R5[i] <- 0
      units$r5_status[i] <- "calculated"
      next
    }
    sub  <- alerts_m[in_ugf, , drop = FALSE]
    cls  <- as.character(sub$confidence_class)
    area <- as.numeric(sub$area_m2)
    w <- as.numeric(weights[cls])
    w[is.na(w)] <- 0
    weighted_area <- sum(w * area)
    raw <- if (unit_areas[i] > 0) weighted_area / unit_areas[i] else 0
    units$R5[i] <- min(raw, 1) * 100
    units$r5_status[i] <- "calculated"
  }

  units
}


# Compute, for every row of `units_m`, a per-unit conifer share in
# [0, 1]. If `resineux_col` is provided and present, use it as-is
# (clamping into [0, 1]). Otherwise, derive a binary 0/1 share from
# the dominant species column via the FORDEAD validity helpers.
.resolve_resineux_share <- function(units_m, resineux_col = NULL) {
  if (!is.null(resineux_col)) {
    if (!resineux_col %in% names(units_m)) {
      cli::cli_abort("Column {.val {resineux_col}} not found on {.arg units}.")
    }
    v <- as.numeric(units_m[[resineux_col]])
    return(pmin(pmax(v, 0), 1))
  }
  col <- .pick_species_column(units_m)
  if (is.na(col)) {
    return(rep(NA_real_, nrow(units_m)))
  }
  lbl <- units_m[[col]]
  is_res <- .is_epicea(lbl) | .is_sapin_pectine(lbl)
  ifelse(is_res, 1, 0)
}
