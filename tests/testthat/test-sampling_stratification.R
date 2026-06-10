# test-sampling_stratification.R — CHM / MNT NA filter (v0.25.1)
#
# Reported from nemetonshiny@v0.35.0 :
#   create_sampling_plan() with CHM × MNT stratification on a partial-
#   coverage raster failed with
#     "le tableau de remplacement a 363 lignes, le tableau remplacé en
#      a 337"
#   when grts() silently dropped the candidates whose mean_height /
#   mean_tpi was NA.
#
# Fix : drop NA candidates BEFORE .stratify() runs, with a cli warn
# when reduction > 10 % and a cli abort when remaining pool < n_base.

skip_if_no_terra <- function() {
  testthat::skip_if_not_installed("terra")
  skip_if_terra_write_broken()
}
skip_if_no_sf <- function() {
  testthat::skip_if_not_installed("sf")
}
skip_if_no_exactextractr <- function() {
  testthat::skip_if_not_installed("exactextractr")
}

# 1 km × 1 km AOI in EPSG:2154.
.make_aoi <- function() {
  sf::st_sf(geometry = sf::st_sfc(sf::st_polygon(list(rbind(
    c(900000, 6500000), c(901000, 6500000),
    c(901000, 6501000), c(900000, 6501000),
    c(900000, 6500000)
  ))), crs = 2154))
}

# CHM that covers ONLY the western half of the AOI — eastern half is
# NA. With grid_step = 50 we have ~441 candidates total, ~221 with a
# CHM value and ~220 with NA.
.make_partial_chm <- function() {
  r <- terra::rast(xmin = 899900, xmax = 900500,   # only western half
                   ymin = 6499900, ymax = 6501100,
                   resolution = 10, crs = "EPSG:2154")
  terra::values(r) <- runif(terra::ncell(r), 5, 30)
  r
}

# MNT that covers the same partial extent as the CHM.
.make_partial_mnt <- function() {
  r <- terra::rast(xmin = 899900, xmax = 900500,
                   ymin = 6499900, ymax = 6501100,
                   resolution = 10, crs = "EPSG:2154")
  terra::values(r) <- runif(terra::ncell(r), 100, 500)
  r
}

# Full-coverage CHM (every candidate has a non-NA value).
.make_full_chm <- function() {
  r <- terra::rast(xmin = 899900, xmax = 901100,
                   ymin = 6499900, ymax = 6501100,
                   resolution = 10, crs = "EPSG:2154")
  terra::values(r) <- runif(terra::ncell(r), 5, 30)
  r
}


# ---- 1. Bug reproducer ------------------------------------------------

test_that("create_sampling_plan() succeeds with a partial CHM (bug reproducer)", {
  skip_if_no_sf(); skip_if_no_terra(); skip_if_no_exactextractr()
  skip_if_not_installed("spsurvey")

  aoi <- .make_aoi()
  chm <- .make_partial_chm()

  # Drop the > 10 % reduction warning and the n_base clamp warning.
  res <- suppressWarnings(
    create_sampling_plan(aoi, n_base = 50L, n_over = 10L,
                         chm = chm, seed = 42L)
  )

  expect_s3_class(res, "sf")
  # Plan generated successfully — no 363/337 error.
  expect_gt(nrow(res), 0L)
  expect_true("plot_id" %in% names(res))
  expect_true(all(res$type %in% c("Base", "Over")))
})


# ---- 2. Warning emitted when reduction > 10 % -------------------------

test_that("create_sampling_plan() warns when CHM filter drops > 10 % of pool", {
  skip_if_no_sf(); skip_if_no_terra(); skip_if_no_exactextractr()

  aoi <- .make_aoi()
  chm <- .make_partial_chm()

  # Collect every warning. We can't use expect_warning() directly
  # because the clamp may also fire — we assert on the strat-warn
  # message specifically.
  msgs <- character(0)
  withCallingHandlers(
    create_sampling_plan(aoi, n_base = 20L, n_over = 5L,
                         chm = chm, seed = 42L),
    warning = function(w) {
      msgs <<- c(msgs, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_true(any(grepl("Stratification filter removed", msgs)))
})


# ---- 3. Abort when pool < n_base --------------------------------------

test_that("create_sampling_plan() aborts when CHM filter leaves pool < n_base", {
  skip_if_no_sf(); skip_if_no_terra(); skip_if_no_exactextractr()

  aoi <- .make_aoi()
  chm <- .make_partial_chm()  # ~half the AOI is NA, ~220 valid candidates

  # Request more base plots than the stratification-valid pool can
  # accommodate.
  expect_error(
    suppressWarnings(
      create_sampling_plan(aoi, n_base = 500L, n_over = 100L,
                           chm = chm, seed = 42L)
    ),
    "Stratification-valid candidate pool"
  )
})


# ---- 4. Regression guard: no stratification ---------------------------

test_that("create_sampling_plan() unchanged when chm = NULL and mnt = NULL", {
  skip_if_no_sf()
  aoi <- .make_aoi()

  res <- suppressWarnings(
    create_sampling_plan(aoi, n_base = 10L, n_over = 3L, seed = 1L)
  )

  expect_s3_class(res, "sf")
  expect_equal(nrow(res), 13L)
  expect_setequal(unique(res$type), c("Base", "Over"))
  # No stratification → method should be lpm2 or random.
  expect_true(attr(res, "method") %in% c("lpm2", "random"))
})


# ---- 5bis. Regression: overlapping BD Forêt polygons (v0.25.2) --------

# Build a forest_mask sf with TWO polygons that overlap the AOI. A
# candidate falling on the overlap should NOT inflate the strat_type
# vector (pre-v0.25.2 this caused sf::st_join() to return multi-rows
# and `frame$strat_type <- ...` crashed with "le tableau de remplacement
# a X lignes, le tableau remplacé en a Y").
.make_overlapping_forest_mask <- function() {
  poly_a <- sf::st_polygon(list(rbind(
    c(900000, 6500000), c(900700, 6500000),
    c(900700, 6500700), c(900000, 6500700),
    c(900000, 6500000)
  )))
  poly_b <- sf::st_polygon(list(rbind(
    c(900300, 6500300), c(901000, 6500300),
    c(901000, 6501000), c(900300, 6501000),
    c(900300, 6500300)
  )))
  sf::st_sf(
    tfv = c("Feuillus", "Conifères"),
    geometry = sf::st_sfc(poly_a, poly_b, crs = 2154)
  )
}


test_that("create_sampling_plan() handles overlapping BD Foret polygons", {
  skip_if_no_sf(); skip_if_no_terra(); skip_if_no_exactextractr()
  skip_if_not_installed("spsurvey")

  aoi <- .make_aoi()
  chm <- .make_full_chm()
  forest_mask <- .make_overlapping_forest_mask()

  # This should not raise the "le tableau de remplacement a 363 lignes,
  # le tableau remplacé en a 337" error from base R's [<-.data.frame.
  res <- suppressWarnings(
    create_sampling_plan(aoi, n_base = 12L, n_over = 4L,
                         chm = chm, forest_mask = forest_mask,
                         seed = 42L)
  )

  expect_s3_class(res, "sf")
  expect_gt(nrow(res), 0L)
  # strat_type should be one of the BD Forêt classes (FEU / CON) — the
  # first-match rule means a candidate on the overlap picks one of the
  # two polygons (deterministic given the spatial index but order not
  # tested here).
  expect_true(all(res$strat_type %in% c("FEU", "CON", "MIX", "POP", "AUT")))
})


# ---- 5. Regression guard: full-coverage CHM doesn't trigger filter ----

test_that("create_sampling_plan() does not warn when CHM covers the full AOI", {
  skip_if_no_sf(); skip_if_no_terra(); skip_if_no_exactextractr()
  skip_if_not_installed("spsurvey")

  aoi <- .make_aoi()
  chm <- .make_full_chm()

  # No "Stratification filter removed" warning should fire. Other
  # warnings (e.g. PROJ deprecations) are tolerated — we check the
  # specific message is absent.
  msgs <- character(0)
  withCallingHandlers(
    suppressMessages(create_sampling_plan(aoi, n_base = 16L, n_over = 4L,
                                          chm = chm, seed = 42L)),
    warning = function(w) {
      msgs <<- c(msgs, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_false(any(grepl("Stratification filter removed", msgs)))
})
