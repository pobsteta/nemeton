#' Normalize indicator values
#'
#' Transforms indicator values to a common scale for comparison and aggregation.
#'
#' @param data An \code{sf} object or data.frame containing indicator values
#' @param indicators Character vector of indicator column names to normalize.
#'   If NULL, auto-detects indicator columns.
#' @param method Character. Normalization method. Options:
#'   \itemize{
#'     \item "minmax" - Min-max normalization to 0-100 scale (default)
#'     \item "zscore" - Z-score standardization (mean=0, sd=1)
#'     \item "quantile" - Quantile normalization (0-100 based on percentile rank)
#'   }
#' @param suffix Character. Suffix to add to normalized column names. Default "_norm".
#' @param keep_original Logical. Keep original indicator columns? Default TRUE.
#' @param na.rm Logical. Remove NA values before normalization? Default TRUE.
#' @param reference_data Optional data.frame with reference values for normalization.
#'   Useful for normalizing new data using parameters from a reference dataset.
#' @param by_family Logical. If TRUE, normalize indicators within each family using
#'   family-wide parameters (e.g., all Carbon indicators C1, C2 share the same min/max).
#'   This makes indicators within a family directly comparable. Default FALSE.
#'
#' @return The input data with added normalized columns
#'
#' @details
#' \strong{Normalization methods:}
#'
#' \itemize{
#'   \item \strong{Min-max (0-100)}: \code{norm = (value - min) / (max - min) * 100}
#'     - Preserves the original distribution shape
#'     - Sensitive to outliers
#'     - Interpretable scale (0 = worst, 100 = best)
#'
#'   \item \strong{Z-score}: \code{norm = (value - mean) / sd}
#'     - Centers data around 0
#'     - Units in standard deviations
#'     - Less sensitive to outliers
#'
#'   \item \strong{Quantile}: \code{norm = percentile_rank * 100}
#'     - Robust to outliers
#'     - Creates uniform distribution
#'     - 0 = lowest percentile, 100 = highest
#' }
#'
#' @examples
#' \dontrun{
#' # Normalize all indicators with min-max
#' normalized <- normalize_indicators(
#'   results,
#'   indicators = c("carbon", "biodiversity", "water"),
#'   method = "minmax"
#' )
#'
#' # Z-score normalization
#' normalized_z <- normalize_indicators(
#'   results,
#'   method = "zscore",
#'   suffix = "_z"
#' )
#'
#' # Normalize using reference dataset
#' new_normalized <- normalize_indicators(
#'   new_data,
#'   indicators = c("carbon", "water"),
#'   reference_data = reference_results
#' )
#' }
#'
#' @seealso \code{\link{create_composite_index}}
#'
#' @export
normalize_indicators <- function(data,
                                 indicators = NULL,
                                 method = c("minmax", "zscore", "quantile"),
                                 suffix = "_norm",
                                 keep_original = TRUE,
                                 na.rm = TRUE,
                                 reference_data = NULL,
                                 by_family = FALSE) {
  # Match method argument
  method <- match.arg(method)

  # When by_family = TRUE and suffix not explicitly set, normalize in-place
  if (by_family && suffix == "_norm") {
    suffix <- ""
    keep_original <- FALSE
  }

  # Auto-detect indicators if not specified
  if (is.null(indicators)) {
    all_cols <- names(data)

    # v0.6.0+ indicator names (family_subname format)
    known_indicators <- list_indicators()
    v6_indicators <- intersect(all_cols, known_indicators)

    # v0.2.0+ family indicators (C1, C2, W1, etc.)
    family_pattern <- "^[A-Z][0-9]" # Matches C1, W1, F1, etc.
    family_indicators <- grep(family_pattern, all_cols, value = TRUE)

    # Family index columns (family_carbon, famille_carbone, etc.)
    family_index_pattern <- "^(family|famille)_"
    family_index_indicators <- grep(family_index_pattern, all_cols, value = TRUE)

    # Combine all
    indicators <- unique(c(
      v6_indicators,
      family_indicators,
      family_index_indicators
    ))

    if (length(indicators) == 0) {
      msg_error("viz_no_indicators")
      cli::cli_inform("i" = msg("viz_specify_indicators"))
      cli::cli_inform(">" = "Example: indicators = c('carbon', 'water') or c('C1', 'W1')")
      cli::cli_abort("")
    }

    n_ind <- length(indicators)
    ind_list <- paste(indicators, collapse = ", ")
    msg_info("normalize_auto_detected", n_ind, ind_list)
  }

  # Validate that indicators exist
  missing <- setdiff(indicators, names(data))
  if (length(missing) > 0) {
    missing_str <- paste(missing, collapse = ", ")
    msg_error("normalize_missing", missing_str)
  }

  # Create result data
  result <- data

  # Normalize each indicator
  for (ind in indicators) {
    values <- data[[ind]]

    # Use reference data if provided
    if (!is.null(reference_data)) {
      if (!ind %in% names(reference_data)) {
        msg_warn("normalize_ref_missing", ind)
        ref_values <- values
      } else {
        ref_values <- reference_data[[ind]]
      }
    } else {
      ref_values <- values
    }

    # Normalize
    normalized <- normalize_vector(
      values,
      method = method,
      reference = ref_values,
      na.rm = na.rm
    )

    # Add to result
    new_col <- paste0(ind, suffix)
    result[[new_col]] <- normalized

    # Optionally remove original (but not if we're replacing in-place)
    if (!keep_original && suffix != "") {
      result[[ind]] <- NULL
    }
  }

  # Preserve class (sf if input was sf)
  if (inherits(data, "sf") && !inherits(result, "sf")) {
    class(result) <- class(data)
  }

  # Add metadata if it's a nemeton object
  if (inherits(data, "nemeton_units")) {
    meta <- attr(data, "metadata")
    meta$normalized_at <- Sys.time()
    meta$normalization_method <- method
    meta$normalized_indicators <- indicators
    attr(result, "metadata") <- meta
  }

  n_ind <- length(indicators)
  msg_success("normalize_normalized", n_ind, method)

  result
}

#' Normalize a numeric vector
#'
#' Internal function to normalize a single vector of values.
#'
#' @param x Numeric vector to normalize
#' @param method Normalization method
#' @param reference Reference vector for normalization parameters
#' @param na.rm Remove NA values?
#'
#' @return Normalized numeric vector
#' @keywords internal
#' @noRd
normalize_vector <- function(x, method, reference = x, na.rm = TRUE) {
  # Check if all values are NA
  if (all(is.na(reference))) {
    return(rep(NA_real_, length(x)))
  }

  if (method == "minmax") {
    # Min-max to 0-100 scale
    min_val <- min(reference, na.rm = na.rm)
    max_val <- max(reference, na.rm = na.rm)

    if (is.na(min_val) || is.na(max_val) || max_val == min_val) {
      msg_warn("normalize_all_identical")
      return(rep(50, length(x)))
    }

    normalized <- ((x - min_val) / (max_val - min_val)) * 100
  } else if (method == "zscore") {
    # Z-score standardization
    mean_val <- mean(reference, na.rm = na.rm)
    sd_val <- sd(reference, na.rm = na.rm)

    if (is.na(sd_val) || sd_val == 0) {
      msg_warn("normalize_sd_zero")
      return(rep(0, length(x)))
    }

    normalized <- (x - mean_val) / sd_val
  } else if (method == "quantile") {
    # Quantile-based (percentile rank)
    # Remove NAs from reference for ranking
    ref_clean <- reference[!is.na(reference)]

    if (length(ref_clean) == 0) {
      return(rep(NA_real_, length(x)))
    }

    # Calculate percentile rank for each value
    normalized <- sapply(x, function(val) {
      if (is.na(val)) {
        return(NA_real_)
      }
      # Percentile rank: proportion of reference values <= current value
      rank <- sum(ref_clean <= val, na.rm = TRUE) / length(ref_clean)
      rank * 100
    })
  }

  normalized
}

#' Create composite index from multiple indicators
#'
#' Aggregates normalized indicators into a single composite score.
#'
#' @param data An \code{sf} object or data.frame with normalized indicators
#' @param indicators Character vector of indicator column names to include
#' @param weights Numeric vector of weights for each indicator (same length as indicators).
#'   If NULL, equal weights are used. Weights are automatically normalized to sum to 1.
#' @param name Character. Name for the composite index column. Default "composite_index".
#' @param aggregation Character. Aggregation method. Options:
#'   \itemize{
#'     \item "weighted_mean" - Weighted arithmetic mean (default)
#'     \item "geometric_mean" - Weighted geometric mean (good for multiplicative effects)
#'     \item "min" - Minimum value (conservative, limiting factor approach)
#'     \item "max" - Maximum value (optimistic)
#'   }
#' @param na.rm Logical. Remove NA values in aggregation? Default TRUE.
#' @param scale_to_100 Logical. Scale result to 0-100? Default TRUE for weighted_mean, FALSE otherwise.
#'
#' @return The input data with an added composite index column
#'
#' @details
#' The composite index combines multiple normalized indicators into a single score.
#'
#' \strong{Aggregation methods:}
#' \itemize{
#'   \item \strong{Weighted mean}: Standard linear combination, assumes indicators contribute additively
#'   \item \strong{Geometric mean}: Better for indicators with multiplicative relationships
#'   \item \strong{Min}: Conservative approach, final score limited by weakest indicator
#'   \item \strong{Max}: Optimistic approach, final score driven by strongest indicator
#' }
#'
#' \strong{Weights} are normalized internally to sum to 1. For example:
#' \code{weights = c(2, 1, 1)} becomes \code{c(0.5, 0.25, 0.25)}
#'
#' @examples
#' \dontrun{
#' # Equal weights
#' results <- create_composite_index(
#'   normalized_data,
#'   indicators = c("carbon_norm", "biodiversity_norm", "water_norm")
#' )
#'
#' # Custom weights (carbon 50\%, biodiversity 30\\%, water 20\\%)
#' results <- create_composite_index(
#'   normalized_data,
#'   indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
#'   weights = c(0.5, 0.3, 0.2),
#'   name = "ecosystem_health"
#' )
#'
#' # Geometric mean for multiplicative effects
#' results <- create_composite_index(
#'   normalized_data,
#'   indicators = c("carbon_norm", "water_norm"),
#'   aggregation = "geometric_mean"
#' )
#'
#' # Limiting factor approach
#' results <- create_composite_index(
#'   normalized_data,
#'   indicators = c("carbon_norm", "biodiversity_norm"),
#'   aggregation = "min",
#'   name = "conservation_potential"
#' )
#' }
#'
#' @seealso \code{\link{normalize_indicators}}
#'
#' @export
create_composite_index <- function(data,
                                   indicators,
                                   weights = NULL,
                                   name = "composite_index",
                                   aggregation = c("weighted_mean", "geometric_mean", "min", "max"),
                                   na.rm = TRUE,
                                   scale_to_100 = NULL) {
  # Match aggregation method
  aggregation <- match.arg(aggregation)

  # Default scale_to_100 based on method
  if (is.null(scale_to_100)) {
    scale_to_100 <- (aggregation == "weighted_mean")
  }

  # Validate indicators exist
  missing <- setdiff(indicators, names(data))
  if (length(missing) > 0) {
    missing_str <- paste(missing, collapse = ", ")
    msg_error("composite_missing", missing_str)
  }

  # Handle weights
  if (is.null(weights)) {
    # Equal weights
    weights <- rep(1 / length(indicators), length(indicators))
    n_ind <- length(indicators)
    msg_info("composite_equal_weights", n_ind)
  } else {
    # Validate weights
    if (length(weights) != length(indicators)) {
      msg_error("composite_weights_length")
    }

    if (any(weights < 0)) {
      msg_error("composite_weights_negative")
    }

    # Normalize weights to sum to 1
    weights <- weights / sum(weights)
  }

  # Extract indicator values as matrix
  # Drop geometry if sf object
  if (inherits(data, "sf")) {
    data_numeric <- sf::st_drop_geometry(data)
  } else {
    data_numeric <- data
  }

  indicator_matrix <- as.matrix(data_numeric[, indicators, drop = FALSE])

  # Calculate composite index
  if (aggregation == "weighted_mean") {
    # Weighted arithmetic mean
    composite <- apply(indicator_matrix, 1, function(row) {
      if (na.rm) {
        # Remove NAs and renormalize weights
        valid <- !is.na(row)
        if (sum(valid) == 0) {
          return(NA_real_)
        }
        sum(row[valid] * weights[valid]) / sum(weights[valid])
      } else {
        sum(row * weights)
      }
    })
  } else if (aggregation == "geometric_mean") {
    # Weighted geometric mean
    composite <- apply(indicator_matrix, 1, function(row) {
      if (na.rm) {
        row <- row[!is.na(row)]
        if (length(row) == 0) {
          return(NA_real_)
        }
      }

      if (any(row < 0, na.rm = TRUE)) {
        msg_warn("composite_negative_geomean")
        row <- abs(row)
      }

      # Weighted geometric mean: exp(sum(w * log(x)))
      exp(sum(weights[!is.na(row)] * log(row)))
    })
  } else if (aggregation == "min") {
    # Minimum (limiting factor)
    composite <- apply(indicator_matrix, 1, min, na.rm = na.rm)
  } else if (aggregation == "max") {
    # Maximum (optimistic)
    composite <- apply(indicator_matrix, 1, max, na.rm = na.rm)
  }

  # Scale to 0-100 if requested
  if (scale_to_100 && aggregation != "weighted_mean") {
    # For methods other than weighted_mean, scale the result
    min_val <- min(composite, na.rm = TRUE)
    max_val <- max(composite, na.rm = TRUE)

    if (max_val > min_val) {
      composite <- ((composite - min_val) / (max_val - min_val)) * 100
    }
  }

  # Add to data
  data[[name]] <- composite

  # Add metadata if nemeton object
  if (inherits(data, "nemeton_units")) {
    meta <- attr(data, "metadata")
    meta$composite_index_created_at <- Sys.time()
    meta$composite_index_name <- name
    meta$composite_index_method <- aggregation
    meta$composite_index_indicators <- indicators
    meta$composite_index_weights <- weights
    attr(data, "metadata") <- meta
  }

  n_ind <- length(indicators)
  msg_success("composite_created", name, n_ind)

  data
}

#' Invert indicator values
#'
#' Reverses the scale of an indicator (e.g., for indicators where low = good).
#'
#' @param data Data containing the indicator
#' @param indicators Character vector of indicator names to invert
#' @param scale Numeric. The scale maximum. Default 100 (assumes 0-100 scale).
#' @param suffix Character. Suffix for inverted columns. Default "_inv".
#' @param keep_original Logical. Keep original columns? Default FALSE.
#'
#' @return Data with inverted indicator columns
#'
#' @details
#' Some indicators have inverse relationships with "goodness":
#' \itemize{
#'   \item Accessibility: High = more human pressure (bad for wilderness)
#'   \item Fragmentation: High = more fragmented (bad for biodiversity)
#' }
#'
#' This function inverts the scale: \code{inverted = scale - original}
#'
#' @examples
#' \dontrun{
#' # Invert accessibility for wilderness index
#' data <- invert_indicator(
#'   data,
#'   indicators = "accessibility_norm",
#'   suffix = "_wilderness"
#' )
#' }
#'
#' @export
invert_indicator <- function(data,
                             indicators,
                             scale = 100,
                             suffix = "_inv",
                             keep_original = FALSE) {
  # Validate indicators exist
  missing <- setdiff(indicators, names(data))
  if (length(missing) > 0) {
    missing_str <- paste(missing, collapse = ", ")
    msg_error("composite_missing", missing_str)
  }

  # Invert each indicator
  for (ind in indicators) {
    inverted <- scale - data[[ind]]

    new_col <- paste0(ind, suffix)
    data[[new_col]] <- inverted

    if (!keep_original) {
      data[[ind]] <- NULL
    }
  }

  n_ind <- length(indicators)
  msg_success("invert_inverted", n_ind)

  data
}


# Indicateurs qui produisent NATIVEMENT une valeur 0-100 (haut = favorable) et
# pour lesquels le repli clamp(0,100) EST la normalisation correcte. Déclarés
# explicitement (spec 038) pour que le garde-fou de `normalize_indicator()`
# distingue un passthrough légitime d'un indicateur connu tombé au repli sans
# règle (le bug R6 z-score). Les indicateurs à `ref_max` ou à case spécial
# (c2/w3/s1/s2/r5/t3/b4/l3/r6/r7) n'atteignent JAMAIS le repli et ne figurent
# donc pas ici. TOUT nouvel indicateur 0-100 natif doit être ajouté à cette liste.
.NORMALIZE_NATIVE_0_100 <- c(
  "indicateur_b1_protection", "indicateur_b2_structure", "indicateur_b3_connectivite",
  "indicateur_w4_vpd",
  "indicateur_a1_couverture", "indicateur_a2_qualite_air", "indicateur_a3_microclimat",
  "indicateur_a4_tamponnement", "indicateur_a5_rafraichissement",
  "indicateur_f1_fertilite", "indicateur_f2_erosion",
  "indicateur_l1_sylvosphere", "indicateur_l2_fragmentation",
  "indicateur_t1_anciennete", "indicateur_t2_changement",
  "indicateur_r1_feu", "indicateur_r2_tempete", "indicateur_r3_secheresse",
  "indicateur_r4_abroutissement",
  "indicateur_p3_qualite_bois",
  "indicateur_n1_distance", "indicateur_n2_continuite", "indicateur_n3_naturalite"
)

#' Normalize a single indicator to 0-100 scale
#'
#' Converts raw indicator values to a common 0-100 scale using
#' indicator-specific reference maxima and special handling rules.
#'
#' @param indicator Character. Indicator name (NMT convention).
#' @param values Numeric vector. Raw indicator values.
#'
#' @return Numeric vector. Normalized values (0-100).
#'
#' @export
# Indicateurs pour lesquels `normalize_indicator()` applique une règle EXPLICITE
# (ref_max, échelle dédiée, inversion de sens). Hors de cette liste et hors de
# `.NORMALIZE_NATIVE_0_100`, la normalisation se réduit à un écrêtage naïf — ce
# que `create_family_index()` signale. Déduire la présence d'une règle en
# comparant les valeurs ne marche pas : quand la règle sature (C1 à 320 tC/ha,
# S3 à 271 900 habitants), son résultat est indistinguable de l'écrêtage.
.NORMALIZE_RULED <- c(
  "indicateur_c1_biomasse", "indicateur_c2_ndvi",
  "indicateur_w1_reseau", "indicateur_w2_zones_humides", "indicateur_w3_humidite",
  "indicateur_s1_routes", "indicateur_s2_bati", "indicateur_s3_population",
  "indicateur_p1_volume", "indicateur_p2_station",
  "indicateur_e1_bois_energie", "indicateur_e2_evitement",
  "indicateur_r5_deperissement", "indicateur_t3_coupes_rases",
  "indicateur_r6_sensibilite", "indicateur_r7_gel",
  "indicateur_b4_div_spectrale", "indicateur_l3_het_spectrale",
  "sensibilite_score"
)

# TRUE quand la colonne est ramenée sur 0-100 par une règle explicite ou par
# déclaration (« native 0-100 »), les deux écritures étant acceptées.
.normalize_has_rule <- function(indicator) {
  ind <- .normalize_resolve_alias(indicator)
  ind %in% .NORMALIZE_RULED || ind %in% .NORMALIZE_NATIVE_0_100
}

# Code court -> nom long canonique (`P1` -> `indicateur_p1_volume`).
#
# `create_family_index()` accepte les deux écritures — le motif `^C[0-9]` est
# même sa PREMIÈRE stratégie de sélection — mais les règles ci-dessous sont
# indexées sur les noms longs. Un `P1` en m3/ha tombait donc sur l'écrêtage
# naïf : 400 m3/ha rendait 100 au lieu de 50 (ref_max 800), et 75 tC/ha en `C1`
# rendait 75 au lieu de 50. Le score de famille était faux sans un mot, pour la
# raison même que ce brief cherchait ailleurs.
.normalize_resolve_alias <- function(indicator) {
  if (length(indicator) != 1L || is.na(indicator)) return(indicator)
  if (grepl("^indicateur_", indicator)) return(indicator)
  if (!grepl("^[A-Za-z][0-9]+$", indicator)) return(indicator)
  longs <- get_all_column_names()
  shorts <- toupper(sub("^indicateur_([a-z][0-9]+)_.*$", "\\1", longs))
  hit <- longs[shorts == toupper(indicator)]
  if (length(hit) == 1L) hit else indicator
}

normalize_indicator <- function(indicator, values) {
  # Les deux écritures (courte et longue) suivent la même règle.
  indicator <- .normalize_resolve_alias(indicator)

  ref_max <- switch(indicator,
    "indicateur_c1_biomasse" = 150,
    "indicateur_c2_ndvi" = NULL,
    "indicateur_w1_reseau" = 50,
    "indicateur_w2_zones_humides" = 5,
    "indicateur_w3_humidite" = NULL,
    "indicateur_s1_routes" = NULL,
    "indicateur_s2_bati" = NULL,
    "indicateur_s3_population" = 10000,
    "indicateur_p1_volume" = 800,
    "indicateur_p2_station" = 15,
    "indicateur_e1_bois_energie" = 0.3,
    "indicateur_e2_evitement" = 0.75,
    NULL
  )

  # TWI: rescale [2.5, 4.5] -> [0, 100]
  if (indicator == "indicateur_w3_humidite") {
    return(pmin(100, pmax(0, (values - 2.5) / 2 * 100)))
  }

  # NDVI: scale 0-1 -> 0-100
  if (indicator == "indicateur_c2_ndvi") {
    return(pmin(100, pmax(0, values * 100)))
  }

  # Distance indicators: inverse (closer = higher score)
  if (indicator %in% c("indicateur_s1_routes", "indicateur_s2_bati")) {
    return(pmin(100, pmax(0, 100 * (1 - values / 2000))))
  }

  # R5 dépérissement: the only family indicator oriented "high = bad"
  # (more dieback). Its raw value (indicateur_r5_deperissement(), 0-100,
  # high = severe) is inverted here so its radar / famille_risque
  # contribution stays "high = good" like R1-R4. The raw indicator
  # function and its callers are unchanged — only the normalized radar
  # value is flipped (cf. spec 008 / indicator-config R5 sens).
  if (indicator %in% c("indicateur_r5_deperissement", "R5")) {
    return(pmin(100, pmax(0, 100 - values)))
  }

  # T3 coupes rases: like R5, oriented "high = bad" (more recent clear-cut
  # pressure). Raw value (indicateur_t3_coupes_rases(), 0-100, high = more
  # clear-cutting) is inverted so its radar / famille_temporelle
  # contribution stays "high = good" like T1/T2 (cf. spec 030).
  if (indicator %in% c("indicateur_t3_coupes_rases", "T3")) {
    return(pmin(100, pmax(0, 100 - values)))
  }

  # R6 microclimate sensitivity: indicateur_r6_sensibilite() and the reGénération
  # `sensibilite_score` already produce a bounded 0-100 (high = favorable = less
  # sensitive, cf. .MICRO_BOUNDS$r6). Explicit passthrough clamp so R6 never falls
  # back to the naive branch — the historical bug was the reGénération *z-score*
  # (`sensibilite`, unbounded ~[-4,4]) being injected here and mangled; the fix is
  # to feed the 0-100 `sensibilite_score` instead (spec 038).
  if (indicator %in% c("indicateur_r6_sensibilite", "R6", "sensibilite_score")) {
    return(pmin(100, pmax(0, values)))
  }

  # R7 late frost: indicateur_r7_gel() already 0-100 (high = favorable, little
  # late-frost exposure). Explicit passthrough clamp, no longer relying on the
  # naive fallback (spec 038).
  if (indicator %in% c("indicateur_r7_gel", "R7")) {
    return(pmin(100, pmax(0, values)))
  }

  # B4 spectral alpha diversity (Shannon of spectral species): high = good.
  # Provisional upper bound log(nbclusters) with the biodivMapR default of
  # 50 clusters (spec 028 D3 — recalibrate empirically after the first
  # real run).
  if (indicator %in% c("indicateur_b4_div_spectrale", "B4")) {
    return(pmin(100, pmax(0, values / log(50) * 100)))
  }

  # L3 spectral beta diversity (Bray-Curtis turnover / landscape mosaic
  # heterogeneity): high = good (spec 028 D1). Provisional scale assumes a
  # dissimilarity in [0, 1] (spec 028 D3 — recalibrate once the biodivMapR
  # beta output range is confirmed on real data).
  if (indicator %in% c("indicateur_l3_het_spectrale", "L3")) {
    return(pmin(100, pmax(0, values * 100)))
  }

  if (!is.null(ref_max)) {
    values <- pmin(100, pmax(0, values / ref_max * 100))
  } else {
    # Repli clamp(0,100) : correct pour les indicateurs déjà 0-100 (déclarés dans
    # .NORMALIZE_NATIVE_0_100). Filet spec 038 : un indicateur CONNU (colonne de
    # INDICATOR_FAMILIES) qui tombe ici sans être déclaré 0-100 natif manque
    # probablement d'une règle de normalisation (le bug R6 z-score) — on avertit
    # au lieu de mutiler le score en silence.
    if (indicator %in% get_all_column_names() &&
        !indicator %in% .NORMALIZE_NATIVE_0_100) {
      cli::cli_warn(c(
        "normalize_indicator(): no explicit 0-100 rule for {.val {indicator}}; using naive clamp(0, 100).",
        i = "Add a case in {.fun normalize_indicator} or declare it in {.code .NORMALIZE_NATIVE_0_100} (spec 038)."))
    }
    values <- pmin(100, pmax(0, values))
  }

  values
}
