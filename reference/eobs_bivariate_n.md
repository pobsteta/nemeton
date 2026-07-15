# Number of classes per axis of the E-OBS bivariate map

The E-OBS bivariate trend map (T°max × precipitation) classifies each
axis into `N` levels, giving `N * N` combined classes. This accessor
exposes `N` so a consumer (e.g. the app's cached-raster layer) can
detect when a cached bivariate raster was written under a **different**
scheme and must be recomputed rather than served stale. The cache meta
carries the writing `N` in `palette$ncol`; compare it against this
value.

## Usage

``` r
eobs_bivariate_n()
```

## Value

Integer scalar. Currently `5` (a 5×5 = 25-class quincunx).

## See also

[`eobs_downscale_bivariate`](https://pobsteta.github.io/nemeton/reference/eobs_downscale_bivariate.md)

## Examples

``` r
eobs_bivariate_n()
#> [1] 5
```
