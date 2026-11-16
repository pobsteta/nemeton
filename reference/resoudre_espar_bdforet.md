# ESPAR code of a BD Forêt essence label

Resolves a BD Forêt v2 essence label to an IFN ESPAR code, including the
**group** labels that
[`resoudre_espar()`](https://pobsteta.github.io/nemeton/reference/resoudre_espar.md)
leaves unresolved because they name several species ("Chênes décidus",
"Pin laricio, pin noir", "Sapin, épicéa", "Mélèze", "Peuplier"…). A
group label takes its member with the largest IFN standing volume per
hectare (`vol_ha_maille` of `ifn_volume_essence_ser.csv`) in the unit's
SER; failing that (no SER, or no member measured there), in the SER's
GRECO; failing that, in France. Single-species labels take their code;
generic labels ("Feuillus", "Conifères", "Mixte", "Pins mélangés", "NC",
"NR"…) give `NA`: no code is guessed. A label absent from the table
falls back to
[`resoudre_espar()`](https://pobsteta.github.io/nemeton/reference/resoudre_espar.md).

The groups are listed in `inst/extdata/bdforet_essence_espar.csv`. For
"Sapin, épicéa" the rule gives silver fir (61) in France, as the former
application convention.

## Usage

``` r
resoudre_espar_bdforet(libelle, ser = NULL)
```

## Arguments

- libelle:

  Character vector of BD Forêt essence labels (accents and case
  ignored).

- ser:

  Optional character vector of SER codes (e.g. `"C30"`), recycled to the
  length of `libelle`. `NULL` or `NA`: France-wide rule.

## Value

A character vector of ESPAR codes, `NA` when unresolved.

## Lifecycle

Experimental: may change in any release, without deprecation (spec 057).

## See also

[`resoudre_espar()`](https://pobsteta.github.io/nemeton/reference/resoudre_espar.md),
[`indicateur_t4_vitalite()`](https://pobsteta.github.io/nemeton/reference/indicateur_t4_vitalite.md)

## Examples

``` r
resoudre_espar_bdforet(c("Hêtre", "Sapin, épicéa", "Feuillus"))
#> [1] "09" "61" NA  
resoudre_espar_bdforet("Chênes décidus", ser = "C30")
#> [1] "03"
```
