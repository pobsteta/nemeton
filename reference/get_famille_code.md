# Family code from family score column name

Reverse of
[`get_famille_col`](https://pobsteta.github.io/nemeton/reference/get_famille_col.md):
`"famille_biodiversite"` becomes `"B"`. Unknown names give `NA` rather
than an error, so the function can be mapped over the columns of an
arbitrary `sf` to pick out the family scores.

## Usage

``` r
get_famille_code(col_name)
```

## Arguments

- col_name:

  Character. Family score column name(s). Vectorised.

## Value

Character vector of single-letter family codes, `NA_character_` where
the name is not a family score column.

## See also

[`get_famille_col`](https://pobsteta.github.io/nemeton/reference/get_famille_col.md),
[`indicator_families`](https://pobsteta.github.io/nemeton/reference/indicator_families.md).

## Examples

``` r
get_famille_code("famille_biodiversite")
#> [1] "B"
get_famille_code(c("famille_eau", "surface_m2"))
#> [1] "W" NA 
```
