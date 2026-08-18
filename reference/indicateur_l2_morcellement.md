# Landscape Fragmentation (L2)

Calculates landscape fragmentation using landscapemetrics (COHESION +
AI) when available, or shape index fallback. Returns a score 0-100.

## Usage

``` r
indicateur_l2_morcellement(
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

## Renamed in 0.176.0

This indicator used to be called
[`indicateur_l1_sylvosphere()`](https://pobsteta.github.io/nemeton/reference/indicateur_l1_sylvosphere.md)
– a name that announced the L1 sylvosphere while computing the L2
fragmentation metric. The old name still works and returns the same
values, with a deprecation warning. Persisted columns are renamed by
[`migrer_colonnes_l`](https://pobsteta.github.io/nemeton/reference/migrer_colonnes_l.md).
See spec 045.

## Examples

``` r
if (FALSE) { # \dontrun{
results <- indicateur_l2_morcellement(units, layers, buffer = 1000)
} # }
```
