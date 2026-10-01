# Linear trend of an E-OBS summer series (per decade)

Fit the least-squares trend of a per-year summer series (the output of
[`eobs_summer_series`](https://pobsteta.github.io/nemeton/reference/eobs_summer_series.md))
and return the per-decade slope with its goodness of fit, for the trend
line of chart 1 (spec 036). The slope is `10 *` the per-year OLS slope,
matching the mapped per-decade slope
([`tendances_estivales_eobs()`](https://pobsteta.github.io/nemeton/reference/tendances_estivales_eobs.md)
/
[`eobs_downscale()`](https://pobsteta.github.io/nemeton/reference/eobs_downscale.md)),
so the click chart and the map colour agree by construction.

## Usage

``` r
eobs_trend_fit(series)
```

## Arguments

- series:

  A `data.frame` with numeric columns `year` and `value` (as returned by
  [`eobs_summer_series`](https://pobsteta.github.io/nemeton/reference/eobs_summer_series.md)).

## Value

A `list(slope_decade, intercept, r2, p_value, n)`. All `NA` (with `n`
the count of finite pairs) when fewer than two finite points are
available.

## See also

[`eobs_summer_series`](https://pobsteta.github.io/nemeton/reference/eobs_summer_series.md)

## Examples

``` r
eobs_trend_fit(data.frame(year = 2011:2020, value = 20 + (0:9) * 0.1))
#> $slope_decade
#> [1] 1
#> 
#> $intercept
#> [1] -181.1
#> 
#> $r2
#> [1] 1
#> 
#> $p_value
#> [1] 1.181394e-112
#> 
#> $n
#> [1] 10
#> 
```
