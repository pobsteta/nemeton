# Rename legacy landscape (L) columns

Renames the two landscape columns that were retired in 0.176.0,
**without touching a single value**:

    indicateur_l2_fragmentation -> indicateur_l1_effet_lisiere   (sylvosphere)
    indicateur_l1_sylvosphere   -> indicateur_l2_morcellement    (fragmentation)

Both old names announced the opposite of what they carried – see spec
045. The `_norm` variants produced by
[`normalize_indicators`](https://pobsteta.github.io/nemeton/reference/normalize_indicators.md)
follow. Short-code columns (`L1`, `L2`) are left alone: they were
already paired correctly.

Call it once when reading a dataset computed before 0.176.0 (project
parquet, PostGIS table, cached GeoPackage). A dataset that carries
neither legacy column is returned unchanged, so the call is safe to keep
in a reading path.

## Usage

``` r
migrer_colonnes_l(data, quiet = FALSE)
```

## Arguments

- data:

  A `data.frame` or `sf` object holding indicator columns.

- quiet:

  Logical. `TRUE` silences the report of what was renamed. Default
  `FALSE`.

## Value

`data`, with the legacy columns renamed. Attributes, row order, geometry
and values are untouched.

## Conflicts

When a legacy column and its target both exist, the target is kept, the
legacy one is dropped, and a warning names both – an already migrated
dataset re-read alongside a stale export must not silently overwrite the
current values.

## See also

[`indicateur_l1_effet_lisiere`](https://pobsteta.github.io/nemeton/reference/indicateur_l1_effet_lisiere.md),
[`indicateur_l2_morcellement`](https://pobsteta.github.io/nemeton/reference/indicateur_l2_morcellement.md)

## Examples

``` r
old <- data.frame(
  id = 1:2,
  indicateur_l2_fragmentation = c(36.4, 34.5),
  indicateur_l1_sylvosphere = c(71.2, 68.0)
)
names(migrer_colonnes_l(old, quiet = TRUE))
#> [1] "id"                          "indicateur_l1_effet_lisiere"
#> [3] "indicateur_l2_morcellement" 
```
