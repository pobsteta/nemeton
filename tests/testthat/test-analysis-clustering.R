# Test Suite for Clustering Analysis (T114-T116)

test_that("cluster_parcels performs K-means clustering correctly (T114)", {
  skip_if_not_installed("sf")

  # Load fixture with clear cluster structure
  fixture <- readRDS("fixtures/cluster_reference.rds")
  data <- fixture$input_data
  families <- fixture$families

  # Test K-means with k=3
  result <- cluster_parcels(
    data,
    families = families,
    k = 3,
    method = "kmeans"
  )

  # Check structure
  expect_s3_class(result, "data.frame")
  expect_true("cluster" %in% names(result))
  expect_type(result$cluster, "integer")

  # Check all parcels assigned to exactly one cluster
  expect_equal(length(unique(result$cluster)), 3)
  expect_true(all(result$cluster %in% 1:3))

  # Check cluster profiles are computed
  expect_true("cluster_profile" %in% names(attributes(result)))
  profiles <- attr(result, "cluster_profile")
  expect_equal(nrow(profiles), 3) # 3 clusters
  expect_equal(ncol(profiles), length(families)) # 4 families

  # Given the clear separation in fixture, clusters should match reasonably
  # Parcels 1-3 should be in same cluster (high performers)
  expect_equal(result$cluster[1], result$cluster[2])
  expect_equal(result$cluster[2], result$cluster[3])

  # Parcels 7-9 should be in same cluster (low performers)
  expect_equal(result$cluster[7], result$cluster[8])
  expect_equal(result$cluster[8], result$cluster[9])

  # High and low clusters should be different
  expect_false(result$cluster[1] == result$cluster[7])
})

test_that("cluster_parcels auto-determines optimal k with silhouette method (T115)", {
  skip_if_not_installed("sf")

  # Load fixture
  fixture <- readRDS("fixtures/cluster_reference.rds")
  data <- fixture$input_data
  families <- fixture$families

  # Test with k=NULL (auto-determination)
  result <- cluster_parcels(
    data,
    families = families,
    k = NULL,
    method = "kmeans"
  )

  # Should automatically determine k
  expect_true("optimal_k" %in% names(attributes(result)))
  optimal_k <- attr(result, "optimal_k")
  expect_type(optimal_k, "integer")
  expect_gte(optimal_k, 2) # At least 2 clusters
  expect_lte(optimal_k, nrow(data) - 1) # At most n-1 clusters

  # For the clear 3-cluster fixture, optimal k should be 3 or close
  expect_gte(optimal_k, 2)
  expect_lte(optimal_k, 4)

  # Silhouette scores should be available
  expect_true("silhouette_scores" %in% names(attributes(result)))
  sil_scores <- attr(result, "silhouette_scores")
  expect_type(sil_scores, "double")
  expect_true(all(!is.na(sil_scores)))
})

test_that("cluster_parcels supports both K-means and hierarchical methods (T116)", {
  skip_if_not_installed("sf")

  # Load fixture
  fixture <- readRDS("fixtures/cluster_reference.rds")
  data <- fixture$input_data
  families <- fixture$families

  # Test K-means
  result_kmeans <- cluster_parcels(
    data,
    families = families,
    k = 3,
    method = "kmeans"
  )
  expect_equal(attr(result_kmeans, "method"), "kmeans")
  expect_equal(length(unique(result_kmeans$cluster)), 3)

  # Test hierarchical (ward.D2 linkage)
  result_hclust <- cluster_parcels(
    data,
    families = families,
    k = 3,
    method = "hierarchical"
  )
  expect_equal(attr(result_hclust, "method"), "hierarchical")
  expect_equal(length(unique(result_hclust$cluster)), 3)

  # Both should have cluster assignments
  expect_true(all(!is.na(result_kmeans$cluster)))
  expect_true(all(!is.na(result_hclust$cluster)))

  # Both should have cluster profiles
  expect_true("cluster_profile" %in% names(attributes(result_kmeans)))
  expect_true("cluster_profile" %in% names(attributes(result_hclust)))

  # Given clear structure, both methods should identify similar groupings
  # (high, medium, low performers)
  # Check that parcels 1-3 are in same cluster for both methods
  expect_equal(
    result_kmeans$cluster[1] == result_kmeans$cluster[2],
    result_hclust$cluster[1] == result_hclust$cluster[2]
  )
})

test_that("cluster_parcels computes cluster profiles correctly", {
  skip_if_not_installed("sf")

  # Load fixture
  fixture <- readRDS("fixtures/cluster_reference.rds")
  data <- fixture$input_data
  families <- fixture$families

  # Cluster with k=3
  result <- cluster_parcels(
    data,
    families = families,
    k = 3,
    method = "kmeans"
  )

  # Get cluster profiles
  profiles <- attr(result, "cluster_profile")

  # Profiles should be means of family values within each cluster
  expect_equal(nrow(profiles), 3)
  expect_equal(ncol(profiles), length(families))
  expect_true(all(colnames(profiles) %in% families))

  # Check that profile values are within data range
  for (fam in families) {
    expect_gte(min(profiles[[fam]]), min(data[[fam]]) - 1) # Allow small tolerance
    expect_lte(max(profiles[[fam]]), max(data[[fam]]) + 1)
  }

  # For the fixture, cluster of parcels 1-3 should have high values
  cluster_high <- result$cluster[1]
  expect_gte(profiles[cluster_high, "family_C"], 70)
  expect_gte(profiles[cluster_high, "family_B"], 70)

  # Cluster of parcels 7-9 should have low values
  cluster_low <- result$cluster[7]
  expect_lte(profiles[cluster_low, "family_C"], 30)
  expect_lte(profiles[cluster_low, "family_B"], 30)
})

test_that("cluster_parcels parameter validation", {
  skip_if_not_installed("sf")

  # Load fixture
  fixture <- readRDS("fixtures/cluster_reference.rds")
  data <- fixture$input_data
  families <- fixture$families

  # Test invalid families (column doesn't exist)
  expect_error(
    cluster_parcels(data, families = c("invalid_fam"), k = 3, method = "kmeans"),
    "(?i)families.*not found"
  )

  # Test invalid method
  expect_error(
    cluster_parcels(data, families = families, k = 3, method = "invalid_method"),
    "(?i)method.*must be"
  )

  # Test invalid k (too small)
  expect_error(
    cluster_parcels(data, families = families, k = 1, method = "kmeans"),
    "(?i)k.*must be.*least 2"
  )

  # Test invalid k (too large)
  expect_error(
    cluster_parcels(data, families = families, k = nrow(data), method = "kmeans"),
    "(?i)k.*must be.*less than"
  )

  # Test with non-numeric families
  data_bad <- data
  data_bad$family_C <- as.character(data_bad$family_C)
  expect_error(
    cluster_parcels(data_bad, families = families, k = 3, method = "kmeans"),
    "numeric"
  )
})

test_that("cluster_parcels preserves sf geometry", {
  skip_if_not_installed("sf")

  # Load fixture
  fixture <- readRDS("fixtures/cluster_reference.rds")
  data <- fixture$input_data

  # Result should preserve sf class
  result <- cluster_parcels(
    data,
    families = fixture$families,
    k = 3,
    method = "kmeans"
  )

  expect_s3_class(result, "sf")
  expect_true("geometry" %in% names(result))
  expect_equal(sf::st_crs(result), sf::st_crs(data))
  expect_equal(nrow(result), nrow(data))
})

test_that("cluster_parcels handles missing values appropriately", {
  skip_if_not_installed("sf")

  # Load fixture
  fixture <- readRDS("fixtures/cluster_reference.rds")
  data <- fixture$input_data
  families <- fixture$families

  # Introduce NA in one family
  data_na <- data
  data_na$family_C[1] <- NA

  # Should error or handle gracefully
  expect_error(
    cluster_parcels(data_na, families = families, k = 3, method = "kmeans"),
    "(?i)NA|missing"
  )
})
