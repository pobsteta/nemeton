# Calculate Stand Age Index (T1)

Estimates stand age from BD Forêt TFV (Type de Formation Végétale) field
using area-weighted spatial intersection, following tuto 04 methodology.
Falls back to direct age field, establishment year, or NDVI proxy.

## Usage

``` r
indicator_temporal_age(
  units,
  layers = NULL,
  bdforet = NULL,
  age_field = "age",
  establishment_year_field = NULL,
  current_year = NULL
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

  Character. Column name with stand age (years). Default "age". Used as
  fallback if BD Forêt not available.

- establishment_year_field:

  Character. Column name with establishment year. Used as fallback if
  age_field not found.

- current_year:

  Integer. Current year for age calculation from establishment year.
  Default uses current system year.

## Value

Numeric vector of estimated age in years (one per parcel). Default value
is 50 when no data available.

## Details

\*\*Primary method\*\* (BD Forêt TFV):

- Spatial intersection of parcels with BD Forêt polygons

- Age estimated from vegetation type (TFV field): - Forêt fermée
  feuillus / Futaie feuillus: 100 years - Forêt fermée conifères /
  Futaie conifères: 80 years - Forêt ouverte / Taillis: 45 years -
  Peupleraie: 20 years - Jeune peuplement / Lande boisée: 15 years -
  Other: 50 years (default)

- Area-weighted average across overlapping polygons

\*\*Fallback methods\*\* (in order):

1.  Direct age column in units

2.  Establishment year column

3.  NDVI-based maturity estimate

## See also

Other temporal-indicators:
[`indicator_temporal_change()`](https://pobsteta.github.io/nemeton/reference/indicator_temporal_change.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)

data(massif_demo_units)
layers <- massif_demo_layers()

# Primary method: BD Forêt
result <- indicator_temporal_age(massif_demo_units, layers = layers)
summary(result)

# Direct age field
units <- massif_demo_units
units$age <- runif(nrow(units), 20, 250)
result <- indicator_temporal_age(units, age_field = "age")
} # }
```
