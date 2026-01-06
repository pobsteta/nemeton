# Test Suite for Social & Recreational Indicators (Family S)
# US1: S1 (trails), S2 (accessibility), S3 (population proximity)

test_that("indicator_social_trails (S1) works with local data", {
  skip_if_not_installed("sf")

  # Create minimal test data
  test_units <- sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0, 1,0, 1,1, 0,1, 0,0), ncol=2, byrow=TRUE))),
      sf::st_polygon(list(matrix(c(1,0, 2,0, 2,1, 1,1, 1,0), ncol=2, byrow=TRUE))),
      crs = 2154
    )
  )

  test_trails <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_linestring(matrix(c(0.5,0, 0.5,1), ncol=2, byrow=TRUE)),
      crs = 2154
    )
  )

  # Test function
  result <- indicator_social_trails(
    units = test_units,
    trails = test_trails,
    method = "local",
    buffer_m = 0
  )

  # Assertions
  expect_s3_class(result, "sf")
  expect_true("S1" %in% names(result))
  expect_type(result$S1, "double")
  expect_true(all(result$S1 >= 0))

  # First unit should have trails, second should not
  expect_true(result$S1[1] > 0)
  expect_equal(result$S1[2], 0)
})

test_that("indicator_social_trails (S1) handles empty trail data", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0, 1,0, 1,1, 0,1, 0,0), ncol=2, byrow=TRUE))),
      crs = 2154
    )
  )

  # Empty trails
  test_trails <- sf::st_sf(
    id = integer(0),
    geometry = sf::st_sfc(crs = 2154)
  )

  result <- indicator_social_trails(
    units = test_units,
    trails = test_trails,
    method = "local"
  )

  expect_equal(result$S1[1], 0)
})

test_that("indicator_social_accessibility (S2) calculates scores", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:3,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0, 1,0, 1,1, 0,1, 0,0), ncol=2, byrow=TRUE))),
      sf::st_polygon(list(matrix(c(1,0, 2,0, 2,1, 1,1, 1,0), ncol=2, byrow=TRUE))),
      sf::st_polygon(list(matrix(c(2,0, 3,0, 3,1, 2,1, 2,0), ncol=2, byrow=TRUE))),
      crs = 2154
    )
  )

  result <- indicator_social_accessibility(
    units = test_units,
    method = "osm"  # Will use proxy calculation in test
  )

  # Assertions
  expect_s3_class(result, "sf")
  expect_true("S2" %in% names(result))
  expect_type(result$S2, "double")

  # Scores should be in 0-100 range
  expect_true(all(result$S2 >= 0 & result$S2 <= 100))
})

test_that("indicator_social_proximity (S3) calculates population buffers", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0, 1000,0, 1000,1000, 0,1000, 0,0), ncol=2, byrow=TRUE))),
      sf::st_polygon(list(matrix(c(2000,0, 3000,0, 3000,1000, 2000,1000, 2000,0), ncol=2, byrow=TRUE))),
      crs = 2154
    )
  )

  result <- indicator_social_proximity(
    units = test_units,
    method = "proxy",
    buffer_radii = c(5000, 10000, 20000)
  )

  # Assertions
  expect_s3_class(result, "sf")
  expect_true(all(c("S3", "S3_5km", "S3_10km", "S3_20km") %in% names(result)))
  expect_type(result$S3, "double")
  expect_type(result$S3_5km, "double")
  expect_type(result$S3_10km, "double")
  expect_type(result$S3_20km, "double")

  # Population should increase with buffer size
  expect_true(all(result$S3_10km >= result$S3_5km))
  expect_true(all(result$S3_20km >= result$S3_10km))
})

test_that("Social family indicators handle NA values correctly", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0, 1,0, 1,1, 0,1, 0,0), ncol=2, byrow=TRUE))),
      crs = 2154
    )
  )

  # S1 with no trails should return 0 (not NA)
  empty_trails <- sf::st_sf(
    geometry = sf::st_sfc(crs = 2154)
  )

  result_s1 <- indicator_social_trails(test_units, trails = empty_trails, method = "local")
  expect_false(is.na(result_s1$S1[1]))

  # S2 and S3 should always return valid scores
  result_s2 <- indicator_social_accessibility(test_units, method = "osm")
  result_s3 <- indicator_social_proximity(test_units, method = "proxy")

  expect_false(any(is.na(result_s2$S2)))
  expect_false(any(is.na(result_s3$S3)))
})

test_that("Social indicators integrate with family system", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0, 1000,0, 1000,1000, 0,1000, 0,0), ncol=2, byrow=TRUE))),
      sf::st_polygon(list(matrix(c(2000,0, 3000,0, 3000,1000, 2000,1000, 2000,0), ncol=2, byrow=TRUE))),
      crs = 2154
    )
  )

  # Calculate all S indicators
  empty_trails <- sf::st_sf(geometry = sf::st_sfc(crs = 2154))

  result <- test_units %>%
    indicator_social_trails(trails = empty_trails, method = "local") %>%
    indicator_social_accessibility(method = "osm") %>%
    indicator_social_proximity(method = "proxy")

  # Check all indicators present
  expect_true(all(c("S1", "S2", "S3") %in% names(result)))

  # Create family composite
  result_family <- create_family_index(result, family_codes = "S")

  expect_true("family_S" %in% names(result_family))
  expect_type(result_family$family_S, "double")
  expect_true(all(result_family$family_S >= 0))
})
