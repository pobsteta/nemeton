# Predict basal area with a calibrated FINN model

Simulates, from the initial state of each plot, the basal area after a
number of FINN steps, averaged over several draws (FINN is stochastic).

## Usage

``` r
predire_finn(calibration, arbres, environnement, n_tirages = 10L, pas = 1L)
```

## Arguments

- calibration:

  A `"finn_calibration"` object from
  [`calibrer_finn()`](https://pobsteta.github.io/nemeton/reference/calibrer_finn.md).

- arbres:

  data.frame of the initial trees: `placette`, `essence`, `d1` (cm),
  `poids` (stems/ha). If a `statut` column is present, only `"vivant"`
  and `"mort"` rows are kept (the initial state, as in
  [`calibrer_finn()`](https://pobsteta.github.io/nemeton/reference/calibrer_finn.md)).
  Species unknown to the calibration go to `"other"`.

- environnement:

  data.frame, one row per plot: `placette` and the variables of the
  calibration.

- n_tirages:

  Integer. Number of draws averaged. Default 10.

- pas:

  Integer. Number of FINN steps (each of `calibration$pas_annees`
  years). Default 1.

## Value

data.frame, one row per plot: `placette`, `g_initiale`, `g_predite`
(mean of the draws), `g_q05`, `g_q95` (5 and 95 % quantiles of the
draws), in m2/ha. The quantiles only show the demographic stochasticity
of FINN, not the uncertainty of its parameters: they are not a
prediction interval (on BFC they held 19 % of the observed values).

## See also

[`calibrer_finn()`](https://pobsteta.github.io/nemeton/reference/calibrer_finn.md)
