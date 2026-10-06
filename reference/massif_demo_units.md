# Massif Demo - Example Forest Dataset

Example forest dataset for demonstrating the nemeton package: 20 forest
parcels covering a 5 km x 5 km area in France (Lambert-93), with a
synthetic stand inventory, the 41 indicators computed by the package
from the demo layers, their normalised versions and the 12 family
indices.

## Usage

``` r
massif_demo_units
```

## Format

An `sf` object with 20 features (POLYGON, EPSG:2154) and 123 columns
(122 fields + geometry):

- parcel_id:

  Character. Unique parcel identifier (P01-P20).

- forest_type:

  Character. Forest type: "Futaie feuillue", "Futaie résineuse", "Futaie
  mixte" or "Taillis".

- age_class:

  Character. Stand age class: "Jeune", "Moyen", "Mature" or "Surannée".

- management:

  Character. Management objective: "Production", "Conservation" or
  "Mixte".

- species:

  Character. Two-digit IFN species code (e.g. "03", "09", "64").

- age:

  Integer. Stand age (years).

- establishment_year:

  Numeric. Stand establishment year (2026 - age).

- density:

  Integer. Stem density (stems/ha).

- height:

  Numeric. Mean height (m).

- dbh:

  Numeric. Mean diameter at breast height (cm).

- volume:

  Numeric. Standing volume (m3/ha).

- strata:

  Integer. Number of vegetation layers (1-4).

- fertility:

  Integer. Fertility class (1 good to 3 poor).

- climate:

  Character. Climate type ("atlantique", "continental", "montagnard").

- surface_ha:

  Numeric. Parcel area (ha).

- couvert:

  Numeric. Canopy cover fraction (0-1), used by C1.

- C1, C2, B1, B2, B3, B4, W1, W2, W3, W4, A1, A2, A3, A4, A5, F1, F2,
  L1, L2, L3, T1, T2, T3, R1, R2, R3, R4, R5, R6, R7, S1, S2, S3, P1,
  P2, P3, E1, E2, N1, N2, N3:

  Numeric. Raw values of the 41 indicators, in the order of
  [`list_indicators()`](https://pobsteta.github.io/nemeton/reference/list_indicators.md);
  see
  [`indicator_labels()`](https://pobsteta.github.io/nemeton/reference/indicator_labels.md)
  for their meaning. `NA` when the demo layers cannot compute the
  indicator (see Details).

- b4_status, w4_status, a3_status, a4_status, a5_status, l3_status,
  t3_status, r1_status, r5_status, r6_status, r7_status, p3_status:

  Character. Status written by the indicators that carry one (e.g.
  `"skipped_no_micro"`, `"fire_exp"`, `"diametre_seul"`).

- C1_norm, ..., N3_norm:

  Numeric. The 41 indicators normalised to 0-100 by
  [`normalize_indicator()`](https://pobsteta.github.io/nemeton/reference/normalize_indicator.md)
  (higher = more favourable).

- famille_carbone, famille_biodiversite, famille_eau, famille_air,
  famille_sol, famille_paysage, famille_temporel, famille_risque,
  famille_social, famille_production, famille_energie,
  famille_naturalite:

  Numeric. Family indices (0-100) computed by
  [`create_family_index()`](https://pobsteta.github.io/nemeton/reference/create_family_index.md)
  (mean of the available indicators).

- geometry:

  sfc_POLYGON. Parcel boundaries (EPSG:2154).

## Source

Generated with `data-raw/massif_demo.R` (nemeton 1.0.0).

## Details

**What is simulated.** The parcels and their stand inventory
(`forest_type` to `surface_ha`, plus `couvert`) are synthetic, drawn
with `set.seed(42)` (`set.seed(4242)` for `couvert`); so are the demo
layers of `inst/extdata/`. The inventory plays the part of field data:
no real stand is described.

**What is computed.** The 41 indicator columns, their `_norm` and the
family indices are not simulated: `data-raw/massif_demo.R` computes them
with the package's own functions from
[`massif_demo_layers`](https://pobsteta.github.io/nemeton/reference/massif_demo_layers.md)
and the synthetic inventory (as
[`nemeton_compute()`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md)
does), with two derived inputs: a BD Forêt-like forest cover polygonised
from the demo land cover (classes 1-3), used by B3, N2, R1 and R4; and
an empty game-density raster for R4, so that the generation needs no
network (R2 also uses the default 270 degree wind).

**Indicators left NA (19).** The demo layers hold no NDVI (C2), no
protected areas (B1), no CHM, LiDAR or NDVI for the stand structure
(B2), no soil layer (F1), no buildings (S2, N1, hence N3), no population
grid (S3), and no LiDAR canopy height or game density for R4. The ten
source-conditional indicators also stay NA, with their status: B4 and L3
(Sentinel-2 spectral diversity), W4, A3, A4 and R6 (microclimate), A5
(land-surface temperature), R5 (FORDEAD / RECONFORT), R7 (daily minimum
temperature) and T3 (SUFOSAT). The demo's two-digit IFN species codes
are not in P2's productivity table, so P2 falls back to the genus mean
(6.5 m3/ha/yr) on the 11 parcels of fertility class 2 and is NA on the 9
parcels of class 1 or 3, which have no genus entry.

Associated layers (25 m rasters and vector layers in `inst/extdata/`)
are loaded with
[`massif_demo_layers`](https://pobsteta.github.io/nemeton/reference/massif_demo_layers.md):

- `massif_demo_biomass.tif`: aboveground biomass (50-400 Mg/ha)

- `massif_demo_dem.tif`: digital elevation model (350-700 m)

- `massif_demo_landcover.tif`: land cover (classes 1-3 forest, 4
  grassland)

- `massif_demo_species_richness.tif`: species richness

- `massif_demo_roads.gpkg`, `massif_demo_water.gpkg`: roads and water
  courses

The data are meant for examples, tests and vignettes, not for analysis.

## See also

[`massif_demo_layers`](https://pobsteta.github.io/nemeton/reference/massif_demo_layers.md),
[`nemeton_compute`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md),
[`nemeton_radar`](https://pobsteta.github.io/nemeton/reference/nemeton_radar.md),
[`create_family_index`](https://pobsteta.github.io/nemeton/reference/create_family_index.md)

## Examples

``` r

data(massif_demo_units)

# Stand attributes
summary(massif_demo_units$surface_ha)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>   1.048   4.047   5.887   6.801  10.149  17.079 
table(massif_demo_units$forest_type)
#> 
#>  Futaie feuillue     Futaie mixte Futaie résineuse          Taillis 
#>               11                2                4                3 

# Family indices
summary(sf::st_drop_geometry(massif_demo_units)[, c(
  "famille_carbone", "famille_production", "famille_naturalite"
)])
#>  famille_carbone  famille_production famille_naturalite
#>  Min.   : 3.857   Min.   : 25.07     Min.   :59.49     
#>  1st Qu.:18.217   1st Qu.: 59.36     1st Qu.:60.00     
#>  Median :30.947   Median : 69.26     Median :60.00     
#>  Mean   :34.164   Mean   : 69.41     Mean   :59.97     
#>  3rd Qu.:36.972   3rd Qu.: 81.33     3rd Qu.:60.00     
#>  Max.   :94.728   Max.   :100.00     Max.   :60.00     

if (FALSE) { # \dontrun{
# 12-axis family radar for parcel 1
nemeton_radar(massif_demo_units, unit_id = 1, mode = "family")

# Recompute indicators from the demo layers
layers <- massif_demo_layers()
results <- nemeton_compute(massif_demo_units, layers, indicators = "all")
} # }
```
