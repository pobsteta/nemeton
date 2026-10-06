# S1: Distance to Roads Indicator

Calculates the mean distance (in metres) from each spatial unit to the
nearest road, using rasterized road data and
[`terra::distance()`](https://rspatial.github.io/terra/reference/distance.html).

## Usage

``` r
indicateur_s1_routes(
  units,
  roads = NULL,
  dem = NULL,
  layers = NULL,
  dem_target_res = .topo_target_res(),
  max_dist = 2000
)
```

## Arguments

- units:

  sf object (POLYGON) of spatial units to assess

- roads:

  sf object (LINESTRING) of road network. If NULL, resolved from layers.

- dem:

  SpatRaster. Digital elevation model used as reference grid. If NULL,
  resolved from layers.

- layers:

  A nemeton_layers object (optional). Used to resolve roads/dem when not
  provided directly.

- dem_target_res:

  Numeric. Working resolution (metres) the DEM grid is aggregated to
  before roads are rasterised and the distance transform runs. The DEM
  is only a grid template here, and a 0.5-1 m LiDAR HD MNT makes that
  transform cost gigabytes for a mean distance per unit. Default: the
  package-wide topographic working resolution, 2 m — see
  `options("nemeton.topo_target_res")`; `NULL` keeps the native
  resolution.

- max_dist:

  Numeric. Search radius (metres) around the units, default 2000 m (the
  distance at which the normalised score reaches 0). The working grid
  covers the units' extent widened by `max_dist`, not the DEM extent, so
  features just outside the DEM are no longer ignored. Distances are
  exact up to `max_dist` and censored at `max_dist` beyond (a unit with
  no feature within `max_dist` gets `max_dist`, i.e. "at least
  `max_dist`"); with no feature at all, the indicator is `NA`.

## Value

sf object with added column: S1 (mean distance to nearest road in
metres)

## Details

\*\*Calculation\*\* (tuto 03 method):

- Rasterize road geometries onto a grid with the DEM resolution,
  covering the units' extent widened by `max_dist`

- Compute distance raster via
  [`terra::distance()`](https://rspatial.github.io/terra/reference/distance.html),
  censored at `max_dist`

- Extract mean distance per spatial unit

Returns NA when DEM or roads are unavailable.

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

## Examples

``` r
if (FALSE) { # \dontrun{
result <- indicateur_s1_routes(
  units = parcels,
  roads = roads_sf,
  dem = dem_raster
)
} # }
```
