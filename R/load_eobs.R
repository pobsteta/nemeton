# load_eobs.R — acquisition E-OBS (T°max / précip estivales par année) pour la
# détection des années de référence et le contexte régional reGénération.
# ------------------------------------------------------------------
# E-OBS = jeu européen quadrillé quotidien (ECA&D / Copernicus). Les deux
# consommateurs cœur — microclimate_detect_years() et tendances_estivales_eobs()
# — attendent un SpatRaster ESTIVAL PAR ANNÉE (une couche/an, nommée par
# l'année). Ce loader produit ce format depuis un netCDF quotidien fourni
# (voie B / injection `nc`, testable) ou téléchargé au CDS (voie A, best-effort,
# validé sur données réelles). Spec 034. Patron : load_foret_ancienne_source().

# Dataset E-OBS sur le Copernicus CDS (même clé ecmwfr que ERA5/mcera5).
.EOBS_CDS_DATASET <- "insitu-gridded-observations-europe"

# var nemeton -> (variable CDS, réducteur estival par défaut).
.eobs_var_spec <- function(var) {
  switch(
    var,
    tx = list(cds = "maximum_temperature",  reducer = "mean"),
    tg = list(cds = "mean_temperature",     reducer = "mean"),
    rr = list(cds = "precipitation_amount", reducer = "sum"),
    cli::cli_abort("Unknown E-OBS {.arg var} {.val {var}}; use \"tx\", \"tg\" or \"rr\".")
  )
}

# Réduction estivale par année (chemin PUR, testable) : un raster quotidien daté
# -> une couche par année = réduction sur les mois d'été, restreinte à l'AOI.
.eobs_summer_by_year <- function(daily, aoi = NULL, years = NULL, months = 6:8,
                                 reducer = "mean") {
  if (!inherits(daily, "SpatRaster")) {
    cli::cli_abort("{.arg daily} must be a {.cls SpatRaster} of daily E-OBS values.")
  }
  fun <- switch(reducer, mean = "mean", sum = "sum", max = "max", median = "median",
                cli::cli_abort("Unknown {.arg reducer} {.val {reducer}}."))
  if (!is.null(aoi)) {
    if (!inherits(aoi, c("sf", "sfc"))) {
      cli::cli_abort("{.arg aoi} must be an {.cls sf}/{.cls sfc}.")
    }
    av <- terra::vect(sf::st_transform(
      sf::st_union(sf::st_geometry(aoi)), terra::crs(daily)))
    daily <- terra::mask(terra::crop(daily, av, snap = "out"), av)
  }
  tt <- terra::time(daily)
  if (length(tt) == 0L || all(is.na(tt))) {
    cli::cli_abort(c(
      "E-OBS raster carries no {.fun terra::time}; cannot select summer months.",
      i = "Read the daily E-OBS netCDF so layers keep their dates."))
  }
  dates <- as.Date(tt)
  yr <- as.integer(format(dates, "%Y"))
  mo <- as.integer(format(dates, "%m"))
  keep_m <- mo %in% months
  ys <- if (is.null(years)) sort(unique(yr[keep_m])) else sort(unique(as.integer(years)))
  layers <- lapply(ys, function(y) {
    idx <- which(keep_m & yr == y)
    if (!length(idx)) return(NULL)
    terra::app(daily[[idx]], fun = fun)
  })
  ok <- !vapply(layers, is.null, logical(1))
  if (!any(ok)) {
    cli::cli_abort("No E-OBS summer layers for the requested {.arg years}/{.arg months}.")
  }
  out <- terra::rast(layers[ok])
  ys_ok <- ys[ok]
  names(out) <- as.character(ys_ok)
  terra::time(out) <- as.Date(sprintf("%d-07-15", ys_ok))
  out
}

# Téléchargement CDS best-effort (voie A). Non jouable en CI ; validé sur données
# réelles. Renvoie un chemin netCDF, ou NULL en dégradation.
.eobs_cds_fetch <- function(cds_var, years, cache_dir, version, resolution,
                            period = NULL) {
  if (!requireNamespace("ecmwfr", quietly = TRUE)) return(NULL)
  if (is.null(cache_dir)) cache_dir <- tempdir()
  if (is.null(period)) {
    if (is.null(years)) return(NULL)          # sans années, pas de bloc CDS déductible
    period <- .eobs_cds_period(as.integer(years))
    if (is.null(period)) return(NULL)
  }
  req <- list(
    dataset_short_name = .EOBS_CDS_DATASET,
    product_type    = "ensemble_mean",
    variable        = cds_var,
    grid_resolution = resolution,
    period          = period,
    version         = version,
    format          = "zip",
    target          = "eobs.zip")
  zip <- tryCatch(
    ecmwfr::wf_request(request = req, path = cache_dir, transfer = TRUE),
    error = function(e) NULL)
  if (is.null(zip) || !file.exists(zip)) return(NULL)
  nc <- tryCatch({
    files <- utils::unzip(zip, exdir = cache_dir)
    files[grepl("\\.nc$", files)][1]
  }, error = function(e) NULL)
  if (is.null(nc) || is.na(nc) || !file.exists(nc)) return(NULL)
  nc
}

# Bloc pluriannuel E-OBS couvrant les années demandées (les fichiers CDS sont
# livrés par tranches). Renvoie NULL si les années débordent d'un seul bloc.
.eobs_cds_period <- function(years) {
  blocks <- list(c(1950, 1964), c(1965, 1979), c(1980, 1994),
                 c(1995, 2010), c(2011, 2100))
  for (b in blocks) {
    if (all(years >= b[1] & years <= b[2])) {
      hi <- if (b[2] >= 2100) 2024L else b[2]     # borne haute réelle du dernier bloc
      return(sprintf("%d_%d", b[1], hi))
    }
  }
  NULL
}

#' Acquire E-OBS per-year summer fields (Tmax / precipitation) for an AOI
#'
#' @description
#' Build the per-year summer `SpatRaster` (one layer per year, named by year)
#' that [microclimate_detect_years()] and [tendances_estivales_eobs()] consume,
#' from the European E-OBS gridded dataset (ECA&D / Copernicus). Two paths
#' (spec 034):
#'
#' - **Injection (`nc`)** — pass a daily E-OBS netCDF path (downloaded from the
#'   CDS web interface or ECA&D) or a dated `SpatRaster`; the core reduces it to
#'   summer-per-year. This is the tested contract.
#' - **CDS (`source = "cds"`)** — best-effort automatic download via `ecmwfr`
#'   (dataset `insitu-gridded-observations-europe`, the same CDS key as ERA5).
#'   Not runnable in CI; validated on real data. Degrades to `NULL`.
#'
#' @param aoi An `sf`/`sfc` of the management units (their union crops E-OBS).
#' @param var E-OBS variable: `"tx"` (max temperature, default), `"tg"` (mean
#'   temperature) or `"rr"` (precipitation).
#' @param years Optional integer years to keep (default: all years present).
#' @param months Summer months to reduce over (default `6:8`, JJA).
#' @param source `"cds"` for the automatic Copernicus download, anything else
#'   requires `nc`.
#' @param reducer Temporal reducer over the summer days: default `"mean"` for
#'   `tx`/`tg`, `"sum"` for `rr`. Also `"max"`, `"median"`.
#' @param nc A daily E-OBS netCDF path (or a dated `SpatRaster`) to use instead
#'   of the CDS download.
#' @param cache_dir Directory for the CDS download / unzip (default `tempdir()`).
#' @param version,resolution E-OBS product version (default `"28.0e"`) and grid
#'   resolution (default `"0.1deg"`) for the CDS request.
#' @param period Optional explicit CDS period block (e.g. `"2011_2024"`);
#'   inferred from `years` when `NULL`.
#' @param ... Ignored (forward-compat).
#'
#' @return A per-year summer `SpatRaster` (layers named by year), or `NULL` on
#'   graceful degradation.
#' @export
load_eobs_source <- function(aoi, var = "tx", years = NULL, months = 6:8,
                             source = "cds", reducer = NULL, nc = NULL,
                             cache_dir = NULL, version = "28.0e",
                             resolution = "0.1deg", period = NULL, ...) {
  if (!requireNamespace("terra", quietly = TRUE) ||
      !requireNamespace("sf", quietly = TRUE)) {
    return(NULL)
  }
  spec <- .eobs_var_spec(var)
  if (is.null(reducer)) reducer <- spec$reducer
  daily <- tryCatch({
    if (!is.null(nc)) {
      if (inherits(nc, "SpatRaster")) nc else terra::rast(nc)
    } else if (identical(source, "cds")) {
      f <- .eobs_cds_fetch(spec$cds, years, cache_dir, version, resolution, period)
      if (is.null(f)) return(NULL)
      terra::rast(f)
    } else {
      return(NULL)
    }
  }, error = function(e) NULL)
  if (is.null(daily)) return(NULL)
  tryCatch(
    .eobs_summer_by_year(daily, aoi = aoi, years = years, months = months,
                         reducer = reducer),
    error = function(e) NULL)
}
