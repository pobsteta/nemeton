# Test Suite for Naturalness & Wilderness Indicators (Family N)
# N1: Distance to infrastructure, N2: Forest continuity, N3: Composite

# ==============================================================================
# N1: Distance to Infrastructure
# ==============================================================================

test_that("indicator_naturalness_distance (N1) works with roads + buildings", {
  skip_if_not_installed("sf")

  # Create test units: one near infrastructure, one far
  test_units <- sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        600900, 6601000,
        601100, 6601000,
        601100, 6601200,
        600900, 6601200,
        600900, 6601000
      ), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(
        605000, 6601000,
        605200, 6601000,
        605200, 6601200,
        605000, 6601200,
        605000, 6601000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Road close to unit 1
  roads <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_linestring(matrix(c(601000, 6600000, 601000, 6602500), ncol = 2, byrow = TRUE)),
      crs = 2154
    )
  )

  # Building close to unit 1
  buildings <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        601000, 6601000,
        601050, 6601000,
        601050, 6601050,
        601000, 6601050,
        601000, 6601000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_naturalness_distance(
    units = test_units,
    roads = roads,
    buildings = buildings
  )

  expect_s3_class(result, "sf")
  expect_true("N1" %in% names(result))
  expect_type(result$N1, "double")

  # Both should have values in 0-100 range
  expect_true(all(!is.na(result$N1)))
  expect_true(all(result$N1 >= 0 & result$N1 <= 100))

  # Unit near infrastructure should have lower N1 (less remote)
  expect_true(result$N1[1] < result$N1[2])
})

test_that("indicator_naturalness_distance (N1) returns default scores without roads/buildings", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_naturalness_distance(units = test_units)

  expect_s3_class(result, "sf")
  expect_true("N1" %in% names(result))
  # Default distances: routes=1000, batiments=500, urbain=2000
  # N1 = 0.40*pmin(100,1000/20) + 0.35*pmin(100,500/20) + 0.25*pmin(100,2000/20)
  # N1 = 0.40*50 + 0.35*25 + 0.25*100 = 20 + 8.75 + 25 = 53.75
  expect_equal(result$N1[1], 53.75)
})

test_that("indicator_naturalness_distance validates input", {
  expect_error(
    indicator_naturalness_distance(data.frame(x = 1:3)),
    "must be an sf object"
  )
})

test_that("indicator_naturalness_distance uses custom column name", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_naturalness_distance(test_units, column_name = "remoteness")

  expect_true("remoteness" %in% names(result))
  expect_false("N1" %in% names(result))
})

# ==============================================================================
# N2: Forest Continuity
# ==============================================================================

test_that("indicator_naturalness_continuity (N2) works with bdforet", {
  skip_if_not_installed("sf")

  # Test unit
  test_units <- sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(200, 0, 300, 0, 300, 100, 200, 100, 200, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # BD Foret covering unit 1 entirely, not unit 2
  bdforet <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, 110, -10, 110, 110, -10, 110, -10, -10), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_naturalness_continuity(
    units = test_units,
    bdforet = bdforet
  )

  expect_s3_class(result, "sf")
  expect_true("N2" %in% names(result))
  expect_type(result$N2, "double")

  # Unit 1 has forest → score 30-60 range (recent forest)
  expect_true(result$N2[1] > 30 & result$N2[1] <= 60)
  # Unit 2 has no forest → score 15
  expect_equal(result$N2[2], 15)
})

test_that("indicator_naturalness_continuity (N2) with ancient forest", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  bdforet <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, 110, -10, 110, 110, -10, 110, -10, -10), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  foret_ancienne <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, 110, -10, 110, 110, -10, 110, -10, -10), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_naturalness_continuity(
    units = test_units,
    bdforet = bdforet,
    foret_ancienne = foret_ancienne
  )

  # Ancient forest → score 60 + 40*taux_ancienne ≈ 100
  expect_true(result$N2[1] >= 60 & result$N2[1] <= 100)
})

test_that("indicator_naturalness_continuity (N2) returns 50 without data", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_naturalness_continuity(units = test_units)

  expect_equal(result$N2[1], 50)
})

test_that("indicator_naturalness_continuity validates input", {
  expect_error(
    indicator_naturalness_continuity(data.frame(x = 1:3)),
    "must be an sf object"
  )
})

test_that("indicator_naturalness_continuity uses custom column name", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_naturalness_continuity(test_units, column_name = "forest_cont")

  expect_true("forest_cont" %in% names(result))
  expect_false("N2" %in% names(result))
})

# ==============================================================================
# N3: Composite Naturalness
# ==============================================================================

test_that("indicator_naturalness_composite (N3) combines N1 and N2", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:2,
    N1 = c(80, 20),
    N2 = c(90, 30),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(200, 0, 300, 0, 300, 100, 200, 100, 200, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_naturalness_composite(units = test_units)

  expect_s3_class(result, "sf")
  expect_true("N3" %in% names(result))
  expect_type(result$N3, "double")

  # N3 = 0.35*N1 + 0.35*N2 + 0.15*50 + 0.15*50 (no L1/B3 → fallback 50)
  expected_1 <- 0.35 * 80 + 0.35 * 90 + 0.15 * 50 + 0.15 * 50
  expected_2 <- 0.35 * 20 + 0.35 * 30 + 0.15 * 50 + 0.15 * 50
  expect_equal(result$N3[1], expected_1)
  expect_equal(result$N3[2], expected_2)

  # Higher N1+N2 → higher N3
  expect_true(result$N3[1] > result$N3[2])
})

test_that("indicator_naturalness_composite (N3) uses L1 and B3 when available", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    N1 = 60,
    N2 = 70,
    L1 = 40,  # fragmentation
    B3 = 80,  # connectivity
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_naturalness_composite(units = test_units)

  # N3 = 0.35*60 + 0.35*70 + 0.15*(100-40) + 0.15*80
  expected <- 0.35 * 60 + 0.35 * 70 + 0.15 * 60 + 0.15 * 80
  expect_equal(result$N3[1], expected)
})

test_that("indicator_naturalness_composite (N3) without N1/N2 uses fallback 50", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_naturalness_composite(units = test_units)

  # All fallback to 50 → N3 = 50
  expect_equal(result$N3[1], 50)
})

test_that("indicator_naturalness_composite validates input", {
  expect_error(
    indicator_naturalness_composite(data.frame(x = 1:3)),
    "must be an sf object"
  )
})

test_that("indicator_naturalness_composite uses custom column name", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    N1 = 60,
    N2 = 70,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_naturalness_composite(test_units, column_name = "nat_idx")

  expect_true("nat_idx" %in% names(result))
  expect_false("N3" %in% names(result))
})

# ==============================================================================
# Integration
# ==============================================================================

test_that("Naturalness indicators integrate with family system", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(2000, 0, 3000, 0, 3000, 1000, 2000, 1000, 2000, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # N1 and N2 without external data → defaults, N3 combines them
  result <- test_units |>
    indicator_naturalness_distance() |>
    indicator_naturalness_continuity() |>
    indicator_naturalness_composite()

  expect_true(all(c("N1", "N2", "N3") %in% names(result)))
  expect_true(all(result$N3 >= 0 & result$N3 <= 100))
})
