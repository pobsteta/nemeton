# Test Suite for Naturalness & Wilderness Indicators (Family N)
# US4: N1 (distance), N2 (continuity), N3 (composite)

test_that("indicator_naturalness_distance (N1) calculates infrastructure remoteness", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:3,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1000, 0, 3000, 0, 3000, 2000, 1000, 2000, 1000, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(5000, 0, 6000, 0, 6000, 1000, 5000, 1000, 5000, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_naturalness_distance(
    units = test_units,
    method = "osm"
  )

  expect_s3_class(result, "sf")
  expect_true(all(c("N1", "N1_roads", "N1_buildings", "N1_power") %in% names(result)))
  expect_true(all(result$N1 > 0, na.rm = TRUE))
})

test_that("indicator_naturalness_continuity (N2) calculates forest patch size", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 500, 0, 500, 500, 0, 500, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(600, 0, 1100, 0, 1100, 500, 600, 500, 600, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_naturalness_continuity(
    units = test_units,
    connectivity_distance = 100,
    method = "local"
  )

  expect_s3_class(result, "sf")
  expect_true("N2" %in% names(result))
  expect_true(all(result$N2 > 0, na.rm = TRUE))
})

test_that("indicator_naturalness_composite (N3) integrates multiple dimensions", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:3,
    N1 = c(500, 1000, 200),
    N2 = c(100, 250, 50),
    T1 = c(80, 120, 40),
    B1 = c(60, 80, 30),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1000, 0, 2000, 0, 2000, 1000, 1000, 1000, 1000, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(2000, 0, 3000, 0, 3000, 1000, 2000, 1000, 2000, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_naturalness_composite(
    units = test_units,
    n1_field = "N1",
    n2_field = "N2",
    t1_field = "T1",
    b1_field = "B1",
    aggregation = "multiplicative"
  )

  expect_s3_class(result, "sf")
  expect_true("N3" %in% names(result))
  expect_true(all(result$N3 >= 0 & result$N3 <= 100))
})

test_that("Naturalness family integrates with family system", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:2,
    T1 = c(80, 100),
    B1 = c(60, 70),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1000, 0, 2000, 0, 2000, 1000, 1000, 1000, 1000, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- test_units %>%
    indicator_naturalness_distance(method = "osm") %>%
    indicator_naturalness_continuity(connectivity_distance = 100) %>%
    indicator_naturalness_composite(n1_field = "N1", n2_field = "N2", t1_field = "T1", b1_field = "B1")

  expect_true(all(c("N1", "N2", "N3") %in% names(result)))

  result_family <- create_family_index(result, family_codes = "N")
  expect_true("family_N" %in% names(result_family))
})
