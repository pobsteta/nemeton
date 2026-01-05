#' Create thematic maps for indicators
#'
#' Generates publication-ready maps visualizing indicator values across spatial units.
#'
#' @param data An \code{sf} object with indicator values
#' @param indicators Character vector of indicator column names to plot.
#'   If NULL and multiple indicators present, creates faceted plot.
#' @param palette Character. Color palette to use. Options:
#'   \itemize{
#'     \item "viridis" - Perceptually uniform, colorblind-friendly (default)
#'     \item "RdYlGn" - Red-Yellow-Green diverging (low-medium-high)
#'     \item "YlOrRd" - Yellow-Orange-Red sequential
#'     \item "Greens" - Green sequential
#'     \item "Blues" - Blue sequential
#'   }
#' @param direction Numeric. Direction of color scale: 1 (default) or -1 (reversed)
#' @param title Character. Plot title. If NULL, auto-generated.
#' @param legend_title Character. Legend title. If NULL, uses "Value" or indicator name.
#' @param breaks Numeric vector. Manual breaks for color scale. If NULL, automatic.
#' @param labels Character vector. Labels for breaks. Same length as breaks.
#' @param alpha Numeric. Transparency (0-1). Default 0.9.
#' @param border_color Character. Border color for polygons. Default "white".
#' @param border_size Numeric. Border line width. Default 0.3.
#' @param facet Logical. Create faceted plot for multiple indicators? Default TRUE.
#' @param ncol Integer. Number of columns for faceted plot. Default 2.
#' @param base_size Numeric. Base font size for theme. Default 11.
#'
#' @return A \code{ggplot} object
#'
#' @details
#' Creates thematic choropleth maps using ggplot2. Supports:
#' \itemize{
#'   \item Single indicator maps
#'   \item Multi-indicator faceted maps
#'   \item Custom color palettes
#'   \item Flexible styling
#' }
#'
#' The function uses \code{geom_sf()} for spatial rendering and applies
#' perceptually uniform color scales by default (viridis).
#'
#' @examples
#' \dontrun{
#' # Single indicator map
#' plot_indicators_map(
#'   results,
#'   indicators = "carbon",
#'   palette = "Greens",
#'   title = "Carbon Stock Distribution"
#' )
#'
#' # Multiple indicators (faceted)
#' plot_indicators_map(
#'   normalized,
#'   indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
#'   palette = "viridis",
#'   facet = TRUE,
#'   ncol = 3
#' )
#'
#' # Composite index with custom breaks
#' plot_indicators_map(
#'   results,
#'   indicators = "ecosystem_health",
#'   palette = "RdYlGn",
#'   breaks = c(0, 25, 50, 75, 100),
#'   labels = c("Low", "Medium-Low", "Medium-High", "High", "Very High")
#' )
#' }
#'
#' @export
plot_indicators_map <- function(data,
                                 indicators = NULL,
                                 palette = c("viridis", "RdYlGn", "YlOrRd", "Greens", "Blues"),
                                 direction = 1,
                                 title = NULL,
                                 legend_title = NULL,
                                 breaks = NULL,
                                 labels = NULL,
                                 alpha = 0.9,
                                 border_color = "white",
                                 border_size = 0.3,
                                 facet = TRUE,
                                 ncol = 2,
                                 base_size = 11) {
  # Validate input
  if (!inherits(data, "sf")) {
    msg_error("viz_not_sf")
  }

  # Match palette
  palette <- match.arg(palette)

  # Auto-detect indicators if not specified
  if (is.null(indicators)) {
    possible_indicators <- c(
      "carbon", "biodiversity", "water", "fragmentation", "accessibility",
      "carbon_norm", "biodiversity_norm", "water_norm",
      "fragmentation_norm", "accessibility_norm",
      "composite_index", "ecosystem_health", "wilderness_index"
    )
    indicators <- intersect(names(data), possible_indicators)

    if (length(indicators) == 0) {
      msg_error("viz_no_indicators")
      cli::cli_inform("i" = msg("viz_specify_indicators"))
      cli::cli_abort("")
    }

    if (length(indicators) > 1) {
      n_ind <- length(indicators)
      ind_list <- paste(indicators, collapse = ", ")
      msg_info("viz_detected", n_ind, ind_list)
    }
  }

  # Validate indicators exist
  missing <- setdiff(indicators, names(data))
  if (length(missing) > 0) {
    missing_str <- paste(missing, collapse = ", ")
    msg_error("viz_missing", missing_str)
  }

  # Prepare data for plotting
  if (length(indicators) == 1) {
    # Single indicator - simple plot
    plot_data <- data
    indicator_col <- indicators[1]

    # Create plot
    p <- ggplot2::ggplot(plot_data) +
      ggplot2::geom_sf(
        ggplot2::aes(fill = .data[[indicator_col]]),
        color = border_color,
        size = border_size,
        alpha = alpha
      )

    # Add color scale
    p <- add_color_scale(
      p,
      palette = palette,
      direction = direction,
      breaks = breaks,
      labels = labels,
      legend_title = legend_title %||% clean_indicator_name(indicator_col)
    )

    # Add title
    if (is.null(title)) {
      title <- sprintf("Map of %s", clean_indicator_name(indicator_col))
    }

  } else {
    # Multiple indicators - faceted plot
    if (!facet) {
      msg_warn("viz_multiple_no_facet")
      cli::cli_inform(">" = msg("viz_creating_facet"))
    }

    # Reshape data to long format for faceting
    plot_data <- reshape_for_facet(data, indicators)

    # Create faceted plot
    p <- ggplot2::ggplot(plot_data) +
      ggplot2::geom_sf(
        ggplot2::aes(fill = value),
        color = border_color,
        size = border_size,
        alpha = alpha
      ) +
      ggplot2::facet_wrap(
        ~ indicator,
        ncol = ncol,
        labeller = ggplot2::labeller(indicator = clean_indicator_name)
      )

    # Add color scale
    p <- add_color_scale(
      p,
      palette = palette,
      direction = direction,
      breaks = breaks,
      labels = labels,
      legend_title = legend_title %||% "Value"
    )

    # Add title
    if (is.null(title)) {
      title <- sprintf("Maps of %d indicators", length(indicators))
    }
  }

  # Apply theme
  p <- p +
    ggplot2::labs(title = title) +
    ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", hjust = 0.5),
      axis.text = ggplot2::element_text(size = ggplot2::rel(0.8)),
      legend.position = "right",
      panel.grid = ggplot2::element_blank()
    )

  p
}

#' Add color scale to plot
#'
#' Internal helper to add appropriate color scale based on palette.
#'
#' @param p ggplot object
#' @param palette Palette name
#' @param direction Direction (1 or -1)
#' @param breaks Manual breaks
#' @param labels Labels for breaks
#' @param legend_title Legend title
#'
#' @return ggplot object with color scale
#' @keywords internal
#' @noRd
add_color_scale <- function(p, palette, direction, breaks, labels, legend_title) {
  if (palette == "viridis") {
    p <- p + ggplot2::scale_fill_viridis_c(
      name = legend_title,
      option = "viridis",
      direction = direction,
      breaks = breaks,
      labels = labels
    )
  } else {
    # ColorBrewer palettes
    p <- p + ggplot2::scale_fill_distiller(
      name = legend_title,
      palette = palette,
      direction = direction,
      breaks = breaks,
      labels = labels
    )
  }

  p
}

#' Clean indicator names for display
#'
#' Converts indicator column names to readable labels.
#'
#' @param names Character vector of indicator names
#'
#' @return Character vector of cleaned names
#' @keywords internal
#' @noRd
clean_indicator_name <- function(names) {
  # Remove common suffixes
  cleaned <- gsub("_norm$", " (Normalized)", names)
  cleaned <- gsub("_inv$", " (Inverted)", cleaned)

  # Capitalize first letter
  cleaned <- gsub("^(.)", "\\U\\1", cleaned, perl = TRUE)

  # Replace underscores with spaces
  cleaned <- gsub("_", " ", cleaned)

  cleaned
}

#' Reshape data for faceted plotting
#'
#' Converts wide format (multiple indicator columns) to long format.
#'
#' @param data sf object with multiple indicators
#' @param indicators Indicator column names
#'
#' @return sf object in long format with 'indicator' and 'value' columns
#' @keywords internal
#' @noRd
reshape_for_facet <- function(data, indicators) {
  # Extract geometry
  geom <- sf::st_geometry(data)

  # Drop geometry for reshaping
  data_df <- sf::st_drop_geometry(data)

  # Keep only indicator columns (and ID if present)
  id_col <- if ("nemeton_id" %in% names(data_df)) "nemeton_id" else NULL

  if (!is.null(id_col)) {
    keep_cols <- c(id_col, indicators)
  } else {
    keep_cols <- indicators
    data_df$row_id <- seq_len(nrow(data_df))
    id_col <- "row_id"
  }

  data_df <- data_df[, keep_cols, drop = FALSE]

  # Reshape to long format
  data_long <- tidyr::pivot_longer(
    data_df,
    cols = tidyr::all_of(indicators),
    names_to = "indicator",
    values_to = "value"
  )

  # Re-attach geometry
  # Each row in original data gets replicated for each indicator
  geom_repeated <- rep(geom, each = length(indicators))

  data_long_sf <- sf::st_sf(data_long, geometry = geom_repeated)

  data_long_sf
}

#' Create comparison map (before/after or scenarios)
#'
#' Compares two sets of indicator values side-by-side.
#'
#' @param data1 First sf object (e.g., "before" scenario)
#' @param data2 Second sf object (e.g., "after" scenario)
#' @param indicator Character. Indicator column name to compare
#' @param labels Character vector of length 2. Labels for scenarios. Default c("Scenario 1", "Scenario 2").
#' @param palette Color palette (same options as plot_indicators_map)
#' @param title Plot title
#' @param ... Additional arguments passed to plot_indicators_map
#'
#' @return A ggplot object with side-by-side comparison
#'
#' @examples
#' \dontrun{
#' plot_comparison_map(
#'   current_state,
#'   future_scenario,
#'   indicator = "ecosystem_health",
#'   labels = c("Current (2024)", "Future (2050)"),
#'   palette = "RdYlGn"
#' )
#' }
#'
#' @export
plot_comparison_map <- function(data1,
                                 data2,
                                 indicator,
                                 labels = c("Scenario 1", "Scenario 2"),
                                 palette = "viridis",
                                 title = NULL,
                                 ...) {
  # Validate inputs
  if (!inherits(data1, "sf") || !inherits(data2, "sf")) {
    msg_error("viz_both_not_sf")
  }

  if (!indicator %in% names(data1) || !indicator %in% names(data2)) {
    msg_error("viz_indicator_missing_both", indicator)
  }

  # Add scenario labels
  data1_labeled <- data1
  data1_labeled$scenario <- labels[1]

  data2_labeled <- data2
  data2_labeled$scenario <- labels[2]

  # Combine
  combined <- rbind(data1_labeled, data2_labeled)

  # Create faceted map
  p <- ggplot2::ggplot(combined) +
    ggplot2::geom_sf(
      ggplot2::aes(fill = .data[[indicator]]),
      color = "white",
      size = 0.3,
      alpha = 0.9
    ) +
    ggplot2::facet_wrap(~ scenario, ncol = 2)

  # Add color scale
  p <- add_color_scale(
    p,
    palette = palette,
    direction = 1,
    breaks = NULL,
    labels = NULL,
    legend_title = clean_indicator_name(indicator)
  )

  # Add title
  if (is.null(title)) {
    title <- sprintf("Comparison: %s", clean_indicator_name(indicator))
  }

  p <- p +
    ggplot2::labs(title = title) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", hjust = 0.5),
      legend.position = "right",
      panel.grid = ggplot2::element_blank()
    )

  p
}

#' Create difference map (change visualization)
#'
#' Visualizes the difference between two scenarios.
#'
#' @param data1 First sf object (baseline)
#' @param data2 Second sf object (comparison)
#' @param indicator Indicator column name
#' @param type Character. Type of difference: "absolute" (data2 - data1) or "relative" ((data2-data1)/data1 * 100)
#' @param palette Color palette. Default "RdBu" (diverging red-blue)
#' @param title Plot title
#' @param legend_title Legend title
#' @param ... Additional arguments
#'
#' @return A ggplot object showing differences
#'
#' @examples
#' \dontrun{
#' plot_difference_map(
#'   current_state,
#'   future_scenario,
#'   indicator = "carbon",
#'   type = "relative",
#'   title = "Carbon Stock Change (%)"
#' )
#' }
#'
#' @export
plot_difference_map <- function(data1,
                                 data2,
                                 indicator,
                                 type = c("absolute", "relative"),
                                 palette = "RdBu",
                                 title = NULL,
                                 legend_title = NULL,
                                 ...) {
  type <- match.arg(type)

  # Validate inputs
  if (!inherits(data1, "sf") || !inherits(data2, "sf")) {
    msg_error("viz_both_not_sf")
  }

  if (!indicator %in% names(data1) || !indicator %in% names(data2)) {
    msg_error("viz_indicator_missing_both", indicator)
  }

  # Calculate difference
  diff_data <- data1

  if (type == "absolute") {
    diff_data$difference <- data2[[indicator]] - data1[[indicator]]
    if (is.null(legend_title)) legend_title <- "Absolute Change"
  } else {
    # Relative (percentage change)
    diff_data$difference <- ((data2[[indicator]] - data1[[indicator]]) / data1[[indicator]]) * 100
    if (is.null(legend_title)) legend_title <- "Relative Change (%)"
  }

  # Create map
  p <- ggplot2::ggplot(diff_data) +
    ggplot2::geom_sf(
      ggplot2::aes(fill = difference),
      color = "white",
      size = 0.3,
      alpha = 0.9
    )

  # Add diverging color scale (red = decrease, blue = increase)
  p <- p + ggplot2::scale_fill_distiller(
    name = legend_title,
    palette = palette,
    direction = 1
  )

  # Add title
  if (is.null(title)) {
    title <- sprintf("Change in %s", clean_indicator_name(indicator))
  }

  p <- p +
    ggplot2::labs(title = title) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", hjust = 0.5),
      legend.position = "right",
      panel.grid = ggplot2::element_blank()
    )

  p
}

#' Create radar chart for indicator profile
#'
#' Generates a radar (spider) chart showing the multi-dimensional profile
#' of indicators for a specific unit or the average across all units.
#'
#' @param data An sf object with indicator columns
#' @param unit_id Optional. ID of the specific unit to plot. If NULL, plots
#'   the average of all units.
#' @param indicators Character vector of indicator names to include in the radar.
#'   If NULL, auto-detects all numeric columns except geometry and standard metadata.
#' @param normalize Logical. If TRUE (default), normalizes values to 0-100 scale.
#' @param title Optional plot title. If NULL, auto-generated based on unit_id.
#' @param fill_color Color to fill the radar polygon. Default "#3182bd" (blue).
#' @param fill_alpha Transparency of the fill (0-1). Default 0.3.
#'
#' @return A ggplot object
#'
#' @details
#' The radar chart displays multiple indicators as axes radiating from a center point.
#' Each axis represents one indicator, with values scaled from center (0) to edge (100).
#'
#' If \code{unit_id} is specified, the chart shows the profile for that specific unit.
#' If \code{unit_id} is NULL, the chart shows the mean values across all units.
#'
#' Normalization is recommended when indicators have different scales. The function
#' applies min-max normalization to scale all values to 0-100.
#'
#' @examples
#' \dontrun{
#' # Load demo data
#' data(massif_demo_units)
#' layers <- massif_demo_layers()
#' results <- nemeton_compute(massif_demo_units, layers, indicators = "all")
#' normalized <- normalize_indicators(results)
#'
#' # Radar for a specific unit
#' nemeton_radar(normalized, unit_id = "unit_001")
#'
#' # Radar for average of all units
#' nemeton_radar(normalized)
#'
#' # Custom indicators and styling
#' nemeton_radar(
#'   normalized,
#'   unit_id = "unit_005",
#'   indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
#'   fill_color = "#d73027",
#'   fill_alpha = 0.5
#' )
#' }
#'
#' @seealso \code{\link{plot_indicators_map}}, \code{\link{normalize_indicators}}
#' @export
nemeton_radar <- function(data,
                          unit_id = NULL,
                          indicators = NULL,
                          normalize = TRUE,
                          title = NULL,
                          fill_color = "#3182bd",
                          fill_alpha = 0.3) {

  # Validate inputs
  if (!inherits(data, "sf")) {
    cli::cli_abort("{.arg data} must be an {.cls sf} object")
  }

  # Auto-detect indicators if not specified
  if (is.null(indicators)) {
    # Get numeric columns excluding geometry and standard metadata
    all_cols <- names(data)
    exclude_cols <- c("geometry", "nemeton_id", "id", "area", "surface_geo",
                      "geo_parcelle", "nomcommune", "codecommune")
    numeric_cols <- all_cols[sapply(data, is.numeric)]
    indicators <- setdiff(numeric_cols, exclude_cols)

    if (length(indicators) == 0) {
      cli::cli_abort("No numeric indicator columns found in data")
    }
  }

  # Validate indicators exist
  missing <- setdiff(indicators, names(data))
  if (length(missing) > 0) {
    cli::cli_abort("Indicators not found in data: {.field {missing}}")
  }

  # Extract data for the specified unit or calculate mean
  if (!is.null(unit_id)) {
    # Find ID column (try common names)
    id_col <- NULL
    for (col_name in c("nemeton_id", "parcel_id", "id", "geo_parcelle")) {
      if (col_name %in% names(data)) {
        id_col <- col_name
        break
      }
    }

    if (is.null(id_col)) {
      cli::cli_abort("{.arg data} must have an ID column (nemeton_id, parcel_id, id, or geo_parcelle) when {.arg unit_id} is specified")
    }

    unit_data <- data[data[[id_col]] == unit_id, ]
    if (nrow(unit_data) == 0) {
      cli::cli_abort("Unit ID {.val {unit_id}} not found in data")
    }

    # Extract indicator values (drop geometry to avoid extra column)
    unit_df <- sf::st_drop_geometry(unit_data)
    values <- as.numeric(unit_df[1, indicators])
    unit_label <- unit_id
  } else {
    # Calculate mean across all units
    values <- sapply(indicators, function(ind) {
      mean(data[[ind]], na.rm = TRUE)
    })
    unit_label <- "Average (all units)"
  }

  # Normalize values if requested
  if (normalize) {
    # Min-max normalization to 0-100
    for (i in seq_along(values)) {
      ind <- indicators[i]
      all_values <- data[[ind]]
      min_val <- min(all_values, na.rm = TRUE)
      max_val <- max(all_values, na.rm = TRUE)

      if (max_val == min_val) {
        # All values identical
        values[i] <- 50
      } else {
        values[i] <- ((values[i] - min_val) / (max_val - min_val)) * 100
      }
    }
  }

  # Create data frame for plotting
  radar_data <- data.frame(
    indicator = indicators,
    value = values,
    stringsAsFactors = FALSE
  )

  # Clean indicator names for display
  radar_data$indicator_clean <- sapply(radar_data$indicator, clean_indicator_name)

  # Add angle for each indicator (equally spaced around circle)
  n_indicators <- nrow(radar_data)
  radar_data$angle <- seq(0, 2 * pi, length.out = n_indicators + 1)[1:n_indicators]

  # Convert to x, y coordinates
  radar_data$x <- radar_data$value * cos(radar_data$angle)
  radar_data$y <- radar_data$value * sin(radar_data$angle)

  # Create closed polygon by repeating first point
  radar_polygon <- rbind(radar_data, radar_data[1, ])

  # Create axis lines data (from center to max value for each indicator)
  max_value <- if (normalize) 100 else max(values, na.rm = TRUE) * 1.2
  axis_data <- data.frame(
    x0 = 0,
    y0 = 0,
    x1 = max_value * cos(radar_data$angle),
    y1 = max_value * sin(radar_data$angle)
  )

  # Create label positions (slightly outside the max circle)
  label_distance <- max_value * 1.15
  label_data <- data.frame(
    x = label_distance * cos(radar_data$angle),
    y = label_distance * sin(radar_data$angle),
    label = radar_data$indicator_clean,
    angle = radar_data$angle
  )

  # Adjust text angle for readability
  label_data$text_angle <- label_data$angle * 180 / pi
  label_data$text_angle <- ifelse(label_data$text_angle > 90 & label_data$text_angle < 270,
                                  label_data$text_angle + 180,
                                  label_data$text_angle)

  # Create the plot
  p <- ggplot2::ggplot() +
    # Draw axis lines
    ggplot2::geom_segment(
      data = axis_data,
      ggplot2::aes(x = x0, y = y0, xend = x1, yend = y1),
      color = "gray80",
      linewidth = 0.5
    ) +
    # Draw concentric circles for scale
    ggplot2::geom_path(
      data = data.frame(
        angle = seq(0, 2 * pi, length.out = 100),
        radius = max_value * 0.25
      ),
      ggplot2::aes(x = radius * cos(angle), y = radius * sin(angle)),
      color = "gray90",
      linewidth = 0.3
    ) +
    ggplot2::geom_path(
      data = data.frame(
        angle = seq(0, 2 * pi, length.out = 100),
        radius = max_value * 0.5
      ),
      ggplot2::aes(x = radius * cos(angle), y = radius * sin(angle)),
      color = "gray90",
      linewidth = 0.3
    ) +
    ggplot2::geom_path(
      data = data.frame(
        angle = seq(0, 2 * pi, length.out = 100),
        radius = max_value * 0.75
      ),
      ggplot2::aes(x = radius * cos(angle), y = radius * sin(angle)),
      color = "gray90",
      linewidth = 0.3
    ) +
    ggplot2::geom_path(
      data = data.frame(
        angle = seq(0, 2 * pi, length.out = 100),
        radius = max_value
      ),
      ggplot2::aes(x = radius * cos(angle), y = radius * sin(angle)),
      color = "gray80",
      linewidth = 0.5
    ) +
    # Draw the data polygon
    ggplot2::geom_polygon(
      data = radar_polygon,
      ggplot2::aes(x = x, y = y),
      fill = fill_color,
      alpha = fill_alpha,
      color = fill_color,
      linewidth = 1
    ) +
    # Draw points at each indicator
    ggplot2::geom_point(
      data = radar_data,
      ggplot2::aes(x = x, y = y),
      color = fill_color,
      size = 3
    ) +
    # Add indicator labels
    ggplot2::geom_text(
      data = label_data,
      ggplot2::aes(x = x, y = y, label = label, angle = text_angle),
      size = 3.5,
      fontface = "bold"
    ) +
    # Equal aspect ratio (circle not ellipse)
    ggplot2::coord_equal() +
    # Clean theme
    ggplot2::theme_void() +
    ggplot2::theme(
      plot.title = ggplot2::element_text(
        face = "bold",
        hjust = 0.5,
        size = 14,
        margin = ggplot2::margin(b = 20)
      ),
      plot.margin = ggplot2::margin(20, 20, 20, 20)
    )

  # Add title
  if (is.null(title)) {
    if (!is.null(unit_id)) {
      title <- sprintf("Indicator Profile - %s", unit_label)
    } else {
      title <- "Indicator Profile - Average"
    }
  }

  p <- p + ggplot2::labs(title = title)

  p
}
