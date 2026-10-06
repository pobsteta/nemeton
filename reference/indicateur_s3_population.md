# S3: Population Proximity Indicator

Calculates the population density around each unit (and population
counts within buffer zones of 5, 10 and 20 km) to estimate visitor
pressure potential and recreational use intensity.

## Usage

``` r
indicateur_s3_population(
  units,
  population_grid = NULL,
  population_field = NULL,
  method = c("insee", "local", "proxy"),
  buffer_radii = c(5000, 10000, 20000)
)
```

## Arguments

- units:

  sf object (POLYGON) of spatial units to assess

- population_grid:

  sf object (polygons carrying a population count) or SpatRaster of
  population counts. If NULL, S3 is NA (no measurement).

- method:

  Character. `"insee"` (default) or `"local"`: both read
  `population_grid` the same way (the label is informative). `"proxy"`
  no longer exists and raises an error.

- buffer_radii:

  Numeric vector. Buffer distances (m) for population counts. Default
  c(5000, 10000, 20000).

- population_field:

  Character or `NULL`. Name of the population column of
  `population_grid` when it is an `sf`. `NULL` (default) looks for
  `ind`, `pop` or `population` (INSEE Filosofi names it `ind`).

## Value

sf object with added columns: `S3` (population density in
inhabitants/km2 within the first buffer), `S3_densite` (same value), and
the population counts `S3_5km`, `S3_10km`, `S3_20km` within the three
buffers of `buffer_radii` (the names are kept whatever the radii).
Without `population_grid`, `S3` and the counts are NA and `S3_densite`
is not added.

## Details

\*\*Calculation\*\*:

- Create buffer zones around each unit (`buffer_radii`, default 5, 10
  and 20 km)

- Sum the population within each buffer; a grid cell straddling the
  buffer counts for the share of its area inside it

- S3 = population of the first buffer / its area (inhabitants/km2)

\*\*Data Sources\*\*:

- INSEE Filosofi gridded population, 200 m or 1 km cells (France; count
  field `ind`)

- WorldPop or GPW for international applications

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

## Examples

``` r
if (FALSE) { # \dontrun{
data(massif_demo_units)
carreaux <- sf::st_read("path/to/filosofi_carreaux_200m.gpkg")
result <- indicateur_s3_population(
  units = massif_demo_units,
  population_grid = carreaux,
  buffer_radii = c(5000, 10000, 20000)
)
} # }
```
