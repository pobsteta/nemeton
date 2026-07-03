# Species choices for the reGénération target-species selector

Build the option list for the app's "target species" dropdown, ready to
render. Two levels: `level = "species"` (default) lists the **FRM**
European species
([`european_species_tolerances`](https://pobsteta.github.io/nemeton/reference/european_species_tolerances.md),
`statut = "frm"`); `level = "class"` lists the 11 broad species classes
([`regeneration_tolerances`](https://pobsteta.github.io/nemeton/reference/regeneration_tolerances.md)
∩
[`list_species_classes`](https://pobsteta.github.io/nemeton/reference/list_species_classes.md)).

## Usage

``` r
regen_species_choices(units = NULL, species_col = NULL, tfv_col = NULL,
  level = c("species", "class"), include_atlas = FALSE, region = "BFC",
  lang = "fr")
```

## Arguments

- units:

  Optional `sf`/data.frame of units, to flag present species.

- species_col:

  Optional column holding species-class codes
  ([`list_species_classes`](https://pobsteta.github.io/nemeton/reference/list_species_classes.md)
  codes). Auto-detected among `essence_dominante`, `essence`,
  `species_class`, `classe_essence`, `species` when `NULL`.

- tfv_col:

  Optional column holding BD Forêt v2 TFV codes; mapped to classes via
  [`map_tfv_to_species_class`](https://pobsteta.github.io/nemeton/reference/map_tfv_to_species_class.md)
  (takes precedence over `species_col`).

- level:

  `"species"` (FRM European species, default) or `"class"` (11 broad
  classes).

- include_atlas:

  Logical; in `"species"` level, also list the JRC-Atlas species (folded
  `"atlas"` group). Default `FALSE`.

- region, lang:

  Passed to
  [`list_species_classes`](https://pobsteta.github.io/nemeton/reference/list_species_classes.md)
  for the class level and presence detection.

## Value

A data.frame of options, ordered present-first then by increasing
`tmax_tol_c`. Level `"species"` columns: `code`, `label`, `species_sci`,
`type`, `statut`, `species_class`, `tmax_tol_c`, `vpd_tol_kpa`,
`shade_tol`, `drought_tol`, `confidence`, `invasif`, `present`,
`groupe`. Level `"class"` columns: `code`, `label`, `tmax_tol_c`,
`vpd_tol_kpa`, `present`, `groupe`.

## Details

Either way the options are **scorable** by
[`indice_priorite_regen`](https://pobsteta.github.io/nemeton/reference/indice_priorite_regen.md)
(`species =` resolves both tables). When `units` are given, the entries
whose species class is present on the parcels are flagged
(`present = TRUE`, `groupe = "present"`) and listed first; presence is
read from a TFV column (`tfv_col`, via
[`map_tfv_to_species_class`](https://pobsteta.github.io/nemeton/reference/map_tfv_to_species_class.md))
or a species-class column. Remaining FRM entries form
`groupe = "adaptation"`; with `include_atlas = TRUE` the Atlas species
follow in a folded `"atlas"` group. Within each group, options are
ordered by increasing heat tolerance (`tmax_tol_c`). The generic "no
species" default is added by the app (`species = NULL`).

## See also

[`indice_priorite_regen`](https://pobsteta.github.io/nemeton/reference/indice_priorite_regen.md),
[`european_species_tolerances`](https://pobsteta.github.io/nemeton/reference/european_species_tolerances.md),
[`regeneration_tolerances`](https://pobsteta.github.io/nemeton/reference/regeneration_tolerances.md),
[`map_tfv_to_species_class`](https://pobsteta.github.io/nemeton/reference/map_tfv_to_species_class.md)
