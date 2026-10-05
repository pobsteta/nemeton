# Massif Demo - Example Forest Dataset

Synthetic forest dataset for demonstrating the nemeton package
functionality: 20 forest parcels covering a 5 km x 5 km area in France
(Lambert-93), with stand attributes, raw indicator values, their
normalised versions and the 12 family indices.

## Usage

``` r
massif_demo_units
```

## Format

An `sf` object with 20 features (POLYGON, EPSG:2154) and 90 columns (89
fields + geometry):

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

  Numeric. Stand establishment year.

- density:

  Integer. Stem density (stems/ha).

- height:

  Numeric. Mean height (m).

- dbh:

  Numeric. Mean diameter at breast height (cm).

- volume:

  Numeric. Standing volume.

- strata:

  Integer. Stratum code.

- fertility:

  Integer. Fertility class.

- climate:

  Character. Climate type (e.g. "atlantique", "continental").

- surface_ha:

  Numeric. Parcel area (ha).

- C1, C2, B1, B2, B3, W1, W2, W3, A1, A2, F1, F2, L1, L2, T1, T2, R1,
  R2, R3, R4, S1, S2, S3, P1, P2, P3, E1, E2, N1, N2, N3:

  Numeric. Raw values of the 31 base indicators available when the
  fixture was generated; see
  [`indicator_labels()`](https://pobsteta.github.io/nemeton/reference/indicator_labels.md)
  for their meaning and
  [`indicator_families()`](https://pobsteta.github.io/nemeton/reference/indicator_families.md)
  for their family.

- C1_norm, ..., N3_norm:

  Numeric. The same 31 indicators normalised to 0-100.

- famille_carbone, famille_biodiversite, famille_eau, famille_air,
  famille_sol, famille_paysage, famille_temporel, famille_risque,
  famille_social, famille_production, famille_energie,
  famille_naturalite:

  Numeric. Family indices (0-100).

- geometry:

  sfc_POLYGON. Parcel boundaries (EPSG:2154).

## Source

Synthetic data generated with `data-raw/massif_demo.R`.

## Details

The fixture predates the indicators added since (for instance B4, W4,
A3-A5, L3, T3, R5-R7): their columns are absent, and the family indices
are computed from the 31 indicators listed above only.

Associated layers (25 m rasters and vector layers in `inst/extdata/`)
are loaded with
[`massif_demo_layers`](https://pobsteta.github.io/nemeton/reference/massif_demo_layers.md):

- `massif_demo_biomass.tif`: aboveground biomass (50-400 Mg/ha)

- `massif_demo_dem.tif`: digital elevation model (350-700 m)

- `massif_demo_landcover.tif`: land cover (6 classes)

- `massif_demo_species_richness.tif`: species richness

- `massif_demo_roads.gpkg`, `massif_demo_water.gpkg`: roads and water
  courses

All values are synthetic (generated with `set.seed(42)`); they are meant
for examples, tests and vignettes, not for analysis.

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
#>  Min.   : 1.298   Min.   : 2.456     Min.   :21.69     
#>  1st Qu.:26.465   1st Qu.:36.885     1st Qu.:38.23     
#>  Median :55.021   Median :46.303     Median :45.42     
#>  Mean   :46.573   Mean   :48.397     Mean   :47.99     
#>  3rd Qu.:64.615   3rd Qu.:68.800     3rd Qu.:60.40     
#>  Max.   :85.695   Max.   :94.525     Max.   :76.79     

if (FALSE) { # \dontrun{
# 12-axis family radar for parcel 1
nemeton_radar(massif_demo_units, unit_id = 1, mode = "family")

# Recompute indicators from the demo layers
layers <- massif_demo_layers()
results <- nemeton_compute(massif_demo_units, layers, indicators = "all")
} # }
```
