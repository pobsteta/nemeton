test_that("nemeton_units creates valid object from sf", {
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
  # Create test data
  test_sf <- create_test_units(n_features = 3)
  test_sf$custom_id <- c("A001", "A002", "A003")

  # Create with custom ID
  units <- nemeton_units(test_sf, id_col = "custom_id")

  # Test that custom IDs were used
  expect_equal(units$nemeton_id, c("A001", "A002", "A003"))
})

test_that("nemeton_units handles metadata", {
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 3)
  test_sf$dup_id <- c("ID1", "ID1", "ID2") # Duplicates!

  expect_error(
    nemeton_units(test_sf, id_col = "dup_id"),
    "must be unique"
  )
})

test_that("nemeton_layers creates valid catalog", {
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
  expect_error(
    nemeton_layers(
      rasters = list(fake = "/non/existent/file.tif")
    ),
    "file not found"
  )
})

test_that("nemeton_layers requires named lists", {
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
  expect_error(
    nemeton_layers(),
    "At least one"
  )
})

test_that("nemeton_layers can skip validation", {
  skip_if_not_installed("terra")
  # Should not error even with non-existent files
  layers <- nemeton_layers(
    rasters = list(fake = "/fake/path.tif"),
    validate = FALSE
  )

  expect_s3_class(layers, "nemeton_layers")
})

test_that("print methods work for nemeton classes", {
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 3)

  # The helper creates an "id" column: unit_001, unit_002, unit_003
  units <- nemeton_units(test_sf, id_col = "id")

  expect_equal(units$nemeton_id, c("unit_001", "unit_002", "unit_003"))
})

# --- nemeton_units: duplicate IDs error ---

test_that("nemeton_units errors on duplicate IDs", {
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 3)
  test_sf$dup_col <- c("A", "A", "B")

  expect_error(
    nemeton_units(test_sf, id_col = "dup_col"),
    "must be unique"
  )
})

# --- nemeton_units: non-existent id_col error ---

test_that("nemeton_units errors on non-existent id_col", {
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 2)

  expect_error(
    nemeton_units(test_sf, id_col = "nonexistent_col"),
    "not found in data"
  )
})

# --- print.nemeton_units: output with site_name, year, area ---

test_that("print.nemeton_units outputs site_name, year, units count, area, CRS", {
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 2)
  units <- nemeton_units(test_sf, metadata = list())

  output <- capture.output(print(units))

  expect_true(any(grepl("nemeton_units", output)))
  expect_true(any(grepl("Units:", output)))
})

# --- summary.nemeton_units: full output with metadata ---

test_that("summary.nemeton_units outputs full metadata", {
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 2)
  units <- nemeton_units(test_sf, metadata = list())

  output <- capture.output(summary(units))

  expect_true(any(grepl("Not specified", output)))
})

# --- nemeton_layers: validate=FALSE with non-existent files ---

test_that("nemeton_layers works with validate=FALSE and non-existent files", {
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
  expect_error(
    nemeton_layers(rasters = list("/some/file.tif")),
    "must be a named list"
  )
})

# --- nemeton_layers: unnamed vectors error ---

test_that("nemeton_layers errors on unnamed vectors", {
  skip_if_not_installed("terra")
  expect_error(
    nemeton_layers(vectors = list("/some/file.gpkg")),
    "must be a named list"
  )
})

# --- nemeton_layers: partially unnamed rasters error ---

test_that("nemeton_layers errors on partially unnamed rasters", {
  skip_if_not_installed("terra")
  expect_error(
    nemeton_layers(rasters = list(dem = "/file1.tif", "/file2.tif")),
    "must be a named list"
  )
})

# --- print.nemeton_layers: output with loaded/not loaded status ---

test_that("print.nemeton_layers shows loaded and not loaded status", {
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
  layers <- nemeton_layers(
    rasters = list(dem = "/fake/dem.tif"),
    validate = FALSE
  )

  output <- capture.output(print(layers))

  expect_true(any(grepl("none", output)))
})

test_that("print.nemeton_layers with no rasters shows (none)", {
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
  expect_error(
    nemeton_layers(
      vectors = list(fake = "/absolutely/nonexistent/file.gpkg"),
      validate = TRUE
    ),
    "file not found"
  )
})

# ==============================================================================
# New tests for additional branch coverage
# ==============================================================================

# --- nemeton_units: validate=FALSE skips sf validation ---

test_that("nemeton_units with validate=FALSE skips geometry validation", {
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 2)

  # validate=FALSE should still create valid object, just skip validation
  units <- nemeton_units(test_sf, validate = FALSE)

  expect_s3_class(units, "nemeton_units")
  expect_s3_class(units, "sf")
  expect_equal(nrow(units), 2)
  expect_true("nemeton_id" %in% names(units))
})

# --- nemeton_units: generated IDs have correct format ---

test_that("nemeton_units generates IDs with correct format when id_col is NULL", {
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 5)

  units <- nemeton_units(test_sf)

  # IDs should follow the "unit_001", "unit_002" format from generate_ids()
  expect_equal(units$nemeton_id, c("unit_001", "unit_002", "unit_003", "unit_004", "unit_005"))
})

# --- nemeton_units: metadata merges user and auto fields ---

test_that("nemeton_units merges user metadata with auto-generated metadata", {
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 2)

  units <- nemeton_units(
    test_sf,
    metadata = list(
      site_name = "My Forest",
      description = "A custom field"
    )
  )

  meta <- attr(units, "metadata")

  # User-supplied fields
  expect_equal(meta$site_name, "My Forest")
  expect_equal(meta$description, "A custom field")

  # Auto-generated fields
  expect_true(!is.null(meta$crs))
  expect_equal(meta$n_units, 2)
  expect_true(!is.null(meta$area_total))
  expect_s3_class(meta$created_at, "POSIXct")
})

# --- nemeton_units: id_col coerces to character ---

test_that("nemeton_units coerces id_col values to character", {
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 3)
  test_sf$numeric_id <- c(10, 20, 30)

  units <- nemeton_units(test_sf, id_col = "numeric_id")

  expect_type(units$nemeton_id, "character")
  expect_equal(units$nemeton_id, c("10", "20", "30"))
})

# --- nemeton_units: single feature ---

test_that("nemeton_units works with a single feature", {
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 1)

  units <- nemeton_units(test_sf)

  expect_s3_class(units, "nemeton_units")
  expect_equal(nrow(units), 1)
  expect_equal(units$nemeton_id, "unit_001")
})

# --- nemeton_units: from file path with id_col ---

test_that("nemeton_units from file path uses id_col correctly", {
  skip_if_not_installed("terra")
  withr::with_tempdir({
    test_sf <- create_test_units(n_features = 2)
    test_sf$parcel_id <- c("P001", "P002")
    path <- file.path(getwd(), "parcels.gpkg")
    sf::st_write(test_sf, path, quiet = TRUE)

    units <- nemeton_units(path, id_col = "parcel_id")

    expect_s3_class(units, "nemeton_units")
    expect_equal(units$nemeton_id, c("P001", "P002"))
  })
})

# --- nemeton_units: from file with validate=FALSE ---

test_that("nemeton_units from file path with validate=FALSE", {
  skip_if_not_installed("terra")
  withr::with_tempdir({
    test_sf <- create_test_units(n_features = 2)
    path <- file.path(getwd(), "test.gpkg")
    sf::st_write(test_sf, path, quiet = TRUE)

    units <- nemeton_units(path, validate = FALSE)

    expect_s3_class(units, "nemeton_units")
    expect_equal(nrow(units), 2)
  })
})

# --- nemeton_units: class hierarchy is correct ---

test_that("nemeton_units class includes nemeton_units as first class", {
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 2)
  units <- nemeton_units(test_sf)

  classes <- class(units)
  expect_equal(classes[1], "nemeton_units")
  expect_true("sf" %in% classes)
  expect_true("data.frame" %in% classes)
})

# --- print.nemeton_units: returns invisible(x) ---

test_that("print.nemeton_units returns the object invisibly", {
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 2)
  units <- nemeton_units(test_sf, metadata = list(site_name = "Invisible Test"))

  result <- NULL
  capture.output(result <- withVisible(print(units)))

  expect_false(result$visible)
  expect_s3_class(result$value, "nemeton_units")
})

# --- print.nemeton_units: without year but with site_name ---

test_that("print.nemeton_units with site_name but without year", {
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 2)
  units <- nemeton_units(test_sf, metadata = list(site_name = "Pine Forest"))

  output <- capture.output(print(units))

  expect_true(any(grepl("Site: Pine Forest", output)))
  # Year line should not appear
  expect_false(any(grepl("Year:", output)))
})

# --- print.nemeton_units: with year but without site_name ---

test_that("print.nemeton_units with year but without site_name", {
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 2)
  units <- nemeton_units(test_sf, metadata = list(year = 2025))

  output <- capture.output(print(units))

  expect_true(any(grepl("Year: 2025", output)))
  # Site line should not appear
  expect_false(any(grepl("Site:", output)))
})

# --- print.nemeton_units: without area_total ---

test_that("print.nemeton_units without area_total metadata", {
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 2)
  units <- nemeton_units(test_sf)

  # Remove area_total from metadata to test the branch
  meta <- attr(units, "metadata")
  meta$area_total <- NULL
  attr(units, "metadata") <- meta

  output <- capture.output(print(units))

  expect_true(any(grepl("nemeton_units", output)))
  expect_true(any(grepl("Units:", output)))
  # "ha" should not appear since area_total is NULL
  expect_false(any(grepl("Total area:", output)))
})

# --- print.nemeton_units: without CRS metadata ---

test_that("print.nemeton_units without crs metadata", {
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 2)
  units <- nemeton_units(test_sf)

  # Remove CRS from metadata to test the branch
  meta <- attr(units, "metadata")
  meta$crs <- NULL
  attr(units, "metadata") <- meta

  output <- capture.output(print(units))

  expect_true(any(grepl("nemeton_units", output)))
  expect_false(any(grepl("CRS:", output)))
})

# --- print.nemeton_units: with NULL metadata attribute ---

test_that("print.nemeton_units with NULL metadata attribute", {
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 2)
  units <- nemeton_units(test_sf)

  # Set metadata to NULL entirely
  attr(units, "metadata") <- NULL

  output <- capture.output(print(units))

  # Should still print the header and units count
  expect_true(any(grepl("nemeton_units", output)))
  expect_true(any(grepl("Units:", output)))
})

# --- summary.nemeton_units: returns invisible(object) ---

test_that("summary.nemeton_units returns the object invisibly", {
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 2)
  units <- nemeton_units(test_sf)

  result <- NULL
  capture.output(result <- withVisible(summary(units)))

  expect_false(result$visible)
  expect_s3_class(result$value, "nemeton_units")
})

# --- summary.nemeton_units: with no CRS ---

test_that("summary.nemeton_units shows Unknown when CRS is NULL", {
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 2)
  units <- nemeton_units(test_sf)

  meta <- attr(units, "metadata")
  meta$crs <- NULL
  attr(units, "metadata") <- meta

  output <- capture.output(summary(units))

  expect_true(any(grepl("Unknown", output)))
})

# --- summary.nemeton_units: without area_total ---

test_that("summary.nemeton_units without area_total omits area lines", {
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 2)
  units <- nemeton_units(test_sf)

  meta <- attr(units, "metadata")
  meta$area_total <- NULL
  attr(units, "metadata") <- meta

  output <- capture.output(summary(units))

  expect_true(any(grepl("Nemeton Units Summary", output)))
  expect_false(any(grepl("Total area:", output)))
  expect_false(any(grepl("Mean area:", output)))
})

# --- summary.nemeton_units: with NULL metadata ---

test_that("summary.nemeton_units with NULL metadata", {
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 2)
  units <- nemeton_units(test_sf)

  attr(units, "metadata") <- NULL

  output <- capture.output(summary(units))

  # Should show "Not specified" or "Unknown" for missing fields
  expect_true(any(grepl("Nemeton Units Summary", output)))
  expect_true(any(grepl("Unknown", output)))
  expect_true(any(grepl("Not specified", output)))
})

# --- print.nemeton_layers: with loaded=TRUE status ---

test_that("print.nemeton_layers shows [loaded] for loaded layers", {
  skip_if_not_installed("terra")
  layers <- nemeton_layers(
    rasters = list(dem = "/fake/dem.tif"),
    vectors = list(roads = "/fake/roads.gpkg"),
    validate = FALSE
  )

  # Manually set loaded = TRUE to test the branch
  layers$rasters$dem$loaded <- TRUE
  layers$vectors$roads$loaded <- TRUE

  output <- capture.output(print(layers))

  # Should show "[loaded]" for both
  loaded_lines <- output[grepl("\\[loaded\\]", output)]
  expect_true(length(loaded_lines) >= 2)
  # Should NOT show "not loaded" for these layers
  not_loaded_lines <- output[grepl("not loaded", output)]
  expect_equal(length(not_loaded_lines), 0)
})

# --- print.nemeton_layers: mix of loaded and not loaded ---

test_that("print.nemeton_layers shows mixed loaded/not loaded status", {
  skip_if_not_installed("terra")
  layers <- nemeton_layers(
    rasters = list(dem = "/fake/dem.tif", ndvi = "/fake/ndvi.tif"),
    validate = FALSE
  )

  # Set one loaded, one not
  layers$rasters$dem$loaded <- TRUE
  layers$rasters$ndvi$loaded <- FALSE

  output <- capture.output(print(layers))

  # dem line should show [loaded]
  dem_line <- output[grepl("dem", output)]
  expect_true(any(grepl("\\[loaded\\]", dem_line)))

  # ndvi line should show [not loaded]
  ndvi_line <- output[grepl("ndvi", output)]
  expect_true(any(grepl("not loaded", ndvi_line)))
})

# --- print.nemeton_layers: returns invisible(x) ---

test_that("print.nemeton_layers returns the object invisibly", {
  skip_if_not_installed("terra")
  layers <- nemeton_layers(
    rasters = list(dem = "/fake/dem.tif"),
    validate = FALSE
  )

  result <- NULL
  capture.output(result <- withVisible(print(layers)))

  expect_false(result$visible)
  expect_s3_class(result$value, "nemeton_layers")
})

# --- summary.nemeton_layers: returns invisible(object) ---

test_that("summary.nemeton_layers returns the object invisibly", {
  skip_if_not_installed("terra")
  layers <- nemeton_layers(
    rasters = list(dem = "/fake/dem.tif"),
    validate = FALSE
  )

  result <- NULL
  capture.output(result <- withVisible(summary(layers)))

  expect_false(result$visible)
  expect_s3_class(result$value, "nemeton_layers")
})

# --- nemeton_layers: rasters only (no vectors) ---

test_that("nemeton_layers with rasters only stores correct metadata", {
  skip_if_not_installed("terra")
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(biomass = temp_files$biomass, dem = temp_files$dem)
  )

  expect_s3_class(layers, "nemeton_layers")
  expect_equal(layers$metadata$n_rasters, 2)
  expect_equal(layers$metadata$n_vectors, 0)
  expect_equal(length(layers$vectors), 0)
})

# --- nemeton_layers: vectors only (no rasters) ---

test_that("nemeton_layers with vectors only stores correct metadata", {
  skip_if_not_installed("terra")
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    vectors = list(roads = temp_files$roads, water = temp_files$water)
  )

  expect_s3_class(layers, "nemeton_layers")
  expect_equal(layers$metadata$n_vectors, 2)
  expect_equal(layers$metadata$n_rasters, 0)
  expect_equal(length(layers$rasters), 0)
})

# --- nemeton_layers: paths are normalized ---

test_that("nemeton_layers normalizes file paths", {
  skip_if_not_installed("terra")
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(biomass = temp_files$biomass)
  )

  stored_path <- layers$rasters$biomass$path
  # Path should be normalized (absolute)
  expect_true(nchar(stored_path) > 0)
  # normalizePath should not change it further since it's already normalized
  expect_equal(stored_path, normalizePath(temp_files$biomass, mustWork = FALSE))
})

# --- nemeton_layers: object field is NULL (not loaded) ---

test_that("nemeton_layers stores NULL object for each layer initially", {
  skip_if_not_installed("terra")
  layers <- nemeton_layers(
    rasters = list(dem = "/fake/dem.tif"),
    vectors = list(roads = "/fake/roads.gpkg"),
    validate = FALSE
  )

  expect_null(layers$rasters$dem$object)
  expect_null(layers$vectors$roads$object)
  expect_type(layers$rasters$dem$metadata, "list")
  expect_type(layers$vectors$roads$metadata, "list")
})

# --- nemeton_layers: partially unnamed vectors error ---

test_that("nemeton_layers errors on partially unnamed vectors", {
  skip_if_not_installed("terra")
  expect_error(
    nemeton_layers(vectors = list(roads = "/file1.gpkg", "/file2.gpkg")),
    "must be a named list"
  )
})

# --- nemeton_layers: validate=TRUE checks each raster file ---

test_that("nemeton_layers validate=TRUE errors on second non-existent raster", {
  skip_if_not_installed("terra")
  temp_files <- create_temp_test_files()

  # First raster exists, second does not
  expect_error(
    nemeton_layers(
      rasters = list(
        real = temp_files$biomass,
        fake = "/absolutely/nonexistent/raster.tif"
      ),
      validate = TRUE
    ),
    "file not found"
  )
})

# --- nemeton_layers: validate=TRUE checks each vector file ---

test_that("nemeton_layers validate=TRUE errors on second non-existent vector", {
  skip_if_not_installed("terra")
  temp_files <- create_temp_test_files()

  # First vector exists, second does not
  expect_error(
    nemeton_layers(
      vectors = list(
        real = temp_files$roads,
        fake = "/absolutely/nonexistent/vector.gpkg"
      ),
      validate = TRUE
    ),
    "file not found"
  )
})

# --- summary.nemeton_layers: with zero rasters ---

test_that("summary.nemeton_layers shows zero rasters", {
  skip_if_not_installed("terra")
  layers <- nemeton_layers(
    vectors = list(roads = "/fake/roads.gpkg"),
    validate = FALSE
  )

  output <- capture.output(summary(layers))

  expect_true(any(grepl("Rasters: 0", output)))
  expect_true(any(grepl("Vectors: 1", output)))
})

# --- summary.nemeton_layers: with zero vectors ---

test_that("summary.nemeton_layers shows zero vectors", {
  skip_if_not_installed("terra")
  layers <- nemeton_layers(
    rasters = list(dem = "/fake/dem.tif"),
    validate = FALSE
  )

  output <- capture.output(summary(layers))

  expect_true(any(grepl("Rasters: 1", output)))
  expect_true(any(grepl("Vectors: 0", output)))
})

# --- nemeton_units: metadata created_at is a POSIXct timestamp ---

test_that("nemeton_units metadata created_at is a recent timestamp", {
  skip_if_not_installed("terra")
  before <- Sys.time()
  test_sf <- create_test_units(n_features = 2)
  units <- nemeton_units(test_sf)
  after <- Sys.time()

  meta <- attr(units, "metadata")

  expect_s3_class(meta$created_at, "POSIXct")
  expect_true(meta$created_at >= before)
  expect_true(meta$created_at <= after)
})

# --- nemeton_layers: created_at timestamp in metadata ---

test_that("nemeton_layers metadata created_at is a recent timestamp", {
  skip_if_not_installed("terra")
  before <- Sys.time()
  layers <- nemeton_layers(
    rasters = list(dem = "/fake/dem.tif"),
    validate = FALSE
  )
  after <- Sys.time()

  expect_s3_class(layers$metadata$created_at, "POSIXct")
  expect_true(layers$metadata$created_at >= before)
  expect_true(layers$metadata$created_at <= after)
})

# --- nemeton_units: area_total is a units object ---

test_that("nemeton_units metadata area_total is a units object", {
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 3)
  units <- nemeton_units(test_sf)

  meta <- attr(units, "metadata")

  # area_total should be a units object (from sf::st_area)
  expect_true(inherits(meta$area_total, "units"))
  expect_true(as.numeric(meta$area_total) > 0)
})

# --- nemeton_units: empty metadata list is valid ---

test_that("nemeton_units with empty metadata list adds auto fields only", {
  skip_if_not_installed("terra")
  test_sf <- create_test_units(n_features = 2)
  units <- nemeton_units(test_sf, metadata = list())

  meta <- attr(units, "metadata")

  # Should have auto-generated fields but no user fields
  expect_true(!is.null(meta$crs))
  expect_equal(meta$n_units, 2)
  expect_true(!is.null(meta$area_total))
  expect_true(!is.null(meta$created_at))
  expect_null(meta$site_name)
  expect_null(meta$year)
  expect_null(meta$source)
})

# --- nemeton_layers: many rasters and vectors ---

test_that("nemeton_layers handles multiple rasters and vectors", {
  skip_if_not_installed("terra")
  layers <- nemeton_layers(
    rasters = list(
      dem = "/fake/dem.tif",
      ndvi = "/fake/ndvi.tif",
      biomass = "/fake/biomass.tif"
    ),
    vectors = list(
      roads = "/fake/roads.gpkg",
      rivers = "/fake/rivers.gpkg"
    ),
    validate = FALSE
  )

  expect_equal(layers$metadata$n_rasters, 3)
  expect_equal(layers$metadata$n_vectors, 2)
  expect_equal(length(layers$rasters), 3)
  expect_equal(length(layers$vectors), 2)

  # Each layer should have the correct structure
  for (name in names(layers$rasters)) {
    expect_false(layers$rasters[[name]]$loaded)
    expect_null(layers$rasters[[name]]$object)
    expect_true(nchar(layers$rasters[[name]]$path) > 0)
  }
  for (name in names(layers$vectors)) {
    expect_false(layers$vectors[[name]]$loaded)
    expect_null(layers$vectors[[name]]$object)
    expect_true(nchar(layers$vectors[[name]]$path) > 0)
  }
})

# ==============================================================================
# (migrated from test-cov80-batch13.R)
# ==============================================================================

# --- nemeton_units() ---

test_that("nemeton_units() from sf object creates valid nemeton_units", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 5)

  nu <- nemeton::nemeton_units(units)

  expect_s3_class(nu, "nemeton_units")
  expect_s3_class(nu, "sf")
  expect_true("nemeton_id" %in% names(nu))
  expect_equal(nrow(nu), 5)
  expect_equal(length(unique(nu$nemeton_id)), 5)

  meta <- attr(nu, "metadata")
  expect_true("crs" %in% names(meta))
  expect_true("n_units" %in% names(meta))
  expect_true("area_total" %in% names(meta))
  expect_true("created_at" %in% names(meta))
  expect_equal(meta$n_units, 5)
})

test_that("nemeton_units() with id_col uses specified column", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 3)
  units$my_id <- c("alpha", "beta", "gamma")

  nu <- nemeton::nemeton_units(units, id_col = "my_id")

  expect_equal(nu$nemeton_id, c("alpha", "beta", "gamma"))
})

test_that("nemeton_units() with id_col=NULL auto-generates IDs", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 3)

  nu <- nemeton::nemeton_units(units)

  expect_true("nemeton_id" %in% names(nu))
  # Auto-generated IDs follow "unit_001", "unit_002" pattern
  expect_equal(nu$nemeton_id, c("unit_001", "unit_002", "unit_003"))
})

test_that("nemeton_units() errors on duplicate IDs", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 3)
  units$dup_id <- c("A", "A", "B")

  expect_error(
    nemeton::nemeton_units(units, id_col = "dup_id"),
    "unique"
  )
})

test_that("nemeton_units() errors on missing id_col", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 3)

  expect_error(
    nemeton::nemeton_units(units, id_col = "nonexistent"),
    "not found"
  )
})

test_that("nemeton_units() stores metadata correctly", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 3)

  nu <- nemeton::nemeton_units(
    units,
    metadata = list(site_name = "Test Forest", year = 2024, source = "IGN")
  )

  meta <- attr(nu, "metadata")
  expect_equal(meta$site_name, "Test Forest")
  expect_equal(meta$year, 2024)
  expect_equal(meta$source, "IGN")
})

# --- print.nemeton_units() ---

test_that("print.nemeton_units() with site_name and year metadata", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 5)
  nu <- nemeton::nemeton_units(
    units,
    metadata = list(site_name = "Fontainebleau", year = 2024)
  )

  output <- capture.output(print(nu))
  output_str <- paste(output, collapse = "\n")

  expect_true(grepl("nemeton_units", output_str))
  expect_true(grepl("Fontainebleau", output_str))
  expect_true(grepl("2024", output_str))
  expect_true(grepl("Units:", output_str))
  expect_true(grepl("5", output_str))
})

test_that("print.nemeton_units() with area_total shows hectares", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 3)
  nu <- nemeton::nemeton_units(units)

  output <- capture.output(print(nu))
  output_str <- paste(output, collapse = "\n")

  expect_true(grepl("Total area", output_str))
  expect_true(grepl("ha", output_str))
})

# --- summary.nemeton_units() ---

test_that("summary.nemeton_units() outputs complete summary", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 5)
  nu <- nemeton::nemeton_units(
    units,
    metadata = list(site_name = "Test", year = 2024, source = "Test Data")
  )

  output <- capture.output(summary(nu))
  output_str <- paste(output, collapse = "\n")

  expect_true(grepl("Nemeton Units Summary", output_str))
  expect_true(grepl("Number of units: 5", output_str))
  expect_true(grepl("Site: Test", output_str))
  expect_true(grepl("Year: 2024", output_str))
  expect_true(grepl("Source: Test Data", output_str))
  expect_true(grepl("Total area", output_str))
  expect_true(grepl("Mean area", output_str))
  expect_true(grepl("Attributes", output_str))
})

test_that("summary.nemeton_units() handles missing metadata fields", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 3)
  nu <- nemeton::nemeton_units(units)

  output <- capture.output(summary(nu))
  output_str <- paste(output, collapse = "\n")

  expect_true(grepl("Not specified", output_str))
})

# --- nemeton_layers() ---

test_that("nemeton_layers() with rasters and vectors (validate=FALSE)", {
  skip_if_not_installed("terra")
  layers <- nemeton::nemeton_layers(
    rasters = list(ndvi = "/tmp/fake_ndvi.tif", dem = "/tmp/fake_dem.tif"),
    vectors = list(rivers = "/tmp/fake_rivers.gpkg"),
    validate = FALSE
  )

  expect_s3_class(layers, "nemeton_layers")
  expect_equal(layers$metadata$n_rasters, 2)
  expect_equal(layers$metadata$n_vectors, 1)
  expect_true("ndvi" %in% names(layers$rasters))
  expect_true("dem" %in% names(layers$rasters))
  expect_true("rivers" %in% names(layers$vectors))
  expect_false(layers$rasters$ndvi$loaded)
})

test_that("nemeton_layers() with only rasters", {
  skip_if_not_installed("terra")
  layers <- nemeton::nemeton_layers(
    rasters = list(ndvi = "/tmp/fake.tif"),
    validate = FALSE
  )

  expect_s3_class(layers, "nemeton_layers")
  expect_equal(layers$metadata$n_rasters, 1)
  expect_equal(layers$metadata$n_vectors, 0)
  expect_equal(length(layers$vectors), 0)
})

test_that("nemeton_layers() with only vectors", {
  skip_if_not_installed("terra")
  layers <- nemeton::nemeton_layers(
    vectors = list(roads = "/tmp/fake.gpkg"),
    validate = FALSE
  )

  expect_s3_class(layers, "nemeton_layers")
  expect_equal(layers$metadata$n_rasters, 0)
  expect_equal(layers$metadata$n_vectors, 1)
  expect_equal(length(layers$rasters), 0)
})

test_that("nemeton_layers() errors when both rasters and vectors are NULL", {
  skip_if_not_installed("terra")
  expect_error(
    nemeton::nemeton_layers(rasters = NULL, vectors = NULL),
    "rasters.*vectors"
  )
})

test_that("nemeton_layers() errors on unnamed rasters list", {
  skip_if_not_installed("terra")
  expect_error(
    nemeton::nemeton_layers(
      rasters = list("/tmp/fake.tif"),
      validate = FALSE
    ),
    "named list"
  )
})

test_that("nemeton_layers() errors on unnamed vectors list", {
  skip_if_not_installed("terra")
  expect_error(
    nemeton::nemeton_layers(
      vectors = list("/tmp/fake.gpkg"),
      validate = FALSE
    ),
    "named list"
  )
})

test_that("nemeton_layers() stores path and loaded status", {
  skip_if_not_installed("terra")
  layers <- nemeton::nemeton_layers(
    rasters = list(ndvi = "/tmp/test_ndvi.tif"),
    vectors = list(rivers = "/tmp/test_rivers.gpkg"),
    validate = FALSE
  )

  expect_false(layers$rasters$ndvi$loaded)
  expect_null(layers$rasters$ndvi$object)
  expect_false(layers$vectors$rivers$loaded)
  expect_null(layers$vectors$rivers$object)
})

# --- print.nemeton_layers() ---

test_that("print.nemeton_layers() shows rasters and vectors", {
  skip_if_not_installed("terra")
  layers <- nemeton::nemeton_layers(
    rasters = list(ndvi = "/tmp/test_ndvi.tif", dem = "/tmp/test_dem.tif"),
    vectors = list(rivers = "/tmp/test_rivers.gpkg"),
    validate = FALSE
  )

  output <- capture.output(print(layers))
  output_str <- paste(output, collapse = "\n")

  expect_true(grepl("nemeton_layers", output_str))
  expect_true(grepl("Rasters", output_str))
  expect_true(grepl("ndvi", output_str))
  expect_true(grepl("dem", output_str))
  expect_true(grepl("Vectors", output_str))
  expect_true(grepl("rivers", output_str))
  expect_true(grepl("not loaded", output_str))
})

test_that("print.nemeton_layers() shows (none) for empty sections", {
  skip_if_not_installed("terra")
  layers <- nemeton::nemeton_layers(
    rasters = list(ndvi = "/tmp/test_ndvi.tif"),
    validate = FALSE
  )

  output <- capture.output(print(layers))
  output_str <- paste(output, collapse = "\n")

  expect_true(grepl("\\(none\\)", output_str))
})

# --- summary.nemeton_layers() ---

test_that("summary.nemeton_layers() outputs basic info", {
  skip_if_not_installed("terra")
  layers <- nemeton::nemeton_layers(
    rasters = list(ndvi = "/tmp/test.tif", dem = "/tmp/test2.tif"),
    vectors = list(roads = "/tmp/test.gpkg"),
    validate = FALSE
  )

  output <- capture.output(summary(layers))
  output_str <- paste(output, collapse = "\n")

  expect_true(grepl("Nemeton Layers Summary", output_str))
  expect_true(grepl("Rasters: 2", output_str))
  expect_true(grepl("Vectors: 1", output_str))
  expect_true(grepl("Created:", output_str))
})

# --- Additional edge cases ---

test_that("nemeton_layers() validates=TRUE errors on nonexistent files", {
  skip_if_not_installed("terra")
  expect_error(
    nemeton::nemeton_layers(
      rasters = list(ndvi = "/tmp/definitely_nonexistent_file_42.tif"),
      validate = TRUE
    ),
    "not found"
  )
})

test_that("nemeton_layers() metadata includes created_at and validated", {
  skip_if_not_installed("terra")
  layers <- nemeton::nemeton_layers(
    rasters = list(ndvi = "/tmp/fake.tif"),
    validate = FALSE
  )

  expect_true(!is.null(layers$metadata$created_at))
  expect_false(layers$metadata$validated)
})
