# Function Contracts: Temporal Dynamics Indicators (T-Family)

**Family**: T (Temporal Dynamics & Trame / Nervurée)
**Date**: 2026-01-05

## Functions

### indicator_temporal_age(units, age_field = "age", establishment_year_field = NULL, current_year = NULL)

**Returns**: sf with `T1` (stand age, years) and `T1_norm` (0-100)

**Calculation**: 
- If `age_field` exists: use directly
- Else if `establishment_year_field`: `T1 = current_year - establishment_year`
- Normalization: `T1_norm = 100 × log(age+1) / log(301)` (log scale, cap 300yr)

**Behavior**: Ancient forests (150+ yr) score high. Handles missing data with warnings.

---

### indicator_temporal_change(units, land_cover_early, land_cover_late, years_elapsed, interpretation = c("stability", "dynamism"))

**Returns**: sf with `T2` (change rate, %/yr) and `T2_norm` (0-100)

**Calculation**: 
- Binary change detection: `change_raster = (lc_late != lc_early)`
- Zonal stats: `pct_changed = exactextractr::exact_extract(change_raster, units, "mean") × 100`
- Annualized: `T2 = pct_changed / years_elapsed`

**Normalization**:
- If interpretation="stability": `T2_norm = 100 × (1 - min(T2, 5) / 5)` (low change = high score)
- If interpretation="dynamism": `T2_norm = 100 × min(T2, 5) / 5` (high change = high score)

**Behavior**: Uses terra raster algebra + exactextractr for efficiency. Supports 30-year CLC time series (1990-2020).

---

**Dependencies**: terra (rasters), exactextractr (zonal stats), BD Forêt (age attributes)
