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
# Per-UGF routing (spec 021 §4, L4): R5 is scored by the method
# calibrated for the unit's dominant species —
#   * oak / chestnut / Scots pine  → RECONFORT (reconfort_results),
#   * spruce / fir                 → FORDEAD   (fordead_results),
#   * neither                      → NA, status "skipped_no_method".
# In each branch R5 is the confidence-weighted area of the method's
# clusters whose centroid falls inside the unit, / unit area, capped
# at 1, rescaled to 0-100. Weighting: ONF/DSF 2024 for FORDEAD
# (`FORDEAD_CONFIDENCE_WEIGHTS`); RECONFORT confusion matrix
# (`RECONFORT_CONFIDENCE_WEIGHTS`, provisional).
# ============================================================


#' Compute the R5 dieback indicator (unified FORDEAD / RECONFORT)
#'
#' Adds an `R5` column (0-100 score, higher = more dieback) and a
#' diagnostic `r5_status` column to the input forest units. R5 is the
#' confidence-weighted fraction of the unit area covered by dieback
#' clusters, capped at 1 and rescaled to 0-100.
#'
#' **Routing by dominant species (spec 021 §4)**: each unit is scored
#' by the method calibrated for its species — RECONFORT for oak /
#' chestnut / Scots pine, FORDEAD for spruce / fir. `r5_status` is one
#' of `"calculated"` (FORDEAD), `"calculated_reconfort"` (RECONFORT),
#' `"skipped_no_fordead"` / `"skipped_no_reconfort"` (method applies
#' but its run is missing), or `"skipped_no_method"` (neither).
#'
#' By default only the trustworthy classes contribute (G1): FORDEAD
#' `3-forte` / `4-sol-nu` (`include_low_classes = TRUE` adds the low
#' classes) and RECONFORT [`RECONFORT_ALERT_CLASSES`].
#'
#' @param units An `sf` of forest management units, with at
#'   least a species column (one of `essence_dominante`,
#'   `essence`, `species_label`, `species`, `essence_principale`).
#' @param fordead_results The list returned by [run_fordead_dieback()]
#'   (only `$alerts_sf` is consumed). Used for **conifer** units.
#' @param reconfort_results The list returned by
#'   [run_reconfort_dieback()] (only `$alerts_sf` is consumed). Used
#'   for **oak / chestnut / Scots pine** units (L4).
#' @param weights Named numeric vector. Per-class FORDEAD weights.
#'   Default [`FORDEAD_CONFIDENCE_WEIGHTS`].
#' @param weights_reconfort Named numeric vector. Per-class RECONFORT
#'   weights (dieback classes). Default = the oak subset of
#'   [`RECONFORT_CONFIDENCE_WEIGHTS`] (provisional).
#' @param min_resineux Numeric in `[0, 1]`. Minimum conifer share to
#'   route a unit to FORDEAD. Default 0.3.
#' @param min_feuillus Numeric in `[0, 1]`. Minimum oak/chestnut/Scots-pine
#'   share to route a unit to RECONFORT. Default 0.3.
#' @param include_low_classes Logical. When `FALSE` (default),
#'   only FORDEAD classes `3-forte` and `4-sol-nu` are considered (G1).
#' @param resineux_col Optional character. Column carrying a per-unit
#'   conifer share in `[0, 1]`; pins the unit to the FORDEAD method.
#' @param feuillus_col Optional character. Column carrying a per-unit
#'   oak/chestnut/Scots-pine share in `[0, 1]`; pins the unit to the
#'   RECONFORT method.
#'
#' @return The input `units` with two added columns: `R5`
#'   (numeric, 0-100, NA where skipped) and `r5_status`
#'   (character).
#'
#' @export
indicateur_r5_deperissement <- function(units,
                                         fordead_results     = NULL,
                                         reconfort_results   = NULL,
                                         weights             = FORDEAD_CONFIDENCE_WEIGHTS,
                                         weights_reconfort   = RECONFORT_CONFIDENCE_WEIGHTS$CHE[-1L],
                                         min_resineux        = 0.3,
                                         min_feuillus        = 0.3,
                                         include_low_classes = FALSE,
                                         resineux_col        = NULL,
                                         feuillus_col        = NULL) {
  if (!inherits(units, "sf")) {
    cli::cli_abort("{.arg units} must be an sf object.")
  }
  if (nrow(units) == 0L) {
    units$R5 <- numeric(0)
    units$r5_status <- character(0)
    return(units)
  }

  units_m    <- sf::st_transform(units, 2154)
  unit_areas <- as.numeric(sf::st_area(units_m))

  # Per-UGF conifer (FORDEAD) and oak/chestnut/Scots-pine (RECONFORT)
  # shares. An explicit `*_col` pins the method intent: `resineux_col`
  # forces the FORDEAD world (RECONFORT share zeroed) and vice-versa.
  resineux_share  <- .resolve_resineux_share(units_m, resineux_col)
  reconfort_share <- .resolve_reconfort_share(units_m, feuillus_col)
  if (!is.null(resineux_col) && is.null(feuillus_col)) reconfort_share[] <- 0
  if (!is.null(feuillus_col) && is.null(resineux_col)) resineux_share[]  <- 0

  # Method routing per unit (spec 021 §4): RECONFORT for the species it
  # was calibrated on (oak / chestnut / Scots pine), FORDEAD for
  # spruce / fir, nothing otherwise.
  method <- ifelse(
    !is.na(reconfort_share) & reconfort_share >= min_feuillus &
      (is.na(resineux_share) | reconfort_share >= resineux_share),
    "reconfort",
    ifelse(!is.na(resineux_share) & resineux_share >= min_resineux,
           "fordead", "none"))

  # Pre-filter each method's alerts once (required columns, class
  # filter, CRS). NULL when the method has no usable run.
  fordead_alerts <- .r5_prepare_alerts(
    fordead_results, classes =
      if (include_low_classes) NULL else c("3-forte", "4-sol-nu"),
    arg = "fordead_results")
  reconfort_alerts <- .r5_prepare_alerts(
    reconfort_results, classes = RECONFORT_ALERT_CLASSES,
    arg = "reconfort_results")

  units$R5 <- NA_real_
  units$r5_status <- "skipped_no_method"

  for (i in seq_len(nrow(units_m))) {
    if (method[i] == "reconfort") {
      if (is.null(reconfort_alerts)) {
        units$r5_status[i] <- "skipped_no_reconfort"; next
      }
      units$R5[i] <- .r5_score(units_m[i, ], reconfort_alerts,
                               weights_reconfort, unit_areas[i])
      units$r5_status[i] <- "calculated_reconfort"
    } else if (method[i] == "fordead") {
      if (is.null(fordead_alerts)) {
        units$r5_status[i] <- "skipped_no_fordead"; next
      }
      units$R5[i] <- .r5_score(units_m[i, ], fordead_alerts,
                               weights, unit_areas[i])
      units$r5_status[i] <- "calculated"
    }
    # else method == "none": keep "skipped_no_method".
  }

  units
}


# Prepare a method's alerts for R5: validate the required columns,
# reproject to Lambert-93, apply the optional `classes` G1 filter.
# Returns NULL when the run is absent/empty (no alert layer at all);
# an empty-after-filter sf still returns (so the unit scores 0).
.r5_prepare_alerts <- function(results, classes, arg) {
  if (is.null(results) || is.null(results$alerts_sf) ||
      nrow(results$alerts_sf) == 0L) {
    return(NULL)
  }
  alerts <- results$alerts_sf
  miss <- setdiff(c("confidence_class", "area_m2"), names(alerts))
  if (length(miss)) {
    cli::cli_abort(
      "{.arg {arg}$alerts_sf} is missing required column{?s}: {.val {miss}}.")
  }
  alerts_m <- sf::st_transform(alerts, 2154)
  if (!is.null(classes)) {
    alerts_m <- alerts_m[alerts_m$confidence_class %in% classes, , drop = FALSE]
  }
  alerts_m
}


# Confidence-weighted fraction of one unit covered by the clusters
# whose centroid falls inside it, capped at 1 and rescaled to 0-100.
.r5_score <- function(unit_m, alerts_m, weights, unit_area) {
  if (is.null(alerts_m) || nrow(alerts_m) == 0L) return(0)
  in_ugf <- sf::st_intersects(alerts_m, unit_m, sparse = FALSE)[, 1]
  if (!any(in_ugf)) return(0)
  sub <- alerts_m[in_ugf, , drop = FALSE]
  w <- as.numeric(weights[as.character(sub$confidence_class)])
  w[is.na(w)] <- 0
  weighted_area <- sum(w * as.numeric(sub$area_m2))
  raw <- if (unit_area > 0) weighted_area / unit_area else 0
  min(raw, 1) * 100
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


# Per-unit RECONFORT share (oak / chestnut / Scots pine) in [0, 1].
# Mirror of [.resolve_resineux_share()]: a `feuillus_col` is used
# as-is (clamped); otherwise a binary 0/1 share is derived from the
# dominant species column via the RECONFORT validity helpers.
.resolve_reconfort_share <- function(units_m, feuillus_col = NULL) {
  if (!is.null(feuillus_col)) {
    if (!feuillus_col %in% names(units_m)) {
      cli::cli_abort("Column {.val {feuillus_col}} not found on {.arg units}.")
    }
    v <- as.numeric(units_m[[feuillus_col]])
    return(pmin(pmax(v, 0), 1))
  }
  col <- .pick_species_column(units_m)
  if (is.na(col)) {
    return(rep(NA_real_, nrow(units_m)))
  }
  lbl <- units_m[[col]]
  is_rec <- .is_chene(lbl) | .is_chataignier(lbl) | .is_pin_sylvestre(lbl)
  ifelse(is_rec, 1, 0)
}
