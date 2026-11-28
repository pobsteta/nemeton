# P4 - net yield after hazards (spec 072)

Computes, per management unit (UGF), the yearly yield of the standing
capital net of the expected losses due to hazards, and compares it with
the yield required by the unit's vocation. It is a
**source-conditional** indicator of family P (like B4, R5, T3): without
a `vocation` column, or without capital and gain (given, or computable
from `P1`, `P2` and the prices of the parameter file), it returns `NA`
with `p4_status = "skipped_no_p4_source"` and existing projects keep
their family P score unchanged.

## Usage

``` r
indicateur_p4_rendement_net(
  units,
  layers = NULL,
  vocation_field = "vocation",
  capital_field = "capital",
  gain_field = "gain_valeur",
  perte_saisie_field = "perte_saisie",
  species_field = "species",
  parametres = NULL,
  ndp = NULL
)
```

## Arguments

- units:

  Data frame or `sf` of management units.

- layers:

  Ignored (dispatcher compatibility).

- vocation_field:

  Name of the declared vocation column.

- capital_field, gain_field:

  Columns holding the capital (EUR/ha) and the yearly value gain
  (EUR/ha/yr). When absent, computed from `P1` and `P2` with the prices
  of `parametres` (`p4_capital_gain` rules: no price gives `NA` and a
  warning; a `P2` that is a site index in metres is refused).

- perte_saisie_field:

  Optional column of entered expected loss (proportion/yr); replaces the
  computed losses.

- species_field:

  Species column used to look prices up.

- parametres:

  Parameter list; default
  [`p4_parametres()`](https://pobsteta.github.io/nemeton/reference/p4_parametres.md).

- ndp:

  Numeric vector, NDP of each input (the weakest is inherited); a `ndp`
  column of `units` is also honoured. Unknown means signal only.

## Value

`units` with `P4`, `P4_norm`, `p4_rendement_brut`, `p4_perte_<alea>`,
`p4_pertes_attendues`, `p4_rendement_geometrique`, `p4_taux_exige`,
`p4_ecart`, `p4_decision`, `p4_alea_dominant`, `p4_signal_seulement`,
`p4_ndp` and `p4_status`.

## Details

    rendement_brut   = gain_valeur / capital
    perte_i          = p_max_i * (1 - Ri_norm / 100) * part_perdue_i
    pertes_attendues = perte_saisie, or sum(perte_i)
    rendement_net    = rendement_brut - pertes_attendues
    ecart            = rendement_net - taux_exige[vocation]

The R scores are read in their **normalised** form (`R1_norm` ...
`R4_norm`, 0-100, high = good, spec 048). A raw column `Ri` (any of R1
to R5) without `Ri_norm` is refused (class `nemeton_p4_colonne_brute`).
When the raw column sits next to `Ri_norm`, the latter must equal
`normalize_indicator("Ri", Ri)` to 1e-6 on non-missing rows, otherwise
the call fails with class `nemeton_p4_norm_incoherent`: per-batch
[`normalize_indicators()`](https://pobsteta.github.io/nemeton/reference/normalize_indicators.md)
does not invert the risk scores (decision of 2026-11-28). The drought
and health hazard reads `min(R3_norm, R5_norm)` when `R5_norm` is
present.

## Lifecycle

Experimental: all economic parameters are provisional (spec 072).

## Examples

``` r
u <- data.frame(vocation = "production", capital = 14000, gain_valeur = 750,
                R1_norm = 70, R2_norm = 40, R3_norm = 45, R4_norm = 80)
indicateur_p4_rendement_net(u)$P4
#> NDP of the P4 inputs unknown: p4_signal_seulement set to "TRUE".
#> [1] 0.03817143
```
