# test-sampling-plan.R
# Tests for R/sampling_plan.R — create_sampling_plan() and internals.

# ------------------------------------------------------------
# Fixtures
# ------------------------------------------------------------

make_zone <- function() {
  sf::st_sf(geometry = sf::st_sfc(sf::st_polygon(list(rbind(
    c(900000, 6500000), c(901000, 6500000),
    c(901000, 6501000), c(900000, 6501000),
    c(900000, 6500000)
  ))), crs = 2154))
}

make_chm <- function() {
  skip_if_not_installed("terra")
  r <- terra::rast(xmin = 899900, xmax = 901100,
                   ymin = 6499900, ymax = 6501100,
                   resolution = 10, crs = "EPSG:2154")
  terra::values(r) <- rep(seq(5, 30, length.out = ncol(r)),
                          each = nrow(r))
  r
}


# ------------------------------------------------------------
# Fallback path: no auxiliary data → spatial draw only
# ------------------------------------------------------------

test_that("create_sampling_plan falls back to a spatial draw without aux inputs", {
  skip_if_not_installed("sf")
  zone <- make_zone()
  res <- create_sampling_plan(zone, n_base = 10, n_over = 3, seed = 1)

  expect_s3_class(res, "sf")
  expect_equal(nrow(res), 13)
  expect_setequal(unique(res$type), c("Base", "Over"))
  expect_equal(sum(res$type == "Base"), 10)
  expect_equal(sum(res$type == "Over"), 3)
  expect_equal(as.integer(sf::st_crs(res)$epsg), 2154L)
  expect_true(all(c("plot_id", "type", "visit_order", "stratum") %in% names(res)))
  expect_true(attr(res, "method") %in% c("lpm2", "random"))
})


test_that("create_sampling_plan preserves zone CRS other than 2154", {
  skip_if_not_installed("sf")
  # Small zone in WGS84 UTM 30N (EPSG:32630) around central France
  zone <- sf::st_sf(geometry = sf::st_sfc(sf::st_polygon(list(rbind(
    c(500000, 5200000), c(501000, 5200000),
    c(501000, 5201000), c(500000, 5201000),
    c(500000, 5200000)
  ))), crs = 32630))
  res <- create_sampling_plan(zone, n_base = 5, seed = 3)
  expect_equal(as.integer(sf::st_crs(res)$epsg), 32630L)
})


# ------------------------------------------------------------
# Stratification path: CHM drives height quartiles
# ------------------------------------------------------------

test_that("create_sampling_plan stratifies on CHM and uses GRTS when available", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")
  skip_if_not_installed("spsurvey")

  zone <- make_zone()
  chm  <- make_chm()
  res  <- create_sampling_plan(zone, n_base = 16, n_over = 4,
                               chm = chm, seed = 42)

  expect_s3_class(res, "sf")
  expect_equal(attr(res, "method"), "grts")
  # Four height strata should exist in the draw
  expect_true(length(unique(res$strat_height)) >= 3)
  expect_true(all(res$strat_height %in% c("H1", "H2", "H3", "H4")))
})


test_that("create_sampling_plan degrades gracefully when GRTS fails", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  zone <- make_zone()
  chm  <- make_chm()

  # Force the GRTS branch to bail out by mocking the internal draw helper.
  local_mocked_bindings(
    .draw_grts = function(frame, allocation, n_over_per_stratum) NULL
  )
  res <- create_sampling_plan(zone, n_base = 10, n_over = 2,
                              chm = chm, seed = 7)
  expect_true(attr(res, "method") %in% c("lpm2", "random"))
  expect_equal(nrow(res), 12)
})


# ------------------------------------------------------------
# Constraint path: slope filter removes candidates
# ------------------------------------------------------------

test_that("max_slope constraint reduces the candidate frame", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  zone <- make_zone()
  # Slope gradient: steep on the west (x < 900500), gentle on the east.
  # Using init(fun="x") avoids row/col-ordering pitfalls in values<-.
  slope <- terra::rast(xmin = 899900, xmax = 901100,
                       ymin = 6499900, ymax = 6501100,
                       resolution = 10, crs = "EPSG:2154")
  xs <- terra::init(slope, fun = "x")
  slope[] <- ifelse(terra::values(xs) < 900500, 45, 5)

  res <- create_sampling_plan(zone, n_base = 30, n_over = 0,
                              slope = slope, max_slope = 30,
                              seed = 11)
  # Only the east half (x > 900500) should pass the max_slope filter.
  xs_pts <- sf::st_coordinates(res)[, "X"]
  expect_true(mean(xs_pts > 900500) >= 0.8)
})


# ------------------------------------------------------------
# Error surfaces
# ------------------------------------------------------------

test_that("create_sampling_plan rejects non-sf zones and non-positive n_base", {
  expect_error(
    create_sampling_plan(data.frame(x = 1), n_base = 5),
    "must be an sf"
  )
  expect_error(
    create_sampling_plan(make_zone(), n_base = 0),
    "n_base"
  )
})


# ------------------------------------------------------------
# Internal: allocation respects min_per_stratum and caps
# ------------------------------------------------------------

test_that(".allocate_per_stratum honors min_per_stratum and caps at counts", {
  counts <- c(A = 50, B = 50, C = 1)
  alloc  <- nemeton:::.allocate_per_stratum(counts, n_main = 20,
                                            min_per_stratum = 2)
  expect_equal(sum(alloc), 20)
  expect_true(alloc[["C"]] <= 1)      # cannot exceed stratum size
  expect_true(alloc[["A"]] >= 2)
  expect_true(alloc[["B"]] >= 2)
})
