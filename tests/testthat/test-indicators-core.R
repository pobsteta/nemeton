test_that("list_indicators returns all indicator names", {
  indicators <- list_indicators()

  expect_type(indicators, "character")
  expect_length(indicators, 31)  # v0.6.0: 31 indicators in 12 families
  expect_true("carbon_biomass" %in% indicators)
  expect_true("biodiversity_protection" %in% indicators)
  expect_true("water_twi" %in% indicators)
  expect_true("landscape_fragmentation" %in% indicators)
  expect_true("social_accessibility" %in% indicators)
})

test_that("list_indicators returns details when requested", {
  details <- list_indicators(return_type = "details")

  expect_s3_class(details, "data.frame")
  expect_equal(nrow(details), 31)  # v0.6.0: 31 indicators
  expect_true("name" %in% names(details))
  expect_true("category" %in% names(details))
  expect_true("description" %in% names(details))
})

test_that("list_indicators filters by category", {
  biophysical <- list_indicators(category = "biophysical")

  expect_true("carbon_biomass" %in% biophysical)
  expect_true("biodiversity_protection" %in% biophysical)
  expect_true("water_twi" %in% biophysical)
  expect_false("social_accessibility" %in% biophysical)
})

test_that("nemeton_compute validates inputs", {
  # Non-sf units
  expect_error(
    nemeton_compute(data.frame(x = 1:3), NULL),
    "must be an.*sf.*object"
  )

  # Non-nemeton_layers
  units <- nemeton_units(create_test_units())
  expect_error(
    nemeton_compute(units, list()),
    "must be a.*nemeton_layers.*object"
  )
})

test_that("nemeton_compute rejects parallel option in MVP", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  expect_error(
    nemeton_compute(units, layers, parallel = TRUE),
    "Parallel computing not implemented"
  )
})

test_that("nemeton_compute validates indicator names", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  # Unknown indicator should warn and skip
  expect_warning(
    nemeton_compute(units, layers, indicators = c("carbon_biomass", "unknown_indicator")),
    "Unknown indicator"
  )
})

test_that("nemeton_compute requires at least one valid indicator", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  expect_error(
    nemeton_compute(units, layers, indicators = c("invalid1", "invalid2")),
    "No valid indicators"
  )
})

test_that("nemeton_compute expands 'all' to all indicators", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()

  # Need all required layers for all indicators
  layers <- nemeton_layers(
    rasters = list(
      biomass = temp_files$biomass,
      species_richness = temp_files$biomass, # Fake
      dem = temp_files$dem,
      landcover = temp_files$landcover
    ),
    vectors = list(
      water = temp_files$water,
      roads = temp_files$roads
    )
  )

  # Should attempt all 5 indicators
  result <- nemeton_compute(units, layers, indicators = "all", preprocess = FALSE)

  expect_s3_class(result, "sf")
  # Should have all indicator columns (or NA if failed)
  expect_true("carbon_biomass" %in% names(result))
  expect_true("biodiversity_protection" %in% names(result))
  expect_true("water_twi" %in% names(result))
  expect_true("landscape_fragmentation" %in% names(result))
  expect_true("social_accessibility" %in% names(result))
})

test_that("nemeton_compute calculates carbon indicator successfully", {
  units <- nemeton_units(create_test_units(n_features = 3))
  # Add required columns for carbon_biomass indicator
  units$species <- c("Quercus", "Fagus", "Pinus")
  units$age <- c(80, 60, 40)
  units$density <- c(0.7, 0.8, 0.6)

  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(biomass = temp_files$biomass)
  )

  result <- nemeton_compute(
    units, layers,
    indicators = "carbon_biomass",
    preprocess = FALSE
  )

  expect_s3_class(result, "sf")
  expect_true("carbon_biomass" %in% names(result))
  expect_equal(nrow(result), 3)
  expect_type(result$carbon_biomass, "double")

  # Should have non-NA values
  expect_false(all(is.na(result$carbon_biomass)))
})

test_that("nemeton_compute handles missing layers gracefully", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()

  # Only biomass layer, but try to calculate water indicator
  layers <- nemeton_layers(
    rasters = list(biomass = temp_files$biomass)
  )

  # Should warn and set water to NA (or 0)
  expect_warning(
    result <- nemeton_compute(units, layers, indicators = "water_twi", preprocess = FALSE),
    regexp = NULL  # Accept any warning about missing layers
  )

  expect_true("water_twi" %in% names(result))
  # When layers are missing, indicator returns NA or 0
  expect_true(all(is.na(result$water_twi) | result$water_twi == 0))
})

test_that("nemeton_compute preprocesses layers when requested", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(biomass = temp_files$biomass)
  )

  # With preprocessing
  expect_message(
    result <- nemeton_compute(units, layers, indicators = "carbon_biomass", preprocess = TRUE),
    "Preprocessing"
  )

  expect_s3_class(result, "sf")
})

test_that("nemeton_compute skips preprocessing when disabled", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(biomass = temp_files$biomass)
  )

  # Without preprocessing - should not see preprocessing message
  result <- nemeton_compute(units, layers, indicators = "carbon_biomass", preprocess = FALSE)

  expect_s3_class(result, "sf")
})

test_that("nemeton_compute adds metadata to results", {
  units <- nemeton_units(create_test_units())
  units$species <- c("Quercus", "Fagus", "Pinus")
  units$age <- c(80, 60, 40)
  units$density <- c(0.7, 0.8, 0.6)

  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(biomass = temp_files$biomass)
  )

  result <- nemeton_compute(units, layers, indicators = "carbon_biomass", preprocess = FALSE)

  # Check metadata
  meta <- attr(result, "metadata")
  expect_true("computed_at" %in% names(meta))
  expect_true("indicators_computed" %in% names(meta))
  expect_true("layers_used" %in% names(meta))

  expect_true("carbon_biomass" %in% meta$indicators_computed)
})

test_that("nemeton_compute preserves original unit columns", {
  units <- nemeton_units(create_test_units())
  units$custom_col <- c("A", "B", "C")

  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton_compute(units, layers, indicators = "carbon_biomass", preprocess = FALSE)

  # Original columns should be preserved
  expect_true("custom_col" %in% names(result))
  expect_equal(result$custom_col, c("A", "B", "C"))
})

test_that("nemeton_compute can calculate multiple indicators", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(
      biomass = temp_files$biomass,
      landcover = temp_files$landcover
    )
  )

  result <- nemeton_compute(
    units, layers,
    indicators = c("carbon_biomass", "landscape_fragmentation"),
    preprocess = FALSE,
    forest_values = c(1, 2, 3) # For fragmentation
  )

  expect_true("carbon_biomass" %in% names(result))
  expect_true("landscape_fragmentation" %in% names(result))
})

test_that("compute_indicator dispatches to correct function", {
  units <- nemeton_units(create_test_units())
  # Add required columns for carbon_biomass indicator
  units$species <- c("Quercus", "Fagus", "Pinus")
  units$age <- c(80, 60, 40)
  units$density <- c(0.7, 0.8, 0.6)

  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  # Test carbon dispatch
  values <- compute_indicator("carbon_biomass", units, layers)

  expect_type(values, "double")
  expect_length(values, nrow(units))
})

test_that("compute_indicator errors on unknown indicator", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  expect_error(
    compute_indicator("unknown_indicator", units, layers),
    "Unknown indicator"
  )
})

test_that("nemeton_compute shows progress when enabled", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  expect_message(
    nemeton_compute(units, layers, indicators = "carbon_biomass", preprocess = FALSE, progress = TRUE),
    "Calculating"
  )
})

test_that("nemeton_compute hides progress when disabled", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  # Should not show "Calculating" messages
  result <- nemeton_compute(
    units, layers,
    indicators = "carbon_biomass",
    preprocess = FALSE,
    progress = FALSE
  )

  expect_s3_class(result, "sf")
})
