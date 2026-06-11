# Calculate Storm Vulnerability Index (R2)

Computes storm vulnerability using wind shelter coefficient from
microclima. Falls back to DEM-derived terrain exposure when microclima
is unavailable.

## Usage

``` r
indicateur_r2_tempete(
  units,
  dem = NULL,
  layers = NULL,
  chm = NULL,
  species_field = "species",
  h_dom_percentile = 0.9,
  h_reference = 30
)
```

## Arguments

- units:

  An sf object with forest parcels.

- dem:

  A SpatRaster with digital elevation model (meters).

- layers:

  A nemeton_layers object. Used to extract DEM if `dem` is NULL.

- chm:

  Optional `SpatRaster` of canopy heights in metres. When supplied,
  activates CHM mode (spec 005 phase 4).

- species_field:

  Character. Column of `units` holding the species code. Used only in
  CHM mode. Default `"species"`.

- h_dom_percentile:

  Numeric in `[0, 1]`. Percentile of CHM pixels used for dominant
  height. Default `0.9`.

- h_reference:

  Numeric. Reference height (metres) at which the canopy-vulnerability
  factor equals the species baseline. Default `30`.

## Value

The input sf object with added column:

- R2: Storm vulnerability (0-100). Higher = more vulnerable.

## Details

When a Canopy Height Model is supplied (spec 005 phase 4), the base
terrain score is modulated by a canopy-vulnerability factor
`f(H_CHM, species)`: tall stands are more vulnerable than short ones,
and at equal height conifers are more vulnerable than broadleaves
(straighter trunks, shallower roots). The modulation is multiplicative
and clamped to `[0, 100]`.

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
