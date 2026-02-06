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

# ==============================================================================
# Additional coverage tests for uncovered lines
# ==============================================================================

# --- nemeton_units: from file path ---

test_that("nemeton_units loads from file path (gpkg)", {
  withr::with_tempdir({
    test_sf <- create_test_units(n_features = 3)
    path <- file.path(getwd(), "test_units.gpkg")
    sf::st_write(test_sf, path, quiet = TRUE)

    units <- nemeton_units(path)

    expect_s3_class(units, "nemeton_units")
    expect_s3_class(units, "sf")
    expect_equal(nrow(units), 3)
    expect_true("nemeton_id" %in% names(units))
  })
})

# --- nemeton_units: with id_col parameter ---

test_that("nemeton_units uses id_col to set nemeton_id", {
  test_sf <- create_test_units(n_features = 3)

  # The helper creates an "id" column: unit_001, unit_002, unit_003
  units <- nemeton_units(test_sf, id_col = "id")

  expect_equal(units$nemeton_id, c("unit_001", "unit_002", "unit_003"))
})

# --- nemeton_units: duplicate IDs error ---

test_that("nemeton_units errors on duplicate IDs", {
  test_sf <- create_test_units(n_features = 3)
  test_sf$dup_col <- c("A", "A", "B")

  expect_error(
    nemeton_units(test_sf, id_col = "dup_col"),
    "must be unique"
  )
})

# --- nemeton_units: non-existent id_col error ---

test_that("nemeton_units errors on non-existent id_col", {
  test_sf <- create_test_units(n_features = 2)

  expect_error(
    nemeton_units(test_sf, id_col = "nonexistent_col"),
    "not found in data"
  )
})

# --- print.nemeton_units: output with site_name, year, area ---

test_that("print.nemeton_units outputs site_name, year, units count, area, CRS", {
  test_sf <- create_test_units(n_features = 3)
  units <- nemeton_units(
    test_sf,
    metadata = list(site_name = "Foret de Test", year = 2024)
  )

  output <- capture.output(print(units))

  expect_true(any(grepl("nemeton_units", output)))
  expect_true(any(grepl("Foret de Test", output)))
  expect_true(any(grepl("2024", output)))
  expect_true(any(grepl("Units:", output)))
  expect_true(any(grepl("ha", output)))  # area in ha
  expect_true(any(grepl("CRS:", output)))
})

test_that("print.nemeton_units without site_name omits Site line", {
  test_sf <- create_test_units(n_features = 2)
  units <- nemeton_units(test_sf, metadata = list())

  output <- capture.output(print(units))

  expect_true(any(grepl("nemeton_units", output)))
  expect_true(any(grepl("Units:", output)))
})

# --- summary.nemeton_units: full output with metadata ---

test_that("summary.nemeton_units outputs full metadata", {
  test_sf <- create_test_units(n_features = 4)
  units <- nemeton_units(
    test_sf,
    metadata = list(site_name = "Massif Central", year = 2023, source = "IGN BD Foret")
  )

  output <- capture.output(summary(units))

  expect_true(any(grepl("Nemeton Units Summary", output)))
  expect_true(any(grepl("Number of units:", output)))
  expect_true(any(grepl("Massif Central", output)))
  expect_true(any(grepl("2023", output)))
  expect_true(any(grepl("IGN BD Foret", output)))
  expect_true(any(grepl("Total area:", output)))
  expect_true(any(grepl("Mean area:", output)))
  expect_true(any(grepl("Attributes:", output)))
})

test_that("summary.nemeton_units handles missing metadata fields", {
  test_sf <- create_test_units(n_features = 2)
  units <- nemeton_units(test_sf, metadata = list())

  output <- capture.output(summary(units))

  expect_true(any(grepl("Not specified", output)))
})

# --- nemeton_layers: validate=FALSE with non-existent files ---

test_that("nemeton_layers works with validate=FALSE and non-existent files", {
  layers <- nemeton_layers(
    rasters = list(dem = "/nonexistent/path/dem.tif"),
    vectors = list(roads = "/nonexistent/path/roads.gpkg"),
    validate = FALSE
  )

  expect_s3_class(layers, "nemeton_layers")
  expect_equal(layers$metadata$n_rasters, 1)
  expect_equal(layers$metadata$n_vectors, 1)
  expect_false(layers$rasters$dem$loaded)
  expect_false(layers$vectors$roads$loaded)
})

# --- nemeton_layers: unnamed rasters error ---

test_that("nemeton_layers errors on unnamed rasters", {
  expect_error(
    nemeton_layers(rasters = list("/some/file.tif")),
    "must be a named list"
  )
})

# --- nemeton_layers: unnamed vectors error ---

test_that("nemeton_layers errors on unnamed vectors", {
  expect_error(
    nemeton_layers(vectors = list("/some/file.gpkg")),
    "must be a named list"
  )
})

# --- nemeton_layers: partially unnamed rasters error ---

test_that("nemeton_layers errors on partially unnamed rasters", {
  expect_error(
    nemeton_layers(rasters = list(dem = "/file1.tif", "/file2.tif")),
    "must be a named list"
  )
})

# --- print.nemeton_layers: output with loaded/not loaded status ---

test_that("print.nemeton_layers shows loaded and not loaded status", {
  layers <- nemeton_layers(
    rasters = list(dem = "/fake/dem.tif", ndvi = "/fake/ndvi.tif"),
    vectors = list(roads = "/fake/roads.gpkg"),
    validate = FALSE
  )

  output <- capture.output(print(layers))

  expect_true(any(grepl("nemeton_layers", output)))
  expect_true(any(grepl("Rasters", output)))
  expect_true(any(grepl("Vectors", output)))
  expect_true(any(grepl("not loaded", output)))
  expect_true(any(grepl("dem", output)))
  expect_true(any(grepl("ndvi", output)))
  expect_true(any(grepl("roads", output)))
})

test_that("print.nemeton_layers with no vectors shows (none)", {
  layers <- nemeton_layers(
    rasters = list(dem = "/fake/dem.tif"),
    validate = FALSE
  )

  output <- capture.output(print(layers))

  expect_true(any(grepl("none", output)))
})

test_that("print.nemeton_layers with no rasters shows (none)", {
  layers <- nemeton_layers(
    vectors = list(roads = "/fake/roads.gpkg"),
    validate = FALSE
  )

  output <- capture.output(print(layers))

  # The rasters section should show (none)
  expect_true(any(grepl("none", output)))
})

# --- summary.nemeton_layers: basic output ---

test_that("summary.nemeton_layers shows raster and vector counts", {
  layers <- nemeton_layers(
    rasters = list(dem = "/fake/dem.tif", ndvi = "/fake/ndvi.tif"),
    vectors = list(roads = "/fake/roads.gpkg"),
    validate = FALSE
  )

  output <- capture.output(summary(layers))

  expect_true(any(grepl("Nemeton Layers Summary", output)))
  expect_true(any(grepl("Rasters: 2", output)))
  expect_true(any(grepl("Vectors: 1", output)))
  expect_true(any(grepl("Created:", output)))
})

# --- nemeton_layers: with real temporary files ---

test_that("print.nemeton_layers with real files shows not loaded", {
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(biomass = temp_files$biomass, dem = temp_files$dem),
    vectors = list(roads = temp_files$roads)
  )

  output <- capture.output(print(layers))

  expect_true(any(grepl("nemeton_layers", output)))
  expect_true(any(grepl("not loaded", output)))
  expect_true(any(grepl("biomass", output)))
})

# --- nemeton_layers: validate=TRUE with existing files ---

test_that("nemeton_layers validates existing files successfully", {
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(biomass = temp_files$biomass),
    vectors = list(roads = temp_files$roads),
    validate = TRUE
  )

  expect_s3_class(layers, "nemeton_layers")
  expect_equal(layers$metadata$validated, TRUE)
})

# --- nemeton_layers: validate=TRUE with non-existent raster errors ---

test_that("nemeton_layers validate=TRUE errors on non-existent raster", {
  expect_error(
    nemeton_layers(
      rasters = list(fake = "/absolutely/nonexistent/file.tif"),
      validate = TRUE
    ),
    "file not found"
  )
})

# --- nemeton_layers: validate=TRUE with non-existent vector errors ---

test_that("nemeton_layers validate=TRUE errors on non-existent vector", {
  expect_error(
    nemeton_layers(
      vectors = list(fake = "/absolutely/nonexistent/file.gpkg"),
      validate = TRUE
    ),
    "file not found"
  )
})
