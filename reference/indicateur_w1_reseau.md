# Hydrographic Network Density (W1)

Calculates stream/river network length density within or near forest
parcels. Includes a proximity bonus for parcels near watercourses
(within 500m) that are not directly crossed, reflecting the hydrological
influence of nearby streams on water table and microclimate.

## Usage

``` r
indicateur_w1_reseau(
  units,
  layers,
  watercourse_layer = "water_network",
  buffer = 0,
  proximity_m = 500,
  proximity_ref = 50
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

- proximity_m:

  Numeric. Maximum distance (m) for proximity bonus. Default 500.

- proximity_ref:

  Numeric. Equivalent density bonus (m/ha) at distance 0. Default 50.

## Value

Numeric vector of network density (m/ha)

## Examples

``` r
if (FALSE) { # \dontrun{
layers <- nemeton_layers(vectors = list(streams = "watercourses.gpkg"))
results <- indicateur_w1_reseau(units, layers, watercourse_layer = "streams")
} # }
```
