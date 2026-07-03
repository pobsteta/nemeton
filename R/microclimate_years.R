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


# Resolve a per-year summer-heat index from `eobs`. Supports either a
# precomputed named numeric (year -> heat) directly, or a per-year summer
# `SpatRaster` (one layer per year, JJA-aggregated, same contract as the `tx`
# input of `tendances_estivales_eobs`): the AOI-mean of each layer gives the
# yearly heat index. Years come from `years` or the layer names.
.eobs_summer_heat <- function(eobs, aoi = NULL, years = NULL, year_window = NULL) {
  if (is.numeric(eobs) && !is.null(names(eobs))) {
    heat <- eobs
  } else if (inherits(eobs, "SpatRaster")) {
    if (!requireNamespace("terra", quietly = TRUE)) {
      cli::cli_abort("E-OBS raster extraction needs the {.pkg terra} package.")
    }
    r <- eobs
    # Restreindre à l'emprise si fournie (crop + mask sur l'union des UGF).
    if (!is.null(aoi)) {
      if (!inherits(aoi, c("sf", "sfc"))) {
        cli::cli_abort("{.arg aoi} must be an sf/sfc when {.arg eobs} is a SpatRaster.")
      }
      av <- terra::vect(sf::st_transform(
        sf::st_union(sf::st_geometry(aoi)), terra::crs(r)))
      r <- terra::mask(terra::crop(r, av, snap = "out"), av)
    }
    # Indice de chaleur estivale par an = moyenne spatiale de la couche sur l'AOI.
    vals <- terra::global(r, "mean", na.rm = TRUE)[[1L]]
    if (is.null(years)) years <- suppressWarnings(as.integer(names(r)))
    if (length(years) != length(vals) || anyNA(years)) {
      cli::cli_abort(c(
        "Cannot resolve one year per E-OBS layer.",
        i = "Name the {.cls SpatRaster} layers with years, or pass {.arg years}."))
    }
    heat <- stats::setNames(vals, as.character(as.integer(years)))
    heat <- heat[is.finite(heat)]
    if (length(heat) < 2L) {
      cli::cli_abort(c(
        "E-OBS raster yielded < 2 usable yearly summer values over the AOI.",
        i = "Widen the AOI, check layer NA coverage, or pass a named numeric {.arg eobs}."))
    }
  } else {
    cli::cli_abort(c(
      "E-OBS summer-heat must be a named numeric (year -> heat) or a per-year summer {.cls SpatRaster}.",
      i = "Pass {.arg eobs} accordingly, or set {.arg year_moyenne}/{.arg year_canicule} manually."))
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
#' @param eobs The E-OBS summer-heat series. Either a **named numeric**
#'   (`year -> summer-heat index`, e.g. mean JJA Tmax), used directly, or a
#'   **per-year summer `SpatRaster`** (one layer per year, JJA-aggregated —
#'   same contract as `tx` in [tendances_estivales_eobs()]): each layer is
#'   averaged over `aoi` to give the yearly index.
#' @param aoi Optional `sf`/`sfc` AOI. When `eobs` is a `SpatRaster` it is
#'   cropped + masked to the units' union before averaging.
#' @param years Optional integer years, one per `SpatRaster` layer (default:
#'   the layer names parsed as integers). Ignored for the named-numeric path.
#' @param year_window Optional. A single integer `n` (last `n` years) or a
#'   `c(from, to)` range to restrict the candidate years.
#' @param lidar_year Optional integer; on a tie for the average year,
#'   prefer the candidate nearest the LiDAR acquisition (limits the
#'   frozen-canopy bias).
#'
#' @return A list: `year_moyenne`, `year_canicule` (integers) and `index`
#'   (named numeric, the summer-heat index per candidate year).
#' @seealso [indicateur_r6_sensibilite()], [tendances_estivales_eobs()]
#' @export
microclimate_detect_years <- function(eobs = NULL, aoi = NULL, years = NULL,
                                      year_window = NULL, lidar_year = NULL) {
  if (is.null(eobs)) {
    cli::cli_abort(c(
      "microclimate_detect_years() needs an E-OBS summer series.",
      i = "Pass {.arg eobs} (named numeric year -> summer heat, or a per-year summer SpatRaster), or set the years manually."))
  }
  heat <- .eobs_summer_heat(eobs, aoi = aoi, years = years,
                            year_window = year_window)
  .select_years(heat, lidar_year = lidar_year)
}
