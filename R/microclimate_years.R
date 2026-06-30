# microclimate_years.R — R6 reference-year selection (spec 027 §6bis, L2)
# ------------------------------------------------------------------
# R6 (indicateur_r6_sensibilite) compares a "heatwave" summer to an
# "average" summer with the canopy held fixed. The two years are chosen
# automatically by default from the E-OBS summer (JJA) heat series, and
# can be overridden by the user. The selection logic is a pure function
# (testable offline); the E-OBS extraction is the data-bound part.


# Pure selector: from a per-year summer heat index, pick the heatwave
# (hottest) and average (closest to the climatological median) years.
# Ties on the average year break toward the year nearest `lidar_year`
# (limits the frozen-canopy bias, spec 027 §12). `moyenne` is forced
# distinct from `canicule`.
.select_years <- function(heat_by_year, lidar_year = NULL) {
  if (!is.numeric(heat_by_year) || is.null(names(heat_by_year)) ||
      length(heat_by_year) < 2L) {
    cli::cli_abort(c(
      "{.arg heat_by_year} must be a named numeric (year -> summer heat), length >= 2.",
      i = "Names are the years; values a summer-heat index (e.g. mean JJA Tmax)."))
  }
  yrs  <- suppressWarnings(as.integer(names(heat_by_year)))
  keep <- !is.na(yrs) & !is.na(heat_by_year)
  yrs  <- yrs[keep]; heat <- as.numeric(heat_by_year)[keep]
  ord  <- order(yrs); yrs <- yrs[ord]; heat <- heat[ord]

  canicule <- yrs[which.max(heat)]
  med <- stats::median(heat)
  d   <- abs(heat - med)
  cand <- yrs[d == min(d)]
  moyenne <- if (!is.null(lidar_year) && length(cand) > 1L) {
    cand[which.min(abs(cand - as.integer(lidar_year)))]
  } else cand[[1L]]
  if (moyenne == canicule && length(yrs) > 1L) {
    d2 <- d; d2[yrs == canicule] <- Inf
    moyenne <- yrs[which.min(d2)]
  }
  list(year_moyenne = as.integer(moyenne),
       year_canicule = as.integer(canicule),
       index = stats::setNames(heat, as.character(yrs)))
}


# Resolve a per-year summer-heat index from `eobs`. Supports a precomputed
# named numeric (year -> heat) directly; raster/netcdf extraction over the
# AOI is deferred (data-bound, requires the E-OBS series — spec 027).
.eobs_summer_heat <- function(eobs, aoi = NULL, year_window = NULL) {
  if (is.numeric(eobs) && !is.null(names(eobs))) {
    heat <- eobs
  } else {
    cli::cli_abort(c(
      "E-OBS summer-heat extraction from a raster/netcdf is not wired yet (spec 027 L2).",
      i = "Pass {.arg eobs} as a named numeric (year -> summer heat index), or set {.arg year_moyenne}/{.arg year_canicule} manually."))
  }
  if (!is.null(year_window)) {
    yrs <- suppressWarnings(as.integer(names(heat)))
    if (length(year_window) == 1L) {
      cutoff <- max(yrs, na.rm = TRUE) - as.integer(year_window) + 1L
      heat <- heat[yrs >= cutoff]
    } else {
      heat <- heat[yrs >= min(year_window) & yrs <= max(year_window)]
    }
  }
  heat
}


#' Detect the average / heatwave reference years for R6 (spec 027 §6bis)
#'
#' @description
#' Picks the **average** and **heatwave** summers used by
#' [indicateur_r6_sensibilite()], from the E-OBS summer (JJA) heat series
#' over the AOI. Auto-detection is the default; the result is meant to
#' pre-fill the app's two year selectors, which the user can override.
#'
#' @param eobs The E-OBS summer-heat series. A **named numeric**
#'   (`year -> summer-heat index`, e.g. mean JJA Tmax) is used directly;
#'   raster/netcdf extraction over `aoi` is deferred (data-bound).
#' @param aoi Optional `sf`/`sfc` AOI (used by the deferred raster path).
#' @param year_window Optional. A single integer `n` (last `n` years) or a
#'   `c(from, to)` range to restrict the candidate years.
#' @param lidar_year Optional integer; on a tie for the average year,
#'   prefer the candidate nearest the LiDAR acquisition (limits the
#'   frozen-canopy bias).
#'
#' @return A list: `year_moyenne`, `year_canicule` (integers) and `index`
#'   (named numeric, the summer-heat index per candidate year).
#' @seealso [indicateur_r6_sensibilite()]
#' @export
microclimate_detect_years <- function(eobs = NULL, aoi = NULL,
                                      year_window = NULL, lidar_year = NULL) {
  if (is.null(eobs)) {
    cli::cli_abort(c(
      "microclimate_detect_years() needs an E-OBS summer series.",
      i = "Pass {.arg eobs} (named numeric year -> summer heat), or set the years manually."))
  }
  heat <- .eobs_summer_heat(eobs, aoi = aoi, year_window = year_window)
  .select_years(heat, lidar_year = lidar_year)
}
