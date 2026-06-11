# Charru 2012 self-thinning coefficients table

Returns the species-keyed lookup table used by
[`n_max_selfthinning`](https://pobsteta.github.io/nemeton/reference/n_max_selfthinning.md).

## Usage

``` r
charru_selfthinning_table()
```

## Value

A data.frame with columns `species, model, a, b, c, dg_min, dg_max`.

## Examples

``` r
charru_selfthinning_table()
#>    species  model      a      b      c dg_min dg_max
#> 1     QUPU linear 12.270 -1.809  0.000     15     37
#> 2     QURO linear 12.138 -1.758  0.000     15     37
#> 3     QUPE linear 12.681 -1.911  0.000     15     30
#> 4     FASY   quad  9.790  0.000 -0.296     16     40
#> 5     PISY   quad  2.279  4.701 -1.023     16     33
#> 6     PIHA   quad  9.575  0.000 -0.299     15     40
#> 7     PILA linear 12.104 -1.653  0.000     18     40
#> 8     PIPI   quad  9.307  0.000 -0.272     16     37
#> 9     PIAB   quad 10.043  0.000 -0.287     15     40
#> 10    ABAL   quad  4.700  3.000 -0.718     15     45
#> 11    PSME   quad  0.607  5.192 -1.009     20     50
```
