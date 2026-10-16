# Reference Schaeffer tariff number of a species (SER, GRECO, France)

Cascade SER -\> GRECO -\> France over
[`ifn_tarif_schaeffer_ser`](https://pobsteta.github.io/nemeton/reference/ifn_tarif_schaeffer_ser.md):
the first level where the species has at least `min_arbres` trees.
`type_conseille` is the type with the lowest coefficient of variation at
that level.

## Usage

``` r
ifn_tarif_schaeffer_reference(espar, ser = NULL, type = NULL, min_arbres = 30)
```

## Arguments

- espar:

  Species codes (any form accepted by
  [`resoudre_espar`](https://pobsteta.github.io/nemeton/reference/resoudre_espar.md)).

- ser:

  Optional SER code (its GRECO is its first letter). `NULL` goes
  straight to France.

- type:

  Optional tariff type; `NULL` returns the four.

- min_arbres:

  Minimal number of trees of a level. Default 30, the threshold Marculus
  applies to the same table.

## Value

A data.frame `espar`, `essence_libelle`, `type`, `numero`, `cv`,
`n_arbres`, `niveau_utilise`, `code`, `type_conseille`; `NA` where no
level qualifies.

## Lifecycle

Experimental (spec 062).

## Examples

``` r
ifn_tarif_schaeffer_reference(c("Chêne sessile", "09"), ser = "C20", type = "SCHL")
#>   espar essence_libelle type numero   cv n_arbres niveau_utilise code
#> 1    03   Chêne sessile SCHL    7.8 40.1     8746            SER  C20
#> 2    09           Hêtre SCHL    8.5 38.7     7056            SER  C20
#>   type_conseille
#> 1           SCHI
#> 2           SCHL
```
