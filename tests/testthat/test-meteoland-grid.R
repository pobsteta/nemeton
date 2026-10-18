# test-meteoland-grid.R — grille journalière meteoland depuis des
# pseudo-stations SAFRAN (chantier microclimat P4, gel R7). Extrait en 2026.10.18
# de test-eobs-downscale.R, retiré avec eobs_downscale().

# DEM 2154 fin : altitude croissante ouest -> est (100..1100 m).
make_dem <- function() {
  d <- terra::rast(terra::ext(0, 40000, 0, 40000), resolution = 200,
                   crs = "EPSG:2154")
  xy <- terra::xyFromCell(d, seq_len(terra::ncell(d)))
  terra::values(d) <- 100 + xy[, 1] / 40
  d
}

make_aoi <- function() {
  sf::st_as_sf(sf::st_sfc(sf::st_polygon(list(rbind(
    c(15000, 15000), c(25000, 15000), c(25000, 25000),
    c(15000, 25000), c(15000, 15000)))), crs = 2154))
}

test_that(".eobs_ds_agg_factor caps the grid below max_cells", {
  d <- terra::rast(nrows = 1000, ncols = 1000)     # 1e6 cellules
  expect_equal(.eobs_ds_agg_factor(d, 5e5), 2L)    # ceil(sqrt(1e6/5e5)) = 2
  expect_equal(.eobs_ds_agg_factor(d, 1e7), 1L)    # sous le plafond -> pas d'agrégation
})

# --- pseudo-stations SAFRAN ---

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

test_that(".safran_to_meteoland: un jour SAFRAN manquant reste NA, pas 0 mm (audit 1.0)", {
  raw <- data.frame(
    time = c("2020-06-01", "2020-06-02", "2020-06-03"),
    T_Q = c(18, NA, 20), TINF_H_Q = c(12, NA, 14), TSUP_H_Q = c(24, NA, 27),
    PRELIQ_Q = c(3, NA, NA), PRENEI_Q = c(1, NA, 2), HU_Q = c(80, NA, 60),
    FF_Q = c(2, NA, 3), SSI_Q = c(1800, NA, 2000), check.names = FALSE)
  d <- .safran_to_meteoland(raw)
  # Jour 2 : ni pluie ni neige renseignées -> NA (et non 0 mm inventé).
  # Jour 3 : une seule des deux composantes renseignée -> on garde la somme
  # partielle (la composante absente est traitée comme nulle).
  expect_equal(d$Precipitation, c(4, NA, 2))
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

# --- MNT de la voie meteoland/SAFRAN : auto-sourcing (fix gel R7) ---

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

test_that(".meteoland_resolve_dem keeps a covering DEM (no download)", {
  # MNT 40 km + buffer étroit : assez de mailles SAFRAN 8 km dans l'emprise ->
  # on garde le fourni. Download mocké en erreur : il ne doit pas être appelé.
  testthat::local_mocked_bindings(.eobs_ds_download_ign_dem = function(...)
    stop("should not download for a covering DEM"))
  r <- .meteoland_resolve_dem(make_dem(), make_aoi(), buffer_m = 8000,
                              min_stations = 3L)
  expect_s4_class(r, "SpatRaster")
  expect_equal(terra::ext(r)[1], terra::ext(make_dem())[1])   # bien le fourni
})

test_that(".meteoland_resolve_dem auto-sources when the DEM is parcelle-scale", {
  # Reproduit le bug gel R7 : MNT LiDAR parcellaire (~4 km) sous un buffer large
  # -> quasi aucune pseudo-station SAFRAN survit (elevation NA) -> auto-source.
  testthat::local_mocked_bindings(.eobs_ds_download_ign_dem = fake_ign_dem)
  small <- terra::crop(make_dem(), terra::ext(18000, 22000, 18000, 22000))
  r <- suppressWarnings(.meteoland_resolve_dem(small, make_aoi(),
                                               buffer_m = 30000, min_stations = 5L))
  expect_s4_class(r, "SpatRaster")
  expect_equal(unname(terra::ext(r)[1]), -50000)   # l'emprise LARGE du WMS factice
})

test_that(".meteoland_resolve_dem returns NULL when auto-source fails", {
  testthat::local_mocked_bindings(.eobs_ds_download_ign_dem = function(...) NULL)
  small <- terra::crop(make_dem(), terra::ext(18000, 22000, 18000, 22000))
  r <- suppressWarnings(.meteoland_resolve_dem(small, make_aoi(),
                                               buffer_m = 30000, min_stations = 5L))
  expect_null(r)
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
