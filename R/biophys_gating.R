# biophys_gating.R — éligibilité du flag `biophysical_s2` (spec 043 D6, ADR-015)
# ---------------------------------------------------------------------------
# Décide, par unité, si les variables biophysiques S2 (LAI/fAPAR/FCOVER/CCC)
# sont assez fiables pour porter le flag d'augmentation `"biophysical_s2"` dans
# le système NDP. Un flag posé sur une base insuffisante ferait compter la
# donnée dans la confiance φ (ADR-011) alors qu'elle est peu fiable — c'est
# précisément ce que ce gating empêche.
#
# Brique de GOUVERNANCE, pas de production : elle ne calcule aucune variable
# biophysique (cela vit dans le package amont `biophysnemeton`, ADR-009). Elle
# consomme les métriques de qualité que l'amont remonte et rend un prédicat.
#
# FAIL-CLOSED : toute métrique manquante (NA) fait échouer le gating. Ne jamais
# poser le flag « par défaut » — l'ADR-011 l'interdit de fait.

#' Default gating thresholds for the Sentinel-2 biophysical augmentation
#'
#' @description
#' The four conditions that must **all** hold for a unit to earn the
#' `"biophysical_s2"` NDP augmentation flag (spec 043 D6, ADR-015).
#'
#' @section All values are provisional — to calibrate:
#' None of these thresholds is settled. Each ships with the order of magnitude
#' expected and the calibration method, per the spec:
#' \itemize{
#'   \item `n_obs_min` (default 3): 3-6; from the stability curve of the median
#'     composite versus `n_obs` (the invariance test, spec 043 §9).
#'   \item `pct_masked_max` (default 0.4): 0.3-0.5; from the composite's
#'     sensitivity to the cloud/shadow masking rate.
#'   \item `oob_frac_max` (default 0.10): 0.05-0.10; the tolerated fraction of
#'     pixels flagged out-of-domain by SL2P (input or output).
#'   \item `area_px_min` (default 25): ~1 ha at 20 m (25 px); from the
#'     within-unit variance versus area.
#' }
#'
#' @return A named list of the four thresholds.
#' @seealso [biophys_gating()]
#' @export
biophys_gating_thresholds <- function() {
  list(
    n_obs_min      = 3L,     # obs. valides dans la fenêtre juin-août
    pct_masked_max = 0.40,   # taux de masquage nuage/ombre de l'unité
    oob_frac_max   = 0.10,   # part de pixels hors-domaine SL2P (in/out)
    area_px_min    = 25L     # taille de l'unité en pixels 20 m (~1 ha)
  )
}

#' Gate the Sentinel-2 biophysical augmentation flag, per unit
#'
#' @description
#' Returns, for each unit, whether the Sentinel-2 biophysical variables are
#' reliable enough to carry the `"biophysical_s2"` NDP augmentation flag
#' (spec 043 D6, ADR-015). All four quality conditions must hold; any missing
#' metric fails the gate (**fail-closed**).
#'
#' This is a **decision**, not a computation: the biophysical rasters and their
#' quality metrics are produced upstream (`biophysnemeton`, ADR-009). This
#' function only decides eligibility, so the confidence φ never counts a
#' variable retrieved on an insufficient basis (ADR-011).
#'
#' @param n_obs Integer vector: valid observations in the June-August window,
#'   per unit.
#' @param pct_masked Numeric vector in \code{[0, 1]}: cloud/shadow masking rate
#'   per unit.
#' @param oob_frac Numeric vector in \code{[0, 1]}: fraction of pixels flagged
#'   out-of-domain by SL2P (input or output) per unit.
#' @param area_px Integer vector: unit size in 20 m pixels.
#' @param thresholds A list as returned by [biophys_gating_thresholds()].
#'
#' @return A logical vector, one per unit: `TRUE` where **all** conditions hold,
#'   `FALSE` otherwise (including where any input is `NA`).
#'
#' @seealso [biophys_gating_thresholds()]
#' @export
#' @examples
#' biophys_gating(n_obs = c(5, 2, 8), pct_masked = c(0.2, 0.1, 0.6),
#'                oob_frac = c(0.02, 0.01, 0.03), area_px = c(40, 30, 100))
#' # -> TRUE, FALSE (n_obs<3), FALSE (pct_masked>0.4)
biophys_gating <- function(n_obs, pct_masked, oob_frac, area_px,
                           thresholds = biophys_gating_thresholds()) {
  req <- c("n_obs_min", "pct_masked_max", "oob_frac_max", "area_px_min")
  if (!is.list(thresholds) || !all(req %in% names(thresholds))) {
    cli::cli_abort(
      "{.arg thresholds} must contain {.val {req}} (see {.fn biophys_gating_thresholds})."
    )
  }
  n <- length(n_obs)
  if (any(lengths(list(pct_masked, oob_frac, area_px)) != n)) {
    cli::cli_abort("All metric vectors must have the same length.")
  }

  n_obs      <- suppressWarnings(as.numeric(n_obs))
  pct_masked <- suppressWarnings(as.numeric(pct_masked))
  oob_frac   <- suppressWarnings(as.numeric(oob_frac))
  area_px    <- suppressWarnings(as.numeric(area_px))

  ok <- n_obs      >= thresholds$n_obs_min &
        pct_masked <= thresholds$pct_masked_max &
        oob_frac   <= thresholds$oob_frac_max &
        area_px    >= thresholds$area_px_min

  # Fail-closed : une métrique NA -> FALSE, jamais de flag par défaut (ADR-011).
  ok & !is.na(ok)
}
