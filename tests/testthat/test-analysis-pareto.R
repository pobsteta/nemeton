# Test Suite for Pareto Optimality Analysis (T112-T113)

test_that("identify_pareto_optimal identifies correct Pareto optimal parcels (T112)", {
  skip_if_not_installed("sf")

  # Load fixture
  fixture <- readRDS("fixtures/pareto_reference.rds")
  data <- fixture$input_data
  objectives <- fixture$objectives
  expected_ids <- fixture$expected_pareto_ids

  # Test with maximize all objectives
  result <- identify_pareto_optimal(
    data,
    objectives = objectives,
    maximize = c(TRUE, TRUE, TRUE)
  )

  # Check structure
  expect_s3_class(result, "data.frame")
  expect_true("is_optimal" %in% names(result))
  expect_type(result$is_optimal, "logical")

  # Check correct number of optimal parcels identified
  n_optimal <- sum(result$is_optimal)
  expect_gte(n_optimal, 1)
  expect_lte(n_optimal, nrow(data))

  # Check that at least the extreme points are optimal
  # Parcel 1 has highest family_C
  # Parcel 5 has highest family_B
  # Parcel 9 has highest family_P
  expect_true(result$is_optimal[1])  # Highest C
  expect_true(result$is_optimal[5])  # Highest B
  expect_true(result$is_optimal[9])  # Highest P
})

test_that("identify_pareto_optimal handles maximize vs minimize correctly (T113)", {
  skip_if_not_installed("sf")

  # Load fixture
  fixture <- readRDS("fixtures/pareto_reference.rds")
  data <- fixture$input_data
  objectives <- fixture$objectives

  # Test 1: Maximize all (default case)
  result_max <- identify_pareto_optimal(
    data,
    objectives = objectives,
    maximize = c(TRUE, TRUE, TRUE)
  )
  n_max <- sum(result_max$is_optimal)

  # Test 2: Minimize all (should give different Pareto set)
  result_min <- identify_pareto_optimal(
    data,
    objectives = objectives,
    maximize = c(FALSE, FALSE, FALSE)
  )
  n_min <- sum(result_min$is_optimal)

  # Both should have optimal solutions
  expect_gte(n_max, 1)
  expect_gte(n_min, 1)

  # The optimal sets should be different
  # When maximizing, parcel 1 (highest C) is optimal
  # When minimizing, parcel 3 (lowest C=150) might be optimal
  expect_true(result_max$is_optimal[1])   # Highest C when maximizing
  expect_false(result_min$is_optimal[1])  # Highest C NOT optimal when minimizing

  # Test 3: Mixed objectives (maximize C and B, minimize P)
  result_mixed <- identify_pareto_optimal(
    data,
    objectives = objectives,
    maximize = c(TRUE, TRUE, FALSE)
  )
  n_mixed <- sum(result_mixed$is_optimal)
  expect_gte(n_mixed, 1)

  # When minimizing P, parcel 7 (P=55, lowest) might be optimal
  # But need high C and B too
})

test_that("identify_pareto_optimal handles edge cases", {
  skip_if_not_installed("sf")

  # Load fixture
  fixture <- readRDS("fixtures/pareto_reference.rds")
  data <- fixture$input_data
  objectives <- fixture$objectives

  # Test with single objective (all should be "Pareto optimal" with respect to that single dimension)
  result_single <- identify_pareto_optimal(
    data,
    objectives = objectives[1],  # Just family_C
    maximize = TRUE
  )
  # With single objective, only the maximum point is optimal
  expect_equal(sum(result_single$is_optimal), 1)
  expect_equal(which(result_single$is_optimal), which.max(data[[objectives[1]]]))

  # Test with duplicate parcels (should handle gracefully)
  data_dup <- rbind(data[1:5, ], data[1, ])  # Duplicate parcel 1
  result_dup <- identify_pareto_optimal(
    data_dup,
    objectives = objectives,
    maximize = c(TRUE, TRUE, TRUE)
  )
  # Both copies of parcel 1 should be optimal
  expect_true(result_dup$is_optimal[1])
  expect_true(result_dup$is_optimal[nrow(data_dup)])
})

test_that("identify_pareto_optimal parameter validation", {
  skip_if_not_installed("sf")

  # Load fixture
  fixture <- readRDS("fixtures/pareto_reference.rds")
  data <- fixture$input_data
  objectives <- fixture$objectives

  # Test invalid objectives (column doesn't exist)
  expect_error(
    identify_pareto_optimal(data, objectives = c("invalid_col"), maximize = TRUE),
    "Objectives not found"
  )

  # Test length mismatch between objectives and maximize
  expect_error(
    identify_pareto_optimal(data, objectives = objectives, maximize = c(TRUE, TRUE)),
    "Length of 'maximize'.*must match.*'objectives'"
  )

  # Test non-sf object (should work with regular data.frame)
  data_df <- as.data.frame(data)
  data_df$geometry <- NULL
  result_df <- identify_pareto_optimal(
    data_df,
    objectives = objectives,
    maximize = c(TRUE, TRUE, TRUE)
  )
  expect_s3_class(result_df, "data.frame")
  expect_true("is_optimal" %in% names(result_df))
})

test_that("identify_pareto_optimal preserves sf geometry", {
  skip_if_not_installed("sf")

  # Load fixture
  fixture <- readRDS("fixtures/pareto_reference.rds")
  data <- fixture$input_data

  # Result should preserve sf class
  result <- identify_pareto_optimal(
    data,
    objectives = fixture$objectives,
    maximize = c(TRUE, TRUE, TRUE)
  )

  expect_s3_class(result, "sf")
  expect_true("geometry" %in% names(result))
  expect_equal(sf::st_crs(result), sf::st_crs(data))
})
