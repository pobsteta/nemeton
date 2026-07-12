# eobs_downscale.R — downscaling d'une variable E-OBS (~11 km) en un raster fin
# par régression-krigeage (KED) avec le MNT en covariable. Spec :
# brief-nemeton-eobs-downscaling. Cible : le CONTEXTE régional (buffer large),
# pas la précision parcellaire — celle-ci est produite par microclimate_run()
# (microclimf + LiDAR HD), qu'on ne duplique pas ici.
# ------------------------------------------------------------------
# v1 : température maximale `tx` uniquement (signal altitudinal fort, ~-0.6 °C
# /100 m). `rr` (précipitations) hors scope (downscaling peu fiable ; le MNT
# n'aide qu'en montagne, le MNH n'a aucun lien avec la pluie incidente).
#
# gstat est en Suggests, chargé via requireNamespace(). Sans gstat, ou avec trop
# peu de mailles E-OBS, la fonction dégrade en `trend_only` (dérive de régression
# sans krigeage des résidus) — un fallback DEMANDÉ, pas une erreur.

# Pente OLS de v sur x, réutilisée de tendances_eobs (tendance par maille).
.eobs_ds_slope <- function(v, x) {
  ok <- is.finite(v) & is.finite(x)
  if (sum(ok) < 2L) return(NA_real_)
  xx <- x[ok]; yy <- v[ok]
  mx <- mean(xx); denom <- sum((xx - mx)^2)
  if (denom == 0) return(NA_real_)
  sum((xx - mx) * (yy - mean(yy))) / denom
}

# Années depuis terra::time() (sinon index 1..n) — pour une pente en °C/décennie.
.eobs_ds_years <- function(r, years = NULL) {
  if (!is.null(years)) return(as.numeric(years))
  tt <- suppressWarnings(terra::time(r))
  if (length(tt) == terra::nlyr(r) && !all(is.na(tt))) {
    return(as.numeric(format(as.Date(tt), "%Y")))
  }
  seq_len(terra::nlyr(r))
}

# Réduit le raster E-OBS (une couche/an) à UNE couche = la statistique visée.
# trend -> pente/décennie ; mean -> moyenne ; value -> couche unique telle quelle.
.eobs_ds_reduce <- function(eobs, statistic, years) {
  if (identical(statistic, "value")) {
    if (terra::nlyr(eobs) != 1L) {
      cli::cli_abort("statistic = \"value\" expects a single-layer {.arg eobs}.")
    }
    return(eobs)
  }
  if (identical(statistic, "mean")) {
    return(terra::app(eobs, fun = "mean", na.rm = TRUE))
  }
  # trend : pente OLS par pixel sur les années, ramenée à la décennie.
  yrs <- .eobs_ds_years(eobs, years)
  terra::app(eobs, function(v) .eobs_ds_slope(v, yrs) * 10)
}

# Facteur d'agrégation carré pour borner la grille sous `max_cells`.
.eobs_ds_agg_factor <- function(r, max_cells) {
  nc <- terra::ncell(r)
  if (!is.finite(max_cells) || max_cells <= 0 || nc <= max_cells) return(1L)
  max(1L, as.integer(ceiling(sqrt(nc / max_cells))))
}

# Pile de covariables dérivées du MNT, alignée sur la grille de `dem`.
# "aspect" est entré comme NORTHNESS = cos(aspect) : l'exposition brute en degrés
# est circulaire et n'a aucun sens dans une régression linéaire ; la northness
# (versant nord = plus frais) est le prédicteur physiquement fondé pour `tx`.
# "twi" est best-effort (dépend de get_or_compute_twi) : ignoré s'il échoue.
.eobs_ds_covariates <- function(dem, covariates) {
  layers <- list()
  if ("dem" %in% covariates) layers$dem <- dem
  if ("slope" %in% covariates) {
    layers$slope <- terra::terrain(dem, v = "slope", unit = "degrees")
  }
  if ("aspect" %in% covariates) {
    asp <- terra::terrain(dem, v = "aspect", unit = "radians")
    north <- cos(asp)
    names(north) <- "northness"
    layers$northness <- north
  }
  if ("twi" %in% covariates) {
    twi <- tryCatch(get_or_compute_twi(dem), error = function(e) NULL)
    if (!is.null(twi)) {
      if (!terra::compareGeom(twi, dem, stopOnError = FALSE)) {
        twi <- terra::resample(twi, dem, method = "bilinear")
      }
      names(twi) <- "twi"
      layers$twi <- twi
    } else {
      cli::cli_warn("eobs_downscale_ked(): TWI covariate unavailable; dropping it.")
    }
  }
  if (!length(layers)) {
    cli::cli_abort("No usable covariate; {.arg covariates} must include at least {.val dem}.")
  }
  st <- terra::rast(layers)
  # Noms = termes du modèle (dem/slope/northness/twi).
  names(st) <- names(layers)
  st
}

# Krige les résidus (KED en deux temps : dérive lm + krigeage des résidus) sur la
# grille `template`. Retourne un SpatRaster de résidus, ou NULL si gstat absent /
# krigeage impossible (l'appelant retombe alors sur la dérive seule).
.eobs_ds_krige_residuals <- function(pts_sf, template, variogram_model = NULL) {
  if (!requireNamespace("gstat", quietly = TRUE)) return(NULL)
  tryCatch({
    # sf de bout en bout : gstat (>= 2.0) et automap (>= 1.1) acceptent sf
    # directement. On évite `as(, "Spatial")`, dont la coercion S4 sp/spacetime
    # entre en conflit avec terra selon l'environnement (« coerce » STFDF/
    # RasterBrick), ce qui faisait échouer le krigeage en silence.
    v <- gstat::variogram(residual ~ 1, pts_sf)
    fit <- if (!is.null(variogram_model)) {
      gstat::fit.variogram(v, variogram_model)
    } else if (requireNamespace("automap", quietly = TRUE)) {
      automap::autofitVariogram(residual ~ 1, pts_sf)$var_model
    } else {
      # Modèle sphérique avec initiales raisonnables (portée = 1/3 de l'étendue).
      ext <- terra::ext(template)
      rng <- max(ext[2] - ext[1], ext[4] - ext[3]) / 3
      psill <- stats::var(pts_sf$residual, na.rm = TRUE)
      gstat::fit.variogram(v, gstat::vgm(psill, "Sph", rng, psill * 0.1))
    }
    grid_pts <- sf::st_as_sf(
      as.data.frame(template, xy = TRUE, na.rm = TRUE),
      coords = c("x", "y"), crs = sf::st_crs(pts_sf))
    kr <- gstat::krige(residual ~ 1, pts_sf, grid_pts, model = fit, debug.level = 0)
    out <- template
    terra::values(out) <- NA_real_
    cells <- terra::cellFromXY(out, sf::st_coordinates(grid_pts))
    out[cells] <- kr$var1.pred
    names(out) <- "residual_kriged"
    out
  }, error = function(e) {
    cli::cli_warn("eobs_downscale_ked(): residual kriging failed ({conditionMessage(e)}); trend-only.")
    NULL
  })
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

#' Build the SAFRAN pseudo-station grid for the meteoland engine (spec P4)
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
#' @seealso [eobs_downscale()], [load_biljou_forcing()]
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


# --- Glue meteoland (chantier microclimat P4, Option A) -------------------------
# Interpole les séries SAFRAN journalières (pseudo-stations) sur la grille MNT,
# par année, puis recompose la statistique (même sémantique que KED). meteoland en
# Suggests (GPL, compatible cœur GPL-3). Le pipeline a été validé de bout en bout
# sur données réelles (meteoland 2.2.7) : CRS projeté (Lambert-93 natif) accepté
# tant que la grille cible est régulière ; interpolate_data -> summarise ->
# terra::rast. Non exécuté en CI (meteoland absent), patron microclimf. Toute
# absence / densité insuffisante / erreur -> NULL, l'appelant retombe sur KED : le
# moteur ne casse jamais la sortie.

# Mappe un data.frame SAFRAN brut (.biljou_forcing_safran, cols time + `*_Q`) vers
# les variables meteoland (with_meteo). Précip = liquide + neige. SSI_Q (J/cm²) ->
# MJ/m² (× 0.01) pour Radiation. Températures/HU/vent tels quels (°C/%/m·s⁻¹).
.safran_to_meteoland <- function(raw) {
  num <- function(v) suppressWarnings(as.numeric(v))
  precip <- rowSums(cbind(num(raw$PRELIQ_Q), num(raw$PRENEI_Q)), na.rm = TRUE)
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

# Fenêtre estivale (1 juin - 31 août) d'une année, pour le Tmax estival.
.eobs_summer_dates <- function(year) {
  seq(as.Date(sprintf("%d-06-01", year)),
      as.Date(sprintf("%d-08-31", year)), by = "day")
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

# Validation croisée LOO -> métadonnée de confiance (R² global + MAE Tmin/Tmax).
# Coûteuse : n'est calculée que si demandée (cv = TRUE). NULL si indisponible.
.meteoland_cv_stats <- function(interp) {
  cvv <- tryCatch(
    meteoland::interpolation_cross_validation(interp, verbose = FALSE),
    error = function(e) NULL)
  if (is.null(cvv)) return(NULL)
  ss <- cvv$station_stats
  mae <- function(col) {
    if (is.null(ss) || !col %in% names(ss)) return(NA_real_)
    mean(ss[[col]], na.rm = TRUE)
  }
  # cvv$r2 est un vecteur (R² par variable) : on le réduit à UN scalaire global
  # (moyenne des valeurs finies) pour ne pas laisser fuiter un vecteur dans meta.
  r2 <- suppressWarnings(mean(as.numeric(unlist(cvv$r2)), na.rm = TRUE))
  list(r2 = if (is.finite(r2)) r2 else NA_real_,
       mae_tmin = mae("MinTemperature_station_mae"),
       mae_tmax = mae("MaxTemperature_station_mae"))
}

# Interpole une variable meteoland sur la grille, année par année, et agrège
# chaque été en UNE couche annuelle (terra). Retourne une pile (une couche/an).
.meteoland_annual_stack <- function(interp, grid, years, variable, fun) {
  layers <- lapply(years, function(y) {
    d <- meteoland::interpolate_data(
      grid, interp, dates = .eobs_summer_dates(y),
      ignore_convex_hull_check = TRUE, verbose = FALSE)
    s <- meteoland::summarise_interpolated_data(
      d, fun = fun, frequency = "year",
      vars_to_summary = variable, verbose = FALSE)
    terra::rast(s)
  })
  stk <- terra::rast(layers)
  terra::time(stk) <- as.Date(sprintf("%d-07-01", years))
  stk
}

.eobs_ds_run_meteoland <- function(var, eobs, dem, aoi, buffer_m, resolution,
                                   covariates, statistic, years, max_cells,
                                   cache_path, min_stations = 5L,
                                   calibrate = FALSE, cv = FALSE, ...) {
  if (!requireNamespace("meteoland", quietly = TRUE) ||
      !requireNamespace("stars", quietly = TRUE)) {
    return(NULL)
  }
  yrs <- sort(unique(as.integer(.eobs_ds_years(eobs, years))))

  tryCatch({
    dem_n <- .normalize_crs(dem)
    aoi_buf <- .eobs_aoi_buffer(aoi, buffer_m, sf::st_crs(dem_n))
    # Stations sur un buffer élargi (l'enveloppe des mailles doit couvrir la
    # grille cible : sinon extrapolation en bordure). SAFRAN dense à 8 km.
    stations <- build_safran_stations(aoi, buffer_m + 8000, yrs, dem_n)
    if (is.null(stations) || nrow(stations$points) < min_stations) {
      cli::cli_warn(c(
        "eobs_downscale(engine = \"meteoland\"): too few SAFRAN pseudo-stations; falling back to KED.",
        i = "Widen {.arg buffer_m} or check the GéoSAS SAFRAN service."))
      return(NULL)
    }
    meteo <- .meteoland_meteo_sf(stations)
    if (is.null(meteo) || !nrow(meteo)) return(NULL)

    interp <- .meteoland_build_interpolator(meteo, calibrate = calibrate,
                                            variable = "MaxTemperature")
    grid <- .eobs_ds_stars_grid(dem_n, aoi_buf, max_cells)
    # var = "tx" -> Tmax estival (max journalier agrégé à l'année).
    stk <- .meteoland_annual_stack(interp, grid, yrs, "MaxTemperature", "max")

    # Même sémantique de réduction que KED. "value" sur pile multi-années -> moyenne.
    reduce_as <- if (identical(statistic, "value")) "mean" else statistic
    stat_r <- .eobs_ds_reduce(stk, reduce_as, yrs)

    unit <- switch(statistic, trend = "°C/decade", "°C")
    value_label <- switch(statistic,
                          trend = "Tendance T°max estivale",
                          mean  = "T°max estivale moyenne",
                          "T°max estivale")
    pred <- terra::mask(stat_r, terra::vect(aoi_buf))
    names(pred) <- var
    terra::units(pred) <- unit

    if (!is.null(cache_path)) {
      tryCatch(terra::writeRaster(pred, cache_path, overwrite = TRUE),
               error = function(e) cli::cli_warn("eobs_downscale(): cache not written."))
    }

    crs_code <- suppressWarnings(terra::crs(pred, describe = TRUE)$code)
    qs <- suppressWarnings(stats::quantile(
      terra::values(pred), c(0.02, 0.98), na.rm = TRUE, names = FALSE))
    cv_stats <- if (isTRUE(cv)) .meteoland_cv_stats(interp) else NULL

    list(raster = pred, meta = list(
      status = "ok", engine = "meteoland", method = "meteoland", var = var,
      statistic = statistic, crs = crs_code, unit = unit,
      value_label = value_label,
      palette = list(low = qs[1], high = qs[2], sense = "hot_unfavorable"),
      n_points = nrow(stations$points), cv = cv_stats))
  }, error = function(e) {
    cli::cli_warn(c(
      "eobs_downscale(engine = \"meteoland\"): interpolation failed ({conditionMessage(e)}); falling back to KED."))
    NULL
  })
}


#' Downscale a daily meteoland variable to a fine raster stack
#'
#' @description
#' Interpolate a **daily** meteorological variable (e.g. daily minimum
#' temperature) from SAFRAN pseudo-stations onto the DEM grid with
#' \pkg{meteoland} (Thornton 1997 + elevation), returning a `SpatRaster` with one
#' layer per day and `terra::time()` set. This is the real-data feeder for
#' [indicateur_r7_gel()] (late-frost risk needs a daily Tmin series) and for any
#' downstream daily-climate use; the reduced-statistic context map goes through
#' [eobs_downscale()] instead.
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
#' @seealso [eobs_downscale()], [indicateur_r7_gel()], [build_safran_stations()]
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
    dem_n <- .normalize_crs(dem)
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

# Cœur KED : réduction E-OBS -> lm(dérive) -> krigeage des résidus (gstat).
# Retourne list(raster, meta) ; jamais appelé pour var = "rr".
.eobs_ds_run_ked <- function(var, eobs, dem, aoi, buffer_m, resolution,
                             covariates, statistic, variogram_model, years,
                             max_cells, min_points, cache_path) {
  unit <- switch(statistic, trend = "°C/decade", "°C")
  value_label <- switch(statistic,
                        trend = "Tendance T°max estivale",
                        mean  = "T°max estivale moyenne",
                        "T°max estivale")

  # --- Grille cible : DEM recadré sur AOI+buffer, borné en cellules. ---
  dem <- .normalize_crs(dem)
  aoi_buf <- .eobs_aoi_buffer(aoi, buffer_m, sf::st_crs(dem))
  box <- terra::vect(aoi_buf)
  dem <- terra::crop(dem, box, snap = "out")
  if (!is.null(resolution)) {
    dem <- terra::aggregate(dem, fact = max(1L, round(resolution / mean(terra::res(dem)))),
                            fun = "mean", na.rm = TRUE)
  }
  fac <- .eobs_ds_agg_factor(dem, max_cells)
  if (fac > 1L) dem <- terra::aggregate(dem, fact = fac, fun = "mean", na.rm = TRUE)

  # --- E-OBS -> statistique par maille -> points (dans le CRS du DEM). ---
  stat_r <- .eobs_ds_reduce(eobs, statistic, years)
  names(stat_r) <- "value"
  df <- terra::as.data.frame(stat_r, xy = TRUE, na.rm = TRUE)
  if (!nrow(df)) {
    return(list(raster = NULL, meta = list(
      status = "insufficient_data", engine = "ked", var = var, method = NA_character_,
      n_points = 0L, reason = "eobs_downscale_no_cell")))
  }
  pts <- sf::st_as_sf(df, coords = c("x", "y"), crs = terra::crs(eobs))
  pts <- sf::st_transform(pts, sf::st_crs(dem))
  pts <- pts[lengths(sf::st_intersects(pts, aoi_buf)) > 0, , drop = FALSE]

  # --- Covariables terrain + extraction aux points. ---
  covar <- .eobs_ds_covariates(dem, covariates)
  ex <- terra::extract(covar, terra::vect(pts), ID = FALSE)
  dat <- cbind(value = pts$value, ex)
  dat <- dat[stats::complete.cases(dat), , drop = FALSE]
  n <- nrow(dat)

  crs_code <- suppressWarnings(terra::crs(dem, describe = TRUE)$code)

  # Trop peu de points pour une régression -> échec propre.
  if (n < 3L) {
    return(list(raster = NULL, meta = list(
      status = "insufficient_data", engine = "ked", var = var, method = NA_character_,
      n_points = n, crs = crs_code, reason = "eobs_downscale_too_few_cells")))
  }

  # --- Dérive : lm(value ~ covariables) puis prédiction sur la grille. ---
  terms <- setdiff(names(covar), character(0))
  form <- stats::as.formula(paste("value ~", paste(terms, collapse = " + ")))
  fit_lm <- stats::lm(form, data = as.data.frame(dat))
  drift <- terra::predict(covar, fit_lm, na.rm = TRUE)
  names(drift) <- "value"

  method <- "trend_only"
  pred <- drift

  # --- Krigeage des résidus si gstat + assez de points. ---
  if (n >= min_points) {
    pts_fit <- sf::st_as_sf(
      data.frame(residual = stats::residuals(fit_lm),
                 sf::st_coordinates(pts[stats::complete.cases(cbind(pts$value, ex)), ])),
      coords = c("X", "Y"), crs = sf::st_crs(dem))
    resid_r <- .eobs_ds_krige_residuals(pts_fit, drift, variogram_model)
    if (!is.null(resid_r)) {
      # resid_r est krigé SUR la grille de `drift` (copie du template) : pas de
      # resample nécessaire. On n'y recourt que si les géométries divergent —
      # un resample same-grid déclenche un warp GDAL qui échoue sur certains
      # builds terra (runner CI coverage).
      if (!terra::compareGeom(resid_r, drift, stopOnError = FALSE)) {
        resid_r <- terra::resample(resid_r, drift, method = "bilinear")
      }
      pred <- drift + resid_r
      names(pred) <- "value"
      method <- "ked"
    }
  }

  # --- Masque au buffer, cache optionnel, méta (contrat de sortie). ---
  pred <- terra::mask(pred, terra::vect(aoi_buf))
  names(pred) <- var
  terra::units(pred) <- unit

  if (!is.null(cache_path)) {
    tryCatch(terra::writeRaster(pred, cache_path, overwrite = TRUE),
             error = function(e) cli::cli_warn("eobs_downscale(): cache not written."))
  }

  qs <- suppressWarnings(stats::quantile(
    terra::values(pred), c(0.02, 0.98), na.rm = TRUE, names = FALSE))
  list(raster = pred, meta = list(
    status = "ok", engine = "ked", method = method, var = var,
    statistic = statistic, crs = crs_code, unit = unit,
    value_label = value_label,
    palette = list(low = qs[1], high = qs[2], sense = "hot_unfavorable"),
    n_points = n, cv = NULL))   # cv : validation croisée (moteur meteoland, P4)
}


#' Downscale an E-OBS variable to a fine raster
#'
#' @description
#' Turn the coarse E-OBS grid (~0.1°, ~11 km) into a fine continuous
#' `SpatRaster` over the project's regional context, using the DEM (and terrain
#' covariates) as external drift. Built for the "regional context" map of the
#' reGénération tab — **not** stand-scale precision, which [microclimate_run()]
#' already produces from microclimf + HD LiDAR.
#'
#' **v1 covers `tx` (maximum temperature) only** — a physically justified
#' altitudinal signal (~ -0.6 °C / 100 m). `rr` (precipitation) is out of scope
#' (unreliable downscaling; the DEM only helps in mountains). `var = "rr"`
#' returns a status, not a raster.
#'
#' **Two engines, one contract** (microclimat brief §8):
#' * `engine = "ked"` (default) — regression-kriging: reduce E-OBS to one value
#'   per cell (the target `statistic`), fit the drift
#'   `value ~ dem [+ slope + northness + twi]`, krige the residuals (variogram
#'   auto-fit via \pkg{automap} when present, else a spherical \pkg{gstat}
#'   model), sum drift + kriged residuals on the DEM grid. Without \pkg{gstat},
#'   or with too few E-OBS cells, it **degrades to trend-only** (drift surface) —
#'   a documented fallback, never an error.
#' * `engine = "meteoland"` — the station-based interpolator (\pkg{meteoland},
#'   Thornton 1997 + elevation, microclimat brief Option A / chantier P4). It
#'   interpolates the **daily** SAFRAN pseudo-station series (from
#'   [build_safran_stations()]) onto the DEM grid, aggregates each summer to an
#'   annual max, then reduces to the requested `statistic` — same output contract
#'   as KED, plus a `meta$cv` cross-validation block. Whenever \pkg{meteoland} is
#'   absent, GéoSAS is down, or too few pseudo-stations resolve, it **falls back
#'   to KED**, so the caller never branches on the engine. For a **daily** raster
#'   stack (e.g. the Tmin series feeding [indicateur_r7_gel()]), use
#'   [meteoland_daily_grid()] instead of a reduced statistic.
#'
#' Both engines return the same `list(raster, meta)` shape; the app renders
#' against `meta` regardless of engine.
#'
#' @param var `"tx"` (v1). `"rr"` returns an out-of-scope status.
#' @param eobs A `SpatRaster` of E-OBS: one layer per year (for
#'   `statistic = "trend"`/`"mean"`) or a single reduced layer
#'   (`statistic = "value"`).
#' @param dem A `SpatRaster` DEM — the downscaling target grid and main
#'   covariate. The output shares its CRS.
#' @param aoi An `sf`/`sfc` of the management units, buffered to frame the
#'   regional context.
#' @param engine `"ked"` (default, regression-kriging) or `"meteoland"`
#'   (station interpolator; falls back to KED when unavailable).
#' @param buffer_m Context buffer around the AOI, in metres (default 25000).
#' @param resolution Optional target resolution (DEM units). `NULL` keeps the
#'   DEM resolution (aggregated if the grid would exceed `max_cells`).
#' @param covariates Terrain covariates among `"dem"`, `"slope"`, `"aspect"`
#'   (entered as northness), `"twi"` (best-effort). Default all four.
#' @param statistic What to downscale: `"trend"` (per-decade OLS slope over the
#'   E-OBS years), `"mean"`, or `"value"` (a pre-reduced single layer).
#' @param variogram_model Optional `gstat::vgm()` model; `NULL` auto-fits.
#' @param years Optional numeric years matching the E-OBS layers (else taken
#'   from `terra::time()`, else the layer index).
#' @param max_cells Cell cap for the target grid (default `5e5`); the DEM is
#'   aggregated above it, so the output is never a gigapixel raster.
#' @param min_points Minimum E-OBS cells within the buffer to attempt kriging
#'   (default 10); below it, trend-only.
#' @param cache_path Optional `.tif` path; when given, the result raster is
#'   written there for instant reload (pattern of `pai.tif`).
#' @param calibrate `engine = "meteoland"` only: run the (expensive) meteoland
#'   LOO calibration before interpolating (default `FALSE`, default params).
#' @param cv `engine = "meteoland"` only: compute leave-one-out cross-validation
#'   and return it in `meta$cv` (`r2`, `mae_tmin`, `mae_tmax`); default `FALSE`
#'   (expensive). KED always reports `meta$cv = NULL`.
#' @param ... Ignored (forward-compat).
#'
#' @return A list `list(raster, meta)`. `raster` is a single-layer `SpatRaster`
#'   in the DEM CRS, or `NULL` when degraded to nothing. `meta` carries the
#'   **output contract** the app renders against: `status`
#'   (`"ok"`/`"out_of_scope"`/`"insufficient_data"`), `engine` (the engine that
#'   actually ran), `method` (`"ked"`/`"trend_only"`), `var`, `statistic`,
#'   `crs` (EPSG code), `unit` (e.g. `"°C/decade"`), `value_label`, `palette`
#'   (`low`/`high` quantile bounds and `sense = "hot_unfavorable"` — high =
#'   warmer = red, per the app's red-is-critical rule), `n_points`, and, when
#'   degraded, `reason` (i18n key).
#' @references E-OBS: Cornes et al. (2018). Regression-kriging: Hengl et al.
#'   (2007). meteoland: De Cáceres et al. (2018).
#' @seealso [tendances_estivales_eobs()], [microclimate_run()]
#' @export
eobs_downscale <- function(var = c("tx", "rr"), eobs, dem, aoi,
                           engine = c("ked", "meteoland"),
                           buffer_m = 25000, resolution = NULL,
                           covariates = c("dem", "slope", "aspect", "twi"),
                           statistic = c("trend", "mean", "value"),
                           variogram_model = NULL, years = NULL,
                           max_cells = 5e5, min_points = 10L,
                           cache_path = NULL, calibrate = FALSE, cv = FALSE,
                           ...) {
  var <- match.arg(var)
  engine <- match.arg(engine)
  statistic <- match.arg(statistic)

  if (identical(var, "rr")) {
    return(list(raster = NULL, meta = list(
      status = "out_of_scope", var = "rr", engine = engine,
      method = NA_character_, reason = "eobs_downscale_rr_out_of_scope")))
  }
  if (!inherits(eobs, "SpatRaster")) {
    cli::cli_abort("{.arg eobs} must be a {.cls SpatRaster}.")
  }
  if (!inherits(dem, "SpatRaster")) {
    cli::cli_abort("{.arg dem} must be a {.cls SpatRaster}.")
  }
  if (!inherits(aoi, c("sf", "sfc"))) {
    cli::cli_abort("{.arg aoi} must be an {.cls sf} or {.cls sfc}.")
  }
  covariates <- intersect(covariates, c("dem", "slope", "aspect", "twi"))
  if (!length(covariates)) covariates <- "dem"

  # engine = "meteoland" : tenté, mais retombe sur KED tant que le rail P4 n'est
  # pas livré / que meteoland est absent (contrat de sortie inchangé).
  if (identical(engine, "meteoland")) {
    out <- .eobs_ds_run_meteoland(
      var = var, eobs = eobs, dem = dem, aoi = aoi, buffer_m = buffer_m,
      resolution = resolution, covariates = covariates, statistic = statistic,
      years = years, max_cells = max_cells, cache_path = cache_path,
      calibrate = calibrate, cv = cv)
    if (!is.null(out)) return(out)
    # repli KED, en gardant trace du moteur demandé.
    out <- .eobs_ds_run_ked(var, eobs, dem, aoi, buffer_m, resolution,
                            covariates, statistic, variogram_model, years,
                            max_cells, min_points, cache_path)
    out$meta$engine_requested <- "meteoland"
    out$meta$engine_fallback <- TRUE
    return(out)
  }

  .eobs_ds_run_ked(var, eobs, dem, aoi, buffer_m, resolution, covariates,
                   statistic, variogram_model, years, max_cells, min_points,
                   cache_path)
}
