# Test Suite for Productive & Economic Indicators (Family P)
# US2: P1 (volume), P2 (productivity), P3 (quality)

test_that("indicator_productive_volume (P1) calculates with IFN equations", {
  skip_if_not_installed("sf")

  # Create test data with species and biometric data
  test_units <- sf::st_sf(
    id = 1:3,
    species = c("FASY", "PIAB", "QUPE"),
    dbh = c(35, 28, 42),
    height = c(25, 22, 30),
    density = c(250, 320, 180),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1000, 0, 2000, 0, 2000, 1000, 1000, 1000, 1000, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(2000, 0, 3000, 0, 3000, 1000, 2000, 1000, 2000, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_productive_volume(
    units = test_units,
    species_field = "species",
    dbh_field = "dbh",
    height_field = "height",
    density_field = "density"
  )

  # Assertions
  expect_s3_class(result, "sf")
  expect_true("P1" %in% names(result))
  expect_type(result$P1, "double")
  expect_true(all(result$P1 > 0, na.rm = TRUE)) # All should have positive volume

  # Volume should be reasonable (not extreme values)
  expect_true(all(result$P1 < 5000, na.rm = TRUE)) # Not > 5000 m³/ha (very dense stands can reach 1000+)
})

test_that("indicator_productive_volume (P1) handles missing height with estimation", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    species = "FASY",
    dbh = 35,
    density = 250,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Without height field - should estimate
  result <- indicator_productive_volume(
    units = test_units,
    species_field = "species",
    dbh_field = "dbh",
    density_field = "density"
  )

  expect_true("P1" %in% names(result))
  expect_false(is.na(result$P1[1]))
  expect_true(result$P1[1] > 0)
})

test_that("indicator_productive_station (P2) looks up productivity tables", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:3,
    species = c("FASY", "PIAB", "QUPE"),
    fertility = c(1, 2, 2),
    climate = c("temperate_oceanic", "mountainous", "temperate_oceanic"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1000, 0, 2000, 0, 2000, 1000, 1000, 1000, 1000, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(2000, 0, 3000, 0, 3000, 1000, 2000, 1000, 2000, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_productive_station(
    units = test_units,
    species_field = "species",
    fertility_field = "fertility",
    climate_field = "climate"
  )

  # Assertions
  expect_s3_class(result, "sf")
  expect_true("P2" %in% names(result))
  expect_type(result$P2, "double")

  # Productivity values should be reasonable (annual increment)
  expect_true(all(result$P2 > 0 & result$P2 < 20, na.rm = TRUE)) # 0-20 m³/ha/yr
})

test_that("indicator_productive_quality (P3) scores timber quality", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:3,
    dbh = c(45, 28, 15), # sawlog, mid, pulpwood
    species = c("FASY", "PIAB", "QUPE"),
    form_score = c(85, 70, 60),
    defects = c(0, 0, 1),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1000, 0, 2000, 0, 2000, 1000, 1000, 1000, 1000, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(2000, 0, 3000, 0, 3000, 1000, 2000, 1000, 2000, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_productive_quality(
    units = test_units,
    dbh_field = "dbh",
    form_score_field = "form_score",
    defects_field = "defects",
    species_field = "species"
  )

  # Assertions
  expect_s3_class(result, "sf")
  expect_true("P3" %in% names(result))
  expect_type(result$P3, "double")

  # Quality scores should be in 0-100 range
  expect_true(all(result$P3 >= 0 & result$P3 <= 100))

  # Larger diameter should generally mean higher quality (if other factors equal)
  # Unit 1 (45cm) should have higher quality than Unit 3 (15cm)
  expect_true(result$P3[1] > result$P3[3])
})

test_that("Productive indicators handle missing data correctly", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:2,
    species = c("FASY", NA),
    dbh = c(35, 30),
    density = c(250, NA),
    fertility = c(1, 2),
    climate = c("temperate_oceanic", "mountainous"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1000, 0, 2000, 0, 2000, 1000, 1000, 1000, 1000, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # P1 with missing species or density should return NA
  result_p1 <- indicator_productive_volume(
    units = test_units,
    species_field = "species",
    dbh_field = "dbh",
    density_field = "density"
  )

  expect_false(is.na(result_p1$P1[1])) # Valid data
  expect_true(is.na(result_p1$P1[2])) # Missing density

  # P2 with missing species should return NA
  result_p2 <- indicator_productive_station(
    units = test_units,
    species_field = "species",
    fertility_field = "fertility",
    climate_field = "climate"
  )

  expect_false(is.na(result_p2$P2[1])) # Valid data
  expect_true(is.na(result_p2$P2[2])) # Missing species
})

test_that("Productive family indicators integrate with family system", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:2,
    species = c("FASY", "PIAB"),
    dbh = c(35, 28),
    height = c(25, 22),
    density = c(250, 320),
    fertility = c(1, 2),
    climate = c("temperate_oceanic", "mountainous"),
    form_score = c(85, 70),
    defects = c(0, 0),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1000, 0, 2000, 0, 2000, 1000, 1000, 1000, 1000, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Calculate all P indicators
  result <- test_units %>%
    indicator_productive_volume(
      species_field = "species",
      dbh_field = "dbh",
      height_field = "height",
      density_field = "density"
    ) %>%
    indicator_productive_station(
      species_field = "species",
      fertility_field = "fertility",
      climate_field = "climate"
    ) %>%
    indicator_productive_quality(
      dbh_field = "dbh",
      form_score_field = "form_score",
      defects_field = "defects",
      species_field = "species"
    )

  # Check all indicators present
  expect_true(all(c("P1", "P2", "P3") %in% names(result)))

  # Create family composite
  result_family <- create_family_index(result, family_codes = "P")

  expect_true("family_P" %in% names(result_family))
  expect_type(result_family$family_P, "double")
  expect_true(all(result_family$family_P > 0))
})

# ==============================================================================
# Additional tests for better coverage
# ==============================================================================

test_that("indicator_productive_volume validates input", {
  expect_error(
    indicator_productive_volume(data.frame(x = 1:3)),
    "must be an sf object"
  )
})

test_that("indicator_productive_volume requires fields", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  expect_error(
    indicator_productive_volume(test_units),
    "Missing required fields"
  )
})

test_that("indicator_productive_volume handles unknown species with fallback", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    species = "UNKNOWN_SPECIES_XYZ",
    dbh = 30,
    density = 200,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Unknown species should use fallback - may or may not warn
  result <- suppressWarnings(
    indicator_productive_volume(
      test_units,
      species_field = "species",
      dbh_field = "dbh",
      density_field = "density"
    )
  )

  # Should still calculate something with fallback
  expect_true("P1" %in% names(result))
  expect_false(is.na(result$P1[1]))
})

test_that("indicator_productive_volume uses custom column name", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    species = "FASY",
    dbh = 35,
    density = 250,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_productive_volume(
    test_units,
    species_field = "species",
    dbh_field = "dbh",
    density_field = "density",
    column_name = "volume_m3_ha"
  )

  expect_true("volume_m3_ha" %in% names(result))
  expect_false("P1" %in% names(result))
})

test_that("indicator_productive_station validates input", {
  expect_error(
    indicator_productive_station(data.frame(x = 1:3)),
    "must be an sf object"
  )
})

test_that("indicator_productive_station uses custom column name", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    species = "FASY",
    fertility = 1,
    climate = "temperate_oceanic",
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_productive_station(
    test_units,
    species_field = "species",
    fertility_field = "fertility",
    climate_field = "climate",
    column_name = "site_index"
  )

  expect_true("site_index" %in% names(result))
})

test_that("indicator_productive_quality validates input", {
  expect_error(
    indicator_productive_quality(data.frame(x = 1:3)),
    "must be an sf object"
  )
})

test_that("indicator_productive_quality uses custom column name", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    dbh = 40,
    species = "FASY",
    form_score = 80,
    defects = 0,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_productive_quality(
    test_units,
    dbh_field = "dbh",
    form_score_field = "form_score",
    defects_field = "defects",
    species_field = "species",
    column_name = "quality_score"
  )

  expect_true("quality_score" %in% names(result))
})

test_that("indicator_productive_quality handles missing optional fields", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:2,
    dbh = c(40, 30),
    species = c("FASY", "PIAB"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1000, 0, 2000, 0, 2000, 1000, 1000, 1000, 1000, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Without form_score and defects
  result <- indicator_productive_quality(
    test_units,
    dbh_field = "dbh",
    species_field = "species"
  )

  expect_true("P3" %in% names(result))
  expect_true(all(result$P3 >= 0 & result$P3 <= 100))
})
