# Test Suite for Clustering Analysis (T114-T116)
# Comprehensive tests for cluster_parcels() covering all code paths

# --- Helper: create a plain data.frame (non-sf) with clear cluster structure ---
make_cluster_df <- function(n_per_group = 5) {
  # Three well-separated groups for predictable clustering
  high <- data.frame(
    id = seq_len(n_per_group),
    family_C = runif(n_per_group, 80, 100),
    family_B = runif(n_per_group, 80, 100),
    family_P = runif(n_per_group, 80, 100),
    family_S = runif(n_per_group, 80, 100)
  )
  mid <- data.frame(
    id = n_per_group + seq_len(n_per_group),
    family_C = runif(n_per_group, 40, 60),
    family_B = runif(n_per_group, 40, 60),
    family_P = runif(n_per_group, 40, 60),
    family_S = runif(n_per_group, 40, 60)
  )
  low <- data.frame(
    id = 2 * n_per_group + seq_len(n_per_group),
    family_C = runif(n_per_group, 0, 20),
    family_B = runif(n_per_group, 0, 20),
    family_P = runif(n_per_group, 0, 20),
    family_S = runif(n_per_group, 0, 20)
  )
  rbind(high, mid, low)
}

# ===========================================================================
# K-MEANS CLUSTERING (with fixture)
# ===========================================================================

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

# ===========================================================================
# AUTO K DETERMINATION (silhouette)
# ===========================================================================

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

# ===========================================================================
# BOTH METHODS (K-means + Hierarchical)
# ===========================================================================

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

# ===========================================================================
# CLUSTER PROFILES
# ===========================================================================

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

# ===========================================================================
# PARAMETER VALIDATION
# ===========================================================================

test_that("cluster_parcels parameter validation", {
  skip_if_not_installed("sf")

  # Load fixture
  fixture <- readRDS("fixtures/cluster_reference.rds")
  data <- fixture$input_data
  families <- fixture$families

  # Test invalid families (column doesn't exist)
  expect_error(
    cluster_parcels(data, families = c("invalid_fam"), k = 3, method = "kmeans"),
    "not found"
  )

  # Test invalid method
  expect_error(
    cluster_parcels(data, families = families, k = 3, method = "invalid_method"),
    "must be"
  )

  # Test invalid k (too small)
  expect_error(
    cluster_parcels(data, families = families, k = 1, method = "kmeans"),
    "at least 2"
  )

  # Test invalid k (too large)
  expect_error(
    cluster_parcels(data, families = families, k = nrow(data), method = "kmeans"),
    "less than"
  )

  # Test with non-numeric families
  data_bad <- data
  data_bad$family_C <- as.character(data_bad$family_C)
  expect_error(
    cluster_parcels(data_bad, families = families, k = 3, method = "kmeans"),
    "numeric"
  )
})

# ===========================================================================
# SF GEOMETRY PRESERVATION
# ===========================================================================

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

# ===========================================================================
# NA HANDLING
# ===========================================================================

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
    "NA"
  )
})

# ===========================================================================
# PLAIN DATA.FRAME INPUT (non-sf branch, lines 153-154)
# ===========================================================================

test_that("cluster_parcels works with plain data.frame (non-sf)", {
  set.seed(42)
  df <- make_cluster_df(n_per_group = 5)
  families <- c("family_C", "family_B", "family_P", "family_S")

  result <- cluster_parcels(df, families = families, k = 3, method = "kmeans")

  # Should return a data.frame (not sf)
  expect_s3_class(result, "data.frame")
  expect_false(inherits(result, "sf"))

  # Should have cluster column
  expect_true("cluster" %in% names(result))
  expect_type(result$cluster, "integer")
  expect_equal(nrow(result), nrow(df))
  expect_equal(length(unique(result$cluster)), 3)

  # Attributes should be present
  expect_equal(attr(result, "method"), "kmeans")
  expect_true(!is.null(attr(result, "cluster_profile")))

  # No optimal_k or silhouette_scores when k is specified

  expect_null(attr(result, "optimal_k"))
  expect_null(attr(result, "silhouette_scores"))
})

test_that("cluster_parcels with data.frame and hierarchical method", {
  set.seed(42)
  df <- make_cluster_df(n_per_group = 5)
  families <- c("family_C", "family_B", "family_P", "family_S")

  result <- cluster_parcels(df, families = families, k = 3, method = "hierarchical")

  expect_s3_class(result, "data.frame")
  expect_false(inherits(result, "sf"))
  expect_equal(attr(result, "method"), "hierarchical")
  expect_equal(length(unique(result$cluster)), 3)
  expect_true(all(!is.na(result$cluster)))
})

# ===========================================================================
# INVALID DATA TYPE (line 101-103)
# ===========================================================================

test_that("cluster_parcels rejects invalid data types", {
  families <- c("family_C", "family_B")

  # NULL input
  expect_error(
    cluster_parcels(NULL, families = families, k = 3),
    "data.frame|sf"
  )

  # Character string
  expect_error(
    cluster_parcels("not a data frame", families = families, k = 3),
    "data.frame|sf"
  )

  # Numeric vector
  expect_error(
    cluster_parcels(1:10, families = families, k = 3),
    "data.frame|sf"
  )

  # List (not data.frame)
  expect_error(
    cluster_parcels(list(a = 1, b = 2), families = families, k = 3),
    "data.frame|sf"
  )

  # Matrix (not data.frame)
  expect_error(
    cluster_parcels(matrix(1:12, nrow = 3), families = families, k = 3),
    "data.frame|sf"
  )
})

# ===========================================================================
# K BOUNDARY CONDITIONS
# ===========================================================================

test_that("cluster_parcels rejects k equal to number of rows", {
  set.seed(42)
  df <- make_cluster_df(n_per_group = 3)  # 9 rows total
  families <- c("family_C", "family_B", "family_P", "family_S")

  # k == n should fail
  expect_error(
    cluster_parcels(df, families = families, k = 9, method = "kmeans"),
    "less than"
  )

  # k > n should also fail
  expect_error(
    cluster_parcels(df, families = families, k = 15, method = "kmeans"),
    "less than"
  )
})

test_that("cluster_parcels works with k = 2 (minimum valid k)", {
  set.seed(42)
  df <- make_cluster_df(n_per_group = 5)
  families <- c("family_C", "family_B", "family_P", "family_S")

  result <- cluster_parcels(df, families = families, k = 2, method = "kmeans")

  expect_equal(length(unique(result$cluster)), 2)
  expect_true(all(result$cluster %in% 1:2))

  # Cluster profile should have 2 rows
  profiles <- attr(result, "cluster_profile")
  expect_equal(nrow(profiles), 2)
})

test_that("cluster_parcels works with k = n-1 (maximum valid k)", {
  set.seed(42)
  # Small dataset for fast test: 5 rows
  df <- data.frame(
    family_C = c(10, 30, 50, 70, 90),
    family_B = c(15, 35, 55, 75, 95)
  )
  families <- c("family_C", "family_B")

  result <- cluster_parcels(df, families = families, k = 4, method = "kmeans")

  expect_equal(nrow(result), 5)
  expect_true("cluster" %in% names(result))
  # With k = n-1 = 4, at least some clusters will have only 1 member
  expect_equal(length(unique(result$cluster)), 4)
})

# ===========================================================================
# AUTO K WITH HIERARCHICAL METHOD (lines 173-176)
# ===========================================================================

test_that("cluster_parcels auto-determines k with hierarchical method", {
  skip_if_not_installed("sf")

  fixture <- readRDS("fixtures/cluster_reference.rds")
  data <- fixture$input_data
  families <- fixture$families

  result <- cluster_parcels(
    data,
    families = families,
    k = NULL,
    method = "hierarchical"
  )

  # Should have auto-determined k
  optimal_k <- attr(result, "optimal_k")
  expect_type(optimal_k, "integer")
  expect_gte(optimal_k, 2)
  expect_lte(optimal_k, nrow(data) - 1)

  # Should have silhouette scores
  sil_scores <- attr(result, "silhouette_scores")
  expect_type(sil_scores, "double")
  expect_true(all(!is.na(sil_scores)))
  expect_true(length(sil_scores) > 0)

  # Method attribute
  expect_equal(attr(result, "method"), "hierarchical")

  # All parcels should be assigned
  expect_true(all(!is.na(result$cluster)))
  expect_equal(length(unique(result$cluster)), optimal_k)
})

# ===========================================================================
# AUTO K WITH PLAIN DATA.FRAME
# ===========================================================================

test_that("cluster_parcels auto-determines k with plain data.frame", {
  set.seed(42)
  df <- make_cluster_df(n_per_group = 5)
  families <- c("family_C", "family_B", "family_P", "family_S")

  result <- cluster_parcels(df, families = families, k = NULL, method = "kmeans")

  expect_false(inherits(result, "sf"))
  expect_true(!is.null(attr(result, "optimal_k")))
  expect_true(!is.null(attr(result, "silhouette_scores")))

  optimal_k <- attr(result, "optimal_k")
  expect_gte(optimal_k, 2)
  expect_equal(length(unique(result$cluster)), optimal_k)
})

# ===========================================================================
# MAX_K PARAMETER
# ===========================================================================

test_that("cluster_parcels respects max_k parameter", {
  set.seed(42)
  df <- make_cluster_df(n_per_group = 5)  # 15 rows
  families <- c("family_C", "family_B", "family_P", "family_S")

  # With max_k = 4, should test k = 2, 3, 4
  result <- cluster_parcels(df, families = families, k = NULL, max_k = 4, method = "kmeans")

  sil_scores <- attr(result, "silhouette_scores")
  # silhouette_scores should have length max_k - 1 = 3 (for k=2, 3, 4)
  expect_equal(length(sil_scores), 3)
  expect_equal(names(sil_scores), c("2", "3", "4"))

  # Optimal k should be at most 4
  expect_lte(attr(result, "optimal_k"), 4)
})

test_that("cluster_parcels limits max_k when n-1 < max_k", {
  # Create tiny dataset with 4 rows => max valid k is 3
  set.seed(42)
  df <- data.frame(
    family_C = c(10, 50, 90, 30),
    family_B = c(15, 55, 95, 35)
  )
  families <- c("family_C", "family_B")

  # max_k=10 but n=4, so max_test_k = min(10, 3) = 3
  result <- cluster_parcels(df, families = families, k = NULL, max_k = 10, method = "kmeans")

  sil_scores <- attr(result, "silhouette_scores")
  # Only k=2,3 should be tested (max_test_k = 3)
  expect_equal(length(sil_scores), 2)
  expect_equal(names(sil_scores), c("2", "3"))
})

# ===========================================================================
# MULTIPLE NA COLUMNS
# ===========================================================================

test_that("cluster_parcels error message includes all NA family names", {
  set.seed(42)
  df <- make_cluster_df(n_per_group = 3)
  families <- c("family_C", "family_B", "family_P", "family_S")

  # Introduce NA in two families
  df$family_C[1] <- NA
  df$family_P[2] <- NA

  expect_error(
    cluster_parcels(df, families = families, k = 3),
    "family_C.*family_P|family_P.*family_C"
  )
})

# ===========================================================================
# MULTIPLE MISSING FAMILIES
# ===========================================================================

test_that("cluster_parcels error message includes all missing family names", {
  set.seed(42)
  df <- data.frame(family_C = c(1, 2, 3), family_B = c(4, 5, 6))

  expect_error(
    cluster_parcels(df, families = c("family_C", "family_X", "family_Y"), k = 2),
    "family_X.*family_Y|family_Y.*family_X"
  )
})

# ===========================================================================
# MULTIPLE NON-NUMERIC FAMILIES
# ===========================================================================

test_that("cluster_parcels error message includes all non-numeric family names", {
  set.seed(42)
  df <- data.frame(
    family_C = c("a", "b", "c"),
    family_B = factor(c("x", "y", "z")),
    family_P = c(1, 2, 3)
  )

  expect_error(
    cluster_parcels(df, families = c("family_C", "family_B", "family_P"), k = 2),
    "family_C.*family_B|family_B.*family_C"
  )
})

# ===========================================================================
# CLUSTER PROFILE VERIFICATION (data.frame path)
# ===========================================================================

test_that("cluster_parcels profiles are actual means of family values per cluster", {
  # Create a deterministic dataset where we can verify means exactly
  set.seed(123)
  df <- data.frame(
    family_C = c(10, 10, 10, 90, 90, 90),
    family_B = c(20, 20, 20, 80, 80, 80)
  )
  families <- c("family_C", "family_B")

  # With k=2, these should clearly split into two groups

  result <- cluster_parcels(df, families = families, k = 2, method = "kmeans")
  profiles <- attr(result, "cluster_profile")

  # Figure out which cluster is "low" vs "high"
  for (cl in 1:2) {
    indices <- which(result$cluster == cl)
    for (fam in families) {
      expected_mean <- mean(df[[fam]][indices])
      expect_equal(profiles[cl, fam], expected_mean, tolerance = 1e-10)
    }
  }
})

# ===========================================================================
# ORIGINAL COLUMNS PRESERVED
# ===========================================================================

test_that("cluster_parcels preserves all original columns plus adds 'cluster'", {
  set.seed(42)
  df <- data.frame(
    my_id = letters[1:6],
    family_C = c(10, 20, 30, 70, 80, 90),
    family_B = c(15, 25, 35, 75, 85, 95),
    extra_col = c(TRUE, FALSE, TRUE, FALSE, TRUE, FALSE)
  )
  families <- c("family_C", "family_B")

  result <- cluster_parcels(df, families = families, k = 2, method = "kmeans")

  # All original columns should be preserved

  expect_true("my_id" %in% names(result))
  expect_true("extra_col" %in% names(result))
  expect_true("family_C" %in% names(result))
  expect_true("family_B" %in% names(result))
  expect_true("cluster" %in% names(result))

  # Original values should be unchanged
  expect_equal(result$my_id, df$my_id)
  expect_equal(result$extra_col, df$extra_col)
  expect_equal(result$family_C, df$family_C)
  expect_equal(result$family_B, df$family_B)
})

# ===========================================================================
# MASSIF_DEMO_UNITS (larger real dataset)
# ===========================================================================

test_that("cluster_parcels works with massif_demo_units dataset", {
  skip_if_not_installed("sf")

  data(massif_demo_units, package = "nemeton")
  families <- c("family_C", "family_B", "family_P", "family_S")

  # K-means with fixed k
  result <- cluster_parcels(
    massif_demo_units,
    families = families,
    k = 4,
    method = "kmeans"
  )

  expect_s3_class(result, "sf")
  expect_equal(nrow(result), 20)
  expect_equal(length(unique(result$cluster)), 4)
  expect_true(all(result$cluster %in% 1:4))

  profiles <- attr(result, "cluster_profile")
  expect_equal(nrow(profiles), 4)
  expect_equal(ncol(profiles), 4)
})

test_that("cluster_parcels auto k with massif_demo_units", {
  skip_if_not_installed("sf")

  data(massif_demo_units, package = "nemeton")
  families <- c("family_C", "family_B", "family_P", "family_S")

  result <- cluster_parcels(
    massif_demo_units,
    families = families,
    k = NULL,
    max_k = 8,
    method = "kmeans"
  )

  expect_s3_class(result, "sf")
  optimal_k <- attr(result, "optimal_k")
  expect_gte(optimal_k, 2)
  expect_lte(optimal_k, 8)

  sil_scores <- attr(result, "silhouette_scores")
  expect_equal(length(sil_scores), 7) # k=2..8
})

# ===========================================================================
# HIERARCHICAL METHOD WITH PLAIN DATA.FRAME
# ===========================================================================

test_that("cluster_parcels hierarchical with plain data.frame", {
  set.seed(42)
  df <- make_cluster_df(n_per_group = 4)
  families <- c("family_C", "family_B", "family_P", "family_S")

  result <- cluster_parcels(df, families = families, k = 3, method = "hierarchical")

  expect_false(inherits(result, "sf"))
  expect_equal(attr(result, "method"), "hierarchical")
  expect_equal(length(unique(result$cluster)), 3)

  # Check profile
  profiles <- attr(result, "cluster_profile")
  expect_equal(nrow(profiles), 3)
  expect_equal(ncol(profiles), 4)
})

# ===========================================================================
# AUTO K HIERARCHICAL WITH PLAIN DATA.FRAME
# ===========================================================================

test_that("cluster_parcels auto k hierarchical with plain data.frame", {
  set.seed(42)
  df <- make_cluster_df(n_per_group = 5)
  families <- c("family_C", "family_B", "family_P", "family_S")

  result <- cluster_parcels(
    df, families = families, k = NULL, method = "hierarchical", max_k = 6
  )

  expect_false(inherits(result, "sf"))
  expect_equal(attr(result, "method"), "hierarchical")
  expect_true(!is.null(attr(result, "optimal_k")))
  expect_true(!is.null(attr(result, "silhouette_scores")))

  sil_scores <- attr(result, "silhouette_scores")
  expect_equal(length(sil_scores), 5) # k=2..6
})

# ===========================================================================
# SUBSET OF FAMILIES
# ===========================================================================

test_that("cluster_parcels works with a subset of families", {
  set.seed(42)
  df <- make_cluster_df(n_per_group = 5)

  # Use only 2 of 4 families
  result <- cluster_parcels(
    df,
    families = c("family_C", "family_B"),
    k = 3,
    method = "kmeans"
  )

  profiles <- attr(result, "cluster_profile")
  expect_equal(ncol(profiles), 2)
  expect_true(all(names(profiles) %in% c("family_C", "family_B")))
})

# ===========================================================================
# SINGLE FAMILY (minimum)
# ===========================================================================

test_that("cluster_parcels works with a single family column", {
  set.seed(42)
  df <- data.frame(
    family_C = c(10, 12, 11, 50, 52, 51, 90, 88, 91)
  )

  result <- cluster_parcels(df, families = "family_C", k = 3, method = "kmeans")

  expect_equal(length(unique(result$cluster)), 3)
  profiles <- attr(result, "cluster_profile")
  expect_equal(ncol(profiles), 1)
  expect_equal(nrow(profiles), 3)
})

# ===========================================================================
# SILHOUETTE SCORE VALUES
# ===========================================================================

test_that("silhouette scores are bounded between -1 and 1", {
  set.seed(42)
  df <- make_cluster_df(n_per_group = 5)
  families <- c("family_C", "family_B", "family_P", "family_S")

  result <- cluster_parcels(df, families = families, k = NULL, max_k = 5, method = "kmeans")

  sil_scores <- attr(result, "silhouette_scores")
  expect_true(all(sil_scores >= -1))
  expect_true(all(sil_scores <= 1))
})

# ===========================================================================
# OPTIMAL K IS CONSISTENT WITH SILHOUETTE ARGMAX
# ===========================================================================

test_that("optimal_k corresponds to the highest silhouette score", {
  set.seed(42)
  df <- make_cluster_df(n_per_group = 5)
  families <- c("family_C", "family_B", "family_P", "family_S")

  result <- cluster_parcels(df, families = families, k = NULL, max_k = 6, method = "kmeans")

  optimal_k <- attr(result, "optimal_k")
  sil_scores <- attr(result, "silhouette_scores")

  # The optimal_k should be the k with the max silhouette score
  best_index <- which.max(sil_scores)
  expected_k <- as.integer(best_index + 1)  # scores start at k=2
  expect_equal(optimal_k, expected_k)
})

# ===========================================================================
# SF WITH HIERARCHICAL + AUTO K
# ===========================================================================

test_that("cluster_parcels auto k hierarchical preserves sf geometry", {
  skip_if_not_installed("sf")

  data(massif_demo_units, package = "nemeton")
  families <- c("family_C", "family_B", "family_P", "family_S")

  result <- cluster_parcels(
    massif_demo_units,
    families = families,
    k = NULL,
    method = "hierarchical",
    max_k = 6
  )

  expect_s3_class(result, "sf")
  expect_equal(sf::st_crs(result), sf::st_crs(massif_demo_units))
  expect_true(!is.null(attr(result, "optimal_k")))
  expect_equal(attr(result, "method"), "hierarchical")
})

# ===========================================================================
# K=NULL DOES NOT SET ATTRIBUTES WHEN K IS PROVIDED
# ===========================================================================

test_that("when k is provided, optimal_k and silhouette_scores are not set", {
  set.seed(42)
  df <- make_cluster_df(n_per_group = 5)
  families <- c("family_C", "family_B", "family_P", "family_S")

  result <- cluster_parcels(df, families = families, k = 3, method = "kmeans")

  expect_null(attr(result, "optimal_k"))
  expect_null(attr(result, "silhouette_scores"))
  expect_equal(attr(result, "method"), "kmeans")
  expect_true(!is.null(attr(result, "cluster_profile")))
})
