# Candidate actions per unit from the P4 diagnosis (spec 072, `actions.md`)

Stage 2 of the P4-driven action plan, deterministic and LLM-free. For
each unit, applies the rules of
[`p4_regles_actions()`](https://pobsteta.github.io/nemeton/reference/p4_regles_actions.md):

- **signal only** (P4 below the minimum NDP, or `p4_signal_seulement`):
  a single data-acquisition action, nothing else (guard 4);

- otherwise the rule of the P4 decision and Pareto status, one rule per
  hazard whose expected loss exceeds `seuil_alea`, and the exposure
  reduction rule for a concentrating unit of a hazard above the exposure
  cap.

## Usage

``` r
p4_actions_candidates(
  ugf_p4,
  pareto = NULL,
  ruine = NULL,
  regles = NULL,
  parametres = NULL,
  id_field = NULL,
  vocation_field = "vocation",
  garde_profil = NULL
)
```

## Arguments

- ugf_p4:

  Output of
  [`indicateur_p4_rendement_net()`](https://pobsteta.github.io/nemeton/reference/indicateur_p4_rendement_net.md).

- pareto:

  Output of
  [`p4_pareto()`](https://pobsteta.github.io/nemeton/reference/p4_pareto.md),
  or one status (`domine` / `non_domine` / `NA`) per unit. An unknown
  status is treated as `non_domine` (no automatic harvest).

- ruine:

  Output of
  [`p4_ruine_foret()`](https://pobsteta.github.io/nemeton/reference/p4_ruine_foret.md)
  (same `id_field` convention), or `NULL`.

- regles:

  Rules, default
  [`p4_regles_actions()`](https://pobsteta.github.io/nemeton/reference/p4_regles_actions.md).

- parametres:

  P4 parameters, default
  [`p4_parametres()`](https://pobsteta.github.io/nemeton/reference/p4_parametres.md)
  (only their version is recorded).

- id_field:

  Unit identifier column (default: row position, as in
  [`p4_ruine_foret()`](https://pobsteta.github.io/nemeton/reference/p4_ruine_foret.md)).

- vocation_field:

  Vocation column.

- garde_profil:

  `NULL`, or a function receiving the candidate table and returning one
  logical per row (`TRUE` = keep): guard 3, supplied by the application
  from the thresholds of the actor profiles.

## Value

A data frame, one row per unit and action: `ugf`, `action_id`, `regle`,
`origine` (`decision`, `alea`, `concentrante`, `signal`), `alea`,
`tableau` (`coupes`, `travaux`, `aucun`), `recolte`, `libelle`, the P4
values used (`p4_rendement_net`, `p4_ecart`, `p4_decision`, `p4_ndp`,
`p4_signal_seulement`, `pareto_statut`, `perte_alea`),
`version_parametres`, `version_regles`, `regles_provisoires` and
`prelevement_max_part_capital` (the bound of the rules file carried by
every harvesting action, guard 5). Attribute `ecartees`: the removed
candidates with their `garde`.

## Details

Guards (brief B6): **1 vocation** (no harvest outside the vocations of
`vocations_recolte`), **4 precision**, **6 traceability** (each action
keeps its rule, the P4 values used and the versions of parameters and
rules). Guard 2 (protected axes) and guard 5 (extent bounds) act on the
options, see
[`p4_options()`](https://pobsteta.github.io/nemeton/reference/p4_options.md).
Guard 3 (alert thresholds of the actor profiles) lives in the
application: it is exposed as `garde_profil`. Removed candidates are not
lost: they are kept, with the guard that removed them, in the attribute
`ecartees`.

## Examples

``` r
u <- data.frame(vocation = "production", capital = 14000, gain_valeur = 750,
                surface_ha = 12, R1_norm = 70, R2_norm = 40, R3_norm = 45, R4_norm = 80)
u <- suppressMessages(indicateur_p4_rendement_net(u, ndp = 3))
p4_actions_candidates(u)[, c("action_id", "regle", "tableau")]
#>                             action_id        regle tableau
#> 1  pas_de_coupe_au_dela_accroissement           D1 travaux
#> 2        eclaircie_precoce_rapport_hd    A_tempete  coupes
#> 3                 traitement_lisieres    A_tempete travaux
#> 4 recolte_anticipee_peuplements_hauts    A_tempete  coupes
#> 5            diversification_essences A_secheresse travaux
#> 6                   recolte_sanitaire A_secheresse  coupes
#> 7             suivi_sanitaire_spec008 A_secheresse travaux
#> 8                  adaptation_densite A_secheresse  coupes
```
