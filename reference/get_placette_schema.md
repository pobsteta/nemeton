# Get the placette layer schema

Returns the ordered list of field descriptors for the `placette` layer.
Each entry is a list with `name`, `type`, `widget`, `qgis_widget`,
`label`, `domain`, `required`, `min`, `max`, `default`.

## Usage

``` r
get_placette_schema()
```

## Value

A list of field descriptors.

## Examples

``` r
schema <- get_placette_schema()
vapply(schema, `[[`, character(1), "name")
#>  [1] "plot_id"          "visit_order"      "type"             "date_visite"     
#>  [5] "observateur"      "pente_pct"        "exposition"       "recouvrement_pct"
#>  [9] "photos"           "notes"           
```
