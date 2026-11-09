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
  trajectoires = NULL
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

  Reserved for the simulation of chantier D (FINN): the output of
  [`simuler_itineraire()`](https://pobsteta.github.io/nemeton/reference/simuler_itineraire.md)
  (unit x itinerary x horizon x indicator, with `valeur`, `bas`, `haut`,
  `methode`). Then `methode` becomes `"finn"` and `incertitude` numeric;
  the output columns do not change. Not implemented yet: an error if
  given.

## Value

A data frame, one row per unit x candidate itinerary: `unit_id`,
`itineraire`, `score_global` (in `[-1, 1]`, `NA` if an evaluated family
has an unknown effect `?` for that itinerary), `rang` (1 = best within
the unit), `pareto`, `reference`, `familles_gagnantes`,
`familles_perdantes` (against the reference, comma-separated codes),
`familles_evaluees` (weighted families documented by at least one
candidate; the others are set aside, since they rank nothing),
`incertitude` (`"qualitative"`), `methode` (`"catalogue_qualitatif"`),
`citations`.

## Details

`score_global` is an **order**, not a measure: the effects are
qualitative and sourced, not simulated. Display it as a rank. The
catalogue is not exhaustive; an itinerary absent from it is not
compared.

## Lifecycle

Experimental (spec 065): may change in any release.

## See also

[`itineraires_admissibles()`](https://pobsteta.github.io/nemeton/reference/itineraires_admissibles.md),
[`profils_poids()`](https://pobsteta.github.io/nemeton/reference/profils_poids.md),
[`identify_pareto_optimal()`](https://pobsteta.github.io/nemeton/reference/identify_pareto_optimal.md)
