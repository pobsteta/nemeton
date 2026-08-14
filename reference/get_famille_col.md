# Family score column name from family code

Maps a family code to the name of the family score column produced by
[`create_family_index`](https://pobsteta.github.io/nemeton/reference/create_family_index.md)
– `"C"` becomes `"famille_carbone"`. That name is a contract between the
core and its consumers: it is the column carried by the computed `sf`,
and downstream packages use it as a stable identifier (tab value,
database column). Read it here rather than hard-coding the 12 strings;
the whole mapping is also available as the `family_column` column of
[`indicator_families`](https://pobsteta.github.io/nemeton/reference/indicator_families.md).

## Usage

``` r
get_famille_col(code)
```

## Arguments

- code:

  Character. Single-letter family code (e.g. `"C"`, `"B"`),
  case-insensitive. Vectorised.

## Value

Character vector of NMT family column names (e.g. `"famille_carbone"`),
same length as `code`.

## See also

[`get_famille_code`](https://pobsteta.github.io/nemeton/reference/get_famille_code.md)
for the reverse lookup,
[`indicator_families`](https://pobsteta.github.io/nemeton/reference/indicator_families.md).

## Examples

``` r
get_famille_col("C")
#> [1] "famille_carbone"
get_famille_col(c("C", "b", "N"))
#> [1] "famille_carbone"      "famille_biodiversite" "famille_naturalite"  
```
