# Structured context for the language-model stage (spec 072, brief B7)

Builds, per unit, the object the application hands to the LLM: the P4
diagnosis, the Pareto status and its dominating units, the priority, the
candidate action identifiers and the non-dominated options with their
`p4_net_apres` and qualitative effects. **No free text coming from
external data**: only numbers, fixed identifiers of the rules, the
closed lists of vocations, decisions and hazards, and the unit
identifier, which is replaced by `ugf_<n>` (`n` = row position)
**always**, also in `dominee_par`; the true identifiers are returned
apart in the attribute `correspondance` (data frame `ugf_contexte`,
`ugf`). Missing pieces (`priorisation`, `candidates`, `options`) are
computed with the functions of the same family.

## Usage

``` r
p4_contexte_llm(
  ugf_p4,
  pareto = NULL,
  ruine = NULL,
  regles = NULL,
  axes = c("B", "N"),
  axes_proteges_profil = NULL,
  parametres = NULL,
  id_field = NULL,
  vocation_field = "vocation",
  priorisation = NULL,
  candidates = NULL,
  options = NULL,
  garde_profil = NULL
)
```

## Arguments

- ugf_p4:

  Output of
  [`indicateur_p4_rendement_net()`](https://pobsteta.github.io/nemeton/reference/indicateur_p4_rendement_net.md)
  (with its input columns: vocation, capital, gain, `R*_norm`, area).

- pareto:

  Output of
  [`p4_pareto()`](https://pobsteta.github.io/nemeton/reference/p4_pareto.md)
  or one status per unit.

- ruine:

  Output of
  [`p4_ruine_foret()`](https://pobsteta.github.io/nemeton/reference/p4_ruine_foret.md),
  or `NULL`.

- regles:

  Rules, default
  [`p4_regles_actions()`](https://pobsteta.github.io/nemeton/reference/p4_regles_actions.md).

- axes:

  Columns of `ugf_p4` (family columns such as `famille_biodiversite`, or
  family letters) whose effects are reported.

- axes_proteges_profil:

  Family letters protected by the actor profile (added to those of the
  vocation).

- parametres:

  P4 parameters, default
  [`p4_parametres()`](https://pobsteta.github.io/nemeton/reference/p4_parametres.md).

- id_field:

  Unit identifier column (default: row position). Never sent to the LLM:
  units are renamed `ugf_<n>`.

- vocation_field:

  Vocation column.

- priorisation, candidates, options:

  Outputs of
  [`p4_prioriser()`](https://pobsteta.github.io/nemeton/reference/p4_prioriser.md),
  [`p4_actions_candidates()`](https://pobsteta.github.io/nemeton/reference/p4_actions_candidates.md)
  and
  [`p4_options()`](https://pobsteta.github.io/nemeton/reference/p4_options.md);
  computed when `NULL`.

- garde_profil:

  Passed to
  [`p4_actions_candidates()`](https://pobsteta.github.io/nemeton/reference/p4_actions_candidates.md)
  and
  [`p4_options()`](https://pobsteta.github.io/nemeton/reference/p4_options.md)
  when those are computed here.

## Value

An unnamed list with one element per unit (`ugf`, `vocation`, `p4`,
`pareto`, `priorite`, `concentrante`, `actions`, `options`, `regles`),
with the attribute `correspondance`.

## Examples

``` r
u <- data.frame(vocation = "production", capital = 11000, gain_valeur = 380,
                surface_ha = 6, R1_norm = 75, R2_norm = 30, R3_norm = 20, R4_norm = 85,
                B = 30, N = 20)
u <- suppressMessages(indicateur_p4_rendement_net(u, ndp = 3))
str(p4_contexte_llm(u)[[1]]$p4)
#> List of 9
#>  $ rendement_brut  : num 0.0345
#>  $ pertes_attendues: num 0.0189
#>  $ rendement_net   : num 0.0156
#>  $ taux_exige      : num 0.03
#>  $ ecart           : num -0.0144
#>  $ decision        : chr "recolter"
#>  $ alea_dominant   : chr "secheresse_sanitaire"
#>  $ ndp             : num 3
#>  $ signal_seulement: logi FALSE
```
