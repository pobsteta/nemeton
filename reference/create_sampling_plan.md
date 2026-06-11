# Generate a forest sampling plan (GRTS with graceful fallback)

Given a study area (and optionally a CHM, DEM, and BD Foret polygon
layer), build a candidate grid, apply terrain constraints, stratify, and
draw Base + Over plots. Prefers spsurvey GRTS, falls back to
BalancedSampling LPM2, then to a plain spatial random draw.

## Usage

``` r
create_sampling_plan(
  zone,
  n_base = NULL,
  n_over = 0L,
  target_error = NULL,
  cv = NULL,
  alpha = 0.05,
  over_ratio = 0.2,
  chm = NULL,
  slope = NULL,
  forest_mask = NULL,
  mnt = NULL,
  grid_step = 50,
  plot_radius = 15,
  min_forest_cover = 0.7,
  max_slope = 30,
  min_per_stratum = 2L,
  seed = 42L
)
```

## Arguments

- zone:

  sf polygon of the study area (any CRS; result uses `zone`'s CRS).

- n_base:

  Integer. Number of base (primary) plots. Optional when `target_error`
  and `cv` are provided — in that case `n_base` is computed via
  [`compute_sample_size`](https://pobsteta.github.io/nemeton/reference/compute_sample_size.md).

- n_over:

  Integer. Number of replacement (oversample) plots. Ignored when
  `target_error` is provided and `n_over` is left at 0: an over-ratio is
  applied to the computed `n_base` instead.

- target_error:

  Optional numeric. Target relative error on the mean of the target
  variable (default variable is basal area G/ha), as a fraction (e.g.
  0.10 for \\\pm\\10 %). When provided together with `cv`, `n_base` is
  sized via
  [`compute_sample_size`](https://pobsteta.github.io/nemeton/reference/compute_sample_size.md).

- cv:

  Optional numeric. Coefficient of variation (fraction) of the target
  variable over the AOI. Required when `target_error` is set. Can be
  derived from BD Forêt v2 via
  [`cv_from_bdforet`](https://pobsteta.github.io/nemeton/reference/cv_from_bdforet.md).

- alpha:

  Numeric. Significance level for the Cochran formula (default 0.05 = 95
  % confidence). Only used when `target_error` is provided.

- over_ratio:

  Numeric in \[0, 1\]. Fraction of `n_base` used as replacement plots
  when `n_over` is left at 0 and `target_error` is provided. Default
  0.20.

- chm:

  Optional `SpatRaster` of canopy height, used for height quartile
  stratification and buffer-mean extraction.

- slope:

  Optional `SpatRaster` of slope (percent), used for the `max_slope`
  constraint.

- forest_mask:

  Optional sf polygon layer. If a `tfv` column is present it's used for
  the type stratum (Feuillus / Conifères / Mixte / Peupleraie / Autre);
  otherwise used only for the `min_forest_cover` constraint.

- mnt:

  Optional `SpatRaster` DEM. A TPI (Topographic Position Index) is
  computed with a 100 m focal window and used for the topographic
  position stratum.

- grid_step:

  Numeric. Spacing (m) of the candidate grid. Default 50.

- plot_radius:

  Numeric. Buffer radius (m) used for the constraints / metric
  extraction. Default 15.

- min_forest_cover:

  Numeric in \[0, 1\]. Minimum forest cover ratio within the plot
  buffer. Default 0.7.

- max_slope:

  Numeric. Maximum slope (percent) for a candidate to be retained.
  Default 30.

- min_per_stratum:

  Integer. Minimum number of base plots in each stratum (capped at the
  number of candidates). Default 2.

- seed:

  Integer random seed. Default 42.

## Value

An sf POINT with columns `plot_id`, `type` (Base or Over),
`visit_order`, `stratum`, and optionally `strat_height` / `strat_type` /
`strat_topo` when the relevant input was supplied. A `"method"`
attribute records how the draw was performed (`"grts"`, `"lpm2"` or
`"random"`).

## Details

Without any of the optional inputs, the pipeline degrades to the
equivalent of a single
[`st_sample`](https://r-spatial.github.io/sf/reference/st_sample.html)
call — useful for quick previews when only the zone is known.

The return is ready for
[`create_qgis_project`](https://pobsteta.github.io/nemeton/reference/create_qgis_project.md).

## Examples

``` r
if (FALSE) { # \dontrun{
library(sf)
zone <- st_sf(geometry = st_sfc(st_polygon(list(rbind(
  c(0, 0), c(1000, 0), c(1000, 1000), c(0, 1000), c(0, 0)
))), crs = 2154))
plan <- create_sampling_plan(zone, n_base = 20, n_over = 5)
attr(plan, "method")
} # }
```
