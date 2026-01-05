#' Multi-Family Indicator System
#'
#' Functions for managing and aggregating indicators by family.
#'
#' @name family-system
#' @keywords internal
NULL

#' Create Family Composite Indices
#'
#' Aggregates sub-indicators into family-level composite scores (e.g., score_carbon,
#' score_water). Automatically detects indicator families from column name prefixes
#' (C_, W_, F_, L_, etc.) and computes weighted averages.
#'
#' @param data An sf object containing indicator columns with family prefixes.
#' @param method Character. Aggregation method: "mean", "weighted", "geometric", "harmonic".
#'   Default "mean".
#' @param weights Named list of weight vectors per family. E.g.,
#'   \code{list(C = c(C1 = 0.6, C2 = 0.4), W = c(W1 = 0.5, W2 = 0.3, W3 = 0.2))}.
#'   If NULL, equal weights are used.
#' @param na.rm Logical. If TRUE, NA values are removed before aggregation. Default TRUE.
#' @param family_codes Character vector. Family codes to process. Default NULL (auto-detect).
#'
#' @return The input sf object with added family_* columns (e.g., family_C, family_W).
#'
#' @details
#' **Family Detection**: Automatically identifies indicators by prefix:
#' \itemize{
#'   \item C1, C2 -> Carbon family (family_C)
#'   \item W1, W2, W3 -> Water family (family_W)
#'   \item F1, F2 -> Soil fertility family (family_F)
#'   \item L1, L2 -> Landscape family (family_L)
#'   \item B1, B2, B3 -> Biodiversity family (family_B)
#'   \item And 7 other families (A, T, R, S, P, E, N)
#' }
#'
#' **Aggregation Methods**:
#' \itemize{
#'   \item mean: Simple arithmetic mean
#'   \item weighted: Weighted average using provided weights
#'   \item geometric: Geometric mean (product^(1/n))
#'   \item harmonic: Harmonic mean (n / sum(1/x))
#' }
#'
#' @export
#' @examples
#' \dontrun{
#' # Setup multi-family indicators
#' data(massif_demo_units)
#' units <- massif_demo_units[1:5, ]
#' units$C1 <- rnorm(5, 50, 10)  # Carbon biomass
#' units$C2 <- rnorm(5, 70, 10)  # Carbon NDVI
#' units$W1 <- rnorm(5, 15, 5)   # Water network
#'
#' # Create family indices
#' units_fam <- create_family_index(units)
#'
#' # With custom weights
#' units_fam <- create_family_index(
#'   units,
#'   weights = list(C = c(C1 = 0.7, C2 = 0.3))
#' )
#' }
create_family_index <- function(data,
                                 method = c("mean", "weighted", "geometric", "harmonic"),
                                 weights = NULL,
                                 na.rm = TRUE,
                                 family_codes = NULL) {
  # Validate inputs
  if (!inherits(data, "sf")) {
    stop("data must be an sf object", call. = FALSE)
  }

  method <- match.arg(method)

  # Define all 12 family codes
  all_families <- c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")

  if (is.null(family_codes)) {
    family_codes <- all_families
  }

  # Detect indicator columns by family prefix
  indicator_cols <- names(data)[vapply(names(data), function(col) {
    is.numeric(data[[col]]) && !col %in% c("geometry", "geom")
  }, logical(1))]

  # Group indicators by family
  family_groups <- list()

  for (fam in family_codes) {
    # Match columns starting with family code + digit (e.g., C1, C2, W1)
    pattern <- paste0("^", fam, "[0-9]")
    fam_indicators <- grep(pattern, indicator_cols, value = TRUE)

    if (length(fam_indicators) > 0) {
      # Prefer normalized indicators (_norm suffix) when both raw and normalized exist
      # Extract base indicator names (without _norm)
      base_names <- sub("_norm$", "", fam_indicators)
      unique_bases <- unique(base_names)

      # For each unique base, prefer the _norm version if it exists
      preferred_indicators <- character(0)
      for (base in unique_bases) {
        norm_version <- paste0(base, "_norm")
        if (norm_version %in% fam_indicators) {
          preferred_indicators <- c(preferred_indicators, norm_version)
        } else {
          preferred_indicators <- c(preferred_indicators, base)
        }
      }

      family_groups[[fam]] <- preferred_indicators
    }
  }

  # Check if any families were detected
  if (length(family_groups) == 0) {
    stop("No family indicators found. Indicators must have family prefix (C1, W1, F1, etc.)",
         call. = FALSE)
  }

  # Create family composite scores
  result <- data

  for (fam in names(family_groups)) {
    indicators <- family_groups[[fam]]
    family_col <- paste0("family_", fam)

    # Get indicator values
    indicator_data <- as.matrix(sf::st_drop_geometry(data[, indicators, drop = FALSE]))

    # Determine weights for this family
    if (!is.null(weights) && fam %in% names(weights)) {
      fam_weights <- weights[[fam]]

      # Ensure weights match indicators
      if (!all(indicators %in% names(fam_weights))) {
        warning(sprintf("Not all indicators in family %s have weights, using equal weights",
                        fam), call. = FALSE)
        fam_weights <- rep(1 / length(indicators), length(indicators))
        names(fam_weights) <- indicators
      } else {
        # Normalize weights to sum to 1
        fam_weights <- fam_weights[indicators]
        fam_weights <- fam_weights / sum(fam_weights)
      }
    } else {
      # Equal weights
      fam_weights <- rep(1 / length(indicators), length(indicators))
      names(fam_weights) <- indicators
    }

    # Compute family score based on method
    if (method == "mean" || method == "weighted") {
      # Always use weighted average (mean is just weighted with equal weights)
      family_score <- apply(indicator_data, 1, function(row) {
        if (all(is.na(row))) return(NA_real_)

        valid_idx <- !is.na(row)
        if (!any(valid_idx)) return(NA_real_)

        valid_values <- row[valid_idx]
        valid_weights <- fam_weights[valid_idx]

        # Renormalize weights
        valid_weights <- valid_weights / sum(valid_weights)

        sum(valid_values * valid_weights)
      })

    } else if (method == "geometric") {
      # Geometric mean: (product of values)^(1/n)
      family_score <- apply(indicator_data, 1, function(row) {
        if (all(is.na(row))) return(NA_real_)

        valid_values <- row[!is.na(row)]
        if (length(valid_values) == 0) return(NA_real_)

        # Handle negative values
        if (any(valid_values <= 0)) {
          warning("Geometric mean requires positive values, using absolute values",
                  call. = FALSE)
          valid_values <- abs(valid_values)
        }

        exp(mean(log(valid_values)))
      })

    } else if (method == "harmonic") {
      # Harmonic mean: n / sum(1/x)
      family_score <- apply(indicator_data, 1, function(row) {
        if (all(is.na(row))) return(NA_real_)

        valid_values <- row[!is.na(row)]
        if (length(valid_values) == 0) return(NA_real_)

        # Handle zeros
        if (any(valid_values == 0)) {
          warning("Harmonic mean undefined for zero values, replacing with small value",
                  call. = FALSE)
          valid_values[valid_values == 0] <- 1e-6
        }

        length(valid_values) / sum(1 / valid_values)
      })
    }

    # Add to result
    result[[family_col]] <- family_score
  }

  # Success message
  family_names <- paste(names(family_groups), collapse = ", ")
  msg_info("family_index_created", family_names, sum(lengths(family_groups)))

  result
}

#' Detect Indicator Family from Name
#'
#' Extracts the family code from an indicator name (e.g., "C1" -> "C").
#'
#' @param indicator_name Character. Indicator name.
#'
#' @return Character. Family code (C, W, F, L, etc.) or NA if not detected.
#'
#' @keywords internal
detect_indicator_family <- function(indicator_name) {
  # Match pattern: family letter + digit
  if (grepl("^[A-Z][0-9]", indicator_name)) {
    return(substr(indicator_name, 1, 1))
  }

  NA_character_
}

#' Get Family Name from Code
#'
#' Returns the full family name for a given family code.
#'
#' @param family_code Character. Family code (C, W, F, etc.).
#' @param lang Character. Language ("en" or "fr"). Default uses current locale.
#'
#' @return Character. Full family name.
#'
#' @usage get_family_name(family_code, lang = NULL)
#'
#' @keywords internal
get_family_name <- function(family_code, lang = NULL) {
  if (is.null(lang)) {
    lang <- get_language()
  }

  family_names_en <- c(
    B = "Biodiversity",
    W = "Water Regulation",
    A = "Air Quality & Microclimate",
    F = "Soil Fertility",
    C = "Carbon & Vitality",
    L = "Landscape & Aesthetics",
    T = "Temporal Dynamics & Trame",
    R = "Risk Management & Resilience",
    S = "Social & Recreational",
    P = "Productive & Economic",
    E = "Education & Climate",
    N = "Naturalness & Night"
  )

  family_names_fr <- c(
    B = "B – Biodiversité / V - Vivant",
    W = "W – Water (eau) / I - Infiltrée",
    A = "A – Air (microclimat) / V – Vaporeuse",
    F = "F – Fertilité / R - Riche",
    C = "C – Carbone / E – Énergétique",
    L = "L – Landscape (paysage) / E – Esthétique",
    T = "T – Trame / N - Nervurée",
    R = "R – Résilience / F - Flexible",
    S = "S – Santé / O – Ouverte",
    P = "P – Patrimoine / R – Radicale",
    E = "E – Éducation / E – Éducative",
    N = "N – Nuit / T – Ténébreuse"
  )

  names_list <- if (lang == "fr") family_names_fr else family_names_en

  if (family_code %in% names(names_list)) {
    return(names_list[[family_code]])
  }

  family_code  # Return code if name not found
}
