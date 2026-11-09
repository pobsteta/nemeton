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
conformer_finn(calibration, arbres, environnement, niveau = 0.9, n_tirages = 10L)
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

## Value

The calibration, with an element `conforme`: a list with `niveau`,
`demi_largeur` (m2/ha, for one step), `n_placettes`, `pas_annees`.

## Details

Stops if some plots were used in the calibration (their residuals are
too small). The residuals are measured for **one step** only (the
interval between two visits): beyond,
[`simuler_itineraire()`](https://pobsteta.github.io/nemeton/reference/simuler_itineraire.md)
widens the interval under an explicit hypothesis. On BFC (1000 plots, 5
years, model calibrated with `min_arbres_essence = 300`), the half-width
at 90 % was 4.70 m2/ha and the interval held 91 % of the basal areas of
1000 other plots (spec 068).

## References

Lei J., G'Sell M., Rinaldo A., Tibshirani R.J., Wasserman L. (2018).
Distribution-free predictive inference for regression. Journal of the
American Statistical Association 113(523), 1094-1111.

## See also

[`calibrer_finn()`](https://pobsteta.github.io/nemeton/reference/calibrer_finn.md),
[`simuler_itineraire()`](https://pobsteta.github.io/nemeton/reference/simuler_itineraire.md)
