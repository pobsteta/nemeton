# Ruin risk at forest scale (spec 072, section 7 bis)

Four measures that complete the expected net yield without entering
`P4`: loss in case of a major disaster (sum over units for a
`systemique` hazard, maximum for a `localisee` one), probability over
the horizon, concentration (share of the first unit and effective number
of units `1 / sum(part^2)`), and the geometric yield (column
`p4_rendement_geometrique` of
[`indicateur_p4_rendement_net()`](https://pobsteta.github.io/nemeton/reference/indicateur_p4_rendement_net.md)).

## Usage

``` r
p4_ruine_foret(
  units,
  capital_field = "capital",
  surface_field = "surface_ha",
  id_field = NULL,
  parametres = NULL
)
```

## Arguments

- units:

  Output of
  [`indicateur_p4_rendement_net()`](https://pobsteta.github.io/nemeton/reference/indicateur_p4_rendement_net.md)
  (needs the `R*_norm` columns).

- capital_field, surface_field:

  Capital (EUR/ha) and area (ha) columns.

- id_field:

  Optional unit identifier column (default: row position).

- parametres:

  Parameter list; default
  [`p4_parametres()`](https://pobsteta.github.io/nemeton/reference/p4_parametres.md).

## Value

A list: `aleas` (data frame, one row per hazard with
`perte_sinistre_eur`, `part_capital`, `annees_gain_net`,
`probabilite_horizon`, `premiere_ugf`, `part_premiere_ugf`,
`nombre_effectif`, `exposition_depassee`, `ugf_concentrante`),
`gain_net_eur_an`, `capital_total_eur`, `ugf_concentrantes`.

## Examples

``` r
u <- data.frame(vocation = "production", capital = 14000, gain_valeur = 750,
                surface_ha = 12, R1_norm = 70, R2_norm = 40, R3_norm = 45, R4_norm = 80)
p4_ruine_foret(indicateur_p4_rendement_net(u))$aleas$perte_sinistre_eur
#> NDP of the P4 inputs unknown: p4_signal_seulement set to "TRUE".
#> [1] 40320 50400 36960  3360
```
