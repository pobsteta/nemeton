# Tests for Carbon/Vitality family indicators (US2 - Phase 4)

# ==============================================================================
# C1: CARBON BIOMASS VIA ALLOMETRIC MODELS
# ==============================================================================

test_that("indicateur_c1_biomasse calculates biomass with BD Forêt attributes", {
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
  data(massif_demo_units)
  layers <- massif_demo_layers()

  units <- massif_demo_units[1:3, ]

  expect_error(
    indicateur_c2_ndvi(units, layers, ndvi_layer = "nonexistent"),
    "NDVI layer.*not found"
  )
})

test_that("indicateur_c2_ndvi handles edge NDVI values", {
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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


# ============================================================
# C1 — CHM mode (spec 005 T4.1-T4.4)
# ============================================================

test_that("C1 CHM mode returns positive biomass for 3 species", {
  skip_if_not_installed("terra")
  chm <- terra::rast(nrows = 30, ncols = 30,
                     xmin = 0, xmax = 300, ymin = 0, ymax = 300,
                     crs = "EPSG:2154",
                     vals = rep(25, 900))
  polys <- lapply(1:3, function(i) {
    ox <- (i - 1) * 100 + 10
    sf::st_polygon(list(rbind(
      c(ox, 10), c(ox + 80, 10),
      c(ox + 80, 90), c(ox, 90), c(ox, 10)
    )))
  })
  units <- sf::st_sf(
    species  = c("QUPE", "FASY", "PIAB"),
    dbh      = c(40, 35, 30),
    stems_ha = c(180, 200, 300),
    geometry = sf::st_sfc(polys, crs = 2154)
  )
  c1 <- indicateur_c1_biomasse(units, chm = chm)
  expect_length(c1, 3)
  expect_true(all(!is.na(c1)))
  expect_true(all(c1 > 0))
})

test_that("C1 CHM mode propagates NA on missing inputs", {
  skip_if_not_installed("terra")
  chm <- terra::rast(nrows = 20, ncols = 20,
                     xmin = 0, xmax = 200, ymin = 0, ymax = 200,
                     crs = "EPSG:2154",
                     vals = rep(20, 400))
  polys <- list(
    sf::st_polygon(list(rbind(c(10,10), c(90,10), c(90,90), c(10,90), c(10,10)))),
    sf::st_polygon(list(rbind(c(110,110), c(190,110), c(190,190), c(110,190), c(110,110))))
  )
  units <- sf::st_sf(
    species  = c("QUPE", "QUPE"),
    dbh      = c(35, NA),
    stems_ha = c(200, 200),
    geometry = sf::st_sfc(polys, crs = 2154)
  )
  c1 <- indicateur_c1_biomasse(units, chm = chm)
  expect_false(is.na(c1[1]))
  expect_true(is.na(c1[2]))
})

test_that("C1 CHM mode and age-based mode are positively correlated", {
  skip_if_not_installed("terra")
  set.seed(3)
  n  <- 8
  dbh_vals <- c(20, 30, 25, 40, 50, 35, 45, 55)
  h_vals   <- c(15, 22, 18, 28, 32, 26, 30, 34)
  ages     <- c(40, 80, 50, 100, 120, 70, 90, 140)
  sp       <- c("QUPE", "FASY", "QUPE", "FASY", "PIAB", "PIAB", "PSME", "PSME")

  rlist <- lapply(seq_along(sp), function(i) {
    terra::rast(nrows = 10, ncols = 10,
                xmin = (i - 1) * 100, xmax = i * 100,
                ymin = 0, ymax = 100,
                crs = "EPSG:2154",
                vals = rep(h_vals[i], 100))
  })
  chm <- do.call(terra::merge, rlist)

  polys <- lapply(seq_along(sp), function(i) {
    ox <- (i - 1) * 100 + 10
    sf::st_polygon(list(rbind(
      c(ox, 10), c(ox + 80, 10),
      c(ox + 80, 90), c(ox, 90), c(ox, 10)
    )))
  })
  units <- sf::st_sf(
    species  = sp,
    age      = ages,
    density  = rep(0.7, n),
    dbh      = dbh_vals,
    stems_ha = rep(200, n),
    geometry = sf::st_sfc(polys, crs = 2154)
  )
  # genus-level species label for the age path
  units_age <- units
  units_age$species <- ifelse(units$species %in% c("QUPE", "FASY"),
                              "Quercus", "Pinus")

  c1_age <- indicateur_c1_biomasse(units_age)
  c1_chm <- indicateur_c1_biomasse(units, chm = chm)

  ok <- !is.na(c1_age) & !is.na(c1_chm)
  rho <- suppressWarnings(
    stats::cor(c1_age[ok], c1_chm[ok], method = "spearman")
  )
  expect_true(rho >= 0.5)
})

test_that("C1 CHM mode respects the bef argument", {
  skip_if_not_installed("terra")
  chm <- terra::rast(nrows = 20, ncols = 20,
                     xmin = 0, xmax = 200, ymin = 0, ymax = 200,
                     crs = "EPSG:2154",
                     vals = rep(25, 400))
  poly <- sf::st_polygon(list(rbind(c(10,10), c(190,10), c(190,190), c(10,190), c(10,10))))
  units <- sf::st_sf(
    species  = "QUPE",
    dbh      = 35,
    stems_ha = 200,
    geometry = sf::st_sfc(poly, crs = 2154)
  )
  c_low  <- indicateur_c1_biomasse(units, chm = chm, bef = 1.0)
  c_high <- indicateur_c1_biomasse(units, chm = chm, bef = 1.5)
  expect_equal(c_high, c_low * 1.5, tolerance = 1e-6)
})

test_that("C1 CHM mode requires dbh_col and species_col", {
  skip_if_not_installed("terra")
  chm <- terra::rast(nrows = 20, ncols = 20,
                     xmin = 0, xmax = 200, ymin = 0, ymax = 200,
                     crs = "EPSG:2154",
                     vals = rep(25, 400))
  poly <- sf::st_polygon(list(rbind(c(10,10), c(190,10), c(190,190), c(10,190), c(10,10))))
  # Missing dbh -> falls through to next paths, returns NA since no inventory
  units <- sf::st_sf(
    species  = "QUPE",
    stems_ha = 200,
    geometry = sf::st_sfc(poly, crs = 2154)
  )
  # CHM mode skipped because dbh_col is missing; falls through
  # to legacy paths. With no inventory data, returns NA.
  c1 <- suppressMessages(indicateur_c1_biomasse(units, chm = chm))
  expect_true(is.na(c1))
})

