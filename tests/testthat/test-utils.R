test_that("validate_sf accepts valid sf objects", {
  test_sf <- create_test_units(n_features = 2)

  # Should not error
  expect_silent(validate_sf(test_sf))
})

test_that("validate_sf rejects non-sf objects", {
  expect_error(
    validate_sf(data.frame(x = 1:3)),
    "must be an.*sf.*object"
  )
})

test_that("validate_sf checks CRS when required", {
  test_sf <- create_test_units(n_features = 2)

  # Remove CRS
  sf::st_crs(test_sf) <- NA

  expect_error(
    validate_sf(test_sf, require_crs = TRUE),
    "must have a defined CRS"
  )

  # Should pass when not required
  expect_silent(validate_sf(test_sf, require_crs = FALSE))
})

test_that("validate_sf detects invalid geometries", {
  # Create a self-intersecting polygon (invalid)
  invalid_poly <- sf::st_polygon(list(matrix(
    c(
      0, 0,
      1, 1,
      1, 0,
      0, 1,
      0, 0
    ),
    ncol = 2, byrow = TRUE
  )))

  invalid_sf <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(invalid_poly, crs = 2154)
  )

  expect_error(
    validate_sf(invalid_sf, require_valid = TRUE),
    "invalid geometry"
  )
})

test_that("validate_sf detects empty geometries", {
  # Create empty geometry
  empty_sf <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(sf::st_polygon(), crs = 2154)
  )

  expect_error(
    validate_sf(empty_sf),
    "empty geometr"
  )
})

test_that("validate_sf checks geometry types", {
  # Create point geometry (not POLYGON/MULTIPOLYGON)
  point_sf <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(sf::st_point(c(0, 0)), crs = 2154)
  )

  expect_error(
    validate_sf(point_sf),
    "must be POLYGON or MULTIPOLYGON"
  )
})

test_that("generate_ids creates unique sequential IDs", {
  ids <- generate_ids(5)

  expect_length(ids, 5)
  expect_equal(ids, c("unit_001", "unit_002", "unit_003", "unit_004", "unit_005"))

  # Check uniqueness
  expect_equal(length(unique(ids)), 5)
})

test_that("generate_ids accepts custom prefix", {
  ids <- generate_ids(3, prefix = "parcel_")

  expect_equal(ids, c("parcel_001", "parcel_002", "parcel_003"))
})

test_that("check_crs validates CRS compatibility", {
  sf1 <- create_test_units(crs = 2154)
  sf2 <- create_test_units(crs = 2154)

  # Same CRS should pass
  expect_silent(check_crs(sf1, sf2, strict = TRUE))
})

test_that("check_crs detects CRS mismatch in strict mode", {
  sf1 <- create_test_units(crs = 2154) # Lambert 93
  sf2 <- create_test_units(crs = 4326) # WGS84

  expect_error(
    check_crs(sf1, sf2, strict = TRUE),
    "CRS mismatch"
  )
})

test_that("check_crs detects undefined CRS", {
  sf1 <- create_test_units(crs = 2154)
  sf2 <- create_test_units(crs = 2154)
  sf::st_crs(sf2) <- NA

  expect_error(
    check_crs(sf1, sf2),
    "undefined CRS"
  )
})

test_that("get_crs extracts CRS from sf objects", {
  test_sf <- create_test_units(crs = 2154)

  crs <- get_crs(test_sf)

  expect_s3_class(crs, "crs")
  expect_equal(crs$epsg, 2154)
})

test_that("get_crs extracts CRS from SpatRaster", {
  test_raster <- create_test_raster(crs = "EPSG:2154")

  crs <- get_crs(test_raster)

  # For SpatRaster, get_crs returns the EPSG code
  expect_equal(crs, "2154")
})

test_that("get_crs returns NA for objects without CRS", {
  crs <- get_crs(data.frame(x = 1:3))

  expect_true(is.na(crs))
})

test_that("message_nemeton formats messages using cli", {
  expect_output(
    message_nemeton("Test message"),
    "Test message"
  )

  expect_output(
    message_nemeton("Processing {3} units"),
    "Processing 3 units"
  )
})
