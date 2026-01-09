# Create 12-Family Test Fixture
# Generates synthetic dataset with all 12 indicator families for integration testing

library(sf)

# Create base spatial units (5 parcels for testing)
set.seed(42)
twelve_family_units <- st_sf(
  id = 1:5,
  name = paste0("Parcel_", LETTERS[1:5]),

  # Family C - Carbon & Vitality
  C1 = c(250, 180, 320, 210, 275), # Biomass (tC/ha)
  C2 = c(0.02, -0.01, 0.03, 0.01, 0.02), # NDVI trend

  # Family B - Biodiversity
  B1 = c(2, 0, 3, 1, 2), # Protection status
  B2 = c(3.5, 2.8, 4.2, 3.1, 3.7), # Structural diversity
  B3 = c(0.85, 0.45, 0.92, 0.67, 0.78), # Connectivity

  # Family W - Water
  W1 = c(1.2, 0.3, 2.1, 0.8, 1.5), # Hydro network density
  W2 = c(5, 0, 12, 2, 7), # Wetland area (%)
  W3 = c(8.5, 4.2, 12.3, 6.7, 9.1), # TWI

  # Family A - Air & Microclimate
  A1 = c(0.75, 0.45, 0.88, 0.62, 0.71), # Forest cover 1km
  A2 = c(45, 38, 52, 42, 47), # Air quality index

  # Family F - Soil Fertility
  F1 = c(4, 3, 5, 3, 4), # Fertility class
  F2 = c(12, 25, 8, 18, 15), # Slope (%)

  # Family L - Landscape
  L1 = c(0.3, 0.6, 0.2, 0.4, 0.35), # Fragmentation
  L2 = c(0.25, 0.42, 0.18, 0.31, 0.28), # Edge ratio

  # Family T - Temporal Dynamics
  T1 = c(120, 45, 180, 80, 95), # Ancientness (years)
  T2 = c(5, 15, 2, 8, 6), # Land cover change (%)

  # Family R - Risks & Resilience
  R1 = c(2, 4, 1, 3, 2), # Fire risk
  R2 = c(3, 2, 4, 3, 3), # Storm risk
  R3 = c(0.45, 0.68, 0.32, 0.51, 0.47), # Water stress

  # Family S - Social & Recreation (NEW)
  S1 = c(0.8, 1.5, 0.3, 1.1, 0.9), # Trail density (km/ha)
  S2 = c(65, 45, 78, 58, 62), # Accessibility score (0-100)
  S3_5km = c(12500, 3200, 18900, 8400, 10200), # Population 5km
  S3_10km = c(45000, 15000, 68000, 32000, 41000), # Population 10km
  S3_20km = c(125000, 52000, 185000, 98000, 115000), # Population 20km
  S3 = c(182500, 70200, 271900, 138400, 166200), # Total proximity

  # Family P - Production & Economy (NEW)
  P1 = c(280, 150, 420, 220, 310), # Standing volume (m³/ha)
  P2 = c(6.5, 4.2, 8.9, 5.8, 7.1), # Site productivity (m³/ha/yr)
  P3 = c(72, 58, 84, 65, 75), # Timber quality (0-100)

  # Family E - Energy & Climate (NEW)
  E1 = c(4.5, 2.8, 6.2, 3.7, 5.1), # Fuelwood potential (t DM/yr)
  E1_residues = c(3.2, 2.1, 4.5, 2.8, 3.6),
  E1_coppice = c(1.3, 0.7, 1.7, 0.9, 1.5),
  E2 = c(8.2, 5.1, 11.3, 6.8, 9.3), # CO2 avoidance (tCO2eq/yr)
  E2_energy = c(7.5, 4.6, 10.2, 6.1, 8.4),
  E2_material = c(0.7, 0.5, 1.1, 0.7, 0.9),

  # Family N - Naturalness & Wilderness (NEW)
  N1 = c(850, 320, 1450, 680, 920), # Infrastructure distance (m)
  N1_roads = c(850, 320, 1450, 680, 920),
  N1_buildings = c(1200, 480, 2100, 950, 1350),
  N1_power = c(2400, 1200, 3800, 1900, 2650),
  N2 = c(450, 180, 820, 320, 520), # Forest continuity (ha)
  N3 = c(68, 42, 82, 55, 71), # Wilderness composite (0-100)
  N3_N1_norm = c(0.65, 0.35, 0.88, 0.52, 0.70),
  N3_N2_norm = c(0.68, 0.40, 0.85, 0.48, 0.72),
  N3_T1_norm = c(0.72, 0.38, 0.92, 0.58, 0.65),
  N3_B1_norm = c(0.67, 0.33, 0.75, 0.50, 0.67),

  # Additional metadata
  species = c("FASY", "PIAB", "QUPE", "ABAL", "PISY"),
  area_ha = c(125, 85, 210, 95, 140),
  geometry = st_sfc(
    st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
    st_polygon(list(matrix(c(1000, 0, 1850, 0, 1850, 850, 1000, 850, 1000, 0), ncol = 2, byrow = TRUE))),
    st_polygon(list(matrix(c(2000, 0, 3000, 0, 3000, 2000, 2000, 2000, 2000, 0), ncol = 2, byrow = TRUE))),
    st_polygon(list(matrix(c(3200, 0, 4150, 0, 4150, 950, 3200, 950, 3200, 0), ncol = 2, byrow = TRUE))),
    st_polygon(list(matrix(c(4500, 0, 5500, 0, 5500, 1400, 4500, 1400, 4500, 0), ncol = 2, byrow = TRUE))),
    crs = 2154
  )
)

# Save fixture
saveRDS(twelve_family_units, "tests/testthat/fixtures/twelve_family_dataset.rds")

# Print summary
cat("✓ Created 12-family test fixture with", nrow(twelve_family_units), "parcels\n")
cat("✓ Indicators per family:\n")
cat("  - C (Carbon): C1, C2\n")
cat("  - B (Biodiversity): B1, B2, B3\n")
cat("  - W (Water): W1, W2, W3\n")
cat("  - A (Air): A1, A2\n")
cat("  - F (Fertility): F1, F2\n")
cat("  - L (Landscape): L1, L2\n")
cat("  - T (Temporal): T1, T2\n")
cat("  - R (Risks): R1, R2, R3\n")
cat("  - S (Social): S1, S2, S3\n")
cat("  - P (Production): P1, P2, P3\n")
cat("  - E (Energy): E1, E2\n")
cat("  - N (Naturalness): N1, N2, N3\n")
cat("✓ Total:", ncol(twelve_family_units) - 2, "columns (excluding id, geometry)\n")
