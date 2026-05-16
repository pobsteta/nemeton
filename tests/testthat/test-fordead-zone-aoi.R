# test-fordead-zone-aoi.R — .get_zone_aoi() helper (spec 008 §13.6)
#
# Pure DB+sf logic, no Python. Mocks DBI::dbGetQuery to avoid needing
# an actual database connection.

skip_if_no_sf <- function() {
  testthat::skip_if_not_installed("sf")
}

make_fake_con <- function() {
  structure(list(), class = c("FakeConnection", "DBIConnection"))
}


test_that(".get_zone_aoi returns sf POLYGON in EPSG:2154 from monitoring_zone", {
  skip_if_no_sf()
  # zone stored in 4326, polygon over Strasbourg vicinity
  wkt_4326 <- "POLYGON((7.7 48.5, 7.8 48.5, 7.8 48.6, 7.7 48.6, 7.7 48.5))"

  testthat::local_mocked_bindings(
    dbGetQuery = function(conn, statement, ...) {
      data.frame(id       = 1L,
                 zone_wkt = wkt_4326,
                 crs_epsg = 4326L,
                 stringsAsFactors = FALSE)
    },
    .package = "DBI"
  )

  aoi <- nemeton:::.get_zone_aoi(make_fake_con(), 1L)
  expect_s3_class(aoi, "sf")
  expect_identical(sf::st_crs(aoi)$epsg, 2154L)
})


test_that(".get_zone_aoi keeps the CRS unchanged when already 2154", {
  skip_if_no_sf()
  wkt_l93 <- "POLYGON((1000000 6800000, 1000100 6800000, 1000100 6800100, 1000000 6800100, 1000000 6800000))"

  testthat::local_mocked_bindings(
    dbGetQuery = function(conn, statement, ...) {
      data.frame(id       = 7L,
                 zone_wkt = wkt_l93,
                 crs_epsg = 2154L,
                 stringsAsFactors = FALSE)
    },
    .package = "DBI"
  )

  aoi <- nemeton:::.get_zone_aoi(make_fake_con(), 7L)
  expect_identical(sf::st_crs(aoi)$epsg, 2154L)
})


test_that(".get_zone_aoi aborts on unknown zone_id", {
  skip_if_no_sf()

  testthat::local_mocked_bindings(
    dbGetQuery = function(conn, statement, ...) {
      data.frame(id = integer(0), zone_wkt = character(0),
                 crs_epsg = integer(0))
    },
    .package = "DBI"
  )

  expect_error(
    nemeton:::.get_zone_aoi(make_fake_con(), 999L),
    "Unknown monitoring zone"
  )
})


test_that(".get_zone_aoi rejects non-DBI con", {
  expect_error(
    nemeton:::.get_zone_aoi("not-a-con", 1L),
    "DBIConnection"
  )
})


test_that(".get_zone_aoi rejects NA zone_id", {
  expect_error(
    nemeton:::.get_zone_aoi(make_fake_con(), NA),
    "zone_id"
  )
})
