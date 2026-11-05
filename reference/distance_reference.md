# Distance of embeddings to a reference set

Mahalanobis distance of each row of `x` to the centroid of `reference`,
with the reference covariance shrunk towards a scaled identity by the
Ledoit-Wolf (2004) estimator. With few reference rows and many
dimensions (15 units, 64 dimensions) the sample covariance is singular;
shrinkage keeps it invertible, at the price of a distance that tends to
the Euclidean one as the reference shrinks.

## Usage

``` r
distance_reference(x, reference, method = c("mahalanobis_lw", "euclidean"))
```

## Arguments

- x:

  Numeric matrix (`n x d`), rows to score (e.g. the `mean` of
  [`embedding_summary()`](https://pobsteta.github.io/nemeton/reference/embedding_summary.md)).

- reference:

  Numeric matrix (`m x d`), the reference rows. Rows with a non-finite
  value are dropped.

- method:

  `"mahalanobis_lw"` (default) or `"euclidean"`.

## Value

A list with

- distance:

  numeric, distance of each row of `x` (NA for a row with a non-finite
  value).

- distance_loo:

  numeric, leave-one-out distance of each reference row to the reference
  built without it: the reference's own spread, used to turn a distance
  into a score.

- shrinkage:

  Ledoit-Wolf intensity in `[0, 1]` (1 = identity), `NA` for
  `"euclidean"`.

- n_reference:

  number of reference rows used.

- method:

  the method.

## Lifecycle

Experimental (spec 064): may change in any release.

## References

Ledoit O., Wolf M. (2004). A well-conditioned estimator for
large-dimensional covariance matrices. *Journal of Multivariate
Analysis* 88(2), 365-411.

## See also

[`embedding_summary()`](https://pobsteta.github.io/nemeton/reference/embedding_summary.md),
[`indicateur_n5_distance_reference()`](https://pobsteta.github.io/nemeton/reference/indicateur_n5_distance_reference.md)
