#' Identify Pareto Optimal Solutions
#'
#' Identifies parcels that are Pareto optimal (non-dominated) across multiple
#' objectives. A parcel is Pareto optimal if no other parcel performs better
#' on all objectives simultaneously. This function supports both maximization
#' and minimization objectives.
#'
#' @param data An sf object or data.frame containing the parcels to analyze
#' @param objectives Character vector of column names representing the objectives
#'   to optimize (e.g., \code{c("family_C", "family_B", "family_P")})
#' @param maximize Logical vector of same length as \code{objectives}, indicating
#'   whether each objective should be maximized (\code{TRUE}) or minimized
#'   (\code{FALSE}). Default is to maximize all objectives.
#'
#' @return The input data with an additional \code{is_optimal} logical column
#'   indicating whether each parcel is Pareto optimal. If input is sf object,
#'   output preserves the sf class and geometry.
#'
#' @details
#' ## Pareto Dominance
#'
#' For maximization objectives:
#' - Parcel A dominates parcel B if A ≥ B on all objectives AND A > B on at
#'   least one objective
#'
#' For minimization objectives:
#' - Parcel A dominates parcel B if A ≤ B on all objectives AND A < B on at
#'   least one objective
#'
#' A parcel is **Pareto optimal** if it is not dominated by any other parcel.
#'
#' ## Applications
#'
#' Pareto analysis is useful for:
#' - Multi-criteria decision making (e.g., balancing production vs conservation)
#' - Identifying trade-off frontiers between ecosystem services
#' - Selecting parcels for diverse management objectives
#' - Benchmarking parcel performance across multiple dimensions
#'
#' @examples
#' \dontrun{
#' # Load demo dataset
#' data("massif_demo_units_extended")
#'
#' # Find parcels that are optimal for carbon, biodiversity, and production
#' result <- identify_pareto_optimal(
#'   massif_demo_units_extended,
#'   objectives = c("family_C", "family_B", "family_P"),
#'   maximize = c(TRUE, TRUE, TRUE)
#' )
#'
#' # How many are Pareto optimal?
#' sum(result$is_optimal)
#'
#' # Mixed objectives: maximize carbon and biodiversity, minimize fire risk
#' result_mixed <- identify_pareto_optimal(
#'   massif_demo_units_extended,
#'   objectives = c("family_C", "family_B", "family_R"),
#'   maximize = c(TRUE, TRUE, FALSE)
#' )
#'
#' # Visualize optimal parcels
#' library(ggplot2)
#' ggplot(result, aes(x = family_C, y = family_B, color = is_optimal)) +
#'   geom_point(size = 3) +
#'   scale_color_manual(values = c("gray", "red")) +
#'   labs(
#'     title = "Pareto Optimal Parcels",
#'     x = "Carbon Storage", y = "Biodiversity"
#'   )
#' }
#'
#' @export
identify_pareto_optimal <- function(data,
                                    objectives,
                                    maximize = rep(TRUE, length(objectives))) {
  # === VALIDATION ===

  # Check data
  if (!inherits(data, c("data.frame", "sf"))) {
    stop(msg("error_invalid_data_type"), call. = FALSE)
  }

  # Check objectives exist
  missing_obj <- setdiff(objectives, names(data))
  if (length(missing_obj) > 0) {
    stop(sprintf(msg("error_objectives_not_found"), paste(missing_obj, collapse = ", ")), call. = FALSE)
  }

  # Check objectives are numeric
  non_numeric <- objectives[!sapply(objectives, function(obj) is.numeric(data[[obj]]))]
  if (length(non_numeric) > 0) {
    stop(sprintf(msg("error_non_numeric_objectives"), paste(non_numeric, collapse = ", ")), call. = FALSE)
  }

  # Check maximize length matches objectives
  if (length(maximize) != length(objectives)) {
    stop(sprintf(msg("error_maximize_length"), length(maximize), length(objectives)), call. = FALSE)
  }

  # Check for NA values in objectives
  has_na <- sapply(data[objectives], function(x) any(is.na(x)))
  if (any(has_na)) {
    stop(sprintf(msg("error_na_values"), paste(objectives[has_na], collapse = ", ")), call. = FALSE)
  }

  # === PARETO DOMINANCE CHECK ===

  cli::cli_alert_info(sprintf(msg("msg_pareto_computing"), nrow(data), length(objectives)))

  # Extract objective matrix (drop geometry if sf object)
  if (inherits(data, "sf")) {
    obj_matrix <- as.matrix(sf::st_drop_geometry(data)[, objectives, drop = FALSE])
  } else {
    obj_matrix <- as.matrix(data[, objectives, drop = FALSE])
  }

  # Flip signs for minimization objectives (convert to maximization)
  for (i in seq_along(objectives)) {
    if (!maximize[i]) {
      obj_matrix[, i] <- -obj_matrix[, i]
    }
  }

  # Check dominance for each parcel
  n <- nrow(obj_matrix)
  is_dominated <- rep(FALSE, n)

  for (i in 1:n) {
    if (is_dominated[i]) next # Skip if already dominated

    # Compare parcel i against all other parcels
    for (j in 1:n) {
      if (i == j) next

      # Check if j dominates i
      # j dominates i if: j >= i on all objectives AND j > i on at least one
      all_geq <- all(obj_matrix[j, ] >= obj_matrix[i, ])
      any_greater <- any(obj_matrix[j, ] > obj_matrix[i, ])

      if (all_geq && any_greater) {
        is_dominated[i] <- TRUE
        break
      }
    }
  }

  # Pareto optimal = not dominated
  is_optimal <- !is_dominated

  n_optimal <- sum(is_optimal)
  pct_optimal <- round(100 * n_optimal / n, 1)

  cli::cli_alert_success(sprintf(msg("msg_pareto_complete"), n_optimal, pct_optimal))

  # === RETURN RESULT ===

  result <- data
  result$is_optimal <- is_optimal

  return(result)
}
