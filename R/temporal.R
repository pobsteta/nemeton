#' Multi-Temporal Analysis Infrastructure
#'
#' Functions for managing multi-period datasets and calculating temporal change rates.
#'
#' @name temporal
#' @keywords internal
NULL

#' Create Multi-Period Temporal Dataset
#'
#' Combines multiple nemeton_units objects from different time periods into
#' a temporal dataset structure for longitudinal analysis.
#'
#' @param periods Named list of nemeton_units objects, one per period.
#'   Names should be period labels (e.g., "2015", "2020").
#' @param dates Character vector of ISO dates corresponding to each period
#'   (e.g., c("2015-01-01", "2020-01-01")). Optional.
#' @param labels Character vector of descriptive labels for periods
#'   (e.g., c("Baseline", "Current")). Optional, defaults to period names.
#' @param id_column Character. Name of the column containing unit IDs.
#'   Default "parcel_id".
#'
#' @return A nemeton_temporal object (list) with components:
#'   \describe{
#'     \item{periods}{List of nemeton_units objects}
#'     \item{metadata}{List with dates, period_labels, alignment info}
#'   }
#'
#' @export
#' @examples
#' \dontrun{
#' # Load demo data for two periods
#' data(massif_demo_units)
#' results_2015 <- nemeton_compute(massif_demo_units, layers_2015, indicators = "C1")
#' results_2020 <- nemeton_compute(massif_demo_units, layers_2020, indicators = "C1")
#'
#' # Create temporal dataset
#' temporal <- nemeton_temporal(
#'   periods = list("2015" = results_2015, "2020" = results_2020),
#'   dates = c("2015-01-01", "2020-01-01"),
#'   labels = c("Baseline", "Current")
#' )
#' }
nemeton_temporal <- function(periods,
                              dates = NULL,
                              labels = NULL,
                              id_column = "parcel_id") {
  # Validate inputs
  if (length(periods) == 0) {
    stop("No periods provided", call. = FALSE)
  }

  # Check all periods are sf objects
  periods_are_sf <- vapply(periods, function(x) inherits(x, "sf"), logical(1))
  if (!all(periods_are_sf)) {
    stop("All periods must be sf objects", call. = FALSE)
  }

  # Validate dates if provided
  if (!is.null(dates)) {
    if (length(dates) != length(periods)) {
      stop("Length of dates must match number of periods", call. = FALSE)
    }
    dates <- as.Date(dates)
  } else {
    # Default: use period names as dates if they look like years
    period_names <- names(periods)
    if (!is.null(period_names) && all(grepl("^[0-9]{4}$", period_names))) {
      dates <- as.Date(paste0(period_names, "-01-01"))
    }
  }

  # Set labels
  if (is.null(labels)) {
    labels <- names(periods)
    if (is.null(labels)) {
      labels <- paste0("Period", seq_along(periods))
    }
  }

  # Check unit alignment across periods
  n_periods <- length(periods)
  n_units_per_period <- vapply(periods, nrow, integer(1))

  # Extract IDs from each period
  period_ids <- lapply(periods, function(p) {
    if (id_column %in% names(p)) {
      as.character(p[[id_column]])
    } else {
      # Generate IDs if column doesn't exist
      seq_len(nrow(p))
    }
  })

  # Find common units
  all_ids <- unique(unlist(period_ids))
  alignment <- data.frame(
    unit_id = all_ids,
    stringsAsFactors = FALSE
  )

  for (i in seq_along(periods)) {
    col_name <- paste0("in_", names(periods)[i])
    alignment[[col_name]] <- alignment$unit_id %in% period_ids[[i]]
  }

  # Count units present in all periods
  n_complete <- sum(rowSums(alignment[, -1, drop = FALSE]) == n_periods)
  n_incomplete <- nrow(alignment) - n_complete

  # Warn if misalignment
  if (n_incomplete > 0) {
    msg_warn("temporal_alignment_warning", n_incomplete)
  }

  # Build temporal object
  temporal <- list(
    periods = periods,
    metadata = list(
      dates = dates,
      period_labels = labels,
      alignment = alignment,
      n_periods = n_periods,
      n_units = nrow(alignment),
      n_complete = n_complete
    )
  )

  class(temporal) <- c("nemeton_temporal", "list")

  # Success message
  msg_info("temporal_created", n_periods, nrow(alignment))

  temporal
}

#' Calculate Change Rates Between Periods
#'
#' Computes annual change rates (absolute and relative) for indicators
#' across temporal periods.
#'
#' @param temporal A nemeton_temporal object created by \code{\link{nemeton_temporal}}.
#' @param indicators Character vector of indicator names to analyze.
#'   Default "all" uses all indicators present in the temporal dataset.
#' @param period_start Character. Label of starting period. Default uses first period.
#' @param period_end Character. Label of ending period. Default uses last period.
#' @param type Character. Type of change rate: "absolute", "relative", or "both".
#'   Default "both".
#'
#' @return A nemeton_units sf object with added columns:
#'   \describe{
#'     \item{<indicator>_rate_abs}{Absolute change per year (e.g., tC/ha/year)}
#'     \item{<indicator>_rate_rel}{Relative change per year (\%/year)}
#'   }
#'
#' @export
#' @examples
#' \dontrun{
#' # Calculate carbon change rates
#' rates <- calculate_change_rate(
#'   temporal,
#'   indicators = c("C1", "W3"),
#'   type = "both"
#' )
#'
#' # View change rates
#' summary(rates[, c("C1_rate_abs", "C1_rate_rel")])
#' }
calculate_change_rate <- function(temporal,
                                   indicators = "all",
                                   period_start = NULL,
                                   period_end = NULL,
                                   type = c("both", "absolute", "relative")) {
  # Validate input
  if (!inherits(temporal, "nemeton_temporal")) {
    stop("temporal must be a nemeton_temporal object", call. = FALSE)
  }

  type <- match.arg(type)

  # Determine start and end periods
  period_names <- names(temporal$periods)

  if (is.null(period_start)) {
    period_start <- period_names[1]
  }

  if (is.null(period_end)) {
    period_end <- period_names[length(period_names)]
  }

  # Validate period names
  if (!period_start %in% period_names) {
    msg_error("temporal_period_missing", period_start)
  }

  if (!period_end %in% period_names) {
    msg_error("temporal_period_missing", period_end)
  }

  # Get periods
  data_start <- temporal$periods[[period_start]]
  data_end <- temporal$periods[[period_end]]

  # Calculate time difference
  if (!is.null(temporal$metadata$dates)) {
    idx_start <- which(period_names == period_start)
    idx_end <- which(period_names == period_end)
    time_diff <- as.numeric(difftime(
      temporal$metadata$dates[idx_end],
      temporal$metadata$dates[idx_start],
      units = "days"
    )) / 365.25  # Years
  } else {
    # Try to parse years from period names
    year_start <- as.numeric(period_start)
    year_end <- as.numeric(period_end)
    if (is.na(year_start) || is.na(year_end)) {
      time_diff <- 1  # Default to 1 year if can't determine
      warning("Cannot determine time difference, assuming 1 year", call. = FALSE)
    } else {
      time_diff <- year_end - year_start
    }
  }

  # Detect indicators if "all"
  if (length(indicators) == 1 && indicators == "all") {
    # Find common indicator columns (numeric only)
    cols_start <- names(data_start)
    cols_end <- names(data_end)
    common_cols <- intersect(cols_start, cols_end)

    # Filter to numeric columns that look like indicators
    indicators <- common_cols[vapply(common_cols, function(col) {
      is.numeric(data_start[[col]]) &&
        !col %in% c("geometry", "geom", "parcel_id", "unit_id")
    }, logical(1))]
  }

  # Merge data by geometry or ID
  # Use the end period as base (to preserve most recent geometry)
  result <- data_end

  # Calculate change rates for each indicator
  for (ind in indicators) {
    if (!ind %in% names(data_start) || !ind %in% names(data_end)) {
      warning(sprintf("Indicator '%s' not found in both periods, skipping", ind),
              call. = FALSE)
      next
    }

    values_start <- data_start[[ind]]
    values_end <- data_end[[ind]]

    # Absolute change rate
    if (type %in% c("both", "absolute")) {
      abs_rate <- (values_end - values_start) / time_diff
      result[[paste0(ind, "_rate_abs")]] <- abs_rate
    }

    # Relative change rate (%)
    if (type %in% c("both", "relative")) {
      rel_rate <- ((values_end / values_start) - 1) * 100 / time_diff
      result[[paste0(ind, "_rate_rel")]] <- rel_rate
    }
  }

  # Success message
  msg_info("temporal_change_calculated", length(indicators))

  result
}

#' Print Method for nemeton_temporal Objects
#'
#' @param x A nemeton_temporal object
#' @param ... Additional arguments (unused)
#'
#' @return Invisible x
#' @export
#' @keywords internal
print.nemeton_temporal <- function(x, ...) {
  cat("nemeton_temporal object\n")
  cat(sprintf("  %d periods: %s\n",
              x$metadata$n_periods,
              paste(x$metadata$period_labels, collapse = ", ")))
  cat(sprintf("  %d units tracked across periods\n", x$metadata$n_units))

  if (!is.null(x$metadata$dates)) {
    date_range <- range(x$metadata$dates, na.rm = TRUE)
    cat(sprintf("  Date range: %s to %s\n",
                format(date_range[1], "%Y-%m-%d"),
                format(date_range[2], "%Y-%m-%d")))
  }

  if (x$metadata$n_complete < x$metadata$n_units) {
    cat(sprintf("  ⚠ %d units not present in all periods\n",
                x$metadata$n_units - x$metadata$n_complete))
  }

  # List indicators (from first period)
  if (length(x$periods) > 0) {
    first_period <- x$periods[[1]]
    indicator_cols <- names(first_period)[vapply(names(first_period), function(col) {
      is.numeric(first_period[[col]]) &&
        !col %in% c("geometry", "geom", "parcel_id", "unit_id")
    }, logical(1))]

    if (length(indicator_cols) > 0) {
      cat(sprintf("  Indicators: %s\n", paste(indicator_cols, collapse = ", ")))
    }
  }

  invisible(x)
}

#' Summary Method for nemeton_temporal Objects
#'
#' @param object A nemeton_temporal object
#' @param ... Additional arguments (unused)
#'
#' @return Invisible object
#' @export
#' @keywords internal
summary.nemeton_temporal <- function(object, ...) {
  print(object)
  cat("\n")

  # Summary statistics per period
  cat("Period summaries:\n")
  for (i in seq_along(object$periods)) {
    period_name <- names(object$periods)[i]
    period_label <- object$metadata$period_labels[i]
    period_data <- object$periods[[i]]

    cat(sprintf("\n  Period %d: %s (%s)\n", i, period_label, period_name))
    cat(sprintf("    Units: %d\n", nrow(period_data)))

    # Numeric columns
    numeric_cols <- names(period_data)[vapply(names(period_data), function(col) {
      is.numeric(period_data[[col]]) &&
        !col %in% c("geometry", "geom", "parcel_id", "unit_id")
    }, logical(1))]

    if (length(numeric_cols) > 0) {
      cat("    Indicator ranges:\n")
      for (col in numeric_cols) {
        values <- period_data[[col]]
        cat(sprintf("      %s: [%.2f, %.2f] (mean: %.2f)\n",
                    col,
                    min(values, na.rm = TRUE),
                    max(values, na.rm = TRUE),
                    mean(values, na.rm = TRUE)))
      }
    }
  }

  invisible(object)
}
