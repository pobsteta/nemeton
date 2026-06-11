# List species covered by the site-index curves

Returns the species codes available in
`inst/extdata/site_index_curves.csv`. Codes `BROADLEAF_GENUS` and
`CONIFER_GENUS` are genus-level fallbacks automatically used when the
input species is not directly tabulated.

## Usage

``` r
list_site_index_species()
```

## Value

A character vector of species codes.

## Examples

``` r
list_site_index_species()
#>  [1] "ABAL"            "BROADLEAF_GENUS" "CASA"            "CONIFER_GENUS"  
#>  [5] "FASY"            "FASY_NE"         "FASY_NO"         "PIAB"           
#>  [9] "PIPI"            "PISY"            "POSP"            "PSME"           
#> [13] "QUPE"            "QURO"           
```
