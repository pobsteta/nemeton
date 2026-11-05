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
  min_windows = 3L,
  embedding = NULL,
  layers = NULL,
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

- min_windows:

  Integer. Minimum number of covered diversity windows below which the
  unit's dispersion is undefined and `NA` is returned (default `3L`, the
  floor for a dispersion around a centroid). Values below 3 are raised
  to 3.

- embedding, layers:

  Embedding mode, as in
  [`indicateur_b4_div_spectrale()`](https://pobsteta.github.io/nemeton/reference/indicateur_b4_div_spectrale.md):
  L3 is then the mean Euclidean distance of the unit's 100 m window mean
  embeddings (fixed grid) to the unit's centroid, `NA` below
  `min_windows` windows. Status `"calculated_embedding"`, method in
  `l3_methode`. The value grows with unit size (more windows, more
  contrast): compare units of similar size.

- ...:

  Passed to
  [`compute_spectral_diversity`](https://pobsteta.github.io/nemeton/reference/compute_spectral_diversity.md)
  when computing on the fly (e.g. `window_size`, `mask`, `nb_cpu`).

## Value

`units` with the numeric `L3` column added, `l3_status` (`"calculated"`,
`"calculated_embedding"`, `"skipped_no_spectral"` or
`"skipped_no_coverage"`) and `l3_methode` (`"biodivmapr"`, `"embedding"`
or `NA`).

## Details

biodivMapR returns beta diversity as the first three axes of a PCoA of
the Bray-Curtis dissimilarity between windows, *not* as a scalar
dissimilarity raster. The value reported here is therefore the unit's
**multivariate dispersion** in that ordination space: the mean Euclidean
distance of the unit's windows to the unit's own centroid (Anderson's
betadisper). A spectrally uniform unit scores near zero; a unit spanning
contrasted spectral communities scores high.

Before v0.190.0 the axes were simply averaged, which measured a unit's
mean *position* in ordination space — a quantity centred on zero by
construction, and clamped to 0 for every unit on the negative side. See
spec 028 section 10.

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

## See also

[`compute_spectral_diversity`](https://pobsteta.github.io/nemeton/reference/compute_spectral_diversity.md)
