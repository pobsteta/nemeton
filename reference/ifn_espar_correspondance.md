# Species-code correspondence across the project's three nomenclatures

Bridge table between the IFN's own species codes (`espar`, e.g. `"09"`),
the four-letter codes used by
[`indicateur_p1_volume`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md)
(e.g. `"FASY"`) and the snake-case codes of
[`european_species_tolerances`](https://pobsteta.github.io/nemeton/reference/european_species_tolerances.md)
(e.g. `"fagus_sylvatica"`). The Latin binomial is the pivot.

## Usage

``` r
ifn_espar_correspondance(espar = NULL, code_p1 = NULL)
```

## Arguments

- espar:

  Optional filter on the IFN code.

- code_p1:

  Optional filter on the four-letter code.

## Value

A data.frame with `espar`, `lib_espar`, `espece_sci`, `code_p1`,
`code_tolerances`, `millesime`, `source`.

## Coverage is uneven, by construction

Every `espar` has a Latin name, so `code_tolerances` resolves for most
rows. `code_p1` resolves only for the species present in
`ifn_volume_equations.csv` — a short list, since P1 falls back to
genus-level equations for anything else. A `NA` in `code_p1` is
therefore normal and means "no species-specific IFN tarif", not "unknown
species".

Matching is done on the Latin binomial, and also on the **autonym** when
the IGN reference descends to infraspecific rank (*Picea abies* subsp.
*abies*). Where no autonym exists — *Pinus nigra* is published only as
varieties — the row is left `NA` rather than assigned an arbitrary
variety.

## See also

[`resoudre_espar`](https://pobsteta.github.io/nemeton/reference/resoudre_espar.md)
to convert a vector of codes.

## Examples

``` r
if (FALSE) { # \dontrun{
ifn_espar_correspondance(espar = "09")
} # }
```
