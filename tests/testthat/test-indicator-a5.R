# test-indicator-a5.R — A5 rafraîchissement urbain (LST), spec 032
#
# In-memory LST rasters (Kelvin), no network. A cool patch under the unit
# surrounded by a hot ring makes the relative-freshness arithmetic checkable.

.a5_grid <- function() {
  terra::rast(nrows = 30, ncols = 30, xmin = 0, xmax = 300,
              ymin = 0, ymax = 300, crs = "EPSG:2154")
}

# Unit = central 100x100 block [100,200] x [100,200].
.a5_unit <- function() {
  g <- sf::st_as_sfc(sf::st_bbox(c(xmin = 100, ymin = 100,
                                   xmax = 200, ymax = 200), crs = 2154))
  sf::st_sf(id = 1L, geometry = g)
}

# LST: hot everywhere (`hot` K), cool square in the centre (`cool` K).
.a5_lst <- function(hot = 315, cool = 305) {
  r <- .a5_grid()
  terra::values(r) <- hot
  centre <- terra::ext(100, 200, 100, 200)
  r[terra::cells(r, centre)] <- cool
  r
}


test_that("A5 is high when the unit is cooler than its surroundings", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")
  lst <- .a5_lst(hot = 315, cool = 305)          # unit 10 K cooler
  out <- indicateur_a5_rafraichissement(.a5_unit(), lst = lst,
                                        buffer_m = 100, delta_scale = 5)
  # delta ~ +10 K (ref 315 - unit 305); score 50 + 10/5*50 = 150 -> clamp 100.
  expect_equal(out$A5[[1]], 100, tolerance = 1)
  expect_gt(out$A5_delta[[1]], 5)
})

test_that("A5 is low when the unit is hotter than its surroundings", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")
  lst <- .a5_lst(hot = 305, cool = 315)          # unit 10 K hotter
  out <- indicateur_a5_rafraichissement(.a5_unit(), lst = lst,
                                        buffer_m = 100, delta_scale = 5)
  expect_equal(out$A5[[1]], 0, tolerance = 1)
  expect_lt(out$A5_delta[[1]], -5)
})

test_that("A5 ~ 50 when the unit matches its surroundings", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")
  lst <- .a5_lst(hot = 310, cool = 310)          # uniform
  out <- indicateur_a5_rafraichissement(.a5_unit(), lst = lst,
                                        buffer_m = 100)
  expect_equal(out$A5[[1]], 50, tolerance = 1)
  expect_equal(out$A5_delta[[1]], 0, tolerance = 1e-6)
})

test_that("A5 accepts a fixed reference temperature", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")
  lst <- .a5_lst(hot = 315, cool = 305)
  # Fixed reference 310 K, unit ~305 K -> delta +5 -> score 100.
  out <- indicateur_a5_rafraichissement(.a5_unit(), lst = lst,
                                        reference = 310, delta_scale = 5)
  expect_equal(out$A5_delta[[1]], 5, tolerance = 1)
  expect_equal(out$A5[[1]], 100, tolerance = 1)
})

test_that("A5 is source-conditional: NULL lst -> NA", {
  skip_if_not_installed("sf")
  out <- indicateur_a5_rafraichissement(.a5_unit(), lst = NULL)
  expect_true(is.na(out$A5[[1]]))
  expect_true(is.na(out$A5_delta[[1]]))
})

test_that("A5 ignores the -32768 LST nodata sentinel", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")
  lst <- .a5_lst(hot = 315, cool = 305)
  # Poison a few cells with the nodata sentinel; must not skew the mean.
  lst[1:20] <- -32768
  out <- indicateur_a5_rafraichissement(.a5_unit(), lst = lst,
                                        buffer_m = 100, delta_scale = 5)
  expect_equal(out$A5[[1]], 100, tolerance = 1)
})

test_that("A5 is NA for a unit off the LST raster", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")
  lst <- .a5_lst()
  off <- sf::st_sf(id = 1L, geometry = sf::st_as_sfc(
    sf::st_bbox(c(xmin = 5000, ymin = 5000, xmax = 5100, ymax = 5100),
                crs = 2154)))
  out <- indicateur_a5_rafraichissement(off, lst = lst)
  expect_true(is.na(out$A5[[1]]))
})
