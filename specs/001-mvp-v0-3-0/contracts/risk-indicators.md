# Function Contracts: Risk & Resilience Indicators (R-Family)

**Family**: R (Risk & Resilience / Flexible)
**Date**: 2026-01-05

## Functions

### indicator_risk_fire(units, dem, species_field = "species", climate = NULL, weights = c(1/3, 1/3, 1/3))

**Returns**: sf with `R1` (fire risk index, 0-100)

**Formula**: `R1 = w1×slope_factor + w2×species_flammability + w3×climate_dryness`

**Behavior**: Higher score = higher fire risk. Uses slope from DEM, species flammability lookup table, precipitation deficit from climate raster.

---

### indicator_risk_storm(units, dem, height_field = "height", density_field = "density", weights = c(1/3, 1/3, 1/3))

**Returns**: sf with `R2` (storm vulnerability, 0-100)

**Formula**: `R2 = w1×stand_height + w2×stand_density + w3×topographic_exposure`

**Behavior**: Higher score = more vulnerable. Uses parcel attributes + topographic position index from DEM.

---

### indicator_risk_drought(units, twi_field = "W3", climate = NULL, species_field = "species", weights = c(0.4, 0.4, 0.2))

**Returns**: sf with `R3` (drought stress, 0-100)

**Formula**: `R3 = w1×(100-TWI) + w2×precip_deficit + w3×species_sensitivity`

**Behavior**: Higher score = higher drought stress. Reuses TWI from W3 (v0.2.0), adds climate + species factors.

---

**Common**: All return indices [0-100], support custom weights, handle NA gracefully, provide bilingual messages.
