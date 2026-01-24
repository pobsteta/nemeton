test_that("Real cadastral parcel can be loaded as nemeton_units", {
  cadastral_path <- get_cadastral_test_file()

  # Load as nemeton_units
  units <- nemeton_units(cadastral_path)

  expect_s3_class(units, "nemeton_units")
  expect_s3_class(units, "sf")
  expect_equal(nrow(units), 1)

  # Check CRS (should be Lambert 93)
  expect_equal(sf::st_crs(units)$epsg, 2154)

  # Check metadata
  meta <- attr(units, "metadata")
  expect_equal(meta$n_units, 1)
  expect_s3_class(meta$crs, "crs")
})

test_that("Real cadastral parcel has valid geometry", {
  cadastral_path <- get_cadastral_test_file()
  units <- nemeton_units(cadastral_path)

  # Geometry should be valid
  expect_true(all(sf::st_is_valid(units)))

  # Should not be empty
  expect_false(any(sf::st_is_empty(units)))

  # Should be POLYGON or MULTIPOLYGON
  geom_type <- unique(sf::st_geometry_type(units))
  expect_true(geom_type %in% c("POLYGON", "MULTIPOLYGON"))

  # Should have positive area
  area <- sf::st_area(units)
  expect_true(all(area > units::set_units(0, "m^2")))
})

test_that("Real cadastral parcel can use custom ID column", {
  cadastral_path <- get_cadastral_test_file()

  # Use geo_parcelle as ID
  units <- nemeton_units(cadastral_path, id_col = "geo_parcelle")

  expect_true("nemeton_id" %in% names(units))

  # ID should come from geo_parcelle
  # Read original to compare
  original <- sf::st_read(cadastral_path, quiet = TRUE)
  expect_equal(units$nemeton_id, as.character(original$geo_parcelle))
})

test_that("Real cadastral parcel preserves original attributes", {
  cadastral_path <- get_cadastral_test_file()
  units <- nemeton_units(cadastral_path)

  # Should have original cadastral attributes
  expected_attrs <- c("geo_parcelle", "nomcommune", "codecommune", "surface_geo")

  for (attr in expected_attrs) {
    expect_true(attr %in% names(units), info = paste("Missing attribute:", attr))
  }
})

test_that("Full workflow with real parcel and synthetic layers", {
  # Load real cadastral parcel
  cadastral_path <- get_cadastral_test_file()
  units <- nemeton_units(
    cadastral_path,
    metadata = list(
      site_name = "Test Cadastral Parcel",
      year = 2024,
      source = "IGN Cadastre"
    )
  )

  # Add required attributes for indicator computation
  # (carbon_biomass needs species, age, density)
  units$species <- "Quercus"
  units$age <- 80
  units$density <- 0.7

  # Create synthetic test layers matching the parcel extent
  bbox <- sf::st_bbox(units)
  extent <- c(bbox["xmin"], bbox["xmax"], bbox["ymin"], bbox["ymax"])

  temp_files <- create_temp_test_files()

  # Create layers
  layers <- nemeton_layers(
    rasters = list(
      biomass = temp_files$biomass,
      dem = temp_files$dem,
      landcover = temp_files$landcover
    ),
    vectors = list(
      roads = temp_files$roads,
      water = temp_files$water
    )
  )

  # Compute indicators with preprocessing
  # Note: forest_values causes issues with carbon_biomass, so we only use it for landscape_fragmentation
  result <- nemeton_compute(
    units, layers,
    indicators = c("carbon_biomass", "landscape_fragmentation"),
    preprocess = TRUE
  )

  # Verify results
  expect_s3_class(result, "sf")
  expect_equal(nrow(result), 1)

  # Check that indicator columns were added
  expect_true("carbon_biomass" %in% names(result))
  expect_true("landscape_fragmentation" %in% names(result))

  # Check metadata
  meta <- attr(result, "metadata")
  expect_true("computed_at" %in% names(meta))
  expect_true("indicators_computed" %in% names(meta))
  expect_equal(meta$site_name, "Test Cadastral Parcel")

  # Indicator values should be present
  expect_false(is.na(result$carbon_biomass))
  expect_false(is.na(result$landscape_fragmentation))
})

test_that("Real parcel with subset of indicators", {
  skip_if_not_installed("here")

  cadastral_path <- get_cadastral_test_file()
  units <- nemeton_units(cadastral_path)

  # Add required attributes for indicator computation
  units$species <- "Quercus"
  units$age <- 80
  units$density <- 0.7

  temp_files <- create_temp_test_files()

  # Create layer catalog
  layers <- nemeton_layers(
    rasters = list(
      biomass = temp_files$biomass,
      dem = temp_files$dem,
      landcover = temp_files$landcover
    ),
    vectors = list(
      roads = temp_files$roads,
      water = temp_files$water
    )
  )

  # Compute specific indicators that work with our test data
  # Note: indicators="all" + forest_values causes issues with some indicators
  result <- nemeton_compute(
    units, layers,
    indicators = c("carbon_biomass", "landscape_fragmentation"),
    preprocess = TRUE
  )

  # Should have the requested indicator columns
  expect_true("carbon_biomass" %in% names(result))
  expect_true("landscape_fragmentation" %in% names(result))

  # Check that carbon_biomass (computed from attributes) is valid
  expect_true(result$carbon_biomass >= 0)
  # Check landscape_fragmentation (computed from landcover) is valid
  expect_true(result$landscape_fragmentation >= 0 && result$landscape_fragmentation <= 100)
})

test_that("Real parcel survives CRS harmonization", {
  cadastral_path <- get_cadastral_test_file()
  units <- nemeton_units(cadastral_path)

  # Create layers with different CRS (WGS84)
  temp_dir <- tempdir()

  # Get extent of parcel in WGS84 for creating overlapping raster
  units_wgs84 <- sf::st_transform(units, 4326)
  bbox <- sf::st_bbox(units_wgs84)

  # Create raster in WGS84 covering the parcel with buffer
  r_wgs84 <- terra::rast(
    extent = terra::ext(bbox[1] - 0.01, bbox[3] + 0.01, bbox[2] - 0.01, bbox[4] + 0.01),
    resolution = 0.001,
    crs = "EPSG:4326"
  )
  terra::values(r_wgs84) <- runif(terra::ncell(r_wgs84), 0, 100)
  biomass_wgs84 <- file.path(temp_dir, "biomass_wgs84.tif")
  terra::writeRaster(r_wgs84, biomass_wgs84, overwrite = TRUE)

  layers <- nemeton_layers(
    rasters = list(biomass = biomass_wgs84)
  )

  # Compute with preprocessing (should harmonize CRS)
  result <- nemeton_compute(
    units, layers,
    indicators = "carbon_biomass",
    preprocess = TRUE
  )

  expect_s3_class(result, "sf")
  expect_true("carbon_biomass" %in% names(result))
})

test_that("Real parcel metadata is preserved through computation", {
  cadastral_path <- get_cadastral_test_file()

  units <- nemeton_units(
    cadastral_path,
    id_col = "geo_parcelle",
    metadata = list(
      site_name = "Parcelle 360053000AS0090",
      year = 2024,
      source = "IGN BD Parcellaire",
      description = "Test cadastral parcel for nemeton package"
    )
  )

  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  result <- nemeton_compute(units, layers, indicators = "carbon_biomass", preprocess = FALSE)

  # Original metadata should be preserved
  meta <- attr(result, "metadata")
  expect_equal(meta$site_name, "Parcelle 360053000AS0090")
  expect_equal(meta$year, 2024)
  expect_equal(meta$source, "IGN BD Parcellaire")
  expect_equal(meta$description, "Test cadastral parcel for nemeton package")

  # New metadata should be added
  expect_true("computed_at" %in% names(meta))
  expect_true("indicators_computed" %in% names(meta))
})

test_that("Real parcel prints and summarizes correctly", {
  cadastral_path <- get_cadastral_test_file()

  units <- nemeton_units(
    cadastral_path,
    metadata = list(site_name = "Test Parcel", year = 2024)
  )

  # Print should work
  expect_output(print(units), "nemeton_units")
  expect_output(print(units), "Test Parcel")
  expect_output(print(units), "2024")

  # Summary should work
  expect_output(summary(units), "Nemeton Units Summary")
  expect_output(summary(units), "Test Parcel")
})

test_that("Real parcel area calculation is sensible", {
  cadastral_path <- get_cadastral_test_file()
  units <- nemeton_units(cadastral_path)

  # Calculate area
  area_m2 <- as.numeric(sf::st_area(units))

  # Should be positive
  expect_true(area_m2 > 0)

  # Cadastral parcel should be reasonable size (e.g., between 100m² and 1000000m²)
  # This is a sanity check
  expect_true(area_m2 >= 100)
  expect_true(area_m2 <= 1e6) # 1 km²

  # Check if surface_geo attribute matches (if present)
  if ("surface_geo" %in% names(units)) {
    # Should be within 10% (accounting for projection differences)
    expect_true(abs(area_m2 - units$surface_geo) / units$surface_geo < 0.1)
  }
})
