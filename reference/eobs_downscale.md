# Downscale an E-OBS variable to a fine raster

Turn the coarse E-OBS grid (~0.1°, ~11 km) into a fine continuous
`SpatRaster` over the project's regional context, using the DEM (and
terrain covariates) as external drift. Built for the "regional context"
map of the reGénération tab — **not** stand-scale precision, which a
microclimf run driven by HD LiDAR already produces.

## Usage

``` r
eobs_downscale(
  var = c("tx", "rr"),
  eobs,
  dem = NULL,
  aoi,
  engine = "ked",
  buffer_m = 25000,
  resolution = NULL,
  covariates = c("dem", "slope", "aspect", "twi"),
  statistic = c("trend", "mean", "value"),
  variogram_model = NULL,
  years = NULL,
  max_cells = 5e+05,
  min_points = 10L,
  cache_path = NULL,
  context_res_m = 250,
  ...
)
```

## Arguments

- var:

  `"tx"` (maximum temperature) or `"rr"` (precipitation; KED only,
  `reliability = "low"`, palette sense `"dry_unfavorable"`).

- eobs:

  A `SpatRaster` of E-OBS: one layer per year (for
  `statistic = "trend"`/`"mean"`) or a single reduced layer
  (`statistic = "value"`).

- dem:

  A `SpatRaster` DEM — the downscaling target grid and main covariate;
  the output shares its CRS. **Optional**: pass `NULL` (or a DEM too
  small to cover the buffer) and a **coarse regional DEM is
  auto-sourced** over the buffer from the IGN Géoplateforme WMS
  (`ELEVATION.ELEVATIONGRIDCOVERAGE`, France, no auth). The KED extracts
  terrain at the E-OBS cell centres, so a stand-scale DEM (~4–5 km)
  covers only ~1 E-OBS cell and yields `insufficient_data`; the
  auto-sourced DEM spans the whole buffer. `meta$dem_source` reports
  `"provided"`, `"autoscaled"`, or `"autoscaled_small_dem"`.

- aoi:

  An `sf`/`sfc` of the management units, buffered to frame the regional
  context.

- engine:

  `"ked"` (regression-kriging, the only engine). The `"meteoland"`
  engine was removed in nemeton 2026.10.17 (no caller): passing it warns
  and runs KED, with `meta$engine_requested = "meteoland"` and
  `meta$engine_fallback = TRUE`, as its former fallback did.

- buffer_m:

  Context buffer around the AOI, in metres (default 25000).

- resolution:

  Optional target resolution (DEM units). `NULL` keeps the DEM
  resolution (aggregated if the grid would exceed `max_cells`).

- covariates:

  Terrain covariates among `"dem"`, `"slope"`, `"aspect"` (entered as
  northness), `"twi"` (best-effort). Default all four.

- statistic:

  What to downscale: `"trend"` (per-decade OLS slope over the E-OBS
  years), `"mean"`, or `"value"` (a pre-reduced single layer).

- variogram_model:

  Optional
  [`gstat::vgm()`](https://r-spatial.github.io/gstat/reference/vgm.html)
  model; `NULL` auto-fits.

- years:

  Optional numeric years matching the E-OBS layers (else taken from
  [`terra::time()`](https://rspatial.github.io/terra/reference/time.html),
  else the layer index).

- max_cells:

  Cell cap for the target grid (default `5e5`); the DEM is aggregated
  above it, so the output is never a gigapixel raster.

- min_points:

  Minimum E-OBS cells within the buffer to attempt kriging (default 10);
  below it, trend-only.

- cache_path:

  Optional `.tif` path; when given, the result raster is written there
  for instant reload (pattern of `pai.tif`).

- context_res_m:

  Target resolution (metres) of the **auto-sourced** coarse regional DEM
  (default 250; ignored when a covering `dem` is supplied). A regional
  trend needs no finer — the grid is capped at `max_cells` anyway.

- ...:

  Ignored (forward-compat; also absorbs the former `calibrate` and `cv`
  arguments of the removed meteoland engine).

## Value

A list `list(raster, meta)`. `raster` is a single-layer `SpatRaster` in
the DEM CRS, or `NULL` when degraded to nothing. `meta` carries the
**output contract** the app renders against: `status`
(`"ok"`/`"insufficient_data"`), `engine` (the engine that actually ran),
`method` (`"ked"`/`"trend_only"`), `var`, `statistic`, `crs` (EPSG
code), `unit` (e.g. `"°C/decade"` for `tx`, `"mm/decade"` for `rr`),
`value_label`, `reliability` (`"high"` for `tx`, `"low"` for `rr`),
`palette` (`low`/`high` quantile bounds and `sense` —
`"hot_unfavorable"` for `tx` (high = warm = red), `"dry_unfavorable"`
for `rr` (low = drying = red)), `n_points`, `dem_source`
(`"provided"`/`"autoscaled"`/`"autoscaled_small_dem"`), and, when
degraded, `reason` (i18n key). Degraded `reason`s distinguish the
causes: `eobs_downscale_dem_too_small` (the supplied DEM covered too
little of the buffer and no coarse DEM could be sourced),
`eobs_downscale_no_dem` (no DEM supplied and none could be sourced),
`eobs_downscale_too_few_cells` (DEM fine but too few E-OBS cells within
the buffer).

## Details

**`var = "tx"`** (maximum temperature) rides a physically strong
altitudinal signal (~ -0.6 °C / 100 m). **`var = "rr"`** (precipitation)
is also supported, through the **same KED pipeline** — but the
rain↔elevation relation is noisy and orographic, so `rr` is **less
reliable** (`meta$reliability = "low"`) and its palette sense flips to
`"dry_unfavorable"` (a drying trend is the adverse one — low = red). Fit
for a **regional context** map, not stand-scale precision.

**Method** — regression-kriging (KED): reduce E-OBS to one value per
cell (the target `statistic`), fit the drift
`value ~ dem [+ slope + northness + twi]`, krige the residuals
(variogram auto-fit via automap when present, else a spherical gstat
model), sum drift + kriged residuals on the DEM grid. Without gstat, or
with too few E-OBS cells, it **degrades to trend-only** (drift surface)
— a documented fallback, never an error. The station-based meteoland
engine was removed in 2026.10.17; for a **daily** raster stack (e.g. the
Tmin series feeding
[`indicateur_r7_gel()`](https://pobsteta.github.io/nemeton/reference/indicateur_r7_gel.md)),
use
[`meteoland_daily_grid()`](https://pobsteta.github.io/nemeton/reference/meteoland_daily_grid.md).

## Lifecycle

Deprecated since nemeton 2026.10.16 (spec 063): the reGénération context
map now uses
[`climat_ete_series()`](https://pobsteta.github.io/nemeton/reference/climat_ete_series.md)
and
[`climat_tendance_bivariee()`](https://pobsteta.github.io/nemeton/reference/climat_tendance_bivariee.md)
(total change over the period, native resolution, L'IF n° 49 palette). A
warning is shown once per session; removal is planned once no caller
remains (spec 057).

## References

E-OBS: Cornes et al. (2018). Regression-kriging: Hengl et al. (2007).

## See also

[`tendances_estivales_eobs`](https://pobsteta.github.io/nemeton/reference/tendances_estivales_eobs.md)
