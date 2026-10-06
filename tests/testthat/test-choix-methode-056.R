# Choix de méthode validés par Pascal le 2026-10-06 (spec 056), livrés en
# 1.0.0 : chaque test fige la nouvelle formule.

skip_if_not_installed("terra")
skip_if_not_installed("sf")

clear_twi_cache <- function() {
  rm(list = ls(envir = .twi_cache, all.names = TRUE), envir = .twi_cache)
}

# Versant incliné en Lambert-93, pente variable (toit + bosse) pour que la
# pente et le TRI ne soient pas proportionnels l'un à l'autre.
make_slope_dem <- function(res = 10, n = 40) {
  r <- terra::rast(nrows = n, ncols = n, xmin = 850000, xmax = 850000 + n * res,
                   ymin = 6650000, ymax = 6650000 + n * res, crs = "EPSG:2154")
  xy <- terra::crds(r)
  x <- (xy[, 1] - 850000) / res; y <- (xy[, 2] - 6650000) / res
  terra::values(r) <- 400 + 3 * x + 0.05 * (x - 20)^2 + 2 * sin(y / 3) * x / 10
  r
}

square_unit <- function(dem, frac = 0.2) {
  e <- as.vector(terra::ext(dem))
  dx <- (e[2] - e[1]) * frac; dy <- (e[4] - e[3]) * frac
  sf::st_sf(id = 1L, geometry = sf::st_sfc(sf::st_polygon(list(cbind(
    c(e[1] + dx, e[2] - dx, e[2] - dx, e[1] + dx, e[1] + dx),
    c(e[3] + dy, e[3] + dy, e[4] - dy, e[4] - dy, e[3] + dy)
  ))), crs = 2154))
}

# ---------------------------------------------------------------------------
# 1. R2 : composante TRI retirée (redondante avec la pente, r = 0,82 à 0,99)
# ---------------------------------------------------------------------------

test_that("R2 terrain fallback is wind exposure x normalised slope, no TRI", {
  local_mocked_bindings(get_nasapower_wind = function(...) 270)
  dem <- make_slope_dem()
  units <- square_unit(dem)
  res <- suppressMessages(indicateur_r2_tempete(units, dem = dem,
                                                dem_target_res = NULL))

  aspect <- terra::terrain(dem, v = "aspect", unit = "degrees")
  slope  <- terra::terrain(dem, v = "slope", unit = "degrees")
  d <- abs(aspect - 270)
  d <- terra::app(terra::sds(d, 360 - d), fun = "min")
  attendu <- (1 - d / 180) * terra::clamp(slope / 45, 0, 1)
  attendu <- safe_extract(attendu, units, fun = "mean", progress = FALSE) * 100

  # Avant 1.0.0 : expo × (0,6·pente + 0,4·TRI/max(TRI)).
  expect_equal(res$R2, attendu, tolerance = 1e-6)
})

test_that("R2 no longer depends on the roughest cell of the extent", {
  # Le TRI était normalisé par son maximum sur l'emprise : un même relief
  # valait de 3 à 85 points selon le projet. Une crête hors des unités ne
  # doit plus rien changer.
  local_mocked_bindings(get_nasapower_wind = function(...) 270)
  dem <- make_slope_dem()
  units <- square_unit(dem)
  dem_crete <- dem
  dem_crete[1, 1] <- 2000
  a <- suppressMessages(indicateur_r2_tempete(units, dem = dem, dem_target_res = NULL))
  b <- suppressMessages(indicateur_r2_tempete(units, dem = dem_crete, dem_target_res = NULL))
  expect_equal(a$R2, b$R2)
})

# ---------------------------------------------------------------------------
# 1-2. Fenêtre TWI commune [2,5 ; 9] pour W3, F2 et R3 (TWI ramené à 2 m)
# ---------------------------------------------------------------------------

test_that("the common TWI window is [2.5, 9]", {
  expect_equal(unname(.TWI_WINDOW), c(2.5, 9))
  expect_equal(.twi_norm(c(1, 2.5, 5.75, 9, 12)), c(0, 0, 0.5, 1, 1))
})

test_that("W3 is normalised on [2.5, 9] (was [2.5, 4.5])", {
  # Avant 1.0.0, 75 à 100 % des UGF LiDAR saturaient à 100.
  expect_equal(normalize_indicator("W3", c(1, 2.5, 4.5, 5.75, 9, 15)),
               c(0, 0, 100 * 2 / 6.5, 50, 100, 100))
  expect_equal(normalize_indicator("indicateur_w3_humidite", 5.75), 50)
})

# Un TWI constant posé sur la grille du MNT (mock du cache TWI).
mock_twi <- function(value_in, value_out = value_in, units = NULL) {
  function(dem, ...) {
    r <- terra::rast(dem)
    terra::values(r) <- value_out
    if (!is.null(units)) {
      m <- terra::rasterize(terra::vect(units), r, touches = TRUE)
      r[!is.na(m)] <- value_in
    }
    r
  }
}

test_that("F2 TWI component uses the common window [2.5, 9] (was [2.5, 10])", {
  clear_twi_cache()
  dem <- terra::rast(nrows = 20, ncols = 20, xmin = 850000, xmax = 850200,
                     ymin = 6650000, ymax = 6650200, crs = "EPSG:2154")
  terra::values(dem) <- 300            # plat : pente 0, slope_norm = 100
  dem_path <- withr::local_tempfile(fileext = ".tif")
  terra::writeRaster(dem, dem_path)
  layers <- nemeton_layers(rasters = list(dem = dem_path))
  units <- square_unit(dem)
  local_mocked_bindings(get_or_compute_twi = mock_twi(5.75))
  f2 <- suppressMessages(indicateur_f2_erosion(units, layers))
  # (TWI_norm 50 + pente 100) / 2. Avant : (43,3 + 100) / 2 = 71,7.
  expect_equal(f2, 75)
})

test_that("R3 TWI risk uses the fixed window, not the extent maximum", {
  clear_twi_cache()
  dem <- make_slope_dem()
  units <- square_unit(dem)
  r3 <- function(twi_in, twi_out = twi_in) {
    local_mocked_bindings(get_or_compute_twi = mock_twi(twi_in, twi_out, units))
    suppressMessages(indicateur_r3_secheresse(units, dem = dem,
                                              dem_target_res = NULL))$R3
  }
  # twi_risk = 1 − norm(TWI) pèse 0,3 de la topographie (R3 = topo seule sans
  # climat) : de TWI 2,5 (risque 1) à TWI 9 (risque 0), R3 perd 30 points.
  expect_equal(r3(2.5) - r3(9), 30, tolerance = 1e-6)
  expect_equal(r3(1) - r3(12), 30, tolerance = 1e-6)
  # Le maximum de l'emprise ne compte plus (avant : TWI / max(TWI)).
  expect_equal(r3(5.75, 5.75), r3(5.75, 16), tolerance = 1e-6)
})
