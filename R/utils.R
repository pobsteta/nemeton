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
      scores[i] <- 50  # Default: medium palatability
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
