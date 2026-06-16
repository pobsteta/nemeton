# test-trend-sanitary-plan.R — spec 025: sanitary plot plan on the FAST
# `trend` raster. Continuous-probability GRTS weighted by |slope|, control
# plots on stable cells, NO TSP, NO link to terrain/inventory plots.

# A synthetic continuous trend raster (EPSG:2154, 10 m): declines of varying
# magnitude (value > 0), a stable background (0) and an NA block (too few
# years). 26 decline cells, plenty of stable cells.
make_trend_raster <- function(crs = "EPSG:2154") {
  m <- matrix(0, 20, 20)
  m[5:8, 5:8]    <- 0.02     # 16 cells, mild decline
  m[10:12, 10:12] <- 0.035   # 9 cells, stronger
  m[15, 15]      <- 0.05     # 1 cell, steepest
  m[2:3, 2:3]    <- NA       # too few years -> excluded from both
  r <- terra::rast(m, crs = crs)
  terra::ext(r) <- terra::ext(0, 200, 0, 200)
  names(r) <- "alert_trend"
  r
}

.fake_con <- function() structure(list(), class = c("FakeConn", "DBIConnection"))


# ---- input validation (before any raster read) -----------------------

test_that("create_trend_sanitary_plan rejects bad inputs", {
  skip_if_not_installed("terra")
  expect_error(
    create_trend_sanitary_plan(.fake_con(), 1L, "2017-01-01", "2024-12-31",
                               cache_dir = ".", n_plots = 0L),
    ">= 1")
  expect_error(
    create_trend_sanitary_plan(.fake_con(), 1L, "2017-01-01", "2024-12-31",
                               cache_dir = ".", n_control = -1L),
    ">= 0")
  expect_error(
    create_trend_sanitary_plan(.fake_con(), 1L, "2017-01-01", "2024-12-31",
                               cache_dir = ".", seed = c(1, 2)),
    "single integer")
})


# ---- the continuous-probability helper -------------------------------

test_that(".draw_grts_continuous draws from the >0 cells, weighted", {
  skip_if_not_installed("terra")
  skip_if_not_installed("spsurvey")
  r <- make_trend_raster()
  priority <- terra::ifel(r > 0, r, NA_real_)

  pts <- nemeton:::.draw_grts_continuous(priority, n = 10L, seed = 7L)
  expect_s3_class(pts, "sf")
  expect_true("alert_value" %in% names(pts))
  expect_lte(nrow(pts), 10L)
  expect_true(all(pts$alert_value > 0))           # only decline cells
})


# ---- the full plan ----------------------------------------------------

test_that("create_trend_sanitary_plan returns Sanitaire + Temoin, no TSP", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("spsurvey")
  testthat::local_mocked_bindings(
    read_fast_alert_raster = function(con, zone_id, ...) make_trend_raster(),
    .package = "nemeton")

  plan <- suppressMessages(create_trend_sanitary_plan(
    .fake_con(), zone_id = 1L, index = "NDRE",
    date_from = "2017-01-01", date_to = "2024-12-31",
    cache_dir = ".", n_plots = 10L, n_control = 5L, seed = 42L))

  expect_s3_class(plan, "sf")
  # No TSP / terrain coupling.
  expect_false("visit_order" %in% names(plan))
  expect_setequal(names(plan),
                  c("plot_id", "type", "alert_value", "index", "source",
                    "seed", "geometry"))
  expect_setequal(unique(plan$type), c("Sanitaire", "Temoin"))
  expect_true(all(plan$source == "FAST_TREND"))
  expect_true(all(plan$index == "NDRE"))

  san <- plan[plan$type == "Sanitaire", ]
  tem <- plan[plan$type == "Temoin", ]
  expect_true(all(grepl("^S\\d{2}$", san$plot_id)))
  expect_true(all(grepl("^T\\d{2}$", tem$plot_id)))
  # Sanitary plots: positive severity, ordered DESCENDING (S01 = steepest).
  expect_true(all(san$alert_value > 0))
  expect_true(all(diff(san$alert_value) <= 0))
  expect_identical(san$plot_id[1], "S01")
  # Controls: stable cells -> value 0.
  expect_true(all(tem$alert_value == 0))
})


test_that("create_trend_sanitary_plan is reproducible with a seed", {
  skip_if_not_installed("terra")
  skip_if_not_installed("spsurvey")
  testthat::local_mocked_bindings(
    read_fast_alert_raster = function(con, zone_id, ...) make_trend_raster(),
    .package = "nemeton")
  p1 <- suppressMessages(create_trend_sanitary_plan(
    .fake_con(), 1L, "2017-01-01", "2024-12-31", cache_dir = ".",
    n_plots = 8L, n_control = 3L, seed = 99L))
  p2 <- suppressMessages(create_trend_sanitary_plan(
    .fake_con(), 1L, "2017-01-01", "2024-12-31", cache_dir = ".",
    n_plots = 8L, n_control = 3L, seed = 99L))
  expect_equal(sf::st_coordinates(p1), sf::st_coordinates(p2))
})


# ---- edge cases: typed error -----------------------------------------

test_that("create_trend_sanitary_plan errors typed when no decline", {
  skip_if_not_installed("terra")
  # All-stable raster (only 0 / NA) -> no significant decline.
  flat <- make_trend_raster()
  terra::values(flat)[!is.na(terra::values(flat))] <- 0
  testthat::local_mocked_bindings(
    read_fast_alert_raster = function(con, zone_id, ...) flat,
    .package = "nemeton")
  expect_error(
    create_trend_sanitary_plan(.fake_con(), 1L, "2017-01-01", "2024-12-31",
                               cache_dir = ".", n_plots = 5L),
    class = "nemeton_empty_alert_mask")
})


test_that("create_trend_sanitary_plan errors typed when raster is NULL", {
  skip_if_not_installed("terra")
  testthat::local_mocked_bindings(
    read_fast_alert_raster = function(con, zone_id, ...) NULL,
    .package = "nemeton")
  expect_error(
    create_trend_sanitary_plan(.fake_con(), 1L, "2017-01-01", "2024-12-31",
                               cache_dir = ".", n_plots = 5L),
    class = "nemeton_empty_alert_mask")
})


test_that("create_trend_sanitary_plan: n_control = 0 -> sanitary only", {
  skip_if_not_installed("terra")
  skip_if_not_installed("spsurvey")
  testthat::local_mocked_bindings(
    read_fast_alert_raster = function(con, zone_id, ...) make_trend_raster(),
    .package = "nemeton")
  plan <- suppressMessages(create_trend_sanitary_plan(
    .fake_con(), 1L, "2017-01-01", "2024-12-31", cache_dir = ".",
    n_plots = 6L, n_control = 0L, seed = 1L))
  expect_setequal(unique(plan$type), "Sanitaire")
})
