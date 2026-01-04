#' Harmonize CRS of layers to match target CRS
#'
#' @param layers A nemeton_layers object
#' @param target_crs CRS object or EPSG code
#' @param verbose Logical. Print messages? Default TRUE.
#'
#' @return nemeton_layers object with harmonized CRS
#' @keywords internal
#' @noRd
harmonize_crs <- function(layers, target_crs, verbose = TRUE) {
  if (!inherits(layers, "nemeton_layers")) {
    cli::cli_abort("{.arg layers} must be a {.cls nemeton_layers} object")
  }

  target_crs <- sf::st_crs(target_crs)

  # Process rasters
  for (name in names(layers$rasters)) {
    layer <- layers$rasters[[name]]

    # Load if not loaded
    if (!layer$loaded) {
      layer$object <- terra::rast(layer$path)
      layer$loaded <- TRUE
    }

    # Check CRS
    layer_crs <- terra::crs(layer$object, describe = TRUE)$code

    if (!is.na(layer_crs) && layer_crs != target_crs$epsg) {
      if (verbose) {
        message_nemeton("Reprojecting raster {.field {name}} from EPSG:{layer_crs} to EPSG:{target_crs$epsg}")
      }
      layer$object <- terra::project(layer$object, paste0("EPSG:", target_crs$epsg))
    }

    layers$rasters[[name]] <- layer
  }

  # Process vectors
  for (name in names(layers$vectors)) {
    layer <- layers$vectors[[name]]

    # Load if not loaded
    if (!layer$loaded) {
      layer$object <- sf::st_read(layer$path, quiet = TRUE)
      layer$loaded <- TRUE
    }

    # Check CRS
    layer_crs <- sf::st_crs(layer$object)

    if (!is.na(layer_crs) && !sf::st_crs(layer_crs) == target_crs) {
      if (verbose) {
        message_nemeton("Reprojecting vector {.field {name}} to {target_crs$input}")
      }
      layer$object <- sf::st_transform(layer$object, target_crs)
    }

    layers$vectors[[name]] <- layer
  }

  layers
}

#' Crop layers to extent of units
#'
#' @param layers A nemeton_layers object
#' @param units Spatial units (sf object)
#' @param buffer Buffer distance in units of CRS (default 0)
#'
#' @return nemeton_layers object with cropped layers
#' @keywords internal
#' @noRd
crop_to_units <- function(layers, units, buffer = 0) {
  if (!inherits(layers, "nemeton_layers")) {
    cli::cli_abort("{.arg layers} must be a {.cls nemeton_layers} object")
  }

  if (!inherits(units, "sf")) {
    cli::cli_abort("{.arg units} must be an {.cls sf} object")
  }

  # Get extent with buffer
  bbox <- sf::st_bbox(units)
  if (buffer > 0) {
    bbox[c("xmin", "ymin")] <- bbox[c("xmin", "ymin")] - buffer
    bbox[c("xmax", "ymax")] <- bbox[c("xmax", "ymax")] + buffer
  }

  # Crop rasters
  for (name in names(layers$rasters)) {
    layer <- layers$rasters[[name]]

    # Load if not loaded
    if (!layer$loaded) {
      layer$object <- terra::rast(layer$path)
      layer$loaded <- TRUE
    }

    # Crop
    ext <- terra::ext(bbox["xmin"], bbox["xmax"], bbox["ymin"], bbox["ymax"])
    layer$object <- terra::crop(layer$object, ext)

    layers$rasters[[name]] <- layer
  }

  # Crop vectors
  for (name in names(layers$vectors)) {
    layer <- layers$vectors[[name]]

    # Load if not loaded
    if (!layer$loaded) {
      layer$object <- sf::st_read(layer$path, quiet = TRUE)
      layer$loaded <- TRUE
    }

    # Crop
    bbox_sf <- sf::st_as_sfc(bbox)
    layer$object <- sf::st_crop(layer$object, bbox_sf)

    layers$vectors[[name]] <- layer
  }

  # Message about cropping
  buffer_value <- buffer
  cli::cli_alert_info("Cropped layers to extent of units (buffer: {buffer_value}m)")

  layers
}

#' Mask raster layers to units
#'
#' @param layers A nemeton_layers object
#' @param units Spatial units (sf object)
#'
#' @return nemeton_layers object with masked rasters
#' @keywords internal
#' @noRd
mask_to_units <- function(layers, units, verbose = TRUE) {
  if (!inherits(layers, "nemeton_layers")) {
    cli::cli_abort("{.arg layers} must be a {.cls nemeton_layers} object")
  }

  if (!inherits(units, "sf")) {
    cli::cli_abort("{.arg units} must be an {.cls sf} object")
  }

  # Mask rasters only (vectors don't need masking)
  for (name in names(layers$rasters)) {
    layer <- layers$rasters[[name]]

    # Load if not loaded
    if (!layer$loaded) {
      layer$object <- terra::rast(layer$path)
      layer$loaded <- TRUE
    }

    # Convert sf to terra vector (remove nemeton_units class for compatibility)
    units_vect <- terra::vect(as_pure_sf(units))

    # Mask
    layer$object <- terra::mask(layer$object, units_vect)

    layers$rasters[[name]] <- layer
  }

  if (verbose) {
    message_nemeton("Masked {length(layers$rasters)} raster{?s} to units")
  }

  layers
}
