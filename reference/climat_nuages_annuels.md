# Yearly summer point clouds on the project circle

Tabular data for the yearly scatter plots of
`nuages_bfc_chelsa_safran.R` (spec 063): each cell of the circle is a
point, x = precipitation (mm), y = maximum temperature (°C), one cloud
per year. The app draws them (an animated year slider and a
small-multiples grid replace the GIF/patchwork).

Modes: `"anomalie"` — departure of each summer from the mean of the
`reference` years (at least 10 of them must be present);
`"tendance_cumulee"` — for year *n*, total change (slope × duration)
from the first year up to *n*, once there are at least `recul_min`
years.

## Usage

``` r
climat_nuages_annuels(
  series,
  mode = c("anomalie", "tendance_cumulee"),
  reference = 1981:2010,
  recul_min = 10L,
  n_points = 4000L,
  seed = 1L
)
```

## Arguments

- series:

  The result of
  [`climat_ete_series()`](https://pobsteta.github.io/nemeton/reference/climat_ete_series.md).

- mode:

  `"anomalie"` or `"tendance_cumulee"`.

- reference:

  Reference years for the anomalies (default `1981:2010`).

- recul_min:

  Minimum number of years for the cumulative trend (default 10).

- n_points:

  Points sampled per year (default 4000; all cells when fewer).

- seed:

  Random seed of the sampling.

## Value

`list(points, moyennes, limites, meta)`: `points` is a
`data.frame(annee, x, y)`; `moyennes` a `data.frame(annee, x, y)` of the
circle mean of each year (over all cells); `limites` a
`list(x = c(lo, hi), y = c(lo, hi))` shared by every year (0.2% and
99.8% quantiles extended to 0); `meta` holds `status`, `reason`, `mode`,
`reference`, `annees`, `n_cellules`, `unites`, `source`,
`resolution_native` and `attribution`.

## Lifecycle

Experimental: may change in any release, without deprecation (spec 057).

## See also

[`climat_ete_series()`](https://pobsteta.github.io/nemeton/reference/climat_ete_series.md),
[`climat_tendance_bivariee()`](https://pobsteta.github.io/nemeton/reference/climat_tendance_bivariee.md)
