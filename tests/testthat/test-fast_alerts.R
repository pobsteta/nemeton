# test-fast_alerts.R — list_fast_alerts_for_zone() (E6.f.5, v0.25.0)
#
# The function is split between a SQL aggregation (mocked here via
# DBI::dbGetQuery) and an R-side severity classifier + sf POINT
# assembly. The mock returns synthetic raw rows so we exercise the
# pure R logic offline.

skip_if_no_sf <- function() {
  testthat::skip_if_not_installed("sf")
}

make_fake_con <- function() {
  structure(list(), class = c("FakeConnection", "DBIConnection"))
}

# Three plots in roughly Strasbourg vicinity (EPSG:4326).
.fake_raw_alerts_rows <- function() {
  data.frame(
    plot_id       = c("P_CRIT",  "P_WARN",  "P_INFO",  "P_SAFE"),
    geom_wkt      = c("POINT(7.71 48.51)", "POINT(7.72 48.52)",
                      "POINT(7.73 48.53)", "POINT(7.74 48.54)"),
    last_obs_date = as.Date(c("2025-06-10","2025-06-12",
                              "2025-06-08","2025-06-14")),
    # threshold_ndvi = 0.40 → critical: < 0.20 ; warning: 0.20..0.40 ;
    # info: 0.40..0.44 ; safe: >= 0.44.
    ndvi_value    = c(0.10, 0.30, 0.42, 0.55),
    # threshold_nbr = 0.30 → keep all four plots above their respective
    # NBR threshold so severity is driven by NDVI ratio.
    nbr_value     = c(0.40, 0.40, 0.40, 0.40),
    stringsAsFactors = FALSE
  )
}


test_that("classifies severities correctly and drops the safe plot", {
  skip_if_no_sf()
  testthat::local_mocked_bindings(
    dbGetQuery   = function(conn, statement, ...) .fake_raw_alerts_rows(),
    dbQuoteLiteral = function(conn, x, ...) {
      if (inherits(x, "Date")) return(sprintf("'%s'", as.character(x)))
      sprintf("'%s'", as.character(x))
    },
    .package = "DBI"
  )

  out <- list_fast_alerts_for_zone(
    make_fake_con(), zone_id = 1L,
    date_from = "2025-06-01", date_to = "2025-06-30"
  )

  expect_s3_class(out, "sf")
  expect_identical(sf::st_crs(out)$epsg, 4326L)
  expect_true(all(sf::st_geometry_type(out, by_geometry = TRUE) == "POINT"))

  # Three plots in the alert zone, P_SAFE dropped.
  expect_equal(nrow(out), 3L)
  expect_false("P_SAFE" %in% out$plot_id)

  by_plot <- setNames(as.character(out$severity), out$plot_id)
  expect_identical(by_plot[["P_CRIT"]], "critical")
  expect_identical(by_plot[["P_WARN"]], "warning")
  expect_identical(by_plot[["P_INFO"]], "info")
})


test_that("severity is the worse of NDVI and NBR ratios", {
  skip_if_no_sf()
  rows <- data.frame(
    plot_id       = c("MIX_A", "MIX_B"),
    geom_wkt      = c("POINT(0 0)", "POINT(1 1)"),
    last_obs_date = as.Date(c("2025-06-10", "2025-06-10")),
    # MIX_A: NDVI safe (0.55 / 0.40 = 1.375), NBR critical (0.10 / 0.30 = 0.33).
    # MIX_B: NDVI warning (0.30 / 0.40 = 0.75), NBR info (0.31 / 0.30 = 1.03).
    ndvi_value    = c(0.55, 0.30),
    nbr_value     = c(0.10, 0.31),
    stringsAsFactors = FALSE
  )
  testthat::local_mocked_bindings(
    dbGetQuery   = function(conn, statement, ...) rows,
    dbQuoteLiteral = function(conn, x, ...) sprintf("'%s'", as.character(x)),
    .package = "DBI"
  )
  out <- list_fast_alerts_for_zone(
    make_fake_con(), zone_id = 1L,
    date_from = "2025-06-01", date_to = "2025-06-30"
  )
  by_plot <- setNames(as.character(out$severity), out$plot_id)
  expect_identical(by_plot[["MIX_A"]], "critical")  # NBR drives
  expect_identical(by_plot[["MIX_B"]], "warning")   # NDVI drives (worse)
})


test_that("computes ndvi_drop / nbr_drop only when value is below threshold", {
  skip_if_no_sf()
  rows <- data.frame(
    plot_id       = "P_W",
    geom_wkt      = "POINT(0 0)",
    last_obs_date = as.Date("2025-06-10"),
    ndvi_value    = 0.32,
    nbr_value     = 0.28,
    stringsAsFactors = FALSE
  )
  testthat::local_mocked_bindings(
    dbGetQuery   = function(conn, statement, ...) rows,
    dbQuoteLiteral = function(conn, x, ...) sprintf("'%s'", as.character(x)),
    .package = "DBI"
  )
  out <- list_fast_alerts_for_zone(
    make_fake_con(), zone_id = 1L,
    date_from = "2025-06-01", date_to = "2025-06-30"
  )
  expect_equal(nrow(out), 1L)
  expect_equal(out$ndvi_drop, 0.08, tolerance = 1e-9)  # 0.40 - 0.32
  expect_equal(out$nbr_drop,  0.02, tolerance = 1e-9)  # 0.30 - 0.28
})


test_that("returns an empty sf with stable schema when no plot is in alert", {
  skip_if_no_sf()
  rows <- data.frame(
    plot_id       = "P_SAFE",
    geom_wkt      = "POINT(0 0)",
    last_obs_date = as.Date("2025-06-10"),
    ndvi_value    = 0.99,
    nbr_value     = 0.99,
    stringsAsFactors = FALSE
  )
  testthat::local_mocked_bindings(
    dbGetQuery   = function(conn, statement, ...) rows,
    dbQuoteLiteral = function(conn, x, ...) sprintf("'%s'", as.character(x)),
    .package = "DBI"
  )
  out <- list_fast_alerts_for_zone(
    make_fake_con(), zone_id = 1L,
    date_from = "2025-06-01", date_to = "2025-06-30"
  )
  expect_s3_class(out, "sf")
  expect_equal(nrow(out), 0L)
  expect_named(
    out,
    c("plot_id", "last_obs_date", "ndvi_value", "nbr_value",
      "ndvi_drop", "nbr_drop", "severity", "geometry"),
    ignore.order = TRUE
  )
  expect_identical(sf::st_crs(out)$epsg, 4326L)
})


test_that("returns empty sf when SQL yields zero rows", {
  skip_if_no_sf()
  testthat::local_mocked_bindings(
    dbGetQuery   = function(conn, statement, ...) {
      .fake_raw_alerts_rows()[0L, , drop = FALSE]
    },
    dbQuoteLiteral = function(conn, x, ...) sprintf("'%s'", as.character(x)),
    .package = "DBI"
  )
  out <- list_fast_alerts_for_zone(
    make_fake_con(), zone_id = 1L,
    date_from = "2025-06-01", date_to = "2025-06-30"
  )
  expect_s3_class(out, "sf")
  expect_equal(nrow(out), 0L)
})


test_that("a plot with no observation (NA values) is excluded", {
  skip_if_no_sf()
  rows <- data.frame(
    plot_id       = c("P_NO_OBS", "P_CRIT"),
    geom_wkt      = c("POINT(0 0)", "POINT(1 1)"),
    last_obs_date = as.Date(c(NA, "2025-06-10")),
    ndvi_value    = c(NA_real_, 0.10),
    nbr_value     = c(NA_real_, 0.40),
    stringsAsFactors = FALSE
  )
  testthat::local_mocked_bindings(
    dbGetQuery   = function(conn, statement, ...) rows,
    dbQuoteLiteral = function(conn, x, ...) sprintf("'%s'", as.character(x)),
    .package = "DBI"
  )
  out <- list_fast_alerts_for_zone(
    make_fake_con(), zone_id = 1L,
    date_from = "2025-06-01", date_to = "2025-06-30"
  )
  expect_equal(nrow(out), 1L)
  expect_identical(out$plot_id, "P_CRIT")
})


# ---- input validation ------------------------------------------------

test_that("rejects non-DBI con", {
  expect_error(
    list_fast_alerts_for_zone("nope", 1L,
                              date_from = "2025-01-01",
                              date_to   = "2025-06-30"),
    "DBI"
  )
})

test_that("rejects missing date bounds", {
  expect_error(
    list_fast_alerts_for_zone(make_fake_con(), 1L),
    "date_from"
  )
})

test_that("rejects date_from > date_to", {
  expect_error(
    list_fast_alerts_for_zone(make_fake_con(), 1L,
                              date_from = "2025-07-01",
                              date_to   = "2025-06-01"),
    "<="
  )
})

test_that("rejects negative thresholds", {
  expect_error(
    list_fast_alerts_for_zone(make_fake_con(), 1L,
                              threshold_ndvi = -0.1,
                              date_from = "2025-06-01",
                              date_to   = "2025-06-30"),
    "threshold_ndvi"
  )
})

test_that("rejects window_days < 1", {
  expect_error(
    list_fast_alerts_for_zone(make_fake_con(), 1L,
                              window_days = 0L,
                              date_from = "2025-06-01",
                              date_to   = "2025-06-30"),
    "window_days"
  )
})
