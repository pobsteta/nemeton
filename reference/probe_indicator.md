# What foundation models see: probe indicators with an embedding

For each indicator already computed on the project's units, fits a ridge
regression from the unit's mean embedding to the indicator and reads its
R² in **spatial block cross-validation**. A high R² means the embedding
carries the indicator's information; a low one is a documented blind
spot (spec 066). The table is a diagnostic: it does not replace any
indicator.

## Usage

``` r
probe_indicator(
  units,
  embedding,
  indicateurs = NULL,
  normalise = TRUE,
  taille_bloc_m = 2000,
  n_plis = 5L,
  min_unites = 50L,
  source = NULL,
  graine = 1L
)
```

## Arguments

- units:

  sf polygons of the project's units, with the indicator columns already
  computed (short codes `C1`, `B2`, ... as in
  [`list_indicators()`](https://pobsteta.github.io/nemeton/reference/list_indicators.md)).

- embedding:

  SpatRaster, one band per embedding dimension (AlphaEarth, MAESTRO or
  ForPT), or a list named by year (latest used).

- indicateurs:

  Short codes to probe. `NULL`: every indicator of
  [`list_indicators()`](https://pobsteta.github.io/nemeton/reference/list_indicators.md)
  present as a column of `units`.

- normalise:

  Logical. Probe the 0-100 normalised value
  ([`normalize_indicator()`](https://pobsteta.github.io/nemeton/reference/normalize_indicator.md),
  with the indicator's status column) rather than the raw one, so that
  RMSE compare across indicators. Default `TRUE`.

- taille_bloc_m:

  Side of the cross-validation blocks, in metres. Default 2000 (units of
  a few hectares).

- n_plis:

  Number of folds. Default 5.

- min_unites:

  Minimum number of usable units for a probe. Default 50: below that,
  the cross-validated R² is too noisy to be read.

- source:

  Label of the embedding source in the output. Default: the raster's
  `embedding_source` attribute, else `"aef"`.

- graine:

  Random seed of the fold assignment.

## Value

A data frame, one row per indicator, sorted by decreasing R²:

- code, famille:

  indicator and family codes.

- n:

  units used.

- r2, rmse:

  cross-validated R² and RMSE (`NA` without probe).

- lecture:

  `"voit"` (R² \>= 0.5), `"partiel"` (0.2 to 0.5), `"angle_mort"` (\<
  0.2): conventions, not test thresholds.

- statut:

  `"ok"`, `"trop_peu_unites"`, `"variance_nulle"` or
  `"indicateur_absent"`.

- source_commune:

  `TRUE` for indicators computed (depending on their source) from
  Sentinel-2, like AlphaEarth: a high R² may then come from the shared
  input rather than from what the model understands of the forest.

- source_embedding:

  embedding source.

## Details

**Pitfalls.** (1) Shared input is not vision: see `source_commune`. (2)
A probe is project-specific: an indicator with no variance in the
project gets no probe, without the model being blind. (3) A probe is not
an estimator: an R² of 0.6 does not allow replacing the indicator by its
prediction; use
[`embedding_regress()`](https://pobsteta.github.io/nemeton/reference/embedding_regress.md)
with a field-measured target for that. (4) Below `min_unites` units, no
probe.

## Lifecycle

Experimental (spec 066): may change in any release.

## See also

[`embedding_summary()`](https://pobsteta.github.io/nemeton/reference/embedding_summary.md),
[`embedding_regress()`](https://pobsteta.github.io/nemeton/reference/embedding_regress.md)
