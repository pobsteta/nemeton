# Charru 2017 BAI drift lookup table

Returns the per-species relative BAI change over 1980-2007 and the
climatic habitat of each species.

## Usage

``` r
charru_bai_drift_table()
```

## Value

A data.frame with columns `species`, `habitat` and `bai_chg`.

## Examples

``` r
charru_bai_drift_table()
#>   species       habitat bai_chg
#> 1    PIAB      mountain    1.25
#> 2    ABAL      mountain    1.17
#> 3    PISY    generalist    0.96
#> 4    FASY    generalist    1.05
#> 5    QURO       lowland    1.00
#> 6    QUPE       lowland    0.97
#> 7    QUPU mediterranean    0.88
#> 8    PIHA mediterranean    0.72
```
