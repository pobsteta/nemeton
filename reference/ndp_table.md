# NDP levels as a data.frame

Returns a data.frame summarizing the 5 NDP levels with their Fibonacci
weights and confidence ratios.

## Usage

``` r
ndp_table()
```

## Value

A data.frame with columns: ndp, key, name, fibonacci, confidence.

## Examples

``` r
ndp_table()
#>   ndp             key        name fibonacci confidence
#> 1   0  ndp_decouverte  Découverte         1 0.08333333
#> 2   1 ndp_observation Observation         1 0.16666667
#> 3   2 ndp_exploration Exploration         2 0.33333333
#> 4   3  ndp_diagnostic  Diagnostic         3 0.58333333
#> 5   4      ndp_jumeau      Jumeau         5 1.00000000
```
