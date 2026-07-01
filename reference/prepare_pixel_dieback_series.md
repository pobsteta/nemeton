# Prepare the derived series for the pixel-dieback plot (CRswir + CRre)

Pure transform of a RECONFORT pixel series (from
[`read_reconfort_pixel_series`](https://pobsteta.github.io/nemeton/reference/read_reconfort_pixel_series.md))
into the derived layers the app's 4-panel plotly needs: a regular
gap-filled grid (optionally light-smoothed), the raw valid observations,
the annual summer extrema (CRswir trough / CRre peak), the annual
state-space centroids, and the long-gap interpolated spans. No plotting,
no Shiny — testable on its own, so the app's rendering function stays
free of business logic (CLAUDE.md rule 3).

## Usage

``` r
prepare_pixel_dieback_series(
  df,
  grid_step = 10L,
  smooth = c("light", "none"),
  summer = c(152L, 273L),
  gap_flag_days = 45L
)
```

## Arguments

- df:

  A `data.frame` from
  [`read_reconfort_pixel_series`](https://pobsteta.github.io/nemeton/reference/read_reconfort_pixel_series.md):
  columns `obs_date` (Date), `crswir_obs`, `crre_obs`. A per-index
  validity is derived as `!is.na()` (an `NA` marks a cloud-masked date).

- grid_step:

  Integer number of days of the regular grid. Default `10L`.

- smooth:

  `"light"` (Savitzky-Golay, `p = 2`, `n = 5`) or `"none"`. Default
  `"light"`. Strong smoothing is intentionally not offered: it razes the
  summer extrema, which are the signal being tracked.

- summer:

  Integer length-2 day-of-year window `c(start, end)` of the
  growing-season peak. Default `c(152L, 273L)` (1 Jun - 30 Sep).

- gap_flag_days:

  Long-gap threshold in days above which an interpolated span is flagged
  in `gaps`. Default `45L`.

## Value

A named list, each element a `data.frame`:

- grid_swir, grid_re:

  `date`, `val`, `year`, `doy` — the regular grid, gap-filled and
  optionally smoothed, per index.

- obs_swir, obs_re:

  `date`, `val`, `year`, `doy` — the raw valid observations per index
  (raw-points overlay).

- trough_swir:

  `year`, `date`, `val` — annual summer CRswir minimum, on real
  observations.

- peak_re:

  `year`, `date`, `val` — annual summer CRre maximum.

- state:

  `date`, `year`, `val_sw`, `val_re` — summer dates where both indices
  are valid (state-space cloud).

- centroids:

  `year`, `val_sw`, `val_re` — annual mean of `state` (state-space
  trajectory).

- gaps:

  `from`, `to` — interpolated spans longer than `gap_flag_days`.

The input attributes (`species`, `v_model`, `n_classes`, `date_from`,
`date_to`, `dans_zone_validite`) are carried over onto the list.

## See also

[`read_reconfort_pixel_series`](https://pobsteta.github.io/nemeton/reference/read_reconfort_pixel_series.md)

## Examples

``` r
df <- data.frame(
  obs_date   = as.Date("2023-01-01") + seq(0, 700, by = 15),
  crswir_obs = 0.8 - 0.1 * sin(seq(0, 700, by = 15) / 58),
  crre_obs   = 0.5 + 0.1 * sin(seq(0, 700, by = 15) / 58)
)
prep <- prepare_pixel_dieback_series(df)
names(prep)
#> [1] "grid_swir"   "grid_re"     "obs_swir"    "obs_re"      "trough_swir"
#> [6] "peak_re"     "state"       "centroids"   "gaps"       
```
