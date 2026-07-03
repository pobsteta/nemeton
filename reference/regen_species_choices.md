# Species choices for the reGénération target-species selector

Build the list of **scorable** target species for the optional
per-species tuning of
[`indice_priorite_regen`](https://pobsteta.github.io/nemeton/reference/indice_priorite_regen.md),
ready for the app's "target species" dropdown. The options are exactly
the classes the core can score — the intersection of
[`regeneration_tolerances`](https://pobsteta.github.io/nemeton/reference/regeneration_tolerances.md)
and
[`list_species_classes`](https://pobsteta.github.io/nemeton/reference/list_species_classes.md)
— so the selector can never offer a species the index ignores.

## Usage

``` r
regen_species_choices(units = NULL, species_col = NULL, region = "BFC",
  lang = "fr")
```

## Arguments

- units:

  Optional `sf`/data.frame of units. Used only to flag the species
  present on the parcels.

- species_col:

  Optional name of the column holding the species-class codes
  ([`list_species_classes`](https://pobsteta.github.io/nemeton/reference/list_species_classes.md)
  codes). Auto-detected among `essence_dominante`, `essence`,
  `species_class`, `classe_essence`, `species` when `NULL`. Values must
  be class codes (e.g. `essence_hetraie`), not BD Forêt codes — map them
  upstream with `map_bdforet_to_species_class` if needed.

- region, lang:

  Passed to
  [`list_species_classes`](https://pobsteta.github.io/nemeton/reference/list_species_classes.md)
  for localised labels.

## Value

A data.frame with `code`, `label`, `tmax_tol_c`, `vpd_tol_kpa`,
`present` (logical) and `groupe` (`"present"` / `"adaptation"`), ordered
present-first then by increasing `tmax_tol_c`.

## Details

When `units` are given, the classes actually present on the parcels are
flagged (`present = TRUE`, `groupe = "present"`) and listed first; the
remaining classes (`groupe = "adaptation"`) follow. Within each group,
species are ordered by increasing heat tolerance (`tmax_tol_c`), so the
adaptation group reads as "more heat-tolerant alternatives". The generic
"no species" default is added by the app (it maps to `species = NULL`).

## See also

[`indice_priorite_regen`](https://pobsteta.github.io/nemeton/reference/indice_priorite_regen.md),
[`regeneration_tolerances`](https://pobsteta.github.io/nemeton/reference/regeneration_tolerances.md),
[`list_species_classes`](https://pobsteta.github.io/nemeton/reference/list_species_classes.md)
