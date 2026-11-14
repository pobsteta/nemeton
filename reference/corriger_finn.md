# Growth and recruitment correction of a FINN calibration

Measures how much FINN's diameter growth of surviving trees and its
number of recruits must be scaled to match the observed ones, as smooth
functions of the initial basal area of the plot, for broadleaves and
conifers. The factors travel with the calibration and
[`simuler_itineraire()`](https://pobsteta.github.io/nemeton/reference/simuler_itineraire.md),
[`predire_finn()`](https://pobsteta.github.io/nemeton/reference/predire_finn.md)
and
[`conformer_finn()`](https://pobsteta.github.io/nemeton/reference/conformer_finn.md)
apply them after every FINN step (spec 068, decision D-G option 1).

## Usage

``` r
corriger_finn(
  calibration,
  arbres,
  environnement,
  placettes_calibration = FALSE,
  grille = seq(0, 80, by = 2.5),
  largeur = 5,
  n_tirages = 3L,
  iterations = 2L,
  min_placettes = 30L
)
```

## Arguments

- calibration:

  A `"finn_calibration"` object from
  [`calibrer_finn()`](https://pobsteta.github.io/nemeton/reference/calibrer_finn.md).

- arbres:

  data.frame of trees measured twice, with the columns of
  [`calibrer_finn()`](https://pobsteta.github.io/nemeton/reference/calibrer_finn.md)
  (`placette`, `essence`, `d1`, `d2`, `poids`, `statut`). Plots with a
  cut between the visits (`statut == "coupe"`) are left out.

- environnement:

  data.frame, one row per plot: `placette` and the variables of the
  calibration.

- placettes_calibration:

  Logical. Accept plots used in the calibration. Default `FALSE`. On
  BFC, FINN's bias on its calibration plots was the same as on held-out
  plots (spec 068), so the many calibration plots give steadier factors
  than the few held-out ones; keep held-out plots for
  [`conformer_finn()`](https://pobsteta.github.io/nemeton/reference/conformer_finn.md)
  and for the test.

- grille:

  Numeric. Basal areas (m2/ha) where the factors are estimated; in
  between they are interpolated linearly, beyond they hold the value of
  the nearest end. Default 0 to 80 by 2.5.

- largeur:

  Numeric. Bandwidth (m2/ha) of the Gaussian kernel: the factor at `g`
  is the ratio of the observed to the simulated sums over all plots,
  weighted by `exp(-((G0 - g) / largeur)^2 / 2)`. Default 5.

- n_tirages:

  Integer. Draws averaged per plot. Default 3.

- iterations:

  Integer. Rounds of measure and adjustment. Default 2: the basal area
  grows with the square of the diameter, so a factor on the diameter
  increment is not exactly the ratio of the basal area increments; a
  second round absorbs the difference.

- min_placettes:

  Integer. A group (broadleaves, conifers) with fewer plots keeps
  factors of 1; a point of `grille` with a smaller kernel effective
  number of plots takes the factor of the nearest point that has enough
  (the ends of the range of basal areas). Default 30.

## Value

The calibration, with an element `correction`: `grille`, `croissance`
and `recrutement` (matrices, `grille` x `feuillus` / `resineux`),
`n_effectif` (kernel effective number of plots, same shape), `resineux`
(logical, one per species of the calibration), `largeur`, `n_placettes`
and `placettes`. A conformal element `conforme` is dropped: measure it
again with
[`conformer_finn()`](https://pobsteta.github.io/nemeton/reference/conformer_finn.md)
on held-out plots, after the correction.

## Details

After a FINN step, a surviving cohort of diameter `dbh0` at the start
and `dbh1` at the end takes `dbh0 + f * (dbh1 - dbh0)`; the diameter
never decreases. A recruited cohort of `n` stems keeps `r * n` stems,
rounded at random to an integer. `f` and `r` are read at the basal area
of the plot at the start of the step, for the group of the species. The
factors correct a mean, not FINN's density-growth relation itself, and
compound over the steps of a long trajectory.

## See also

[`calibrer_finn()`](https://pobsteta.github.io/nemeton/reference/calibrer_finn.md),
[`conformer_finn()`](https://pobsteta.github.io/nemeton/reference/conformer_finn.md),
[`simuler_itineraire()`](https://pobsteta.github.io/nemeton/reference/simuler_itineraire.md)
