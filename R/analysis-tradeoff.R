#' Plot Trade-off Analysis Between Two Objectives
#'
#' Creates a 2D scatterplot visualizing trade-offs between two ecosystem service
#' families or indicators. Optionally overlays the Pareto optimal frontier to
#' highlight non-dominated solutions.
#'
#' @param data An sf object or data.frame containing the parcels to visualize
#' @param x Character string specifying the column name for the x-axis variable
#' @param y Character string specifying the column name for the y-axis variable
#' @param color Optional character string specifying a column for color mapping
#'   (e.g., to show a third dimension)
#' @param size Optional character string specifying a column for size mapping
#' @param pareto_frontier Logical indicating whether to overlay the Pareto
#'   optimal frontier. Requires an \code{is_optimal} column in the data
#'   (default: \code{FALSE})
#' @param label Optional character string specifying column for point labels
#' @param xlab Custom x-axis label (default: variable name)
#' @param ylab Custom y-axis label (default: variable name)
#' @param title Custom plot title (default: auto-generated)
#'
#' @return A ggplot2 object that can be further customized or printed
#'
#' @details
#' ## Trade-off Analysis
#'
#' Trade-off plots reveal relationships between ecosystem services:
#' - **Synergies**: Both variables increase together (positive correlation)
#' - **Trade-offs**: One increases while the other decreases (negative correlation)
#' - **No relationship**: Variables are independent
#'
#' ## Pareto Frontier
#'
#' When \code{pareto_frontier = TRUE}, Pareto optimal parcels are highlighted
#' and connected to show the efficiency frontier. These parcels represent the
#' best possible trade-offs - improving one objective requires sacrificing another.
#'
#' ## Visualization Tips
#'
#' - Use \code{color} to add a third dimension (e.g., color by fire risk)
#' - Use \code{size} to emphasize important parcels (e.g., size by area)
#' - Use \code{label} to identify specific parcels of interest
#' - Combine with faceting for multi-scenario comparisons
#'
#' @examples
#' \dontrun{
#' # Load demo dataset
#' data("massif_demo_units_extended")
#'
#' # Basic trade-off plot: carbon vs biodiversity
#' plot_tradeoff(
#'   massif_demo_units_extended,
#'   x = "family_C",
#'   y = "family_B"
#' )
#'
#' # Add color for a third dimension (production)
#' plot_tradeoff(
#'   massif_demo_units_extended,
#'   x = "family_C",
#'   y = "family_B",
#'   color = "family_P",
#'   title = "Carbon-Biodiversity Trade-off (colored by Production)"
#' )
#'
#' # Overlay Pareto frontier
#' result <- identify_pareto_optimal(
#'   massif_demo_units_extended,
#'   objectives = c("family_C", "family_B", "family_P"),
#'   maximize = rep(TRUE, 3)
#' )
#'
#' plot_tradeoff(
#'   result,
#'   x = "family_C",
#'   y = "family_B",
#'   pareto_frontier = TRUE
#' )
#'
#' # With labels for Pareto optimal parcels
#' plot_tradeoff(
#'   result,
#'   x = "family_C",
#'   y = "family_B",
#'   pareto_frontier = TRUE,
#'   label = "name"
#' )
#'
#' # Multiple trade-off comparisons
#' library(patchwork)
#' p1 <- plot_tradeoff(massif_demo_units_extended, "family_C", "family_B")
#' p2 <- plot_tradeoff(massif_demo_units_extended, "family_C", "family_P")
#' p3 <- plot_tradeoff(massif_demo_units_extended, "family_B", "family_P")
#' p1 + p2 + p3
#' }
#'
#' @export
plot_tradeoff <- function(data,
                          x,
                          y,
                          color = NULL,
                          size = NULL,
                          pareto_frontier = FALSE,
                          label = NULL,
                          xlab = NULL,
                          ylab = NULL,
                          title = NULL) {

  # === VALIDATION ===

  # Check ggplot2 is available
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop(msg("error_ggplot2_required"), call. = FALSE)
  }

  # Check data
  if (!inherits(data, c("data.frame", "sf"))) {
    stop(msg("error_invalid_data_type"), call. = FALSE)
  }

  # Check x variable
  if (!x %in% names(data)) {
    stop(sprintf(msg("error_variable_not_found"), x),
         call. = FALSE)
  }
  if (!is.numeric(data[[x]])) {
    stop(sprintf(msg("error_non_numeric_variable"), x),
         call. = FALSE)
  }

  # Check y variable
  if (!y %in% names(data)) {
    stop(sprintf(msg("error_variable_not_found"), y),
         call. = FALSE)
  }
  if (!is.numeric(data[[y]])) {
    stop(sprintf(msg("error_non_numeric_variable"), y),
         call. = FALSE)
  }

  # Check color variable if specified
  if (!is.null(color) && !color %in% names(data)) {
    stop(sprintf(msg("error_variable_not_found"), color),
         call. = FALSE)
  }

  # Check size variable if specified
  if (!is.null(size) && !size %in% names(data)) {
    stop(sprintf(msg("error_variable_not_found"), size),
         call. = FALSE)
  }

  # Check label variable if specified
  if (!is.null(label) && !label %in% names(data)) {
    stop(sprintf(msg("error_variable_not_found"), label),
         call. = FALSE)
  }

  # Check is_optimal if pareto_frontier requested
  if (pareto_frontier && !"is_optimal" %in% names(data)) {
    stop(msg("error_is_optimal_required"), call. = FALSE)
  }

  # === PREPARE PLOT DATA ===

  # Convert sf to data.frame for ggplot
  plot_data <- data
  if (inherits(plot_data, "sf")) {
    plot_data <- sf::st_drop_geometry(plot_data)
  }

  # === BUILD PLOT ===

  # Base aesthetics
  aes_mapping <- ggplot2::aes(x = .data[[x]], y = .data[[y]])
  if (!is.null(color)) {
    aes_mapping$colour <- ggplot2::aes(colour = .data[[color]])$colour
  }
  if (!is.null(size)) {
    aes_mapping$size <- ggplot2::aes(size = .data[[size]])$size
  }

  # Create base plot
  p <- ggplot2::ggplot(plot_data, aes_mapping)

  # Add Pareto frontier if requested
  if (pareto_frontier && "is_optimal" %in% names(plot_data)) {
    # Plot non-optimal parcels first (gray, smaller)
    p <- p +
      ggplot2::geom_point(
        data = plot_data[!plot_data$is_optimal, ],
        color = "gray70",
        alpha = 0.6,
        size = 2
      )

    # Plot optimal parcels (highlighted)
    optimal_data <- plot_data[plot_data$is_optimal, ]

    # Sort optimal parcels for frontier line (by x then y)
    optimal_sorted <- optimal_data[order(optimal_data[[x]], optimal_data[[y]]), ]

    # Add frontier line
    p <- p +
      ggplot2::geom_step(
        data = optimal_sorted,
        ggplot2::aes(x = .data[[x]], y = .data[[y]]),
        color = "red",
        linetype = "dashed",
        alpha = 0.7,
        direction = "vh"
      )

    # Add optimal points
    if (is.null(color) && is.null(size)) {
      p <- p + ggplot2::geom_point(
        data = optimal_data,
        color = "red",
        size = 3,
        alpha = 0.8
      )
    } else {
      p <- p + ggplot2::geom_point(
        data = optimal_data,
        size = if (is.null(size)) 3 else ggplot2::aes(size = .data[[size]]),
        alpha = 0.8
      )
    }

  } else {
    # Standard scatterplot (no Pareto frontier)
    p <- p + ggplot2::geom_point(alpha = 0.7)
  }

  # Add labels if requested
  if (!is.null(label)) {
    if (requireNamespace("ggrepel", quietly = TRUE)) {
      # Use ggrepel for non-overlapping labels
      label_data <- if (pareto_frontier && "is_optimal" %in% names(plot_data)) {
        plot_data[plot_data$is_optimal, ]  # Only label optimal parcels
      } else {
        plot_data
      }

      p <- p + ggrepel::geom_text_repel(
        data = label_data,
        ggplot2::aes(label = .data[[label]]),
        size = 3,
        max.overlaps = 20
      )
    } else {
      warning(msg("warning_ggrepel_not_installed"))
      p <- p + ggplot2::geom_text(
        ggplot2::aes(label = .data[[label]]),
        size = 3,
        nudge_y = 0.02 * diff(range(plot_data[[y]]))
      )
    }
  }

  # === STYLING ===

  # Default labels
  if (is.null(xlab)) xlab <- x
  if (is.null(ylab)) ylab <- y
  if (is.null(title)) {
    title <- sprintf("Trade-off: %s vs %s", x, y)
  }

  p <- p +
    ggplot2::labs(
      x = xlab,
      y = ylab,
      title = title
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"),
      legend.position = "right"
    )

  # Color scale if continuous
  if (!is.null(color) && is.numeric(plot_data[[color]])) {
    p <- p + ggplot2::scale_color_viridis_c(name = color)
  }

  return(p)
}
