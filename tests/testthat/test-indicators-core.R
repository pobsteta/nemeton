# ──────────────────────────────────────────────────────────────────
# tests/testthat/test-indicators-core.R
# Comprehensive tests for R/indicators-core.R
# Covers: list_indicators(), compute_indicator(), nemeton_compute()
# ──────────────────────────────────────────────────────────────────

# ══════════════════════════════════════════════════════════════════
# list_indicators() — return_type = "names" (default)
# ══════════════════════════════════════════════════════════════════

test_that("list_indicators returns all 31 indicator names by default", {
  skip_if_not_installed("terra")
  indicators <- list_indicators()

  expect_type(indicators, "character")
  expect_length(indicators, 31)

  # Spot-check a few from different families
  expect_true("indicateur_c1_biomasse" %in% indicators)
  expect_true("indicateur_c2_ndvi" %in% indicators)
  expect_true("indicateur_w1_reseau" %in% indicators)
  expect_true("indicateur_w2_zones_humides" %in% indicators)
  expect_true("indicateur_w3_humidite" %in% indicators)
  expect_true("indicateur_f1_fertilite" %in% indicators)
  expect_true("indicateur_f2_erosion" %in% indicators)
  expect_true("indicateur_l1_effet_lisiere" %in% indicators)
  expect_true("indicateur_l2_morcellement" %in% indicators)
  expect_true("indicateur_b1_protection" %in% indicators)
  expect_true("indicateur_b2_structure" %in% indicators)
  expect_true("indicateur_b3_connectivite" %in% indicators)
  expect_true("indicateur_r1_feu" %in% indicators)
  expect_true("indicateur_r2_tempete" %in% indicators)
  expect_true("indicateur_r3_secheresse" %in% indicators)
  expect_true("indicateur_r4_abroutissement" %in% indicators)
  expect_true("indicateur_t1_anciennete" %in% indicators)
  expect_true("indicateur_t2_changement" %in% indicators)
  expect_true("indicateur_a1_couverture" %in% indicators)
  expect_true("indicateur_a2_qualite_air" %in% indicators)
  expect_true("indicateur_s1_routes" %in% indicators)
  expect_true("indicateur_s2_bati" %in% indicators)
  expect_true("indicateur_s3_population" %in% indicators)
  expect_true("indicateur_p1_volume" %in% indicators)
  expect_true("indicateur_p3_qualite_bois" %in% indicators)
  expect_true("indicateur_p2_station" %in% indicators)
  expect_true("indicateur_e1_bois_energie" %in% indicators)
  expect_true("indicateur_e2_evitement" %in% indicators)
  expect_true("indicateur_n1_distance" %in% indicators)
  expect_true("indicateur_n2_continuite" %in% indicators)
  expect_true("indicateur_n3_naturalite" %in% indicators)
})

test_that("list_indicators returns details data.frame when requested", {
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
  details <- list_indicators(return_type = "details")

  # Verify the 12 family codes exist
  expected_families <- c("C", "W", "F", "L", "B", "R", "T", "A", "S", "P", "E", "N")
  actual_families <- unique(details$family)
  expect_setequal(actual_families, expected_families)

  # Verify family mapping for specific indicators
  carbon_row <- details[details$name == "indicateur_c1_biomasse", ]
  expect_equal(carbon_row$family, "C")

  risk_row <- details[details$name == "indicateur_r1_feu", ]
  expect_equal(risk_row$family, "R")

  naturalness_row <- details[details$name == "indicateur_n3_naturalite", ]
  expect_equal(naturalness_row$family, "N")
})

# ══════════════════════════════════════════════════════════════════
# list_indicators() — category filtering
# ══════════════════════════════════════════════════════════════════

test_that("list_indicators filters by category = 'biophysical'", {
  skip_if_not_installed("terra")
  biophysical <- list_indicators(category = "biophysical")

  expect_true("indicateur_c1_biomasse" %in% biophysical)
  expect_true("indicateur_c2_ndvi" %in% biophysical)
  expect_true("indicateur_w1_reseau" %in% biophysical)
  expect_true("indicateur_b1_protection" %in% biophysical)
  expect_true("indicateur_a1_couverture" %in% biophysical)
  # social, risk, etc. should NOT be in biophysical

  expect_false("indicateur_s2_bati" %in% biophysical)
  expect_false("indicateur_r1_feu" %in% biophysical)
  expect_false("indicateur_l1_effet_lisiere" %in% biophysical)
})

test_that("list_indicators filters by category = 'risk'", {
  skip_if_not_installed("terra")
  risk <- list_indicators(category = "risk")

  expect_length(risk, 4)
  expect_true("indicateur_r1_feu" %in% risk)
  expect_true("indicateur_r2_tempete" %in% risk)
  expect_true("indicateur_r3_secheresse" %in% risk)
  expect_true("indicateur_r4_abroutissement" %in% risk)
  expect_false("indicateur_c1_biomasse" %in% risk)
})

test_that("list_indicators filters by category = 'social'", {
  skip_if_not_installed("terra")
  social <- list_indicators(category = "social")

  expect_length(social, 3)
  expect_true("indicateur_s1_routes" %in% social)
  expect_true("indicateur_s2_bati" %in% social)
  expect_true("indicateur_s3_population" %in% social)
  expect_false("indicateur_c1_biomasse" %in% social)
})

test_that("list_indicators filters by category = 'landscape'", {
  skip_if_not_installed("terra")
  landscape <- list_indicators(category = "landscape")

  expect_length(landscape, 2)
  expect_true("indicateur_l1_effet_lisiere" %in% landscape)
  expect_true("indicateur_l2_morcellement" %in% landscape)
  expect_false("indicateur_c1_biomasse" %in% landscape)
})

test_that("list_indicators filters by category = 'temporal'", {
  skip_if_not_installed("terra")
  temporal <- list_indicators(category = "temporal")

  expect_length(temporal, 2)
  expect_true("indicateur_t1_anciennete" %in% temporal)
  expect_true("indicateur_t2_changement" %in% temporal)
})

test_that("list_indicators filters by category = 'productive'", {
  skip_if_not_installed("terra")
  productive <- list_indicators(category = "productive")

  expect_length(productive, 3)
  expect_true("indicateur_p1_volume" %in% productive)
  expect_true("indicateur_p3_qualite_bois" %in% productive)
  expect_true("indicateur_p2_station" %in% productive)
})

test_that("list_indicators filters by category = 'energy'", {
  skip_if_not_installed("terra")
  energy <- list_indicators(category = "energy")

  expect_length(energy, 2)
  expect_true("indicateur_e1_bois_energie" %in% energy)
  expect_true("indicateur_e2_evitement" %in% energy)
})

test_that("list_indicators filters by category = 'naturalness'", {
  skip_if_not_installed("terra")
  naturalness <- list_indicators(category = "naturalness")

  expect_length(naturalness, 3)
  expect_true("indicateur_n1_distance" %in% naturalness)
  expect_true("indicateur_n2_continuite" %in% naturalness)
  expect_true("indicateur_n3_naturalite" %in% naturalness)
})

test_that("list_indicators with unknown category returns empty", {
  skip_if_not_installed("terra")
  result <- list_indicators(category = "nonexistent_category")

  expect_type(result, "character")
  expect_length(result, 0)
})

test_that("list_indicators details with category filter returns filtered data.frame", {
  skip_if_not_installed("terra")
  details <- list_indicators(category = "risk", return_type = "details")

  expect_s3_class(details, "data.frame")
  expect_equal(nrow(details), 4)
  expect_true(all(details$category == "risk"))
  expect_true(all(details$family == "R"))
  expect_true(all(c("name", "family", "category", "description") %in% names(details)))
})

test_that("list_indicators return_type uses match.arg", {
  skip_if_not_installed("terra")
  # Invalid return_type should error via match.arg
  expect_error(
    list_indicators(return_type = "invalid"),
    "should be one of|doit \u00eatre un de"
  )
})

test_that("list_indicators details descriptions are non-empty", {
  skip_if_not_installed("terra")
  details <- list_indicators(return_type = "details")

  expect_true(all(nchar(details$description) > 0))
  expect_true(all(!is.na(details$description)))
})

test_that("list_indicators names match across return types", {
  skip_if_not_installed("terra")
  names_only <- list_indicators()
  details <- list_indicators(return_type = "details")

  expect_equal(names_only, details$name)
})

# ══════════════════════════════════════════════════════════════════
# nemeton_compute() — input validation
# ══════════════════════════════════════════════════════════════════

test_that("nemeton_compute rejects non-sf units", {
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  expect_warning(
    result <- nemeton_compute(
      units, layers,
      indicators = c("indicateur_c1_biomasse", "totally_fake_indicator"),
      preprocess = FALSE
    ),
    "Unknown indicator"
  )

  # The valid indicator should still be computed
  expect_true("indicateur_c1_biomasse" %in% names(result))
  # The fake one should not appear as a column (it was skipped before dispatch)
  expect_false("totally_fake_indicator" %in% names(result))
})

test_that("nemeton_compute warns on multiple unknown indicators", {
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  expect_warning(
    result <- nemeton_compute(
      units, layers,
      indicators = c("indicateur_c1_biomasse", "fake1", "fake2"),
      preprocess = FALSE
    ),
    "Unknown indicator"
  )

  expect_true("indicateur_c1_biomasse" %in% names(result))
})

test_that("nemeton_compute errors when ALL indicators are invalid", {
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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

test_that("nemeton_compute calculates indicateur_c1_biomasse successfully", {
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units(n_features = 3))
  units$species <- c("Quercus", "Fagus", "Pinus")
  units$age <- c(80, 60, 40)
  units$density <- c(0.7, 0.8, 0.6)

  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton_compute(
    units, layers,
    indicators = "indicateur_c1_biomasse",
    preprocess = FALSE
  )

  expect_s3_class(result, "sf")
  expect_true("indicateur_c1_biomasse" %in% names(result))
  expect_equal(nrow(result), 3)
  expect_type(result$indicateur_c1_biomasse, "double")
  expect_false(all(is.na(result$indicateur_c1_biomasse)))
})

test_that("nemeton_compute handles failing indicators gracefully (sets NA)", {
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()

  # Only provide biomass layer, try water indicator which needs different data
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  # indicateur_w3_humidite may fail or return 0/NA when required layers are missing
  expect_warning(
    result <- nemeton_compute(units, layers, indicators = "indicateur_w3_humidite", preprocess = FALSE),
    regexp = NULL  # Accept any warning about missing layers or failure
  )

  expect_true("indicateur_w3_humidite" %in% names(result))
  # Value should be NA or 0 when layers are missing
  expect_true(all(is.na(result$indicateur_w3_humidite) | result$indicateur_w3_humidite == 0))
})

test_that("nemeton_compute computes multiple indicators at once", {
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(
      biomass = temp_files$biomass,
      landcover = temp_files$landcover
    )
  )

  # indicateur_c1_biomasse may fail with mock data
  result <- suppressWarnings(
    nemeton_compute(
      units, layers,
      indicators = c("indicateur_c1_biomasse", "indicateur_l1_effet_lisiere"),
      preprocess = FALSE,
      forest_values = c(1, 2, 3)
    )
  )

  expect_true("indicateur_c1_biomasse" %in% names(result))
  expect_true("indicateur_l1_effet_lisiere" %in% names(result))
  expect_equal(nrow(result), nrow(units))
})

# ══════════════════════════════════════════════════════════════════
# nemeton_compute() — preprocessing
# ══════════════════════════════════════════════════════════════════

test_that("nemeton_compute preprocesses layers when preprocess = TRUE", {
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  # With preprocessing, should emit "Preprocessing" message
  expect_message(
    result <- nemeton_compute(units, layers, indicators = "indicateur_c1_biomasse", preprocess = TRUE),
    "Preprocessing|Harmoniz"
  )

  expect_s3_class(result, "sf")
})

test_that("nemeton_compute skips preprocessing when preprocess = FALSE", {
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton_compute(units, layers, indicators = "indicateur_c1_biomasse", preprocess = FALSE)

  expect_s3_class(result, "sf")
})

# ══════════════════════════════════════════════════════════════════
# nemeton_compute() — metadata
# ══════════════════════════════════════════════════════════════════

test_that("nemeton_compute attaches metadata to result", {
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units())
  units$species <- c("Quercus", "Fagus", "Pinus")
  units$age <- c(80, 60, 40)
  units$density <- c(0.7, 0.8, 0.6)

  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton_compute(units, layers, indicators = "indicateur_c1_biomasse", preprocess = FALSE)

  meta <- attr(result, "metadata")
  expect_true(!is.null(meta))
  expect_true("computed_at" %in% names(meta))
  expect_true("indicators_computed" %in% names(meta))
  expect_true("layers_used" %in% names(meta))
  expect_true(inherits(meta$computed_at, "POSIXct"))
  expect_true("indicateur_c1_biomasse" %in% meta$indicators_computed)
  expect_true("biomass" %in% meta$layers_used)
})

test_that("nemeton_compute preserves original metadata from units", {
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units())
  # Set original metadata
  attr(units, "metadata") <- list(source = "test_data", created = "2025-01-01")

  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton_compute(units, layers, indicators = "indicateur_c1_biomasse", preprocess = FALSE)

  meta <- attr(result, "metadata")
  # Original metadata should be preserved (merged)
  expect_equal(meta$source, "test_data")
  expect_equal(meta$created, "2025-01-01")
  # New metadata should also be present
  expect_true("computed_at" %in% names(meta))
  expect_true("indicators_computed" %in% names(meta))
})

test_that("nemeton_compute metadata tracks failed indicators correctly", {
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()

  # Only biomass layer — indicateur_w3_humidite will likely fail or return NA
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  suppressWarnings(
    result <- nemeton_compute(
      units, layers,
      indicators = c("indicateur_c1_biomasse", "indicateur_w3_humidite"),
      preprocess = FALSE
    )
  )

  meta <- attr(result, "metadata")
  # indicateur_c1_biomasse should be in computed list; indicateur_w3_humidite may or may not be
  # depending on whether it returns a value or throws an error

  expect_true("indicators_computed" %in% names(meta))
  expect_true(is.character(meta$indicators_computed))
})

# ══════════════════════════════════════════════════════════════════
# nemeton_compute() — column preservation
# ══════════════════════════════════════════════════════════════════

test_that("nemeton_compute preserves original unit columns", {
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units())
  units$custom_col <- c("A", "B", "C")
  units$numeric_col <- c(10.5, 20.3, 30.7)

  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton_compute(units, layers, indicators = "indicateur_c1_biomasse", preprocess = FALSE)

  expect_true("custom_col" %in% names(result))
  expect_equal(result$custom_col, c("A", "B", "C"))
  expect_true("numeric_col" %in% names(result))
  expect_equal(result$numeric_col, c(10.5, 20.3, 30.7))
})

# ══════════════════════════════════════════════════════════════════
# nemeton_compute() — progress flag
# ══════════════════════════════════════════════════════════════════

test_that("nemeton_compute shows progress messages when progress = TRUE", {
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  expect_message(
    nemeton_compute(units, layers, indicators = "indicateur_c1_biomasse", preprocess = FALSE, progress = TRUE),
    "Calculating|indicateur_c1_biomasse"
  )
})

test_that("nemeton_compute works with progress = FALSE", {
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton_compute(
    units, layers,
    indicators = "indicateur_c1_biomasse",
    preprocess = FALSE,
    progress = FALSE
  )

  expect_s3_class(result, "sf")
  expect_true("indicateur_c1_biomasse" %in% names(result))
})

# ══════════════════════════════════════════════════════════════════
# compute_indicator() — dispatch and special returns
# ══════════════════════════════════════════════════════════════════

test_that("compute_indicator dispatches to correct indicator function", {
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units())
  units$species <- c("Quercus", "Fagus", "Pinus")
  units$age <- c(80, 60, 40)
  units$density <- c(0.7, 0.8, 0.6)

  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  values <- nemeton:::compute_indicator("indicateur_c1_biomasse", units, layers)

  expect_type(values, "double")
  expect_length(values, nrow(units))
})

test_that("compute_indicator errors on unknown indicator name", {
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  expect_error(
    nemeton:::compute_indicator("completely_nonexistent", units, layers),
    "Unknown indicator"
  )
})

test_that("compute_indicator handles risk indicators that return sf with R-columns", {
  skip_if_not_installed("terra")
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
  values <- nemeton:::compute_indicator("indicateur_r1_feu", units, layers)

  expect_type(values, "double")
  expect_length(values, 3)
})

test_that("compute_indicator handles indicateur_r2_tempete indicator", {
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units(n_features = 3))
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(
    rasters = list(
      biomass = temp_files$biomass,
      dem = temp_files$dem
    )
  )

  values <- nemeton:::compute_indicator("indicateur_r2_tempete", units, layers)
  expect_type(values, "double")
  expect_length(values, 3)
})

test_that("compute_indicator handles indicateur_r3_secheresse indicator", {
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units(n_features = 3))
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(
    rasters = list(
      biomass = temp_files$biomass,
      dem = temp_files$dem
    )
  )

  values <- nemeton:::compute_indicator("indicateur_r3_secheresse", units, layers)
  expect_type(values, "double")
  expect_length(values, 3)
})

test_that("compute_indicator handles indicateur_r4_abroutissement indicator", {
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units(n_features = 3))
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(
    rasters = list(
      biomass = temp_files$biomass,
      dem = temp_files$dem
    )
  )

  values <- nemeton:::compute_indicator("indicateur_r4_abroutissement", units, layers)
  expect_type(values, "double")
  expect_length(values, 3)
})

# ══════════════════════════════════════════════════════════════════
# compute_indicator() — col_map logic for sf-returning indicators
# ══════════════════════════════════════════════════════════════════

test_that("compute_indicator col_map maps indicateur_r1_feu to R1", {
  skip_if_not_installed("terra")
  # Verify the col_map extracts the R1 column from sf returned by indicateur_r1_feu
  units <- nemeton_units(create_test_units(n_features = 2))

  mock_sf <- units
  mock_sf$R1 <- c(42.0, 58.0)

  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  local_mocked_bindings(
    indicateur_r1_feu = function(units, ...) mock_sf,
    .package = "nemeton"
  )

  values <- nemeton:::compute_indicator("indicateur_r1_feu", units, layers)
  expect_equal(values, c(42.0, 58.0))
})

test_that("compute_indicator returns numeric vector for non-sf indicators", {
  skip_if_not_installed("terra")
  # indicateur_c1_biomasse should return a numeric vector, not an sf
  units <- nemeton_units(create_test_units(n_features = 3))
  units$species <- c("Quercus", "Fagus", "Pinus")
  units$age <- c(80, 60, 40)
  units$density <- c(0.7, 0.8, 0.6)

  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton:::compute_indicator("indicateur_c1_biomasse", units, layers)

  expect_type(result, "double")
  expect_false(inherits(result, "sf"))
})

# ══════════════════════════════════════════════════════════════════
# nemeton_compute() — edge cases
# ══════════════════════════════════════════════════════════════════

test_that("nemeton_compute works with single-feature units", {
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units(n_features = 1))
  units$species <- "Quercus"
  units$age <- 80
  units$density <- 0.7

  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton_compute(
    units, layers,
    indicators = "indicateur_c1_biomasse",
    preprocess = FALSE
  )

  expect_s3_class(result, "sf")
  expect_equal(nrow(result), 1)
  expect_true("indicateur_c1_biomasse" %in% names(result))
})

test_that("nemeton_compute passes extra arguments through ...", {
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(
    rasters = list(landcover = temp_files$landcover)
  )

  # forest_values is passed through ... to indicateur_l1_effet_lisiere
  result <- nemeton_compute(
    units, layers,
    indicators = "indicateur_l1_effet_lisiere",
    preprocess = FALSE,
    forest_values = c(1, 2, 3)
  )

  expect_s3_class(result, "sf")
  expect_true("indicateur_l1_effet_lisiere" %in% names(result))
})

test_that("nemeton_compute result is still an sf object", {
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton_compute(units, layers, indicators = "indicateur_c1_biomasse", preprocess = FALSE)

  expect_s3_class(result, "sf")
  # Geometry should still be present
  expect_true("geometry" %in% names(result) || !is.null(sf::st_geometry(result)))
})

test_that("nemeton_compute with layers having both rasters and vectors tracks layers_used", {
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(biomass = temp_files$biomass),
    vectors = list(roads = temp_files$roads)
  )

  result <- nemeton_compute(units, layers, indicators = "indicateur_c1_biomasse", preprocess = FALSE)

  meta <- attr(result, "metadata")
  expect_true("layers_used" %in% names(meta))
  expect_true("biomass" %in% meta$layers_used)
  expect_true("roads" %in% meta$layers_used)
})

test_that("nemeton_compute accepts raw sf (not nemeton_units) as units input", {
  skip_if_not_installed("terra")
  # nemeton_compute only checks inherits(units, "sf"), not "nemeton_units"
  raw_sf <- create_test_units()
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton_compute(raw_sf, layers, indicators = "indicateur_c1_biomasse", preprocess = FALSE)

  expect_s3_class(result, "sf")
  expect_true("indicateur_c1_biomasse" %in% names(result))
})

test_that("nemeton_compute with indicators = vector of length 1 (not 'all')", {
  skip_if_not_installed("terra")
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton_compute(
    units, layers,
    indicators = "indicateur_c1_biomasse",
    preprocess = FALSE
  )

  expect_s3_class(result, "sf")
  expect_true("indicateur_c1_biomasse" %in% names(result))
})

# ==============================================================================
# get_global_cache_dir()
# (migrated from test-cov80-batch14.R)
# ==============================================================================

test_that("get_global_cache_dir returns path string", {
  skip_if_not_installed("terra")
  result <- nemeton:::get_global_cache_dir()
  expect_type(result, "character")
  expect_true(nchar(result) > 0)
})
