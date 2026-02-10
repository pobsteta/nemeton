# Calculate Storm Vulnerability Index (R2)

Computes storm vulnerability using wind shelter coefficient from
microclima. Falls back to DEM-derived terrain exposure when microclima
is unavailable.

## Usage

``` r
indicator_risk_storm(units, dem = NULL, layers = NULL)
```

## Arguments

- units:

  An sf object with forest parcels.

- dem:

  A SpatRaster with digital elevation model (meters).

- layers:

  A nemeton_layers object. Used to extract DEM if `dem` is NULL.

## Value

The input sf object with added column:

- R2: Storm vulnerability (0-100). Higher = more vulnerable.

## Details

\*\*Primary method\*\* (requires microclima): Uses
[`microclima::windcoef()`](https://rdrr.io/pkg/microclima/man/windcoef.html)
to compute wind shelter coefficient from the DEM. Dominant wind
direction is obtained from NASA POWER climatology (nasapower),
defaulting to 270 degrees (west) for France. R2 = (1 - shelter_coef) \*
100.

\*\*Fallback method\*\* (DEM terrain derivatives): Combines aspect-wind
alignment, slope, and terrain ruggedness (TRI): R2 = wind_exposure \*
(0.6 \* slope_norm + 0.4 \* TRI_norm) \* 100.

## See also

Other risk-indicators:
[`indicator_risk_browsing()`](https://pobsteta.github.io/nemeton/reference/indicator_risk_browsing.md),
[`indicator_risk_drought()`](https://pobsteta.github.io/nemeton/reference/indicator_risk_drought.md),
[`indicator_risk_fire()`](https://pobsteta.github.io/nemeton/reference/indicator_risk_fire.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)

data(massif_demo_units)
units <- massif_demo_units
dem <- rast("path/to/dem.tif")

result <- indicator_risk_storm(units, dem = dem)
summary(result$R2)
} # }
```
