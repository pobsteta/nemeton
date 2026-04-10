# Calculate Game Browsing Pressure Index (R4)

Computes browsing pressure risk from ungulates (deer, wild boar) based
on species palatability from BD Foret, stand vulnerability from LiDAR,
edge exposure, and local game density from hunting statistics.

## Usage

``` r
indicateur_r4_abroutissement(
  units,
  layers = NULL,
  bdforet = NULL,
  game_density = NULL,
  edge_buffer = 50
)
```

## Arguments

- units:

  An sf object with forest parcels.

- layers:

  A nemeton_layers object. Used to extract BD Foret and LiDAR MNH.

- bdforet:

  An sf object with BD Foret V2 polygons, or NULL (resolved from
  layers).

- game_density:

  SpatRaster with game density index (0-100), or NULL (auto-computed
  from hunting data if available).

- edge_buffer:

  Numeric. Buffer distance (m) for edge effect calculation. Default 50.

## Value

The input sf object with added columns:

- R4: Browsing pressure risk (0-100). Higher = higher risk.

- R4_palatability: Species palatability score (0-100).

- R4_vulnerability: Stand vulnerability score (0-100).

## Details

Aligned with tuto 03 methodology: BD Foret intersection for
palatability, LiDAR MNH for vulnerability, hunting data (data.gouv.fr)
for density.

\*\*Formula\*\*: R4 = 0.35\*palatability + 0.30\*vulnerability +
0.20\*edge + 0.15\*density

\*\*Components\*\*:

- palatability: From BD Foret species intersection (pattern matching on
  essence names). Quercus=90, Abies=85, Fagus=70, Pinus=30.

- vulnerability: From LiDAR MNH mean height per parcel. \<2m = 100,
  2-10m = decreasing, \>10m = 0.

- edge_exposure: Proportion of parcel within buffer of forest edge.

- game_density: From departmental hunting harvest statistics
  (data.gouv.fr, OFB). Auto-fetched via
  [`get_game_pressure_raster`](https://pobsteta.github.io/nemeton/reference/get_game_pressure_raster.md).

## See also

Other risk-indicators:
[`indicateur_r1_feu()`](https://pobsteta.github.io/nemeton/reference/indicateur_r1_feu.md),
[`indicateur_r2_tempete()`](https://pobsteta.github.io/nemeton/reference/indicateur_r2_tempete.md),
[`indicateur_r3_secheresse()`](https://pobsteta.github.io/nemeton/reference/indicateur_r3_secheresse.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)

data(massif_demo_units)
units <- massif_demo_units

result <- indicateur_r4_abroutissement(units)
summary(result$R4)
} # }
```
