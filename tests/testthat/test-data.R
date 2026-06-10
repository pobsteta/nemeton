# Test Suite for Package Datasets
# massif_demo_units with 12-family referential

test_that("massif_demo_units has correct structure", {
  skip_if_not_installed("sf")

  data("massif_demo_units", package = "nemeton")

  expect_s3_class(massif_demo_units, "sf")
  expect_equal(nrow(massif_demo_units), 20)
  expect_true("geometry" %in% names(massif_demo_units))
  expect_true("parcel_id" %in% names(massif_demo_units))
  expect_equal(sf::st_crs(massif_demo_units)$epsg, 2154)
})

test_that("massif_demo_units has all 29 indicators present", {
  skip_if_not_installed("sf")

  data("massif_demo_units", package = "nemeton")

  required_indicators <- c(
    "C1", "C2", "B1", "B2", "B3", "W1", "W2", "W3", "A1", "A2",
    "F1", "F2", "L1", "L2", "T1", "T2", "R1", "R2", "R3",
    "S1", "S2", "S3", "P1", "P2", "P3", "E1", "E2", "N1", "N2", "N3"
  )

  missing_indicators <- setdiff(required_indicators, names(massif_demo_units))
  expect_length(missing_indicators, 0)

  for (ind in required_indicators) {
    expect_type(massif_demo_units[[ind]], "double")
    expect_true(any(!is.na(massif_demo_units[[ind]])))
  }
})

test_that("massif_demo_units has all 12 family composites in valid range", {
  skip_if_not_installed("sf")

  data("massif_demo_units", package = "nemeton")

  required_families <- unname(nemeton:::FAMILLE_NMT_MAP[c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")])

  missing_families <- setdiff(required_families, names(massif_demo_units))
  expect_length(missing_families, 0)

  for (fam in required_families) {
    expect_type(massif_demo_units[[fam]], "double")
    values <- massif_demo_units[[fam]]
    expect_true(all(values >= 0 & values <= 100, na.rm = TRUE))
    expect_true(any(!is.na(values)))
  }
})

test_that("massif_demo_units has base attributes", {
  skip_if_not_installed("sf")

  data("massif_demo_units", package = "nemeton")

  # Base attributes from original massif_demo_units
  expect_true("parcel_id" %in% names(massif_demo_units))
  expect_true("species" %in% names(massif_demo_units))
  expect_true("age" %in% names(massif_demo_units))
  expect_true("density" %in% names(massif_demo_units))
  expect_true("surface_ha" %in% names(massif_demo_units))

  expect_true(all(massif_demo_units$surface_ha > 0, na.rm = TRUE))
})

test_that("massif_demo_units covers realistic value ranges", {
  skip_if_not_installed("sf")

  data("massif_demo_units", package = "nemeton")

  # Social indicators
  expect_true(all(massif_demo_units$S1 >= 0 & massif_demo_units$S1 <= 5, na.rm = TRUE))
  expect_true(all(massif_demo_units$S2 >= 0 & massif_demo_units$S2 <= 100, na.rm = TRUE))
  expect_true(all(massif_demo_units$S3 >= 0, na.rm = TRUE))

  # Production indicators
  expect_true(all(massif_demo_units$P1 >= 0 & massif_demo_units$P1 <= 1000, na.rm = TRUE))
  expect_true(all(massif_demo_units$P2 >= 0 & massif_demo_units$P2 <= 20, na.rm = TRUE))
  expect_true(all(massif_demo_units$P3 >= 0 & massif_demo_units$P3 <= 100, na.rm = TRUE))

  # Energy indicators
  expect_true(all(massif_demo_units$E1 >= 0 & massif_demo_units$E1 <= 15, na.rm = TRUE))
  expect_true(all(massif_demo_units$E2 >= 0 & massif_demo_units$E2 <= 30, na.rm = TRUE))

  # Naturality indicators
  expect_true(all(massif_demo_units$N1 >= 0 & massif_demo_units$N1 <= 10000, na.rm = TRUE))
  expect_true(all(massif_demo_units$N2 >= 0, na.rm = TRUE))
  expect_true(all(massif_demo_units$N3 >= 0 & massif_demo_units$N3 <= 100, na.rm = TRUE))
})

# ==============================================================================
# Tests for massif_demo_layers()
# ==============================================================================

test_that("massif_demo_layers returns valid nemeton_layers object", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  layers <- massif_demo_layers()

  expect_s3_class(layers, "nemeton_layers")
  expect_true(is.list(layers))
  expect_true("rasters" %in% names(layers))
  expect_true("vectors" %in% names(layers))
})

test_that("massif_demo_layers contains required rasters", {
  skip_if_not_installed("terra")

  layers <- massif_demo_layers()

  # Required rasters
  required_rasters <- c("biomass", "dem", "landcover")

  for (raster_name in required_rasters) {
    expect_true(raster_name %in% names(layers$rasters),
      info = paste("Missing raster:", raster_name))
  }
})

test_that("massif_demo_layers contains required vectors", {
  skip_if_not_installed("sf")

  layers <- massif_demo_layers()

  # Required vectors
  required_vectors <- c("roads", "water")

  for (vector_name in required_vectors) {
    expect_true(vector_name %in% names(layers$vectors),
      info = paste("Missing vector:", vector_name))
  }
})

test_that("massif_demo_layers rasters are loadable from paths", {
  skip_if_not_installed("terra")

  layers <- massif_demo_layers()

  # Rasters are lazy-loaded, get the path
  expect_true(!is.null(layers$rasters$biomass$path))

  # Test that we can load biomass raster from path
  biomass <- terra::rast(layers$rasters$biomass$path)
  expect_s4_class(biomass, "SpatRaster")
  expect_true(terra::ncell(biomass) > 0)
})

test_that("massif_demo_layers vectors are loadable from paths", {
  skip_if_not_installed("sf")

  layers <- massif_demo_layers()

  # Vectors are lazy-loaded, get the path
  expect_true(!is.null(layers$vectors$roads$path))

  # Test that we can load roads vector from path
  roads <- sf::st_read(layers$vectors$roads$path, quiet = TRUE)
  expect_s3_class(roads, "sf")
  expect_true(nrow(roads) > 0)
})

test_that("massif_demo_layers has consistent CRS across layers", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  layers <- massif_demo_layers()

  # Load a raster and vector from paths
  biomass <- terra::rast(layers$rasters$biomass$path)
  roads <- sf::st_read(layers$vectors$roads$path, quiet = TRUE)

  # Get CRS
  raster_crs <- terra::crs(biomass, describe = TRUE)$code
  vector_crs <- sf::st_crs(roads)$epsg

  # Both should be EPSG:2154 (Lambert 93)
  expect_equal(as.numeric(raster_crs), 2154)
  expect_equal(vector_crs, 2154)
})

test_that("massif_demo_layers works with nemeton_compute", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  data("massif_demo_units", package = "nemeton")
  layers <- massif_demo_layers()

  # Test computing a simple indicator
  result <- nemeton_compute(
    massif_demo_units[1:3, ],
    layers,
    indicators = "indicateur_c1_biomasse",
    preprocess = TRUE
  )

  expect_s3_class(result, "sf")
  expect_true("C1" %in% names(result))
})

test_that("massif_demo_layers print method works", {
  skip_if_not_installed("terra")
  layers <- massif_demo_layers()

  expect_output(print(layers), "nemeton_layers")
})

test_that("massif_demo_layers summary method works", {
  skip_if_not_installed("terra")
  layers <- massif_demo_layers()

  # summary should return a summary
  summary_result <- summary(layers)
  expect_true(is.list(summary_result) || is.character(summary_result) || !is.null(summary_result))
})
