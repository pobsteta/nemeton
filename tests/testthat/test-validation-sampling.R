# test-validation-sampling.R — spec 014 A2+A3: weighted GRTS draw +
# create_validation_sampling_plan() entry point.

# Helper: build a 20x20 categorical raster with a known cluster of
# class 4 cells in the centre, ringed by class 3, then class 0
# (healthy) around. Total: 4 class-4 cells, 12 class-3 cells,
# 384 class-0 cells.
make_alert_raster_20x20 <- function(crs = "EPSG:2154") {
  m <- matrix(0L, 20, 20)
  m[9:10, 9:10] <- 4L
  m[8:11, 8:11][m[8:11, 8:11] == 0L] <- 3L
  r <- terra::rast(m, crs = crs)
  terra::ext(r) <- terra::ext(0, 200, 0, 200)  # 10m pixels
  r
}


# ---- unit: create_validation_sampling_plan input validation ----------

test_that("create_validation_sampling_plan rejects bad inputs", {
  r <- make_alert_raster_20x20()
  zone <- sf::st_as_sfc(sf::st_bbox(c(xmin = 0, ymin = 0,
                                      xmax = 200, ymax = 200), crs = 2154))
  zone <- sf::st_sf(geometry = zone)

  expect_error(create_validation_sampling_plan(
    "not-an-sf", r, n_validation = 5L),
    regexp = "sf / sfc"
  )
  expect_error(create_validation_sampling_plan(
    zone, matrix(1, 4, 4), n_validation = 5L),
    regexp = "SpatRaster"
  )
  expect_error(create_validation_sampling_plan(
    zone, r, n_validation = 0L),
    regexp = ">= 1"
  )
  expect_error(create_validation_sampling_plan(
    zone, r, n_validation = 5L, n_control = -1L),
    regexp = ">= 0"
  )
  expect_error(create_validation_sampling_plan(
    zone, r, n_validation = 5L, seed = c(1, 2)),
    regexp = "single integer"
  )
})


# ---- integration: GRTS-based draws (requires spsurvey) ---------------

test_that("create_validation_sampling_plan returns Validation + Temoin", {
  testthat::skip_if_not_installed("spsurvey")
  r <- make_alert_raster_20x20()
  zone <- sf::st_as_sfc(sf::st_bbox(c(xmin = 0, ymin = 0,
                                      xmax = 200, ymax = 200), crs = 2154))
  zone <- sf::st_sf(geometry = zone)

  plan <- create_validation_sampling_plan(
    zone, r,
    n_validation = 8L, n_control = 4L,
    classes = c(3L, 4L), source = "FORDEAD", seed = 42L)

  expect_s3_class(plan, "sf")
  expect_true(all(c("plot_id", "type", "alert_class", "visit_order",
                    "source", "classes", "seed") %in% names(plan)))
  # Both types must be present.
  expect_true(all(c("Validation", "Temoin") %in% unique(plan$type)))
  # Témoins are on class 0.
  expect_true(all(plan$alert_class[plan$type == "Temoin"] == 0L))
  # Validation plots are on alert classes (3 or 4).
  vc <- plan$alert_class[plan$type == "Validation"]
  expect_true(all(vc %in% c(3L, 4L)))
  # Source / classes / seed echoed.
  expect_true(all(plan$source == "FORDEAD"))
  expect_true(all(plan$classes == "3,4"))
  expect_true(all(plan$seed == 42L))
  # visit_order is a permutation of 1..N.
  expect_setequal(plan$visit_order, seq_len(nrow(plan)))
})


test_that("create_validation_sampling_plan errors on empty alert mask", {
  testthat::skip_if_not_installed("spsurvey")
  # Healthy zone — no class 3 or 4 anywhere.
  m <- matrix(0L, 10, 10)
  r <- terra::rast(m, crs = "EPSG:2154")
  terra::ext(r) <- terra::ext(0, 100, 0, 100)
  zone <- sf::st_as_sfc(sf::st_bbox(c(xmin = 0, ymin = 0,
                                      xmax = 100, ymax = 100), crs = 2154))
  zone <- sf::st_sf(geometry = zone)

  expect_error(
    create_validation_sampling_plan(zone, r, n_validation = 5L),
    class = "nemeton_empty_alert_mask"
  )
})


test_that("create_validation_sampling_plan weighting favours higher classes", {
  # On a frame with equal counts of class 3 and class 4, the weighted
  # GRTS allocates n proportionally to class value: 4 / (3+4) for
  # class 4. With n = 14, expect ~6 class-3 and ~8 class-4.
  testthat::skip_if_not_installed("spsurvey")
  m <- matrix(0L, 10, 10)
  m[1:5, ] <- 3L      # 50 cells of class 3
  m[6:10, ] <- 4L     # 50 cells of class 4
  r <- terra::rast(m, crs = "EPSG:2154")
  terra::ext(r) <- terra::ext(0, 100, 0, 100)
  zone <- sf::st_as_sfc(sf::st_bbox(c(xmin = 0, ymin = 0,
                                      xmax = 100, ymax = 100), crs = 2154))
  zone <- sf::st_sf(geometry = zone)

  plan <- create_validation_sampling_plan(
    zone, r,
    n_validation = 14L, n_control = 0L,
    classes = c(3L, 4L), seed = 1L)

  tbl <- table(plan$alert_class[plan$type == "Validation"])
  # Class 4 should have more points than class 3.
  expect_true(as.integer(tbl["4"]) >= as.integer(tbl["3"]))
})


test_that("create_validation_sampling_plan with n_control=0 yields no Temoin", {
  testthat::skip_if_not_installed("spsurvey")
  r <- make_alert_raster_20x20()
  zone <- sf::st_as_sfc(sf::st_bbox(c(xmin = 0, ymin = 0,
                                      xmax = 200, ymax = 200), crs = 2154))
  zone <- sf::st_sf(geometry = zone)

  plan <- create_validation_sampling_plan(
    zone, r, n_validation = 4L, n_control = 0L, seed = 42L)

  expect_true(all(plan$type == "Validation"))
})


test_that("create_validation_sampling_plan is reproducible with seed", {
  testthat::skip_if_not_installed("spsurvey")
  r <- make_alert_raster_20x20()
  zone <- sf::st_as_sfc(sf::st_bbox(c(xmin = 0, ymin = 0,
                                      xmax = 200, ymax = 200), crs = 2154))
  zone <- sf::st_sf(geometry = zone)

  p1 <- create_validation_sampling_plan(
    zone, r, n_validation = 5L, n_control = 2L, seed = 123L)
  p2 <- create_validation_sampling_plan(
    zone, r, n_validation = 5L, n_control = 2L, seed = 123L)
  # Same geometries in same order (post-TSP).
  expect_equal(sf::st_coordinates(p1), sf::st_coordinates(p2))
})
