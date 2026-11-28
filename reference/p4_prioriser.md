# Deterministic priority of the units (spec 072, `actions.md`, brief B5)

    manque_a_gagner = max(0, -ecart - seuil) * capital * surface      EUR/yr
    priorite        = manque_a_gagner * confiance_ndp

## Usage

``` r
p4_prioriser(
  ugf_p4,
  pareto = NULL,
  ruine = NULL,
  parametres = NULL,
  id_field = NULL,
  capital_field = "capital",
  surface_field = "surface_ha"
)
```

## Arguments

- ugf_p4:

  Output of
  [`indicateur_p4_rendement_net()`](https://pobsteta.github.io/nemeton/reference/indicateur_p4_rendement_net.md).

- pareto:

  Output of
  [`p4_pareto()`](https://pobsteta.github.io/nemeton/reference/p4_pareto.md)
  or one status per unit.

- ruine:

  Output of
  [`p4_ruine_foret()`](https://pobsteta.github.io/nemeton/reference/p4_ruine_foret.md),
  or `NULL`.

- parametres:

  P4 parameters, default
  [`p4_parametres()`](https://pobsteta.github.io/nemeton/reference/p4_parametres.md).

- id_field, capital_field, surface_field:

  Column names (default: row position, `capital`, `surface_ha`; the area
  of an `sf` object is used when `surface_field` is absent).

## Value

A list: `ugf` (all units: `manque_a_gagner_eur_an`, `confiance_ndp`,
`priorite`, `rang`, `dominee`, `signal_seulement`, `concentrante`),
`principale` (ranked units), `concentrantes` and `acquisitions`.

## Details

`seuil` is `seuil_decision` of the P4 parameters and `confiance_ndp` the
Fibonacci confidence of the NDP
([`get_ndp_confidence()`](https://pobsteta.github.io/nemeton/reference/get_ndp_confidence.md)).
Units are ranked by decreasing `priorite`; at equal priority a dominated
unit comes first. Three lists are returned apart, because they answer
different questions: the main ranking (decision-grade units only, `rang`
from 1), the concentrating units of a hazard above the exposure cap (by
decreasing disaster loss), and the data acquisitions of the signal-only
units (first those whose P4 decision is to harvest, since they condition
a harvest decision). The ranking is not meant to be changed by a
language model.

## Examples

``` r
u <- data.frame(vocation = "production", capital = 11000, gain_valeur = 380,
                surface_ha = 6, R1_norm = 75, R2_norm = 30, R3_norm = 20, R4_norm = 85)
u <- suppressMessages(indicateur_p4_rendement_net(u, ndp = 3))
p4_prioriser(u)$principale[, c("ugf", "manque_a_gagner_eur_an", "rang")]
#>   ugf manque_a_gagner_eur_an rang
#> 1   1                  617.4    1
```
