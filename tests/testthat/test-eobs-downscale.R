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

test_that("engine = 'meteoland' currently falls back to KED (rail P4)", {
  # `.eobs_ds_run_meteoland()` returns NULL until the P4 station-based engine is
  # wired, so the fallback happens whether or not meteoland is installed.
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
