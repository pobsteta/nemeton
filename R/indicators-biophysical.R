#' Calculate carbon stock indicator
#'
#' Estimates above-ground carbon stock from biomass raster data.
#'
#' @param units A \code{nemeton_units} or \code{sf} object representing analysis units
#' @param layers A \code{nemeton_layers} object containing spatial data
#' @param biomass_layer Character. Name of the biomass raster layer in layers. Default "biomass".
#' @param conversion_factor Numeric. Conversion factor from biomass to carbon (default 0.47 for forests)
#' @param fun Character. Summary function for zonal extraction. Default "mean".
#'   Options: "mean", "sum", "median", "min", "max"
#' @param ... Additional arguments (not used)
#'
#' @return Numeric vector of carbon stock values (tonnes C/ha or similar units)
#'
#' @details
#' The function performs the following steps:
#' \enumerate{
#'   \item Extracts biomass values from raster using exact zonal statistics
#'   \item Applies conversion factor to convert biomass to carbon stock
#'   \item Returns summary statistic per unit (default: mean)
#' }
#'
#' The default conversion factor (0.47) is based on IPCC guidelines for forest biomass.
#' Adjust this value based on your biomass data units and carbon estimation method.
#'
#' @examples
#' \dontrun{
#' carbon <- indicator_carbon(units, layers, biomass_layer = "agb")
#' }
#'
#' @seealso \code{\link{nemeton_compute}}
#'
#' @export
indicator_carbon <- function(units,
                             layers,
                             biomass_layer = "biomass",
                             conversion_factor = 0.47,
                             fun = "mean",
                             ...) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    cli::cli_abort("{.arg units} must be an {.cls sf} object")
  }

  if (!inherits(layers, "nemeton_layers")) {
    cli::cli_abort("{.arg layers} must be a {.cls nemeton_layers} object")
  }

  # Check if layer exists
  if (!biomass_layer %in% names(layers$rasters)) {
    cli::cli_abort(c(
      "!" = "Biomass layer {.field {biomass_layer}} not found",
      "i" = "Available rasters: {.field {names(layers$rasters)}}",
      ">" = "Specify layer with {.code biomass_layer = 'name'}"
    ))
  }

  # Get the raster layer
  layer <- layers$rasters[[biomass_layer]]

  # Load if not loaded
  if (!layer$loaded) {
    layer$object <- terra::rast(layer$path)
  }

  # Extract values using exactextractr
  extracted <- exactextractr::exact_extract(
    layer$object,
    units,
    fun = fun,
    progress = FALSE
  )

  # Convert to carbon stock
  carbon_stock <- extracted * conversion_factor

  # Return numeric vector
  as.numeric(carbon_stock)
}

#' Calculate biodiversity indicator
#'
#' Computes biodiversity indices from species occurrence or richness data.
#'
#' @param units A \code{nemeton_units} or \code{sf} object representing analysis units
#' @param layers A \code{nemeton_layers} object containing spatial data
#' @param richness_layer Character. Name of species richness raster layer. Default "species_richness".
#' @param index Character. Biodiversity index to calculate. Options: "richness", "shannon", "simpson".
#'   Default "richness".
#' @param fun Character. Summary function for zonal extraction. Default "mean".
#' @param ... Additional arguments (not used)
#'
#' @return Numeric vector of biodiversity index values
#'
#' @details
#' Biodiversity indices:
#' \itemize{
#'   \item \strong{richness}: Mean species count per unit (raw values from raster)
#'   \item \strong{shannon}: Shannon diversity index (if provided in raster)
#'   \item \strong{simpson}: Simpson diversity index (if provided in raster)
#' }
#'
#' For MVP (v0.1.0), this function expects pre-calculated biodiversity rasters.
#' Future versions will support raw species occurrence data and in-situ calculation.
#'
#' @examples
#' \dontrun{
#' # Species richness
#' richness <- indicator_biodiversity(units, layers, index = "richness")
#'
#' # Shannon index
#' shannon <- indicator_biodiversity(
#'   units, layers,
#'   richness_layer = "shannon_index",
#'   index = "shannon"
#' )
#' }
#'
#' @seealso \code{\link{nemeton_compute}}
#'
#' @export
indicator_biodiversity <- function(units,
                                   layers,
                                   richness_layer = "species_richness",
                                   index = c("richness", "shannon", "simpson"),
                                   fun = "mean",
                                   ...) {
  # Match index argument
  index <- match.arg(index)

  # Validate inputs
  if (!inherits(units, "sf")) {
    cli::cli_abort("{.arg units} must be an {.cls sf} object")
  }

  if (!inherits(layers, "nemeton_layers")) {
    cli::cli_abort("{.arg layers} must be a {.cls nemeton_layers} object")
  }

  # Check if layer exists
  if (!richness_layer %in% names(layers$rasters)) {
    cli::cli_abort(c(
      "!" = "Biodiversity layer {.field {richness_layer}} not found",
      "i" = "Available rasters: {.field {names(layers$rasters)}}",
      ">" = "Specify layer with {.code richness_layer = 'name'}"
    ))
  }

  # Get the raster layer
  layer <- layers$rasters[[richness_layer]]

  # Load if not loaded
  if (!layer$loaded) {
    layer$object <- terra::rast(layer$path)
  }

  # Extract values
  biodiv_values <- exactextractr::exact_extract(
    layer$object,
    units,
    fun = fun,
    progress = FALSE
  )

  # Return numeric vector
  as.numeric(biodiv_values)
}

#' Calculate water regulation indicator
#'
#' Estimates water regulation capacity from topography and hydrography.
#'
#' @param units A \code{nemeton_units} or \code{sf} object representing analysis units
#' @param layers A \code{nemeton_layers} object containing spatial data
#' @param dem_layer Character. Name of Digital Elevation Model raster. Default "dem".
#' @param water_layer Character. Name of water bodies vector layer. Default "water".
#' @param calculate_twi Logical. Calculate Topographic Wetness Index? Default TRUE.
#' @param calculate_proximity Logical. Calculate proximity to water bodies? Default TRUE.
#' @param max_distance Numeric. Maximum distance to consider for proximity (meters). Default 1000.
#' @param weights Numeric vector of length 2. Weights for TWI and proximity components.
#'   Default c(0.6, 0.4) (60% TWI, 40% proximity).
#' @param ... Additional arguments (not used)
#'
#' @return Numeric vector of water regulation indicator values
#'
#' @details
#' The water regulation indicator combines:
#' \enumerate{
#'   \item \strong{Topographic Wetness Index (TWI)}: Simplified proxy from DEM slope
#'   \item \strong{Proximity to water}: Distance to nearest water body (inverse weighted)
#' }
#'
#' For MVP (v0.1.0), TWI is approximated from slope. Future versions will implement
#' full flow accumulation analysis.
#'
#' @examples
#' \dontrun{
#' water_reg <- indicator_water(units, layers)
#'
#' # TWI only
#' twi <- indicator_water(
#'   units, layers,
#'   calculate_proximity = FALSE
#' )
#' }
#'
#' @seealso \code{\link{nemeton_compute}}
#'
#' @export
indicator_water <- function(units,
                            layers,
                            dem_layer = "dem",
                            water_layer = "water",
                            calculate_twi = TRUE,
                            calculate_proximity = TRUE,
                            max_distance = 1000,
                            weights = c(0.6, 0.4),
                            ...) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    cli::cli_abort("{.arg units} must be an {.cls sf} object")
  }

  if (!inherits(layers, "nemeton_layers")) {
    cli::cli_abort("{.arg layers} must be a {.cls nemeton_layers} object")
  }

  # Initialize components
  n_units <- nrow(units)
  twi_component <- rep(0, n_units)
  proximity_component <- rep(0, n_units)

  # Calculate TWI from DEM
  if (calculate_twi) {
    if (!dem_layer %in% names(layers$rasters)) {
      cli::cli_warn(c(
        "!" = "DEM layer {.field {dem_layer}} not found",
        ">" = "Skipping TWI calculation"
      ))
    } else {
      # Get DEM
      dem <- layers$rasters[[dem_layer]]
      if (!dem$loaded) {
        dem$object <- terra::rast(dem$path)
      }

      # Calculate slope
      slope <- terra::terrain(dem$object, v = "slope", unit = "degrees")

      # Extract mean slope per unit
      mean_slope <- exactextractr::exact_extract(
        slope,
        units,
        fun = "mean",
        progress = FALSE
      )

      # Simplified TWI proxy: inverse of slope (flat areas = high wetness potential)
      # Add small constant to avoid division by zero
      twi_component <- 1 / (mean_slope + 0.1)

      # Normalize to 0-1 range
      twi_component <- (twi_component - min(twi_component, na.rm = TRUE)) /
        (max(twi_component, na.rm = TRUE) - min(twi_component, na.rm = TRUE))
    }
  }

  # Calculate proximity to water bodies
  if (calculate_proximity) {
    if (!water_layer %in% names(layers$vectors)) {
      cli::cli_warn(c(
        "!" = "Water layer {.field {water_layer}} not found",
        ">" = "Skipping proximity calculation"
      ))
    } else {
      # Get water layer
      water <- layers$vectors[[water_layer]]
      if (!water$loaded) {
        water$object <- sf::st_read(water$path, quiet = TRUE)
      }

      # Calculate distance to nearest water feature
      distances <- sf::st_distance(units, water$object)

      # Get minimum distance per unit
      min_distances <- apply(distances, 1, min)

      # Inverse distance weighting (closer = higher value)
      # Cap at max_distance
      proximity_component <- pmax(0, 1 - (as.numeric(min_distances) / max_distance))
    }
  }

  # Combine components
  if (calculate_twi && calculate_proximity) {
    water_indicator <- (twi_component * weights[1]) + (proximity_component * weights[2])
  } else if (calculate_twi) {
    water_indicator <- twi_component
  } else if (calculate_proximity) {
    water_indicator <- proximity_component
  } else {
    cli::cli_abort("At least one of {.code calculate_twi} or {.code calculate_proximity} must be TRUE")
  }

  # Return numeric vector
  as.numeric(water_indicator)
}

#' Calculate forest fragmentation indicator
#'
#' Quantifies forest fragmentation from land cover data.
#'
#' @param units A \code{nemeton_units} or \code{sf} object representing analysis units
#' @param layers A \code{nemeton_layers} object containing spatial data
#' @param landcover_layer Character. Name of land cover raster layer. Default "landcover".
#' @param forest_values Numeric vector. Raster values representing forest classes.
#'   Default NULL (auto-detect if possible).
#' @param metric Character. Fragmentation metric to calculate. Options: "forest_pct", "edge_density", "patch_count".
#'   Default "forest_pct".
#' @param ... Additional arguments (not used)
#'
#' @return Numeric vector of fragmentation indicator values
#'
#' @details
#' Fragmentation metrics:
#' \itemize{
#'   \item \strong{forest_pct}: Percentage of forest cover in each unit (simple metric)
#'   \item \strong{edge_density}: Ratio of forest edge to total forest area (higher = more fragmented)
#'   \item \strong{patch_count}: Number of distinct forest patches (higher = more fragmented)
#' }
#'
#' For MVP (v0.1.0), only forest_pct is implemented. Future versions will add
#' advanced landscape metrics using landscapemetrics package.
#'
#' @examples
#' \dontrun{
#' # Forest percentage
#' forest_pct <- indicator_fragmentation(
#'   units, layers,
#'   forest_values = c(1, 2, 3)
#' )
#' }
#'
#' @seealso \code{\link{nemeton_compute}}
#'
#' @export
indicator_fragmentation <- function(units,
                                    layers,
                                    landcover_layer = "landcover",
                                    forest_values = NULL,
                                    metric = c("forest_pct", "edge_density", "patch_count"),
                                    ...) {
  # Match metric argument
  metric <- match.arg(metric)

  # Validate inputs
  if (!inherits(units, "sf")) {
    cli::cli_abort("{.arg units} must be an {.cls sf} object")
  }

  if (!inherits(layers, "nemeton_layers")) {
    cli::cli_abort("{.arg layers} must be a {.cls nemeton_layers} object")
  }

  # Check if layer exists
  if (!landcover_layer %in% names(layers$rasters)) {
    cli::cli_abort(c(
      "!" = "Land cover layer {.field {landcover_layer}} not found",
      "i" = "Available rasters: {.field {names(layers$rasters)}}",
      ">" = "Specify layer with {.code landcover_layer = 'name'}"
    ))
  }

  # Get the raster layer
  layer <- layers$rasters[[landcover_layer]]

  # Load if not loaded
  if (!layer$loaded) {
    layer$object <- terra::rast(layer$path)
  }

  # MVP implementation: forest percentage only
  if (metric %in% c("edge_density", "patch_count")) {
    cli::cli_warn(c(
      "!" = "Metric {.field {metric}} not implemented in v0.1.0",
      "i" = "Available in v0.2.0+",
      ">" = "Using {.field forest_pct} instead"
    ))
    metric <- "forest_pct"
  }

  # Calculate forest percentage
  if (is.null(forest_values)) {
    cli::cli_abort(c(
      "!" = "{.arg forest_values} must be specified",
      "i" = "Provide numeric vector of raster values representing forest classes",
      ">" = "Example: {.code forest_values = c(1, 2, 3)}"
    ))
  }

  # Extract fraction of forest pixels
  # Use coverage_fraction from exactextractr for categorical rasters
  extracted <- exactextractr::exact_extract(
    layer$object,
    units,
    function(values, coverage_fraction) {
      # Calculate forest coverage
      forest_mask <- values %in% forest_values
      sum(coverage_fraction[forest_mask], na.rm = TRUE) / sum(coverage_fraction, na.rm = TRUE)
    },
    coverage_area = FALSE,
    progress = FALSE
  )

  # Convert to percentage (0-100)
  forest_pct <- extracted * 100

  # Return numeric vector
  as.numeric(forest_pct)
}

#' Calculate accessibility indicator
#'
#' Measures accessibility based on proximity to roads and trails.
#'
#' @param units A \code{nemeton_units} or \code{sf} object representing analysis units
#' @param layers A \code{nemeton_layers} object containing spatial data
#' @param roads_layer Character. Name of roads vector layer. Default "roads".
#' @param trails_layer Character. Name of trails vector layer. Default NULL (optional).
#' @param max_distance Numeric. Maximum distance to consider (meters). Default 5000.
#' @param road_weight Numeric. Weight for road proximity (0-1). Default 0.7.
#' @param trail_weight Numeric. Weight for trail proximity (0-1). Default 0.3.
#' @param invert Logical. If TRUE, higher values = less accessible (more remote). Default FALSE.
#' @param ... Additional arguments (not used)
#'
#' @return Numeric vector of accessibility indicator values
#'
#' @details
#' The accessibility indicator is based on proximity to transportation infrastructure:
#' \itemize{
#'   \item \strong{Roads}: Primary accessibility factor (default weight: 0.7)
#'   \item \strong{Trails}: Secondary accessibility factor (default weight: 0.3)
#' }
#'
#' If \code{invert = TRUE}, the indicator represents remoteness (useful for
#' wilderness/conservation contexts where low accessibility is desirable).
#'
#' @examples
#' \dontrun{
#' # Accessibility (higher = more accessible)
#' accessibility <- indicator_accessibility(units, layers)
#'
#' # Remoteness (higher = more remote)
#' remoteness <- indicator_accessibility(
#'   units, layers,
#'   invert = TRUE
#' )
#' }
#'
#' @seealso \code{\link{nemeton_compute}}
#'
#' @export
indicator_accessibility <- function(units,
                                    layers,
                                    roads_layer = "roads",
                                    trails_layer = NULL,
                                    max_distance = 5000,
                                    road_weight = 0.7,
                                    trail_weight = 0.3,
                                    invert = FALSE,
                                    ...) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    cli::cli_abort("{.arg units} must be an {.cls sf} object")
  }

  if (!inherits(layers, "nemeton_layers")) {
    cli::cli_abort("{.arg layers} must be a {.cls nemeton_layers} object")
  }

  # Initialize components
  n_units <- nrow(units)
  road_component <- rep(0, n_units)
  trail_component <- rep(0, n_units)

  # Calculate distance to roads
  if (!roads_layer %in% names(layers$vectors)) {
    cli::cli_warn(c(
      "!" = "Roads layer {.field {roads_layer}} not found",
      ">" = "Setting road accessibility to 0"
    ))
  } else {
    # Get roads layer
    roads <- layers$vectors[[roads_layer]]
    if (!roads$loaded) {
      roads$object <- sf::st_read(roads$path, quiet = TRUE)
    }

    # Calculate distance to nearest road
    distances <- sf::st_distance(units, roads$object)
    min_distances <- apply(distances, 1, min)

    # Inverse distance (closer = more accessible)
    road_component <- pmax(0, 1 - (as.numeric(min_distances) / max_distance))
  }

  # Calculate distance to trails (optional)
  if (!is.null(trails_layer)) {
    if (!trails_layer %in% names(layers$vectors)) {
      cli::cli_warn(c(
        "!" = "Trails layer {.field {trails_layer}} not found",
        ">" = "Skipping trail accessibility"
      ))
    } else {
      # Get trails layer
      trails <- layers$vectors[[trails_layer]]
      if (!trails$loaded) {
        trails$object <- sf::st_read(trails$path, quiet = TRUE)
      }

      # Calculate distance to nearest trail
      distances <- sf::st_distance(units, trails$object)
      min_distances <- apply(distances, 1, min)

      # Inverse distance
      trail_component <- pmax(0, 1 - (as.numeric(min_distances) / max_distance))
    }
  }

  # Combine components
  if (!is.null(trails_layer) && trails_layer %in% names(layers$vectors)) {
    accessibility <- (road_component * road_weight) + (trail_component * trail_weight)
  } else {
    # Roads only
    accessibility <- road_component
  }

  # Invert if remoteness indicator requested
  if (invert) {
    accessibility <- 1 - accessibility
  }

  # Return numeric vector
  as.numeric(accessibility)
}
