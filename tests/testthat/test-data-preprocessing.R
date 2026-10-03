test_that("harmonize_crs reprojects rasters to target CRS", {
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
  expect_error(
    harmonize_crs(list(), sf::st_crs(2154)),
    "must be a.*nemeton_layers.*object"
  )
})

test_that("crop_to_units crops rasters to unit extent", {
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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
  skip_if_not_installed("terra")
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


# --- Audit 1.0 : couches categorielles et CRS sans code EPSG ---------------

.layers_en_memoire <- function(rasters) {
  layers <- nemeton_layers(
    rasters = stats::setNames(as.list(rep("absent.tif", length(rasters))), names(rasters)),
    validate = FALSE
  )
  for (nm in names(rasters)) {
    layers$rasters[[nm]]$object <- rasters[[nm]]
    layers$rasters[[nm]]$loaded <- TRUE
  }
  layers
}

test_that("harmonize_crs reprojects a categorical layer by nearest neighbour", {
  skip_if_not_installed("terra")
  set.seed(1)
  lc <- terra::rast(xmin = 566400, xmax = 567000, ymin = 6615100, ymax = 6615500,
                    resolution = 10, crs = "EPSG:2154")
  terra::values(lc) <- sample(c(1, 5, 9), terra::ncell(lc), replace = TRUE)
  layers <- .layers_en_memoire(list(landcover = lc))

  out <- harmonize_crs(layers, sf::st_crs(4326), verbose = FALSE)
  v <- stats::na.omit(terra::values(out$rasters$landcover$object)[, 1])
  # Bilineaire : classes fractionnaires inexistantes ; plus proche voisin : non
  expect_true(all(v %in% c(1, 5, 9)))
})

test_that("harmonize_crs keeps bilinear resampling for continuous layers", {
  skip_if_not_installed("terra")
  r <- terra::rast(xmin = 566400, xmax = 567000, ymin = 6615100, ymax = 6615500,
                   resolution = 10, crs = "EPSG:2154")
  terra::values(r) <- seq(0, 1, length.out = terra::ncell(r))
  expect_false(.is_categorical_raster(r, "biomass"))
  int_r <- r
  terra::values(int_r) <- rep(1:4, length.out = terra::ncell(r))
  expect_true(.is_categorical_raster(int_r, "foo"))
  expect_true(.is_categorical_raster(r, "landcover"))
})

test_that("harmonize_crs reprojects a raster whose CRS has no EPSG code", {
  skip_if_not_installed("terra")
  # Lambert-93 decrit par une chaine PROJ, sans code EPSG
  proj_l93 <- paste(
    "+proj=lcc +lat_0=46.5 +lon_0=3 +lat_1=49 +lat_2=44 +x_0=700000",
    "+y_0=6600000 +ellps=GRS80 +units=m +no_defs")
  r <- terra::rast(xmin = 566400, xmax = 567000, ymin = 6615100, ymax = 6615500,
                   resolution = 10, crs = proj_l93)
  terra::values(r) <- seq(0, 1, length.out = terra::ncell(r))
  layers <- .layers_en_memoire(list(biomass = r))

  out <- harmonize_crs(layers, sf::st_crs(4326), verbose = FALSE)
  expect_true(sf::st_crs(terra::crs(out$rasters$biomass$object)) == sf::st_crs(4326))
})
