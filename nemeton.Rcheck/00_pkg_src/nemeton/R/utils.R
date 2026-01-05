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
#' Returns full family name from single-letter code.
#'
#' @param family_code Character. Single letter (B, W, A, F, C, L, T, R, S, P, E, N)
#'
#' @return Character. Full family name
#' @keywords internal
#' @noRd
get_family_name <- function(family_code) {
  family_names <- c(
    B = "Biodiversité/Vivant",
    W = "Water/Infiltrée",
    A = "Air/Vaporeuse",
    F = "Fertilité/Riche",
    C = "Carbone/Énergétique",
    L = "Landscape/Esthétique",
    T = "Trame/Nervurée",
    R = "Résilience/Flexible",
    S = "Santé/Ouverte",
    P = "Patrimoine/Radicale",
    E = "Éducation/Éducative",
    N = "Nuit/Ténébreuse"
  )

  name <- family_names[family_code]
  if (is.na(name)) {
    return(paste0("Family ", family_code))
  }
  name
}
