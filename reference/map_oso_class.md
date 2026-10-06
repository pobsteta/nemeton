# Map OSO class to possible NMT species classes

Returns the species classes a pixel of the given OSO land-cover code may
hold. OSO (2018 onwards, 23 classes) splits forest into broadleaf (16)
and coniferous (17) and has no mixed-forest class: a mixed stand falls
in either, so `"essence_mixte"` is listed under both.

## Usage

``` r
map_oso_class(oso_class, region = "BFC")
```

## Arguments

- oso_class:

  Integer. OSO class code; only the forest codes 16 and 17 map to
  species classes.

- region:

  Character. Region code. Default "BFC".

## Value

Character vector of possible NMT species class codes; empty
(`character(0)`) for a non-forest code or a region without OSO mapping.

## Details

Before 0.212.2 the mapping read an obsolete nomenclature (17 =
deciduous, 18 = coniferous, 19 = mixed): under the current one, 17 is
coniferous forest and 18 is grassland, so broadleaf species were
returned for conifers and conifers for grassland. Any non-forest code
also returned `"essence_mixte"`.

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

## Examples

``` r
map_oso_class(16, "BFC")  # feuillus possibles
#> [1] "essence_chenaie"            "essence_hetraie"           
#> [3] "essence_chataigneraie"      "essence_feuillus_pionniers"
#> [5] "essence_peupleraie"         "essence_chene_vert"        
#> [7] "essence_mixte"             
map_oso_class(17, "BFC")  # coniferes possibles
#> [1] "essence_pessiere_sapiniere" "essence_douglasaie"        
#> [3] "essence_pinede"             "essence_melezin"           
#> [5] "essence_mixte"             
map_oso_class(4, "BFC")   # routes : aucune essence
#> character(0)
```
