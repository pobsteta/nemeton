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
  column_name = "S1",
  lang = "en"
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

- column_name:

  Character. Name for output column. Default "S1".

- lang:

  Character. Message language ("en" or "fr"). Default "en".

## Value

sf object with added column: S1 (mean distance to nearest road in
metres)

## Details

\*\*Calculation\*\* (tuto 03 method):

- Rasterize road geometries onto the DEM grid

- Compute distance raster via
  [`terra::distance()`](https://rspatial.github.io/terra/reference/distance.html)

- Extract mean distance per spatial unit

Returns NA when DEM or roads are unavailable.

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
