# test-foret-ancienne-mask.R — build_foret_ancienne_mask() (spec 031)
#
# Source-agnostic helper that builds the `foret_ancienne` polygon layer
# consumed by indicateur_n2_continuite(). In-memory rasters/sf, no network.

# 10x10 grid, 10 m cells, EPSG:2154, extent [0,100] x [0,100].
.fa_grid <- function() {
  terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 100,
              ymin = 0, ymax = 100, crs = "EPSG:2154")
}

.fa_unit <- function(xmin = 0, xmax = 50, ymin = 0, ymax = 100) {
  g <- sf::st_as_sfc(sf::st_bbox(c(xmin = xmin, ymin = ymin,
                                   xmax = xmax, ymax = ymax), crs = 2154))
  sf::st_sf(id = 1L, geometry = g)
}


test_that("raster + forest_class yields an ancient-forest polygon layer", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  # Left half (cols 1-5) = class 1 (forest), right half = class 2.
  r <- .fa_grid()
  v <- rep(2L, 100)
  m <- matrix(v, nrow = 10, byrow = TRUE)
  m[, 1:5] <- 1L
  terra::values(r) <- as.integer(t(m))
  fa <- build_foret_ancienne_mask(r, forest_class = 1L)
  expect_s3_class(fa, "sf")
  expect_true(all(fa$foret_ancienne))
  expect_gt(nrow(fa), 0L)
  # Forest area ~ left half = 50x100 = 5000 m2.
  expect_equal(sum(as.numeric(sf::st_area(fa))), 5000, tolerance = 1)
})

test_that("raster + threshold selects values >= threshold", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  r <- .fa_grid()
  # Continuous "forest probability": top 3 rows high (0.9), rest low (0.1).
  m <- matrix(0.1, nrow = 10, ncol = 10)
  m[1:3, ] <- 0.9
  terra::values(r) <- as.numeric(t(m))
  fa <- build_foret_ancienne_mask(r, threshold = 0.5)
  # 3 rows of 10 cells x 100 m2 = 3000 m2.
  expect_equal(sum(as.numeric(sf::st_area(fa))), 3000, tolerance = 1)
})

test_that("vector source is validated and returned with the marker column", {
  skip_if_not_installed("sf")
  poly <- sf::st_as_sfc(sf::st_bbox(c(xmin = 0, ymin = 0,
                                      xmax = 30, ymax = 30), crs = 2154))
  fa <- build_foret_ancienne_mask(sf::st_sf(geometry = poly))
  expect_s3_class(fa, "sf")
  expect_identical(names(fa)[1], "foret_ancienne")
  expect_true(all(fa$foret_ancienne))
  expect_equal(as.numeric(sf::st_area(fa)), 900, tolerance = 1)
})

test_that("min_area_m2 drops small patches", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  r <- .fa_grid()
  # One big block (rows 1-5, cols 1-5 = 50x50 = 2500 m2) + a 1-cell speckle.
  m <- matrix(NA_integer_, nrow = 10, ncol = 10)
  m[1:5, 1:5] <- 1L
  m[10, 10]  <- 1L          # isolated 10x10 = 100 m2 patch
  terra::values(r) <- as.integer(t(m))
  fa <- build_foret_ancienne_mask(r, forest_class = 1L, min_area_m2 = 200)
  # The 100 m2 speckle is dropped, the 2500 m2 block kept.
  expect_true(all(as.numeric(sf::st_area(fa)) >= 200))
  expect_equal(sum(as.numeric(sf::st_area(fa))), 2500, tolerance = 1)
})

test_that("output feeds indicateur_n2_continuite (ancient forest -> high score)", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  r <- .fa_grid()
  terra::values(r) <- rep(1L, 100)             # whole grid = forest
  fa <- build_foret_ancienne_mask(r, forest_class = 1L)
  unit <- .fa_unit()                            # unit inside the grid
  res <- indicateur_n2_continuite(unit, foret_ancienne = fa)
  # N2: taux_ancienne = 1 -> score 60 + 1*40 = 100.
  expect_equal(res$N2[[1]], 100, tolerance = 1e-6)
})

test_that("unsupported source type errors", {
  expect_error(build_foret_ancienne_mask(42), "sf/sfc.*SpatRaster")
})
