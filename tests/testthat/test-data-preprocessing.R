test_that("harmonize_crs reprojects rasters to target CRS", {
  temp_files <- create_temp_test_files()

  # Create layers in Lambert 93
  layers <- nemeton_layers(
    rasters = list(biomass = temp_files$biomass),
    validate = TRUE
  )

  # Target: WGS84 (EPSG:4326)
  target_crs <- sf::st_crs(4326)

  # Harmonize
  harmonized <- harmonize_crs(layers, target_crs, verbose = FALSE)

  # Check that raster was loaded and reprojected
  expect_true(harmonized$rasters$biomass$loaded)

  # Check that it was reprojected
  raster_crs <- terra::crs(harmonized$rasters$biomass$object, describe = TRUE)$code
  expect_equal(raster_crs, "4326")
})

test_that("harmonize_crs reprojects vectors to target CRS", {
  temp_files <- create_temp_test_files()

  # Create layers
  layers <- nemeton_layers(
    vectors = list(roads = temp_files$roads)
  )

  # Target: WGS84
  target_crs <- sf::st_crs(4326)

  # Harmonize
  harmonized <- harmonize_crs(layers, target_crs, verbose = FALSE)

  # Check that vector was loaded and reprojected
  expect_true(harmonized$vectors$roads$loaded)

  result_crs <- sf::st_crs(harmonized$vectors$roads$object)
  expect_equal(result_crs$epsg, 4326)
})

test_that("harmonize_crs handles already-matching CRS", {
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(biomass = temp_files$biomass)
  )

  # Use same CRS as source
  target_crs <- sf::st_crs(2154)

  # Should not reproject (already matching)
  harmonized <- harmonize_crs(layers, target_crs, verbose = FALSE)

  expect_s3_class(harmonized, "nemeton_layers")
})

test_that("harmonize_crs requires nemeton_layers object", {
  expect_error(
    harmonize_crs(list(), sf::st_crs(2154)),
    "must be a.*nemeton_layers.*object"
  )
})

test_that("crop_to_units crops rasters to unit extent", {
  # Create units and layers
  units <- nemeton_units(create_test_units(n_features = 1))
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(biomass = temp_files$biomass)
  )

  # Crop
  cropped <- crop_to_units(layers, units, buffer = 0)

  # Load and check extent
  cropped$rasters$biomass$object <- terra::rast(cropped$rasters$biomass$path)

  # Original extent
  original_raster <- terra::rast(temp_files$biomass)
  original_ext <- terra::ext(original_raster)

  # Cropped extent
  cropped_ext <- terra::ext(cropped$rasters$biomass$object)

  # Cropped should be smaller or equal
  expect_true(cropped_ext$xmin >= original_ext$xmin)
  expect_true(cropped_ext$xmax <= original_ext$xmax)
})

test_that("crop_to_units crops vectors to unit extent", {
  units <- nemeton_units(create_test_units(n_features = 1))
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    vectors = list(roads = temp_files$roads)
  )

  # Crop
  cropped <- crop_to_units(layers, units, buffer = 0)

  # Should complete without error
  expect_s3_class(cropped, "nemeton_layers")
})

test_that("crop_to_units applies buffer correctly", {
  units <- nemeton_units(create_test_units(n_features = 1))
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(biomass = temp_files$biomass)
  )

  # Crop with buffer
  cropped_buffered <- crop_to_units(layers, units, buffer = 100)
  cropped_no_buffer <- crop_to_units(layers, units, buffer = 0)

  # Load both
  r_buffered <- terra::rast(cropped_buffered$rasters$biomass$path)
  r_no_buffer <- terra::rast(cropped_no_buffer$rasters$biomass$path)

  # Buffered should have larger extent
  ext_buffered <- terra::ext(r_buffered)
  ext_no_buffer <- terra::ext(r_no_buffer)

  expect_true(ext_buffered$xmin <= ext_no_buffer$xmin)
  expect_true(ext_buffered$xmax >= ext_no_buffer$xmax)
})

test_that("crop_to_units requires valid inputs", {
  units <- nemeton_units(create_test_units(n_features = 1))

  # Non-nemeton_layers object
  expect_error(
    crop_to_units(list(), units),
    "must be a.*nemeton_layers.*object"
  )

  # Non-sf units
  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  expect_error(
    crop_to_units(layers, data.frame(x = 1:3)),
    "must be an.*sf.*object"
  )
})

test_that("mask_to_units masks rasters to unit geometries", {
  units <- nemeton_units(create_test_units(n_features = 1))
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    rasters = list(biomass = temp_files$biomass)
  )

  # Mask
  masked <- mask_to_units(layers, units, verbose = FALSE)

  # Check that raster was loaded and masked
  expect_true(masked$rasters$biomass$loaded)

  # Should have some NA values (outside the unit polygon)
  expect_true(any(is.na(terra::values(masked$rasters$biomass$object))))
})

test_that("mask_to_units only affects rasters", {
  units <- nemeton_units(create_test_units(n_features = 1))
  temp_files <- create_temp_test_files()

  layers <- nemeton_layers(
    vectors = list(roads = temp_files$roads)
  )

  # Should work but not modify vectors
  masked <- mask_to_units(layers, units, verbose = FALSE)

  expect_s3_class(masked, "nemeton_layers")
  expect_equal(length(masked$vectors), 1)
})

test_that("mask_to_units requires valid inputs", {
  units <- nemeton_units(create_test_units(n_features = 1))

  expect_error(
    mask_to_units(list(), units),
    "must be a.*nemeton_layers.*object"
  )

  temp_files <- create_temp_test_files()
  layers <- nemeton_layers(rasters = list(biomass = temp_files$biomass))

  expect_error(
    mask_to_units(layers, data.frame(x = 1:3)),
    "must be an.*sf.*object"
  )
})
