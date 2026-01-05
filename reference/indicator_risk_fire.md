# Calculate Fire Risk Index (R1)

Computes fire risk based on topographic slope, species flammability, and
climate dryness.

## Usage

``` r
indicator_risk_fire(
  units,
  dem,
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

- species_field:

  Character. Column name with species names.

- climate:

  List with 'temperature' and 'precipitation' SpatRasters, or NULL.

- weights:

  Named numeric vector. Weights for components: c(slope, species,
  climate). Default c(1/3, 1/3, 1/3).

## Value

The input sf object with added column:

- R1: Fire risk index (0-100). Higher = higher risk.

## Details

\*\*Formula\*\*: R1 = w1×slope_factor + w2×species_flammability +
w3×climate_dryness

\*\*Components\*\*:

- slope_factor: Slope from DEM, normalized to 0-100 (\>30° = max risk)

- species_flammability: Lookup from internal table (Pinus=80,
  Quercus=50, Fagus=20)

- climate_dryness: Low precipitation + high temperature = high dryness

## See also

Other risk-indicators:
[`indicator_risk_drought()`](https://pobsteta.github.io/nemeton/reference/indicator_risk_drought.md),
[`indicator_risk_storm()`](https://pobsteta.github.io/nemeton/reference/indicator_risk_storm.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)
library(terra)

data(massif_demo_units)
units <- massif_demo_units
units$species <- sample(c("Pinus", "Quercus", "Fagus"), nrow(units), replace = TRUE)

dem <- rast("path/to/dem.tif")
climate <- list(
  temperature = rast("path/to/temp.tif"),
  precipitation = rast("path/to/precip.tif")
)

result <- indicator_risk_fire(units, dem = dem, species_field = "species", climate = climate)
summary(result$R1)
} # }
```
