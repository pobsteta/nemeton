# Calculate Drought Stress Index (R3)

Computes drought stress combining a climate component (SPEI-3 index) and
a topographic modulation (aspect, slope, TWI). Falls back to
topographic-only assessment when SPEI is unavailable.

## Usage

``` r
indicateur_r3_secheresse(units, layers = NULL, dem = NULL, climate_data = NULL)
```

## Arguments

- units:

  An sf object with forest parcels.

- layers:

  A nemeton_layers object. Used to extract DEM.

- dem:

  A SpatRaster with digital elevation model (meters).

- climate_data:

  Optional list with `precip` (monthly precipitation vector in mm) and
  `temp` (list with `tmin` and `tmax` monthly vectors in degrees C). If
  NULL, uses simulated data.

## Value

The input sf object with added column:

- R3: Drought stress (0-100). Higher = higher stress.

## Details

\*\*Climate component\*\* (weight 0.6): Uses SPEI-3 (Standardised
Precipitation-Evapotranspiration Index at 3-month scale) via SPEI. PET
is computed with the Hargreaves method. R3_climat = (-SPEI_recent + 2) /
4, clamped to 0-1. Falls back to 0.5 without SPEI.

\*\*Topographic component\*\* (weight 0.4):

- aspect_risk: south-facing = max risk

- slope_risk: steep slopes = runoff = dry

- twi_risk: low TWI = dry

topo_risk = 0.4\*aspect_risk + 0.3\*slope_risk + 0.3\*twi_risk

R3 = (0.6 \* climate + 0.4 \* topo) \* 100

## See also

Other risk-indicators:
[`indicateur_r1_feu()`](https://pobsteta.github.io/nemeton/reference/indicateur_r1_feu.md),
[`indicateur_r2_tempete()`](https://pobsteta.github.io/nemeton/reference/indicateur_r2_tempete.md),
[`indicateur_r4_abroutissement()`](https://pobsteta.github.io/nemeton/reference/indicateur_r4_abroutissement.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)

data(massif_demo_units)
units <- massif_demo_units
dem <- rast("path/to/dem.tif")

result <- indicateur_r3_secheresse(units, dem = dem)
summary(result$R3)
} # }
```
