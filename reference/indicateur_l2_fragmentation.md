# Sylvosphere - Edge Effect (L1), deprecated name

Deprecated since 0.176.0. The name announced the L2 fragmentation metric
while the function computes the L1 edge effect. Use
[`indicateur_l1_effet_lisiere`](https://pobsteta.github.io/nemeton/reference/indicateur_l1_effet_lisiere.md),
which returns the same values.

## Usage

``` r
indicateur_l2_fragmentation(
  units,
  layers = NULL,
  landcover_layer = "landcover",
  forest_values = c(16, 17),
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

  Numeric vector. Land cover codes for forest; their matrix contrast
  is 0. Default `c(16, 17)`: OSO broadleaf and coniferous forest
  (23-class Theia/CESBIO nomenclature). Other codes are read with the
  OSO contrast table (built-up 90, roads 75, crops 50,
  orchards/vineyards 45, water 30, grassland 20, moorland 15; 50 for
  codes outside the nomenclature).

- buffer:

  Numeric. Buffer distance (meters) for contrast analysis. Default 50m.

## Value

Numeric vector of sylvosphere scores (0-100) – unchanged.

## See also

[`migrer_colonnes_l`](https://pobsteta.github.io/nemeton/reference/migrer_colonnes_l.md)
to rename the columns of an already computed dataset.
