# Get NDP confidence ratio

Returns the cumulative confidence phi, calculated as the ratio of
cumulative Fibonacci weight up to this level over the total (12).

## Usage

``` r
get_ndp_confidence(ndp)
```

## Arguments

- ndp:

  Integer. NDP level (0-4).

## Value

Numeric. Confidence ratio between 0 and 1.

## Examples

``` r
get_ndp_confidence(0) # 1/12 ~ 0.083
#> [1] 0.08333333
get_ndp_confidence(4) # 1.0
#> [1] 1
```
