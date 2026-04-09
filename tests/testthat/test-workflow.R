# test-workflow-v030.R
# Integration Tests for v0.3.0 - Full Multi-Family Workflow
# T061: Complete workflow from data loading to visualization

# ==============================================================================
# T061: Full v0.3.0 Workflow Integration Test
# ==============================================================================

# Note: Complete v0.3.0 pipe workflow test removed - deprecated in favor of nemeton_compute()
# For a complete workflow, use:
#   result <- nemeton_compute(units, layers, indicators = c("indicateur_t1_anciennete", "indicateur_r2_tempete", ...))
#   normalized <- normalize_indicators(result, ...)
#   final <- create_family_index(normalized, ...)

test_that("v0.3.0 workflow maintains backward compatibility with v0.2.0", {
  skip_if_not_installed("nemeton")

  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  # v0.2.0 workflow should still work
  units$C1 <- runif(5, 100, 500)
  units$W1 <- runif(5, 10, 30)

  # v0.3.0 indicators
  units$B1 <- runif(5, 20, 80)
  units$R1 <- runif(5, 10, 70)

  # Normalize all together
  normalized <- normalize_indicators(units, method = "minmax")

  # Create family indices
  families <- create_family_index(normalized)

  # Should have both old and new families
  expect_true("famille_carbone" %in% names(families))
  expect_true("famille_eau" %in% names(families))
  expect_true("famille_biodiversite" %in% names(families))
  expect_true("famille_risque" %in% names(families))

  # All should be valid
  expect_true(all(!is.na(families$famille_carbone)))
  expect_true(all(!is.na(families$famille_biodiversite)))
})

test_that("v0.3.0 workflow handles partial indicator sets gracefully", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # Only some new family indicators
  units$B1 <- c(25, 50, 75)
  units$B2 <- c(0.3, 0.6, 0.9)
  # B3 missing

  units$R1 <- c(30, 50, 70)
  # R2, R3 missing

  units$T1 <- c(50, 100, 150)
  units$T2 <- c(0.5, 1.0, 2.0)

  # Should still work with partial indicators
  normalized <- suppressWarnings(normalize_indicators(units, method = "minmax"))
  families <- create_family_index(normalized)

  # Should create families from available indicators
  expect_true("famille_biodiversite" %in% names(families)) # From B1, B2
  expect_true("famille_risque" %in% names(families)) # From R1 only
  expect_true("famille_temporel" %in% names(families)) # From T1, T2

  # Family B should average B1 and B2
  expect_true(all(!is.na(families$famille_biodiversite)))
})
