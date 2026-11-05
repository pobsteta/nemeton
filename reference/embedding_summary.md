# Summarise a pixel-embedding raster per spatial unit

Coverage-weighted mean and standard deviation of every embedding
dimension inside each unit. Generic: the raster may come from any
foundation model (AlphaEarth, MAESTRO, ForPT), one band per dimension.

## Usage

``` r
embedding_summary(units, layer, stats = c("mean", "sd"), min_pixels = 10)
```

## Arguments

- units:

  sf polygon layer (spatial units / UGF).

- layer:

  SpatRaster, one band per embedding dimension (e.g. 64 for AlphaEarth
  Foundations).

- stats:

  Character. Statistics to return among `"mean"` and `"sd"`.

- min_pixels:

  Numeric. Minimum covered area, in pixels (sum of the coverage
  fractions of the valid pixels), below which the unit's row is `NA`.

## Value

A list with

- mean:

  `n_units x d` matrix of coverage-weighted means (if requested).

- sd:

  `n_units x d` matrix of coverage-weighted standard deviations (if
  requested).

- n_pixels:

  numeric vector, covered area in pixels.

- meta:

  list: `dimension`, `source` (the raster's `embedding_source`
  attribute, or `NA`), `min_pixels`.

## Details

AlphaEarth embeddings have unit norm. The mean of unit vectors does not:
its norm (between 0 and 1) measures how homogeneous the unit is. The
mean is returned as is, not renormalised (spec 064, D-3).

A pixel counts only if all its dimensions are finite.

## Lifecycle

Experimental (spec 064): may change in any release.

## See also

[`distance_reference()`](https://pobsteta.github.io/nemeton/reference/distance_reference.md),
[`indicateur_n5_distance_reference()`](https://pobsteta.github.io/nemeton/reference/indicateur_n5_distance_reference.md)
