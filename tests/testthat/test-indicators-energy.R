# Test Suite for Energy & Climate Indicators (Family E)
# US3: E1 (fuelwood potential), E2 (carbon avoidance)

test_that("indicator_energy_fuelwood (E1) calculates biomass potential", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:3,
    volume = c(200, 150, 180),
    species = c("FASY", "PIAB", "QUPE"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1000, 0, 2000, 0, 2000, 1000, 1000, 1000, 1000, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(2000, 0, 3000, 0, 3000, 1000, 2000, 1000, 2000, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_energy_fuelwood(
    units = test_units,
    volume_field = "volume",
    species_field = "species"
  )

  expect_s3_class(result, "sf")
  expect_true(all(c("E1", "E1_residues", "E1_coppice") %in% names(result)))
  expect_type(result$E1, "double")
  expect_true(all(result$E1 > 0, na.rm = TRUE))
})

test_that("indicator_energy_avoidance (E2) calculates CO2 substitution", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:2,
    E1 = c(5.0, 3.5), # tonnes DM/yr
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1000, 0, 2000, 0, 2000, 1000, 1000, 1000, 1000, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_energy_avoidance(
    units = test_units,
    fuelwood_field = "E1",
    energy_scenario = "vs_natural_gas"
  )

  expect_s3_class(result, "sf")
  expect_true(all(c("E2", "E2_energy", "E2_material") %in% names(result)))
  expect_true(all(result$E2 > 0, na.rm = TRUE))
  expect_true(all(result$E2_energy > 0, na.rm = TRUE))
})

test_that("Energy family integrates with family system", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:2,
    volume = c(200, 150),
    species = c("FASY", "PIAB"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1000, 0, 2000, 0, 2000, 1000, 1000, 1000, 1000, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- test_units %>%
    indicator_energy_fuelwood(volume_field = "volume", species_field = "species") %>%
    indicator_energy_avoidance(fuelwood_field = "E1")

  expect_true(all(c("E1", "E2") %in% names(result)))

  result_family <- create_family_index(result, family_codes = "E")
  expect_true("family_E" %in% names(result_family))
  expect_true(all(result_family$family_E > 0))
})

# ==============================================================================
# Additional tests for better coverage
# ==============================================================================

test_that("indicator_energy_fuelwood validates input", {
  expect_error(
    indicator_energy_fuelwood(data.frame(x = 1:3)),
    "must be an sf object"
  )
})

test_that("indicator_energy_fuelwood requires volume field", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  expect_error(
    indicator_energy_fuelwood(test_units, volume_field = "volume"),
    "Required field missing"
  )
})

test_that("indicator_energy_fuelwood handles NA values", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:3,
    volume = c(200, NA, 180),
    species = c("FASY", "PIAB", "QUPE"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1000, 0, 2000, 0, 2000, 1000, 1000, 1000, 1000, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(2000, 0, 3000, 0, 3000, 1000, 2000, 1000, 2000, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_energy_fuelwood(test_units, volume_field = "volume", species_field = "species")

  expect_false(is.na(result$E1[1]))
  expect_true(is.na(result$E1[2]))
  expect_false(is.na(result$E1[3]))
})

test_that("indicator_energy_fuelwood uses custom harvest rate", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    volume = 200,
    species = "FASY",
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result_low <- indicator_energy_fuelwood(
    test_units, volume_field = "volume", harvest_rate = 0.01
  )

  result_high <- indicator_energy_fuelwood(
    test_units, volume_field = "volume", harvest_rate = 0.04
  )

  # Higher harvest rate should produce more fuelwood
  expect_true(result_high$E1[1] > result_low$E1[1])
})

test_that("indicator_energy_fuelwood uses coppice area if provided", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:2,
    volume = c(200, 200),
    species = c("FASY", "FASY"),
    coppice_fraction = c(0, 0.5),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1000, 0, 2000, 0, 2000, 1000, 1000, 1000, 1000, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_energy_fuelwood(
    test_units,
    volume_field = "volume",
    species_field = "species",
    coppice_area_field = "coppice_fraction"
  )

  # Unit with coppice should have higher E1 and non-zero E1_coppice
  expect_true(result$E1[2] > result$E1[1])
  expect_equal(result$E1_coppice[1], 0)
  expect_true(result$E1_coppice[2] > 0)
})

test_that("indicator_energy_fuelwood uses custom column name", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    volume = 200,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_energy_fuelwood(
    test_units,
    volume_field = "volume",
    column_name = "fuelwood_potential"
  )

  expect_true("fuelwood_potential" %in% names(result))
  expect_true("fuelwood_potential_residues" %in% names(result) || "E1_residues" %in% names(result))
})

test_that("indicator_energy_avoidance validates input", {
  expect_error(
    indicator_energy_avoidance(data.frame(x = 1:3)),
    "must be an sf object"
  )
})

test_that("indicator_energy_avoidance handles missing fuelwood field gracefully", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_energy_avoidance(test_units, fuelwood_field = "E1")

  expect_true("E2" %in% names(result))
  expect_equal(result$E2[1], 0)  # No fuelwood data, so 0 avoided
})

test_that("indicator_energy_avoidance works with material substitution", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:2,
    E1 = c(5.0, 3.5),
    construction_volume = c(50, 30),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1000, 0, 2000, 0, 2000, 1000, 1000, 1000, 1000, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_energy_avoidance(
    test_units,
    fuelwood_field = "E1",
    volume_field = "construction_volume",
    material_scenario = "vs_concrete"
  )

  expect_true("E2" %in% names(result))
  expect_true("E2_material" %in% names(result))
})

test_that("indicator_energy_avoidance uses custom column name", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    E1 = 5.0,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicator_energy_avoidance(
    test_units,
    fuelwood_field = "E1",
    column_name = "co2_avoided"
  )

  expect_true("co2_avoided" %in% names(result))
})

test_that("indicator_energy_avoidance handles different energy scenarios", {
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    E1 = 5.0,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Test with default scenario (vs_natural_gas)
  result_gas <- indicator_energy_avoidance(
    test_units,
    fuelwood_field = "E1",
    energy_scenario = "vs_natural_gas"
  )

  expect_true("E2" %in% names(result_gas))
  expect_true(result_gas$E2[1] > 0)

  # Test with oil scenario
  result_oil <- indicator_energy_avoidance(
    test_units,
    fuelwood_field = "E1",
    energy_scenario = "vs_fuel_oil"
  )

  expect_true("E2" %in% names(result_oil))
})
