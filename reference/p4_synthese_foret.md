# P4 summary at forest scale (spec 072, section 7)

P4 summary at forest scale (spec 072, section 7)

## Usage

``` r
p4_synthese_foret(
  units,
  capital_field = "capital",
  surface_field = "surface_ha",
  parametres = NULL
)
```

## Arguments

- units:

  Output of
  [`indicateur_p4_rendement_net()`](https://pobsteta.github.io/nemeton/reference/indicateur_p4_rendement_net.md).

- capital_field, surface_field:

  Capital (EUR/ha) and area (ha) columns; without `surface_field`, the
  area of an `sf` object is used.

- parametres:

  Parameter list; default
  [`p4_parametres()`](https://pobsteta.github.io/nemeton/reference/p4_parametres.md).

## Value

A list: `rendement_net_foret`, `part_capital_ecart_negatif`,
`pertes_attendues_eur_an`, `alea_dominant_foret`, `capital_total_eur`
and `gain_net_eur_an`. Units with a missing P4 are left out of every sum
(with a warning).

## Examples

``` r
u <- data.frame(vocation = "production", capital = 14000, gain_valeur = 750,
                surface_ha = 12, R1_norm = 70, R2_norm = 40, R3_norm = 45, R4_norm = 80)
p4_synthese_foret(indicateur_p4_rendement_net(u))$rendement_net_foret
#> NDP of the P4 inputs unknown: p4_signal_seulement set to "TRUE".
#> [1] 0.03817143
```
