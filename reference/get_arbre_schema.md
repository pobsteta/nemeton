# Get the arbre layer schema

Returns the ordered list of field descriptors for the `arbre` layer. The
`espece` domain is populated from the species configuration of `region`
(see
[`list_species_classes`](https://pobsteta.github.io/nemeton/reference/list_species_classes.md)),
so that QField offers a controlled vocabulary consistent with the rest
of the package.

## Usage

``` r
get_arbre_schema(region = "BFC", lang = "fr")
```

## Arguments

- region:

  Character. Species region used to populate the `espece` domain.
  Default `"BFC"`.

- lang:

  Character. Language for the species labels. Default `"fr"`.

## Value

A list of field descriptors.

## Examples

``` r
schema <- get_arbre_schema(region = "BFC", lang = "fr")
espece <- Filter(function(f) f$name == "espece", schema)[[1]]
espece$domain
#>  [1] "essence_chenaie"            "essence_hetraie"           
#>  [3] "essence_chataigneraie"      "essence_feuillus_pionniers"
#>  [5] "essence_peupleraie"         "essence_pessiere_sapiniere"
#>  [7] "essence_douglasaie"         "essence_pinede"            
#>  [9] "essence_melezin"            "essence_chene_vert"        
#> [11] "essence_mixte"             
```
