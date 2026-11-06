# Predict a stand variable from foundation-model embeddings (NDP 0)

Fits a regression from the embedding around field plots (typically IFN
plots of the project area) to a measured variable (default: dominant
height `H0`), evaluates it by **spatial block cross-validation**, and
predicts a raster of that variable over the embedding's extent. It gives
the height-based indicators a NDP 0 height when there is neither a CHM
nor LiDAR (spec 064, chantier A): pass the prediction to their `chm =`
argument.

## Usage

``` r
embedding_regress(
  train,
  embedding,
  target = "H0",
  methode = c("auto", "ranger", "ridge"),
  rayon_m = 15,
  taille_bloc_m = 5000,
  n_plis = 5L,
  min_train = 30L,
  predire = TRUE,
  graine = 1L
)
```

## Arguments

- train:

  sf points (or polygons) of the training plots, with the `target`
  column.

- embedding:

  SpatRaster, one band per embedding dimension (e.g.
  `alphaearthnemeton::aef_fetch()`), or a list named by year (latest
  used).

- target:

  Name of the column to predict. Default `"H0"`.

- methode:

  `"auto"` (ranger when installed, else ridge), `"ranger"` or `"ridge"`
  (base R, penalty chosen by generalised cross-validation).

- rayon_m:

  Plot radius in metres: the plot's embedding is the coverage-weighted
  mean within this radius. Default 15 (IFN plot).

- taille_bloc_m:

  Side of the square blocks of the spatial cross-validation, in metres.
  Default 5000: plots closer than that tend to share their errors, and a
  random split would flatter the model.

- n_plis:

  Number of cross-validation folds (blocks are dealt to folds). Default
  5.

- min_train:

  Minimum number of usable plots. Below it, no model is fitted and the
  status is `"train_too_small"`. Default 30.

- predire:

  Logical. Predict the raster. Default `TRUE`.

- graine:

  Random seed for the fold assignment and ranger.

## Value

An object of class `embedding_regression`, a list with

- status:

  `"ok"` or `"train_too_small"`.

- prediction:

  SpatRaster named after `target` (`NULL` when no model), with
  `attr(, "chm_source") = "aef_regression"`.

- cv:

  list: `rmse`, `r2`, `biais` (mean prediction minus observation), `n`,
  `n_plis`, `taille_bloc_m`, and `observations` (data frame of
  out-of-fold predictions).

- methode:

  the method used.

- n_train:

  number of usable plots.

- modele:

  the fitted model (ridge coefficients or ranger object).

## Details

**Pitfalls.** The prediction is smooth: it carries the mean height of a
10 m pixel's neighbourhood as the embedding sees it, not the
within-stand variability of a CHM. It suits indicators that read a level
(P1, P2, C1) and **not** B2, whose structural component is the
coefficient of variation of the CHM: a CV of predicted heights measures
the model, not the stand. The cross-validated RMSE is the error to quote
with any value derived from the prediction; with fewer than `min_train`
plots nothing is fitted rather than a model that would mostly fit noise.

## Lifecycle

Experimental (spec 064): may change in any release.

## See also

[`embedding_summary()`](https://pobsteta.github.io/nemeton/reference/embedding_summary.md),
[`indicateur_p2_station()`](https://pobsteta.github.io/nemeton/reference/indicateur_p2_station.md)
