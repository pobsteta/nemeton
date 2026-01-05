# Landscape Fragmentation (L1)

Calculates forest patch metrics within buffer zone: patch count and mean
size. Higher fragmentation = more patches with smaller mean size.

## Usage

``` r
indicator_landscape_fragmentation(
  units,
  layers,
  landcover_layer = "landcover",
  forest_values = c(1, 2, 3),
  buffer = 1000
)
```

## Arguments

- units:

  nemeton_units object

- layers:

  nemeton_layers object containing land cover

- landcover_layer:

  Character. Name of land cover layer

- forest_values:

  Numeric vector. Land cover codes for forest

- buffer:

  Numeric. Analysis buffer distance (meters). Default 1000 (1 km).

## Value

Numeric vector of fragmentation index (patch count / mean size)

## Examples

``` r
if (FALSE) { # \dontrun{
layers <- nemeton_layers(rasters = list(landcover = "landcover.tif"))
results <- indicator_landscape_fragmentation(
  units, layers, forest_values = c(1, 2, 3), buffer = 1000
)
} # }
```
