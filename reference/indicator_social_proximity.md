# S3: Population Proximity Indicator

Calculates population counts within buffer zones (5km, 10km, 20km) to
estimate visitor pressure potential and recreational use intensity.

## Usage

``` r
indicator_social_proximity(
  units,
  population_grid = NULL,
  method = c("proxy", "insee", "local"),
  buffer_radii = c(5000, 10000, 20000),
  column_name = "S3",
  lang = "en"
)
```

## Arguments

- units:

  sf object (POLYGON) of spatial units to assess

- population_grid:

  sf object or SpatRaster of population data. If NULL, uses proxy.

- method:

  Character. Data source: "insee" (INSEE Carroyage), "local", or
  "proxy". Default "proxy".

- buffer_radii:

  Numeric vector. Buffer distances (m) for population counts. Default
  c(5000, 10000, 20000).

- column_name:

  Character. Name for output column (main indicator). Default "S3".

- lang:

  Character. Message language. Default "en".

## Value

sf object with added columns: S3 (population within primary buffer),
S3_5km, S3_10km, S3_20km

## Details

\*\*Calculation\*\*:

- Create buffer zones around each unit (5km, 10km, 20km)

- Sum population within each buffer from INSEE Carroyage 1km grid

- S3 = population within closest buffer (highest pressure)

\*\*Data Sources\*\*:

- INSEE Carroyage 1km or 200m population grids (France)

- WorldPop or GPW for international applications

- Proxy: Distance to nearest urban area if no population data

## Examples

``` r
if (FALSE) { # \dontrun{
result <- indicator_social_proximity(
  units = massif_demo_units,
  method = "proxy",
  buffer_radii = c(5000, 10000, 20000)
)
} # }
```
