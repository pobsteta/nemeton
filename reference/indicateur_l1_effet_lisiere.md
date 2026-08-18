# Sylvosphere - Edge Effect (L1)

Composite indicator (0-100) with 3 components: - Geometry (30 - Matrix
contrast (40 - Exposure (30

## Usage

``` r
indicateur_l1_effet_lisiere(
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

## Renamed in 0.176.0

This indicator used to be called
[`indicateur_l2_fragmentation()`](https://pobsteta.github.io/nemeton/reference/indicateur_l2_fragmentation.md)
– a name that announced the L2 fragmentation metric while computing the
L1 edge effect. The old name still works and returns the same values,
with a deprecation warning. Persisted columns are renamed by
[`migrer_colonnes_l`](https://pobsteta.github.io/nemeton/reference/migrer_colonnes_l.md).
See spec 045.

## Examples

``` r
if (FALSE) { # \dontrun{
layers <- nemeton_layers(rasters = list(landcover = "landcover.tif"))
results <- indicateur_l1_effet_lisiere(
  units, layers,
  forest_values = c(1, 2, 3), buffer = 50
)
} # }
```
