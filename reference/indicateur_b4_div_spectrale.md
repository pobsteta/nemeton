# Indicator B4 — Spectral alpha diversity (family B)

Per-unit Shannon alpha diversity of spectral species (biodivMapR), a
remote-sensing proxy for compositional biodiversity available from NDP 0
(Sentinel-2). Strictly backward compatible: with neither `spectral` nor
`reflectance`, the column is filled with `NA` and the `sf` is returned
unchanged.

## Usage

``` r
indicateur_b4_div_spectrale(
  units,
  spectral = NULL,
  reflectance = NULL,
  ...
)
```

## Arguments

- units:

  sf polygon layer (spatial units / UGF).

- spectral:

  Optional precomputed result of
  [`compute_spectral_diversity`](https://pobsteta.github.io/nemeton/reference/compute_spectral_diversity.md)
  (preferred — compute once, share with L3). When `NULL`, falls back to
  `reflectance`.

- reflectance:

  Optional reflectance `SpatRaster` / path used to compute spectral
  diversity on the fly when `spectral` is `NULL`.

- ...:

  Passed to
  [`compute_spectral_diversity`](https://pobsteta.github.io/nemeton/reference/compute_spectral_diversity.md)
  when computing on the fly (e.g. `window_size`, `mask`, `nb_cpu`).

## Value

`units` with the numeric `B4` column added, and `b4_status`
(`"calculated"`, `"skipped_no_spectral"` or `"skipped_no_coverage"`).

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

## See also

[`compute_spectral_diversity`](https://pobsteta.github.io/nemeton/reference/compute_spectral_diversity.md)
