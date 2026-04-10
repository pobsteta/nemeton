# Get NDP level name

Get NDP level name

## Usage

``` r
get_ndp_name(ndp)
```

## Arguments

- ndp:

  Integer. NDP level (0-4).

## Value

Character. French name of the level.

## Examples

``` r
get_ndp_name(0) # "Decouverte"
#> [1] "Découverte"
get_ndp_name(4) # "Jumeau"
#> [1] "Jumeau"
```
