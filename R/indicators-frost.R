# indicators-frost.R — R7, risque de gel tardif (chantier microclimat P4).
# ------------------------------------------------------------------
# Le gel tardif (gelée APRÈS débourrement) est un déterminant majeur de l'échec
# de régénération, surtout pour les essences sensibles (chêne, hêtre, douglas).
# R7 croise une série de température MINIMALE journalière (Tmin) — issue du
# downscaling meteoland/SAFRAN (chantier P4) ou d'une source Tmin directe — avec
# le jour de débourrement, et compte les gelées printanières post-débourrement.
#
# Conditionnel comme R5 (FORDEAD) / R6 (microclimf) : sans Tmin, R7 = NA / skip.
# Sens R1-R4/R6 : score élevé = FAIBLE risque (peu de gel). PAS d'inversion
# (contrairement à R5, seul indicateur « haut = mauvais »).

# Nombre de gelées tardives par an à partir d'une série Tmin journalière par UGF.
# `days` : matrice UGF × jours (Tmin, °C) ; `doy` : jour julien de chaque colonne ;
# `year` : année de chaque colonne. Compte, par (UGF, année), les jours où
# Tmin < seuil ET doy dans [budburst, fin_fenetre], puis moyenne inter-annuelle.
.frost_late_days <- function(tmin_mat, doy, year, budburst_doy, threshold,
                             window_end_doy) {
  in_window <- doy >= budburst_doy & doy <= window_end_doy
  yrs <- unique(year[in_window])
  if (!length(yrs)) return(rep(NA_real_, nrow(tmin_mat)))
  per_year <- vapply(yrs, function(y) {
    cols <- which(in_window & year == y)
    m <- tmin_mat[, cols, drop = FALSE]
    rowSums(m < threshold, na.rm = TRUE)
  }, numeric(nrow(tmin_mat)))
  # moyenne des gelées tardives par an ; NA si aucune donnée valide sur l'UGF.
  all_na <- rowSums(!is.na(tmin_mat[, in_window, drop = FALSE])) == 0
  out <- rowMeans(per_year, na.rm = TRUE)
  out[all_na] <- NA_real_
  out
}


#' Late-frost risk indicator (R7)
#'
#' @description
#' Per-unit **late-frost risk** — the frequency of spring frost **after
#' budburst**, the dominant cause of regeneration failure for frost-sensitive
#' species (oak, beech, Douglas fir). Fed by a daily **minimum temperature**
#' series (`tmin`), typically the meteoland/SAFRAN downscaling of the microclimat
#' chantier (P4); it also accepts a direct daily Tmin raster.
#'
#' Conditional like R5 (FORDEAD) and R6 (microclimf): without `tmin`, `R7` is
#' `NA` and `r7_status = "skipped_no_tmin"`. Sense follows R1–R4/R6 — **high
#' score = low risk** (few late frosts); it is **not** inverted (unlike R5).
#'
#' A unit's mean number of late-frost days per year (Tmin below
#' `frost_threshold_c`, on days after `budburst_doy` up to `window_end_doy`) is
#' mapped to 0–100: `0` days → `100`, `max_frost_days` or more → `0`.
#'
#' @param units An `sf` of management units.
#' @param tmin A daily minimum-temperature `SpatRaster` (one layer per day, dates
#'   via `terra::time()`), or `NULL` (→ skip). Multi-year series are supported.
#' @param budburst_doy Day-of-year of budburst; frosts before it don't count
#'   (default 100 ≈ 10 April).
#' @param window_end_doy Last day-of-year of the sensitivity window (default 180
#'   ≈ end June).
#' @param frost_threshold_c Tmin threshold (°C) below which a day is a frost
#'   (default 0).
#' @param max_frost_days Late-frost days per year mapping to score 0 (default 8).
#' @param ... Ignored (forward-compat).
#'
#' @return `units` with `R7` (0–100, high = low frost risk, `NA` when skipped),
#'   `r7_gel_days` (mean late-frost days/year), and `r7_status`
#'   (`"calculated"` / `"skipped_no_tmin"`).
#' @seealso [indicateur_r6_sensibilite()], [eobs_downscale()]
#' @export
indicateur_r7_gel <- function(units, tmin = NULL, budburst_doy = 100,
                              window_end_doy = 180, frost_threshold_c = 0,
                              max_frost_days = 8, ...) {
  validate_sf(units)

  if (is.null(tmin)) {
    units$R7 <- NA_real_
    units$r7_gel_days <- NA_real_
    units$r7_status <- "skipped_no_tmin"
    return(units)
  }
  if (!inherits(tmin, "SpatRaster")) {
    cli::cli_abort("{.arg tmin} must be a daily-minimum-temperature {.cls SpatRaster} or NULL.")
  }

  tt <- suppressWarnings(terra::time(tmin))
  if (length(tt) != terra::nlyr(tmin) || all(is.na(tt))) {
    cli::cli_abort(c(
      "{.arg tmin} carries no {.fun terra::time}; cannot place frosts in the season.",
      i = "Set daily dates with {.code terra::time(tmin) <- <Date vector>}."))
  }
  dts <- as.Date(tt)
  doy  <- as.integer(format(dts, "%j"))
  year <- as.integer(format(dts, "%Y"))

  # Tmin moyen par UGF et par jour. Matrice UGF × jours. On passe par
  # terra::extract (et non exactextractr) : les couches journalières partagent le
  # même nom par défaut, ce que exactextractr refuse ; la pondération de
  # couverture est de toute façon négligeable pour un champ de température.
  uv <- terra::vect(sf::st_transform(as_pure_sf(units),
                                     sf::st_crs(terra::crs(tmin))))
  ex <- terra::extract(tmin, uv, fun = mean, na.rm = TRUE, ID = FALSE)
  tmin_mat <- as.matrix(ex)
  storage.mode(tmin_mat) <- "double"

  gel_days <- .frost_late_days(tmin_mat, doy, year, budburst_doy,
                               frost_threshold_c, window_end_doy)

  # Score 0-100 : 0 gelée -> 100 ; >= max_frost_days -> 0 (haut = faible risque).
  score <- 100 * (1 - pmin(pmax(gel_days, 0), max_frost_days) / max_frost_days)

  units$R7 <- score
  units$r7_gel_days <- gel_days
  units$r7_status <- ifelse(is.na(gel_days), "skipped_no_tmin", "calculated")
  units
}
