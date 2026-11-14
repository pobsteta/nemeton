# Excess mortality against a FINN baseline

Compares the basal area of the trees that died between two inventories
with the mortality a calibrated FINN model expects from the state at the
first one: the difference is the excess mortality (spec 069). Calibrated
before a crisis, FINN gives the ordinary mortality of competition and
ageing; an excess above the conformal threshold is abnormal (drought,
bark beetles, dieback, storm). It says "more than expected", not why.

## Usage

``` r
surmortalite_finn(
  calibration,
  arbres,
  environnement,
  unites = NULL,
  niveau = 0.95,
  n_tirages = 20L,
  correction = TRUE
)
```

## Arguments

- calibration:

  A `"finn_calibration"` object from
  [`calibrer_finn()`](https://pobsteta.github.io/nemeton/reference/calibrer_finn.md).
  For the threshold, with the mortality residuals of
  [`conformer_finn()`](https://pobsteta.github.io/nemeton/reference/conformer_finn.md).

- arbres:

  data.frame of trees measured twice, with the columns of
  [`calibrer_finn()`](https://pobsteta.github.io/nemeton/reference/calibrer_finn.md)
  (`placette`, `essence`, `d1`, `d2`, `poids`, `statut`). Dead trees
  (`statut == "mort"`) count at their first diameter `d1`. Plots with a
  cut between the visits (`statut == "coupe"`) are left out: a cut tree
  would have counted in the expected mortality.

- environnement:

  data.frame, one row per plot: `placette` and the variables of the
  calibration.

- unites:

  data.frame or `NULL`. `placette`, `unite`: the plots of each unit
  (management unit, or essence x region x period for a regional
  diagnosis). The default, `NULL`, reports every plot, with a warning:
  the death of a tree is a rare event and a single plot over a few years
  is noisy (spec 069, S-2).

- niveau:

  Numeric in `(0, 1)`. Level of the one-sided conformal threshold.
  Default 0.95 (spec 069, S-4).

- n_tirages:

  Integer. Draws of the FINN step averaged per plot. Default 20.

- correction:

  Logical. Apply the growth correction of the calibration
  ([`corriger_finn()`](https://pobsteta.github.io/nemeton/reference/corriger_finn.md))
  if it has one. Default `TRUE`.

## Value

A data.frame, one row per plot (or per unit, with `unite` and
`n_placettes` instead of `placette`): `g_initiale` (m2/ha, living and
dead trees at the first visit), `mort_observee` and `mort_attendue`
(m2/ha of basal area at the first visit of the trees that died during
one FINN step, `calibration$pas_annees` years), `surmortalite` (observed
minus expected), `surmortalite_pct` (in % of `g_initiale`), `seuil`
(m2/ha) and `anormale` (`surmortalite > seuil`). For a unit the values
are the means of its plots. `seuil` and `anormale` are `NA` without
mortality residuals, or for a unit too large for them.

## Details

**Expected.** One FINN step from the trees of the first visit; the stems
that die in the step count at their diameter at the start of the step,
mean of `n_tirages` draws. The interval between the visits should be the
step of the calibration (5 years for the IFN).

**Threshold.** For one plot, the conformal quantile at level
`niveau * (1 + 1 / n)` of the observed minus expected mortality on the
held-out plots of
[`conformer_finn()`](https://pobsteta.github.io/nemeton/reference/conformer_finn.md):
on plots exchangeable with those, an ordinary mortality exceeds it with
probability at most `1 - niveau`. For a unit of `k` plots, the same
quantile of the mean residual of groups of `k` held-out plots,
neighbours when
[`conformer_finn()`](https://pobsteta.github.io/nemeton/reference/conformer_finn.md)
had the coordinates, as for the interval of
[`simuler_itineraire()`](https://pobsteta.github.io/nemeton/reference/simuler_itineraire.md);
it needs at least 30 groups.

**Baseline.** The model must have learnt ordinary mortality. On BFC, a
FINN calibrated on the 1724 plots revisited in 2015-2017 put 3.7 to 6.6
% of the held-out plots of those years above the 95 % threshold (2.45
m2/ha in 5 years), and the excess rose after 2018: spruce 4.9 times the
expected mortality in 2021-2025 (+1.36 m2/ha), ash 3.0 times (+1.19),
beech 1.06 (spec 069, `data-raw/surmortalite_ifn_bfc.R`). The observed
mortality counts every tree dead between the visits, windthrow included.

## See also

[`conformer_finn()`](https://pobsteta.github.io/nemeton/reference/conformer_finn.md),
[`calibrer_finn()`](https://pobsteta.github.io/nemeton/reference/calibrer_finn.md),
[`simuler_itineraire()`](https://pobsteta.github.io/nemeton/reference/simuler_itineraire.md)
