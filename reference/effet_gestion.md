# Effects of management estimated from the project's own units

Estimates, for each unit and each family index (or indicator), the
effect of the declared management type compared with a reference type,
from the units of the project themselves: a T- or X-learner (Kunzel et
al. 2019) fitted on covariates that describe the site (P2, altitude,
slope, SER). The overlap between treated and reference units is checked
on a propensity score; units outside the common support are left out,
and the function refuses to conclude when too few units are comparable
(spec 068, chantier D, step 1). It needs no simulation model: it says
what management has produced on this massif, so that a simulation can
later be confronted with it.

## Usage

``` r
effet_gestion(
  units,
  traitement = "type_sylviculture",
  resultats = NULL,
  covariables = c("P2", "altitude", "pente", "ser"),
  reference = NULL,
  methode = c("x_learner", "t_learner"),
  support_min = 0.7,
  min_par_traitement = 10L,
  n_boot = 50L,
  graine = 1L
)
```

## Arguments

- units:

  sf or data.frame of units.

- traitement:

  Character. Column holding the declared management type (e.g.
  `"type_sylviculture"`, or the `itineraire_actuel` of spec 065).
  Default `"type_sylviculture"`.

- resultats:

  Character. Outcome columns. `NULL` (default): the family indices
  present (`famille_*`).

- covariables:

  Character. Site covariates. Only those present in `units` are used; at
  least one is required. Default `c("P2", "altitude", "pente", "ser")`.

- reference:

  Character. Reference level of `traitement`. `NULL`: the most frequent
  level.

- methode:

  `"x_learner"` (default) or `"t_learner"`.

- support_min:

  Numeric in `[0, 1]`. Minimum share of the units of a contrast that
  must lie in the common support; below it the contrast is refused
  (`recouvrement_insuffisant`). Default 0.7 (spec 068, D-4).

- min_par_traitement:

  Integer. Minimum number of units per level in a contrast; below it,
  `trop_peu_unites`. Default 10 (D-4).

- n_boot:

  Integer. Bootstrap replicates for the intervals. Default 50.

- graine:

  Integer. Random seed. Default 1.

## Value

A list of class `"effet_gestion"`:

- resume:

  one row per contrast (`traitement` against `reference`) and outcome:
  `traitement`, `reference`, `resultat`, `n_traite`, `n_reference`,
  `part_support`, `effet_moyen` (doubly robust, AIPW, mean effect over
  the units in the support), `ic_bas`, `ic_haut` (90 % interval from its
  influence function), `statut` (`calcule`, `recouvrement_insuffisant`,
  `trop_peu_unites`).

- unites:

  one row per unit of a computed contrast and outcome: `unite` (row
  number), `traitement`, `resultat`, `effet` (individual effect from the
  T- or X-learner), `ic_bas`, `ic_haut` (bootstrap 5-95 % quantiles,
  indicative), `support`; `NA` outside the support.

- reference, methode, apprenant, covariables:

  what was used; `apprenant` is `"ranger"` when installed, else `"lm"`.

## Details

**Learners.** T-learner: one outcome model per group, the effect is the
difference of their predictions. X-learner: the effects imputed in each
group are modelled in turn and mixed by the propensity score, which
suits unbalanced groups (Kunzel et al. 2019). Outcome models are random
forests (ranger) when installed, else linear models.

**Mean effect.** The summary uses an augmented inverse-probability
weighting estimator (AIPW, doubly robust) on the units in the support,
with out-of-bag predictions of the outcome models; `methode` only
changes the individual effects. On simulated data (150 units, effect 8,
strong confounding by P2, 30 draws), the naive difference of means gave
18.5, the AIPW estimate 7.1 on average, and its 90 % interval covered
the true value 93 % of the time: a small downward bias remains with
forests.

**Support.** Propensity score by logistic regression on the covariates;
a unit is in the common support when its score lies within the range
shared by both groups and within `[0.05, 0.95]`.

**What it is not** (fiche): an association adjusted for the covariates,
not a causal effect unless every confounder is among them; a declared
management type is not necessarily the one applied; with few units per
type the intervals are wide. Results enter the AI perspectives as
results of the project, cited as such.

## Lifecycle

Experimental (spec 068): may change in any release.

## References

Kunzel, S. R., Sekhon, J. S., Bickel, P. J. & Yu, B. (2019).
Metalearners for estimating heterogeneous treatment effects using
machine learning. *PNAS* 116(10), 4156-4165.

## See also

[`comparer_itineraires()`](https://pobsteta.github.io/nemeton/reference/comparer_itineraires.md)

## Examples

``` r
set.seed(1)
n <- 120
d <- data.frame(P2 = runif(n, 2, 10), altitude = runif(n, 200, 900))
d$type_sylviculture <- ifelse(runif(n) < plogis((d$P2 - 6) / 2), "irregulier", "regulier")
d$famille_biodiversite <- 40 + 3 * d$P2 + 8 * (d$type_sylviculture == "irregulier") + rnorm(n, 0, 3)
e <- effet_gestion(d, reference = "regulier", n_boot = 20)
e$resume
#>   traitement reference             resultat n_traite n_reference part_support
#> 1 irregulier  regulier famille_biodiversite       68          52          0.8
#>   effet_moyen   ic_bas  ic_haut  statut
#> 1    7.928485 6.329075 9.527895 calcule
```
