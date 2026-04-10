# Get NDP Fibonacci weight

Get NDP Fibonacci weight

## Usage

``` r
get_ndp_weight(ndp)
```

## Arguments

- ndp:

  Integer. NDP level (0-4).

## Value

Integer. Fibonacci weight (1, 1, 2, 3, or 5).

## Examples

``` r
get_ndp_weight(0) # 1
#> [1] 1
get_ndp_weight(4) # 5
#> [1] 5
```
