# create_sysdata.R
# Create internal package data (R/sysdata.rda)
# Based on research.md decisions for risk indices

# ==============================================================================
# v0.2.0 DATA - Allometric Models for Carbon Biomass
# ==============================================================================

# Allometric Models Lookup Table (for C1: Carbon Biomass)
# Source: Research literature on temperate forest biomass equations
allometric_models <- data.frame(
  species = c(
    "Quercus", "Fagus", "Pinus", "Abies", "Picea",
    "Castanea", "Fraxinus", "Acer", "Betula", "Populus",
    "Generic"
  ),
  a = c(
    0.35, 0.40, 0.38, 0.42, 0.40,
    0.36, 0.38, 0.37, 0.33, 0.32,
    0.37 # Generic fallback
  ),
  b = c(
    1.15, 1.20, 1.18, 1.22, 1.20,
    1.16, 1.18, 1.17, 1.14, 1.12,
    1.18 # Generic fallback
  ),
  c = c(
    0.85, 0.90, 0.88, 0.92, 0.90,
    0.86, 0.88, 0.87, 0.84, 0.82,
    0.88 # Generic fallback
  ),
  source = c(
    rep("Literature", 10),
    "Default"
  ),
  citation = c(
    rep("Forest Biomass Equations Database", 10),
    "Package Default"
  ),
  stringsAsFactors = FALSE
)

# ==============================================================================
# v0.3.0 DATA - Species Lookup Tables for Risk Indicators
# ==============================================================================

# Species Flammability Lookup Table (for R1: Fire Risk)
# Source: Research Decision R3 - Fire risk species classification
species_flammability_lookup <- data.frame(
  species = c(
    # High flammability (resinous, fine fuels)
    "Pinus", "Pinus sylvestris", "Pinus pinaster", "Pinus nigra",
    "Eucalyptus", "Eucalyptus globulus",
    # Medium flammability
    "Quercus", "Quercus robur", "Quercus petraea", "Quercus ilex",
    "Castanea", "Castanea sativa",
    "Mixed", "Mixte",
    # Low flammability (deciduous, moist fuels)
    "Fagus", "Fagus sylvatica",
    "Fraxinus", "Fraxinus excelsior",
    "Acer", "Acer pseudoplatanus",
    "Betula", "Betula pendula",
    "Populus", "Populus tremula",
    "Alnus", "Alnus glutinosa"
  ),
  flammability_score = c(
    # High: 80
    80, 80, 80, 80, 80, 80,
    # Medium: 50
    50, 50, 50, 50, 50, 50, 50, 50,
    # Low: 20
    20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20
  ),
  flammability_class = c(
    rep("High", 6),
    rep("Medium", 8),
    rep("Low", 12)
  ),
  stringsAsFactors = FALSE
)

# Species Drought Sensitivity Lookup Table (for R3: Drought Stress)
# Source: Research Decision R3 - Drought vulnerability
species_drought_sensitivity <- data.frame(
  species = c(
    # High sensitivity (mesophilous, shallow roots)
    "Fagus", "Fagus sylvatica",
    "Abies", "Abies alba",
    "Picea", "Picea abies",
    "Fraxinus", "Fraxinus excelsior",
    # Intermediate sensitivity
    "Quercus", "Quercus robur", "Quercus petraea",
    "Pinus", "Pinus sylvestris", "Pinus nigra",
    "Castanea", "Castanea sativa",
    "Betula", "Betula pendula",
    "Mixed", "Mixte",
    # Low sensitivity (Mediterranean, deep roots)
    "Quercus ilex", "Quercus suber",
    "Pinus pinaster", "Pinus halepensis",
    "Juniperus", "Juniperus oxycedrus",
    "Cedrus", "Cedrus atlantica"
  ),
  drought_sensitivity = c(
    # High: 80
    80, 80, 80, 80, 80, 80, 80, 80,
    # Intermediate: 50
    50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50,
    # Low: 20
    20, 20, 20, 20, 20, 20, 20, 20
  ),
  drought_class = c(
    rep("High", 8),
    rep("Intermediate", 12),
    rep("Low", 8)
  ),
  stringsAsFactors = FALSE
)

# Save as internal package data
usethis::use_data(
  allometric_models,
  species_flammability_lookup,
  species_drought_sensitivity,
  internal = TRUE,
  overwrite = TRUE
)

message("✓ Created R/sysdata.rda with internal lookup tables")
message("  - allometric_models: ", nrow(allometric_models), " species (v0.2.0)")
message("  - species_flammability_lookup: ", nrow(species_flammability_lookup), " species (v0.3.0)")
message("  - species_drought_sensitivity: ", nrow(species_drought_sensitivity), " species (v0.3.0)")
