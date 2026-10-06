# Topographic Wetness Index (W3)

Calculates TWI using fasterRaster/GRASS GIS (preferred) or terra
fallback (D8). Higher values indicate areas with greater water
accumulation potential.

## Usage

``` r
indicateur_w3_humidite(
  units,
  layers,
  dem_layer = "dem",
  method = c("auto", "grass", "d8"),
  dem_target_res = .topo_target_res()
)
```

## Arguments

- units:

  nemeton_units object

- layers:

  nemeton_layers object containing DEM raster

- dem_layer:

  Character. Name of DEM layer in layers object

- method:

  Character. TWI calculation method: "auto" (prefer GRASS), "grass"
  (fasterRaster/GRASS GIS), or "d8" (terra D8). Default "auto".

- dem_target_res:

  Numeric. Working resolution (metres) the DEM is aggregated to before
  TWI is computed. The same value drives the TWI grid, so both coincide
  and the TWI is never resampled up to a finer grid. Keep it identical
  across W2/W3/F2/R3 to share a single cached TWI. Default: the
  package-wide topographic working resolution, 2 m — see
  `options("nemeton.topo_target_res")`; `NULL` keeps the native
  resolution.

## Value

The input `units` (same class, rows and order) with an added numeric
column `W3`: mean TWI, referenced to a 2 m grid.

## Details

The GRASS method (via fasterRaster) performs proper hydrological
conditioning: depression filling, flow direction, flow accumulation,
then TWI = ln(SCA / tan(slope)). The terra D8 method is a simpler
approximation used as fallback.

A DEM in geographic coordinates is first projected to a metric CRS (the
units' CRS when projected, else EPSG:3035): the specific catchment area
is in metres, never in degrees. The TWI is then referenced to a 2 m
grid, `TWI_2m = TWI - ln(step / 2)` with `step` the computation grid
step in metres, because the specific catchment area scales with the step
(spec 056). Values from different DEM resolutions are thus on one scale.

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

## Examples

``` r
if (FALSE) { # \dontrun{
layers <- nemeton_layers(rasters = list(dem = "dem_25m.tif"))
results <- indicateur_w3_humidite(units, layers, dem_layer = "dem")
} # }
```
