# Convert a schema to a tidy data.frame

Helper used by exporters and tests. Drops attachment-only fields (those
whose name starts with a dot).

## Usage

``` r
schema_to_df(schema)
```

## Arguments

- schema:

  A list returned by
  [`get_placette_schema`](https://pobsteta.github.io/nemeton/reference/get_placette_schema.md)
  or
  [`get_arbre_schema`](https://pobsteta.github.io/nemeton/reference/get_arbre_schema.md).

## Value

A data.frame with one row per visible field.

## Examples

``` r
schema_to_df(get_placette_schema())
#>                name      type           widget            label required
#> 1           plot_id character         TextEdit          Plot ID     TRUE
#> 2       visit_order   integer            Range      Visit order    FALSE
#> 3              type character         ValueMap    Sampling type    FALSE
#> 4       date_visite  datetime         DateTime       Visit date    FALSE
#> 5       observateur character         TextEdit         Observer    FALSE
#> 6         pente_pct    double            Range        Slope (%)    FALSE
#> 7        exposition character         ValueMap           Aspect    FALSE
#> 8  recouvrement_pct    double            Range Canopy cover (%)    FALSE
#> 9            photos character ExternalResource           Photos    FALSE
#> 10            notes character         TextEdit            Notes    FALSE
```
