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

    # Comparaison sur les objets CRS (et non sur les codes EPSG : un CRS sans
    # code EPSG donnait NA et la reprojection etait sautee).
    layer_wkt <- terra::crs(layer$object)
    if (!nzchar(layer_wkt)) {
      cli::cli_warn("Raster layer {.val {name}} has no CRS; left as is (cannot reproject it).")
    } else if (!isTRUE(sf::st_crs(layer_wkt) == target_crs)) {
      # Couche categorielle (occupation du sol, essences, masques...) :
      # plus proche voisin, sinon l'interpolation fabrique des classes
      # fractionnaires inexistantes.
      method <- if (.is_categorical_raster(layer$object, name)) "near" else "bilinear"
      if (verbose) {
        message_nemeton("Reprojecting raster ", name, " to ",
                        .crs_label(target_crs), " (method: ", method, ")")
      }
      layer$object <- terra::project(layer$object, target_crs$wkt, method = method)
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

    if (!is.na(layer_crs) && !isTRUE(layer_crs == target_crs)) {
      if (verbose) {
        message_nemeton("Reprojecting vector ", name, " to ", .crs_label(target_crs))
      }
      layer$object <- sf::st_transform(layer$object, target_crs)
    }

    layers$vectors[[name]] <- layer
  }

  layers
}

# Libelle lisible d'un CRS (code EPSG si connu, sinon son nom).
.crs_label <- function(crs) {
  if (!is.na(crs$epsg)) paste0("EPSG:", crs$epsg) else as.character(crs$Name %||% crs$input)
}

#' Detect a categorical raster
#'
#' A raster is treated as categorical (to be resampled by nearest neighbour)
#' when it is a factor raster, when its layer name matches a known
#' categorical product, or when a sample of its values holds only integers
#' with few distinct values.
#'
#' @param r A `SpatRaster`.
#' @param name Layer name in the `nemeton_layers` object.
#' @param max_classes Maximum number of distinct integer values for the
#'   value-based detection.
#' @return Logical scalar.
#' @keywords internal
#' @noRd
.is_categorical_raster <- function(r, name = "", max_classes = 64L) {
  if (any(terra::is.factor(r))) return(TRUE)
  categorical_names <- paste0(
    "landcover|land_cover|occupation|oso|corine|clc|species|essence|",
    "classif|class|mask|masque|tfv|forest_type|type_foret|bdforet")
  noms <- tolower(c(name, names(r)))
  if (any(grepl(categorical_names, noms))) return(TRUE)
  v <- tryCatch(
    terra::spatSample(r[[1]], size = 2000, method = "regular",
                      na.rm = TRUE, warn = FALSE)[[1]],
    error = function(e) NULL)
  v <- v[is.finite(v)]
  if (!length(v)) return(FALSE)
  all(v == round(v)) && length(unique(v)) <= max_classes
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

    # Crop (set agr to avoid "attribute variables assumed spatially constant" warning)
    bbox_sf <- sf::st_as_sfc(bbox)
    sf::st_agr(layer$object) <- "constant"
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
