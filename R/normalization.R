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
                                  reference_data = NULL) {
  # Match method argument
  method <- match.arg(method)

  # Auto-detect indicators if not specified
  if (is.null(indicators)) {
    # Common indicator names
    possible_indicators <- c(
      "carbon", "biodiversity", "water",
      "fragmentation", "accessibility"
    )
    indicators <- intersect(names(data), possible_indicators)

    if (length(indicators) == 0) {
      msg_error("viz_no_indicators")
      cli::cli_inform("i" = msg("viz_specify_indicators"))
      cli::cli_inform(">" = "Example: indicators = c('carbon', 'water')")
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

    # Optionally remove original
    if (!keep_original) {
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
  if (method == "minmax") {
    # Min-max to 0-100 scale
    min_val <- min(reference, na.rm = na.rm)
    max_val <- max(reference, na.rm = na.rm)

    if (max_val == min_val) {
      msg_warn("normalize_all_identical")
      return(rep(50, length(x)))
    }

    normalized <- ((x - min_val) / (max_val - min_val)) * 100

  } else if (method == "zscore") {
    # Z-score standardization
    mean_val <- mean(reference, na.rm = na.rm)
    sd_val <- sd(reference, na.rm = na.rm)

    if (sd_val == 0) {
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
#' # Custom weights (carbon 50%, biodiversity 30%, water 20%)
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
        if (sum(valid) == 0) return(NA_real_)
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
        if (length(row) == 0) return(NA_real_)
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
