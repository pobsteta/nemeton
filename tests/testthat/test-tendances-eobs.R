# test-tendances-eobs.R — branche A tendances estivales E-OBS (spec 027 §6)
#
# Rasters par-année synthétiques (EPSG:3035, buffer métrique propre), aucune
# donnée E-OBS réelle, aucun réseau.

# A 4x4 raster (10 km cells) of per-year summer values: cell i has value
# base + slope_i * year, slope_i = i * 0.1 -> spatial gradient of trends.
.eobs_stack <- function(base = 20, slope_scale = 0.1, nyear = 5,
                        xmin = 0, xmax = 40000, ymin = 0, ymax = 40000) {
  sl <- (1:16) * slope_scale
  vals <- vapply(seq_len(nyear), function(L) base + sl * L, numeric(16))
  r <- terra::rast(nrows = 4, ncols = 4, xmin = xmin, xmax = xmax,
                   ymin = ymin, ymax = ymax, nlyrs = nyear, crs = "EPSG:3035")
  terra::values(r) <- vals
  r
}

.eobs_aoi <- function() {
  sf::st_as_sf(sf::st_sfc(
    sf::st_polygon(list(rbind(c(15000, 15000), c(25000, 15000),
                              c(25000, 25000), c(15000, 25000),
                              c(15000, 15000)))), crs = 3035))
}


test_that("trends recover the per-cell linear slope", {
  skip_if_not_installed("terra")
  tx <- .eobs_stack(base = 20, slope_scale = 0.1)     # slope_i = i*0.1
  rr <- .eobs_stack(base = 300, slope_scale = -2)     # drying: slope_i = -2i
  out <- tendances_estivales_eobs(.eobs_aoi(), tx = tx, rr = rr,
                                  buffer_m = 25000)
  expect_s3_class(out, "sf")
  expect_true(all(c("trend_tmax", "trend_precip", "classe_tmax",
                    "classe_precip", "classe_bivariee") %in% names(out)))
  expect_true(all(out$trend_tmax > 0, na.rm = TRUE))      # warming
  expect_true(all(out$trend_precip < 0, na.rm = TRUE))    # drying
})

test_that("classes are 1-3 and the bivariate class is 1-9", {
  skip_if_not_installed("terra")
  tx <- .eobs_stack(slope_scale = 0.1)
  rr <- .eobs_stack(base = 300, slope_scale = 0.1)
  out <- tendances_estivales_eobs(.eobs_aoi(), tx = tx, rr = rr, buffer_m = 25000)
  expect_true(all(out$classe_tmax %in% 1:3))
  expect_true(all(out$classe_precip %in% 1:3))
  expect_true(all(out$classe_bivariee %in% 1:9))
  # Bivariate encoding is consistent.
  expect_equal(out$classe_bivariee,
               (out$classe_tmax - 1L) * 3L + out$classe_precip)
})

test_that("a larger buffer keeps at least as many cells", {
  skip_if_not_installed("terra")
  tx <- .eobs_stack(); rr <- .eobs_stack(base = 300)
  small <- tendances_estivales_eobs(.eobs_aoi(), tx = tx, rr = rr, buffer_m = 3000)
  big   <- tendances_estivales_eobs(.eobs_aoi(), tx = tx, rr = rr, buffer_m = 25000)
  expect_gte(nrow(big), nrow(small))
  expect_gt(nrow(small), 0)
})

test_that("default buffer is 25 km (decision §10.4)", {
  expect_equal(formals(tendances_estivales_eobs)$buffer_m, 25000)
})

test_that("precomputed sf is cropped + classified without rasters", {
  skip_if_not_installed("terra")
  # Build a precomputed sf of points with trends over the area.
  pts <- sf::st_as_sf(data.frame(
    trend_tmax = c(0.1, 0.5, 0.9, 0.3),
    trend_precip = c(-1, -3, 0.5, -2),
    x = c(16000, 20000, 24000, 40000),
    y = c(20000, 20000, 20000, 20000)),
    coords = c("x", "y"), crs = 3035)
  out <- tendances_estivales_eobs(.eobs_aoi(), precomputed = pts, buffer_m = 5000)
  expect_true(all(c("classe_tmax", "classe_bivariee") %in% names(out)))
  # The far point (x=30000) is > 5 km from the [15000,25000] AOI -> dropped.
  expect_lt(nrow(out), nrow(pts))
})

test_that("fixed breaks override the tertiles", {
  skip_if_not_installed("terra")
  pts <- sf::st_as_sf(data.frame(
    trend_tmax = c(0.1, 0.5, 0.9), trend_precip = c(-3, -1, 1),
    x = c(18000, 20000, 22000), y = c(20000, 20000, 20000)),
    coords = c("x", "y"), crs = 3035)
  out <- tendances_estivales_eobs(
    .eobs_aoi(), precomputed = pts, buffer_m = 25000,
    breaks = list(tmax = c(0.3, 0.7), precip = c(-2, 0)))
  expect_equal(out$classe_tmax, c(1L, 2L, 3L))
  expect_equal(out$classe_precip, c(1L, 2L, 3L))
})

test_that("no data -> clean error", {
  expect_error(tendances_estivales_eobs(.eobs_aoi()), "E-OBS data required")
})

test_that("aoi must be sf/sfc", {
  expect_error(tendances_estivales_eobs(list(1)), "must be an sf")
})
