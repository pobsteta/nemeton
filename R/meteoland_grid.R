# meteoland_grid.R — grille journalière meteoland depuis des pseudo-stations
# SAFRAN (chantier microclimat P4) : build_safran_stations() et
# meteoland_daily_grid(), qui alimentent le gel tardif R7. Extrait en 2026.10.18
# d'eobs_downscale.R, retiré avec eobs_downscale(), eobs_downscale_bivariate() et
# tendances_estivales_eobs() (remplacées par le contexte climatique sur un
# cercle, spec 063). Les helpers géométriques et MNT gardent leur nom d'origine.


# Emprise UGF + buffer, exprimée dans le CRS `crs_out`. Buffer métrique via
# EPSG:3035 (LAEA paneuropéen, ADR-008) pour un rayon en mètres correct.
.eobs_aoi_buffer <- function(aoi, buffer_m, crs_out) {
  g <- sf::st_union(sf::st_geometry(aoi))
  gm <- sf::st_transform(g, 3035)
  buf <- sf::st_buffer(gm, buffer_m)
  sf::st_transform(buf, crs_out)
}

# Facteur d'agrégation carré pour borner la grille sous `max_cells`.
.eobs_ds_agg_factor <- function(r, max_cells) {
  nc <- terra::ncell(r)
  if (!is.finite(max_cells) || max_cells <= 0 || nc <= max_cells) return(1L)
  max(1L, as.integer(ceiling(sqrt(nc / max_cells))))
}

# MNT de contexte de la voie meteoland : un MNT parcellaire ne couvre que
# quelques mailles SAFRAN sur le buffer ; on auto-source alors une élévation
# GROSSIÈRE (WMS IGN Géoplateforme, France, sans auth) sur tout le buffer.

# CRS métrique cible : celui du MNT s'il est projeté, sinon celui de l'AOI si
# projeté, sinon Lambert-93 (le WMS IGN est français).
.eobs_ds_metric_crs <- function(dem, aoi) {
  for (x in list(dem, aoi)) {
    if (is.null(x)) next
    crs <- tryCatch(
      if (inherits(x, "SpatRaster")) sf::st_crs(terra::crs(x)) else sf::st_crs(x),
      error = function(e) NA)
    if (!is.na(crs) && !isTRUE(sf::st_is_longlat(crs))) return(crs)
  }
  sf::st_crs(2154)
}

# Télécharge un MNT grossier (GetMap WMS IGN ELEVATION.ELEVATIONGRIDCOVERAGE,
# image/geotiff = vraies altitudes) sur un bbox WGS84. Best-effort -> NULL.
.eobs_ds_download_ign_dem <- function(bbox, res_m = 250, max_px = 2000L,
                                      timeout = 180) {
  svc <- tryCatch(get_layer_service("dem", "FR"), error = function(e) NULL)
  base_url <- svc$url %||% "https://data.geopf.fr/wms-r/wms"
  layer <- svc$layer %||% "ELEVATION.ELEVATIONGRIDCOVERAGE"
  res_deg <- res_m / 111000
  w <- max(1L, ceiling((bbox[3] - bbox[1]) / res_deg))
  h <- max(1L, ceiling((bbox[4] - bbox[2]) / res_deg))
  sc <- max(w, h) / max_px
  if (sc > 1) { w <- max(1L, floor(w / sc)); h <- max(1L, floor(h / sc)) }
  url <- paste0(base_url, "?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap",
                "&LAYERS=", layer, "&STYLES=&CRS=EPSG:4326",
                # WMS 1.3.0 + EPSG:4326 -> ordre lat,lon.
                "&BBOX=", paste(c(bbox[2], bbox[1], bbox[4], bbox[3]), collapse = ","),
                "&WIDTH=", w, "&HEIGHT=", h, "&FORMAT=image/geotiff")
  tmp <- tempfile(fileext = ".tif")
  old <- options(timeout = timeout); on.exit(options(old), add = TRUE)
  ok <- tryCatch({
    utils::download.file(url, tmp, mode = "wb", quiet = TRUE)
    file.exists(tmp) && file.size(tmp) > 1000
  }, error = function(e) FALSE)
  if (!ok) return(NULL)
  r <- tryCatch(suppressWarnings(terra::rast(tmp)), error = function(e) NULL)
  if (is.null(r)) return(NULL)
  # Le WMS IGN sert un datum ambigu (code NA) alors que les coords SONT en 4326.
  if (is.na(terra::crs(r, describe = TRUE)$code)) terra::crs(r) <- "EPSG:4326"
  if (terra::nlyr(r) > 1L) r <- r[[1]]
  names(r) <- "elevation"
  r
}

# Auto-source d'un MNT grossier sur le buffer, reprojeté dans le CRS métrique.
.eobs_ds_autoscale_dem <- function(aoi, buffer_m, res_m, metric_crs,
                                   timeout = 180) {
  buf_ll <- .eobs_aoi_buffer(aoi, buffer_m, sf::st_crs(4326))
  bbox <- as.numeric(sf::st_bbox(buf_ll))   # xmin, ymin, xmax, ymax
  r <- .eobs_ds_download_ign_dem(bbox, res_m = res_m, timeout = timeout)
  if (is.null(r)) return(NULL)
  # Le WMS IGN sert du 4326 -> reprojection dans le CRS métrique. Court-circuit si
  # déjà dans ce CRS (évite un warp GDAL inutile).
  if (sf::st_crs(terra::crs(r)) == sf::st_crs(metric_crs)) return(r)
  tryCatch(terra::project(r, sf::st_crs(metric_crs)$wkt),
           error = function(e) NULL)
}

# Grille de pseudo-stations SAFRAN sur AOI + buffer (chantier microclimat P4).
# SAFRAN est une réanalyse ~8 km : chaque maille = une pseudo-station (série
# journalière + altitude), ce qui suffit à meteoland. Réutilise l'acquisition
# GéoSAS déjà écrite/testée pour BILJOU (.biljou_forcing_safran) — pas de source
# neuve. L'altitude vient du MNT (cohérent avec le moteur KED).
#
# Retourne list(points = sf(id, elevation), series = liste de data.frame bruts
# SAFRAN par id), ou NULL si aucune série. `spacing_m` = pas de la grille de
# pseudo-stations (défaut 8 km, résolution SAFRAN).

#' Build the SAFRAN pseudo-station grid for meteoland (spec P4)
#'
#' @description
#' Sample SAFRAN cells over the AOI + buffer as **pseudo-stations** for the
#' meteoland interpolator: a point grid at `spacing_m` (SAFRAN ~8 km), each point
#' carrying its DEM elevation and its daily SAFRAN series (fetched from the same
#' GéoSAS OGC API-EDR already used for BILJOU). SAFRAN is a gridded reanalysis,
#' not a station network, but that is exactly what meteoland needs as reference
#' — see the P4 brief. The data source is thus already wired; no new one.
#'
#' @param aoi An `sf`/`sfc` of the management units.
#' @param buffer_m Context buffer (metres) sampled around the AOI.
#' @param years Integer year(s) of the SAFRAN series.
#' @param dem A `SpatRaster` DEM, sampled for each point's `elevation`.
#' @param spacing_m Pseudo-station grid step in metres (default 8000, SAFRAN
#'   resolution).
#' @param fetch Acquisition function (for testing); defaults to the internal
#'   GéoSAS SAFRAN reader. Signature `function(points, years)` returning a named
#'   list of raw daily data frames keyed by `points$id`.
#'
#' @return A list `list(points, series)`: `points` an `sf` of pseudo-stations
#'   (`id`, `elevation`, geometry in the DEM CRS) restricted to those with a
#'   non-empty series; `series` the matching named list. `NULL` if none resolve.
#' @section Lifecycle:
#' Experimental: may change in any release, without deprecation (spec 057).
#'
#' @seealso [meteoland_daily_grid()], [load_biljou_forcing()]
#' @export
build_safran_stations <- function(aoi, buffer_m, years, dem,
                                   spacing_m = 8000,
                                   fetch = NULL) {
  validate_sf(if (inherits(aoi, "sfc")) sf::st_sf(geometry = aoi) else aoi)
  if (!inherits(dem, "SpatRaster")) {
    cli::cli_abort("{.arg dem} must be a {.cls SpatRaster}.")
  }
  fetch <- fetch %||% function(points, years) {
    # jeu meteoland : Tmin/Tmax journalières en plus (gel R7 / stress thermique).
    .biljou_forcing_safran(points, years, params = .SAFRAN_METEOLAND_PARAMS)
  }
  crs_dem <- sf::st_crs(dem)
  buf <- .eobs_aoi_buffer(aoi, buffer_m, crs_dem)
  # Grille régulière de points au pas SAFRAN, restreinte au buffer.
  grid <- sf::st_make_grid(buf, cellsize = spacing_m, what = "centers")
  grid <- grid[lengths(sf::st_intersects(grid, buf)) > 0]
  if (!length(grid)) return(NULL)
  ll <- sf::st_coordinates(sf::st_transform(grid, 4326))
  points <- data.frame(id = seq_along(grid), lon = ll[, 1], lat = ll[, 2])

  series <- fetch(points, years)
  keep <- !vapply(series, function(s) is.null(s) || !NROW(s), logical(1))
  if (!any(keep)) return(NULL)

  elev <- as.numeric(terra::extract(
    dem, terra::vect(sf::st_transform(grid, crs_dem)), ID = FALSE)[[1]])
  pts_sf <- sf::st_sf(id = points$id, elevation = elev, geometry = grid)
  # meteoland exige une altitude par station : écarter les pseudo-stations hors
  # emprise MNT (elevation NA) autant que celles sans série.
  keep <- keep & is.finite(elev)
  if (!any(keep)) return(NULL)
  list(points = pts_sf[keep, ], series = series[keep])
}


# Résout le MNT de la voie meteoland/SAFRAN. Le MNT fourni sert à LA FOIS de
# source d'altitude des pseudo-stations SAFRAN (8 km) et de grille cible.
# `build_safran_stations()` écarte toute pseudo-station hors emprise MNT
# (elevation NA) : un MNT parcellaire (~5 km) ne garde qu'une poignée de mailles
# sur le buffer -> `< min_stations` -> abort. Même symptôme que le KED sur MNT
# trop petit : on auto-source alors un MNT régional grossier (WMS IGN) couvrant
# le buffer, réutilisé pour les altitudes ET la grille. Retourne un SpatRaster
# (le fourni s'il couvre assez de mailles, sinon l'auto-sourcé) ou NULL si
# l'auto-source échoue (réseau) — l'appelant émet alors `too few pseudo-stations`.
.meteoland_resolve_dem <- function(dem, aoi, buffer_m, min_stations,
                                   spacing_m = 8000, context_res_m = 250,
                                   timeout = 180) {
  metric_crs <- .eobs_ds_metric_crs(dem, aoi)
  buf <- .eobs_aoi_buffer(aoi, buffer_m, metric_crs)
  grid <- sf::st_make_grid(buf, cellsize = spacing_m, what = "centers")
  grid <- grid[lengths(sf::st_intersects(grid, buf)) > 0]
  if (!length(grid)) return(NULL)
  if (!is.null(dem)) {
    dem <- .normalize_crs(dem)
    elev <- tryCatch(as.numeric(terra::extract(
      dem, terra::vect(sf::st_transform(grid, sf::st_crs(dem))),
      ID = FALSE)[[1]]), error = function(e) rep(NA_real_, length(grid)))
    if (sum(is.finite(elev)) >= min_stations) return(dem)
  }
  auto <- .eobs_ds_autoscale_dem(aoi, buffer_m, context_res_m, metric_crs,
                                 timeout)
  if (!is.null(auto)) {
    cli::cli_warn(c(
      "meteoland: provided DEM spans too few SAFRAN cells over the {buffer_m} m buffer; auto-sourced a coarse regional DEM (IGN WMS).",
      i = "Pass a DEM spanning the buffer to skip the download."))
  }
  auto
}


# --- Glue meteoland (chantier microclimat P4, Option A) -------------------------
# Interpole les séries SAFRAN journalières (pseudo-stations) sur la grille MNT
# pour meteoland_daily_grid() (gel R7). meteoland en Suggests (GPL, compatible
# cœur GPL-3), validé sur données réelles (meteoland 2.2.7) ; non exécuté en CI.

# Mappe un data.frame SAFRAN brut (.biljou_forcing_safran, cols time + `*_Q`) vers
# les variables meteoland (with_meteo). Précip = liquide + neige. SSI_Q (J/cm²) ->
# MJ/m² (× 0.01) pour Radiation. Températures/HU/vent tels quels (°C/%/m·s⁻¹).
# Précip NA quand liquide ET neige manquent (jamais 0 mm inventé).
.safran_to_meteoland <- function(raw) {
  num <- function(v) suppressWarnings(as.numeric(v))
  pq <- cbind(num(raw$PRELIQ_Q), num(raw$PRENEI_Q))
  precip <- rowSums(pq, na.rm = TRUE)
  # Jour sans aucune composante renseignée (audit 1.0) : NA, pas 0 mm --
  # rowSums(na.rm = TRUE) inventait un jour sec.
  precip[rowSums(!is.na(pq)) == 0L] <- NA_real_
  data.frame(
    dates                = as.Date(substr(raw$time, 1, 10)),
    MinTemperature       = num(raw$TINF_H_Q),
    MaxTemperature       = num(raw$TSUP_H_Q),
    MeanTemperature      = num(raw$T_Q),
    Precipitation        = precip,
    MeanRelativeHumidity = num(raw$HU_Q),
    WindSpeed            = num(raw$FF_Q),
    Radiation            = num(raw$SSI_Q) * 0.01,
    stringsAsFactors     = FALSE)
}

# Construit l'objet `meteo` de meteoland (sf LONG : une ligne par station × jour)
# depuis la sortie de build_safran_stations (points + series brutes). Géométrie
# répétée par jour, `stationID`/`elevation` portés. NULL si aucune série.
.meteoland_meteo_sf <- function(stations) {
  pts <- stations$points
  ser <- stations$series
  parts <- list()
  geoms <- list()
  for (i in seq_len(nrow(pts))) {
    raw <- ser[[i]]
    if (is.null(raw) || !NROW(raw) || !"time" %in% names(raw)) next
    d <- .safran_to_meteoland(raw)
    d$stationID <- as.character(pts$id[i])
    d$elevation <- pts$elevation[i]
    parts[[length(parts) + 1L]] <- d
    geoms[[length(geoms) + 1L]] <- sf::st_geometry(pts)[rep(i, nrow(d))]
  }
  if (!length(parts)) return(NULL)
  sf::st_sf(do.call(rbind, parts), geometry = do.call(c, geoms),
            crs = sf::st_crs(pts))
}

# Grille cible meteoland = MNT recadré sur AOI+buffer, borné en cellules, en
# `stars` à 3 attributs SÉPARÉS (elevation/slope/aspect en degrés) — le format
# exact attendu par interpolate_data (une grille régulière, pas curviligne : d'où
# le MNT natif, jamais une reprojection).
.eobs_ds_stars_grid <- function(dem, aoi_buf, max_cells) {
  dem <- .normalize_crs(dem)
  dem <- terra::crop(dem, terra::vect(aoi_buf), snap = "out")
  fac <- .eobs_ds_agg_factor(dem, max_cells)
  if (fac > 1L) dem <- terra::aggregate(dem, fact = fac, fun = "mean", na.rm = TRUE)
  names(dem) <- "elevation"
  slo <- terra::terrain(dem, v = "slope", unit = "degrees")
  asp <- terra::terrain(dem, v = "aspect", unit = "degrees")
  to_stars <- function(x, nm) {
    s <- stars::st_as_stars(x)
    names(s) <- nm
    s
  }
  c(to_stars(dem, "elevation"), to_stars(slo, "slope"), to_stars(asp, "aspect"))
}

# Construit et (optionnellement) calibre l'interpolateur meteoland. La calibration
# LOO est LOURDE -> hors défaut ; l'appelant la déclenche sciemment.
.meteoland_build_interpolator <- function(meteo, calibrate = FALSE,
                                          variable = "MaxTemperature") {
  interp <- meteoland::create_meteo_interpolator(
    meteoland::with_meteo(meteo, verbose = FALSE), verbose = FALSE)
  if (isTRUE(calibrate)) {
    interp <- tryCatch(
      meteoland::interpolator_calibration(
        interp, variable = variable,
        update_interpolation_params = TRUE, verbose = FALSE),
      error = function(e) {
        cli::cli_warn("meteoland calibration failed ({conditionMessage(e)}); default params.")
        interp
      })
  }
  interp
}



#' Downscale a daily meteoland variable to a fine raster stack
#'
#' @description
#' Interpolate a **daily** meteorological variable (e.g. daily minimum
#' temperature) from SAFRAN pseudo-stations onto the DEM grid with
#' \pkg{meteoland} (Thornton 1997 + elevation), returning a `SpatRaster` with one
#' layer per day and `terra::time()` set. This is the real-data feeder for
#' [indicateur_r7_gel()] (late-frost risk needs a daily Tmin series) and for any
#' downstream daily-climate use; the regional climate context map goes through
#' [climat_tendance_bivariee()] instead.
#'
#' meteoland lives in Suggests and is **absent from CI** — like microclimf, this
#' path is validated on real data. Any failure (package absent, GéoSAS down, too
#' few stations) returns `NULL`, never an error, so callers degrade gracefully.
#'
#' @param aoi An `sf`/`sfc` of the management units.
#' @param dem A `SpatRaster` DEM — the target grid; the output shares its CRS.
#' @param years Integer year(s) of the SAFRAN series to interpolate.
#' @param variable meteoland variable to return (default `"MinTemperature"`;
#'   also `"MaxTemperature"`, `"MeanTemperature"`, `"Precipitation"`, …).
#' @param dates Optional explicit `Date` vector; when `NULL`, the spring window
#'   (day-of-year `doy_range`) of each year is used — the season that matters for
#'   late frost.
#' @param doy_range Integer length-2 day-of-year window used when `dates` is
#'   `NULL` (default `c(60, 180)` ≈ 1 March–end June).
#' @param buffer_m Context buffer (metres) for sampling SAFRAN stations
#'   (default 25000).
#' @param max_cells Cell cap for the target grid (default `5e5`).
#' @param min_stations Minimum SAFRAN pseudo-stations required (default 5).
#' @param calibrate Run the (expensive) meteoland LOO calibration first
#'   (default `FALSE`).
#' @param ... Ignored (forward-compat).
#'
#' @return A daily `SpatRaster` (one layer per interpolated day, `terra::time()`
#'   set, DEM CRS), ready to pass as `tmin =` to [indicateur_r7_gel()]; or `NULL`
#'   when unavailable.
#' @section Lifecycle:
#' Experimental: may change in any release, without deprecation (spec 057).
#'
#' @seealso [climat_ete_series()], [indicateur_r7_gel()], [build_safran_stations()]
#' @export
meteoland_daily_grid <- function(aoi, dem, years, variable = "MinTemperature",
                                 dates = NULL, doy_range = c(60L, 180L),
                                 buffer_m = 25000, max_cells = 5e5,
                                 min_stations = 5L, calibrate = FALSE, ...) {
  if (!requireNamespace("meteoland", quietly = TRUE) ||
      !requireNamespace("stars", quietly = TRUE)) {
    return(NULL)
  }
  if (!inherits(dem, "SpatRaster")) {
    cli::cli_abort("{.arg dem} must be a {.cls SpatRaster}.")
  }
  yrs <- sort(unique(as.integer(years)))

  tryCatch({
    # Un MNT parcellaire ne couvre qu'une poignée de mailles SAFRAN sur le
    # buffer -> auto-source d'un MNT régional grossier (WMS IGN), sinon abort.
    dem_n <- .meteoland_resolve_dem(dem, aoi, buffer_m + 8000, min_stations)
    if (is.null(dem_n)) {
      cli::cli_warn("meteoland_daily_grid(): too few SAFRAN pseudo-stations.")
      return(NULL)
    }
    aoi_buf <- .eobs_aoi_buffer(aoi, buffer_m, sf::st_crs(dem_n))
    stations <- build_safran_stations(aoi, buffer_m + 8000, yrs, dem_n)
    if (is.null(stations) || nrow(stations$points) < min_stations) {
      cli::cli_warn("meteoland_daily_grid(): too few SAFRAN pseudo-stations.")
      return(NULL)
    }
    meteo <- .meteoland_meteo_sf(stations)
    if (is.null(meteo) || !nrow(meteo)) return(NULL)

    interp <- .meteoland_build_interpolator(meteo, calibrate = calibrate,
                                            variable = variable)
    grid <- .eobs_ds_stars_grid(dem_n, aoi_buf, max_cells)

    if (is.null(dates)) {
      dates <- do.call(c, lapply(yrs, function(y) {
        all_d <- seq(as.Date(sprintf("%d-01-01", y)),
                     as.Date(sprintf("%d-12-31", y)), by = "day")
        all_d[as.integer(format(all_d, "%j")) >= doy_range[1] &
                as.integer(format(all_d, "%j")) <= doy_range[2]]
      }))
    }
    d <- meteoland::interpolate_data(
      grid, interp, dates = dates,
      ignore_convex_hull_check = TRUE, verbose = FALSE)
    # dim `date` -> couches terra (split : terra::rast() ne convertit pas un stars
    # multi-dimension directement).
    stk <- terra::rast(split(d[variable], "date"))
    stk <- terra::mask(stk, terra::vect(aoi_buf))
    terra::time(stk) <- as.Date(dates)
    names(stk) <- format(as.Date(dates), "%Y-%m-%d")
    stk
  }, error = function(e) {
    cli::cli_warn("meteoland_daily_grid(): interpolation failed ({conditionMessage(e)}).")
    NULL
  })
}
