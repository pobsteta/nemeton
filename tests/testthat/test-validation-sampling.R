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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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


test_that("create_validation_sampling_plan warns when no cell in control_classes (v0.49.1)", {
  skip_if_not_installed("terra")
  testthat::skip_if_not_installed("spsurvey")
  # Raster with only classes 3 and 4 (no class 0/1/2 at all).
  m <- matrix(0L, 10, 10)
  m[1:5, ] <- 3L
  m[6:10, ] <- 4L
  r <- terra::rast(m, crs = "EPSG:2154")
  terra::ext(r) <- terra::ext(0, 100, 0, 100)

  zone <- sf::st_as_sfc(sf::st_bbox(c(xmin = 0, ymin = 0,
                                      xmax = 100, ymax = 100), crs = 2154))
  zone <- sf::st_sf(geometry = zone)

  expect_warning(
    plan <- create_validation_sampling_plan(
      zone, r, n_validation = 4L, n_control = 3L,
      classes = c(3L, 4L), control_classes = c(0L), seed = 42L),
    regexp = "control_classes"
  )
  # Validation plots still drawn ; témoins absent.
  expect_true(all(plan$type == "Validation"))
})


test_that("create_validation_sampling_plan accepts relaxed control_classes (v0.49.1)", {
  skip_if_not_installed("terra")
  testthat::skip_if_not_installed("spsurvey")
  # Same raster (only classes 3, 4), but with control_classes = c(3L)
  # → the lower-priority alert cells become the controls.
  m <- matrix(0L, 10, 10)
  m[1:5, ] <- 3L
  m[6:10, ] <- 4L
  r <- terra::rast(m, crs = "EPSG:2154")
  terra::ext(r) <- terra::ext(0, 100, 0, 100)

  zone <- sf::st_as_sfc(sf::st_bbox(c(xmin = 0, ymin = 0,
                                      xmax = 100, ymax = 100), crs = 2154))
  zone <- sf::st_sf(geometry = zone)

  plan <- create_validation_sampling_plan(
    zone, r, n_validation = 4L, n_control = 3L,
    classes = c(4L), control_classes = c(3L), seed = 42L)
  expect_true(all(c("Validation", "Temoin") %in% unique(plan$type)))
  # alert_class of témoin rows should be 3 (the real cell value).
  expect_true(all(plan$alert_class[plan$type == "Temoin"] == 3L))
})


test_that("create_validation_sampling_plan with n_control=0 yields no Temoin", {
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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


# ---- RECONFORT broadleaf source (spec 021 G4) ------------------------

# 20x20 reconfort class raster: 1 sain (majority), 2 deperissant, 3 tres.
make_reconfort_raster_20x20 <- function(crs = "EPSG:2154") {
  m <- matrix(1L, 20, 20)
  m[9:10, 9:10] <- 3L
  m[8:11, 8:11][m[8:11, 8:11] == 1L] <- 2L
  r <- terra::rast(m, crs = crs)
  terra::ext(r) <- terra::ext(0, 200, 0, 200)
  r
}

test_that("create_validation_sampling_plan accepts source = 'RECONFORT'", {
  skip_if_not_installed("terra")
  testthat::skip_if_not_installed("spsurvey")
  r <- make_reconfort_raster_20x20()
  zone <- sf::st_sf(geometry = sf::st_as_sfc(sf::st_bbox(
    c(xmin = 0, ymin = 0, xmax = 200, ymax = 200), crs = 2154)))

  plan <- create_validation_sampling_plan(
    zone, r,
    n_validation = 6L, n_control = 3L,
    classes = c(2L, 3L), control_classes = c(1L),
    source = "RECONFORT", seed = 7L)

  expect_s3_class(plan, "sf")
  expect_true(all(plan$source == "RECONFORT"))
  expect_true(all(plan$alert_class[plan$type == "Temoin"] == 1L))
  expect_true(all(plan$alert_class[plan$type == "Validation"] %in% c(2L, 3L)))
  expect_true(all(plan$classes == "2,3"))
})


# ---- weighting = "continuous" (spec 014 A3 — parité FORDEAD/RECONFORT) ----

# 20x20 alert raster fully eligible (all class 3) — large frame for the
# statistical over-representation test.
make_full_alert_20x20 <- function(crs = "EPSG:2154") {
  r <- terra::rast(matrix(3L, 20, 20), crs = crs)
  terra::ext(r) <- terra::ext(0, 200, 0, 200)
  r
}
# Continuous severity gradient on the SAME grid: value = column index (1..20),
# so severity increases from left (1) to right (20).
make_weight_gradient_20x20 <- function(crs = "EPSG:2154") {
  m <- outer(seq_len(20), seq_len(20), function(i, j) j)   # [i, j] = j
  r <- terra::rast(m, crs = crs)
  terra::ext(r) <- terra::ext(0, 200, 0, 200)
  r
}
zone_200 <- function() sf::st_sf(geometry = sf::st_as_sfc(sf::st_bbox(
  c(xmin = 0, ymin = 0, xmax = 200, ymax = 200), crs = 2154)))

test_that("weighting='uniform' explicit == default (byte-identical, no alert_weight)", {
  skip_if_not_installed("terra")
  testthat::skip_if_not_installed("spsurvey")
  r <- make_alert_raster_20x20(); zone <- zone_200()
  p_def <- create_validation_sampling_plan(zone, r, n_validation = 6L,
                                           n_control = 2L, seed = 99L)
  p_uni <- create_validation_sampling_plan(zone, r, n_validation = 6L,
                                           n_control = 2L, weighting = "uniform",
                                           seed = 99L)
  expect_equal(sf::st_coordinates(p_def), sf::st_coordinates(p_uni))
  expect_identical(names(p_def), names(p_uni))
  expect_false("alert_weight" %in% names(p_def))   # uniform : schéma inchangé
})

test_that("weighting='continuous' over-represents high-severity cells", {
  skip_if_not_installed("terra")
  testthat::skip_if_not_installed("spsurvey")
  alert  <- make_full_alert_20x20()
  weight <- make_weight_gradient_20x20()
  plan <- create_validation_sampling_plan(
    zone_200(), alert, n_validation = 40L, n_control = 0L,
    classes = c(3L), weighting = "continuous", weight_raster = weight,
    seed = 7L)
  expect_true("alert_weight" %in% names(plan))
  vw <- plan$alert_weight[plan$type == "Validation"]
  # Frame mean severity = mean(1:20) = 10.5 ; inclusion ∝ severity pushes the
  # drawn mean well above it (E ≈ 14). Deterministic under the fixed seed.
  expect_gt(mean(vw), 12)
})

test_that("weighting='continuous' aligns a weight_raster on a different grid", {
  skip_if_not_installed("terra")
  testthat::skip_if_not_installed("spsurvey")
  alert <- make_full_alert_20x20()               # 10 m grid
  # Coarser weight raster (40 m), same extent/CRS -> must be resampled, not error.
  m <- outer(seq_len(5), seq_len(5), function(i, j) j)
  weight <- terra::rast(m, crs = "EPSG:2154")
  terra::ext(weight) <- terra::ext(0, 200, 0, 200)
  plan <- create_validation_sampling_plan(
    zone_200(), alert, n_validation = 10L, n_control = 0L,
    classes = c(3L), weighting = "continuous", weight_raster = weight,
    seed = 3L)
  expect_s3_class(plan, "sf")
  expect_true(all(is.finite(plan$alert_weight[plan$type == "Validation"])))
})

test_that("weighting='continuous' errors on a constant weight raster", {
  skip_if_not_installed("terra")
  alert  <- make_full_alert_20x20()
  weight <- alert; terra::values(weight) <- 5      # constant over alert cells
  expect_error(
    create_validation_sampling_plan(
      zone_200(), alert, n_validation = 5L, n_control = 0L,
      classes = c(3L), weighting = "continuous", weight_raster = weight),
    class = "nemeton_empty_alert_mask")
})

test_that("weighting='continuous' errors on an all-NA weight raster", {
  skip_if_not_installed("terra")
  alert  <- make_full_alert_20x20()
  weight <- terra::rast(matrix(NA_real_, 20, 20), crs = "EPSG:2154")
  terra::ext(weight) <- terra::ext(0, 200, 0, 200)
  expect_error(
    create_validation_sampling_plan(
      zone_200(), alert, n_validation = 5L, n_control = 0L,
      classes = c(3L), weighting = "continuous", weight_raster = weight),
    class = "nemeton_empty_alert_mask")
})

test_that("weighting='continuous' requires weight_raster (explicit error, no fallback)", {
  skip_if_not_installed("terra")
  expect_error(
    create_validation_sampling_plan(
      zone_200(), make_full_alert_20x20(), n_validation = 5L,
      classes = c(3L), weighting = "continuous"),
    regexp = "weight_raster")
})

test_that("weighting='continuous' aborts on an unreconcilable CRS", {
  skip_if_not_installed("terra")
  alert  <- make_full_alert_20x20()
  weight <- make_weight_gradient_20x20()
  terra::crs(weight) <- ""                          # no CRS -> not alignable
  expect_error(
    create_validation_sampling_plan(
      zone_200(), alert, n_validation = 5L, n_control = 0L,
      classes = c(3L), weighting = "continuous", weight_raster = weight),
    class = "validation_weight_raster_mismatch")
})

test_that("weighting='continuous' assembles Validation + Temoin with alert_weight on both", {
  skip_if_not_installed("terra")
  testthat::skip_if_not_installed("spsurvey")
  alert  <- make_alert_raster_20x20()             # class 0 background + 3/4 cluster
  weight <- make_weight_gradient_20x20()          # continuous severity, same grid
  plan <- create_validation_sampling_plan(
    zone_200(), alert, n_validation = 6L, n_control = 3L,
    classes = c(3L, 4L), control_classes = c(0L),
    weighting = "continuous", weight_raster = weight, seed = 11L)
  expect_true(all(c("Validation", "Temoin") %in% unique(plan$type)))
  expect_true("alert_weight" %in% names(plan))
  expect_true(all(is.finite(plan$alert_weight)))   # renseigné sur les 2 types
})
