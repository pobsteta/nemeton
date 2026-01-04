test_that("indicator_carbon calculates carbon stock from biomass", {
  units <- nemeton_units(create_test_units(n_features = 3))
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(biomass = temp_files$biomass)
  )

  carbon <- indicator_carbon(units, layers)

  expect_type(carbon, "double")
  expect_length(carbon, 3)
  expect_false(any(is.na(carbon)))
  expect_true(all(carbon >= 0))
})

test_that("indicator_carbon applies conversion factor correctly", {
  units <- nemeton_units(create_test_units(n_features = 2))
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  # Default factor (0.47)
  carbon_default <- indicator_carbon(units, layers)

  # Custom factor (1.0 = no conversion)
  carbon_no_conversion <- indicator_carbon(units, layers, conversion_factor = 1.0)

  # With factor 1.0 should be larger
  expect_true(all(carbon_no_conversion >= carbon_default))
})

test_that("indicator_carbon supports different summary functions", {
  units <- nemeton_units(create_test_units(n_features = 2))
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  carbon_mean <- indicator_carbon(units, layers, fun = "mean")
  carbon_sum <- indicator_carbon(units, layers, fun = "sum")
  carbon_max <- indicator_carbon(units, layers, fun = "max")

  expect_type(carbon_mean, "double")
  expect_type(carbon_sum, "double")
  expect_type(carbon_max, "double")

  # Sum should generally be larger than mean
  expect_true(all(carbon_sum >= carbon_mean))
})

test_that("indicator_carbon errors when biomass layer missing", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()

  # Create layers without biomass
  layers <- nemeton_layers(rasters = list(dem = temp_files$dem))

  expect_error(
    indicator_carbon(units, layers),
    "not found"
  )
})

test_that("indicator_carbon validates inputs", {
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  # Non-sf units
  expect_error(
    indicator_carbon(data.frame(x = 1:3), layers),
    "must be an.*sf.*object"
  )

  # Non-nemeton_layers
  units <- nemeton_units(create_test_units())
  expect_error(
    indicator_carbon(units, list()),
    "must be a.*nemeton_layers.*object"
  )
})

test_that("indicator_biodiversity calculates from richness raster", {
  units <- nemeton_units(create_test_units(n_features = 3))
  temp_files <- create_temp_test_files()

  # Use biomass as proxy for species richness
  layers <- nemeton_layers(
    rasters = list(species_richness = temp_files$biomass)
  )

  biodiv <- indicator_biodiversity(units, layers)

  expect_type(biodiv, "double")
  expect_length(biodiv, 3)
  expect_false(any(is.na(biodiv)))
})

test_that("indicator_biodiversity supports different indices", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(species_richness = temp_files$biomass))

  # All index types should work
  richness <- indicator_biodiversity(units, layers, index = "richness")
  shannon <- indicator_biodiversity(units, layers, index = "shannon")
  simpson <- indicator_biodiversity(units, layers, index = "simpson")

  expect_type(richness, "double")
  expect_type(shannon, "double")
  expect_type(simpson, "double")
})

test_that("indicator_biodiversity errors when layer missing", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(dem = temp_files$dem))

  expect_error(
    indicator_biodiversity(units, layers),
    "not found"
  )
})

test_that("indicator_water calculates from DEM and water layers", {
  units <- nemeton_units(create_test_units(n_features = 3))
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(dem = temp_files$dem),
    vectors = list(water = temp_files$water)
  )

  water <- indicator_water(units, layers)

  expect_type(water, "double")
  expect_length(water, 3)
  expect_false(any(is.na(water)))
  expect_true(all(water >= 0 & water <= 1))
})

test_that("indicator_water can calculate TWI only", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(dem = temp_files$dem)
  )

  water <- indicator_water(units, layers, calculate_proximity = FALSE)

  expect_type(water, "double")
  expect_false(any(is.na(water)))
})

test_that("indicator_water can calculate proximity only", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    vectors = list(water = temp_files$water)
  )

  water <- indicator_water(units, layers, calculate_twi = FALSE)

  expect_type(water, "double")
  expect_false(any(is.na(water)))
})

test_that("indicator_water applies weights correctly", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(dem = temp_files$dem),
    vectors = list(water = temp_files$water)
  )

  # Equal weights
  water_equal <- indicator_water(units, layers, weights = c(0.5, 0.5))

  # TWI dominant
  water_twi <- indicator_water(units, layers, weights = c(0.9, 0.1))

  expect_type(water_equal, "double")
  expect_type(water_twi, "double")
})

test_that("indicator_water errors when both components disabled", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(dem = temp_files$dem))

  expect_error(
    indicator_water(units, layers, calculate_twi = FALSE, calculate_proximity = FALSE),
    "At least one"
  )
})

test_that("indicator_water handles missing layers gracefully", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()

  # Only DEM, but try to calculate proximity
  layers <- nemeton_layers(rasters = list(dem = temp_files$dem))

  expect_warning(
    water <- indicator_water(units, layers, calculate_proximity = TRUE),
    "not found"
  )

  # Should still return values (TWI only)
  expect_type(water, "double")
})

test_that("indicator_fragmentation calculates forest percentage", {
  units <- nemeton_units(create_test_units(n_features = 3))
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(landcover = temp_files$landcover)
  )

  # Forest values: 1, 2, 3
  frag <- indicator_fragmentation(units, layers, forest_values = c(1, 2, 3))

  expect_type(frag, "double")
  expect_length(frag, 3)
  expect_false(any(is.na(frag)))
  expect_true(all(frag >= 0 & frag <= 100))
})

test_that("indicator_fragmentation requires forest_values parameter", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(landcover = temp_files$landcover))

  expect_error(
    indicator_fragmentation(units, layers),
    "must be specified"
  )
})

test_that("indicator_fragmentation warns for unimplemented metrics", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(landcover = temp_files$landcover))

  expect_warning(
    frag <- indicator_fragmentation(
      units, layers,
      forest_values = c(1, 2),
      metric = "edge_density"
    ),
    "not implemented"
  )

  # Should fall back to forest_pct
  expect_type(frag, "double")
})

test_that("indicator_fragmentation errors when layer missing", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(dem = temp_files$dem))

  expect_error(
    indicator_fragmentation(units, layers, forest_values = c(1)),
    "not found"
  )
})

test_that("indicator_accessibility calculates from roads", {
  units <- nemeton_units(create_test_units(n_features = 3))
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    vectors = list(roads = temp_files$roads)
  )

  access <- indicator_accessibility(units, layers)

  expect_type(access, "double")
  expect_length(access, 3)
  expect_false(any(is.na(access)))
  expect_true(all(access >= 0 & access <= 1))
})

test_that("indicator_accessibility can include trails", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()

  # Use water layer as fake trails
  layers <- nemeton_layers(
    vectors = list(
      roads = temp_files$roads,
      trails = temp_files$water
    )
  )

  access <- indicator_accessibility(units, layers, trails_layer = "trails")

  expect_type(access, "double")
})

test_that("indicator_accessibility applies weights correctly", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    vectors = list(roads = temp_files$roads)
  )

  # Different weights
  access1 <- indicator_accessibility(units, layers, road_weight = 0.8)
  access2 <- indicator_accessibility(units, layers, road_weight = 0.5)

  expect_type(access1, "double")
  expect_type(access2, "double")
})

test_that("indicator_accessibility can be inverted to remoteness", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(vectors = list(roads = temp_files$roads))

  accessibility <- indicator_accessibility(units, layers, invert = FALSE)
  remoteness <- indicator_accessibility(units, layers, invert = TRUE)

  # Should be inversely related
  expect_true(all(abs((accessibility + remoteness) - 1) < 0.001))
})

test_that("indicator_accessibility handles missing roads layer", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(vectors = list(water = temp_files$water))

  expect_warning(
    access <- indicator_accessibility(units, layers),
    "not found"
  )

  # Should return zeros (no accessibility)
  expect_true(all(access == 0))
})

test_that("indicator_accessibility respects max_distance", {
  units <- nemeton_units(create_test_units())
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(vectors = list(roads = temp_files$roads))

  # Very small max distance
  access_small <- indicator_accessibility(units, layers, max_distance = 10)

  # Large max distance
  access_large <- indicator_accessibility(units, layers, max_distance = 10000)

  expect_type(access_small, "double")
  expect_type(access_large, "double")
})

test_that("all indicators validate input types", {
  temp_files <- create_temp_test_files()

  # Non-sf units should error for all indicators
  expect_error(
    indicator_carbon(data.frame(x = 1), nemeton_layers(rasters = list(biomass = temp_files$biomass))),
    "must be an.*sf"
  )

  expect_error(
    indicator_biodiversity(data.frame(x = 1), nemeton_layers(rasters = list(species_richness = temp_files$biomass))),
    "must be an.*sf"
  )

  expect_error(
    indicator_water(data.frame(x = 1), nemeton_layers(rasters = list(dem = temp_files$dem))),
    "must be an.*sf"
  )

  expect_error(
    indicator_fragmentation(data.frame(x = 1), nemeton_layers(rasters = list(landcover = temp_files$landcover)), forest_values = 1),
    "must be an.*sf"
  )

  expect_error(
    indicator_accessibility(data.frame(x = 1), nemeton_layers(vectors = list(roads = temp_files$roads))),
    "must be an.*sf"
  )
})

test_that("all indicators return correct length vectors", {
  units <- nemeton_units(create_test_units(n_features = 5))
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(
      biomass = temp_files$biomass,
      species_richness = temp_files$biomass,
      dem = temp_files$dem,
      landcover = temp_files$landcover
    ),
    vectors = list(
      roads = temp_files$roads,
      water = temp_files$water
    )
  )

  # Each indicator should return exactly 5 values
  expect_length(indicator_carbon(units, layers), 5)
  expect_length(indicator_biodiversity(units, layers), 5)
  expect_length(indicator_water(units, layers), 5)
  expect_length(indicator_fragmentation(units, layers, forest_values = c(1, 2)), 5)
  expect_length(indicator_accessibility(units, layers), 5)
})
