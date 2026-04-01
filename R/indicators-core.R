#' Calculate Nemeton indicators for spatial units
#'
#' Main function to compute biophysical indicators for forest units from spatial layers.
#' Orchestrates indicator calculation with automatic preprocessing and error handling.
#'
#' @param units A \code{nemeton_units} or \code{sf} object representing analysis units
#' @param layers A \code{nemeton_layers} object containing spatial data layers
#' @param indicators Character vector of indicator names to calculate, or "all" for all available.
#'   See \code{\link{list_indicators}} for available indicators from the 12-family framework.
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
#' \code{\link{list_indicators}} for available indicators in the 12-family framework
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

  # Get list of available indicators from the 12-family framework
  available_indicators <- list_indicators()

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
  # Le nom NMT de l'indicateur est aussi le nom de la fonction
  func_name <- indicator

  # Check if function exists
  if (!exists(func_name, mode = "function")) {
    stop("Unknown indicator: ", indicator,
         "\nAvailable indicators: ", paste(list_indicators(), collapse = ", "),
         call. = FALSE)
  }

  # Call the indicator function dynamically
  func <- get(func_name, mode = "function")
  result <- do.call(func, list(units = units, layers = layers, ...))

  # Risk indicator functions return sf objects with added columns (R1, R2, R3, R4)
  # Extract the indicator column as a numeric vector
  if (inherits(result, "sf")) {
    col_map <- c(
      indicateur_r1_feu = "R1", indicateur_r2_tempete = "R2",
      indicateur_r3_secheresse = "R3", indicateur_r4_abroutissement = "R4"
    )
    col_name <- col_map[indicator]
    if (!is.na(col_name) && col_name %in% names(result)) {
      return(result[[col_name]])
    }
    stop("Indicator function '", func_name, "' returned sf but column '",
         col_name, "' not found", call. = FALSE)
  }

  result
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

  # 12-family indicator framework (v0.4.0+)
  indicators <- data.frame(
    name = c(
      # C - Carbon/Energy (2)
      "indicateur_c1_biomasse", "indicateur_c2_ndvi",
      # W - Water (3)
      "indicateur_w1_reseau", "indicateur_w2_zones_humides", "indicateur_w3_humidite",
      # F - Soil Fertility (2)
      "soil_fertility", "soil_erosion",
      # L - Landscape (2)
      "indicateur_l2_fragmentation", "landscape_edge",
      # B - Biodiversity (3)
      "indicateur_b1_protection", "indicateur_b2_structure", "indicateur_b3_connectivite",
      # R - Risk/Resilience (4)
      "indicateur_r1_feu", "indicateur_r2_tempete", "indicateur_r3_secheresse", "indicateur_r4_abroutissement",
      # T - Temporal (2)
      "indicateur_t1_anciennete", "indicateur_t2_changement",
      # A - Air/Microclimate (2)
      "air_coverage", "indicateur_a2_qualite_air",
      # S - Social (3)
      "indicateur_s1_routes", "indicateur_s2_bati", "social_proximity",
      # P - Productive (3)
      "productive_volume", "productive_quality", "productive_station",
      # E - Energy (2)
      "energy_fuelwood", "energy_avoidance",
      # N - Naturalness (3)
      "indicateur_n1_distance", "indicateur_n2_continuite", "naturalness_composite"
    ),
    family = c(
      "C", "C",
      "W", "W", "W",
      "F", "F",
      "L", "L",
      "B", "B", "B",
      "R", "R", "R", "R",
      "T", "T",
      "A", "A",
      "S", "S", "S",
      "P", "P", "P",
      "E", "E",
      "N", "N", "N"
    ),
    category = c(
      "biophysical", "biophysical",
      "biophysical", "biophysical", "biophysical",
      "biophysical", "biophysical",
      "landscape", "landscape",
      "biophysical", "biophysical", "biophysical",
      "risk", "risk", "risk", "risk",
      "temporal", "temporal",
      "biophysical", "biophysical",
      "social", "social", "social",
      "productive", "productive", "productive",
      "energy", "energy",
      "naturalness", "naturalness", "naturalness"
    ),
    description = c(
      "Carbon stock via biomass allometric models (C1)",
      "Vegetation vitality via NDVI (C2)",
      "Water regulation via stream network (W1)",
      "Water regulation via wetlands (W2)",
      "Water regulation via Topographic Wetness Index (W3)",
      "Soil fertility assessment (F1)",
      "Soil erosion risk (F2)",
      "Forest fragmentation metrics (L1)",
      "Edge density and quality (L2)",
      "Biodiversity protection status (B1)",
      "Structural diversity (B2)",
      "Habitat connectivity (B3)",
      "Fire risk assessment (R1)",
      "Storm vulnerability (R2)",
      "Drought risk (R3)",
      "Browsing pressure (R4)",
      "Stand age and maturity (T1)",
      "Temporal change detection (T2)",
      "Air quality regulation via canopy coverage (A1)",
      "Air quality improvement potential (A2)",
      "Trail network accessibility (S1)",
      "General accessibility (S2)",
      "Proximity to population centers (S3)",
      "Timber volume production (P1)",
      "Wood quality (P2)",
      "Site productivity (P3)",
      "Fuelwood energy potential (E1)",
      "Fossil fuel avoidance via carbon sequestration (E2)",
      "Distance to natural reference (N1)",
      "Ecological continuity (N2)",
      "Composite naturalness index (N3)"
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
