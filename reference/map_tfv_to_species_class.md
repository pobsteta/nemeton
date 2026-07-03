# Map BD Forêt v2 TFV codes to NMT species classes

Translate BD Forêt v2 vegetation-formation-type (TFV) codes into the
corresponding NMT species class
([`list_species_classes`](https://pobsteta.github.io/nemeton/reference/list_species_classes.md)),
via
[`bdforet_v2_mapping`](https://pobsteta.github.io/nemeton/reference/bdforet_v2_mapping.md).
Named essences map to their class (e.g. `FF1-09-09` hêtre →
`essence_hetraie`); generic or mixed formations map to `essence_mixte`;
non-forest / no-canopy TFV (bare, moorland, grassland) return `NA`. Lets
the app pre-fill the reGénération target-species selector with the
classes actually present on a BD Forêt v2 coverage.

## Usage

``` r
map_tfv_to_species_class(tfv_code, mapping = NULL)
```

## Arguments

- tfv_code:

  Character vector of TFV codes.

- mapping:

  Optional override table (as returned by
  [`bdforet_v2_mapping`](https://pobsteta.github.io/nemeton/reference/bdforet_v2_mapping.md)).

## Value

Character vector of species-class codes (same length as `tfv_code`),
`NA` where the TFV has no forest species class or is unknown.

## See also

[`bdforet_v2_mapping`](https://pobsteta.github.io/nemeton/reference/bdforet_v2_mapping.md),
[`regen_species_choices`](https://pobsteta.github.io/nemeton/reference/regen_species_choices.md),
[`map_bdforet_essence`](https://pobsteta.github.io/nemeton/reference/map_bdforet_essence.md)
