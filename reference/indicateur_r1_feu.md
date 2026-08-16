# Calculate Fire Risk Index (R1)

Computes fire risk using fire exposure analysis from BD Foret fuel
mapping (via fireexposuR). Falls back to slope + species + climate
method when fireexposuR or BD Foret data is unavailable.

## Usage

``` r
indicateur_r1_feu(
  units,
  dem = NULL,
  layers = NULL,
  bdforet = NULL,
  species_field = "species",
  climate = NULL,
  weights = c(slope = 1/3, species = 1/3, climate = 1/3),
  dem_target_res = .topo_target_res(),
  fire_exp_res = .NEMETON_FIRE_EXP_RES,
  fire_exp_weights = c(exposure = 0.5, slope = 0.25, climate = 0.25)
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

- dem_target_res:

  Numeric. Working resolution (metres) the DEM is aggregated to before
  terrain derivatives are computed. A LiDAR HD MNT comes at 0.5-1 m,
  i.e. hundreds of millions of cells per derived layer over a whole
  massif, for an index that is averaged per unit anyway. Default: the
  package-wide topographic working resolution, 2 m — see
  `options("nemeton.topo_target_res")`; `NULL` keeps the native
  resolution. Never upsamples, and is a no-op on a lon/lat DEM.

- fire_exp_res:

  Numeric. Upper bound (metres) on the working resolution of the
  fireexposuR path only: the hazard raster handed to `fire_exp()` is
  aggregated to at least this cell size. Default 30 m, the Landsat-like
  resolution fireexposuR is calibrated for. The fallback method is
  unaffected and keeps `dem_target_res`. Never upsamples a DEM that is
  already coarser; `NULL` disables the bound.

- fire_exp_weights:

  Named numeric vector weighting the components of the fireexposuR path:
  `exposure` (fire transmission exposure), `slope` and `climate`.
  Default `c(exposure = 0.5, slope = 0.25, climate = 0.25)`. Exposure
  alone saturates near 100 over a continuous forest — every unit has
  ~all its 500 m neighbourhood burnable — so slope and climatic dryness
  modulate it, as in the fallback. A component that cannot be computed
  (no climate raster) drops out and its weight is redistributed
  proportionally. `c(exposure = 1)` restores the raw exposure.

## Value

The input sf object with added column:

- R1: Fire risk index (0-100). Higher = higher risk.

## Details

\*\*Primary method\*\* (requires fireexposuR + BD Foret): Rasterizes BD
Foret as a hazard layer, then computes fire exposure with a 500m
transmission distance. The 0-1 exposure is scaled to 0-100. The hazard
grid is bounded to `fire_exp_res` (30 m) because the annular kernel of
`fire_exp()` costs `(2 * t_dist / res)^2` operations per cell: at 2 m it
is ~52 000x the cost at 30 m.

\*\*Fallback method\*\*: R1 = w1\*slope + w2\*species_flammability +
w3\*climate_dryness

## See also

Other risk-indicators:
[`indicateur_r2_tempete()`](https://pobsteta.github.io/nemeton/reference/indicateur_r2_tempete.md),
[`indicateur_r3_secheresse()`](https://pobsteta.github.io/nemeton/reference/indicateur_r3_secheresse.md),
[`indicateur_r4_abroutissement()`](https://pobsteta.github.io/nemeton/reference/indicateur_r4_abroutissement.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)
library(terra)

data(massif_demo_units)
units <- massif_demo_units

dem <- rast("path/to/dem.tif")
result <- indicateur_r1_feu(units, dem = dem)
summary(result$R1)
} # }
```
