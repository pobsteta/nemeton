# Map BD Foret essence to NMT species class

Translates a BD Foret V2 essence label into the corresponding NMT
species class code using the region's bdforet_mapping.

## Usage

``` r
map_bdforet_essence(essence, region = "BFC")
```

## Arguments

- essence:

  Character. BD Foret essence label.

- region:

  Character. Region code. Default "BFC".

## Value

Character. NMT species class code (e.g., "essence_chenaie"), or
"essence_mixte" if no mapping found.

## Examples

``` r
map_bdforet_essence("Hêtre", region = "BFC")  # "essence_hetraie"
#> [1] "essence_hetraie"
map_bdforet_essence("Douglas", region = "BFC")  # "essence_douglasaie"
#> [1] "essence_douglasaie"
```
