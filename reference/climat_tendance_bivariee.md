# Bivariate summer-trend map on the project circle (L'IF n° 49 method)

Crosses the **total change over the period** (least-squares slope ×
(last year − first year)) of summer maximum temperature (°C) and summer
precipitation (mm) into a bivariate classification, at the native
resolution of the series from
[`climat_ete_series()`](https://pobsteta.github.io/nemeton/reference/climat_ete_series.md)
(spec 063). A cell needs at least 80% valid years. Each axis is clipped
to its bounds and cut into `n` classes.

Periods: `"complete"` (all the years of the series), `"if49"`
(2006-2020, Figure 1 of *L'IF* n° 49) or `c(debut, fin)`.

Bounds (`bornes`): `"if49"` (fixed, ΔT ∈ \[−0.7, 4\] °C, ΔP ∈ \[−270,
120\] mm, default for `periode = "if49"`); `"france"` (default
otherwise: 1% and 99% quantiles, extended to 0, of the E-OBS changes
over metropolitan France for the same years and months — the same
colours for neighbouring projects and across sources; needs the machine
E-OBS monthly cache, falls back to `"emprise"` with `meta$bornes$reason`
otherwise); `"emprise"` (same quantiles on the circle, as in the source
scripts); or an explicit `list(tmax = c(lo, hi), precip = c(lo, hi))`.

The class is `(ct - 1) * n + cp`, `ct` = 1 for the smallest Tmax rise to
`n` for the largest, `cp` = 1 for the driest to `n` for the wettest; so
"hot & dry" is `(n - 1) * n + 1`. `meta$palette$colors[classe]` gives
the colour: the 10 × 10 palette read on the Figure 1 legend
(`"if49_10x10"`, needs `n = 10`), or the bilinear interpolation of four
corner colours (`"coins"`, any `n`).

## Usage

``` r
climat_tendance_bivariee(
  series,
  periode = "complete",
  bornes = NULL,
  palette = c("if49_10x10", "coins"),
  n = 10L,
  cache_path = NULL,
  eobs_cache_dir = NULL,
  version = "33.0e"
)
```

## Arguments

- series:

  The result of
  [`climat_ete_series()`](https://pobsteta.github.io/nemeton/reference/climat_ete_series.md).

- periode:

  `"complete"`, `"if49"` or `c(debut, fin)`.

- bornes:

  `NULL` (default, see above), `"france"`, `"if49"`, `"emprise"` or a
  list of explicit bounds.

- palette:

  `"if49_10x10"` (default) or `"coins"`.

- n:

  Classes per axis (default 10).

- cache_path:

  Optional `.tif` path: the class raster is written there, the two
  change layers to `<name>_tendances.tif` and the meta to
  `<name>.meta.json` (the app reads them back across a `future` worker).

- eobs_cache_dir:

  Machine-wide E-OBS cache, for `bornes = "france"`.

- version:

  E-OBS version of that cache (default `"33.0e"`).

## Value

`list(raster, tendances, meta)`: `raster` is an integer `SpatRaster`
`classe_bivariee` (1..n²) on the native grid and CRS of the source;
`tendances` a 2-layer `SpatRaster` (`tendance_tmax` in °C,
`tendance_precip` in mm); `meta` holds `status`, `reason`, `periode`
(`c(debut, fin)` actually used), `n_annees`, `bornes` (`tmax`, `precip`,
`mode`, `reference`, `reason`), `palette` (`name`, `classes`, `colors`,
`ncol = n`, `zero = list(tmax, precip)` — the \[0, 1\] position of the
zero change on each axis, for the dashed 0/0 lines), `unites`, `source`,
`resolution_native`, `crs`, `attribution` and `fichiers`.

## Lifecycle

Experimental: may change in any release, without deprecation (spec 057).

## See also

[`climat_ete_series()`](https://pobsteta.github.io/nemeton/reference/climat_ete_series.md),
[`climat_nuages_annuels()`](https://pobsteta.github.io/nemeton/reference/climat_nuages_annuels.md)
