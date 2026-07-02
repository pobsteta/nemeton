# regeneration_index.R — composite regeneration potential (spec 027 L3)
# ------------------------------------------------------------------
# Head-of-tab score (NOT a radar axis) combining the four microclimate
# sub-indicators A3/A4/W4/R6 into a single 0-100 "regeneration potential",
# tunable by target species through the tolerance table
# inst/extdata/regeneration_tolerances.csv (ADR-014).
#
# Sens: higher = more favourable to natural regeneration. All four
# sub-indicators are already 0-100 "higher = better", so the base score is a
# (re-normalisable) weighted mean of whichever are present. A target species
# then applies a heat/dryness tolerance penalty on the raw A3_tmax / W4_vpd:
# a mesophilic beech is penalised on a hot, dry microsite where a thermophilic
# holm oak is not.

# Components consumed (short-code score columns) and their raw counterparts.
.REGEN_COMPONENTS <- c("A3", "A4", "W4", "R6")

# Tolerance-penalty spans: exceeding the species threshold by this much drives
# the penalty to 1 (full). Documented, revisable on field validation.
.REGEN_TOL_SPAN <- c(tmax_c = 5.0, vpd_kpa = 1.5)

# Class breaks on the 0-100 potential (NMT labels, no accent).
.REGEN_CLASS_BREAKS <- c(defavorable = 33, favorable = 66)


#' Regeneration tolerance table (per species)
#'
#' @description
#' The per-species heat / dryness tolerance thresholds used by
#' [regeneration_index()] to tune the composite score to a target species
#' (spec 027 L3, ADR-014). Read from
#' `inst/extdata/regeneration_tolerances.csv`.
#'
#' Values are **indicative** (they order species sensitivity), keyed on the
#' species classes of [list_species_classes()]; they are documented, not
#' field-calibrated (spec 027 §7/§12).
#'
#' @return A `data.frame` with columns `code`, `label`, `tmax_tol_c`
#'   (max tolerated under-canopy summer T°max, °C), `vpd_tol_kpa`
#'   (max tolerated summer VPD, kPa).
#' @seealso [regeneration_index()], [list_species_classes()]
#' @export
regeneration_tolerances <- function() {
  path <- system.file("extdata", "regeneration_tolerances.csv",
                      package = "nemeton")
  if (!nzchar(path) || !file.exists(path)) {
    stop("regeneration_tolerances.csv not found in the installed package",
         call. = FALSE)
  }
  utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8")
}

# Resolve the (tmax_tol_c, vpd_tol_kpa) thresholds for a target species, from
# an explicit `tolerances` override or the packaged table. NULL species /
# no match -> NULL (no species penalty; generic equiponderated score).
.regen_resolve_tolerance <- function(species, tolerances) {
  if (is.null(species) || !nzchar(species)) return(NULL)

  # Explicit single-species override: named numeric / list.
  if (is.list(tolerances) && !is.data.frame(tolerances) &&
      all(c("tmax_tol_c", "vpd_tol_kpa") %in% names(tolerances))) {
    return(list(tmax_tol_c = as.numeric(tolerances$tmax_tol_c),
                vpd_tol_kpa = as.numeric(tolerances$vpd_tol_kpa)))
  }

  tbl <- if (is.data.frame(tolerances)) tolerances else regeneration_tolerances()
  hit <- tbl[tbl$code == species, , drop = FALSE]
  if (nrow(hit) == 0L) return(NULL)
  list(tmax_tol_c = as.numeric(hit$tmax_tol_c[1]),
       vpd_tol_kpa = as.numeric(hit$vpd_tol_kpa[1]))
}

# Per-row weighted mean over the present, non-NA components, with weights
# renormalised so a missing component (e.g. R6 without two years) does not
# collapse the score. All-NA row -> NA.
.regen_weighted_mean <- function(mat, weights) {
  vapply(seq_len(nrow(mat)), function(i) {
    v <- mat[i, ]
    ok <- is.finite(v)
    if (!any(ok)) return(NA_real_)
    w <- weights[ok]
    sum(v[ok] * w) / sum(w)
  }, numeric(1))
}


#' Composite regeneration potential (spec 027 L3)
#'
#' @description
#' Combine the four under-canopy microclimate sub-indicators
#' (A3 T°max, A4 buffering, W4 VPD, R6 sensitivity) into a single 0-100
#' **regeneration potential** for a target species (ADR-014). This is a
#' head-of-tab score, **not** a radar axis; the four sub-indicators keep their
#' own axes (families A, W, R).
#'
#' The base score is a weighted mean of whichever sub-indicator score columns
#' are present on `units` (weights renormalised over the available, non-NA
#' components, so a missing R6 does not void the score). When a target
#' `species` is given, a heat / dryness **tolerance penalty** is applied from
#' the raw `A3_tmax` / `W4_vpd` columns: a parcel whose under-canopy summer
#' T°max or VPD exceeds the species threshold (see [regeneration_tolerances()])
#' is down-weighted, so the same microsite scores higher for a thermophilic
#' species than for a mesophilic one.
#'
#' @param units An `sf` of UGF, already carrying the sub-indicator columns
#'   from [indicateur_a3_microclimat()], [indicateur_a4_tamponnement()],
#'   [indicateur_w4_vpd()] and/or [indicateur_r6_sensibilite()]. Absent
#'   components are simply skipped; if none are present the score is `NA`.
#' @param species Optional target-species code (one of
#'   [list_species_classes()]`$code`). `NULL` → generic equiponderated score,
#'   no tolerance penalty.
#' @param weights Optional named numeric over `c("A3","A4","W4","R6")` to
#'   override the default equal weighting.
#' @param tolerances Optional override of the tolerance thresholds: a
#'   `data.frame` like [regeneration_tolerances()], or a single-species list
#'   `list(tmax_tol_c=, vpd_tol_kpa=)`. `NULL` → the packaged table.
#' @param class_breaks Numeric `c(defavorable, favorable)` cut points on the
#'   0-100 potential (default `c(33, 66)`).
#' @param ... Unused (signature harmonisation).
#'
#' @return `units` with `regeneration_potentiel` (0-100, rounded),
#'   `regeneration_classe` (`"favorable"` / `"marginal"` / `"defavorable"`,
#'   NMT, `NA` where the potential is `NA`) and `regeneration_essence`
#'   (the species used, or `"generique"`).
#' @seealso [regeneration_tolerances()], [indicateur_a3_microclimat()],
#'   [indicateur_w4_vpd()]
#' @examples
#' \dontrun{
#'   units <- indicateur_a3_microclimat(units, micro)
#'   units <- indicateur_w4_vpd(units, micro)
#'   units <- regeneration_index(units, species = "essence_hetraie")
#' }
#' @export
regeneration_index <- function(units, species = NULL, weights = NULL,
                               tolerances = NULL,
                               class_breaks = .REGEN_CLASS_BREAKS, ...) {
  validate_sf(units)
  n <- nrow(units)

  # Which sub-indicator score columns are actually present.
  components <- .REGEN_COMPONENTS
  present <- components[components %in% names(units)]
  if (length(present) == 0L) {
    cli::cli_warn(c(
      "regeneration_index(): none of {.val {components}} present on {.arg units}.",
      i = "Compute the microclimate sub-indicators first; potential set to NA."
    ))
    units$regeneration_potentiel <- rep(NA_real_, n)
    units$regeneration_classe <- rep(NA_character_, n)
    units$regeneration_essence <- if (is.null(species)) "generique" else species
    return(units)
  }

  # Weights over the present components (default equal), user override applied
  # then renormalised inside .regen_weighted_mean per row.
  w <- stats::setNames(rep(1, length(present)), present)
  if (!is.null(weights)) {
    ov <- weights[names(weights) %in% present]
    w[names(ov)] <- as.numeric(ov)
  }
  mat <- as.matrix(sf::st_drop_geometry(units)[, present, drop = FALSE])
  storage.mode(mat) <- "double"
  base <- .regen_weighted_mean(mat, w)

  # Species tolerance penalty on the raw heat / dryness, when resolvable.
  tol <- .regen_resolve_tolerance(species, tolerances)
  penalty <- rep(0, n)
  if (!is.null(tol)) {
    if ("A3_tmax" %in% names(units)) {
      exc <- pmax(0, units$A3_tmax - tol$tmax_tol_c)
      penalty <- pmax(penalty, pmin(1, exc / .REGEN_TOL_SPAN[["tmax_c"]]))
    }
    if ("W4_vpd" %in% names(units)) {
      exc <- pmax(0, units$W4_vpd - tol$vpd_tol_kpa)
      penalty <- pmax(penalty, pmin(1, exc / .REGEN_TOL_SPAN[["vpd_kpa"]]))
    }
    penalty[is.na(penalty)] <- 0
  }

  potentiel <- base * (1 - penalty)
  potentiel <- pmin(100, pmax(0, potentiel))

  lo <- class_breaks[[1]]; hi <- class_breaks[[2]]
  classe <- ifelse(is.na(potentiel), NA_character_,
                   ifelse(potentiel >= hi, "favorable",
                          ifelse(potentiel < lo, "defavorable", "marginal")))

  units$regeneration_potentiel <- round(potentiel, 1)
  units$regeneration_classe <- classe
  units$regeneration_essence <- if (is.null(species) || is.null(tol)) {
    "generique"
  } else {
    species
  }
  units
}
