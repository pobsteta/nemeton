# Generate massif_demo_units_extended with 12-Family Referential
# nemeton v0.4.0 - Complete ecosystem services dataset
#
# This script extends the base massif_demo_units with all 12 indicator families:
# - Existing (v0.3.0): C, B, W, A, F, L, T, R (9 families, 18 indicators)
# - New (v0.4.0): S, P, E, N (4 families, 11 indicators)
# Total: 12 families, 29 indicators + 12 family composites

library(sf)
library(dplyr)
library(nemeton)

set.seed(2024)  # Reproducibility

cat("=== Generating massif_demo_units_extended ===\n\n")

# 1. LOAD BASE DATASET =========================================================

cat("Step 1: Loading base dataset (massif_demo_units)...\n")

# Load existing demo data (basic metadata only - no indicators yet)
data("massif_demo_units", package = "nemeton")

# Ensure we have the expected structure
stopifnot(nrow(massif_demo_units) == 20)
stopifnot(inherits(massif_demo_units, "sf"))

cat(sprintf("  ✓ Loaded %d parcels from massif_demo_units\n", nrow(massif_demo_units)))

# Create extended dataset starting from base
massif_demo_units_extended <- massif_demo_units

# Add metadata fields for indicator calculations
massif_demo_units_extended$id <- 1:20
massif_demo_units_extended$name <- sprintf("Parcel_%02d", 1:20)

# Add species codes for volume calculations
species_codes <- c(
  "FASY", "PIAB", "QUPE", "ABAL", "PISY",  # Common European species
  "QURO", "PINI", "LADE", "PSME", "CABE",
  "FASY", "PIAB", "QUPE", "ABAL", "PISY",
  "QURO", "PINI", "LADE", "PSME", "CABE"
)
massif_demo_units_extended$species <- species_codes

# Calculate actual area_ha from geometry
massif_demo_units_extended$area_ha <- as.numeric(sf::st_area(massif_demo_units_extended)) / 10000

cat("  ✓ Added metadata (id, name, species, area_ha)\n\n")

# 1B. GENERATE EXISTING FAMILIES (C, B, W, A, F, L, T, R) =======================

cat("Step 1B: Generating existing families (C, B, W, A, F, L, T, R)...\n")

# Family C - Carbon & Vitality
massif_demo_units_extended$C1 <- pmax(50, rnorm(20, 200, 60))  # Biomass tC/ha
massif_demo_units_extended$C2 <- rnorm(20, 0.01, 0.02)  # NDVI trend

# Family B - Biodiversity
massif_demo_units_extended$B1 <- as.numeric(sample(0:3, 20, replace = TRUE, prob = c(0.3, 0.3, 0.3, 0.1)))  # Protection 0-3
massif_demo_units_extended$B2 <- pmax(1, rnorm(20, 3, 0.8))  # Structural diversity
massif_demo_units_extended$B3 <- pmax(0.1, pmin(1, rnorm(20, 0.6, 0.2)))  # Connectivity 0-1

# Family W - Water
massif_demo_units_extended$W1 <- pmax(0, rnorm(20, 0.8, 0.5))  # Hydro network km/ha
massif_demo_units_extended$W2 <- pmax(0, rnorm(20, 5, 3))  # Wetland %
massif_demo_units_extended$W3 <- pmax(3, rnorm(20, 8, 3))  # TWI

# Family A - Air & Microclimate
massif_demo_units_extended$A1 <- pmax(0.3, pmin(1, rnorm(20, 0.7, 0.15)))  # Forest cover 1km
massif_demo_units_extended$A2 <- pmax(20, rnorm(20, 45, 10))  # Air quality index

# Family F - Soil Fertility
massif_demo_units_extended$F1 <- as.numeric(sample(1:5, 20, replace = TRUE, prob = c(0.1, 0.2, 0.4, 0.2, 0.1)))  # Fertility class
massif_demo_units_extended$F2 <- pmax(0, rnorm(20, 15, 8))  # Slope %

# Family L - Landscape
massif_demo_units_extended$L1 <- pmax(0.1, pmin(0.9, rnorm(20, 0.35, 0.15)))  # Fragmentation
massif_demo_units_extended$L2 <- pmax(0.1, pmin(0.6, rnorm(20, 0.28, 0.10)))  # Edge ratio

# Family T - Temporal Dynamics
massif_demo_units_extended$T1 <- pmax(10, rnorm(20, 100, 50))  # Ancientness years
massif_demo_units_extended$T2 <- pmax(0, rnorm(20, 8, 5))  # Land cover change %

# Family R - Risks & Resilience
massif_demo_units_extended$R1 <- as.numeric(sample(1:5, 20, replace = TRUE, prob = c(0.2, 0.3, 0.3, 0.15, 0.05)))  # Fire risk
massif_demo_units_extended$R2 <- as.numeric(sample(1:5, 20, replace = TRUE, prob = c(0.15, 0.25, 0.35, 0.2, 0.05)))  # Storm risk
massif_demo_units_extended$R3 <- pmax(0.1, pmin(1, rnorm(20, 0.5, 0.15)))  # Water stress 0-1

cat("  ✓ Generated 18 indicators for families C, B, W, A, F, L, T, R\n\n")

# 2. GENERATE FAMILY S - SOCIAL & RECREATIONAL (T100) ==========================

cat("Step 2: Generating Family S - Social & Recreational indicators...\n")

# S1: Trail density (km/ha) - OSM footways/cycleways
# Realistic range: 0-3 km/ha (urban forests can be higher)
# Distribution: Most forests have low-moderate trail density
massif_demo_units_extended$S1 <- pmax(0, rnorm(20, mean = 0.8, sd = 0.5))

# S2: Accessibility score (0-100) - multimodal access
# Higher near population centers, lower in remote areas
# Create gradient based on parcel position
centroids <- sf::st_coordinates(sf::st_centroid(massif_demo_units_extended))
dist_to_center <- sqrt((centroids[,1] - mean(centroids[,1]))^2 +
                        (centroids[,2] - mean(centroids[,2]))^2)
dist_norm <- (dist_to_center - min(dist_to_center)) / (max(dist_to_center) - min(dist_to_center))
massif_demo_units_extended$S2 <- pmax(20, pmin(100, 85 - dist_norm * 60 + rnorm(20, 0, 10)))

# S3: Population proximity (total within 5/10/20km)
# Higher near urban areas, lower in remote forests
# Correlated with accessibility
pop_base <- exp(4 + (1 - dist_norm) * 2.5) + rnorm(20, 0, 10000)
massif_demo_units_extended$S3 <- pmax(1000, pop_base)

cat(sprintf("  ✓ S1 trail density: %.2f ± %.2f km/ha\n",
            mean(massif_demo_units_extended$S1), sd(massif_demo_units_extended$S1)))
cat(sprintf("  ✓ S2 accessibility: %.1f ± %.1f (0-100)\n",
            mean(massif_demo_units_extended$S2), sd(massif_demo_units_extended$S2)))
cat(sprintf("  ✓ S3 population: %.0f ± %.0f persons\n\n",
            mean(massif_demo_units_extended$S3), sd(massif_demo_units_extended$S3)))

# 3. GENERATE FAMILY P - PRODUCTIVE & ECONOMIC (T101) ==========================

cat("Step 3: Generating Family P - Productive & Economic indicators...\n")

# P1: Standing volume (m³/ha) - from allometry
# Realistic range: 50-600 m³/ha depending on age, species, site quality
# Assume volume correlates with parcel area (larger = older/denser)
area_norm <- (massif_demo_units_extended$area_ha - min(massif_demo_units_extended$area_ha)) /
              (max(massif_demo_units_extended$area_ha) - min(massif_demo_units_extended$area_ha))
massif_demo_units_extended$P1 <- pmax(50, 150 + area_norm * 300 + rnorm(20, 0, 80))

# P2: Site productivity (m³/ha/yr) - fertility × climate × species
# Realistic range: 2-12 m³/ha/yr for European temperate forests
# Conifers generally more productive than broadleaves in good conditions
is_conifer <- massif_demo_units_extended$species %in% c("PIAB", "PISY", "ABAL", "PINI", "LADE", "PSME")
base_productivity <- ifelse(is_conifer, 7, 5)
massif_demo_units_extended$P2 <- pmax(2, base_productivity + rnorm(20, 0, 2))

# P3: Timber quality (0-100) - straightness, diameter, defects
# Higher quality in well-managed stands with good site conditions
# Correlated with volume and productivity
quality_base <- 40 + (massif_demo_units_extended$P1 / max(massif_demo_units_extended$P1)) * 40
massif_demo_units_extended$P3 <- pmax(20, pmin(100, quality_base + rnorm(20, 0, 12)))

cat(sprintf("  ✓ P1 volume: %.1f ± %.1f m³/ha\n",
            mean(massif_demo_units_extended$P1), sd(massif_demo_units_extended$P1)))
cat(sprintf("  ✓ P2 productivity: %.2f ± %.2f m³/ha/yr\n",
            mean(massif_demo_units_extended$P2), sd(massif_demo_units_extended$P2)))
cat(sprintf("  ✓ P3 quality: %.1f ± %.1f (0-100)\n\n",
            mean(massif_demo_units_extended$P3), sd(massif_demo_units_extended$P3)))

# 4. GENERATE FAMILY E - ENERGY & CLIMATE (T102) ===============================

cat("Step 4: Generating Family E - Energy & Climate indicators...\n")

# E1: Fuelwood potential (tonnes DM/yr) - residues + coppice
# Realistic range: 1-10 tonnes DM/ha/yr
# Proportional to harvest volume (assume 2% harvest rate, 30% residues)
harvest_rate <- 0.02
residue_fraction <- 0.3
wood_density <- 550  # kg/m³ average
massif_demo_units_extended$E1 <- pmax(0.5,
  massif_demo_units_extended$P1 * harvest_rate * residue_fraction * wood_density / 1000 * 0.5)

# E2: CO2 emission avoidance (tCO2eq/yr) - energy + material substitution
# Realistic range: 1-20 tCO2eq/ha/yr
# Based on ADEME factors: ~0.222 kgCO2eq/kWh for natural gas substitution
# 1 tonne DM wood = 4500 kWh energy
energy_kwh <- massif_demo_units_extended$E1 * 4500
emission_factor <- 0.222  # kgCO2eq/kWh
massif_demo_units_extended$E2 <- pmax(0.5, energy_kwh * emission_factor / 1000 + rnorm(20, 0, 1))

cat(sprintf("  ✓ E1 fuelwood: %.2f ± %.2f tonnes DM/yr\n",
            mean(massif_demo_units_extended$E1), sd(massif_demo_units_extended$E1)))
cat(sprintf("  ✓ E2 CO2 avoided: %.2f ± %.2f tCO2eq/yr\n\n",
            mean(massif_demo_units_extended$E2), sd(massif_demo_units_extended$E2)))

# 5. GENERATE FAMILY N - NATURALNESS & WILDERNESS (T103) =======================

cat("Step 5: Generating Family N - Naturalness & Wilderness indicators...\n")

# N1: Infrastructure distance (m) - roads, buildings, powerlines
# Realistic range: 50-5000 m
# Remote parcels have higher distance (inverse of accessibility)
access_norm <- (massif_demo_units_extended$S2 - min(massif_demo_units_extended$S2)) /
                (max(massif_demo_units_extended$S2) - min(massif_demo_units_extended$S2))
massif_demo_units_extended$N1 <- pmax(50, 2500 - access_norm * 2200 + rnorm(20, 0, 400))

# N2: Forest continuity (ha) - continuous patch area
# Realistic range: 10-1000 ha (larger parcels = more continuous)
# Assume parcels are part of larger forest blocks
patch_multiplier <- runif(20, 5, 50)  # Parcels are 5-50x smaller than their patch
massif_demo_units_extended$N2 <- pmax(10, massif_demo_units_extended$area_ha * patch_multiplier)

# N3: Wilderness composite (0-100) - N1 × N2 × T1 × B1
# This will be calculated from normalized components
# For now, create a proxy based on remoteness + size
wilderness_score <- (massif_demo_units_extended$N1 / max(massif_demo_units_extended$N1)) * 50 +
                    (log(massif_demo_units_extended$N2) / log(max(massif_demo_units_extended$N2))) * 50
massif_demo_units_extended$N3 <- pmax(10, pmin(100, wilderness_score + rnorm(20, 0, 10)))

cat(sprintf("  ✓ N1 infrastructure distance: %.0f ± %.0f m\n",
            mean(massif_demo_units_extended$N1), sd(massif_demo_units_extended$N1)))
cat(sprintf("  ✓ N2 forest continuity: %.1f ± %.1f ha\n",
            mean(massif_demo_units_extended$N2), sd(massif_demo_units_extended$N2)))
cat(sprintf("  ✓ N3 wilderness: %.1f ± %.1f (0-100)\n\n",
            mean(massif_demo_units_extended$N3), sd(massif_demo_units_extended$N3)))

# 6. NORMALIZE ALL INDICATORS (T104) ===========================================

cat("Step 6: Normalizing all 29 indicators...\n")

# Get list of ALL indicators to normalize across 12 families
all_indicators <- c(
  # Family C - Carbon & Vitality
  "C1", "C2",
  # Family B - Biodiversity
  "B1", "B2", "B3",
  # Family W - Water
  "W1", "W2", "W3",
  # Family A - Air & Microclimate
  "A1", "A2",
  # Family F - Soil Fertility
  "F1", "F2",
  # Family L - Landscape
  "L1", "L2",
  # Family T - Temporal Dynamics
  "T1", "T2",
  # Family R - Risks & Resilience
  "R1", "R2", "R3",
  # Family S - Social & Recreational
  "S1", "S2", "S3",
  # Family P - Productive & Economic
  "P1", "P2", "P3",
  # Family E - Energy & Climate
  "E1", "E2",
  # Family N - Naturalness & Wilderness
  "N1", "N2", "N3"
)

# Normalize using minmax method (0-100 scale)
massif_demo_units_extended <- normalize_indicators(
  massif_demo_units_extended,
  indicators = all_indicators,
  method = "minmax",
  suffix = "_norm"
)

cat(sprintf("  ✓ Normalized %d indicators across 12 families\n\n", length(all_indicators)))

# 7. CREATE FAMILY COMPOSITES FOR ALL 12 FAMILIES (T105) =======================

cat("Step 7: Creating family composite indices for all 12 families...\n")

# Create family indices for all 12 families
# This uses the create_family_index function which auto-detects indicators by prefix
massif_demo_units_extended <- create_family_index(
  massif_demo_units_extended,
  family_codes = c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N"),
  method = "mean"
)

cat("  ✓ Created 12 family composite indices:\n")
family_codes <- c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")
for (fam in family_codes) {
  fam_col <- paste0("family_", fam)
  if (fam_col %in% names(massif_demo_units_extended)) {
    fam_mean <- mean(massif_demo_units_extended[[fam_col]], na.rm = TRUE)
    fam_sd <- sd(massif_demo_units_extended[[fam_col]], na.rm = TRUE)
    cat(sprintf("    - family_%s: %.1f ± %.1f\n", fam, fam_mean, fam_sd))
  }
}

cat("\n=== Generation Complete ===\n")
cat(sprintf("Total indicators: %d\n", sum(grepl("^[A-Z][0-9]$", names(massif_demo_units_extended)))))
cat(sprintf("Total families: %d\n", sum(grepl("^family_", names(massif_demo_units_extended)))))
cat(sprintf("Total parcels: %d\n\n", nrow(massif_demo_units_extended)))

# 8. SAVE DATASET (T106) =======================================================

cat("Step 8: Saving massif_demo_units_extended.rda...\n")

# Save to data/ directory
usethis::use_data(massif_demo_units_extended, overwrite = TRUE)

cat("  ✓ Saved to data/massif_demo_units_extended.rda\n\n")

# Print summary statistics
cat("=== Summary Statistics ===\n\n")

cat("Complete 12-Family Referential:\n")
cat(sprintf("  C - Carbon: C1=%.1f tC/ha, C2=%.3f trend\n",
            mean(massif_demo_units_extended$C1),
            mean(massif_demo_units_extended$C2)))
cat(sprintf("  B - Biodiversity: B1=%.1f, B2=%.2f, B3=%.2f\n",
            mean(massif_demo_units_extended$B1),
            mean(massif_demo_units_extended$B2),
            mean(massif_demo_units_extended$B3)))
cat(sprintf("  W - Water: W1=%.2f km/ha, W2=%.1f%%, W3=%.1f\n",
            mean(massif_demo_units_extended$W1),
            mean(massif_demo_units_extended$W2),
            mean(massif_demo_units_extended$W3)))
cat(sprintf("  A - Air: A1=%.2f, A2=%.1f\n",
            mean(massif_demo_units_extended$A1),
            mean(massif_demo_units_extended$A2)))
cat(sprintf("  F - Fertility: F1=%.1f class, F2=%.1f%% slope\n",
            mean(massif_demo_units_extended$F1),
            mean(massif_demo_units_extended$F2)))
cat(sprintf("  L - Landscape: L1=%.2f frag, L2=%.2f edge\n",
            mean(massif_demo_units_extended$L1),
            mean(massif_demo_units_extended$L2)))
cat(sprintf("  T - Temporal: T1=%.0f years, T2=%.1f%% change\n",
            mean(massif_demo_units_extended$T1),
            mean(massif_demo_units_extended$T2)))
cat(sprintf("  R - Risks: R1=%.1f, R2=%.1f, R3=%.2f\n",
            mean(massif_demo_units_extended$R1),
            mean(massif_demo_units_extended$R2),
            mean(massif_demo_units_extended$R3)))

cat("\nNew Families (v0.4.0):\n")
cat(sprintf("  S - Social: S1=%.2f, S2=%.1f, S3=%.0f\n",
            mean(massif_demo_units_extended$S1),
            mean(massif_demo_units_extended$S2),
            mean(massif_demo_units_extended$S3)))
cat(sprintf("  P - Productive: P1=%.1f, P2=%.2f, P3=%.1f\n",
            mean(massif_demo_units_extended$P1),
            mean(massif_demo_units_extended$P2),
            mean(massif_demo_units_extended$P3)))
cat(sprintf("  E - Energy: E1=%.2f, E2=%.2f\n",
            mean(massif_demo_units_extended$E1),
            mean(massif_demo_units_extended$E2)))
cat(sprintf("  N - Naturalness: N1=%.0f, N2=%.1f, N3=%.1f\n\n",
            mean(massif_demo_units_extended$N1),
            mean(massif_demo_units_extended$N2),
            mean(massif_demo_units_extended$N3)))

cat("\n✓ massif_demo_units_extended generation complete!\n")
cat(sprintf("  📊 29 indicators across 12 families\n"))
cat(sprintf("  🌲 20 demo parcels with complete data\n"))
