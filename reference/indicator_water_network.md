# Hydrographic Network Density (W1)

Calculates stream/river network length density within or near forest
parcels. Higher values indicate greater hydrological connectivity.

## Usage

``` r
indicator_water_network(
  units,
  layers,
  watercourse_layer = "watercourses",
  buffer = 0
)
```

## Arguments

- units:

  nemeton_units object

- layers:

  nemeton_layers object containing watercourse vector layer

- watercourse_layer:

  Character. Name of watercourse layer in layers object

- buffer:

  Numeric. Buffer distance (meters) for proximity analysis. Default 0.

## Value

Numeric vector of network density (km/ha)

## Examples

``` r
if (FALSE) { # \dontrun{
layers <- nemeton_layers(vectors = list(streams = "watercourses.gpkg"))
results <- indicator_water_network(units, layers, watercourse_layer = "streams")
} # }
```
