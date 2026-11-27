# Apply a SharkRF model: votes per class

Vectorised prediction of a
[`reconfort_sharkrf_lire()`](https://pobsteta.github.io/nemeton/reference/reconfort_sharkrf_lire.md)
model: every tree casts one vote for the class of the leaf a row
reaches. The votes sum to the number of trees (1000 for the RECONFORT
models); the class is their argmax, as in IOTA2's
`ProbabilityMap_seed_0` (probability in per mille) and `Classif_Seed_0`.

## Usage

``` r
reconfort_sharkrf_predire(modele, x, bloc = 20000L)
```

## Arguments

- modele:

  A `reconfort_sharkrf` object.

- x:

  Numeric matrix, one row per pixel, one column per feature (at least
  `modele$n_vars` columns, in the order the model was trained on).

- bloc:

  Rows per block (default 20000).

## Value

An integer matrix with one row per row of `x` and one column per class
(header order); rows containing an `NA` are not predictable and give
`-1` in every column.

## Examples

``` r
# voir reconfort_sharkrf_lire()
```
