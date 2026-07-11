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


# Moteur meteoland (chantier microclimat, Option A). meteoland interpole depuis
# des STATIONS à séries journalières (Thornton 1997 + altitude + calibration LOO) :
# il ne consomme pas une tendance déjà réduite. Le brancher proprement sur ce
# downscaling-de-grille = interpoler année par année puis recalculer la tendance
# sur la grille fine (chantier P4 du brief microclimat). meteoland est en Suggests
# (GPL, compatible cœur GPL-3). NON testable en CI. Toute absence/erreur -> NULL,
# et l'appelant retombe sur KED : le moteur meteoland ne casse jamais la sortie.
.eobs_ds_run_meteoland <- function(...) {
  if (!requireNamespace("meteoland", quietly = TRUE)) return(NULL)
  # Rail ouvert pour le chantier microclimat P4 (interpolation station-based).
  # Le downscaling d'une tendance en grille n'entre pas dans le modèle de données
  # journalier de meteoland sans une refonte per-année ; livré séparément.
  cli::cli_warn(c(
    "eobs_downscale(engine = \"meteoland\"): not wired for gridded-statistic downscaling yet.",
    i = "meteoland is a station/daily-series interpolator (microclimat brief, chantier P4); falling back to KED."))
  NULL
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
    n_points = n))
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
#'   interpolates **daily station series**, so downscaling a pre-reduced trend
#'   needs a per-year restructuring that is delivered separately. Until then, and
#'   whenever \pkg{meteoland} is absent, this engine **falls back to KED** — the
#'   output contract is identical, so the caller never branches on the engine.
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
                           cache_path = NULL, ...) {
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
      years = years, max_cells = max_cells, cache_path = cache_path)
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
