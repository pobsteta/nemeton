# test-indicator-t3.R — T3 coupes rases (SUFOSAT), spec 030
#
# In-memory terra rasters, no network. `dates` encodes YYDDD, `proba` is a
# percentage. A single full-extent unit makes the arithmetic checkable.

# 10x10 grid, 10 m cells, EPSG:2154, extent [0,100] x [0,100].
.t3_grid <- function() {
  terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 100,
              ymin = 0, ymax = 100, crs = "EPSG:2154")
}

# dates: 10 cells cut in 2024 (24100), 10 cells cut in 2020 (20050), rest 0.
# proba: those 20 cells at `p` percent, rest 0.
.t3_rasters <- function(p_2020 = 95, p_2024 = 95) {
  dates <- .t3_grid()
  dv <- rep(0, 100); dv[1:10] <- 24100; dv[11:20] <- 20050
  terra::values(dates) <- dv

  proba <- .t3_grid()
  pv <- rep(0, 100); pv[1:10] <- p_2024; pv[11:20] <- p_2020
  terra::values(proba) <- pv

  list(dates = dates, proba = proba)
}

# Full-extent unit covering all 100 cells.
.t3_unit <- function(xmin = 0, xmax = 100, ymin = 0, ymax = 100) {
  g <- sf::st_as_sfc(sf::st_bbox(c(xmin = xmin, ymin = ymin,
                                   xmax = xmax, ymax = ymax), crs = 2154))
  sf::st_sf(id = 1L, geometry = g)
}


test_that("T3 = recency-weighted clear-cut share over the unit footprint", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")
  r <- .t3_rasters()
  # ref year auto = 2024, window 2020-2024.
  # w(2024)=5/5=1 on 10 cells, w(2020)=1/5=0.2 on 10 cells, denom=100 cells.
  # T3 = 100 * (10*1 + 10*0.2) / 100 = 12.
  out <- indicateur_t3_coupes_rases(.t3_unit(), r$dates, r$proba,
                                    window_years = 5, min_proba = 0.9)
  expect_length(out, 1L)
  expect_equal(out[[1]], 12, tolerance = 1e-6)
})

test_that("T3 min_proba drops low-confidence pixels", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")
  # 2020 cells at 80% < 0.9*100 -> excluded; only the 2024 cells (w=1) count.
  r <- .t3_rasters(p_2020 = 80, p_2024 = 95)
  out <- indicateur_t3_coupes_rases(.t3_unit(), r$dates, r$proba,
                                    min_proba = 0.9)
  expect_equal(out[[1]], 10, tolerance = 1e-6)
})

test_that("T3 window_years restricts the recency window", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")
  # window_years = 2, ref 2024 -> window 2023-2024; 2020 cells excluded.
  r <- .t3_rasters()
  out <- indicateur_t3_coupes_rases(.t3_unit(), r$dates, r$proba,
                                    window_years = 2, min_proba = 0.9)
  expect_equal(out[[1]], 10, tolerance = 1e-6)  # only 2024 cells, w=1
})

test_that("T3 without a proba raster applies no probability filter", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")
  r <- .t3_rasters()
  out <- indicateur_t3_coupes_rases(.t3_unit(), r$dates, sufosat_proba = NULL,
                                    window_years = 5)
  expect_equal(out[[1]], 12, tolerance = 1e-6)  # same as full-proba case
})

test_that("T3 is source-conditional: NULL dates -> NA per unit", {
  skip_if_not_installed("sf")
  units <- rbind(.t3_unit(), .t3_unit())
  out <- indicateur_t3_coupes_rases(units, sufosat_dates = NULL)
  expect_length(out, 2L)
  expect_true(all(is.na(out)))
})

test_that("T3 is NA for a unit that does not overlap the raster", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")
  r <- .t3_rasters()
  off <- .t3_unit(xmin = 1000, xmax = 1100, ymin = 1000, ymax = 1100)
  out <- indicateur_t3_coupes_rases(off, r$dates, r$proba)
  expect_true(is.na(out[[1]]))
})

test_that("T3 with no clear-cut pixel is 0 over the covered footprint", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")
  dates <- .t3_grid(); terra::values(dates) <- rep(0, 100)  # all nodata
  out <- indicateur_t3_coupes_rases(.t3_unit(), dates)
  expect_equal(out[[1]], 0, tolerance = 1e-6)
})

test_that("T3 empty units -> length-0 numeric", {
  skip_if_not_installed("sf")
  empty <- .t3_unit()[0, ]
  out <- indicateur_t3_coupes_rases(empty, sufosat_dates = NULL)
  expect_length(out, 0L)
})

test_that("T3 normalization inverts the sense (high clear-cut -> low score)", {
  # Like R5, T3 is oriented high = bad; normalize_indicator flips it.
  out <- normalize_indicator("indicateur_t3_coupes_rases", c(0, 12, 100))
  expect_equal(out, c(100, 88, 0), tolerance = 1e-6)
})
