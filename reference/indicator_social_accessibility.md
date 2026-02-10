# S2: Distance to Buildings Indicator

Calculates the mean distance (in metres) from each spatial unit to the
nearest building, using rasterized building data and
[`terra::distance()`](https://rspatial.github.io/terra/reference/distance.html).

## Usage

``` r
indicator_social_accessibility(
  units,
  buildings = NULL,
  dem = NULL,
  layers = NULL,
  column_name = "S2",
  lang = "en"
)
```

## Arguments

- units:

  sf object (POLYGON) of spatial units to assess

- buildings:

  sf object (POLYGON) of buildings. If NULL, resolved from layers.

- dem:

  SpatRaster. Digital elevation model used as reference grid. If NULL,
  resolved from layers.

- layers:

  A nemeton_layers object (optional). Used to resolve buildings/dem when
  not provided directly.

- column_name:

  Character. Name for output column. Default "S2".

- lang:

  Character. Message language. Default "en".

## Value

sf object with added column: S2 (mean distance to nearest building in
metres)

## Details

\*\*Calculation\*\* (tuto 03 method):

- Rasterize building geometries onto the DEM grid

- Compute distance raster via
  [`terra::distance()`](https://rspatial.github.io/terra/reference/distance.html)

- Extract mean distance per spatial unit

Returns NA when DEM or buildings are unavailable.

## Examples

``` r
if (FALSE) { # \dontrun{
result <- indicator_social_accessibility(
  units = parcels,
  buildings = buildings_sf,
  dem = dem_raster
)
} # }
```
