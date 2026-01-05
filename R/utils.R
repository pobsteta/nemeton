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
  msg <- tryCatch({
    glue::glue(msg_raw, .envir = parent.frame())
  }, error = function(e) {
    # If glue fails (e.g., cli syntax), just use the raw message
    msg_raw
  })
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
as_pure_sf <- function(x) {
  x_sf <- sf::st_as_sf(x)
  class(x_sf) <- setdiff(class(x_sf), "nemeton_units")
  x_sf
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
      scores[i] <- 50  # Default: medium flammability
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
      scores[i] <- 50  # Default: intermediate sensitivity
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
#' calculate_shannon_h(c(0.25, 0.25, 0.25, 0.25))  # Returns ~1.386 (log(4))
#'
#' # Unequal distribution
#' calculate_shannon_h(c(0.5, 0.3, 0.2))  # Returns ~1.03
#'
#' # Single category (no diversity)
#' calculate_shannon_h(c(1.0))  # Returns 0
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
