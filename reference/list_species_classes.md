# Get species classes for a region

Returns a data.frame of the species classes with their codes, labels,
and allometric keys.

## Usage

``` r
list_species_classes(region = "BFC", lang = "fr")
```

## Arguments

- region:

  Character. Region code. Default "BFC".

- lang:

  Character. Language for labels. Default "fr".

## Value

A data.frame with columns: code, label, allometric_key, color.

## Examples

``` r
classes <- list_species_classes("BFC", lang = "fr")
classes$code   # "essence_chenaie", "essence_hetraie", ...
#>  [1] "essence_chenaie"            "essence_hetraie"           
#>  [3] "essence_chataigneraie"      "essence_feuillus_pionniers"
#>  [5] "essence_peupleraie"         "essence_pessiere_sapiniere"
#>  [7] "essence_douglasaie"         "essence_pinede"            
#>  [9] "essence_melezin"            "essence_chene_vert"        
#> [11] "essence_mixte"             
classes$label  # "Chênaie", "Hêtraie", ...
#>  [1] "Chênaie"            "Hêtraie"            "Châtaigneraie"     
#>  [4] "Feuillus pionniers" "Peupleraie"         "Pessière-Sapinière"
#>  [7] "Douglasaie"         "Pinède"             "Mélézin"           
#> [10] "Chêne vert"         "Forêt mixte"       
```
