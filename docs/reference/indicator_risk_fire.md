# Calculate Fire Risk Index (R1)

Computes fire risk using fire exposure analysis from BD Foret fuel
mapping (via fireexposuR). Falls back to slope + species + climate
method when fireexposuR or BD Foret data is unavailable.

## Usage

``` r
indicator_risk_fire(
  units,
  dem = NULL,
  layers = NULL,
  bdforet = NULL,
  species_field = "species",
  climate = NULL,
  weights = c(slope = 1/3, species = 1/3, climate = 1/3)
)
```

## Arguments

- units:

  An sf object with forest parcels.

- dem:

  A SpatRaster with digital elevation model (meters).

- layers:

  A nemeton_layers object. Used to extract DEM and BD Foret.

- bdforet:

  An sf object with BD Foret V2 polygons, or NULL.

- species_field:

  Character. Column name with species names (fallback only).

- climate:

  List with 'temperature' and 'precipitation' SpatRasters, or NULL
  (fallback only).

- weights:

  Named numeric vector. Weights for fallback components: c(slope,
  species, climate). Default c(1/3, 1/3, 1/3).

## Value

The input sf object with added column:

- R1: Fire risk index (0-100). Higher = higher risk.

## Details

\*\*Primary method\*\* (requires fireexposuR + BD Foret): Rasterizes BD
Foret as a hazard layer, then computes fire exposure with a 500m
transmission distance. The 0-1 exposure is scaled to 0-100.

\*\*Fallback method\*\*: R1 = w1\*slope + w2\*species_flammability +
w3\*climate_dryness

## See also

Other risk-indicators:
[`indicator_risk_browsing()`](https://pobsteta.github.io/nemeton/reference/indicator_risk_browsing.md),
[`indicator_risk_drought()`](https://pobsteta.github.io/nemeton/reference/indicator_risk_drought.md),
[`indicator_risk_storm()`](https://pobsteta.github.io/nemeton/reference/indicator_risk_storm.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)
library(terra)

data(massif_demo_units)
units <- massif_demo_units

dem <- rast("path/to/dem.tif")
result <- indicator_risk_fire(units, dem = dem)
summary(result$R1)
} # }
```
