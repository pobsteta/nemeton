# H_dom -\> D_g calibration table (IFN / Charru)

Returns the species-keyed power-law parameters used by
[`estimate_dq_from_hdom`](https://pobsteta.github.io/nemeton/reference/estimate_dq_from_hdom.md).
The `a` column is calibrated so that \\a \cdot H_0^{0.9} = D_g\\ for the
mean IFN \\(H_0, D_g)\\ pair of each species (Charru et al. 2012 Table 1
x Charru et al. 2017 Table 1). The `dq_min` / `dq_max` columns are the
observed Dg range boundaries from Charru 2012 Table 1.

## Usage

``` r
h_to_dq_params()
```

## Value

A data.frame with columns `species, a, b, dq_min, dq_max`.

## Examples

``` r
h_to_dq_params()
#>    species     a   b dq_min dq_max
#> 1     QUPU 1.928 0.9     15     37
#> 2     QURO 1.646 0.9     15     37
#> 3     QUPE 1.351 0.9     15     30
#> 4     FASY 1.523 0.9     16     40
#> 5     PIAB 1.646 0.9     15     45
#> 6     ABAL 1.615 0.9     15     45
#> 7     PISY 1.922 0.9     14     33
#> 8     PIPI 2.050 0.9     16     37
#> 9     PIHA 2.431 0.9     15     40
#> 10    PILA 2.058 0.9     18     50
#> 11    PSME 1.551 0.9     20     50
#> 12    CASA 1.450 0.9     12     50
#> 13    POSP 1.450 0.9     12     50
```
