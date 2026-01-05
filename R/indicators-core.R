#' Calculate Nemeton indicators for spatial units
#'
#' Main function to compute biophysical indicators for forest units from spatial layers.
#' Orchestrates indicator calculation with automatic preprocessing and error handling.
#'
#' @param units A \code{nemeton_units} or \code{sf} object representing analysis units
#' @param layers A \code{nemeton_layers} object containing spatial data layers
#' @param indicators Character vector of indicator names to calculate, or "all" for all available.
#'   Available indicators: "carbon", "biodiversity", "water", "fragmentation", "accessibility"
#' @param preprocess Logical. Automatically harmonize CRS and crop layers? Default TRUE.
#' @param parallel Logical. Use parallel computation? (Not implemented in MVP, will error if TRUE)
#' @param progress Logical. Show progress bar? Default TRUE.
#' @param ... Additional arguments passed to indicator functions
#'
#' @return An \code{sf} object with original columns plus one column per calculated indicator
#'
#' @details
#' The function performs the following steps:
#' \enumerate{
#'   \item Validates inputs (units and layers)
#'   \item If \code{preprocess = TRUE}:
#'     \itemize{
#'       \item Reprojects layers to units CRS
#'       \item Crops layers to units extent
#'     }
#'   \item For each indicator:
#'     \itemize{
#'       \item Calls corresponding \code{indicator_*()} function
#'       \item Handles errors gracefully (warning + NA column)
#'       \item Updates metadata
#'     }
#'   \item Returns enriched sf object
#' }
#'
#' If an indicator calculation fails, a warning is issued and the indicator column
#' is filled with NA, but computation continues for other indicators.
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#'
#' # Create units
#' units <- nemeton_units(sf::st_read("parcels.gpkg"))
#'
#' # Create layer catalog
#' layers <- nemeton_layers(
#'   rasters = list(
#'     biomass = "biomass.tif",
#'     dem = "dem.tif"
#'   ),
#'   vectors = list(
#'     roads = "roads.gpkg"
#'   )
#' )
#'
#' # Calculate all indicators
#' results <- nemeton_compute(units, layers)
#'
#' # Calculate specific indicators
#' results <- nemeton_compute(
#'   units, layers,
#'   indicators = c("carbon", "biodiversity")
#' )
#' }
#'
#' @seealso
#' \code{\link{indicator_carbon}}, \code{\link{indicator_biodiversity}},
#' \code{\link{indicator_water}}, \code{\link{indicator_fragmentation}},
#' \code{\link{indicator_accessibility}}
#'
#' @export
nemeton_compute <- function(units,
                            layers,
                            indicators = "all",
                            preprocess = TRUE,
                            parallel = FALSE,
                            progress = TRUE,
                            ...) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    cli::cli_abort("{.arg units} must be an {.cls sf} or {.cls nemeton_units} object")
  }

  if (!inherits(layers, "nemeton_layers")) {
    cli::cli_abort("{.arg layers} must be a {.cls nemeton_layers} object")
  }

  # Check parallel (not implemented in MVP)
  if (parallel) {
    cli::cli_abort(c(
      "!" = "Parallel computing not implemented in v0.1.0",
      "i" = "Available in v0.4.0+",
      ">" = "Set {.code parallel = FALSE}"
    ))
  }

  # Get list of available indicators
  available_indicators <- c(
    "carbon",
    "biodiversity",
    "water",
    "fragmentation",
    "accessibility"
  )

  # Handle "all"
  if (length(indicators) == 1 && indicators[1] == "all") {
    indicators <- available_indicators
  }

  # Validate indicator names
  unknown <- setdiff(indicators, available_indicators)
  if (length(unknown) > 0) {
    n_unknown <- length(unknown)
    cli::cli_warn(c(
      "!" = "Unknown indicator{cli::qty(n_unknown)}{?s}: {.field {unknown}}",
      "i" = "Available: {.field {available_indicators}}",
      ">" = "Skipping unknown indicator{cli::qty(n_unknown)}{?s}"
    ))
    indicators <- intersect(indicators, available_indicators)
  }

  if (length(indicators) == 0) {
    msg_error("indicator_no_valid")
  }

  # Preprocessing
  if (preprocess) {
    msg_info("preprocess_start")
    msg_info("preprocess_harmonizing")

    # Harmonize CRS
    target_crs <- sf::st_crs(units)
    layers <- harmonize_crs(layers, target_crs, verbose = TRUE)

    # Crop to extent
    layers <- crop_to_units(layers, units, buffer = 0)
  }

  # Initialize result as copy of units
  results <- units

  # Store original metadata if exists
  orig_metadata <- attr(units, "metadata")

  # Calculate each indicator
  n_indicators <- length(indicators)
  msg_info("indicator_computing", n_indicators)

  computed_indicators <- character()
  layers_used <- character()

  for (ind in indicators) {
    if (progress) {
      msg_info("indicator_calculated", ind)
    }

    tryCatch(
      {
        # Dispatch to appropriate indicator function
        values <- compute_indicator(ind, units, layers, ...)

        # Add to results
        results[[ind]] <- values

        computed_indicators <- c(computed_indicators, ind)
      },
      error = function(e) {
        msg_warn("indicator_failed", ind)
        msg_info("indicator_set_na", ind)
        results[[ind]] <<- rep(NA_real_, nrow(results))
      }
    )
  }

  # Update metadata
  new_metadata <- c(
    orig_metadata,
    list(
      computed_at = Sys.time(),
      indicators_computed = computed_indicators,
      layers_used = names(c(layers$rasters, layers$vectors))
    )
  )

  attr(results, "metadata") <- new_metadata

  n_computed <- length(computed_indicators)
  n_total <- length(indicators)
  msg_success("indicator_computed", n_computed, n_total)

  results
}

#' Dispatch indicator calculation to appropriate function
#'
#' Internal function that routes indicator name to corresponding calculation function.
#'
#' @param indicator Character. Name of indicator
#' @param units Spatial units
#' @param layers Layer catalog
#' @param ... Additional arguments
#'
#' @return Numeric vector of indicator values
#' @keywords internal
#' @noRd
compute_indicator <- function(indicator, units, layers, ...) {
  switch(indicator,
    carbon = indicator_carbon(units, layers, ...),
    biodiversity = indicator_biodiversity(units, layers, ...),
    water = indicator_water(units, layers, ...),
    fragmentation = indicator_fragmentation(units, layers, ...),
    accessibility = indicator_accessibility(units, layers, ...),
    stop("Unknown indicator: ", indicator)
  )
}

#' List available indicators
#'
#' Returns a character vector of available indicator names.
#'
#' @param category Character. Filter by category: "all", "biophysical", "social", "landscape".
#'   Default "all".
#' @param return_type Character. Return "names" (default) or "details" (data.frame with descriptions)
#'
#' @return Character vector of indicator names or data.frame with details
#'
#' @examples
#' \dontrun{
#' # Get all indicator names
#' list_indicators()
#'
#' # Get details
#' list_indicators(return_type = "details")
#' }
#'
#' @export
list_indicators <- function(category = "all", return_type = c("names", "details")) {
  return_type <- match.arg(return_type)

  indicators <- data.frame(
    name = c("carbon", "biodiversity", "water", "fragmentation", "accessibility"),
    category = c("biophysical", "biophysical", "biophysical", "landscape", "social"),
    description = c(
      "Carbon stock (above-ground biomass)",
      "Biodiversity indices (Shannon, richness, Simpson)",
      "Water regulation (TWI, proximity to waterbodies)",
      "Forest fragmentation (patch count, connectivity)",
      "Accessibility (distance to roads/trails)"
    ),
    stringsAsFactors = FALSE
  )

  # Filter by category
  if (category != "all") {
    indicators <- indicators[indicators$category == category, ]
  }

  if (return_type == "names") {
    return(indicators$name)
  } else {
    return(indicators)
  }
}
