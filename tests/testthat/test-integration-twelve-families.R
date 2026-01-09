# Integration Tests for 12-Family System
# US5: Verify system integration with complete 12-family referential

test_that("12-family dataset fixture loads correctly", {
  skip_if_not_installed("sf")

  fixture_path <- test_path("fixtures/twelve_family_dataset.rds")
  expect_true(file.exists(fixture_path), info = "Fixture file should exist")

  twelve_families <- readRDS(fixture_path)
  expect_s3_class(twelve_families, "sf")
  expect_equal(nrow(twelve_families), 5)

  # Verify all 12 families have representative indicators
  required_indicators <- c(
    "C1", "C2", # Carbon
    "B1", "B2", "B3", # Biodiversity
    "W1", "W2", "W3", # Water
    "A1", "A2", # Air
    "F1", "F2", # Fertility
    "L1", "L2", # Landscape
    "T1", "T2", # Temporal
    "R1", "R2", "R3", # Risks
    "S1", "S2", "S3", # Social (NEW)
    "P1", "P2", "P3", # Production (NEW)
    "E1", "E2", # Energy (NEW)
    "N1", "N2", "N3" # Naturalness (NEW)
  )

  missing <- setdiff(required_indicators, names(twelve_families))
  expect_length(missing, 0)
})

test_that("create_family_index handles all 12 families", {
  skip_if_not_installed("sf")

  twelve_families <- readRDS(test_path("fixtures/twelve_family_dataset.rds"))

  # Test each family individually
  families <- c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")

  for (fam in families) {
    result <- create_family_index(twelve_families, family_codes = fam)
    family_col <- paste0("family_", fam)
    expect_true(family_col %in% names(result),
      info = paste("Family", fam, "should have family index")
    )
    expect_type(result[[family_col]], "double")
    expect_true(all(!is.na(result[[family_col]])))
  }
})

test_that("create_family_index can process all 12 families together", {
  skip_if_not_installed("sf")

  twelve_families <- readRDS(test_path("fixtures/twelve_family_dataset.rds"))

  result <- create_family_index(
    twelve_families,
    family_codes = c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")
  )

  expected_cols <- paste0("family_", c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N"))
  expect_true(all(expected_cols %in% names(result)))
})

test_that("12-axis radar plot works with all families (T086)", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")

  twelve_families <- readRDS(test_path("fixtures/twelve_family_dataset.rds"))

  # Create family indices for all 12 families
  result <- create_family_index(
    twelve_families,
    family_codes = c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")
  )

  # Generate 12-axis radar plot
  p <- nemeton_radar(result,
    unit_id = 1, mode = "family",
    indicators = c(
      "family_C", "family_B", "family_W", "family_A",
      "family_F", "family_L", "family_T", "family_R",
      "family_S", "family_P", "family_E", "family_N"
    )
  )

  expect_s3_class(p, "gg")
  expect_s3_class(p, "ggplot")

  # Verify plot has 12 axes
  plot_data <- ggplot2::layer_data(p)
  expect_true(nrow(plot_data) >= 12)
})

test_that("12×12 correlation matrix generation works (T087)", {
  skip_if_not_installed("sf")

  twelve_families <- readRDS(test_path("fixtures/twelve_family_dataset.rds"))

  # Create family indices for all 12 families
  result <- create_family_index(
    twelve_families,
    family_codes = c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")
  )

  # Compute correlation matrix (auto-detect all family_* columns)
  cor_matrix <- compute_family_correlations(result)

  expect_type(cor_matrix, "double")
  expect_equal(nrow(cor_matrix), 12)
  expect_equal(ncol(cor_matrix), 12)

  # Column/row names should be family_*
  expected_names <- c(
    "family_C", "family_B", "family_W", "family_A", "family_F", "family_L",
    "family_T", "family_R", "family_S", "family_P", "family_E", "family_N"
  )
  expect_true(all(rownames(cor_matrix) %in% expected_names))
  expect_true(all(colnames(cor_matrix) %in% expected_names))

  # Diagonal should be 1 (correlation with self)
  expect_equal(as.numeric(diag(cor_matrix)), rep(1, 12))

  # Matrix should be symmetric
  expect_equal(cor_matrix, t(cor_matrix))
})

test_that("plot_correlation_matrix handles 12×12 matrix (T087)", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")

  twelve_families <- readRDS(test_path("fixtures/twelve_family_dataset.rds"))

  result <- create_family_index(
    twelve_families,
    family_codes = c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")
  )

  cor_matrix <- compute_family_correlations(result)

  p <- plot_correlation_matrix(cor_matrix)

  expect_s3_class(p, "gg")
  expect_s3_class(p, "ggplot")

  # Plot should have 12×12 = 144 tiles
  plot_data <- ggplot2::layer_data(p)
  expect_equal(nrow(plot_data), 144)
})

test_that("12-family hotspot detection works (T088)", {
  skip_if_not_installed("sf")

  twelve_families <- readRDS(test_path("fixtures/twelve_family_dataset.rds"))

  result <- create_family_index(
    twelve_families,
    family_codes = c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")
  )

  # Identify hotspots across all 12 families (auto-detect family columns)
  hotspots <- identify_hotspots(
    result,
    threshold = 75,
    min_families = 3
  )

  expect_s3_class(hotspots, "sf")
  expect_true("hotspot_count" %in% names(hotspots))
  expect_true("hotspot_families" %in% names(hotspots))

  # At least one parcel should be a hotspot
  expect_true(any(hotspots$hotspot_count > 0))
})

test_that("normalize_indicators handles all 11 new indicators (T089)", {
  skip_if_not_installed("sf")

  twelve_families <- readRDS(test_path("fixtures/twelve_family_dataset.rds"))

  # Test normalization of new Social indicators (scales to 0-100)
  result_s <- normalize_indicators(
    twelve_families,
    indicators = c("S1", "S2", "S3"),
    method = "minmax"
  )

  expect_true(all(c("S1_norm", "S2_norm", "S3_norm") %in% names(result_s)))
  expect_true(all(result_s$S1_norm >= 0 & result_s$S1_norm <= 100, na.rm = TRUE))
  expect_true(all(result_s$S2_norm >= 0 & result_s$S2_norm <= 100, na.rm = TRUE))

  # Test normalization of new Production indicators
  result_p <- normalize_indicators(
    twelve_families,
    indicators = c("P1", "P2", "P3"),
    method = "minmax"
  )

  expect_true(all(c("P1_norm", "P2_norm", "P3_norm") %in% names(result_p)))
  expect_true(all(result_p$P1_norm >= 0 & result_p$P1_norm <= 100, na.rm = TRUE))

  # Test normalization of new Energy indicators
  result_e <- normalize_indicators(
    twelve_families,
    indicators = c("E1", "E2"),
    method = "minmax"
  )

  expect_true(all(c("E1_norm", "E2_norm") %in% names(result_e)))
  expect_true(all(result_e$E1_norm >= 0 & result_e$E1_norm <= 100, na.rm = TRUE))

  # Test normalization of new Naturalness indicators
  result_n <- normalize_indicators(
    twelve_families,
    indicators = c("N1", "N2", "N3"),
    method = "minmax"
  )

  expect_true(all(c("N1_norm", "N2_norm", "N3_norm") %in% names(result_n)))
  expect_true(all(result_n$N1_norm >= 0 & result_n$N1_norm <= 100, na.rm = TRUE))
  expect_true(all(result_n$N3_norm >= 0 & result_n$N3_norm <= 100, na.rm = TRUE))
})

test_that("normalize_indicators quantile method works for new families", {
  skip_if_not_installed("sf")

  twelve_families <- readRDS(test_path("fixtures/twelve_family_dataset.rds"))

  # Test all 11 new indicators together
  result <- normalize_indicators(
    twelve_families,
    indicators = c("S1", "S2", "S3", "P1", "P2", "P3", "E1", "E2", "N1", "N2", "N3"),
    method = "quantile"
  )

  new_indicators_norm <- paste0(c("S1", "S2", "S3", "P1", "P2", "P3", "E1", "E2", "N1", "N2", "N3"), "_norm")
  expect_true(all(new_indicators_norm %in% names(result)))

  # Quantile normalization returns percentile ranks (0-100)
  for (col in new_indicators_norm) {
    expect_true(all(result[[col]] >= 0 & result[[col]] <= 100, na.rm = TRUE))
  }
})

test_that("create_composite_index works with 12-family dataset", {
  skip_if_not_installed("sf")

  twelve_families <- readRDS(test_path("fixtures/twelve_family_dataset.rds"))

  # Normalize all families first
  normalized <- normalize_indicators(
    twelve_families,
    indicators = c("C1", "B1", "W1", "A1", "F1", "L1", "T1", "R1", "S1", "P1", "E1", "N1"),
    method = "minmax"
  )

  # Create composite index from all 12 families
  composite <- create_composite_index(
    normalized,
    indicators = c(
      "C1_norm", "B1_norm", "W1_norm", "A1_norm", "F1_norm", "L1_norm",
      "T1_norm", "R1_norm", "S1_norm", "P1_norm", "E1_norm", "N1_norm"
    ),
    weights = rep(1 / 12, 12),
    aggregation = "weighted_mean"
  )

  expect_true("composite_index" %in% names(composite))
  expect_type(composite$composite_index, "double")
  expect_true(all(composite$composite_index >= 0 & composite$composite_index <= 100, na.rm = TRUE))
})

test_that("family names are correct for new families S, P, E, N", {
  # Test English names
  expect_equal(get_family_name("S", lang = "en"), "Social & Recreational")
  expect_equal(get_family_name("P", lang = "en"), "Productive & Economic")
  expect_equal(get_family_name("E", lang = "en"), "Energy & Climate")
  expect_equal(get_family_name("N", lang = "en"), "Naturalness & Wilderness")

  # Test French names
  expect_equal(get_family_name("S", lang = "fr"), "S – Social / U – Usages récréatifs")
  expect_equal(get_family_name("P", lang = "fr"), "P – Productif / É – Économie forestière")
  expect_equal(get_family_name("E", lang = "fr"), "E – Énergie / C – Climat")
  expect_equal(get_family_name("N", lang = "fr"), "N – Naturalité / S – Sauvage")
})
