# Video inventory GeoPackage schema

Reads the schema of `inventaire_video.gpkg`, shared with the Groma
Python and Kotlin code, and returns it as field descriptors in the
format of
[`get_placette_schema`](https://pobsteta.github.io/nemeton/reference/get_placette_schema.md)
(`name`, `type`, `widget`, `qgis_widget`, `label`, `domain`, `required`,
`min`, `max`, `default`), plus `readonly`, `hidden` and, for
`essence_arbre`, `labels` (code to label).

## Usage

``` r
schema_inventaire_video(couche = NULL)
```

## Arguments

- couche:

  Character or `NULL`. A layer name (`"placettes"`, `"centres_mesures"`,
  `"cibles"`, `"arbres"`, `"detections"`, `"houppiers"`, and the
  read-only `"parcelles"`, `"ugf"` and `"projet"` of schema 1.2.0;
  `"projet"` has no geometry). `NULL` (default) returns every layer.

## Value

For one layer, a list of field descriptors with the attributes
`geometrie`, `index_spatial` and `lecture_seule`. Without `couche`, a
named list of those, with the attributes `version`, `crs`, `domaines`
and `rasters`.

## Lifecycle

Experimental (spec 061).

## Examples

``` r
arbres <- schema_inventaire_video("arbres")
vapply(arbres, `[[`, character(1), "name")
#>  [1] "plot_id"        "tree_id"        "espece"         "dbh_cm"        
#>  [5] "h_m"            "statut"         "qualite"        "photos"        
#>  [9] "notes"          "uuid"           "num_provisoire" "azimut"        
#> [13] "distance_m"     "essence_arbre"  "h_source"       "houppier_id"   
#> [17] "etat_detection" "methode"       
attr(arbres, "index_spatial")  # FALSE
#> [1] FALSE
```
