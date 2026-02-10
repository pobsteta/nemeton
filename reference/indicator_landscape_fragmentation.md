# Sylvosphere - Edge Effect (L1)

Composite indicator (0-100) with 3 components: - Geometry (30 - Matrix
contrast (40 - Exposure (30

## Usage

``` r
indicator_landscape_fragmentation(
  units,
  layers = NULL,
  landcover_layer = "landcover",
  forest_values = seq(1, 6),
  buffer = 50
)
```

## Arguments

- units:

  nemeton_units object

- layers:

  nemeton_layers object containing land cover (optional)

- landcover_layer:

  Character. Name of land cover layer

- forest_values:

  Numeric vector. Land cover codes for forest

- buffer:

  Numeric. Buffer distance (meters) for contrast analysis. Default 50m.

## Value

Numeric vector of sylvosphere scores (0-100)

## Examples

``` r
if (FALSE) { # \dontrun{
layers <- nemeton_layers(rasters = list(landcover = "landcover.tif"))
results <- indicator_landscape_fragmentation(
  units, layers,
  forest_values = c(1, 2, 3), buffer = 50
)
} # }
```
