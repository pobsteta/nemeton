# test-filter-alerts-to-zone.R — UGF zone filter for alert vectors (spec 021 L7)
#   * filter_alerts_to_zone() keeps only in-polygon centroids
#   * opt-out apply_zone_mask = FALSE
#   * warn + passthrough when no polygon resolvable
#   * CRS reprojection (polygon in a different CRS than the alerts)
#   * non-sf / empty inputs pass through unchanged

skip_if_no_sf <- function() testthat::skip_if_not_installed("sf")

# 5 POINT alerts on a line x = 0,10,20,30,40 (y = 5), in EPSG:2154.
make_alerts <- function() {
  skip_if_no_sf()
  pts <- lapply(c(0, 10, 20, 30, 40), function(x) sf::st_point(c(x, 5)))
  sf::st_sf(id = 1:5, geometry = sf::st_sfc(pts, crs = 2154))
}

# Square polygon covering x in [-1, 21] (so it contains the first 3 points).
left_polygon <- function(crs = 2154) {
  skip_if_no_sf()
  bb <- sf::st_bbox(c(xmin = -1, ymin = -1, xmax = 21, ymax = 11), crs = 2154)
  poly <- sf::st_as_sf(sf::st_as_sfc(bb))
  if (crs != 2154) poly <- sf::st_transform(poly, crs)
  poly
}

test_that("only the alerts inside the polygon are kept", {
  skip_if_no_sf()
  out <- filter_alerts_to_zone(make_alerts(), mask_polygon = left_polygon())
  expect_s3_class(out, "sf")
  expect_identical(out$id, 1:3)   # points at x = 0,10,20 are inside
})

test_that("apply_zone_mask = FALSE returns the layer unchanged", {
  skip_if_no_sf()
  a <- make_alerts()
  out <- filter_alerts_to_zone(a, mask_polygon = left_polygon(),
                               apply_zone_mask = FALSE)
  expect_identical(nrow(out), 5L)
})

test_that("the polygon CRS is reprojected to the alerts' CRS", {
  skip_if_no_sf()
  # same polygon expressed in EPSG:4326 — must still select the same 3 points
  out <- filter_alerts_to_zone(make_alerts(),
                               mask_polygon = left_polygon(crs = 4326))
  expect_identical(out$id, 1:3)
})

test_that("no resolvable polygon warns and passes through", {
  skip_if_no_sf()
  a <- make_alerts()
  expect_warning(
    out <- filter_alerts_to_zone(a, apply_zone_mask = TRUE),
    "no UGF polygon"
  )
  expect_identical(nrow(out), 5L)
})

test_that("non-sf and empty inputs pass through unchanged", {
  skip_if_no_sf()
  expect_null(filter_alerts_to_zone(NULL, mask_polygon = left_polygon()))
  empty <- make_alerts()[0, ]
  out <- filter_alerts_to_zone(empty, mask_polygon = left_polygon())
  expect_identical(nrow(out), 0L)
})
