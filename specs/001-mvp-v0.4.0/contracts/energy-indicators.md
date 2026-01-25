# API Contract: Energy Indicators (E Family)

**Family**: Energy & Climate Services
**Feature**: [spec.md](../spec.md) | **Data Model**: [data-model.md](../data-model.md)
**Created**: 2026-01-05

## Overview

This contract defines the API for calculating energy/climate indicators (E1-E2) that quantify bioenergy potential and climate mitigation through forest biomass valorization. Functions accept `sf` objects with biomass/volume data and return enriched objects with energy indicators.

---

## E1: Fuelwood Potential Indicator

### Function Signature

```r
indicator_energy_fuelwood(
  units,
  volume_field = "P1",
  harvest_rate = 0.02,
  coppice_area_field = NULL,
  species_field = "species",
  residue_fraction = "default",
  coppice_yield = "default",
  column_name = "E1",
  lang = "en"
)
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `units` | `sf` (POLYGON) | Yes | - | Spatial units with volume/biomass data |
| `volume_field` | character | No | `"P1"` | Column for standing volume (m³/ha), used for residue calculation |
| `harvest_rate` | numeric | No | `0.02` | Fraction of volume harvested annually (2% default = sustainable) |
| `coppice_area_field` | character | No | `NULL` | Column for coppice area (ha), NULL if no coppice |
| `species_field` | character | No | `"species"` | Column for species (for wood density lookup) |
| `residue_fraction` | character/numeric | No | `"default"` | Fraction of harvest becoming residue (species-specific if "default") |
| `coppice_yield` | character/numeric | No | `"default"` | Annual coppice yield (t DM/ha/year), species-specific if "default" |
| `column_name` | character | No | `"E1"` | Name for output column |
| `lang` | character | No | `"en"` | Message language |

### Returns

**Type**: `sf` object

**Added Columns**:
- `{column_name}` (numeric): Total fuelwood potential (t DM/year)
- `{column_name}_residue` (numeric): Contribution from harvest residues
- `{column_name}_coppice` (numeric): Contribution from coppice

### Behavior

1. **Harvest Residue Component**:
   ```r
   # Annual harvest volume
   harvest_vol = volume × harvest_rate

   # Residue volume
   residue_vol = harvest_vol × residue_fraction

   # Convert to dry matter tonnes
   residue_tdm = residue_vol × wood_density × dry_matter_content
   ```

   **Defaults**:
   - `residue_fraction`: 0.35 (35% of harvest becomes slash)
   - `wood_density`: Species-specific (0.4-0.8 t/m³ fresh)
   - `dry_matter_content`: 0.5 (50% dry matter)

2. **Coppice Component**:
   ```r
   # If coppice_area_field provided
   coppice_tdm = coppice_area × coppice_yield
   ```

   **Defaults** (species-specific):
   - Willow: 12 t DM/ha/year
   - Poplar: 10 t DM/ha/year
   - Chestnut: 8 t DM/ha/year
   - Generic: 7 t DM/ha/year

3. **Total**:
   ```r
   E1 = residue_tdm + coppice_tdm
   ```

4. **Edge Cases**:
   - Volume missing + no coppice: E1 = NA with message
   - Volume = 0 + no coppice: E1 = 0
   - Warn if E1 > 10 t/ha/year (very high)

### Example

```r
library(nemeton)

# Load demo data (assuming P1 already calculated)
data(massif_demo_units_extended)

# Calculate E1
result <- indicator_energy_fuelwood(
  units = massif_demo_units_extended,
  volume_field = "P1",
  harvest_rate = 0.02,  # 2% annual harvest
  species_field = "dominant_species"
)

summary(result$E1)
#> Min: 0.45, Median: 1.82, Max: 4.67 t DM/year
```

### Error Handling

| Error Condition | Response |
|-----------------|----------|
| Volume and coppice both missing | Stop: "Require volume_field or coppice_area_field" |
| harvest_rate < 0 or > 1 | Stop: "Invalid harvest_rate, must be in [0, 1]" |
| Species not found | Warn, use generic defaults |
| E1 > 10 t/ha/year | Warn: "Exceptionally high fuelwood potential" |

### Dependencies

- `sf`
- Internal wood density table (`data/wood_density.rda`)
- Internal coppice yield table (`data/coppice_yields.rda`)

### Performance

- 20 parcels: <1 second
- 1000 parcels: ~2 seconds

---

## E2: Carbon Avoidance Indicator

### Function Signature

```r
indicator_energy_avoidance(
  units,
  fuelwood_field = "E1",
  timber_field = "P1",
  substitution_scenario = c("energy_only", "energy+material"),
  emission_factors = "ademe",
  fossil_fuel = c("heating_oil", "natural_gas"),
  energy_content = 4.2,
  column_name = "E2",
  lang = "en"
)
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `units` | `sf` (POLYGON) | Yes | - | Spatial units with fuelwood and/or timber data |
| `fuelwood_field` | character | No | `"E1"` | Column for fuelwood potential (t DM/year) |
| `timber_field` | character | No | `"P1"` | Column for timber volume (m³/ha), optional for material substitution |
| `substitution_scenario` | character | No | `"energy_only"` | "energy_only" or "energy+material" |
| `emission_factors` | character | No | `"ademe"` | Emission factor source ("ademe" = ADEME Base Carbone 2024) |
| `fossil_fuel` | character | No | `"heating_oil"` | Fossil fuel replaced: "heating_oil" or "natural_gas" |
| `energy_content` | numeric | No | `4.2` | Wood energy content (MWh/t DM) |
| `column_name` | character | No | `"E2"` | Name for output column |
| `lang` | character | No | `"en"` | Message language |

### Returns

**Type**: `sf` object

**Added Columns**:
- `{column_name}` (numeric): Total carbon avoidance (tCO2eq/year)
- `{column_name}_energy` (numeric): Energy substitution component
- `{column_name}_material` (numeric): Material substitution component (0 if energy_only)

### Behavior

1. **Energy Substitution Component**:
   ```r
   # Energy produced from fuelwood
   energy_mwh = fuelwood × energy_content

   # Emissions avoided
   avoided = energy_mwh × (fossil_EF - wood_EF)
   ```

   **ADEME Emission Factors** (kgCO2eq/MWh):
   - Heating oil: 324
   - Natural gas: 227
   - Wood combustion: 30 (transport + processing only, biogenic CO2 neutral)

2. **Material Substitution Component** (if scenario = "energy+material"):
   ```r
   # Timber used in construction replaces concrete/steel
   # Assume 50% of timber volume suitable for construction

   timber_construction = timber_volume × 0.5

   # Emission avoided
   material_avoided = timber_construction × (concrete_EF - wood_production_EF)
   ```

   **ADEME Factors**:
   - Concrete: 900 kgCO2eq/m³
   - Wood construction: 150 kgCO2eq/m³
   - Net benefit: 750 kgCO2eq/m³

3. **Total**:
   ```r
   E2 = avoided_energy + avoided_material
   ```

4. **Edge Cases**:
   - Fuelwood missing: E2 = NA with message
   - Timber missing + scenario="energy+material": Material component = 0 with warning
   - E2 < 0: Error (should never happen with correct factors)

### Example

```r
# Assuming E1 and P1 already calculated
result <- indicator_energy_avoidance(
  units = massif_demo_units_extended,
  fuelwood_field = "E1",
  timber_field = "P1",
  substitution_scenario = "energy+material",
  fossil_fuel = "heating_oil"
)

# Component breakdown
result[, c("E2", "E2_energy", "E2_material")]

summary(result$E2)
#> Min: 0.85, Median: 3.42, Max: 12.56 tCO2eq/year
```

### Error Handling

| Error Condition | Response |
|-----------------|----------|
| Fuelwood field missing | Stop: "E2 requires fuelwood potential (E1)" |
| Timber missing + energy+material | Warn: "Material substitution skipped (no timber data)" |
| Invalid emission_factors | Stop: "emission_factors must be 'ademe'" |
| E2 < 0 | Stop: "Negative carbon avoidance (factor error)" |

### Dependencies

- `sf`
- Internal emission factor table (`data/emission_factors.rda`)

### Performance

- 20 parcels: <1 second
- 1000 parcels: ~1 second

---

## Integration with Family System

```r
# Calculate all E indicators
units_with_E <- units |>
  indicator_energy_fuelwood(
    volume_field = "P1",
    harvest_rate = 0.02,
    species_field = "species"
  ) |>
  indicator_energy_avoidance(
    fuelwood_field = "E1",
    timber_field = "P1",
    substitution_scenario = "energy+material"
  )

# Normalize
units_normalized <- normalize_indicators(
  units_with_E,
  indicators = c("E1", "E2"),
  methods = c("linear", "linear")
)

# Create family composite
units_with_family <- create_family_index(
  units_normalized,
  family = "E",
  indicators = c("E1", "E2"),
  weights = c(0.5, 0.5)
)
```

---

## Testing Requirements

### Unit Tests

- ✅ Residue calculation (volume → t DM)
- ✅ Coppice yield lookup
- ✅ Energy substitution calculation
- ✅ Material substitution calculation
- ✅ Scenario switching (energy_only vs energy+material)
- ✅ Edge cases (missing volume, missing timber)

### Integration Tests

- ✅ Full E1-E2 workflow
- ✅ Dependency on P1 (volume)
- ✅ Normalization and family composite

### Fixtures

- `tests/testthat/fixtures/energy_reference.rds`: Expected E1-E2 values
- `tests/testthat/fixtures/emission_factors_ademe.rds`: ADEME factor table snapshot

---

**Document Version**: 1.0
**Last Updated**: 2026-01-05
**Status**: Contract Complete
**Implemented**: TBD (Phase 5 tasks)
