# IFN Schaeffer tariff numbers by species and ecoregion

Reads `inst/extdata/ifn_tarif_schaeffer_ser.csv`, built by
`data-raw/build_ifn_tarifs_schaeffer.R` with
[`calculer_tarifs_schaeffer`](https://pobsteta.github.io/nemeton/reference/calculer_tarifs_schaeffer.md)
over the latest IFN campaigns: one row per level (`SER`, `GRECO`,
`FRANCE` with code `FR`) x species x tariff type, every group of 3 trees
or more, without threshold (the format Marculus embeds). `cv` is in
percent.

## Usage

``` r
ifn_tarif_schaeffer_ser(espar = NULL, code = NULL, niveau = NULL, type = NULL)
```

## Arguments

- espar:

  Optional IFN species codes (any form accepted by
  [`resoudre_espar`](https://pobsteta.github.io/nemeton/reference/resoudre_espar.md)).

- code:

  Optional SER / GRECO codes, or `"FR"`.

- niveau:

  Optional levels among `"SER"`, `"GRECO"`, `"FRANCE"`.

- type:

  Optional tariff types.

## Value

A data.frame `niveau`, `code`, `espar`, `essence_libelle`, `type`,
`numero`, `n_arbres`, `cv`, `millesime`, `part_houppier` (crown share of
the merchantable wood, percent, EMERGE model, see
[`calculer_tarifs_schaeffer`](https://pobsteta.github.io/nemeton/reference/calculer_tarifs_schaeffer.md)).

## Details

The numbers are a \*\*default\*\* for the marker, not a prescription:
they describe the trees the IFN measured.

## Lifecycle

Experimental (spec 062).

## Examples

``` r
ifn_tarif_schaeffer_ser(espar = "09", code = "C20", type = "SCHL")
#>   niveau code espar essence_libelle type numero n_arbres   cv millesime
#> 1    SER  C20    09           Hêtre SCHL    8.5     7056 38.7 2011-2025
#>   part_houppier
#> 1          12.6
```
