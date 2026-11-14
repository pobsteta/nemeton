# Conformal residuals of a FINN calibration

Measures the error of a calibrated FINN model on plots that took no part
in the calibration, so that
[`simuler_itineraire()`](https://pobsteta.github.io/nemeton/reference/simuler_itineraire.md)
can give a prediction interval (split conformal prediction, Lei et al.
2018). The half-width is the quantile of the absolute residuals of the
basal area after one FINN step, at level `niveau * (1 + 1 / n)`: if the
new plots are exchangeable with these ones, the interval holds the
observed value with probability at least `niveau` on average.

## Usage

``` r
conformer_finn(
  calibration,
  arbres,
  environnement,
  niveau = 0.9,
  n_tirages = 10L,
  coordonnees = NULL,
  mortalite = TRUE
)
```

## Arguments

- calibration:

  A `"finn_calibration"` object from
  [`calibrer_finn()`](https://pobsteta.github.io/nemeton/reference/calibrer_finn.md).

- arbres:

  data.frame of trees measured twice on plots **not** used in the
  calibration, with the columns of
  [`calibrer_finn()`](https://pobsteta.github.io/nemeton/reference/calibrer_finn.md)
  (`placette`, `essence`, `d1`, `d2`, `poids`, `statut`).

- environnement:

  data.frame, one row per plot: `placette` and the variables of the
  calibration.

- niveau:

  Numeric in `(0, 1)`. Target coverage. Default 0.9.

- n_tirages:

  Integer. Draws averaged per plot. Default 10.

- coordonnees:

  data.frame or `NULL`. `placette`, `x`, `y` in a projected CRS
  (metres), for the interval of units of several plots in
  [`simuler_itineraire()`](https://pobsteta.github.io/nemeton/reference/simuler_itineraire.md):
  residuals are then averaged over groups of **neighbouring** plots.
  Without coordinates the groups are random, which ignores the spatial
  correlation of the errors and gives a narrower interval.

- mortalite:

  Logical. Also measure the residuals of mortality (observed minus
  expected basal area of the dead trees, one FINN step) for the
  threshold of
  [`surmortalite_finn()`](https://pobsteta.github.io/nemeton/reference/surmortalite_finn.md).
  Default `TRUE`; plots cut between the visits get `NA`.

## Value

The calibration, with an element `conforme`: a list with `niveau`,
`demi_largeur` (m2/ha, for one step and one plot), `n_placettes`,
`pas_annees`, and the signed residuals `residus` (with `x`, `y` when
`coordonnees` is given) for the units; with `mortalite = TRUE`,
`mortalite`: a list with the mortality residuals `residus` (same plots,
same order) and `n_placettes`.

## Details

Stops if some plots were used in the calibration (their residuals are
too small). The residuals are measured for **one step** only (the
interval between two visits): beyond,
[`simuler_itineraire()`](https://pobsteta.github.io/nemeton/reference/simuler_itineraire.md)
widens the interval under an explicit hypothesis. On BFC (1000 plots, 5
years, model calibrated with `min_arbres_essence = 300`), the half-width
at 90 % was 4.70 m2/ha and the interval held 91 % of the basal areas of
1000 other plots (spec 068).

For a unit of `k` plots, the half-width is the conformal quantile of the
mean residual of groups of `k` held-out plots. On BFC the residuals of
two plots are barely correlated (0.02 to 0.04 between 1.5 and 20 km),
but the mean error does not shrink as `1 / sqrt(k)`: the shared bias
stays. At 90 %, measured on 1000 held-out plots: 4.57 m2/ha for one
plot, 2.93 for 4 neighbouring plots, 1.79 for 16; on groups of 1000
other plots they held 91, 93 and 91 % of the errors, against 88 and 77 %
for `1 / sqrt(k)` (2.28 and 1.14) and 94 and 86 % for random groups
(`data-raw/prototype_finn_unites.R`). IFN plots are kilometres apart and
their coordinates are blurred: a correlation within a stand, at a few
hundred metres, is not measured.

## References

Lei J., G'Sell M., Rinaldo A., Tibshirani R.J., Wasserman L. (2018).
Distribution-free predictive inference for regression. Journal of the
American Statistical Association 113(523), 1094-1111.

## See also

[`calibrer_finn()`](https://pobsteta.github.io/nemeton/reference/calibrer_finn.md),
[`simuler_itineraire()`](https://pobsteta.github.io/nemeton/reference/simuler_itineraire.md)
