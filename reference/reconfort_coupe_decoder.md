# Decode a SUFOSAT \`YYDDD\` clear-cut date

\`YYDDD\` is the two-digit year followed by the day of the year (1 to
366), as in the published SUFOSAT / nemetonsar files: \`21150\` is day
150 of 2021. Zero and \`NA\` mean "no clear-cut".

## Usage

``` r
reconfort_coupe_decoder(code)
```

## Arguments

- code:

  Numeric vector of \`YYDDD\` codes.

## Value

A \`data.frame\` with \`annee\` (integer, 2000 + YY), \`jour\` (integer)
and \`date\` (\`Date\`), \`NA\` where there is no clear-cut. A code
whose day is outside 1..366 is an error, not a missing value.

## Examples

``` r
reconfort_coupe_decoder(c(21150, 0, NA))
#>   annee jour       date
#> 1  2021  150 2021-05-30
#> 2    NA   NA       <NA>
#> 3    NA   NA       <NA>
```
