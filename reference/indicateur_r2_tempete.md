# Calculate Storm Vulnerability Index (R2)

Computes storm vulnerability using wind shelter coefficient from
microclima. Falls back to DEM-derived terrain exposure when microclima
is unavailable.

## Usage

``` r
indicateur_r2_tempete(units, dem = NULL, layers = NULL)
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
`microclima::windcoef()` to compute wind shelter coefficient from the
DEM. Dominant wind direction is obtained from NASA POWER climatology
(nasapower), defaulting to 270 degrees (west) for France. R2 = (1 -
shelter_coef) \* 100.

\*\*Fallback method\*\* (DEM terrain derivatives): Combines aspect-wind
alignment, slope, and terrain ruggedness (TRI): R2 = wind_exposure \*
(0.6 \* slope_norm + 0.4 \* TRI_norm) \* 100.

## See also

Other risk-indicators:
[`indicateur_r1_feu()`](https://pobsteta.github.io/nemeton/reference/indicateur_r1_feu.md),
[`indicateur_r3_secheresse()`](https://pobsteta.github.io/nemeton/reference/indicateur_r3_secheresse.md),
[`indicateur_r4_abroutissement()`](https://pobsteta.github.io/nemeton/reference/indicateur_r4_abroutissement.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)

data(massif_demo_units)
units <- massif_demo_units
dem <- rast("path/to/dem.tif")

result <- indicateur_r2_tempete(units, dem = dem)
summary(result$R2)
} # }
```
