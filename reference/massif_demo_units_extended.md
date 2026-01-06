# Complete Demo Dataset with 12-Family Ecosystem Services Referential

Extended demonstration dataset containing 20 forest parcels with all 29
indicators across the complete 12-family referential for ecosystem
services assessment. This dataset is synthetically generated for package
demonstration and testing purposes.

## Usage

``` r
massif_demo_units_extended
```

## Format

An `sf` object with 20 forest parcels and 100+ columns:

- id:

  Numeric parcel identifier (1-20)

- name:

  Parcel name (Parcel_01 to Parcel_20)

- parcel_id:

  Legacy identifier (P01-P20)

- species:

  Tree species code (4-letter IFN codes: FASY, PIAB, QUPE, etc.)

- area_ha:

  Parcel area in hectares

- forest_type:

  Forest type classification

- age_class:

  Forest age class

- management:

  Management objective

- geometry:

  Spatial geometry (POLYGON, EPSG:2154 - Lambert 93)

- C1:

  Biomass carbon stock (tC/ha)

- C2:

  NDVI trend (annual rate of change)

- B1:

  Protection status (0=none, 1=local, 2=regional, 3=national)

- B2:

  Structural diversity index

- B3:

  Landscape connectivity (0-1)

- W1:

  Hydrographic network density (km/ha)

- W2:

  Wetland area percentage

- W3:

  Topographic Wetness Index

- A1:

  Forest cover within 1km buffer (0-1)

- A2:

  Air quality index

- F1:

  Soil fertility class (1-5)

- F2:

  Slope percentage (erosion risk)

- L1:

  Landscape fragmentation index (0-1)

- L2:

  Edge-to-area ratio

- T1:

  Forest ancientness (years)

- T2:

  Land cover change rate (percentage)

- R1:

  Fire risk level (1-5)

- R2:

  Storm/windthrow risk (1-5)

- R3:

  Water stress index (0-1)

- S1:

  Trail density (km/ha)

- S2:

  Accessibility score (0-100)

- S3:

  Population proximity (persons within 5/10/20km)

- P1:

  Standing timber volume (m³/ha)

- P2:

  Site productivity (m³/ha/yr)

- P3:

  Timber quality score (0-100)

- E1:

  Fuelwood potential (tonnes DM/yr)

- E2:

  CO2 emission avoidance (tCO2eq/yr)

- N1:

  Infrastructure distance (m)

- N2:

  Forest continuity (ha)

- N3:

  Wilderness composite score (0-100)

- \*\_norm:

  Normalized versions (0-100 scale) for all 29 indicators

- family_C, family_B, ..., family_N:

  Aggregated family scores (0-100)

## Source

Synthetically generated using `data-raw/generate_extended_demo.R`. Based
on:

- French National Forest Inventory (IFN) allometric equations

- ADEME Base Carbone® emission factors

- OpenStreetMap infrastructure data patterns

- INSEE population distribution models

## Details

This dataset extends `massif_demo_units` with complete indicator
coverage across all 12 families in the nemeton ecosystem services
framework. It includes:

- **29 primary indicators** measuring different ecosystem service
  dimensions

- **29 normalized indicators** (0-100 scale) for direct comparison

- **12 family composite indices** aggregating related indicators

- **Spatial coverage**: Synthetic 5km × 5km forest area in Lambert 93

- **Realistic value ranges**: Based on French forest inventory data
  (IFN)

The data generation methodology combines:

- Allometric models from IFN for volume calculations

- ADEME emission factors for climate indicators

- Spatial relationships (accessibility, naturalness, continuity)

- Stochastic variation to simulate real-world heterogeneity

## Families v0.4.0

The complete 12-family referential includes:

- **v0.2.0**: C, W, F, L (biophysical services)

- **v0.3.0**: B, A, T, R (biodiversity, climate, temporal, risks)

- **v0.4.0**: S, P, E, N (social, productive, energy, naturalness)

## Usage

This dataset is ideal for:

- Package vignettes demonstrating multi-criteria analysis

- Testing visualization functions (radar plots, correlation matrices)

- Prototyping composite indices and decision support tools

- Educational examples of ecosystem services assessment

## See also

[`massif_demo_units`](https://pobsteta.github.io/nemeton/reference/massif_demo_units.md)
for the base dataset without indicators.

[`create_family_index`](https://pobsteta.github.io/nemeton/reference/create_family_index.md)
for creating family composites.

[`normalize_indicators`](https://pobsteta.github.io/nemeton/reference/normalize_indicators.md)
for indicator normalization.

[`nemeton_radar`](https://pobsteta.github.io/nemeton/reference/nemeton_radar.md)
for visualizing the 12-family profile.

## Examples

``` r
if (FALSE) { # \dontrun{
# Load the extended demo dataset
data("massif_demo_units_extended")

# Explore structure
library(sf)
plot(massif_demo_units_extended["family_S"])  # Social services
plot(massif_demo_units_extended["family_E"])  # Energy services

# Create 12-axis radar plot for parcel 1
library(nemeton)
nemeton_radar(
  massif_demo_units_extended,
  unit_id = 1,
  mode = "family"
)

# Compute correlations across all 12 families
cor_matrix <- compute_family_correlations(massif_demo_units_extended)
plot_correlation_matrix(cor_matrix)

# Identify multi-service hotspots
hotspots <- identify_hotspots(
  massif_demo_units_extended,
  threshold = 75,
  min_families = 6
)

# Summary statistics
summary(massif_demo_units_extended[, c("family_S", "family_P", "family_E", "family_N")])
} # }
```
