# Landscape Fragmentation (L2)

Calculates landscape fragmentation using landscapemetrics (COHESION +
AI) when available, or shape index fallback. Returns a score 0-100.

## Usage

``` r
indicator_landscape_edge(
  units,
  layers = NULL,
  landcover_layer = "landcover",
  forest_values = seq(1, 6),
  buffer = 1000
)
```

## Arguments

- units:

  nemeton_units object

- layers:

  nemeton_layers object (optional, for raster-based metrics)

- landcover_layer:

  Character. Name of landcover layer in layers.

- forest_values:

  Numeric vector. Values representing forest in landcover.

- buffer:

  Numeric. Buffer distance in meters around union of parcels.

## Value

Numeric vector of fragmentation scores (0-100)

## Examples

``` r
if (FALSE) { # \dontrun{
results <- indicator_landscape_edge(units, layers, buffer = 1000)
} # }
```
