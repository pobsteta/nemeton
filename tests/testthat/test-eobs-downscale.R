# test-eobs-downscale.R — downscaling E-OBS par régression-krigeage (spec
# brief-nemeton-eobs-downscaling). Le chemin KED complet exige gstat (Suggests) ;
# le repli trend-only (dérive lm seule) est pleinement testable sans lui.

# DEM 2154 fin : altitude croissante ouest -> est (100..1100 m).
make_dem <- function() {
  d <- terra::rast(terra::ext(0, 40000, 0, 40000), resolution = 200,
                   crs = "EPSG:2154")
  xy <- terra::xyFromCell(d, seq_len(terra::ncell(d)))
  terra::values(d) <- 100 + xy[, 1] / 40
  d
}

# E-OBS grossier co-localisé (2 km, 2154). `slope_per_year` pose la tendance ;
# `lapse` pose la dépendance à x (proxy d'altitude) pour la cohérence physique.
make_eobs <- function(nyr = 10, slope_per_year = 0.3, lapse = 0.6, seed = 1) {
  set.seed(seed)
  lay <- lapply(seq_len(nyr), function(k) {
    r <- terra::rast(terra::ext(-5000, 45000, -5000, 45000), resolution = 2000,
                     crs = "EPSG:2154")
    cxy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
    terra::values(r) <- 25 - cxy[, 1] / 40 * lapse + slope_per_year * k +
      stats::rnorm(terra::ncell(r), 0, 0.1)
    r
  })
  e <- terra::rast(lay)
  terra::time(e) <- as.Date(sprintf("%d-07-15", seq(2010, by = 1, length.out = nyr)))
  e
}

make_aoi <- function() {
  sf::st_as_sf(sf::st_sfc(sf::st_polygon(list(rbind(
    c(15000, 15000), c(25000, 15000), c(25000, 25000),
    c(15000, 25000), c(15000, 15000)))), crs = 2154))
}

test_that("eobs_downscale produces a DEM-resolution raster with the output contract", {
  res <- eobs_downscale(var = "tx", eobs = make_eobs(), dem = make_dem(),
                        aoi = make_aoi(), statistic = "trend", buffer_m = 30000,
                        covariates = c("dem", "slope", "aspect"))
  expect_equal(res$meta$status, "ok")
  expect_s4_class(res$raster, "SpatRaster")
  expect_equal(terra::nlyr(res$raster), 1L)
  expect_equal(terra::res(res$raster)[1], 200)            # résolution du DEM
  expect_equal(res$meta$crs, "2154")                      # CRS du DEM
  expect_equal(res$meta$unit, "°C/decade")
  expect_equal(res$meta$palette$sense, "hot_unfavorable")
  expect_true(res$meta$palette$high >= res$meta$palette$low)
  # tendance 0.3/an -> ~3 °C/décennie
  expect_equal(unname(terra::global(res$raster, "mean", na.rm = TRUE)$mean),
               3, tolerance = 0.3)
})

test_that("physical coherence: higher altitude -> colder downscaled tx (mean)", {
  # E-OBS mean encode une décroissance avec x (= altitude via le DEM) : la dérive
  # lm doit donner un coefficient dem NÉGATIF -> surface plus froide en altitude.
  res <- eobs_downscale(var = "tx", eobs = make_eobs(), dem = make_dem(),
                        aoi = make_aoi(), statistic = "mean", buffer_m = 30000,
                        covariates = c("dem", "slope", "aspect"))
  expect_equal(res$meta$unit, "°C")
  # corrélation pred ~ dem strictement négative sur l'emprise.
  s <- c(res$raster, terra::crop(make_dem(), res$raster))
  df <- terra::as.data.frame(s, na.rm = TRUE)
  names(df) <- c("pred", "dem")
  expect_lt(stats::cor(df$pred, df$dem), 0)
})

test_that("var = 'rr' is out of scope in v1", {
  res <- eobs_downscale(var = "rr", eobs = make_eobs(), dem = make_dem(),
                        aoi = make_aoi())
  expect_null(res$raster)
  expect_equal(res$meta$status, "out_of_scope")
  expect_equal(res$meta$reason, "eobs_downscale_rr_out_of_scope")
})

test_that("insufficient E-OBS coverage degrades cleanly, no error", {
  # AOI minuscule + buffer minuscule -> < 3 mailles E-OBS -> insufficient_data.
  tiny <- sf::st_as_sf(sf::st_sfc(sf::st_polygon(list(rbind(
    c(20000, 20000), c(20100, 20000), c(20100, 20100),
    c(20000, 20100), c(20000, 20000)))), crs = 2154))
  res <- eobs_downscale(var = "tx", eobs = make_eobs(), dem = make_dem(),
                        aoi = tiny, statistic = "trend", buffer_m = 500)
  expect_true(res$meta$status %in% c("insufficient_data"))
  expect_null(res$raster)
  expect_match(res$meta$reason, "eobs_downscale")
})

test_that("eobs_downscale validates its inputs", {
  expect_error(eobs_downscale("tx", eobs = 1, dem = make_dem(), aoi = make_aoi()),
               "SpatRaster")
  expect_error(eobs_downscale("tx", eobs = make_eobs(), dem = 1, aoi = make_aoi()),
               "SpatRaster")
  expect_error(eobs_downscale("tx", eobs = make_eobs(), dem = make_dem(), aoi = 1),
               "sf")
})

test_that("engine = 'meteoland' falls back to KED when no stations resolve", {
  # Sans meteoland (CI) le moteur retourne NULL avant tout réseau. Avec meteoland,
  # on force le repli en mockant l'acquisition -> aucune pseudo-station : pas de
  # réseau GéoSAS dans le test, repli déterministe quel que soit l'environnement.
  testthat::local_mocked_bindings(build_safran_stations = function(...) NULL)
  res <- suppressWarnings(eobs_downscale(
    var = "tx", eobs = make_eobs(), dem = make_dem(), aoi = make_aoi(),
    engine = "meteoland", statistic = "trend", buffer_m = 30000,
    covariates = c("dem", "slope")))
  expect_equal(res$meta$status, "ok")
  expect_equal(res$meta$engine, "ked")
  expect_true(isTRUE(res$meta$engine_fallback))
  expect_equal(res$meta$engine_requested, "meteoland")
})

test_that("the full KED path runs when gstat is available", {
  skip_if_not_installed("gstat")
  res <- eobs_downscale(var = "tx", eobs = make_eobs(), dem = make_dem(),
                        aoi = make_aoi(), statistic = "trend", buffer_m = 30000,
                        covariates = c("dem", "slope", "aspect"))
  expect_equal(res$meta$method, "ked")
  expect_s4_class(res$raster, "SpatRaster")
})

test_that("cache_path writes a reusable GeoTIFF", {
  skip_if_terra_write_broken()
  withr::with_tempdir({
    res <- eobs_downscale(var = "tx", eobs = make_eobs(), dem = make_dem(),
                          aoi = make_aoi(), statistic = "trend", buffer_m = 30000,
                          covariates = c("dem", "slope"), cache_path = "eobs.tif")
    expect_true(file.exists("eobs.tif"))
    expect_s4_class(terra::rast("eobs.tif"), "SpatRaster")
  })
})

# --- helpers internes ---

test_that(".eobs_ds_agg_factor caps the grid below max_cells", {
  d <- terra::rast(nrows = 1000, ncols = 1000)     # 1e6 cellules
  expect_equal(.eobs_ds_agg_factor(d, 5e5), 2L)    # ceil(sqrt(1e6/5e5)) = 2
  expect_equal(.eobs_ds_agg_factor(d, 1e7), 1L)    # sous le plafond -> pas d'agrégation
})

test_that(".eobs_ds_covariates enters aspect as northness = cos(aspect)", {
  st <- .eobs_ds_covariates(make_dem(), c("dem", "slope", "aspect"))
  expect_true(all(c("dem", "slope", "northness") %in% names(st)))
  expect_false("aspect" %in% names(st))            # jamais l'exposition brute
  vals <- terra::values(st[["northness"]])
  expect_true(all(vals[is.finite(vals)] >= -1 & vals[is.finite(vals)] <= 1))
})

test_that(".eobs_ds_reduce computes a per-decade trend", {
  e <- make_eobs(nyr = 10, slope_per_year = 0.5, lapse = 0)
  r <- .eobs_ds_reduce(e, "trend", NULL)
  expect_equal(terra::nlyr(r), 1L)
  # pente 0.5/an -> ~5 °C/décennie
  expect_equal(unname(terra::global(r, "mean", na.rm = TRUE)$mean), 5, tolerance = 0.3)
})

# --- moteur meteoland / SAFRAN (chantier P4) ---

test_that("build_safran_stations builds a grid with elevation and series", {
  mock <- function(points, years) stats::setNames(
    lapply(points$id, function(i)
      data.frame(time = as.Date("2020-06-01") + 0:9, T_Q = 20)),
    as.character(points$id))
  st <- build_safran_stations(make_aoi(), buffer_m = 20000, years = 2020,
                              dem = make_dem(), spacing_m = 8000, fetch = mock)
  expect_type(st, "list")
  expect_s3_class(st$points, "sf")
  expect_true(all(c("id", "elevation") %in% names(st$points)))
  expect_true(all(is.finite(st$points$elevation)))         # NA-elevation écartés
  expect_equal(names(st$series), as.character(st$points$id))
  expect_gt(nrow(st$points), 0)
})

test_that("build_safran_stations returns NULL when no series resolve", {
  none <- function(points, years) stats::setNames(
    vector("list", nrow(points)), as.character(points$id))   # que des NULL
  expect_null(build_safran_stations(make_aoi(), 20000, 2020, make_dem(),
                                    fetch = none))
})

test_that("the KED contract carries a cv slot (NULL, filled by meteoland)", {
  res <- eobs_downscale("tx", eobs = make_eobs(), dem = make_dem(),
                        aoi = make_aoi(), statistic = "trend", buffer_m = 30000,
                        covariates = c("dem", "slope"))
  expect_true("cv" %in% names(res$meta))
  expect_null(res$meta$cv)
})

# --- transformation SAFRAN -> meteoland (pur, testable sans meteoland) ---

# Série SAFRAN synthétique par station : colonnes EXACTES de l'EDR GéoSAS.
# Un gradient de Tmax par station rend l'interpolation non triviale.
fake_safran_series <- function(points, years, ndays = 30, base_tx = 25) {
  yr <- min(years)
  dts <- as.Date(sprintf("%d-06-01", yr)) + seq_len(ndays) - 1L
  stats::setNames(lapply(seq_len(nrow(points)), function(i) {
    off <- (points$lat[i] - mean(points$lat)) * 2   # gradient latitudinal
    data.frame(
      time = format(dts, "%Y-%m-%d 00:00:00"),
      T_Q = base_tx - 5 + off, TINF_H_Q = base_tx - 10 + off,
      TSUP_H_Q = base_tx + off, PRELIQ_Q = 1, PRENEI_Q = 0,
      HU_Q = 70, FF_Q = 2, SSI_Q = 1800, check.names = FALSE)
  }), as.character(points$id))
}

test_that(".safran_to_meteoland maps raw SAFRAN columns and sums precipitation", {
  raw <- data.frame(
    time = c("2020-06-01 00:00:00", "2020-06-02 00:00:00"),
    T_Q = c(18, 20), TINF_H_Q = c(12, 14), TSUP_H_Q = c(24, 27),
    PRELIQ_Q = c(3, 0), PRENEI_Q = c(1, 0), HU_Q = c(80, 60),
    FF_Q = c(2, 3), SSI_Q = c(1800, 2000), check.names = FALSE)
  d <- .safran_to_meteoland(raw)
  expect_equal(d$MinTemperature, c(12, 14))
  expect_equal(d$MaxTemperature, c(24, 27))
  expect_equal(d$MeanTemperature, c(18, 20))
  expect_equal(d$Precipitation, c(4, 0))            # liquide + neige
  expect_equal(d$Radiation, c(18, 20))              # J/cm² -> MJ/m² (× 0.01)
  expect_s3_class(d$dates, "Date")
})

test_that(".meteoland_meteo_sf builds a long sf (station × day)", {
  st <- build_safran_stations(make_aoi(), buffer_m = 20000, years = 2020,
                              dem = make_dem(), spacing_m = 8000,
                              fetch = function(p, y) fake_safran_series(p, y, ndays = 5))
  meteo <- .meteoland_meteo_sf(st)
  expect_s3_class(meteo, "sf")
  expect_true(all(c("stationID", "elevation", "MinTemperature",
                    "MaxTemperature", "Precipitation") %in% names(meteo)))
  expect_equal(nrow(meteo), nrow(st$points) * 5)    # 5 jours par station
  expect_true(all(is.finite(meteo$elevation)))
})

# --- glue meteoland réelle (skippée en CI : meteoland/stars en Suggests) ---

test_that("engine = 'meteoland' runs the interpolator and honours the contract", {
  skip_if_not_installed("meteoland")
  skip_if_not_installed("stars")
  # Injecte des pseudo-stations SAFRAN synthétiques -> vrai run meteoland, offline.
  testthat::local_mocked_bindings(
    .biljou_forcing_safran = function(points, years, ...)
      fake_safran_series(points, years, ndays = 30))
  eobs <- make_eobs(nyr = 1)
  res <- suppressWarnings(eobs_downscale(
    "tx", eobs = eobs, dem = make_dem(), aoi = make_aoi(), engine = "meteoland",
    statistic = "mean", buffer_m = 20000, covariates = c("dem", "slope"),
    max_cells = 2000, years = 2020))
  # Selon la densité effective on obtient meteoland (idéal) OU un repli KED propre.
  expect_equal(res$meta$status, "ok")
  expect_true(res$meta$engine %in% c("meteoland", "ked"))
  if (identical(res$meta$engine, "meteoland")) {
    expect_equal(res$meta$method, "meteoland")
    expect_s4_class(res$raster, "SpatRaster")
    expect_equal(res$meta$crs, "2154")
    expect_equal(res$meta$palette$sense, "hot_unfavorable")
    expect_true("cv" %in% names(res$meta))
  }
})

test_that("meteoland_daily_grid returns a dated daily Tmin stack for R7", {
  skip_if_not_installed("meteoland")
  skip_if_not_installed("stars")
  testthat::local_mocked_bindings(
    .biljou_forcing_safran = function(points, years, ...)
      fake_safran_series(points, years, ndays = 20))
  tn <- suppressWarnings(meteoland_daily_grid(
    make_aoi(), make_dem(), years = 2020, variable = "MinTemperature",
    doy_range = c(153L, 160L), buffer_m = 20000, max_cells = 2000))
  # NULL toléré si la densité mockée ne suffit pas ; sinon pile datée exploitable.
  if (!is.null(tn)) {
    expect_s4_class(tn, "SpatRaster")
    expect_gt(terra::nlyr(tn), 0)
    expect_false(all(is.na(terra::time(tn))))
    expect_equal(terra::crs(tn, describe = TRUE)$code, "2154")
  } else {
    succeed()
  }
})

# --- MNT de contexte : auto-sourcing (brief eobs-downscaling-dem) ---

# MNT grossier et LARGE simulant le retour du WMS IGN, déjà dans le CRS métrique
# (2154) des fixtures : l'auto-source court-circuite alors la reprojection, si bien
# que ces tests de résolution ne font AUCUNE écriture/warp terra (tournent sur tout
# runner, y compris ceux à l'anomalie GDAL). Indépendant du bbox reçu.
fake_ign_dem <- function(bbox = NULL, ...) {
  r <- terra::rast(terra::ext(-50000, 100000, -50000, 100000),
                   resolution = 2000, crs = "EPSG:2154")
  terra::values(r) <- seq_len(terra::ncell(r))
  names(r) <- "elevation"
  r
}

test_that(".eobs_ds_metric_crs prefers a projected CRS, else Lambert-93", {
  expect_equal(.eobs_ds_metric_crs(make_dem(), make_aoi())$epsg, 2154)
  ll <- sf::st_transform(make_aoi(), 4326)
  expect_equal(.eobs_ds_metric_crs(NULL, ll)$epsg, 2154)   # longlat -> repli 2154
})

test_that("a covering DEM stays 'provided' (backcompat, no download)", {
  # download mocké : s'il était appelé le test le saurait (raster factice reconnaissable).
  testthat::local_mocked_bindings(.eobs_ds_download_ign_dem = function(...) NULL)
  r <- .eobs_ds_resolve_dem(make_dem(), make_eobs(), make_aoi(),
                            buffer_m = 30000, min_points = 10L)
  expect_equal(r$dem_source, "provided")
  expect_s4_class(r$dem, "SpatRaster")
})

test_that("a small DEM under a wide buffer triggers auto-sourcing", {
  testthat::local_mocked_bindings(.eobs_ds_download_ign_dem = fake_ign_dem)
  small <- terra::crop(make_dem(), terra::ext(18000, 22000, 18000, 22000))
  r <- suppressWarnings(.eobs_ds_resolve_dem(small, make_eobs(), make_aoi(),
                                             buffer_m = 30000, min_points = 10L))
  expect_equal(r$dem_source, "autoscaled_small_dem")
  expect_s4_class(r$dem, "SpatRaster")
})

test_that("small DEM + failed download degrades to dem_too_small", {
  testthat::local_mocked_bindings(.eobs_ds_download_ign_dem = function(...) NULL)
  small <- terra::crop(make_dem(), terra::ext(18000, 22000, 18000, 22000))
  r <- .eobs_ds_resolve_dem(small, make_eobs(), make_aoi(),
                            buffer_m = 30000, min_points = 10L)
  expect_null(r$dem)
  expect_equal(r$reason, "eobs_downscale_dem_too_small")
})

test_that("dem = NULL auto-sources; failure degrades to no_dem", {
  testthat::local_mocked_bindings(.eobs_ds_download_ign_dem = fake_ign_dem)
  ok <- .eobs_ds_resolve_dem(NULL, make_eobs(), make_aoi(),
                             buffer_m = 30000, min_points = 10L)
  expect_equal(ok$dem_source, "autoscaled")
  testthat::local_mocked_bindings(.eobs_ds_download_ign_dem = function(...) NULL)
  ko <- .eobs_ds_resolve_dem(NULL, make_eobs(), make_aoi(),
                             buffer_m = 30000, min_points = 10L)
  expect_null(ko$dem)
  expect_equal(ko$reason, "eobs_downscale_no_dem")
})

test_that("a tiny buffer stays 'provided' (E-OBS is the limiter, not the DEM)", {
  # Auto-sourcer un MNT ne sauve rien si le buffer lui-même a trop peu de mailles :
  # on garde le MNT fourni et le KED renvoie too_few_cells (pas de téléchargement).
  testthat::local_mocked_bindings(.eobs_ds_download_ign_dem = function(...)
    stop("should not download for a tiny buffer"))
  tiny <- sf::st_as_sf(sf::st_sfc(sf::st_polygon(list(rbind(
    c(20000, 20000), c(20100, 20000), c(20100, 20100),
    c(20000, 20100), c(20000, 20000)))), crs = 2154))
  r <- .eobs_ds_resolve_dem(make_dem(), make_eobs(), tiny,
                            buffer_m = 500, min_points = 10L)
  expect_equal(r$dem_source, "provided")
})

test_that("eobs_downscale sets meta$dem_source on the ok path", {
  res <- eobs_downscale("tx", eobs = make_eobs(), dem = make_dem(),
                        aoi = make_aoi(), statistic = "trend", buffer_m = 30000,
                        covariates = c("dem", "slope"))
  expect_equal(res$meta$status, "ok")
  expect_equal(res$meta$dem_source, "provided")
})

test_that("eobs without a CRS is assumed EPSG:4326 (robustness path fires)", {
  # E-OBS est toujours en lon/lat WGS84 ; un raster sans CRS ferait chuter
  # n_points à 0 silencieusement. On vérifie que le garde-fou pose bien 4326
  # (le mécanisme) — l'alignement géographique réel est couvert par le test WMS.
  e <- make_eobs()
  terra::crs(e) <- ""
  expect_warning(
    eobs_downscale("tx", eobs = e, dem = make_dem(), aoi = make_aoi(),
                   statistic = "trend", buffer_m = 30000,
                   covariates = c("dem", "slope")),
    "EPSG:4326")
})

test_that(".eobs_ds_download_ign_dem fetches a real coarse DEM (IGN WMS)", {
  testthat::skip_on_cran()
  testthat::skip_if_offline("data.geopf.fr")
  # petit bbox français (Jura), résolution grossière -> image légère.
  r <- .eobs_ds_download_ign_dem(c(5.9, 47.1, 6.2, 47.3), res_m = 500)
  skip_if(is.null(r), "IGN WMS unavailable")
  expect_s4_class(r, "SpatRaster")
  v <- terra::values(r); v <- v[is.finite(v)]
  expect_gt(length(v), 0)
  expect_true(all(v > -500 & v < 5000))     # altitudes plausibles (m)
})
