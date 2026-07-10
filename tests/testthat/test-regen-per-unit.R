# test-regen-per-unit.R — spec 035 : per-UGF lai_max / sol, et lai_max_depuis_pai().

make_units <- function(n = 3) {
  geoms <- lapply(seq_len(n), function(i) {
    x0 <- (i - 1) * 100
    sf::st_polygon(list(rbind(c(x0, 0), c(x0 + 100, 0), c(x0 + 100, 100),
                              c(x0, 100), c(x0, 0))))
  })
  sf::st_sf(id = seq_len(n), geometry = sf::st_sfc(geoms, crs = 2154))
}

# --- .regen_per_unit_list : le garde-fou de correction (spec 035 D6) ---

test_that("a scalar stays a scalar (shared across every point)", {
  expect_equal(.regen_per_unit_list(5, ids = 1:3, arg = "lai_max"), 5)
})

test_that("NULL stays NULL", {
  expect_null(.regen_per_unit_list(NULL, ids = 1:3, arg = "lai_max"))
})

test_that("a per-unit vector becomes a list keyed by id", {
  out <- .regen_per_unit_list(c(3, 5, 7), ids = 1:3, arg = "lai_max")
  expect_type(out, "list")
  expect_named(out, c("1", "2", "3"))
  expect_equal(out[["2"]], 5)
  # C'est exactement la forme que as_fun() de biljou_run_grid sait indexer.
  expect_true(is.list(out) && !is.data.frame(out))
})

test_that("a vector of the wrong length is refused, not silently recycled", {
  expect_error(.regen_per_unit_list(c(3, 5), ids = 1:3, arg = "lai_max"),
               "expected 1 or 3")
})

test_that("a biljou_soil object is passed through untouched", {
  fake <- structure(list(ewm = 150), class = "biljou_soil")
  expect_identical(.regen_per_unit_list(fake, ids = 1:3, arg = "sol"), fake)
})

test_that("an unnamed or incomplete list is refused", {
  expect_error(.regen_per_unit_list(list(1, 2, 3), ids = 1:3, arg = "sol"),
               "not keyed by every unit id")
  expect_error(
    .regen_per_unit_list(stats::setNames(list(1, 2), c("1", "2")),
                         ids = 1:3, arg = "sol"),
    "not keyed by every unit id")
})

test_that("a correctly named list passes through", {
  l <- stats::setNames(list(3, 5, 7), c("1", "2", "3"))
  expect_identical(.regen_per_unit_list(l, ids = 1:3, arg = "lai_max"), l)
})

# --- lai_max_depuis_pai() ---

test_that("lai_max_depuis_pai takes the high percentile, not the mean", {
  units <- make_units(1)
  # Raster couvrant l'UGF : 90 % de pixels a 2, 10 % a 6.
  r <- terra::rast(terra::ext(0, 100, 0, 100), resolution = 10, crs = "EPSG:2154")
  v <- rep(2, terra::ncell(r))
  v[1:10] <- 6                       # 10 pixels sur 100
  terra::values(r) <- v

  lai <- lai_max_depuis_pai(units, r, probs = 0.9)
  moy <- mean(v)                     # 2.4
  expect_gt(lai, moy)                # le plateau, pas la moyenne
  expect_true(lai >= 2 && lai <= 6)
})

test_that("lai_max_depuis_pai excludes non-canopy pixels below min_pai", {
  units <- make_units(1)
  r <- terra::rast(terra::ext(0, 100, 0, 100), resolution = 10, crs = "EPSG:2154")
  v <- rep(4, terra::ncell(r))
  v[1:50] <- 0                       # moitie de trouees
  terra::values(r) <- v

  # Avec le filtre : seul le peuplement compte -> ~4.
  expect_equal(lai_max_depuis_pai(units, r, probs = 0.5, min_pai = 0.1), 4)
  # Sans filtre : la mediane tombe entre 0 et 4.
  expect_lt(lai_max_depuis_pai(units, r, probs = 0.5, min_pai = 0), 4)
})

test_that("lai_max_depuis_pai returns one value per unit", {
  units <- make_units(3)
  r <- terra::rast(terra::ext(0, 300, 0, 100), resolution = 10, crs = "EPSG:2154")
  # PAI croissant d'ouest en est -> les 3 UGF doivent differer.
  xy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
  terra::values(r) <- 1 + xy[, 1] / 100

  lai <- lai_max_depuis_pai(units, r)
  expect_length(lai, 3)
  expect_false(anyNA(lai))
  expect_true(all(diff(lai) > 0), info = "le PAI croissant doit spatialiser lai_max")
})

test_that("lai_max_depuis_pai returns NA for a unit with no canopy pixel", {
  units <- make_units(1)
  r <- terra::rast(terra::ext(0, 100, 0, 100), resolution = 10, crs = "EPSG:2154")
  terra::values(r) <- rep(0, terra::ncell(r))   # tout sous min_pai
  expect_true(is.na(lai_max_depuis_pai(units, r)))
})

test_that("lai_max_depuis_pai validates its arguments", {
  units <- make_units(1)
  r <- terra::rast(terra::ext(0, 100, 0, 100), resolution = 10, crs = "EPSG:2154")
  terra::values(r) <- rep(3, terra::ncell(r))

  expect_error(lai_max_depuis_pai(units, r, probs = 1.5), "in .*0, 1")
  expect_error(lai_max_depuis_pai(units, 42), "SpatRaster")
  expect_error(lai_max_depuis_pai(units, "/no/such/pai.tif"), "does not exist")
})

test_that("lai_max_depuis_pai accepts a path to a raster", {
  # Ce test écrit un GeoTIFF : certains runners GitHub Actions ont une anomalie
  # terra sur writeRaster(crs = "EPSG:nnnn"). Cf. helper-fast-raster.R.
  skip_if_terra_write_broken()
  units <- make_units(1)
  r <- terra::rast(terra::ext(0, 100, 0, 100), resolution = 10, crs = "EPSG:2154")
  terra::values(r) <- rep(3, terra::ncell(r))
  withr::with_tempdir({
    terra::writeRaster(r, "pai.tif")
    expect_equal(lai_max_depuis_pai(units, "pai.tif"), 3)
  })
})

# --- build_biljou_soil : mode uniforme vs per-UGF ---

test_that("build_biljou_soil keeps the v0.146.x uniform contract", {
  skip_if_not_installed("biljouR")
  s <- build_biljou_soil(ewm = 150)
  expect_s3_class(s, "biljou_soil")
  expect_equal(s$ewm_total, 150)
})

test_that("build_biljou_soil soilgrids mode returns one soil per unit", {
  skip_if_not_installed("biljouR")
  units <- make_units(3)
  local_mocked_bindings(
    ewm_depuis_soilgrids = function(...) c(80, 120, 200))

  sols <- build_biljou_soil(units, source = "soilgrids")
  expect_type(sols, "list")
  expect_named(sols, c("1", "2", "3"))
  expect_s3_class(sols[["1"]], "biljou_soil")
  expect_equal(vapply(sols, function(s) s$ewm_total, numeric(1)),
               c("1" = 80, "2" = 120, "3" = 200))
})

test_that("build_biljou_soil falls back to a uniform soil when SoilGrids is down", {
  skip_if_not_installed("biljouR")
  units <- make_units(2)
  local_mocked_bindings(ewm_depuis_soilgrids = function(...) NULL)

  expect_warning(s <- build_biljou_soil(units, ewm = 150, source = "soilgrids"),
                 "unreachable")
  expect_s3_class(s, "biljou_soil")
  expect_equal(s$ewm_total, 150)
})

test_that("build_biljou_soil replaces non-positive ewm by the fallback", {
  skip_if_not_installed("biljouR")
  units <- make_units(3)
  local_mocked_bindings(ewm_depuis_soilgrids = function(...) c(90, NA, 0))

  expect_warning(sols <- build_biljou_soil(units, ewm = 150, source = "soilgrids"),
                 "without usable soil data")
  expect_equal(vapply(sols, function(s) s$ewm_total, numeric(1)),
               c("1" = 90, "2" = 150, "3" = 150))
})

test_that("build_biljou_soil requires units in soilgrids mode", {
  skip_if_not_installed("biljouR")
  expect_error(build_biljou_soil(source = "soilgrids"), "units.*required")
})
