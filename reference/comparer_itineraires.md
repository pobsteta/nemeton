# Compare silvicultural itineraries under an actor profile

Ranks the itineraries of each unit by the weighted sum of their expected
effects on the indicator families (`+` = 1, `0` = 0, `-` = -1), says
which families win and lose against a reference itinerary, flags the
Pareto front and carries the catalogue's citations (spec 065 § 5).

## Usage

``` r
comparer_itineraires(
  units,
  poids,
  catalogue = itineraires_catalogue(),
  admissibles = NULL,
  itineraires = NULL,
  reference = "statu_quo",
  col_actuel = "itineraire_actuel",
  protected_areas = NULL,
  trajectoires = NULL,
  horizon = NULL,
  tolerance = 0.05
)
```

## Arguments

- units:

  sf (or data frame) of units.

- poids:

  Named numeric vector of weights per family (`c(P = 3, B = 2)`), or the
  key of a profile of
  [`profils_poids()`](https://pobsteta.github.io/nemeton/reference/profils_poids.md).

- catalogue:

  Itineraries, from
  [`itineraires_catalogue()`](https://pobsteta.github.io/nemeton/reference/itineraires_catalogue.md).

- admissibles:

  Output of
  [`itineraires_admissibles()`](https://pobsteta.github.io/nemeton/reference/itineraires_admissibles.md).
  `NULL`: computed with the default columns (and `protected_areas`).

- itineraires:

  Optional character vector restricting the candidates.

- reference:

  `"statu_quo"`: the unit's declared itinerary (column `col_actuel`)
  when it is a candidate, else the best `score_global` (spec 065, D-6).
  Or the code of an itinerary.

- col_actuel:

  Column of the declared current itinerary.

- protected_areas:

  Passed to
  [`itineraires_admissibles()`](https://pobsteta.github.io/nemeton/reference/itineraires_admissibles.md).

- trajectoires:

  `NULL` (default): compare on the qualitative effects of the catalogue.
  Or the simulated trajectories of chantier D: the output of
  [`simuler_itineraire()`](https://pobsteta.github.io/nemeton/reference/simuler_itineraire.md),
  one call per itinerary bound with
  [`rbind()`](https://rdrr.io/r/base/cbind.html), with `volume = TRUE`
  and `carbone = TRUE` for the two families it carries (see Details).
  The rows of
  [`simuler_itineraire()`](https://pobsteta.github.io/nemeton/reference/simuler_itineraire.md)
  without management (`itineraire = "sans_gestion"`) are a candidate of
  every unit. Then `methode` becomes `"finn"` and `incertitude` numeric;
  the output columns do not change.

- horizon:

  Numeric or `NULL`. Year of the trajectories read with `trajectoires`.
  `NULL`: the longest horizon simulated for every itinerary.

- tolerance:

  Numeric. With `trajectoires`, a family is won or lost against the
  reference only when the values differ by more than this share of the
  reference value (FINN trajectories are stochastic means), and an
  itinerary leaves the Pareto front only when another one beats it by
  more than this share on a family without losing more than this share
  on any. Default 0.05, a convention.

## Value

A data frame, one row per unit x candidate itinerary: `unit_id`,
`itineraire`, `score_global` (in `[-1, 1]`, `NA` if an evaluated family
has an unknown effect `?` for that itinerary), `rang` (1 = best within
the unit), `pareto`, `reference`, `familles_gagnantes`,
`familles_perdantes` (against the reference, comma-separated codes),
`familles_evaluees` (weighted families documented by at least one
candidate; the others are set aside, since they rank nothing),
`incertitude` (`"qualitative"`; with `trajectoires`, the half-width of
the conformal interval of the basal area at the horizon, m2/ha, `NA`
without conformal residuals), `methode` (`"catalogue_qualitatif"` or
`"finn"`), `citations`. With `trajectoires`, `attr(, "valeurs")` holds
the simulated values behind the score: `unit_id`, `itineraire`,
`famille`, `variable`, `valeur`, `unite_mesure`, `horizon`.

## Details

`score_global` is an **order**, not a measure: the effects are
qualitative and sourced, not simulated. Display it as a rank. The
catalogue is not exhaustive; an itinerary absent from it is not
compared.

**With `trajectoires`** (spec 068), two families are read from the
simulation, the others weighted by the profile are set aside (said in
`familles_evaluees`):

- P:

  volume harvested, summed up to the horizon (`volume_preleve`, m3/ha;
  `g_prelevee`, m2/ha, when the volume was not simulated).

- C:

  carbon standing at the horizon (`carbone`, tC/ha).

Within a unit, each family is rescaled to `[-1, 1]` across the
candidates (`-1` the lowest value, `1` the highest, `0` for all when
they are equal), then weighted as the qualitative effects. The score is
still an order: it depends on the candidates compared, and the rescaling
gives the same weight to a small and to a large difference. The values
are in `attr(, "valeurs")`. The pitfalls of
[`simuler_itineraire()`](https://pobsteta.github.io/nemeton/reference/simuler_itineraire.md)
hold: recent climate held constant, response to thinning not learnt,
interval widened under a hypothesis beyond one step.

## Lifecycle

Experimental (spec 065): may change in any release.

## See also

[`itineraires_admissibles()`](https://pobsteta.github.io/nemeton/reference/itineraires_admissibles.md),
[`profils_poids()`](https://pobsteta.github.io/nemeton/reference/profils_poids.md),
[`identify_pareto_optimal()`](https://pobsteta.github.io/nemeton/reference/identify_pareto_optimal.md)
