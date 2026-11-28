# Costed options per unit: keep, intervene, convert (spec 072, `actions.md`)

For each eligible unit (not signal only, and either under the decision
threshold, or marked by a hazard above `seuil_alea`, or concentrating),
builds at most three options. Each option carries `p4_net_apres`,
**recomputed by
[`indicateur_p4_rendement_net()`](https://pobsteta.github.io/nemeton/reference/indicateur_p4_rendement_net.md)**
on inputs modified by the rules (points added to the score of the
dominant hazard, share of the capital harvested, gain factor), its
qualitative effects `+`, `0`, `-` on the axes, and the mark of dominated
options (at least as good on `p4_net_apres` and on every axis, strictly
better on one).

## Usage

``` r
p4_options(
  ugf_p4,
  regles = NULL,
  ruine = NULL,
  axes = c("B", "N"),
  axes_proteges_profil = NULL,
  parametres = NULL,
  id_field = NULL,
  vocation_field = "vocation",
  capital_field = "capital",
  gain_field = "gain_valeur",
  perte_saisie_field = "perte_saisie",
  garde_profil = NULL
)
```

## Arguments

- ugf_p4:

  Output of
  [`indicateur_p4_rendement_net()`](https://pobsteta.github.io/nemeton/reference/indicateur_p4_rendement_net.md)
  (with its input columns: vocation, capital, gain, `R*_norm`, area).

- regles:

  Rules, default
  [`p4_regles_actions()`](https://pobsteta.github.io/nemeton/reference/p4_regles_actions.md).

- ruine:

  Output of
  [`p4_ruine_foret()`](https://pobsteta.github.io/nemeton/reference/p4_ruine_foret.md),
  or `NULL`.

- axes:

  Columns of `ugf_p4` (family columns such as `famille_biodiversite`, or
  family letters) whose effects are reported.

- axes_proteges_profil:

  Family letters protected by the actor profile (added to those of the
  vocation).

- parametres:

  P4 parameters, default
  [`p4_parametres()`](https://pobsteta.github.io/nemeton/reference/p4_parametres.md).

- id_field, vocation_field, capital_field, gain_field,
  perte_saisie_field:

  Column names, as in
  [`indicateur_p4_rendement_net()`](https://pobsteta.github.io/nemeton/reference/indicateur_p4_rendement_net.md).

- garde_profil:

  `NULL` or a function of the option table returning one logical per row
  (`TRUE` = keep); guard 3, supplied by the application.

## Value

A data frame, one row per unit and option: `ugf`, `option`, `libelle`,
`tableau`, `recolte`, `delta_score`, `prelevement_capital`,
`facteur_gain`, `p4_net_avant`, `p4_net_apres`, `delta_p4`,
`p4_ecart_apres`, `effet_<lettre>` for each axis,
`cout_indicatif_eur_ha` (`NA`: no cost parameter), `dominee`,
`dominee_par`, `statut` (`retenable`, `dominee`, `ecartee_axe_protege`,
`ecartee_profil`), `arbitrage_axes`, `garde`, `version_parametres`,
`version_regles` and `regles_provisoires`.

## Details

Guards, which are invariants of the code that no rules file can lower:
**1 vocation** (outside production and mixed, or for a unit to
capitalise, any option that harvests falls back on its `sans_recolte`
variant, so that `recolte` holds exactly when `prelevement_capital > 0`
and the tableau is `coupes`) and **4 precision** (NDP floor of 3), **5
extent** (the harvest is capped by `prelevement_max_part_capital`, never
a clear-cut), **2 protected axes** (an option rated `-` on an axis
protected by the vocation or by `axes_proteges_profil` is
`ecartee_axe_protege`, or, with `axes_proteges_mode: arbitrage`, kept
with the axes listed in `arbitrage_axes`), **3** through `garde_profil`.
The option `conserver` is the reference status quo: it is always
presented, and marked `dominee = TRUE` when it is dominated, but never
discarded. The effects are expert hypotheses, never measures. The gain
on the dominant hazard is added to every score the hazard reads
(`R3_norm` and `R5_norm` for the drought and health hazard), so it
raises the minimum; it has no effect on a unit with `perte_saisie` (its
entered loss is kept) or on a score already at 100. Lowering the capital
raises the gross yield without counting the income of the harvest (model
hypothesis, to be reviewed).

## Examples

``` r
u <- data.frame(vocation = "production", capital = 11000, gain_valeur = 380,
                surface_ha = 6, R1_norm = 75, R2_norm = 30, R3_norm = 20, R4_norm = 85,
                B = 30, N = 20)
u <- suppressMessages(indicateur_p4_rendement_net(u, ndp = 3))
p4_options(u)[, c("option", "p4_net_apres", "statut")]
#>       option p4_net_apres    statut
#> 1  conserver   0.01564545 retenable
#> 2 intervenir   0.01953232 retenable
#> 3  convertir   0.01588182 retenable
```
