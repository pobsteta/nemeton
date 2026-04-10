# Map OSO class to possible NMT species classes

Returns the list of possible species classes for a given OSO land cover
code (17=deciduous, 18=coniferous, 19=mixed).

## Usage

``` r
map_oso_class(oso_class, region = "BFC")
```

## Arguments

- oso_class:

  Integer. OSO class code (17, 18, or 19).

- region:

  Character. Region code. Default "BFC".

## Value

Character vector of possible NMT species class codes.

## Examples

``` r
map_oso_class(17, "BFC")  # feuillus possibles
#> [1] "essence_chenaie"            "essence_hetraie"           
#> [3] "essence_chataigneraie"      "essence_feuillus_pionniers"
#> [5] "essence_peupleraie"         "essence_chene_vert"        
map_oso_class(18, "BFC")  # coniferes possibles
#> [1] "essence_pessiere_sapiniere" "essence_douglasaie"        
#> [3] "essence_pinede"             "essence_melezin"           
```
