#!/usr/bin/env Rscript
# Test script for nemeton v0.2.0
# Tests package installation and core workflows with massif_demo data

cat("═══════════════════════════════════════════════════════════\n")
cat("            nemeton v0.2.0 - Integration Tests\n")
cat("═══════════════════════════════════════════════════════════\n\n")

# =============================================================================
# STEP 1: Install Package from Local Source
# =============================================================================

cat("STEP 1: Installing package from local source...\n")
cat("───────────────────────────────────────────────────────────\n")

if (!requireNamespace("devtools", quietly = TRUE)) {
  install.packages("devtools", quiet = TRUE)
}

tryCatch({
  devtools::install(".", upgrade = "never", quiet = TRUE, force = TRUE)
  cat("✓ Package installed successfully\n\n")
}, error = function(e) {
  cat("✗ Installation failed:", conditionMessage(e), "\n\n")
  quit(status = 1)
})

# =============================================================================
# STEP 2: Load Package and Dependencies
# =============================================================================

cat("STEP 2: Loading package and dependencies...\n")
cat("───────────────────────────────────────────────────────────\n")

required_packages <- c("nemeton", "sf", "terra", "ggplot2", "dplyr")

for (pkg in required_packages) {
  tryCatch({
    library(pkg, character.only = TRUE)
    cat("✓", pkg, "loaded\n")
  }, error = function(e) {
    cat("✗", pkg, "failed to load:", conditionMessage(e), "\n")
    quit(status = 1)
  })
}

cat("\n")

# =============================================================================
# STEP 3: Verify Package Version
# =============================================================================

cat("STEP 3: Verifying package version...\n")
cat("───────────────────────────────────────────────────────────\n")

version <- packageVersion("nemeton")
cat("Package version:", as.character(version), "\n")

if (version != "0.2.0") {
  cat("✗ Expected version 0.2.0, got", as.character(version), "\n\n")
  quit(status = 1)
} else {
  cat("✓ Version check passed\n\n")
}

# =============================================================================
# STEP 4: Load Demo Data
# =============================================================================

cat("STEP 4: Loading massif_demo data...\n")
cat("───────────────────────────────────────────────────────────\n")

data(massif_demo_units)

if (!inherits(massif_demo_units, "sf")) {
  cat("✗ massif_demo_units is not an sf object\n\n")
  quit(status = 1)
}

cat("✓ massif_demo_units loaded:", nrow(massif_demo_units), "parcels\n")
cat("  Total area:", sum(massif_demo_units$surface_ha), "ha\n")

# Load layers
layers <- massif_demo_layers()
cat("✓ massif_demo_layers loaded:", length(layers), "layers\n")
cat("  Rasters:", sum(sapply(layers, inherits, "SpatRaster")), "\n")
cat("  Vectors:", sum(sapply(layers, inherits, "sf")), "\n\n")

# =============================================================================
# STEP 5: Test Basic Workflow (v0.1.0 Compatibility)
# =============================================================================

cat("STEP 5: Testing backward compatibility (v0.1.0 workflow)...\n")
cat("───────────────────────────────────────────────────────────\n")

units_small <- massif_demo_units[1:5, ]

tryCatch({
  # Compute legacy indicators
  results_legacy <- nemeton_compute(
    units_small,
    layers,
    indicators = c("carbon", "water"),
    preprocess = TRUE
  )

  cat("✓ nemeton_compute() with legacy indicators\n")

  # Normalize
  normalized_legacy <- normalize_indicators(
    results_legacy,
    method = "minmax"
  )

  cat("✓ normalize_indicators() working\n")

  # Create composite
  composite_legacy <- create_composite_index(
    normalized_legacy,
    indicators = c("carbon_norm", "water_norm"),
    weights = c(0.5, 0.5),
    name = "ecosystem_health"
  )

  cat("✓ create_composite_index() working\n")

  # Visualize
  p_legacy <- nemeton_radar(composite_legacy, unit_id = 1)

  cat("✓ nemeton_radar() working\n")
  cat("✓ Backward compatibility: PASSED\n\n")

}, error = function(e) {
  cat("✗ Backward compatibility test failed:", conditionMessage(e), "\n\n")
  quit(status = 1)
})

# =============================================================================
# STEP 6: Test Multi-Family System (v0.2.0 New Features)
# =============================================================================

cat("STEP 6: Testing multi-family system (v0.2.0)...\n")
cat("───────────────────────────────────────────────────────────\n")

# Create synthetic multi-family data
units_families <- massif_demo_units[1:5, ]
units_families$C1 <- rnorm(5, 150, 20)  # Carbon biomass
units_families$C2 <- runif(5, 0.7, 0.9) # NDVI
units_families$W1 <- rnorm(5, 0.8, 0.2) # Water network
units_families$W2 <- runif(5, 5, 15)    # Wetlands %
units_families$W3 <- rnorm(5, 8, 2)     # TWI
units_families$F1 <- runif(5, 40, 80)   # Soil fertility
units_families$F2 <- rnorm(5, 15, 5)    # Erosion risk
units_families$L1 <- rpois(5, 3)        # Fragmentation
units_families$L2 <- rnorm(5, 50, 15)   # Edge ratio

cat("✓ Synthetic multi-family data created (9 indicators)\n")

tryCatch({
  # Test normalization by family
  normalized_families <- normalize_indicators(
    units_families,
    method = "minmax",
    by_family = TRUE
  )

  cat("✓ normalize_indicators(by_family = TRUE)\n")

  # Check that normalization worked
  if (!all(c("C1", "C2", "W1") %in% names(normalized_families))) {
    stop("Normalized columns missing")
  }

  cat("✓ Family-aware normalization: columns present\n")

  # Create family indices
  family_scores <- create_family_index(
    normalized_families,
    method = "weighted",
    weights = list(
      C = c(C1 = 0.7, C2 = 0.3),
      W = c(W1 = 0.3, W2 = 0.3, W3 = 0.4),
      F = c(F1 = 0.6, F2 = 0.4),
      L = c(L1 = 0.5, L2 = 0.5)
    )
  )

  cat("✓ create_family_index() with custom weights\n")

  # Check family columns
  family_cols <- grep("^family_", names(family_scores), value = TRUE)
  cat("✓ Family scores created:", paste(family_cols, collapse = ", "), "\n")

  if (length(family_cols) < 4) {
    stop("Expected at least 4 family scores, got ", length(family_cols))
  }

  # Test multi-family radar
  p_families <- nemeton_radar(
    family_scores,
    unit_id = 1,
    mode = "family"
  )

  cat("✓ nemeton_radar(mode = 'family')\n")
  cat("✓ Multi-family system: PASSED\n\n")

}, error = function(e) {
  cat("✗ Multi-family test failed:", conditionMessage(e), "\n\n")
  print(traceback())
  quit(status = 1)
})

# =============================================================================
# STEP 7: Test Temporal Analysis (v0.2.0 New Features)
# =============================================================================

cat("STEP 7: Testing temporal analysis (v0.2.0)...\n")
cat("───────────────────────────────────────────────────────────\n")

# Create synthetic temporal data
units_2015 <- massif_demo_units[1:5, ]
units_2015$parcel_id <- paste0("P", 1:5)
units_2015$carbon <- rnorm(5, 120, 15)
units_2015$water <- rnorm(5, 8, 2)

units_2020 <- massif_demo_units[1:5, ]
units_2020$parcel_id <- paste0("P", 1:5)
units_2020$carbon <- units_2015$carbon * runif(5, 1.1, 1.2)
units_2020$water <- units_2015$water + rnorm(5, 0.5, 0.3)

units_2025 <- massif_demo_units[1:5, ]
units_2025$parcel_id <- paste0("P", 1:5)
units_2025$carbon <- units_2020$carbon * runif(5, 1.1, 1.15)
units_2025$water <- units_2020$water + rnorm(5, 0.8, 0.4)

cat("✓ Synthetic temporal data created (3 periods)\n")

tryCatch({
  # Create temporal object
  temporal_data <- nemeton_temporal(
    periods = list(
      "2015" = units_2015,
      "2020" = units_2020,
      "2025" = units_2025
    ),
    id_column = "parcel_id"
  )

  cat("✓ nemeton_temporal() created\n")

  # Verify temporal structure
  if (!inherits(temporal_data, "nemeton_temporal")) {
    stop("temporal_data is not nemeton_temporal class")
  }

  if (length(temporal_data$periods) != 3) {
    stop("Expected 3 periods, got ", length(temporal_data$periods))
  }

  cat("✓ Temporal object structure verified\n")

  # Calculate change rates
  rates_abs <- calculate_change_rate(
    temporal_data,
    indicators = c("carbon", "water"),
    type = "absolute"
  )

  cat("✓ calculate_change_rate(type = 'absolute')\n")

  rates_rel <- calculate_change_rate(
    temporal_data,
    indicators = c("carbon", "water"),
    type = "relative"
  )

  cat("✓ calculate_change_rate(type = 'relative')\n")

  # Check rate columns
  if (!all(c("carbon_rate_abs", "water_rate_abs") %in% names(rates_abs))) {
    stop("Absolute rate columns missing")
  }

  if (!all(c("carbon_rate_rel", "water_rate_rel") %in% names(rates_rel))) {
    stop("Relative rate columns missing")
  }

  cat("✓ Change rate calculations verified\n")

  # Test temporal visualizations
  p_trend <- plot_temporal_trend(
    temporal_data,
    indicator = "carbon"
  )

  cat("✓ plot_temporal_trend() working\n")

  p_heatmap <- plot_temporal_heatmap(
    temporal_data,
    unit_id = "P1",
    indicators = c("carbon", "water")
  )

  cat("✓ plot_temporal_heatmap() working\n")
  cat("✓ Temporal analysis: PASSED\n\n")

}, error = function(e) {
  cat("✗ Temporal analysis test failed:", conditionMessage(e), "\n\n")
  print(traceback())
  quit(status = 1)
})

# =============================================================================
# STEP 8: Summary
# =============================================================================

cat("═══════════════════════════════════════════════════════════\n")
cat("                    TEST SUMMARY\n")
cat("═══════════════════════════════════════════════════════════\n\n")

cat("✅ Package installation: PASSED\n")
cat("✅ Package loading: PASSED\n")
cat("✅ Version check (0.2.0): PASSED\n")
cat("✅ Demo data loading: PASSED\n")
cat("✅ Backward compatibility (v0.1.0): PASSED\n")
cat("✅ Multi-family system (v0.2.0): PASSED\n")
cat("✅ Temporal analysis (v0.2.0): PASSED\n\n")

cat("═══════════════════════════════════════════════════════════\n")
cat("         ALL INTEGRATION TESTS PASSED ✓\n")
cat("═══════════════════════════════════════════════════════════\n\n")

cat("Package nemeton v0.2.0 is ready for production use!\n\n")

# Exit with success
quit(status = 0, save = "no")
