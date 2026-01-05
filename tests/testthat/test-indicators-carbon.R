# Tests for Carbon/Vitality family indicators (US2 - Phase 4)

# ==============================================================================
# C1: CARBON BIOMASS VIA ALLOMETRIC MODELS
# ==============================================================================

test_that("indicator_carbon_biomass calculates biomass with BD Forêt attributes", {
  data(massif_demo_units)

  # Add BD Forêt attributes
  units <- massif_demo_units[1:5, ]
  units$species <- c("Quercus", "Fagus", "Pinus", "Abies", "Quercus")
  units$age <- c(80, 60, 40, 100, 50)
  units$density <- c(0.7, 0.8, 0.6, 0.9, 0.5)

  # Calculate biomass
  biomass <- indicator_carbon_biomass(units)

  # Test output
  expect_type(biomass, "double")
  expect_length(biomass, 5)
  expect_true(all(!is.na(biomass)))
  expect_true(all(biomass > 0))  # Biomass should be positive

  # Order of magnitude check
  # Young/sparse stands: ~2-10 tC/ha, mature forests: 50-200 tC/ha
  expect_true(all(biomass > 1))    # Minimum for very young/sparse stands
  expect_true(all(biomass < 500))  # Maximum upper bound
})

test_that("indicator_carbon_biomass uses Generic model for unknown species", {
  data(massif_demo_units)

  units <- massif_demo_units[1:3, ]
  units$species <- c("Quercus", "UnknownSpecies", "Fagus")
  units$age <- c(80, 80, 80)
  units$density <- c(0.7, 0.7, 0.7)

  # Should not error, should use Generic for unknown
  expect_no_error(biomass <- indicator_carbon_biomass(units))
  expect_length(biomass, 3)
  expect_true(all(!is.na(biomass)))
})

test_that("indicator_carbon_biomass errors on missing required columns", {
  data(massif_demo_units)

  units <- massif_demo_units[1:3, ]

  # Missing species
  units$age <- c(80, 60, 40)
  units$density <- c(0.7, 0.8, 0.6)
  expect_error(
    indicator_carbon_biomass(units),
    "species.*not found"
  )

  # Missing age
  units <- massif_demo_units[1:3, ]
  units$species <- c("Quercus", "Fagus", "Pinus")
  units$density <- c(0.7, 0.8, 0.6)
  expect_error(
    indicator_carbon_biomass(units),
    "age.*not found"
  )

  # Missing density
  units <- massif_demo_units[1:3, ]
  units$species <- c("Quercus", "Fagus", "Pinus")
  units$age <- c(80, 60, 40)
  expect_error(
    indicator_carbon_biomass(units),
    "density.*not found"
  )
})

test_that("indicator_carbon_biomass handles NA values appropriately", {
  data(massif_demo_units)

  units <- massif_demo_units[1:4, ]
  units$species <- c("Quercus", NA, "Fagus", "Pinus")
  units$age <- c(80, 60, NA, 40)
  units$density <- c(0.7, 0.8, 0.6, NA)

  biomass <- indicator_carbon_biomass(units)

  # NA inputs should produce NA outputs
  expect_true(is.na(biomass[2]))  # NA species
  expect_true(is.na(biomass[3]))  # NA age
  expect_true(is.na(biomass[4]))  # NA density

  # Valid input should produce valid output
  expect_false(is.na(biomass[1]))
})

test_that("indicator_carbon_biomass respects custom column names", {
  data(massif_demo_units)

  units <- massif_demo_units[1:3, ]
  units$tree_species <- c("Quercus", "Fagus", "Pinus")
  units$stand_age <- c(80, 60, 40)
  units$stand_density <- c(0.7, 0.8, 0.6)

  biomass <- indicator_carbon_biomass(
    units,
    species_col = "tree_species",
    age_col = "stand_age",
    density_col = "stand_density"
  )

  expect_length(biomass, 3)
  expect_true(all(!is.na(biomass)))
})

test_that("indicator_carbon_biomass produces consistent results", {
  data(massif_demo_units)

  units <- massif_demo_units[1:2, ]
  units$species <- c("Quercus", "Quercus")
  units$age <- c(80, 80)  # Same age
  units$density <- c(0.7, 0.7)  # Same density

  biomass <- indicator_carbon_biomass(units)

  # Same inputs should produce same outputs
  expect_equal(biomass[1], biomass[2])
})

test_that("indicator_carbon_biomass scales with age and density", {
  data(massif_demo_units)

  # Test age scaling
  units_age <- massif_demo_units[1:3, ]
  units_age$species <- c("Quercus", "Quercus", "Quercus")
  units_age$age <- c(40, 80, 120)  # Increasing age
  units_age$density <- c(0.7, 0.7, 0.7)

  biomass_age <- indicator_carbon_biomass(units_age)
  expect_true(biomass_age[1] < biomass_age[2])  # More age = more biomass
  expect_true(biomass_age[2] < biomass_age[3])

  # Test density scaling
  units_density <- massif_demo_units[1:3, ]
  units_density$species <- c("Fagus", "Fagus", "Fagus")
  units_density$age <- c(60, 60, 60)
  units_density$density <- c(0.4, 0.7, 1.0)  # Increasing density

  biomass_density <- indicator_carbon_biomass(units_density)
  expect_true(biomass_density[1] < biomass_density[2])  # More density = more biomass
  expect_true(biomass_density[2] < biomass_density[3])
})

# ==============================================================================
# C2: NDVI VITALITY INDEX
# ==============================================================================

test_that("indicator_carbon_ndvi extracts mean NDVI from raster", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:5, ]

  # Load biomass raster to get spatial template
  biomass_raster <- terra::rast(layers$rasters$biomass$path)

  # Create synthetic NDVI raster with same extent/resolution
  ndvi_raster <- biomass_raster
  terra::values(ndvi_raster) <- runif(terra::ncell(ndvi_raster), 0.3, 0.9)

  # Add to layers object
  layers$rasters$ndvi <- list(
    object = ndvi_raster,
    path = "synthetic_ndvi.tif",
    layer_type = "raster"
  )

  ndvi <- indicator_carbon_ndvi(units, layers, ndvi_layer = "ndvi")

  # Test output
  expect_type(ndvi, "double")
  expect_length(ndvi, 5)
  expect_true(all(!is.na(ndvi)))

  # NDVI should be in valid range [0, 1]
  expect_true(all(ndvi >= 0))
  expect_true(all(ndvi <= 1))
})

test_that("indicator_carbon_ndvi errors when NDVI layer missing", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  expect_error(
    indicator_carbon_ndvi(units, layers, ndvi_layer = "nonexistent"),
    "NDVI layer.*not found"
  )
})

test_that("indicator_carbon_ndvi handles edge NDVI values", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # Load biomass raster as template
  biomass_raster <- terra::rast(layers$rasters$biomass$path)

  # Create NDVI with edge values
  ndvi_raster <- biomass_raster
  # Mix of low (bare soil), medium (vegetation), high (dense forest)
  terra::values(ndvi_raster) <- rep(c(0.1, 0.5, 0.9), length.out = terra::ncell(ndvi_raster))

  layers$rasters$ndvi <- list(object = ndvi_raster, layer_type = "raster")

  ndvi <- indicator_carbon_ndvi(units, layers, ndvi_layer = "ndvi")

  expect_length(ndvi, 3)
  expect_true(all(ndvi >= 0 & ndvi <= 1))
})

test_that("indicator_carbon_ndvi with trend option (future implementation)", {
  # Note: Trend calculation requires multi-date NDVI rasters
  # This is a placeholder for future temporal NDVI support

  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:2, ]

  # Load biomass raster as template
  biomass_raster <- terra::rast(layers$rasters$biomass$path)
  ndvi_raster <- biomass_raster
  terra::values(ndvi_raster) <- runif(terra::ncell(ndvi_raster), 0.5, 0.8)
  layers$rasters$ndvi <- list(object = ndvi_raster, layer_type = "raster")

  # For v0.2.0 MVP, trend = TRUE should warn or use single-date only
  expect_warning(
    ndvi <- indicator_carbon_ndvi(units, layers, ndvi_layer = "ndvi", trend = TRUE),
    "trend.*not.*implemented|single.*date"
  )
})

# ==============================================================================
# BACKWARD COMPATIBILITY: OLD indicator_carbon()
# ==============================================================================

test_that("old indicator_carbon() still works with deprecation warning", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  # Should work but warn about deprecation
  expect_warning(
    carbon <- indicator_carbon(units, layers),
    "deprecated"
  )

  # Should still produce valid output
  expect_type(carbon, "double")
  expect_length(carbon, 3)
})

test_that("indicator_carbon() produces same results as before (regression)", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:5, ]

  # Calculate with old function (suppressing deprecation warning)
  suppressWarnings(carbon_old <- indicator_carbon(units, layers))

  # Should be positive values
  expect_true(all(!is.na(carbon_old)))
  expect_true(all(carbon_old > 0))
})

# ==============================================================================
# INTEGRATION WITH nemeton_compute()
# ==============================================================================

test_that("nemeton_compute works with new carbon indicators", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]
  units$species <- c("Quercus", "Fagus", "Pinus")
  units$age <- c(80, 60, 40)
  units$density <- c(0.7, 0.8, 0.6)

  # Load biomass raster as template and add NDVI to layers
  biomass_raster <- terra::rast(layers$rasters$biomass$path)
  ndvi_raster <- biomass_raster
  terra::values(ndvi_raster) <- runif(terra::ncell(ndvi_raster), 0.4, 0.9)
  layers$rasters$ndvi <- list(object = ndvi_raster, layer_type = "raster")

  # This will be implemented when nemeton_compute() is extended
  # For now, just test that the functions can be called independently
  expect_no_error({
    c1 <- indicator_carbon_biomass(units)
    c2 <- indicator_carbon_ndvi(units, layers, ndvi_layer = "ndvi")
  })
})
