test_that("nemeton_units creates valid object from sf", {
  # Create test data
  test_sf <- create_test_units(n_features = 3)

  # Create nemeton_units
  units <- nemeton_units(test_sf)

  # Test class
  expect_s3_class(units, "nemeton_units")
  expect_s3_class(units, "sf")

  # Test that nemeton_id was created
  expect_true("nemeton_id" %in% names(units))
  expect_equal(nrow(units), 3)

  # Test that IDs are unique
  expect_equal(length(unique(units$nemeton_id)), 3)

  # Test metadata
  meta <- attr(units, "metadata")
  expect_type(meta, "list")
  expect_true("crs" %in% names(meta))
  expect_true("n_units" %in% names(meta))
  expect_true("area_total" %in% names(meta))
  expect_true("created_at" %in% names(meta))
  expect_equal(meta$n_units, 3)
})

test_that("nemeton_units creates object from file path", {
  # Get cadastral test file
  cadastral_path <- get_cadastral_test_file()

  # Create nemeton_units from file
  units <- nemeton_units(cadastral_path)

  # Test
  expect_s3_class(units, "nemeton_units")
  expect_s3_class(units, "sf")
  expect_true("nemeton_id" %in% names(units))
  expect_equal(nrow(units), 1)
})

test_that("nemeton_units handles custom ID column", {
  # Create test data
  test_sf <- create_test_units(n_features = 3)
  test_sf$custom_id <- c("A001", "A002", "A003")

  # Create with custom ID
  units <- nemeton_units(test_sf, id_col = "custom_id")

  # Test that custom IDs were used
  expect_equal(units$nemeton_id, c("A001", "A002", "A003"))
})

test_that("nemeton_units handles metadata", {
  test_sf <- create_test_units(n_features = 2)

  # Create with metadata
  units <- nemeton_units(
    test_sf,
    metadata = list(
      site_name = "Test Forest",
      year = 2024,
      source = "Test data"
    )
  )

  # Check metadata
  meta <- attr(units, "metadata")
  expect_equal(meta$site_name, "Test Forest")
  expect_equal(meta$year, 2024)
  expect_equal(meta$source, "Test data")
})

test_that("nemeton_units rejects invalid inputs", {
  # Non-existent file
  expect_error(
    nemeton_units("non_existent_file.gpkg"),
    "File not found"
  )

  # Non-sf object
  expect_error(
    nemeton_units(data.frame(x = 1:3, y = 1:3)),
    "must be an.*sf.*object" # Should fail validation
  )

  # Missing ID column
  test_sf <- create_test_units(n_features = 2)
  expect_error(
    nemeton_units(test_sf, id_col = "missing_column"),
    "not found in data"
  )
})

test_that("nemeton_units detects duplicate IDs", {
  test_sf <- create_test_units(n_features = 3)
  test_sf$dup_id <- c("ID1", "ID1", "ID2") # Duplicates!

  expect_error(
    nemeton_units(test_sf, id_col = "dup_id"),
    "must be unique"
  )
})

test_that("nemeton_layers creates valid catalog", {
  # Create temp test files
  temp_files <- create_temp_test_files()

  # Create layers catalog
  layers <- nemeton_layers(
    rasters = list(
      biomass = temp_files$biomass,
      dem = temp_files$dem
    ),
    vectors = list(
      roads = temp_files$roads
    )
  )

  # Test class
  expect_s3_class(layers, "nemeton_layers")

  # Test structure
  expect_type(layers$rasters, "list")
  expect_type(layers$vectors, "list")
  expect_equal(length(layers$rasters), 2)
  expect_equal(length(layers$vectors), 1)

  # Test that layers are not loaded yet (lazy loading)
  expect_false(layers$rasters$biomass$loaded)
  expect_false(layers$rasters$dem$loaded)
  expect_false(layers$vectors$roads$loaded)

  # Test metadata
  expect_equal(layers$metadata$n_rasters, 2)
  expect_equal(layers$metadata$n_vectors, 1)
})

test_that("nemeton_layers validates file existence", {
  expect_error(
    nemeton_layers(
      rasters = list(fake = "/non/existent/file.tif")
    ),
    "file not found"
  )
})

test_that("nemeton_layers requires named lists", {
  temp_files <- create_temp_test_files()

  # Unnamed list should fail
  expect_error(
    nemeton_layers(
      rasters = list(temp_files$biomass) # No name!
    ),
    "must be a named list"
  )
})

test_that("nemeton_layers requires at least one layer type", {
  expect_error(
    nemeton_layers(),
    "At least one"
  )
})

test_that("nemeton_layers can skip validation", {
  # Should not error even with non-existent files
  layers <- nemeton_layers(
    rasters = list(fake = "/fake/path.tif"),
    validate = FALSE
  )

  expect_s3_class(layers, "nemeton_layers")
})

test_that("print methods work for nemeton classes", {
  # Test units print
  test_sf <- create_test_units(n_features = 2)
  units <- nemeton_units(
    test_sf,
    metadata = list(site_name = "Test Site", year = 2024)
  )

  expect_output(print(units), "nemeton_units")
  expect_output(print(units), "Test Site")

  # Test layers print
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(
    rasters = list(biomass = temp_files$biomass),
    vectors = list(roads = temp_files$roads)
  )

  expect_output(print(layers), "nemeton_layers")
  expect_output(print(layers), "Rasters")
  expect_output(print(layers), "Vectors")
})

test_that("summary methods work for nemeton classes", {
  test_sf <- create_test_units(n_features = 2)
  units <- nemeton_units(
    test_sf,
    metadata = list(site_name = "Test", year = 2024)
  )

  expect_output(summary(units), "Nemeton Units Summary")
  expect_output(summary(units), "Test")

  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(
    rasters = list(biomass = temp_files$biomass)
  )

  expect_output(summary(layers), "Nemeton Layers Summary")
})
