#' Cluster Parcels by Multi-Family Profiles
#'
#' Performs clustering analysis on forest parcels based on their ecosystem
#' service family profiles. Supports both K-means and hierarchical clustering
#' with automatic optimal k determination via silhouette analysis.
#'
#' @param data An sf object or data.frame containing the parcels to cluster
#' @param families Character vector of family column names to use for clustering
#'   (e.g., \code{c("family_C", "family_B", "family_P", "family_S")})
#' @param k Integer number of clusters. If \code{NULL} (default), the optimal
#'   number of clusters is determined automatically using silhouette analysis.
#' @param method Character string specifying clustering method: \code{"kmeans"}
#'   (default) or \code{"hierarchical"} (Ward's linkage)
#' @param max_k Maximum number of clusters to test when k is NULL (default: 10)
#'
#' @return The input data with an additional \code{cluster} integer column
#'   indicating cluster assignment. The result also has attributes:
#'   \itemize{
#'     \item \code{cluster_profile}: Data frame with mean family values per cluster
#'     \item \code{method}: Clustering method used
#'     \item \code{optimal_k}: Optimal k if auto-determined (only when k=NULL)
#'     \item \code{silhouette_scores}: Silhouette scores for k=2 to max_k (only when k=NULL)
#'   }
#'   If input is sf object, output preserves the sf class and geometry.
#'
#' @details
#' ## Clustering Methods
#'
#' - **K-means**: Fast, works well with spherical clusters, sensitive to outliers
#' - **Hierarchical**: More flexible cluster shapes, deterministic, slower
#'
#' ## Automatic K Determination
#'
#' When \code{k = NULL}, the function tests k from 2 to \code{max_k} and selects
#' the k with highest average silhouette width. Silhouette values range from
#' -1 to 1:
#' - > 0.7: Strong structure
#' - 0.5-0.7: Reasonable structure
#' - 0.25-0.5: Weak structure
#' - < 0.25: No substantial structure
#'
#' ## Cluster Profiles
#'
#' The function computes cluster profiles (centroid values) for each family,
#' allowing interpretation of cluster characteristics (e.g., "high production,
#' low biodiversity" cluster).
#'
#' @examples
#' \dontrun{
#' # Load demo dataset
#' data("massif_demo_units_extended")
#'
#' # Cluster parcels into 3 groups based on 4 families
#' result <- cluster_parcels(
#'   massif_demo_units_extended,
#'   families = c("family_C", "family_B", "family_P", "family_S"),
#'   k = 3,
#'   method = "kmeans"
#' )
#'
#' # View cluster assignments
#' table(result$cluster)
#'
#' # View cluster profiles
#' attr(result, "cluster_profile")
#'
#' # Auto-determine optimal k
#' result_auto <- cluster_parcels(
#'   massif_demo_units_extended,
#'   families = c("family_C", "family_B", "family_P", "family_S"),
#'   k = NULL
#' )
#' attr(result_auto, "optimal_k")
#' attr(result_auto, "silhouette_scores")
#'
#' # Use hierarchical clustering
#' result_hclust <- cluster_parcels(
#'   massif_demo_units_extended,
#'   families = c("family_C", "family_B", "family_P", "family_S"),
#'   k = 3,
#'   method = "hierarchical"
#' )
#'
#' # Visualize clusters spatially
#' library(ggplot2)
#' ggplot(result) +
#'   geom_sf(aes(fill = factor(cluster))) +
#'   scale_fill_viridis_d() +
#'   labs(title = "Parcel Clusters", fill = "Cluster")
#' }
#'
#' @export
cluster_parcels <- function(data,
                             families,
                             k = NULL,
                             method = "kmeans",
                             max_k = 10) {

  # === VALIDATION ===

  # Check data
  if (!inherits(data, c("data.frame", "sf"))) {
    stop(msg("error_invalid_data_type"), call. = FALSE)
  }

  # Check families exist
  missing_fam <- setdiff(families, names(data))
  if (length(missing_fam) > 0) {
    stop(sprintf(msg("error_families_not_found"), paste(missing_fam, collapse = ", ")),
         call. = FALSE)
  }

  # Check families are numeric
  non_numeric <- families[!sapply(families, function(fam) is.numeric(data[[fam]]))]
  if (length(non_numeric) > 0) {
    stop(sprintf(msg("error_non_numeric_families"), paste(non_numeric, collapse = ", ")),
         call. = FALSE)
  }

  # Check for NA values
  has_na <- sapply(data[families], function(x) any(is.na(x)))
  if (any(has_na)) {
    stop(sprintf(msg("error_na_values"), paste(families[has_na], collapse = ", ")),
         call. = FALSE)
  }

  # Check method
  if (!method %in% c("kmeans", "hierarchical")) {
    stop(msg("error_invalid_method",
                       "Method must be either 'kmeans' or 'hierarchical'"),
         call. = FALSE)
  }

  # Check k validity
  n <- nrow(data)
  if (!is.null(k)) {
    if (k < 2) {
      stop(msg("error_k_too_small", "k must be at least 2"), call. = FALSE)
    }
    if (k >= n) {
      stop(sprintf(msg("error_k_too_large"), n),
           call. = FALSE)
    }
  }

  # === PREPARE DATA ===

  # Extract family matrix and scale (drop geometry if sf object)
  if (inherits(data, "sf")) {
    fam_matrix <- as.matrix(sf::st_drop_geometry(data)[, families, drop = FALSE])
  } else {
    fam_matrix <- as.matrix(data[, families, drop = FALSE])
  }
  fam_scaled <- scale(fam_matrix)

  # === AUTO K DETERMINATION ===

  optimal_k <- k
  silhouette_scores <- NULL

  if (is.null(k)) {
    cli::cli_alert_info(sprintf(msg("msg_cluster_auto_k"), min(max_k, n - 1)))

    max_test_k <- min(max_k, n - 1)
    silhouette_scores <- numeric(max_test_k - 1)
    names(silhouette_scores) <- 2:max_test_k

    for (test_k in 2:max_test_k) {
      if (method == "kmeans") {
        fit <- stats::kmeans(fam_scaled, centers = test_k, nstart = 25)
        clusters <- fit$cluster
      } else {
        dist_matrix <- stats::dist(fam_scaled)
        hc <- stats::hclust(dist_matrix, method = "ward.D2")
        clusters <- stats::cutree(hc, k = test_k)
      }

      # Compute silhouette
      dist_matrix <- stats::dist(fam_scaled)
      sil <- cluster::silhouette(clusters, dist_matrix)
      silhouette_scores[test_k - 1] <- mean(sil[, 3])
    }

    # Select k with highest silhouette
    optimal_k <- which.max(silhouette_scores) + 1
    cli::cli_alert_success(sprintf(msg("msg_cluster_optimal_k"), optimal_k, silhouette_scores[optimal_k - 1]))
  }

  # === CLUSTERING ===

  cli::cli_alert_info(sprintf(msg("msg_cluster_computing"), n, optimal_k, method))

  if (method == "kmeans") {
    fit <- stats::kmeans(fam_scaled, centers = optimal_k, nstart = 25)
    clusters <- fit$cluster
  } else {
    # Hierarchical clustering with Ward's linkage
    dist_matrix <- stats::dist(fam_scaled)
    hc <- stats::hclust(dist_matrix, method = "ward.D2")
    clusters <- stats::cutree(hc, k = optimal_k)
  }

  # === COMPUTE CLUSTER PROFILES ===

  # Calculate mean family values per cluster
  cluster_profile <- data.frame(cluster = 1:optimal_k)
  for (fam in families) {
    cluster_profile[[fam]] <- sapply(1:optimal_k, function(cl) {
      mean(data[[fam]][clusters == cl], na.rm = TRUE)
    })
  }

  cli::cli_alert_success(msg("msg_cluster_complete",
                                        sprintf("Clustering complete. Cluster sizes: %s",
                                               paste(table(clusters), collapse = ", "))))

  # === RETURN RESULT ===

  result <- data
  result$cluster <- as.integer(clusters)

  # Add attributes
  attr(result, "cluster_profile") <- cluster_profile
  attr(result, "method") <- method
  if (is.null(k)) {
    attr(result, "optimal_k") <- optimal_k
    attr(result, "silhouette_scores") <- silhouette_scores
  }

  return(result)
}
