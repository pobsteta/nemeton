# Calculate Stand Age Index (T1)

Estimates stand age per unit, a measured age taking precedence over an
estimate: direct age field, then establishment year, then a structural
age when one is given (e.g. ForPT from the LiDAR point cloud, spec 067),
then BD Forêt TFV (Type de Formation Végétale, area-weighted, tuto 04
methodology), then an NDVI proxy. Each source only fills the units left
`NA` by the previous ones.

## Usage

``` r
indicateur_t1_anciennete(
  units,
  layers = NULL,
  bdforet = NULL,
  age_field = "age",
  establishment_year_field = NULL,
  current_year = NULL,
  age_structurel = NULL
)
```

## Arguments

- units:

  An sf object with forest parcels.

- layers:

  A nemeton_layers object (optional). Used to resolve bdforet.

- bdforet:

  An sf object with BD Forêt V2 polygons. If NULL and layers provided,
  resolved from layers.

- age_field:

  Character. Column name with stand age (years). Default "age". A
  measured age takes precedence over every estimate.

- establishment_year_field:

  Character. Column name with establishment year. Used for units with no
  measured age.

- current_year:

  Integer. Current year for age calculation from establishment year.
  Default uses current system year.

- age_structurel:

  Optional structural age (years), estimated from the stand structure
  rather than dated: a numeric vector (one value per unit), the name of
  a column of `units`, or a SpatRaster (mean over each unit). Typically
  `forptnemeton::forpt_age()` from the LiDAR point cloud (spec 067). It
  ranks after a measured age and an establishment year and before BD
  Forêt and NDVI, which saturate at 100 and 120 years. `NULL` (default):
  T1 is unchanged.

## Value

The input `units` (same class, rows and order) with an added numeric
column `T1`: estimated age in years – NOT a 0-100 score. **Higher =
older = more favourable**, so it is not inverted; normalize_indicator()
rescales it against a ref_max of 200 years, beyond which ancientness
counts as maximal. Until 0.196.0 it was wrongly declared natively 0-100
and merely clamped, so 150 and 250 years both came out at 100. See spec
048 section 10. `NA` for a unit no source can date (no default age). A
column `t1_source` says which source dated each unit: `"age"`,
`"annee_installation"`, `"age_structurel"`, `"bdforet"`, `"ndvi"`, or
`NA`.

## Details

\*\*Order of precedence\*\* (per unit): measured age, establishment
year, structural age (when given), BD Forêt TFV, NDVI proxy.

\*\*Structural age\*\* (spec 067, "T1 désaturé"): the BD Forêt TFV tops
out at 100 years and the NDVI proxy at 120, so old stands are all read
as about a century old. A structural age read in the LiDAR point cloud
can go further; normalisation still rescales against 200 years (spec 048
section 10), so the default meaning of T1 does not change. A structural
age is not an age: a stand on a poor site looks younger, and the ForPT
age head was trained outside France.

\*\*BD Forêt TFV method\*\*:

- Spatial intersection of parcels with BD Forêt polygons

- Age estimated from vegetation type (TFV field): - Forêt fermée
  feuillus / Futaie feuillus: 100 years - Forêt fermée conifères /
  Futaie conifères: 80 years - Forêt ouverte / Taillis: 45 years -
  Peupleraie: 20 years - Jeune peuplement / Lande boisée: 15 years -
  Other: not recognised, left out (no default age)

- Area-weighted average across overlapping polygons with a recognised
  TFV

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

## See also

Other temporal-indicators:
[`indicateur_t2_changement()`](https://pobsteta.github.io/nemeton/reference/indicateur_t2_changement.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)

data(massif_demo_units)
layers <- massif_demo_layers()

# Primary method: BD Forêt
result <- indicateur_t1_anciennete(massif_demo_units, layers = layers)
summary(result$T1)

# Direct age field
units <- massif_demo_units
units$age <- runif(nrow(units), 20, 250)
result <- indicateur_t1_anciennete(units, age_field = "age")
} # }
```
