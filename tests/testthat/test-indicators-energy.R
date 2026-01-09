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
