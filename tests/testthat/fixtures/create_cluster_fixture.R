# Create clustering reference fixture for testing
# This fixture contains test data with clear cluster structure

library(sf)

# Create data with 3 distinct clusters (high/medium/low for all families)
# Cluster 1: High performers (parcels 1-3)
# Cluster 2: Medium performers (parcels 4-6)
# Cluster 3: Low performers (parcels 7-9)

cluster_test_data <- data.frame(
  id = 1:9,
  name = sprintf("Parcel_%02d", 1:9),

  # Cluster 1: High values (70-90 range)
  # Cluster 2: Medium values (40-60 range)
  # Cluster 3: Low values (10-30 range)

  family_C = c(
    85, 80, 88, # Cluster 1
    50, 55, 52, # Cluster 2
    20, 15, 25
  ), # Cluster 3

  family_B = c(
    82, 87, 85, # Cluster 1
    48, 52, 50, # Cluster 2
    18, 22, 20
  ), # Cluster 3

  family_P = c(
    78, 83, 80, # Cluster 1
    45, 50, 48, # Cluster 2
    25, 20, 22
  ), # Cluster 3

  family_S = c(
    88, 85, 82, # Cluster 1
    55, 52, 58, # Cluster 2
    15, 18, 20
  ) # Cluster 3
)

# Add simple geometry
cluster_test_data$geometry <- sf::st_sfc(
  lapply(1:9, function(i) {
    sf::st_point(c(i * 100, i * 100))
  }),
  crs = 2154
)
cluster_test_data <- sf::st_as_sf(cluster_test_data)

# Expected cluster assignments (1, 2, 3)
expected_clusters_k3 <- c(
  1, 1, 1, # Parcels 1-3 in cluster 1
  2, 2, 2, # Parcels 4-6 in cluster 2
  3, 3, 3
) # Parcels 7-9 in cluster 3

# For k=2, combine clusters 2 and 3
expected_clusters_k2 <- c(
  1, 1, 1, # High performers
  2, 2, 2, 2, 2, 2
) # Medium+low performers

# Save fixture
reference_output <- list(
  input_data = cluster_test_data,
  families = c("family_C", "family_B", "family_P", "family_S"),
  expected_k_optimal = 3, # Optimal number of clusters
  expected_clusters_k3 = expected_clusters_k3,
  expected_clusters_k2 = expected_clusters_k2
)

saveRDS(reference_output, "tests/testthat/fixtures/cluster_reference.rds")
cat("✓ Created cluster_reference.rds with 3 clear clusters\n")
