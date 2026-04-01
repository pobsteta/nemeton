# Tests for Carbon/Vitality family indicators (US2 - Phase 4)

# ==============================================================================
# C1: CARBON BIOMASS VIA ALLOMETRIC MODELS
# ==============================================================================

test_that("indicateur_c1_biomasse calculates biomass with BD Forêt attributes", {
  data(massif_demo_units)

  # Add BD Forêt attributes
  units <- massif_demo_units[1:5, ]
  units$species <- c("Quercus", "Fagus", "Pinus", "Abies", "Quercus")
  units$age <- c(80, 60, 40, 100, 50)
  units$density <- c(0.7, 0.8, 0.6, 0.9, 0.5)

  # Calculate biomass
  biomass <- indicateur_c1_biomasse(units)

  # Test output
  expect_type(biomass, "double")
  expect_length(biomass, 5)
  expect_true(all(!is.na(biomass)))
  expect_true(all(biomass > 0)) # Biomass should be positive

  # Order of magnitude check
  # Young/sparse stands: ~2-10 tC/ha, mature forests: 50-200 tC/ha
  expect_true(all(biomass > 1)) # Minimum for very young/sparse stands
  expect_true(all(biomass < 500)) # Maximum upper bound
})

test_that("indicateur_c1_biomasse uses Generic model for unknown species", {
  data(massif_demo_units)

  units <- massif_demo_units[1:3, ]
  units$species <- c("Quercus", "UnknownSpecies", "Fagus")
  units$age <- c(80, 80, 80)
  units$density <- c(0.7, 0.7, 0.7)

  # Should not error, should use Generic for unknown
  expect_no_error(biomass <- indicateur_c1_biomasse(units))
  expect_length(biomass, 3)
  expect_true(all(!is.na(biomass)))
})

test_that("indicateur_c1_biomasse returns NA when required columns missing", {
  data(massif_demo_units)

  units <- massif_demo_units[1:3, ]

  # Missing species - function falls back to NA (no NDVI available either)
  units_no_species <- units
  units_no_species$species <- NULL
  units_no_species$age <- c(80, 60, 40)
  units_no_species$density <- c(0.7, 0.8, 0.6)
  result <- indicateur_c1_biomasse(units_no_species)
  expect_true(all(is.na(result)))

  # Missing age
  units_no_age <- units
  units_no_age$age <- NULL
  units_no_age$species <- c("Quercus", "Fagus", "Pinus")
  units_no_age$density <- c(0.7, 0.8, 0.6)
  result <- indicateur_c1_biomasse(units_no_age)
  expect_true(all(is.na(result)))

  # Missing density
  units_no_density <- units
  units_no_density$density <- NULL
  units_no_density$species <- c("Quercus", "Fagus", "Pinus")
  units_no_density$age <- c(80, 60, 40)
  result <- indicateur_c1_biomasse(units_no_density)
  expect_true(all(is.na(result)))
})

test_that("indicateur_c1_biomasse handles NA values appropriately", {
  data(massif_demo_units)

  units <- massif_demo_units[1:4, ]
  units$species <- c("Quercus", NA, "Fagus", "Pinus")
  units$age <- c(80, 60, NA, 40)
  units$density <- c(0.7, 0.8, 0.6, NA)

  biomass <- indicateur_c1_biomasse(units)

  # NA inputs should produce NA outputs
  expect_true(is.na(biomass[2])) # NA species
  expect_true(is.na(biomass[3])) # NA age
  expect_true(is.na(biomass[4])) # NA density

  # Valid input should produce valid output
  expect_false(is.na(biomass[1]))
})

test_that("indicateur_c1_biomasse respects custom column names", {
  data(massif_demo_units)

  units <- massif_demo_units[1:3, ]
  units$tree_species <- c("Quercus", "Fagus", "Pinus")
  units$stand_age <- c(80, 60, 40)
  units$stand_density <- c(0.7, 0.8, 0.6)

  biomass <- indicateur_c1_biomasse(
    units,
    species_col = "tree_species",
    age_col = "stand_age",
    density_col = "stand_density"
  )

  expect_length(biomass, 3)
  expect_true(all(!is.na(biomass)))
})

test_that("indicateur_c1_biomasse produces consistent results", {
  data(massif_demo_units)

  units <- massif_demo_units[1:2, ]
  units$species <- c("Quercus", "Quercus")
  units$age <- c(80, 80) # Same age
  units$density <- c(0.7, 0.7) # Same density

  biomass <- indicateur_c1_biomasse(units)

  # Same inputs should produce same outputs
  expect_equal(biomass[1], biomass[2])
})

test_that("indicateur_c1_biomasse scales with age and density", {
  data(massif_demo_units)

  # Test age scaling
  units_age <- massif_demo_units[1:3, ]
  units_age$species <- c("Quercus", "Quercus", "Quercus")
  units_age$age <- c(40, 80, 120) # Increasing age
  units_age$density <- c(0.7, 0.7, 0.7)

  biomass_age <- indicateur_c1_biomasse(units_age)
  expect_true(biomass_age[1] < biomass_age[2]) # More age = more biomass
  expect_true(biomass_age[2] < biomass_age[3])

  # Test density scaling
  units_density <- massif_demo_units[1:3, ]
  units_density$species <- c("Fagus", "Fagus", "Fagus")
  units_density$age <- c(60, 60, 60)
  units_density$density <- c(0.4, 0.7, 1.0) # Increasing density

  biomass_density <- indicateur_c1_biomasse(units_density)
  expect_true(biomass_density[1] < biomass_density[2]) # More density = more biomass
  expect_true(biomass_density[2] < biomass_density[3])
})

# ==============================================================================
# C2: NDVI VITALITY INDEX
# ==============================================================================

test_that("indicateur_c2_ndvi extracts mean NDVI from raster", {
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

  ndvi <- indicateur_c2_ndvi(units, layers, ndvi_layer = "ndvi")

  # Test output
  expect_type(ndvi, "double")
  expect_length(ndvi, 5)
  expect_true(all(!is.na(ndvi)))

  # NDVI should be in valid range [0, 1]
  expect_true(all(ndvi >= 0))
  expect_true(all(ndvi <= 1))
})

test_that("indicateur_c2_ndvi errors when NDVI layer missing", {
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  expect_error(
    indicateur_c2_ndvi(units, layers, ndvi_layer = "nonexistent"),
    "NDVI layer.*not found"
  )
})

test_that("indicateur_c2_ndvi handles edge NDVI values", {
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

  ndvi <- indicateur_c2_ndvi(units, layers, ndvi_layer = "ndvi")

  expect_length(ndvi, 3)
  expect_true(all(ndvi >= 0 & ndvi <= 1))
})

test_that("indicateur_c2_ndvi with trend option (future implementation)", {
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
    ndvi <- indicateur_c2_ndvi(units, layers, ndvi_layer = "ndvi", trend = TRUE),
    "trend.*not.*implemented|single.*date"
  )
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
    c1 <- indicateur_c1_biomasse(units)
    c2 <- indicateur_c2_ndvi(units, layers, ndvi_layer = "ndvi")
  })
})
