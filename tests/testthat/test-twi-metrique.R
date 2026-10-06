# TWI : MNT en degrés et dépendance à la résolution (spec 056, 1.0.0).
#
# Constat 1 de la spec 056 : sur un MNT en EPSG:4326 (repli IGN WMS de
# Couchey et d'Aumur), `calculate_twi_terra()` calculait l'aire spécifique en
# res²/res dans l'unité du raster, des DEGRÉS (≈ 2,5e-4). Le TWI perdait
# ln(19 m / 2,5e-4) ≈ 11 unités et finissait écrêté à 0 : W3 = 0 sur les 76
# UGF de Couchey, composante TWI de F2 = 0.

skip_if_not_installed("terra")
skip_if_not_installed("sf")

clear_twi_cache <- function() {
  rm(list = ls(envir = .twi_cache, all.names = TRUE), envir = .twi_cache)
}

# Vallée en V en Lambert-93 : versants à 10 % vers un talweg central, qui
# s'écoule lui-même vers le sud. Un relief réel, pas un plan, pour que
# l'accumulation D8 varie.
make_valley_l93 <- function(res = 20, n = 60) {
  x0 <- 850000; y0 <- 6650000
  r <- terra::rast(nrows = n, ncols = n,
                   xmin = x0, xmax = x0 + n * res,
                   ymin = y0, ymax = y0 + n * res, crs = "EPSG:2154")
  xy <- terra::crds(r)
  cx <- x0 + n * res / 2
  terra::values(r) <- 300 + 0.10 * abs(xy[, 1] - cx) + 0.02 * (xy[, 2] - y0)
  r
}

unit_l93 <- function(dem, frac = 0.25) {
  e <- as.vector(terra::ext(dem))
  dx <- (e[2] - e[1]) * frac; dy <- (e[4] - e[3]) * frac
  sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(sf::st_polygon(list(cbind(
      c(e[1] + dx, e[2] - dx, e[2] - dx, e[1] + dx, e[1] + dx),
      c(e[3] + dy, e[3] + dy, e[4] - dy, e[4] - dy, e[3] + dy)
    ))), crs = 2154)
  )
}

test_that("TWI on a lon/lat DEM is computed on a metric grid (no more zeros)", {
  clear_twi_cache()
  dem_m <- make_valley_l93()
  dem_ll <- terra::project(dem_m, "EPSG:4326", method = "bilinear")
  units <- unit_l93(dem_m)

  twi_m  <- safe_extract(calculate_twi_terra(dem_m, target_res = NULL),
                         units, fun = "mean", progress = FALSE)
  twi_ll <- safe_extract(calculate_twi_terra(dem_ll, target_res = NULL),
                         units, fun = "mean", progress = FALSE)

  # Avant 1.0.0 : twi_ll ≈ 0 (aire spécifique en degrés).
  expect_gt(twi_ll, 2)
  # Même terrain, même résolution à l'arrondi de la reprojection près.
  expect_lt(abs(twi_ll - twi_m), 1.5)
})

test_that("the lon/lat DEM is projected to the units' CRS when it is metric", {
  clear_twi_cache()
  dem_ll <- terra::project(make_valley_l93(), "EPSG:4326", method = "bilinear")
  twi <- calculate_twi_terra(dem_ll, target_res = NULL, crs = "EPSG:2154")
  expect_false(terra::is.lonlat(twi))
  expect_equal(terra::crs(twi, describe = TRUE)$code, "2154")
  # Sans CRS métrique fourni : ETRS89-LAEA (ADR-008).
  twi_3035 <- calculate_twi_terra(dem_ll, target_res = NULL)
  expect_equal(terra::crs(twi_3035, describe = TRUE)$code, "3035")
})

test_that("W3 and F2 are no longer 0 on a lon/lat DEM", {
  clear_twi_cache()
  dem_m <- make_valley_l93()
  dem_ll <- terra::project(dem_m, "EPSG:4326", method = "bilinear")
  units <- unit_l93(dem_m)
  cache <- withr::local_tempdir()
  dem_path <- file.path(cache, "dem_ll.tif")
  terra::writeRaster(dem_ll, dem_path)
  layers <- nemeton_layers(rasters = list(dem = dem_path))
  layers$cache_dir <- cache

  w3 <- suppressMessages(indicateur_w3_humidite(units, layers, method = "d8"))
  expect_gt(w3, 2)
  expect_gt(normalize_indicator("W3", w3), 0)

  # F2 = (TWI_norm + pente_norm) / 2 : la composante TWI ne vaut plus 0.
  f2 <- suppressMessages(indicateur_f2_erosion(units, layers))
  slope <- terra::terrain(dem_ll, v = "slope", unit = "degrees")
  slope_norm <- 100 - safe_extract(slope, units, fun = "mean",
                                   progress = FALSE) / 45 * 100
  expect_gt(2 * f2 - slope_norm, 5)
})

test_that("R3 aligns a metric TWI on a lon/lat terrain grid", {
  clear_twi_cache()
  dem_m <- make_valley_l93()
  dem_ll <- terra::project(dem_m, "EPSG:4326", method = "bilinear")
  units <- unit_l93(dem_m)
  res <- suppressMessages(indicateur_r3_secheresse(
    units, dem = dem_ll, layers = list(cache_dir = withr::local_tempdir())))
  expect_true(is.finite(res$R3))
  expect_true(res$R3 >= 0 && res$R3 <= 100)
})

test_that("a TWI cached under the pre-1.0 key is never reused", {
  # La clé de cache change en 1.0.0 : un TWI calculé en degrés (ou non ramené
  # à 2 m) ne doit pas ressortir d'un cache fichier d'avant le correctif.
  clear_twi_cache()
  cache <- withr::local_tempdir()
  dem <- make_valley_l93()
  old_key <- paste(nrow(dem), ncol(dem),
                   paste(as.vector(terra::ext(dem)), collapse = ","),
                   terra::crs(dem, describe = TRUE)$code,
                   signif(.dem_working_res_value(dem, 2), 6),
                   sep = "|")
  stale <- terra::rast(dem)
  terra::values(stale) <- 999
  terra::writeRaster(stale, file.path(cache, .twi_cache_file(old_key)))

  twi <- get_or_compute_twi(dem, cache_dir = cache, twi_target_res = 2)
  expect_false(any(terra::values(twi) == 999, na.rm = TRUE))
})

test_that("the TWI cache key depends on the metric CRS of a lon/lat DEM", {
  clear_twi_cache()
  cache <- withr::local_tempdir()
  dem_ll <- terra::project(make_valley_l93(), "EPSG:4326", method = "bilinear")
  a <- get_or_compute_twi(dem_ll, cache_dir = cache, crs = "EPSG:2154")
  b <- get_or_compute_twi(dem_ll, cache_dir = cache, crs = "EPSG:3035")
  expect_false(terra::same.crs(a, b))
  expect_length(list.files(cache, pattern = "^twi_.*\\.tif$"), 2)
})

# --------------------------------------------------------------------------
# Constat 2 de la spec 056 : l'aire spécifique vaut A / pas, si bien que pour
# une même pente TWI(2 m) − TWI(25 m) ≈ ln(25/2). Le TWI est désormais ramené à
# la référence de 2 m : TWI_2m = TWI_brut − ln(pas / 2), pas en mètres.
# --------------------------------------------------------------------------

test_that("the same relief gives the same TWI whatever the grid step", {
  clear_twi_cache()
  # Même relief (même pente, même réseau D8), deux pas : 10 m et 40 m. Les
  # altitudes de la grille à 40 m sont multipliées par 4 pour garder la pente.
  make_relief <- function(res) {
    m <- make_valley_l93(res = 10, n = 40)
    r <- terra::rast(nrows = 40, ncols = 40, xmin = 0, xmax = 40 * res,
                     ymin = 0, ymax = 40 * res, crs = "EPSG:2154")
    terra::values(r) <- terra::values(m) * res / 10
    r
  }
  t10 <- terra::values(calculate_twi_terra(make_relief(10), target_res = NULL))
  t40 <- terra::values(calculate_twi_terra(make_relief(40), target_res = NULL))
  ok <- is.finite(t10) & is.finite(t40) & t10 > 0 & t40 > 0
  expect_gt(sum(ok), 100)
  # Avant 1.0.0 : t40 − t10 = ln(4) ≈ 1,39 partout.
  expect_equal(t40[ok], t10[ok], tolerance = 1e-6)
})

test_that("a TWI at 2 m is unchanged by the 2 m reference", {
  clear_twi_cache()
  dem <- terra::rast(nrows = 40, ncols = 40, xmin = 0, xmax = 80,
                     ymin = 0, ymax = 80, crs = "EPSG:2154")
  terra::values(dem) <- terra::values(make_valley_l93(res = 2, n = 40))
  twi <- calculate_twi_terra(dem, target_res = NULL)
  # Formule brute, sans recentrage : ln(a / tan(pente)), a = (acc + 1) · pas.
  slope <- terra::terrain(dem, v = "slope", unit = "radians")
  slope[slope < 0.001] <- 0.001
  acc <- terra::flowAccumulation(terra::terrain(dem, v = "flowdir"))
  brut <- log((acc + 1) * 2 / tan(slope))
  v <- terra::values(twi); b <- terra::values(brut)
  ok <- is.finite(v) & is.finite(b) & b > 0
  expect_equal(v[ok], b[ok], tolerance = 1e-6)
})

test_that(".twi_ref_2m subtracts ln(step / 2)", {
  r <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 50, ymin = 0,
                   ymax = 50, crs = "EPSG:2154")
  terra::values(r) <- c(5, 6, 7, 8)
  expect_equal(terra::values(.twi_ref_2m(r))[, 1], c(5, 6, 7, 8) - log(25 / 2))
})
