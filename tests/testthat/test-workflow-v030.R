# test-workflow-v030.R
# Integration Tests for v0.3.0 - Full Multi-Family Workflow
# T061: Complete workflow from data loading to visualization

library(testthat)
library(sf)
library(terra)

# ==============================================================================
# T061: Full v0.3.0 Workflow Integration Test
# ==============================================================================

test_that("Complete v0.3.0 workflow: All 10 new indicators → families → radar", {
  skip_if_not_installed("nemeton")

  # Load demo data
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:10, ]

  # Load fixtures for testing
  dem <- terra::rast(test_path("fixtures/climate/dem_demo.tif"))
  climate <- list(
    temperature = terra::rast(test_path("fixtures/climate/temperature_demo.tif")),
    precipitation = terra::rast(test_path("fixtures/climate/precipitation_demo.tif"))
  )
  lc_1990 <- terra::rast(test_path("fixtures/land_cover/land_cover_1990.tif"))
  lc_2020 <- terra::rast(test_path("fixtures/land_cover/land_cover_2020.tif"))
  protected_areas <- readRDS(test_path("fixtures/protected_areas/protected_areas_demo.rds"))

  # Add required attributes
  units$species <- sample(c("Pinus", "Quercus", "Fagus"), 10, replace = TRUE)
  units$age <- runif(10, 20, 250)
  units$height <- runif(10, 10, 30)
  units$density <- runif(10, 0.5, 0.9)
  units$age_class <- sample(c("young", "mature", "old"), 10, replace = TRUE)
  units$strata <- sample(1:3, 10, replace = TRUE)

  # ============================================================================
  # Step 1: Compute all 10 v0.3.0 indicators
  # ============================================================================

  # Biodiversity family (B1-B3)
  result <- units %>%
    indicator_biodiversity_protection(protected_areas = protected_areas) %>%
    indicator_biodiversity_structure(
      age_class_field = "age_class",
      strata_field = "strata",
      species_field = "species"
    ) %>%
    indicator_biodiversity_connectivity(corridors = NULL)  # Will use default fallback

  # Risk/Resilience family (R1-R3)
  result <- result %>%
    indicator_risk_fire(dem = dem, species_field = "species", climate = climate) %>%
    indicator_risk_storm(dem = dem, height_field = "height", density_field = "density")

  # Compute W3 (TWI) for R3 (reuse from v0.2.0)
  result$W3 <- runif(10, 5, 15)

  result <- result %>%
    indicator_risk_drought(twi_field = "W3", climate = climate, species_field = "species")

  # Temporal family (T1-T2)
  result <- result %>%
    indicator_temporal_age(age_field = "age") %>%
    indicator_temporal_change(
      land_cover_early = lc_1990,
      land_cover_late = lc_2020,
      years_elapsed = 30,
      interpretation = "stability"
    )

  # Air quality family (A1-A2)
  result <- result %>%
    indicator_air_coverage(land_cover = lc_2020, buffer_radius = 1000)

  # Create mock road and urban data for A2
  bbox <- st_bbox(units)
  roads <- st_sf(
    road_id = "R1",
    geometry = st_sfc(
      st_linestring(matrix(c(bbox["xmin"], bbox["xmax"], bbox["ymin"], bbox["ymax"]), ncol = 2)),
      crs = st_crs(units)
    )
  )

  urban_areas <- st_sf(
    urban_id = "U1",
    geometry = st_sfc(
      st_point(c(mean(c(bbox["xmin"], bbox["xmax"])), mean(c(bbox["ymin"], bbox["ymax"])))),
      crs = st_crs(units)
    )
  )

  result <- result %>%
    indicator_air_quality(roads = roads, urban_areas = urban_areas, method = "proxy")

  # ============================================================================
  # Step 2: Verify all 10 indicators were computed
  # ============================================================================

  expect_s3_class(result, "sf")

  # Biodiversity (B1-B3)
  expect_true("B1" %in% names(result))
  expect_true("B2" %in% names(result))
  expect_true("B3" %in% names(result))

  # Risk/Resilience (R1-R3)
  expect_true("R1" %in% names(result))
  expect_true("R2" %in% names(result))
  expect_true("R3" %in% names(result))

  # Temporal (T1-T2)
  expect_true("T1" %in% names(result))
  expect_true("T2" %in% names(result))

  # Air quality (A1-A2)
  expect_true("A1" %in% names(result))
  expect_true("A2" %in% names(result))

  # All should be numeric and in valid range
  expect_true(all(result$B1 >= 0 & result$B1 <= 100, na.rm = TRUE))
  expect_true(all(result$R1 >= 0 & result$R1 <= 100, na.rm = TRUE))
  expect_true(all(result$T1 >= 0, na.rm = TRUE))
  expect_true(all(result$A1 >= 0 & result$A1 <= 100, na.rm = TRUE))

  # ============================================================================
  # Step 3: Normalize all indicators
  # ============================================================================

  normalized <- normalize_indicators(
    result,
    indicators = c("B1", "B2", "B3", "R1", "R2", "R3", "T1", "T2", "A1", "A2"),
    method = "minmax"
  )

  # Verify normalized columns exist
  expect_true(all(c("B1_norm", "B2_norm", "B3_norm") %in% names(normalized)))
  expect_true(all(c("R1_norm", "R2_norm", "R3_norm") %in% names(normalized)))
  expect_true(all(c("T1_norm", "T2_norm") %in% names(normalized)))
  expect_true(all(c("A1_norm", "A2_norm") %in% names(normalized)))

  # All normalized values in 0-100 range
  expect_true(all(normalized$B1_norm >= 0 & normalized$B1_norm <= 100, na.rm = TRUE))
  expect_true(all(normalized$R1_norm >= 0 & normalized$R1_norm <= 100, na.rm = TRUE))
  expect_true(all(normalized$T1_norm >= 0 & normalized$T1_norm <= 100, na.rm = TRUE))
  expect_true(all(normalized$A1_norm >= 0 & normalized$A1_norm <= 100, na.rm = TRUE))

  # ============================================================================
  # Step 4: Create family indices
  # ============================================================================

  families <- create_family_index(
    normalized,
    family_codes = c("B", "R", "T", "A")
  )

  # Verify family indices created
  expect_true("family_B" %in% names(families))
  expect_true("family_R" %in% names(families))
  expect_true("family_T" %in% names(families))
  expect_true("family_A" %in% names(families))

  # All family indices should be valid numbers
  expect_true(all(!is.na(families$family_B)))
  expect_true(all(!is.na(families$family_R)))
  expect_true(all(!is.na(families$family_T)))
  expect_true(all(!is.na(families$family_A)))

  # Family indices should be in reasonable range
  expect_true(all(families$family_B >= 0 & families$family_B <= 100))
  expect_true(all(families$family_R >= 0 & families$family_R <= 100))

  # ============================================================================
  # Step 5: Create radar plot with all 9 families (if v0.2.0 families exist)
  # ============================================================================

  # Add v0.2.0 family indicators for complete 9-family test
  families$C1 <- runif(10, 100, 500)
  families$W1 <- runif(10, 10, 30)
  families$F1 <- runif(10, 5, 20)
  families$L1 <- runif(10, 0.3, 0.8)

  # Create all family indices
  all_families <- create_family_index(families)

  # Create radar plot
  radar_plot <- nemeton_radar(
    all_families,
    unit_id = 1,
    indicators = grep("^family_", names(all_families), value = TRUE),
    normalize = FALSE
  )

  expect_s3_class(radar_plot, "ggplot")
  expect_true(!is.null(radar_plot$data))

  # ============================================================================
  # Final verification: Complete workflow successful
  # ============================================================================

  expect_s3_class(result, "sf")
  expect_s3_class(normalized, "sf")
  expect_s3_class(families, "sf")
  expect_s3_class(all_families, "sf")
  expect_s3_class(radar_plot, "ggplot")

  # Original geometry preserved
  expect_true(!is.null(st_geometry(families)))
})

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
  expect_true("family_C" %in% names(families))
  expect_true("family_W" %in% names(families))
  expect_true("family_B" %in% names(families))
  expect_true("family_R" %in% names(families))

  # All should be valid
  expect_true(all(!is.na(families$family_C)))
  expect_true(all(!is.na(families$family_B)))
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
  normalized <- normalize_indicators(units, method = "minmax")
  families <- create_family_index(normalized)

  # Should create families from available indicators
  expect_true("family_B" %in% names(families))  # From B1, B2
  expect_true("family_R" %in% names(families))  # From R1 only
  expect_true("family_T" %in% names(families))  # From T1, T2

  # Family B should average B1 and B2
  expect_true(all(!is.na(families$family_B)))
})
