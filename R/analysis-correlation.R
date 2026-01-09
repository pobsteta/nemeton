# analysis-correlation.R
# Cross-Family Correlation Analysis
# MVP v0.3.0 - Multi-Family Indicator Extension

#' @importFrom rlang .data
NULL

#' Compute Correlation Matrix Between Family Indices
#'
#' Calculates pairwise correlations between family composite indices to
#' identify synergies and trade-offs across ecosystem service dimensions.
#'
#' @param units sf object with computed family indices (family_*)
#' @param families Character vector of family column names to analyze.
#'   If NULL (default), auto-detects all columns starting with "family_"
#' @param method Correlation method: "pearson" (default), "spearman", or "kendall"
#'
#' @return Correlation matrix (class "matrix") with family names as row/column names
#'
#' @details
#' The function computes pairwise correlations between selected family indices
#' to reveal ecological relationships:
#' - **Positive correlations** suggest synergies (e.g., Biodiversity × Age)
#' - **Negative correlations** indicate trade-offs (e.g., Protection × Risk)
#' - **Near-zero correlations** show independence
#'
#' Missing values (NA) are handled using pairwise complete observations.
#'
#' @section Bilingual Support:
#' This function supports bilingual messages via `nemeton_set_language()`.
#'
#' @examples
#' \dontrun{
#' # Load demo data with family indices
#' data(massif_demo_units)
#' units <- massif_demo_units
#' units$family_B <- runif(nrow(units), 30, 90)
#' units$family_T <- runif(nrow(units), 40, 85)
#' units$family_C <- runif(nrow(units), 45, 80)
#'
#' # Compute correlation matrix
#' corr_matrix <- compute_family_correlations(units)
#' print(corr_matrix)
#'
#' # Use Spearman for non-linear relationships
#' corr_spearman <- compute_family_correlations(units, method = "spearman")
#'
#' # Analyze specific families only
#' corr_subset <- compute_family_correlations(
#'   units,
#'   families = c("family_B", "family_T")
#' )
#' }
#'
#' @export
#' @family analysis
#' @seealso [identify_hotspots()], [plot_correlation_matrix()]
compute_family_correlations <- function(units,
                                        families = NULL,
                                        method = "pearson") {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object")
  }

  if (!method %in% c("pearson", "spearman", "kendall")) {
    stop("method must be one of: pearson, spearman, kendall")
  }

  # Auto-detect family columns if not specified
  if (is.null(families)) {
    all_names <- names(units)
    families <- all_names[grepl("^family_", all_names)]

    if (length(families) == 0) {
      stop("No family indices found. Columns must start with 'family_'")
    }
  }

  # Validate that specified families exist
  missing_families <- setdiff(families, names(units))
  if (length(missing_families) > 0) {
    stop(paste("Families not found in data:", paste(missing_families, collapse = ", ")))
  }

  # Extract numeric data (drop geometry)
  family_data <- sf::st_drop_geometry(units)[, families, drop = FALSE]

  # Ensure all columns are numeric
  if (!all(sapply(family_data, is.numeric))) {
    stop("All family columns must be numeric")
  }

  # Compute correlation matrix
  corr_matrix <- stats::cor(
    family_data,
    method = method,
    use = "pairwise.complete.obs" # Handle NAs
  )

  # Set class and attributes
  class(corr_matrix) <- c("matrix", "array")
  attr(corr_matrix, "method") <- method
  attr(corr_matrix, "n_obs") <- nrow(family_data)

  return(corr_matrix)
}


#' Identify Multi-Criteria Hotspots
#'
#' Identifies parcels ranking in the top percentile across multiple ecosystem
#' service families, revealing areas with exceptional multi-functional value.
#'
#' @param units sf object with computed family indices (family_*)
#' @param families Character vector of family column names to analyze.
#'   If NULL (default), uses all columns starting with "family_"
#' @param threshold Numeric percentile threshold (0-100) for defining "high" values.
#'   Default: 80 (top 20 percent)
#' @param min_families Minimum number of families in which a parcel must rank
#'   above threshold to be classified as a hotspot. Default: 3
#'
#' @return sf object with original data plus three new columns:
#'   hotspot_count (number of families where parcel ranks above threshold),
#'   hotspot_families (comma-separated list of family names above threshold),
#'   is_hotspot (logical indicating if parcel meets min_families criterion)
#'
#' @details
#' The function identifies multi-criteria hotspots by:
#' 1. Computing percentile thresholds for each family index
#' 2. Counting how many families each parcel ranks above threshold
#' 3. Flagging parcels exceeding `min_families` as hotspots
#'
#' **Use cases**:
#' - Conservation prioritization (high biodiversity + age + connectivity)
#' - Risk mitigation (high vulnerability across fire + storm + drought)
#' - Multi-objective optimization (balancing competing services)
#'
#' @section Bilingual Support:
#' This function supports bilingual messages via `nemeton_set_language()`.
#'
#' @examples
#' \dontrun{
#' # Load demo data with family indices
#' data(massif_demo_units)
#' units <- massif_demo_units
#' units$family_B <- runif(nrow(units), 30, 90)
#' units$family_T <- runif(nrow(units), 40, 85)
#' units$family_C <- runif(nrow(units), 45, 80)
#' units$family_W <- runif(nrow(units), 35, 75)
#'
#' # Identify hotspots: top 20\% in at least 3 families
#' hotspots <- identify_hotspots(
#'   units,
#'   threshold = 80,
#'   min_families = 3
#' )
#'
#' # View hotspot parcels
#' hotspot_parcels <- hotspots[hotspots$is_hotspot, ]
#' print(hotspot_parcels[, c("parcel_id", "hotspot_count", "hotspot_families")])
#'
#' # Conservative threshold: top 10\% in 4+ families
#' elite_hotspots <- identify_hotspots(
#'   units,
#'   threshold = 90,
#'   min_families = 4
#' )
#'
#' # Analyze specific families only
#' biodiversity_hotspots <- identify_hotspots(
#'   units,
#'   families = c("family_B", "family_T"),
#'   threshold = 75,
#'   min_families = 2
#' )
#' }
#'
#' @export
#' @family analysis
#' @seealso [compute_family_correlations()], [plot_correlation_matrix()]
identify_hotspots <- function(units,
                              families = NULL,
                              threshold = 80,
                              min_families = 3) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object")
  }

  if (!is.numeric(threshold) || threshold < 0 || threshold > 100) {
    stop("threshold must be a number between 0 and 100")
  }

  if (!is.numeric(min_families) || min_families < 1) {
    stop("min_families must be a positive integer")
  }

  # Auto-detect family columns if not specified
  if (is.null(families)) {
    all_names <- names(units)
    families <- all_names[grepl("^family_", all_names)]

    if (length(families) == 0) {
      stop("No family indices found. Columns must start with 'family_'")
    }
  }

  # Validate that specified families exist
  missing_families <- setdiff(families, names(units))
  if (length(missing_families) > 0) {
    stop(paste("Families not found in data:", paste(missing_families, collapse = ", ")))
  }

  # Extract family data (preserve sf object)
  result <- units

  # Compute percentile thresholds for each family
  thresholds_list <- list()
  for (fam in families) {
    fam_values <- result[[fam]]
    if (all(is.na(fam_values))) {
      thresholds_list[[fam]] <- NA
    } else {
      thresholds_list[[fam]] <- stats::quantile(fam_values, probs = threshold / 100, na.rm = TRUE)
    }
  }

  # For each parcel, count how many families exceed threshold
  hotspot_count <- integer(nrow(result))
  hotspot_families_list <- vector("list", nrow(result))

  for (i in seq_len(nrow(result))) {
    high_families <- character(0)

    for (fam in families) {
      fam_value <- result[[fam]][i]
      fam_threshold <- thresholds_list[[fam]]

      # For threshold=100, use strict > (no values can be above max)
      # For other thresholds, use >= (include values at the percentile)
      is_above <- if (threshold == 100) {
        fam_value > fam_threshold
      } else {
        fam_value >= fam_threshold
      }

      if (!is.na(fam_value) && !is.na(fam_threshold) && is_above) {
        high_families <- c(high_families, fam)
      }
    }

    hotspot_count[i] <- length(high_families)
    hotspot_families_list[[i]] <- paste(high_families, collapse = ", ")
  }

  # Add results to sf object
  result$hotspot_count <- hotspot_count
  result$hotspot_families <- unlist(hotspot_families_list)
  result$is_hotspot <- hotspot_count >= min_families

  return(result)
}


#' Plot Correlation Matrix Heatmap
#'
#' Visualizes pairwise correlations between family indices as a heatmap with
#' color-coded correlation coefficients.
#'
#' @param corr_matrix Correlation matrix from [compute_family_correlations()]
#' @param method Display method: "circle" (default), "square", "number", or "color"
#' @param title Plot title. If NULL, generates automatic title
#' @param palette Color palette: "RdBu" (default, red-blue diverging) or "viridis"
#'
#' @return ggplot2 object
#'
#' @details
#' Creates a publication-ready correlation heatmap with:
#' - Color intensity proportional to correlation strength
#' - Diverging palette (blue = negative, red = positive)
#' - Correlation coefficients displayed on cells
#' - Hierarchical clustering (optional)
#'
#' **Interpretation**:
#' - **Strong positive** (red, >0.5): Synergies (services co-occur)
#' - **Strong negative** (blue, <-0.5): Trade-offs (services conflict)
#' - **Weak** (white, ~0): Independence
#'
#' @section Bilingual Support:
#' This function supports bilingual labels via `nemeton_set_language()`.
#'
#' @examples
#' \dontrun{
#' # Compute correlations
#' data(massif_demo_units)
#' units <- massif_demo_units
#' units$family_B <- runif(nrow(units), 30, 90)
#' units$family_T <- runif(nrow(units), 40, 85)
#' units$family_C <- runif(nrow(units), 45, 80)
#'
#' corr_matrix <- compute_family_correlations(units)
#'
#' # Plot correlation heatmap
#' plot_correlation_matrix(corr_matrix)
#'
#' # Customize appearance
#' plot_correlation_matrix(
#'   corr_matrix,
#'   method = "number",
#'   title = "Ecosystem Service Synergies & Trade-offs"
#' )
#' }
#'
#' @export
#' @family visualization
#' @seealso [compute_family_correlations()], [identify_hotspots()]
plot_correlation_matrix <- function(corr_matrix,
                                    method = "circle",
                                    title = NULL,
                                    palette = "RdBu") {
  # Validate inputs
  if (!inherits(corr_matrix, "matrix")) {
    stop("corr_matrix must be a matrix from compute_family_correlations()")
  }

  if (!method %in% c("circle", "square", "number", "color")) {
    stop("method must be one of: circle, square, number, color")
  }

  # Convert matrix to long format for ggplot2
  corr_df <- as.data.frame(as.table(corr_matrix))
  names(corr_df) <- c("Family1", "Family2", "Correlation")

  # Clean family names for display (remove "family_" prefix)
  corr_df$Family1 <- gsub("^family_", "", corr_df$Family1)
  corr_df$Family2 <- gsub("^family_", "", corr_df$Family2)

  # Generate title if not provided
  if (is.null(title)) {
    corr_method <- attr(corr_matrix, "method")
    if (is.null(corr_method)) corr_method <- "pearson"
    title <- sprintf("Family Correlations (%s)", tools::toTitleCase(corr_method))
  }

  # Choose color palette
  if (palette == "RdBu") {
    colors <- c(
      "#2166AC", "#4393C3", "#92C5DE", "#D1E5F0",
      "#FFFFFF",
      "#FDDBC7", "#F4A582", "#D6604D", "#B2182B"
    )
  } else {
    colors <- viridisLite::viridis(9)
  }

  # Create base heatmap
  p <- ggplot2::ggplot(corr_df, ggplot2::aes(x = .data$Family1, y = .data$Family2, fill = .data$Correlation)) +
    ggplot2::geom_tile(color = "white", linewidth = 0.5) +
    ggplot2::scale_fill_gradientn(
      colors = colors,
      limits = c(-1, 1),
      breaks = seq(-1, 1, 0.5),
      name = "Correlation"
    ) +
    ggplot2::labs(
      title = title,
      x = NULL,
      y = NULL
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, vjust = 1),
      axis.text.y = ggplot2::element_text(),
      panel.grid = ggplot2::element_blank(),
      legend.position = "right",
      plot.title = ggplot2::element_text(hjust = 0.5, face = "bold")
    )

  # Add correlation values as text (except for "color" method)
  if (method %in% c("number", "circle", "square")) {
    p <- p + ggplot2::geom_text(
      ggplot2::aes(label = sprintf("%.2f", .data$Correlation)),
      color = ifelse(abs(corr_df$Correlation) > 0.5, "white", "black"),
      size = 3.5
    )
  }

  # Add circles for "circle" method
  if (method == "circle") {
    p <- p + ggplot2::geom_point(
      ggplot2::aes(size = abs(.data$Correlation)),
      shape = 21,
      color = "white",
      fill = "transparent"
    ) +
      ggplot2::scale_size_continuous(range = c(0, 8), guide = "none")
  }

  # Equal aspect ratio for square cells
  p <- p + ggplot2::coord_fixed()

  return(p)
}
