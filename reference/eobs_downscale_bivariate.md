# Downscaled bivariate climate-trend map (T°max × precipitation)

The fine-resolution counterpart of
[`tendances_estivales_eobs`](https://pobsteta.github.io/nemeton/reference/tendances_estivales_eobs.md):
instead of the coarse E-OBS grid (~11 km), it **downscales** both summer
trends via
[`eobs_downscale`](https://pobsteta.github.io/nemeton/reference/eobs_downscale.md)
(KED with an auto-sourced regional DEM) and crosses them into a
**bivariate classification** — the "L'IF n°49" map (warming × drying,
red = warm & dry) at the project's context resolution.

Each trend is cut into tertiles (1 = coolest/driest, 3 =
warmest/wettest; or fixed `breaks`); the combined class is
`(classe_tmax - 1) * 3 + classe_precip`, 1-9, with **warm & dry = 7**
(red) and cool & wet = 3 (blue) — the same encoding as
[`tendances_estivales_eobs`](https://pobsteta.github.io/nemeton/reference/tendances_estivales_eobs.md).
Reliability is `"low"` (bounded by the noisy precipitation downscaling).

## Usage

``` r
eobs_downscale_bivariate(
  tx,
  rr,
  dem = NULL,
  aoi,
  buffer_m = 25000,
  breaks = NULL,
  context_res_m = 250,
  min_points = 10L,
  cache_path = NULL,
  ...
)
```

## Arguments

- tx:

  Per-year summer maximum-temperature `SpatRaster` (one layer per year)
  — the `eobs` input of
  [`eobs_downscale`](https://pobsteta.github.io/nemeton/reference/eobs_downscale.md)
  for `var = "tx"`.

- rr:

  Per-year summer precipitation `SpatRaster` — for `var = "rr"`.

- dem:

  Optional DEM; `NULL` (default) auto-sources a coarse regional DEM over
  the buffer (IGN WMS), shared by both trends. See
  [`eobs_downscale`](https://pobsteta.github.io/nemeton/reference/eobs_downscale.md).

- aoi:

  An `sf`/`sfc` of the management units.

- buffer_m:

  Context buffer around the AOI, in metres (default 25000).

- breaks:

  Optional `list(tmax=, precip=)` of two cut points each for a fixed
  classification; `NULL` → tertiles per trend.

- context_res_m:

  Auto-sourced DEM resolution in metres (default 250).

- min_points:

  Minimum E-OBS cells to attempt kriging (default 10).

- cache_path:

  Optional `.tif` path for the bivariate raster.

- ...:

  Passed to
  [`eobs_downscale`](https://pobsteta.github.io/nemeton/reference/eobs_downscale.md).

## Value

A list `list(raster, meta)`. `raster` is a single-layer integer
`SpatRaster` `classe_bivariee` (1-9) in the DEM CRS, or `NULL` if either
trend degraded. `meta`: `status`, `var = "bivariate"`, `crs`,
`dem_source`, `n_points`, `breaks` (`list(tmax, precip)` used),
`reliability = "low"`, `value_label`, and `palette` (`classes` 1-9,
`colors` hex, `labels`, `sense = "bivariate"` — class 7 warm&dry = red).
`meta$tx` / `meta$rr` carry the two component
[`eobs_downscale`](https://pobsteta.github.io/nemeton/reference/eobs_downscale.md)
metas.

## See also

[`eobs_downscale`](https://pobsteta.github.io/nemeton/reference/eobs_downscale.md),
[`tendances_estivales_eobs`](https://pobsteta.github.io/nemeton/reference/tendances_estivales_eobs.md)
