# Indicator L3 — Spectral beta diversity / landscape heterogeneity (family L)

Per-unit Bray-Curtis beta diversity (spectral-species turnover,
biodivMapR): the compositional heterogeneity of the landscape mosaic,
complementary to L2 (geometric fragmentation). Higher = more diverse
mosaic (spec 028 D1). Backward compatible like
[`indicateur_b4_div_spectrale`](https://pobsteta.github.io/nemeton/reference/indicateur_b4_div_spectrale.md).

## Usage

``` r
indicateur_l3_het_spectrale(
  units,
  spectral = NULL,
  reflectance = NULL,
  column_name = "L3",
  ...
)
```

## Arguments

- units:

  sf polygon layer (spatial units / UGF).

- spectral:

  Optional precomputed result of
  [`compute_spectral_diversity`](https://pobsteta.github.io/nemeton/reference/compute_spectral_diversity.md)
  (preferred — compute once, share with B4). When `NULL`, falls back to
  `reflectance`.

- reflectance:

  Optional reflectance `SpatRaster` / path used to compute spectral
  diversity on the fly when `spectral` is `NULL`.

- column_name:

  Output column name (default `"L3"`).

- ...:

  Passed to
  [`compute_spectral_diversity`](https://pobsteta.github.io/nemeton/reference/compute_spectral_diversity.md)
  when computing on the fly (e.g. `window_size`, `mask`, `nb_cpu`).

## Value

`units` with the numeric `column_name` column added.

## See also

[`compute_spectral_diversity`](https://pobsteta.github.io/nemeton/reference/compute_spectral_diversity.md)
