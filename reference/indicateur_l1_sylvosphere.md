# Landscape Fragmentation (L2), deprecated name

Deprecated since 0.176.0. The name announced the L1 sylvosphere while
the function computes the L2 fragmentation metric. Use
[`indicateur_l2_morcellement`](https://pobsteta.github.io/nemeton/reference/indicateur_l2_morcellement.md),
which returns the same values.

## Usage

``` r
indicateur_l1_sylvosphere(
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

Numeric vector of fragmentation scores (0-100) – unchanged.

## See also

[`migrer_colonnes_l`](https://pobsteta.github.io/nemeton/reference/migrer_colonnes_l.md)
to rename the columns of an already computed dataset.
