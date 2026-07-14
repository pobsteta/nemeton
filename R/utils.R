# ==============================================================================
# Smart Parallel Mapping - Adaptive threshold for furrr/purrr
# ==============================================================================

#' Complexity-based thresholds for smart_map
#'
#' Predefined thresholds based on operation complexity.
#' Based on benchmarks: furrr setup overhead is ~15-18 seconds.
#'
#' @format Named list with threshold values
#' @keywords internal
#' @noRd
.smart_map_thresholds <- list(
  # Very fast operations (1-5ms): almost never use parallel
  very_low = 2000L,
  # Fast operations (5-20ms): raster extraction, simple geometry
 low = 1000L,
 # Medium operations (20-100ms): spatial intersections, buffers
  medium = 200L,
  # Slow operations (100-500ms): WFS queries, complex spatial
  high = 50L,
  # Very slow operations (500ms-5s): API calls, downloads
  very_high = 20L
)

#' Smart Map with Adaptive Parallelization
#'
#' Applies a function over elements with automatic decision between sequential
#' and parallel execution based on input size and operation complexity.
#' Avoids the overhead of parallel processing for small datasets where it
#' would be counterproductive.
#'
#' @param x A list or vector to iterate over.
#' @param fn Function to apply to each element.
#' @param ... Additional arguments passed to `fn`.
#' @param complexity Character. Operation complexity level that determines
#'   the threshold automatically:
#'   \itemize{
#'     \item `"very_low"`: ~1-5ms/op (threshold=2000) - instant calculations
#'     \item `"low"`: ~5-20ms/op (threshold=1000) - raster extraction
#'     \item `"medium"`: ~20-100ms/op (threshold=200) - spatial intersections
#'     \item `"high"`: ~100-500ms/op (threshold=50) - WFS queries
#'     \item `"very_high"`: ~500ms-5s/op (threshold=20) - API calls, downloads
#'   }
#'   Default is `"medium"`. Ignored if `threshold` is explicitly set.
#' @param threshold Integer or NULL. Explicit minimum number of elements to
#'   trigger parallel execution. If NULL (default), uses value from `complexity`.
#' @param workers Integer. Number of parallel workers. Default is
#'   `min(4, parallel::detectCores() - 1)`.
#' @param progress Logical. Show progress bar? Default TRUE for n > 50.
#' @param .type Character. Return type: "list" (default), "dbl", "chr", "lgl", "int".
#'   Determines the output format and uses appropriate map variant.
#'
#' @return A list or vector (depending on `.type`) of results.
#'
#' @details
#' The function implements a three-tier strategy:
#' \enumerate{
#'   \item If n <= threshold OR furrr not available: use purrr (or base lapply)
#'   \item If n > threshold AND furrr available: use furrr with parallel plan
#'   \item Falls back gracefully to base R if neither purrr nor furrr available
#' }
#'
#' The `complexity` parameter is based on benchmarks showing that furrr has
#' a setup overhead of ~15-18 seconds. Parallelization is only beneficial when:
#' `n * time_per_op * (1 - 1/workers) > overhead`
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Using complexity parameter (recommended)
#' results <- smart_map(parcels, extract_raster, complexity = "low")
#' results <- smart_map(parcels, query_wfs, complexity = "high")
#' results <- smart_map(urls, download_file, complexity = "very_high")
#'
#' # Using explicit threshold
#' results <- smart_map(1:500, complex_function, threshold = 100)
#'
#' # Return numeric vector
#' values <- smart_map(parcels_list, extract_value, .type = "dbl")
#' }
smart_map <- function(x,
                      fn,
                      ...,
                      complexity = "medium",
                      threshold = NULL,
                      workers = NULL,
                      progress = NULL,
                      .type = "list") {
  n <- length(x)

  # Resolve threshold from complexity if not explicitly set
 if (is.null(threshold)) {
    valid_complexities <- names(.smart_map_thresholds)
    if (!complexity %in% valid_complexities) {
      cli::cli_abort(c(
        "Invalid {.arg complexity} value: {.val {complexity}}",
        "i" = "Must be one of: {.val {valid_complexities}}"
      ))
    }
    threshold <- .smart_map_thresholds[[complexity]]
  }

  # Default workers
  if (is.null(workers)) {
    workers <- min(4L, max(1L, parallel::detectCores() - 1L))
  }

  # Default progress (show for n > 50)
  if (is.null(progress)) {
    progress <- n > 50
  }

  # Check package availability
  has_furrr <- requireNamespace("furrr", quietly = TRUE) &&
    requireNamespace("future", quietly = TRUE)
  has_purrr <- requireNamespace("purrr", quietly = TRUE)

  # Decision: parallel only if above threshold AND furrr available
  use_parallel <- n > threshold && has_furrr

  # Select map function based on type
  map_fn <- switch(.type,
    "dbl" = if (has_purrr) purrr::map_dbl else function(x, f, ...) vapply(x, f, numeric(1), ...),
    "chr" = if (has_purrr) purrr::map_chr else function(x, f, ...) vapply(x, f, character(1), ...),
    "lgl" = if (has_purrr) purrr::map_lgl else function(x, f, ...) vapply(x, f, logical(1), ...),
    "int" = if (has_purrr) purrr::map_int else function(x, f, ...) vapply(x, f, integer(1), ...),
    if (has_purrr) purrr::map else lapply
  )

  # Select parallel map function based on type
  future_map_fn <- if (has_furrr) {
    switch(.type,
      "dbl" = furrr::future_map_dbl,
      "chr" = furrr::future_map_chr,
      "lgl" = furrr::future_map_lgl,
      "int" = furrr::future_map_int,
      furrr::future_map
    )
  } else {
    NULL
  }

  # Execute
  if (use_parallel) {
    # Check if a parallel plan is already active (avoid recreating workers)
    current_plan <- future::plan()
    already_parallel <- inherits(current_plan, "multisession") ||
      inherits(current_plan, "multicore") ||
      inherits(current_plan, "cluster")

    if (already_parallel) {
      # Reuse existing parallel plan - no overhead!
      plan_name <- intersect(class(current_plan), c("multisession", "multicore", "cluster"))[1]
      cli::cli_alert_info("Parallel mode: {n} elements (reusing {plan_name})")
    } else {
      # Create new parallel plan (will be cleaned up on exit)
      old_plan <- current_plan
      on.exit(future::plan(old_plan), add = TRUE)
      future::plan(future::multisession, workers = workers)
      cli::cli_alert_info("Parallel mode: {n} elements, {workers} workers (new plan)")
    }

    result <- future_map_fn(x, fn, ..., .progress = progress)
  } else {
    mode_msg <- if (n <= threshold) {
      "Sequential mode: {n} elements (below threshold {threshold})"
    } else {
      "Sequential mode: {n} elements (furrr not available)"
    }
    cli::cli_alert_info(mode_msg)

    # Use progress wrapper if requested and cli available
    if (progress && has_purrr && requireNamespace("cli", quietly = TRUE)) {
      result <- purrr::map(x, function(xi) {
        fn(xi, ...)
      }, .progress = TRUE)
      # Convert if needed
      if (.type != "list") {
        result <- switch(.type,
          "dbl" = as.numeric(unlist(result)),
          "chr" = as.character(unlist(result)),
          "lgl" = as.logical(unlist(result)),
          "int" = as.integer(unlist(result)),
          result
        )
      }
    } else {
      result <- map_fn(x, fn, ...)
    }
  }

  result
}

#' Smart Map for Spatial Data with Row Indices
#'
#' Convenience wrapper for spatial operations where the function operates on
#' row indices of an sf object. Automatically passes the sf object to each
#' worker in parallel mode.
#'
#' @param sf_data An sf object.
#' @param fn Function that takes (index, sf_data) and returns a value.
#' @param ... Additional arguments passed to `fn`.
#' @param complexity Character. Operation complexity level:
#'   `"very_low"`, `"low"`, `"medium"` (default), `"high"`, `"very_high"`.
#'   See [smart_map()] for details.
#' @param threshold Integer or NULL. Explicit threshold. If NULL, uses `complexity`.
#' @param workers Integer. Number of workers. Default auto-detected.
#' @param progress Logical. Show progress? Default TRUE for n > 50.
#' @param .type Character. Return type: "list", "dbl", "chr", "lgl", "int".
#'
#' @return A list or vector of results.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Calculate indicator for each parcel (medium complexity = spatial ops)
#' parcelles$indicator <- smart_map_sf(parcelles, function(i, data) {
#'   geom <- sf::st_geometry(data[i, ])
#'   # ... spatial calculation ...
#'   return(value)
#' }, complexity = "medium", .type = "dbl")
#'
#' # WFS query per parcel (high complexity)
#' parcelles$zones <- smart_map_sf(parcelles, function(i, data) {
#'   query_wfs(data[i, ])
#' }, complexity = "high")
#' }
smart_map_sf <- function(sf_data,
                         fn,
                         ...,
                         complexity = "medium",
                         threshold = NULL,
                         workers = NULL,
                         progress = NULL,
                         .type = "list") {
  if (!inherits(sf_data, "sf")) {
    cli::cli_abort("{.arg sf_data} must be an {.cls sf} object")
  }

  n <- nrow(sf_data)
  indices <- seq_len(n)

  # Wrapper to inject sf_data
  fn_wrapper <- function(i) {
    fn(i, sf_data, ...)
  }

  smart_map(
    x = indices,
    fn = fn_wrapper,
    complexity = complexity,
    threshold = threshold,
    workers = workers,
    progress = progress,
    .type = .type
  )
}

# ==============================================================================
# Original utils.R content
# ==============================================================================

#' Check CRS compatibility between spatial objects
#'
#' @param x First spatial object (sf or SpatRaster)
#' @param y Second spatial object (sf or SpatRaster)
#' @param strict Logical. If TRUE, CRS must be identical. If FALSE, check only if defined.
#'
#' @return Invisible TRUE if compatible, otherwise stops with error
#' @keywords internal
#' @noRd
check_crs <- function(x, y, strict = FALSE) {
  crs_x <- get_crs(x)
  crs_y <- get_crs(y)

  # Check if CRS are defined
  if (is.na(crs_x)) {
    cli::cli_abort("First object has undefined CRS")
  }
  if (is.na(crs_y)) {
    cli::cli_abort("Second object has undefined CRS")
  }

  # Check compatibility
  if (strict && !sf::st_crs(crs_x) == sf::st_crs(crs_y)) {
    cli::cli_abort(c(
      "!" = "CRS mismatch",
      "i" = "First object: {format(sf::st_crs(crs_x)$input)}",
      "i" = "Second object: {format(sf::st_crs(crs_y)$input)}",
      ">" = "Set {.code preprocess = TRUE} to harmonize automatically"
    ))
  }

  invisible(TRUE)
}

#' Get CRS from various spatial objects
#'
#' @param x Spatial object (sf, sfc, or SpatRaster)
#' @return CRS object
#' @keywords internal
#' @noRd
get_crs <- function(x) {
  if (inherits(x, "sf") || inherits(x, "sfc")) {
    sf::st_crs(x)
  } else if (inherits(x, "SpatRaster")) {
    terra::crs(x, describe = TRUE)$code
  } else {
    NA
  }
}

#' Validate sf object
#'
#' @param x Object to validate
#' @param require_crs Logical. Must CRS be defined?
#' @param require_valid Logical. Must geometries be valid?
#'
#' @return Invisible TRUE if valid, otherwise stops with error
#' @keywords internal
#' @noRd
validate_sf <- function(x, require_crs = TRUE, require_valid = TRUE) {
  # Check if sf
  if (!inherits(x, "sf")) {
    cli::cli_abort("{.arg x} must be an {.cls sf} object")
  }

  # Check CRS
  if (require_crs && is.na(sf::st_crs(x))) {
    cli::cli_abort("{.arg x} must have a defined CRS")
  }

  # Check valid geometries
  if (require_valid) {
    valid <- sf::st_is_valid(x)
    if (any(!valid, na.rm = TRUE)) {
      n_invalid <- sum(!valid, na.rm = TRUE)
      cli::cli_abort(c(
        "!" = "Found {n_invalid} invalid geometr{?y/ies}",
        ">" = "Fix with {.code sf::st_make_valid()}"
      ))
    }
  }

  # Check empty geometries
  empty <- sf::st_is_empty(x)
  if (any(empty, na.rm = TRUE)) {
    n_empty <- sum(empty, na.rm = TRUE)
    cli::cli_abort(c(
      "!" = "Found {n_empty} empty geometr{?y/ies}",
      ">" = "Remove with {.code dplyr::filter(!sf::st_is_empty(.))}"
    ))
  }

  # Check geometry type
  geom_types <- unique(sf::st_geometry_type(x))
  if (!all(geom_types %in% c("POLYGON", "MULTIPOLYGON"))) {
    cli::cli_abort(c(
      "!" = "Geometry must be POLYGON or MULTIPOLYGON",
      "i" = "Found: {paste(geom_types, collapse = ', ')}"
    ))
  }

  invisible(TRUE)
}

#' Formatted message helper using cli
#'
#' @param ... Message components passed to cli::cli_alert_info()
#'
#' @return NULL (called for side effect)
#' @keywords internal
#' @noRd
message_nemeton <- function(...) {
  # Format message with glue interpolation, handling cli syntax gracefully
  msg_raw <- paste0(...)
  # Try glue interpolation first
  msg <- tryCatch(
    {
      glue::glue(msg_raw, .envir = parent.frame())
    },
    error = function(e) {
      # If glue fails (e.g., cli syntax), just use the raw message
      msg_raw
    }
  )
  cat(msg, "\n", sep = "")
}

#' Generate unique IDs for units
#'
#' @param n Number of IDs to generate
#' @param prefix Prefix for IDs
#'
#' @return Character vector of IDs
#' @keywords internal
#' @noRd
generate_ids <- function(n, prefix = "unit_") {
  sprintf(paste0(prefix, "%03d"), seq_len(n))
}

#' Strip nemeton_units class and return pure sf object
#'
#' This is needed for compatibility with packages that use S3 method dispatch
#' on sf objects (e.g., exactextractr). The nemeton_units class can interfere
#' with method resolution.
#'
#' @param x nemeton_units or sf object
#' @return Pure sf object without nemeton_units class
#' @keywords internal
#' @noRd
as_pure_sf <- function(x, raster = NULL) {
  x_sf <- sf::st_as_sf(x)
  class(x_sf) <- setdiff(class(x_sf), "nemeton_units")
  # If a raster is provided, reproject polygons to match its CRS
  # to avoid "Polygons transformed to raster CRS" warnings from exact_extract
  if (!is.null(raster) && inherits(raster, "SpatRaster")) {
    raster_crs <- sf::st_crs(terra::crs(raster))
    if (!is.na(raster_crs) && sf::st_crs(x_sf) != raster_crs) {
      x_sf <- sf::st_transform(x_sf, raster_crs)
    }
  }
  x_sf
}


#' Extract raster values for polygons with automatic CRS alignment
#'
#' Wrapper around exactextractr::exact_extract that transforms polygons
#' to the raster CRS to avoid "Polygons transformed to raster CRS" warnings.
#'
#' @param raster SpatRaster.
#' @param polygons sf object.
#' @param ... Additional arguments passed to exact_extract.
#' @return Result of exact_extract.
#' @keywords internal
#' @noRd
safe_extract <- function(raster, polygons, ...) {
  poly_sf <- as_pure_sf(polygons)
  raster_crs <- sf::st_crs(terra::crs(raster))
  if (!is.na(raster_crs) && sf::st_crs(poly_sf) != raster_crs) {
    poly_sf <- sf::st_transform(poly_sf, raster_crs)
  }
  exactextractr::exact_extract(raster, poly_sf, ...)
}


#' Resolve a raster layer from a nemeton_layers object
#'
#' Extracts a SpatRaster from a lazy-load list structure (with path/object/loaded
#' fields) or returns the object directly if it is already a SpatRaster.
#'
#' @param layers A nemeton_layers object.
#' @param name Character. Name of the raster layer to resolve.
#' @return A SpatRaster or NULL if the layer is not available.
#' @keywords internal
#' @noRd
resolve_raster_layer <- function(layers, name) {
  if (!inherits(layers, "nemeton_layers")) return(NULL)
  if (!name %in% names(layers$rasters)) return(NULL)

  entry <- layers$rasters[[name]]
  if (is.null(entry)) return(NULL)

  # Already a SpatRaster

  if (inherits(entry, "SpatRaster")) return(entry)

  # Lazy-load list: check for object first, then load from path

  if (is.list(entry)) {
    obj <- entry$object
    if (!is.null(obj) && inherits(obj, "SpatRaster")) return(obj)
    path <- entry$path
    if (!is.null(path) && nzchar(path) && file.exists(path)) {
      return(terra::rast(path))
    }
  }

  NULL
}

#' Resolve a vector layer from a nemeton_layers object
#'
#' Extracts an sf object from a lazy-load list structure (with path/object/loaded
#' fields) or returns the object directly if it is already an sf object.
#'
#' @param layers A nemeton_layers object.
#' @param name Character. Name of the vector layer to resolve.
#' @return An sf object or NULL if the layer is not available.
#' @keywords internal
#' @noRd
resolve_vector_layer <- function(layers, name) {
  if (!inherits(layers, "nemeton_layers")) return(NULL)
  if (!name %in% names(layers$vectors)) return(NULL)

  entry <- layers$vectors[[name]]
  if (is.null(entry)) return(NULL)

  # Already an sf object
  if (inherits(entry, "sf")) return(entry)

  # Lazy-load list: check for object first, then load from path
  if (is.list(entry)) {
    obj <- entry$object
    if (!is.null(obj) && inherits(obj, "sf")) return(obj)
    path <- entry$path
    if (!is.null(path) && nzchar(path) && file.exists(path)) {
      return(sf::st_read(path, quiet = TRUE))
    }
  }

  NULL
}

#' Get best available DEM raster from layers
#'
#' Returns the LiDAR HD MNT (1m resolution) if available, otherwise falls back
#' to the BD ALTI DEM (25m resolution).
#'
#' @param layers A nemeton_layers object.
#' @return A SpatRaster or NULL if no DEM is available.
#' @keywords internal
#' @noRd
get_dem_raster <- function(layers) {
  if (!inherits(layers, "nemeton_layers")) return(NULL)
  # Prefer LiDAR HD MNT (1m) over BD ALTI DEM (25m)
  dem <- resolve_raster_layer(layers, "lidar_mnt")
  if (is.null(dem)) {
    dem <- resolve_raster_layer(layers, "dem")
  }
  # Répare un CRS LiDAR HD « sans autorité » (cf. .normalize_crs) : sinon les
  # extractions DEM (R1/R2/R3/W3) et le contrôle de couverture bbox échouent.
  .normalize_crs(dem)
}

# ==============================================================================
# v0.2.0 HELPERS - Allometric Models & Family Management
# ==============================================================================

#' Get Allometric Coefficients for Species
#'
#' Retrieves allometric equation coefficients from internal lookup table
#' (allometric_models from R/sysdata.rda).
#'
#' @param species Character. Species name (e.g., "Quercus", "Fagus", "Pinus",
#'   "Abies"). If not found, returns "Generic" equation.
#'
#' @return List with components: a, b, c (coefficients), source, citation
#' @keywords internal
#' @noRd
get_allometric_coefficients <- function(species) {
  # Access internal package data (created in data-raw/allometric_models.R)
  models <- allometric_models

  # Match species (case-insensitive)
  idx <- match(tolower(species), tolower(models$species))

  # Fallback to Generic if not found
  if (is.na(idx)) {
    idx <- which(models$species == "Generic")
    if (length(idx) == 0) {
      stop("Allometric models data missing - reinstall package")
    }
  }

  # Return coefficients as list
  list(
    a = models$a[idx],
    b = models$b[idx],
    c = models$c[idx],
    source = models$source[idx],
    citation = models$citation[idx]
  )
}

#' Calculate Biomass Using Allometric Equation
#'
#' Applies species-specific allometric equation: Biomass = a * Age^b * Density^c
#'
#' @param species Character vector. Species names
#' @param age Numeric vector. Stand age (years)
#' @param density Numeric vector. Stand density (0-1 scale)
#'
#' @return Numeric vector of biomass (tC/ha)
#' @keywords internal
#' @noRd
calculate_allometric_biomass <- function(species, age, density) {
  # Vectorized calculation
  biomass <- numeric(length(species))

  for (i in seq_along(species)) {
    # Check for NA inputs
    if (is.na(species[i]) || is.na(age[i]) || is.na(density[i])) {
      biomass[i] <- NA_real_
      next
    }

    coef <- get_allometric_coefficients(species[i])
    biomass[i] <- coef$a * (age[i]^coef$b) * (density[i]^coef$c)
  }

  biomass
}

#' Detect Indicator Family from Column Name
#'
#' Extracts family code from indicator column name (e.g., "C1" -> "C",
#' "W3_norm" -> "W").
#'
#' @param indicator_name Character. Indicator column name
#'
#' @return Character. Family code (single letter) or NA if not recognized
#' @keywords internal
#' @noRd
detect_indicator_family <- function(indicator_name) {
  # Extract first character if followed by digit
  if (grepl("^[A-Z][0-9]", indicator_name)) {
    return(substr(indicator_name, 1, 1))
  }
  NA_character_
}

#' Get Family Name from Code
#'
# get_family_name() moved to R/family-system.R (now supports bilingual names)

# ==============================================================================
# v0.3.0 HELPERS - Species Lookups & Shannon Diversity
# ==============================================================================

#' Get Species Flammability Score
#'
#' Retrieves fire risk flammability score from internal lookup table
#' (species_flammability_lookup from R/sysdata.rda).
#'
#' @param species Character. Species name (e.g., "Pinus", "Quercus", "Fagus").
#'   If not found, returns medium flammability (50).
#'
#' @return Numeric. Flammability score (0-100): High=80, Medium=50, Low=20
#' @keywords internal
#' @noRd
get_species_flammability <- function(species) {
  # Access internal package data (created in data-raw/create_sysdata.R)
  lookup <- species_flammability_lookup

  # Vectorized lookup
  scores <- numeric(length(species))

  for (i in seq_along(species)) {
    if (is.na(species[i])) {
      scores[i] <- NA_real_
      next
    }

    # Match species (case-insensitive, partial matching)
    idx <- which(tolower(lookup$species) == tolower(species[i]))

    # If not found, try partial match
    if (length(idx) == 0) {
      idx <- grep(tolower(species[i]), tolower(lookup$species), fixed = TRUE)
    }

    # Return score or default to medium (50)
    if (length(idx) > 0) {
      scores[i] <- lookup$flammability_score[idx[1]]
    } else {
      scores[i] <- 50 # Default: medium flammability
    }
  }

  scores
}

#' Get Species Drought Sensitivity Score
#'
#' Retrieves drought stress sensitivity score from internal lookup table
#' (species_drought_sensitivity from R/sysdata.rda).
#'
#' @param species Character. Species name (e.g., "Fagus", "Quercus", "Pinus").
#'   If not found, returns intermediate sensitivity (50).
#'
#' @return Numeric. Drought sensitivity (0-100): High=80, Intermediate=50, Low=20
#' @keywords internal
#' @noRd
get_species_drought_sensitivity <- function(species) {
  # Access internal package data
  lookup <- species_drought_sensitivity

  # Vectorized lookup
  scores <- numeric(length(species))

  for (i in seq_along(species)) {
    if (is.na(species[i])) {
      scores[i] <- NA_real_
      next
    }

    # Match species (case-insensitive, partial matching)
    idx <- which(tolower(lookup$species) == tolower(species[i]))

    # If not found, try partial match
    if (length(idx) == 0) {
      idx <- grep(tolower(species[i]), tolower(lookup$species), fixed = TRUE)
    }

    # Return score or default to intermediate (50)
    if (length(idx) > 0) {
      scores[i] <- lookup$drought_sensitivity[idx[1]]
    } else {
      scores[i] <- 50 # Default: intermediate sensitivity
    }
  }

  scores
}

#' Get Species Palatability for Browsing
#'
#' Returns palatability scores indicating how attractive species are to
#' ungulate browsers (deer, wild boar). Used for R4 (browsing pressure) indicator.
#'
#' @param species Character vector. Species names to look up.
#'
#' @return Numeric vector. Palatability scores (0-100).
#'   Higher = more palatable = higher browsing risk.
#'
#' @details
#' Palatability scores based on forestry literature:
#' \itemize{
#'   \item Very high (80-100): Quercus (oak), Abies (fir), Acer (maple), Fraxinus (ash)
#'   \item High (60-80): Fagus (beech), Carpinus (hornbeam), Prunus, Sorbus
#'   \item Medium (40-60): Betula (birch), Populus (poplar), Salix (willow)
#'   \item Low (20-40): Pinus (pine), Larix (larch)
#'   \item Very low (0-20): Picea (spruce), Robinia
#' }
#'
#' @keywords internal
#' @noRd
get_species_palatability <- function(species) {
  # Palatability lookup table (0-100 scale)
  # Based on: ONF technical guides, CNPF browsing studies
  lookup <- data.frame(
    species = c(
      # Very high palatability (80-100)
      "quercus", "chene", "oak",
      "abies", "sapin", "fir",
      "acer", "erable", "maple",
      "fraxinus", "frene", "ash",
      "castanea", "chataignier", "chestnut",
      # High palatability (60-80)
      "fagus", "hetre", "beech",
      "carpinus", "charme", "hornbeam",
      "prunus", "merisier", "cerisier", "cherry",
      "sorbus", "alisier", "sorbier",
      "tilia", "tilleul", "lime",
      # Medium palatability (40-60)
      "betula", "bouleau", "birch",
      "populus", "peuplier", "poplar",
      "salix", "saule", "willow",
      "alnus", "aulne", "alder",
      # Low palatability (20-40)
      "pinus", "pin", "pine",
      "larix", "meleze", "larch",
      "pseudotsuga", "douglas",
      # Very low palatability (0-20)
      "picea", "epicea", "spruce",
      "robinia", "robinier", "acacia"
    ),
    palatability = c(
      # Very high
      90, 90, 90,
      85, 85, 85,
      88, 88, 88,
      85, 85, 85,
      80, 80, 80,
      # High
      70, 70, 70,
      72, 72, 72,
      75, 75, 75, 75,
      68, 68, 68,
      65, 65, 65,
      # Medium
      55, 55, 55,
      50, 50, 50,
      52, 52, 52,
      48, 48, 48,
      # Low
      30, 30, 30,
      35, 35, 35,
      32, 32,
      # Very low
      15, 15, 15,
      10, 10, 10
    ),
    stringsAsFactors = FALSE
  )

  # Vectorized lookup
  scores <- numeric(length(species))

  for (i in seq_along(species)) {
    if (is.na(species[i])) {
      scores[i] <- NA_real_
      next
    }

    species_lower <- tolower(species[i])

    # Exact match first
    idx <- which(lookup$species == species_lower)

    # If not found, try partial match
    if (length(idx) == 0) {
      idx <- grep(species_lower, lookup$species, fixed = TRUE)
    }

    # If still not found, try reverse partial match
    if (length(idx) == 0) {
      for (j in seq_len(nrow(lookup))) {
        if (grepl(lookup$species[j], species_lower, fixed = TRUE)) {
          idx <- j
          break
        }
      }
    }

    # Return score or default to medium (50)
    if (length(idx) > 0) {
      scores[i] <- lookup$palatability[idx[1]]
    } else {
      scores[i] <- 50 # Default: medium palatability
    }
  }

  scores
}

#' Calculate Shannon Diversity Index
#'
#' Computes Shannon diversity index (H) from proportions of categories.
#' Used for structural diversity (B2) indicator.
#'
#' Formula: H = -sum(p_i * log(p_i)) where p_i are proportions summing to 1.
#'
#' @param proportions Numeric vector. Proportions of categories (must sum to ~1).
#'   Zero values are automatically removed.
#' @param base Numeric. Logarithm base (default: exp(1) for natural log).
#'
#' @return Numeric. Shannon diversity index H. Returns 0 if only one category.
#'   Returns NA if all proportions are zero or NA.
#' @keywords internal
#' @noRd
#'
#' @examples
#' \dontrun{
#' # Equal distribution of 4 strata classes
#' calculate_shannon_h(c(0.25, 0.25, 0.25, 0.25)) # Returns ~1.386 (log(4))
#'
#' # Unequal distribution
#' calculate_shannon_h(c(0.5, 0.3, 0.2)) # Returns ~1.03
#'
#' # Single category (no diversity)
#' calculate_shannon_h(c(1.0)) # Returns 0
#' }
calculate_shannon_h <- function(proportions, base = exp(1)) {
  # Remove zeros and NAs
  p <- proportions[!is.na(proportions) & proportions > 0]

  # Check if valid
  if (length(p) == 0) {
    return(NA_real_)
  }

  # Normalize to sum to 1 (in case not exactly 1 due to rounding)
  p <- p / sum(p)

  # Shannon formula: H = -sum(p_i * log(p_i))
  H <- -sum(p * log(p, base = base))

  return(H)
}

# ============================================================================
# v0.4.0 - New Helper Functions for S, P, E, N Families
# ============================================================================

#' Get OSM Bounding Box from Spatial Units
#'
#' Automatically detects the bounding box from sf units for OpenStreetMap queries.
#' Adds optional buffer to ensure complete data coverage.
#'
#' @param units sf object (POLYGON or MULTIPOLYGON)
#' @param buffer_m Numeric. Buffer distance in meters to expand bbox. Default 1000m.
#'
#' @return Numeric vector of length 4: c(xmin, ymin, xmax, ymax) in WGS84 (EPSG:4326)
#'
#' @keywords internal
#' @noRd
get_osm_bbox <- function(units, buffer_m = 1000) {
  # Validate input
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  # Get CRS
  units_crs <- sf::st_crs(units)

  # Buffer in native CRS if metric
  if (buffer_m > 0 && !is.na(units_crs) && units_crs$input != "EPSG:4326") {
    units_buffered <- sf::st_buffer(units, dist = buffer_m)
  } else {
    units_buffered <- units
  }

  # Transform to WGS84 for OSM
  units_wgs84 <- sf::st_transform(units_buffered, crs = 4326)

  # Extract bbox
  bbox <- sf::st_bbox(units_wgs84)

  # Return as named vector (OSM expects xmin, ymin, xmax, ymax)
  return(c(
    xmin = unname(bbox["xmin"]),
    ymin = unname(bbox["ymin"]),
    xmax = unname(bbox["xmax"]),
    ymax = unname(bbox["ymax"])
  ))
}

#' Lookup IFN Allometric Equation
#'
#' Retrieves IFN volume equation parameters for a given species from bundled lookup table.
#' Falls back to genus-level equations if species not found.
#'
#' @param species_code Character. IFN species code (e.g., "FASY", "QUPE", "PIAB")
#' @param fallback_genus Character. Genus fallback: "broadleaf" or "conifer". Default NULL (auto-detect).
#'
#' @return Named list with equation parameters: a, b, c, dbh_min, dbh_max, height_min, height_max
#'   Returns NULL if species not found and no fallback specified.
#'
#' @keywords internal
#' @noRd
lookup_ifn_equation <- function(species_code, fallback_genus = NULL) {
  # Load bundled IFN equations table
  equations_path <- system.file("extdata", "ifn_volume_equations.csv", package = "nemeton")

  if (!file.exists(equations_path)) {
    warning("IFN equations table not found: ", equations_path)
    return(NULL)
  }

  equations <- utils::read.csv(equations_path, stringsAsFactors = FALSE)

  # Lookup species
  species_row <- equations[equations$species_code == toupper(species_code), ]

  if (nrow(species_row) > 0) {
    # Species found - return first match
    return(as.list(species_row[1, ]))
  }

  # Species not found - try fallback
  if (!is.null(fallback_genus)) {
    fallback_code <- if (fallback_genus == "broadleaf") {
      "BROADLEAF_GENUS"
    } else if (fallback_genus == "conifer") {
      "CONIFER_GENUS"
    } else {
      NULL
    }

    if (!is.null(fallback_code)) {
      fallback_row <- equations[equations$species_code == fallback_code, ]
      if (nrow(fallback_row) > 0) {
        return(as.list(fallback_row[1, ]))
      }
    }
  }

  # No equation found
  return(NULL)
}

#' Lookup Species-Specific Threshold or Parameter
#'
#' Generic lookup function for species-specific thresholds, densities, or other parameters
#' from bundled lookup tables (e.g., wood density, fire susceptibility, drought tolerance).
#'
#' @param species_code Character. Species code (e.g., "FASY", "PIAB")
#' @param parameter Character. Parameter name: "density", "fire_risk", "drought_tolerance", etc.
#' @param table_name Character. Lookup table filename (without .csv extension). Default "wood_density".
#'
#' @return Numeric value or NA if not found
#'
#' @keywords internal
#' @noRd
lookup_species_threshold <- function(species_code, parameter = "density_kg_m3", table_name = "wood_density") {
  # Load bundled lookup table
  table_path <- system.file("extdata", paste0(table_name, ".csv"), package = "nemeton")

  if (!file.exists(table_path)) {
    warning("Lookup table not found: ", table_path)
    return(NA_real_)
  }

  lookup_table <- utils::read.csv(table_path, stringsAsFactors = FALSE)

  # Lookup species
  species_row <- lookup_table[lookup_table$species_code == toupper(species_code), ]

  if (nrow(species_row) > 0 && parameter %in% names(species_row)) {
    return(species_row[1, parameter])
  }

  # Try genus fallback
  genus_row <- lookup_table[lookup_table$species_code == "BROADLEAF_GENUS", ]
  if (nrow(genus_row) > 0 && parameter %in% names(genus_row)) {
    return(genus_row[1, parameter])
  }

  # Not found
  return(NA_real_)
}

#' Lookup ADEME Emission Factor
#'
#' Retrieves carbon emission factors from ADEME Base Carbone for substitution scenarios.
#'
#' @param material_type Character. Material type: "wood_energy", "wood_construction", "fuelwood_extraction", etc.
#' @param scenario Character. Substitution scenario: "vs_natural_gas", "vs_concrete", "vs_steel", etc.
#'
#' @return Named list with: emission_factor_kgCO2eq_per_unit, unit, reference, year, notes
#'   Returns NULL if not found.
#'
#' @keywords internal
#' @noRd
lookup_ademe_factor <- function(material_type, scenario = NULL) {
  # Load bundled ADEME factors table
  factors_path <- system.file("extdata", "ademe_emission_factors.csv", package = "nemeton")

  if (!file.exists(factors_path)) {
    warning("ADEME emission factors table not found: ", factors_path)
    return(NULL)
  }

  factors <- utils::read.csv(factors_path, stringsAsFactors = FALSE)

  # Lookup by material type and scenario
  if (!is.null(scenario)) {
    factor_row <- factors[factors$material_type == material_type &
      factors$substitution_scenario == scenario, ]
  } else {
    factor_row <- factors[factors$material_type == material_type, ]
  }

  if (nrow(factor_row) > 0) {
    return(as.list(factor_row[1, ]))
  }

  # Not found
  return(NULL)
}

# ==============================================================================
# BD Forêt V2 Enrichment
# ==============================================================================

#' Enrich Parcels with BD Forêt V2 Data
#'
#' Performs spatial intersection between parcels and BD Forêt V2 polygons
#' to extract dominant species, then maps IGN essence codes to allometric
#' model species names. Used upstream of indicator functions that accept
#' `species`/`age` unit columns (P2 station in CHM mode, C1 biomass in
#' allometric mode).
#'
#' The returned `density` column is a canopy-cover fraction (default
#' \code{0.7}), suitable for the C1 allometric formula. It is NOT a
#' stems-per-hectare figure, so do not feed it to
#' \code{indicateur_p1_volume()} as `density_field`.
#'
#' @param parcels sf object. Parcel geometries to enrich.
#' @param bdforet_sf sf object. BD Forêt V2 formation_vegetale layer.
#'
#' @return A data.frame with columns `species`, `age`, `density` (one row
#'   per parcel). Parcels with no BD Forêt coverage get NA values.
#' @export
enrich_parcels_bdforet <- function(parcels, bdforet_sf) {
  # Identify the essence column in BD Forêt data
  essence_col <- intersect(
    c("essence", "tfv", "lib_fv", "libelle"),
    tolower(names(bdforet_sf))
  )
  if (length(essence_col) == 0) {
    cli::cli_alert_warning(
      "BD For\u00eat layer has no recognizable essence column; skipping enrichment"
    )
    return(data.frame(
      species = rep(NA_character_, nrow(parcels)),
      age     = rep(NA_real_, nrow(parcels)),
      density = rep(NA_real_, nrow(parcels))
    ))
  }
  # Use the original-case column name
  essence_col_orig <- names(bdforet_sf)[tolower(names(bdforet_sf)) == essence_col[1]]

  # Ensure matching CRS
  if (sf::st_crs(parcels) != sf::st_crs(bdforet_sf)) {
    bdforet_sf <- sf::st_transform(bdforet_sf, sf::st_crs(parcels))
  }

  # Add parcel id for aggregation
  parcels$..parcel_id.. <- seq_len(nrow(parcels))

  # Spatial intersection. Real BD For\u00eat V2 polygons occasionally carry
  # invalid rings (e.g. "Edge N is degenerate (duplicate vertex)") that make
  # GEOS abort the whole intersection -> every UGF ends up with NA species,
  # silently degrading the species-dependent indicators (P/C/B) to their
  # synthetic-inventory fallback. Repair both layers with st_make_valid()
  # and retry once before giving up; only pay the repair cost when the raw
  # intersection actually fails.
  .bdf_intersect <- function(bdf, pcl) {
    suppressWarnings(sf::st_intersection(bdf, pcl["..parcel_id.."]))
  }
  inter <- tryCatch(
    .bdf_intersect(bdforet_sf, parcels),
    error = function(e) {
      cli::cli_alert_info(
        "BD For\u00eat intersection hit an invalid geometry ({e$message}); repairing with {.fn sf::st_make_valid} and retrying...")
      tryCatch(
        .bdf_intersect(sf::st_make_valid(bdforet_sf),
                       sf::st_make_valid(parcels)),
        error = function(e2) {
          cli::cli_alert_warning("BD For\u00eat intersection failed after repair: {e2$message}")
          NULL
        }
      )
    }
  )

  # Default result: all NA
  result <- data.frame(
    ..parcel_id.. = seq_len(nrow(parcels)),
    species       = rep(NA_character_, nrow(parcels)),
    age           = rep(NA_real_, nrow(parcels)),
    density       = rep(NA_real_, nrow(parcels))
  )

  if (is.null(inter) || nrow(inter) == 0) {
    return(result[, c("species", "age", "density")])
  }

  # Compute area of each intersection fragment
  inter$..area.. <- as.numeric(sf::st_area(inter))

  # Aggregate: pick dominant essence (largest area) per parcel
  inter_df <- sf::st_drop_geometry(inter)
  inter_df$essence_raw <- inter_df[[essence_col_orig]]

  dominant <- do.call(rbind, lapply(
    split(inter_df, inter_df$..parcel_id..),
    function(df) {
      idx <- which.max(df$..area..)
      data.frame(
        ..parcel_id.. = df$..parcel_id..[1],
        essence_raw   = df$essence_raw[idx],
        stringsAsFactors = FALSE
      )
    }
  ))

  # Map IGN essence codes to allometric model names
  dominant$species <- map_essence_to_species(dominant$essence_raw)

  # Default age and density for temperate forest
  dominant$age     <- 60
  dominant$density <- 0.7

  # Merge back to full parcel set
  result$species[match(dominant$..parcel_id.., result$..parcel_id..)] <- dominant$species
  result$age[match(dominant$..parcel_id.., result$..parcel_id..)]     <- dominant$age
  result$density[match(dominant$..parcel_id.., result$..parcel_id..)] <- dominant$density

  result[, c("species", "age", "density")]
}

#' Add a dominant-species column from a classification raster
#'
#' Fills a species column on \code{units} from a tree-species
#' classification raster (typically the Theia \code{theia_species}
#' product) and a user-supplied class-to-species crosswalk. For each
#' unit the coverage-weighted dominant raster class is resolved, then
#' mapped to a species code via \code{class_map}. This is an upstream
#' helper for indicators that read a species column —
#' \code{indicateur_p1_volume()}, \code{indicateur_p2_station()},
#' \code{indicateur_c1_biomasse()} and the biodiversity indicators.
#'
#' The class-to-species crosswalk is product-specific (it depends on
#' the legend of the classification raster), so it must be supplied
#' explicitly rather than guessed.
#'
#' @param units sf object. Unit geometries to enrich.
#' @param species_raster A \code{SpatRaster} of integer tree-species
#'   classes.
#' @param class_map Named vector or list mapping raster class values
#'   (names, as character) to species codes (values). Classes absent
#'   from the map yield \code{NA}.
#' @param species_col Character. Name of the column to add. Default
#'   \code{"species"}.
#'
#' @return The input \code{units} sf with the species column added
#'   (or overwritten). Units with no raster coverage get \code{NA}.
#' @export
units_add_species_from_raster <- function(units, species_raster, class_map,
                                          species_col = "species") {
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }
  if (!inherits(species_raster, "SpatRaster")) {
    stop("species_raster must be a terra SpatRaster", call. = FALSE)
  }
  if (missing(class_map) || length(class_map) == 0L) {
    stop("class_map must be a non-empty named vector or list", call. = FALSE)
  }

  per_unit <- safe_extract(
    species_raster,
    as_pure_sf(units),
    fun = NULL,
    progress = FALSE
  )

  dominant <- vapply(per_unit, function(df) {
    if (is.null(df) || nrow(df) == 0) return(NA_character_)
    w <- df$coverage_fraction
    if (is.null(w)) w <- rep(1, nrow(df))
    agg <- tapply(w, df$value, sum, na.rm = TRUE)
    agg <- agg[!is.na(agg)]
    if (length(agg) == 0) return(NA_character_)
    mode_class <- names(agg)[which.max(agg)]
    code <- class_map[[mode_class]]
    if (is.null(code) || is.na(code)) NA_character_ else as.character(code)
  }, character(1))

  units[[species_col]] <- dominant
  units
}

#' Map IGN BD Forêt Essence Codes to Allometric Species Names
#'
#' @param essence Character vector of raw essence labels from BD Forêt V2.
#' @return Character vector of allometric model species names.
#' @keywords internal
#' @noRd
map_essence_to_species <- function(essence) {
  essence_lower <- tolower(essence)
  species <- rep("Generic", length(essence))
  species[grepl("ch\u00eane|chene|ch\\u00eane", essence_lower)] <- "Quercus"
  species[grepl("h\u00eatre|hetre|h\\u00eatre", essence_lower)] <- "Fagus"
  species[grepl("pin|\\u00e9pic\\u00e9a|epicea", essence_lower)] <- "Pinus"
  species[grepl("sapin|douglas", essence_lower)]                 <- "Abies"
  species[is.na(essence)] <- NA_character_
  species
}


#' Get global shared cache directory
#'
#' Returns the path to a global cache directory shared across all projects.
#' Used for large datasets like OSO, TWI caches, and nasapower wind data.
#'
#' @return Character. Path to the global cache directory.
#' @export
get_global_cache_dir <- function() {
  if (requireNamespace("rappdirs", quietly = TRUE)) {
    base_dir <- rappdirs::user_data_dir("nemeton", "nemeton")
  } else {
    base_dir <- file.path(Sys.getenv("HOME"), ".nemeton")
  }
  cache_dir <- file.path(base_dir, "cache")
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE)
  }
  cache_dir
}


#' Format a duration as hours, then minutes, then seconds
#'
#' Human-facing durations always lead with the largest meaningful unit: a
#' two-hour run reads `"2 h 05 min 12 s"`, never `"7512 s"`. Machine-facing
#' fields (`duration_sec`, `elapsed_sec` in results and `run_meta.json`) stay
#' in raw seconds — this is for messages only.
#'
#' @param sec Numeric. Duration in seconds. `NULL`, `NA` or a negative value
#'   yields `"?"`.
#' @param with_seconds Logical. Keep the seconds component above one minute.
#'   `FALSE` gives the coarser `"2 h 05 min"` used in push notifications.
#'
#' @return A character scalar.
#'
#' @examples
#' format_duration(23)                        # "23 s"
#' format_duration(819)                       # "13 min 39 s"
#' format_duration(7512)                      # "2 h 05 min 12 s"
#' format_duration(7512, with_seconds = FALSE) # "2 h 05 min"
#'
#' @export
format_duration <- function(sec, with_seconds = TRUE) {
  sec <- suppressWarnings(as.numeric(sec)[1])
  if (length(sec) != 1L || is.na(sec) || !is.finite(sec) || sec < 0) return("?")
  s <- round(sec)
  if (s < 60) return(sprintf("%d s", as.integer(s)))
  h    <- s %/% 3600
  mins <- (s %% 3600) %/% 60
  secs <- s %% 60
  if (h > 0L) {
    if (with_seconds) sprintf("%d h %02d min %02d s", h, mins, secs)
    else              sprintf("%d h %02d min", h, mins)
  } else {
    if (with_seconds) sprintf("%d min %02d s", mins, secs)
    else              sprintf("%d min", mins)
  }
}


# TRUE when a raster holds no data at all, WITHOUT materialising it.
# `all(is.na(terra::values(x)))` pulls every cell into RAM just to answer a
# yes/no question — on a large tile that is hundreds of MB for one boolean.
# `terra::global(x, "notNA")` counts through terra's own streaming reader.
.raster_is_empty <- function(x) {
  if (is.null(x)) return(TRUE)
  n <- tryCatch(sum(terra::global(x, "notNA")[[1L]], na.rm = TRUE),
                error = function(e) NA_real_)
  # Unreadable/degenerate raster: fall back to the honest (costly) answer
  # rather than silently claiming it is empty.
  if (is.na(n)) return(all(is.na(terra::values(x))))
  n == 0
}


#' Scratch directory for a run's bulky intermediates
#'
#' Long pipelines stream their intermediates to disk rather than holding them
#' in RAM (see [run_reconfort_dieback()]). The volume is not negligible — the
#' RECONFORT feature stacks measured ~800 MB for a 0.89 Mpx AOI over 115 dates,
#' and that scales with pixels x dates: a department-wide run lands in the tens
#' of GB. `tempdir()` often sits on a small root partition or on tmpfs (i.e. in
#' RAM, which would defeat the purpose entirely), so the location is
#' configurable.
#'
#' Resolution order:
#' \enumerate{
#'   \item `options(nemeton.scratch_dir = "/data/scratch")`
#'   \item the `NEMETON_SCRATCH_DIR` environment variable
#'   \item `tempdir()` (the default)
#' }
#'
#' Intermediates are removed by the pipeline as soon as they are consumed; the
#' directory itself is left in place.
#'
#' @param subdir Optional sub-directory to create under the scratch root.
#'
#' @return The path, created if needed (character scalar).
#'
#' @examples
#' \dontrun{
#' options(nemeton.scratch_dir = "/mnt/big/scratch")
#' scratch_dir()
#' }
#'
#' @export
scratch_dir <- function(subdir = NULL) {
  root <- getOption("nemeton.scratch_dir", NULL)
  if (is.null(root) || !nzchar(as.character(root)[1])) {
    root <- Sys.getenv("NEMETON_SCRATCH_DIR", "")
  }
  root <- as.character(root)[1]
  if (is.na(root) || !nzchar(root)) root <- tempdir()

  path <- if (is.null(subdir)) root else file.path(root, subdir)
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  if (!dir.exists(path)) {
    cli::cli_abort(c(
      "Cannot create the scratch directory {.path {path}}.",
      i = "Set {.code options(nemeton.scratch_dir=)} or {.envvar NEMETON_SCRATCH_DIR} to a writable location."
    ))
  }
  path
}


# Free space (in GB) on the filesystem holding `path`, or NA when it cannot be
# read (non-POSIX, `df` absent). Advisory only — never abort a run over it.
.free_space_gb <- function(path) {
  out <- tryCatch(
    suppressWarnings(system2("df", c("-Pk", shQuote(path)), stdout = TRUE, stderr = FALSE)),
    error = function(e) character(0))
  if (length(out) < 2L) return(NA_real_)
  f <- strsplit(trimws(out[2L]), "\\s+")[[1L]]
  kb <- suppressWarnings(as.numeric(f[4L]))
  if (is.na(kb)) return(NA_real_)
  kb / 1048576
}
