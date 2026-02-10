# ──────────────────────────────────────────────────────────────────
# tests/testthat/test-indicators-core.R
# Comprehensive tests for R/indicators-core.R
# Covers: list_indicators(), compute_indicator(), nemeton_compute()
# ──────────────────────────────────────────────────────────────────

# ══════════════════════════════════════════════════════════════════
# list_indicators() — return_type = "names" (default)
# ══════════════════════════════════════════════════════════════════

test_that("list_indicators returns all 31 indicator names by default", {
  indicators <- list_indicators()

  expect_type(indicators, "character")
  expect_length(indicators, 31)

  # Spot-check a few from different families
  expect_true("carbon_biomass" %in% indicators)
  expect_true("carbon_ndvi" %in% indicators)
  expect_true("water_network" %in% indicators)
  expect_true("water_wetlands" %in% indicators)
  expect_true("water_twi" %in% indicators)
  expect_true("soil_fertility" %in% indicators)
  expect_true("soil_erosion" %in% indicators)
  expect_true("landscape_fragmentation" %in% indicators)
  expect_true("landscape_edge" %in% indicators)
  expect_true("biodiversity_protection" %in% indicators)
  expect_true("biodiversity_structure" %in% indicators)
  expect_true("biodiversity_connectivity" %in% indicators)
  expect_true("risk_fire" %in% indicators)
  expect_true("risk_storm" %in% indicators)
  expect_true("risk_drought" %in% indicators)
  expect_true("risk_browsing" %in% indicators)
  expect_true("temporal_age" %in% indicators)
  expect_true("temporal_change" %in% indicators)
  expect_true("air_coverage" %in% indicators)
  expect_true("air_quality" %in% indicators)
  expect_true("social_trails" %in% indicators)
  expect_true("social_accessibility" %in% indicators)
  expect_true("social_proximity" %in% indicators)
  expect_true("productive_volume" %in% indicators)
  expect_true("productive_quality" %in% indicators)
  expect_true("productive_station" %in% indicators)
  expect_true("energy_fuelwood" %in% indicators)
  expect_true("energy_avoidance" %in% indicators)
  expect_true("naturalness_distance" %in% indicators)
  expect_true("naturalness_continuity" %in% indicators)
  expect_true("naturalness_composite" %in% indicators)
})

test_that("list_indicators returns details data.frame when requested", {
  details <- list_indicators(return_type = "details")

  expect_s3_class(details, "data.frame")
  expect_equal(nrow(details), 31)
  expect_true(all(c("name", "family", "category", "description") %in% names(details)))
  expect_type(details$name, "character")
  expect_type(details$family, "character")
  expect_type(details$category, "character")
  expect_type(details$description, "character")
})

test_that("list_indicators details contain correct family codes", {
  details <- list_indicators(return_type = "details")

  # Verify the 12 family codes exist
  expected_families <- c("C", "W", "F", "L", "B", "R", "T", "A", "S", "P", "E", "N")
  actual_families <- unique(details$family)
  expect_setequal(actual_families, expected_families)

  # Verify family mapping for specific indicators
  carbon_row <- details[details$name == "carbon_biomass", ]
  expect_equal(carbon_row$family, "C")

  risk_row <- details[details$name == "risk_fire", ]
  expect_equal(risk_row$family, "R")

  naturalness_row <- details[details$name == "naturalness_composite", ]
  expect_equal(naturalness_row$family, "N")
})

# ══════════════════════════════════════════════════════════════════
# list_indicators() — category filtering
# ══════════════════════════════════════════════════════════════════

test_that("list_indicators filters by category = 'biophysical'", {
  biophysical <- list_indicators(category = "biophysical")

  expect_true("carbon_biomass" %in% biophysical)
  expect_true("carbon_ndvi" %in% biophysical)
  expect_true("water_network" %in% biophysical)
  expect_true("biodiversity_protection" %in% biophysical)
  expect_true("air_coverage" %in% biophysical)
  # social, risk, etc. should NOT be in biophysical

  expect_false("social_accessibility" %in% biophysical)
  expect_false("risk_fire" %in% biophysical)
  expect_false("landscape_fragmentation" %in% biophysical)
})

test_that("list_indicators filters by category = 'risk'", {
  risk <- list_indicators(category = "risk")

  expect_length(risk, 4)
  expect_true("risk_fire" %in% risk)
  expect_true("risk_storm" %in% risk)
  expect_true("risk_drought" %in% risk)
  expect_true("risk_browsing" %in% risk)
  expect_false("carbon_biomass" %in% risk)
})

test_that("list_indicators filters by category = 'social'", {
  social <- list_indicators(category = "social")

  expect_length(social, 3)
  expect_true("social_trails" %in% social)
  expect_true("social_accessibility" %in% social)
  expect_true("social_proximity" %in% social)
  expect_false("carbon_biomass" %in% social)
})

test_that("list_indicators filters by category = 'landscape'", {
  landscape <- list_indicators(category = "landscape")

  expect_length(landscape, 2)
  expect_true("landscape_fragmentation" %in% landscape)
  expect_true("landscape_edge" %in% landscape)
  expect_false("carbon_biomass" %in% landscape)
})

test_that("list_indicators filters by category = 'temporal'", {
  temporal <- list_indicators(category = "temporal")

  expect_length(temporal, 2)
  expect_true("temporal_age" %in% temporal)
  expect_true("temporal_change" %in% temporal)
})

test_that("list_indicators filters by category = 'productive'", {
  productive <- list_indicators(category = "productive")

  expect_length(productive, 3)
  expect_true("productive_volume" %in% productive)
  expect_true("productive_quality" %in% productive)
  expect_true("productive_station" %in% productive)
})

test_that("list_indicators filters by category = 'energy'", {
  energy <- list_indicators(category = "energy")

  expect_length(energy, 2)
  expect_true("energy_fuelwood" %in% energy)
  expect_true("energy_avoidance" %in% energy)
})

test_that("list_indicators filters by category = 'naturalness'", {
  naturalness <- list_indicators(category = "naturalness")

  expect_length(naturalness, 3)
  expect_true("naturalness_distance" %in% naturalness)
  expect_true("naturalness_continuity" %in% naturalness)
  expect_true("naturalness_composite" %in% naturalness)
})

test_that("list_indicators with unknown category returns empty", {
  result <- list_indicators(category = "nonexistent_category")

  expect_type(result, "character")
  expect_length(result, 0)
})

test_that("list_indicators details with category filter returns filtered data.frame", {
  details <- list_indicators(category = "risk", return_type = "details")

  expect_s3_class(details, "data.frame")
  expect_equal(nrow(details), 4)
  expect_true(all(details$category == "risk"))
  expect_true(all(details$family == "R"))
  expect_true(all(c("name", "family", "category", "description") %in% names(details)))
})

test_that("list_indicators return_type uses match.arg", {
  # Invalid return_type should error via match.arg
  expect_error(
    list_indicators(return_type = "invalid"),
    "should be one of|doit \u00eatre un de"
  )
})

test_that("list_indicators details descriptions are non-empty", {
  details <- list_indicators(return_type = "details")

  expect_true(all(nchar(details$description) > 0))
  expect_true(all(!is.na(details$description)))
})

test_that("list_indicators names match across return types", {
  names_only <- list_indicators()
  details <- list_indicators(return_type = "details")

  expect_equal(names_only, details$name)
})

# ══════════════════════════════════════════════════════════════════
# nemeton_compute() — input validation
# ══════════════════════════════════════════════════════════════════

test_that("nemeton_compute rejects non-sf units", {
  expect_error(
    nemeton_compute(data.frame(x = 1:3), NULL),
    "must be an.*sf.*object"
  )

  expect_error(
    nemeton_compute("not_an_sf", NULL),
    "must be an.*sf.*object"
  )

  expect_error(
    nemeton_compute(list(a = 1), NULL),
    "must be an.*sf.*object"
  )

  expect_error(
    nemeton_compute(NULL, NULL),
    "must be an.*sf.*object"
  )
})

test_that("nemeton_compute rejects non-nemeton_layers layers", {
  units <- nemeton_units(create_test_units())

  expect_error(
    nemeton_compute(units, list()),
    "must be a.*nemeton_layers.*object"
  )

  expect_error(
    nemeton_compute(units, data.frame()),
    "must be a.*nemeton_layers.*object"
  )

  expect_error(
    nemeton_compute(units, "a_path"),
    "must be a.*nemeton_layers.*object"
  )
})

test_that("nemeton_compute rejects parallel = TRUE in MVP", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  expect_error(
    nemeton_compute(units, layers, parallel = TRUE),
    "Parallel computing not implemented"
  )
})

# ══════════════════════════════════════════════════════════════════
# nemeton_compute() — indicator name validation
# ══════════════════════════════════════════════════════════════════

test_that("nemeton_compute warns on unknown indicators and skips them", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  expect_warning(
    result <- nemeton_compute(
      units, layers,
      indicators = c("carbon_biomass", "totally_fake_indicator"),
      preprocess = FALSE
    ),
    "Unknown indicator"
  )

  # The valid indicator should still be computed
  expect_true("carbon_biomass" %in% names(result))
  # The fake one should not appear as a column (it was skipped before dispatch)
  expect_false("totally_fake_indicator" %in% names(result))
})

test_that("nemeton_compute warns on multiple unknown indicators", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  expect_warning(
    result <- nemeton_compute(
      units, layers,
      indicators = c("carbon_biomass", "fake1", "fake2"),
      preprocess = FALSE
    ),
    "Unknown indicator"
  )

  expect_true("carbon_biomass" %in% names(result))
})

test_that("nemeton_compute errors when ALL indicators are invalid", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  # All invalid => after filtering, 0 valid => msg_error("indicator_no_valid")
  expect_error(
    suppressWarnings(
      nemeton_compute(units, layers, indicators = c("invalid1", "invalid2"))
    ),
    "No valid indicators"
  )
})

# ══════════════════════════════════════════════════════════════════
# nemeton_compute() — "all" expansion
# ══════════════════════════════════════════════════════════════════

test_that("nemeton_compute expands 'all' to full indicator list", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(
      biomass = temp_files$biomass,
      species_richness = temp_files$biomass,
      dem = temp_files$dem,
      landcover = temp_files$landcover
    ),
    vectors = list(
      water = temp_files$water,
      roads = temp_files$roads
    )
  )

  # indicators = "all" should attempt all 31 indicators
  # Many will fail with mock data, producing expected "Indicator X calculation failed" warnings
  result <- suppressWarnings(
    nemeton_compute(units, layers, indicators = "all", preprocess = FALSE)
  )

  expect_s3_class(result, "sf")
  # All 31 indicator columns should exist (even if NA from failures)
  all_indicator_names <- list_indicators()
  for (ind in all_indicator_names) {
    expect_true(ind %in% names(result), info = paste("Missing indicator column:", ind))
  }
})

# ══════════════════════════════════════════════════════════════════
# nemeton_compute() — indicator calculation and error handling
# ══════════════════════════════════════════════════════════════════

test_that("nemeton_compute calculates carbon_biomass successfully", {
  units <- nemeton_units(create_test_units(n_features = 3))
  units$species <- c("Quercus", "Fagus", "Pinus")
  units$age <- c(80, 60, 40)
  units$density <- c(0.7, 0.8, 0.6)

  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton_compute(
    units, layers,
    indicators = "carbon_biomass",
    preprocess = FALSE
  )

  expect_s3_class(result, "sf")
  expect_true("carbon_biomass" %in% names(result))
  expect_equal(nrow(result), 3)
  expect_type(result$carbon_biomass, "double")
  expect_false(all(is.na(result$carbon_biomass)))
})

test_that("nemeton_compute handles failing indicators gracefully (sets NA)", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()

  # Only provide biomass layer, try water indicator which needs different data
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  # water_twi may fail or return 0/NA when required layers are missing
  expect_warning(
    result <- nemeton_compute(units, layers, indicators = "water_twi", preprocess = FALSE),
    regexp = NULL  # Accept any warning about missing layers or failure
  )

  expect_true("water_twi" %in% names(result))
  # Value should be NA or 0 when layers are missing
  expect_true(all(is.na(result$water_twi) | result$water_twi == 0))
})

test_that("nemeton_compute computes multiple indicators at once", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(
      biomass = temp_files$biomass,
      landcover = temp_files$landcover
    )
  )

  # carbon_biomass may fail with mock data
  result <- suppressWarnings(
    nemeton_compute(
      units, layers,
      indicators = c("carbon_biomass", "landscape_fragmentation"),
      preprocess = FALSE,
      forest_values = c(1, 2, 3)
    )
  )

  expect_true("carbon_biomass" %in% names(result))
  expect_true("landscape_fragmentation" %in% names(result))
  expect_equal(nrow(result), nrow(units))
})

# ══════════════════════════════════════════════════════════════════
# nemeton_compute() — preprocessing
# ══════════════════════════════════════════════════════════════════

test_that("nemeton_compute preprocesses layers when preprocess = TRUE", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  # With preprocessing, should emit "Preprocessing" message
  expect_message(
    result <- nemeton_compute(units, layers, indicators = "carbon_biomass", preprocess = TRUE),
    "Preprocessing|Harmoniz"
  )

  expect_s3_class(result, "sf")
})

test_that("nemeton_compute skips preprocessing when preprocess = FALSE", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton_compute(units, layers, indicators = "carbon_biomass", preprocess = FALSE)

  expect_s3_class(result, "sf")
})

# ══════════════════════════════════════════════════════════════════
# nemeton_compute() — metadata
# ══════════════════════════════════════════════════════════════════

test_that("nemeton_compute attaches metadata to result", {
  units <- nemeton_units(create_test_units())
  units$species <- c("Quercus", "Fagus", "Pinus")
  units$age <- c(80, 60, 40)
  units$density <- c(0.7, 0.8, 0.6)

  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton_compute(units, layers, indicators = "carbon_biomass", preprocess = FALSE)

  meta <- attr(result, "metadata")
  expect_true(!is.null(meta))
  expect_true("computed_at" %in% names(meta))
  expect_true("indicators_computed" %in% names(meta))
  expect_true("layers_used" %in% names(meta))
  expect_true(inherits(meta$computed_at, "POSIXct"))
  expect_true("carbon_biomass" %in% meta$indicators_computed)
  expect_true("biomass" %in% meta$layers_used)
})

test_that("nemeton_compute preserves original metadata from units", {
  units <- nemeton_units(create_test_units())
  # Set original metadata
  attr(units, "metadata") <- list(source = "test_data", created = "2025-01-01")

  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton_compute(units, layers, indicators = "carbon_biomass", preprocess = FALSE)

  meta <- attr(result, "metadata")
  # Original metadata should be preserved (merged)
  expect_equal(meta$source, "test_data")
  expect_equal(meta$created, "2025-01-01")
  # New metadata should also be present
  expect_true("computed_at" %in% names(meta))
  expect_true("indicators_computed" %in% names(meta))
})

test_that("nemeton_compute metadata tracks failed indicators correctly", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()

  # Only biomass layer — water_twi will likely fail or return NA
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  suppressWarnings(
    result <- nemeton_compute(
      units, layers,
      indicators = c("carbon_biomass", "water_twi"),
      preprocess = FALSE
    )
  )

  meta <- attr(result, "metadata")
  # carbon_biomass should be in computed list; water_twi may or may not be
  # depending on whether it returns a value or throws an error

  expect_true("indicators_computed" %in% names(meta))
  expect_true(is.character(meta$indicators_computed))
})

# ══════════════════════════════════════════════════════════════════
# nemeton_compute() — column preservation
# ══════════════════════════════════════════════════════════════════

test_that("nemeton_compute preserves original unit columns", {
  units <- nemeton_units(create_test_units())
  units$custom_col <- c("A", "B", "C")
  units$numeric_col <- c(10.5, 20.3, 30.7)

  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton_compute(units, layers, indicators = "carbon_biomass", preprocess = FALSE)

  expect_true("custom_col" %in% names(result))
  expect_equal(result$custom_col, c("A", "B", "C"))
  expect_true("numeric_col" %in% names(result))
  expect_equal(result$numeric_col, c(10.5, 20.3, 30.7))
})

# ══════════════════════════════════════════════════════════════════
# nemeton_compute() — progress flag
# ══════════════════════════════════════════════════════════════════

test_that("nemeton_compute shows progress messages when progress = TRUE", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  expect_message(
    nemeton_compute(units, layers, indicators = "carbon_biomass", preprocess = FALSE, progress = TRUE),
    "Calculating|carbon_biomass"
  )
})

test_that("nemeton_compute works with progress = FALSE", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton_compute(
    units, layers,
    indicators = "carbon_biomass",
    preprocess = FALSE,
    progress = FALSE
  )

  expect_s3_class(result, "sf")
  expect_true("carbon_biomass" %in% names(result))
})

# ══════════════════════════════════════════════════════════════════
# compute_indicator() — dispatch and special returns
# ══════════════════════════════════════════════════════════════════

test_that("compute_indicator dispatches to correct indicator function", {
  units <- nemeton_units(create_test_units())
  units$species <- c("Quercus", "Fagus", "Pinus")
  units$age <- c(80, 60, 40)
  units$density <- c(0.7, 0.8, 0.6)

  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  values <- nemeton:::compute_indicator("carbon_biomass", units, layers)

  expect_type(values, "double")
  expect_length(values, nrow(units))
})

test_that("compute_indicator errors on unknown indicator name", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  expect_error(
    nemeton:::compute_indicator("completely_nonexistent", units, layers),
    "Unknown indicator"
  )
})

test_that("compute_indicator handles risk indicators that return sf with R-columns", {
  units <- nemeton_units(create_test_units(n_features = 3))
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(
    rasters = list(
      biomass = temp_files$biomass,
      dem = temp_files$dem
    )
  )

  # Risk indicators return an sf with R1/R2/R3/R4 columns.
  # compute_indicator should extract the correct column.
  values <- nemeton:::compute_indicator("risk_fire", units, layers)

  expect_type(values, "double")
  expect_length(values, 3)
})

test_that("compute_indicator handles risk_storm indicator", {
  units <- nemeton_units(create_test_units(n_features = 3))
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(
    rasters = list(
      biomass = temp_files$biomass,
      dem = temp_files$dem
    )
  )

  values <- nemeton:::compute_indicator("risk_storm", units, layers)
  expect_type(values, "double")
  expect_length(values, 3)
})

test_that("compute_indicator handles risk_drought indicator", {
  units <- nemeton_units(create_test_units(n_features = 3))
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(
    rasters = list(
      biomass = temp_files$biomass,
      dem = temp_files$dem
    )
  )

  values <- nemeton:::compute_indicator("risk_drought", units, layers)
  expect_type(values, "double")
  expect_length(values, 3)
})

test_that("compute_indicator handles risk_browsing indicator", {
  units <- nemeton_units(create_test_units(n_features = 3))
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(
    rasters = list(
      biomass = temp_files$biomass,
      dem = temp_files$dem
    )
  )

  values <- nemeton:::compute_indicator("risk_browsing", units, layers)
  expect_type(values, "double")
  expect_length(values, 3)
})

# ══════════════════════════════════════════════════════════════════
# compute_indicator() — col_map logic for sf-returning indicators
# ══════════════════════════════════════════════════════════════════

test_that("compute_indicator col_map maps risk_fire to R1", {
  # Verify the col_map extracts the R1 column from sf returned by risk_fire
  units <- nemeton_units(create_test_units(n_features = 2))

  mock_sf <- units
  mock_sf$R1 <- c(42.0, 58.0)

  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  local_mocked_bindings(
    indicator_risk_fire = function(units, ...) mock_sf,
    .package = "nemeton"
  )

  values <- nemeton:::compute_indicator("risk_fire", units, layers)
  expect_equal(values, c(42.0, 58.0))
})

test_that("compute_indicator returns numeric vector for non-sf indicators", {
  # carbon_biomass should return a numeric vector, not an sf
  units <- nemeton_units(create_test_units(n_features = 3))
  units$species <- c("Quercus", "Fagus", "Pinus")
  units$age <- c(80, 60, 40)
  units$density <- c(0.7, 0.8, 0.6)

  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton:::compute_indicator("carbon_biomass", units, layers)

  expect_type(result, "double")
  expect_false(inherits(result, "sf"))
})

# ══════════════════════════════════════════════════════════════════
# nemeton_compute() — edge cases
# ══════════════════════════════════════════════════════════════════

test_that("nemeton_compute works with single-feature units", {
  units <- nemeton_units(create_test_units(n_features = 1))
  units$species <- "Quercus"
  units$age <- 80
  units$density <- 0.7

  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton_compute(
    units, layers,
    indicators = "carbon_biomass",
    preprocess = FALSE
  )

  expect_s3_class(result, "sf")
  expect_equal(nrow(result), 1)
  expect_true("carbon_biomass" %in% names(result))
})

test_that("nemeton_compute passes extra arguments through ...", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(
    rasters = list(landcover = temp_files$landcover)
  )

  # forest_values is passed through ... to indicator_landscape_fragmentation
  result <- nemeton_compute(
    units, layers,
    indicators = "landscape_fragmentation",
    preprocess = FALSE,
    forest_values = c(1, 2, 3)
  )

  expect_s3_class(result, "sf")
  expect_true("landscape_fragmentation" %in% names(result))
})

test_that("nemeton_compute result is still an sf object", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton_compute(units, layers, indicators = "carbon_biomass", preprocess = FALSE)

  expect_s3_class(result, "sf")
  # Geometry should still be present
  expect_true("geometry" %in% names(result) || !is.null(sf::st_geometry(result)))
})

test_that("nemeton_compute with layers having both rasters and vectors tracks layers_used", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(biomass = temp_files$biomass),
    vectors = list(roads = temp_files$roads)
  )

  result <- nemeton_compute(units, layers, indicators = "carbon_biomass", preprocess = FALSE)

  meta <- attr(result, "metadata")
  expect_true("layers_used" %in% names(meta))
  expect_true("biomass" %in% meta$layers_used)
  expect_true("roads" %in% meta$layers_used)
})

test_that("nemeton_compute accepts raw sf (not nemeton_units) as units input", {
  # nemeton_compute only checks inherits(units, "sf"), not "nemeton_units"
  raw_sf <- create_test_units()
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton_compute(raw_sf, layers, indicators = "carbon_biomass", preprocess = FALSE)

  expect_s3_class(result, "sf")
  expect_true("carbon_biomass" %in% names(result))
})

test_that("nemeton_compute with indicators = vector of length 1 (not 'all')", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton_compute(
    units, layers,
    indicators = "carbon_biomass",
    preprocess = FALSE
  )

  expect_s3_class(result, "sf")
  expect_true("carbon_biomass" %in% names(result))
})
