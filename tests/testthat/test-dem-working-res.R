# Garde-fou de résolution du MNT de travail (.dem_working_res).
#
# Contexte : le 2026-08-06, le calcul des indicateurs du projet Dabo (NDP 1,
# MNT LiDAR HD 12000 x 10000 à 1 m) a fait monter la session R à 21,2 Go et
# systemd-oomd a tué le scope RStudio pendant R2. Les indicateurs dérivés du
# terrain ramènent désormais le MNT à ~10 m avant tout calcul.

skip_if_not_installed("terra")

make_dem <- function(res, crs = "EPSG:2154", nrow = 100, ncol = 100) {
  r <- terra::rast(
    nrows = nrow, ncols = ncol,
    xmin = 0, xmax = ncol * res, ymin = 0, ymax = nrow * res,
    crs = crs
  )
  terra::values(r) <- seq_len(terra::ncell(r))
  r
}

test_that(".dem_working_res aggregates a fine DEM to the target resolution", {
  dem <- make_dem(res = 1)
  out <- .dem_working_res(dem, target_res = 10)

  expect_equal(terra::res(out)[1], 10)
  # 100 x 100 cellules à 1 m -> 10 x 10 à 10 m : 100x moins de mémoire.
  expect_equal(terra::ncell(out), 100)
  # L'emprise est conservée : les extractions par unité restent comparables.
  expect_equal(as.vector(terra::ext(out)), as.vector(terra::ext(dem)))
})

test_that(".dem_working_res never upsamples a DEM already coarser than target", {
  dem <- make_dem(res = 25)
  out <- .dem_working_res(dem, target_res = 10)

  expect_equal(terra::res(out)[1], 25)
  expect_equal(terra::ncell(out), terra::ncell(dem))
})

test_that(".dem_working_res is a no-op below a factor of 2", {
  # 6 m vers 10 m -> facteur 1 : agréger dégraderait sans gain notable.
  dem <- make_dem(res = 6)
  expect_equal(terra::res(.dem_working_res(dem, target_res = 10))[1], 6)
})

test_that(".dem_working_res leaves lon/lat DEMs alone (degrees, not metres)", {
  dem <- make_dem(res = 0.001, crs = "EPSG:4326")
  out <- .dem_working_res(dem, target_res = 10)

  expect_true(terra::is.lonlat(out))
  expect_equal(terra::res(out)[1], terra::res(dem)[1])
})

test_that(".dem_working_res opts out on NULL / invalid target_res", {
  dem <- make_dem(res = 1)
  for (tr in list(NULL, NA_real_, 0, -5)) {
    expect_equal(terra::res(.dem_working_res(dem, target_res = tr))[1], 1)
  }
})

test_that(".dem_working_res passes non-raster inputs through untouched", {
  expect_null(.dem_working_res(NULL))
  expect_identical(.dem_working_res("not a raster"), "not a raster")
})

test_that(".dem_working_res announces the aggregation only when given a context", {
  dem <- make_dem(res = 1)
  expect_message(.dem_working_res(dem, target_res = 10, context = "R2"), "R2")
  expect_silent(.dem_working_res(dem, target_res = 10))
})

test_that(".twi_aggregate_dem keeps its historical behaviour via the shared helper", {
  dem <- make_dem(res = 1)
  expect_equal(terra::res(.twi_aggregate_dem(dem))[1], 10)
  expect_equal(terra::res(.twi_aggregate_dem(dem, target_res = 5))[1], 5)
  expect_equal(terra::res(.twi_aggregate_dem(make_dem(res = 25)))[1], 25)
})

test_that("terrain indicators expose dem_target_res and default to 10 m", {
  targets <- c(
    "indicateur_r1_feu", "indicateur_r2_tempete", "indicateur_r3_secheresse",
    "indicateur_w2_zones_humides", "indicateur_w3_humidite",
    "indicateur_f2_erosion", "indicateur_s1_routes", "indicateur_s2_bati"
  )
  for (fn in targets) {
    fmls <- formals(get(fn, envir = asNamespace("nemeton")))
    expect_true("dem_target_res" %in% names(fmls), info = fn)
    expect_equal(fmls$dem_target_res, 10, info = fn)
  }
})

test_that("R2 bounds its working grid before deriving terrain layers", {
  # Le chemin réel : un MNT fin passe par le garde-fou, l'indicateur reste
  # calculable et les valeurs restent dans [0, 100].
  units <- sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(10, 40, 40, 10, 10), c(10, 10, 40, 40, 10)))),
      sf::st_polygon(list(cbind(c(50, 90, 90, 50, 50), c(50, 50, 90, 90, 50)))),
      crs = 2154
    )
  )
  dem <- make_dem(res = 1)
  terra::values(dem) <- as.numeric(terra::init(dem, "y")[] / 10)

  res <- indicateur_r2_tempete(units, dem = dem, dem_target_res = 10)
  expect_true("R2" %in% names(res))
  expect_true(all(is.na(res$R2) | (res$R2 >= 0 & res$R2 <= 100)))
})
