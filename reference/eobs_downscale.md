# Downscale an E-OBS variable to a fine raster

Turn the coarse E-OBS grid (~0.1°, ~11 km) into a fine continuous
`SpatRaster` over the project's regional context, using the DEM (and
terrain covariates) as external drift. Built for the "regional context"
map of the reGénération tab — **not** stand-scale precision, which
[`microclimate_run`](https://pobsteta.github.io/nemeton/reference/microclimate_run.md)
already produces from microclimf + HD LiDAR.

## Usage

``` r
eobs_downscale(
  var = c("tx", "rr"),
  eobs,
  dem,
  aoi,
  engine = c("ked", "meteoland"),
  buffer_m = 25000,
  resolution = NULL,
  covariates = c("dem", "slope", "aspect", "twi"),
  statistic = c("trend", "mean", "value"),
  variogram_model = NULL,
  years = NULL,
  max_cells = 5e+05,
  min_points = 10L,
  cache_path = NULL,
  calibrate = FALSE,
  cv = FALSE,
  ...
)
```

## Arguments

- var:

  `"tx"` (v1). `"rr"` returns an out-of-scope status.

- eobs:

  A `SpatRaster` of E-OBS: one layer per year (for
  `statistic = "trend"`/`"mean"`) or a single reduced layer
  (`statistic = "value"`).

- dem:

  A `SpatRaster` DEM — the downscaling target grid and main covariate.
  The output shares its CRS.

- aoi:

  An `sf`/`sfc` of the management units, buffered to frame the regional
  context.

- engine:

  `"ked"` (default, regression-kriging) or `"meteoland"` (station
  interpolator; falls back to KED when unavailable).

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

- calibrate:

  `engine = "meteoland"` only: run the (expensive) meteoland LOO
  calibration before interpolating (default `FALSE`, default params).

- cv:

  `engine = "meteoland"` only: compute leave-one-out cross-validation
  and return it in `meta$cv` (`r2`, `mae_tmin`, `mae_tmax`); default
  `FALSE` (expensive). KED always reports `meta$cv = NULL`.

- ...:

  Ignored (forward-compat).

## Value

A list `list(raster, meta)`. `raster` is a single-layer `SpatRaster` in
the DEM CRS, or `NULL` when degraded to nothing. `meta` carries the
**output contract** the app renders against: `status`
(`"ok"`/`"out_of_scope"`/`"insufficient_data"`), `engine` (the engine
that actually ran), `method` (`"ked"`/`"trend_only"`), `var`,
`statistic`, `crs` (EPSG code), `unit` (e.g. `"°C/decade"`),
`value_label`, `palette` (`low`/`high` quantile bounds and
`sense = "hot_unfavorable"` — high = warmer = red, per the app's
red-is-critical rule), `n_points`, and, when degraded, `reason` (i18n
key).

## Details

**v1 covers `tx` (maximum temperature) only** — a physically justified
altitudinal signal (~ -0.6 °C / 100 m). `rr` (precipitation) is out of
scope (unreliable downscaling; the DEM only helps in mountains).
`var = "rr"` returns a status, not a raster.

**Two engines, one contract** (microclimat brief §8):

- `engine = "ked"` (default) — regression-kriging: reduce E-OBS to one
  value per cell (the target `statistic`), fit the drift
  `value ~ dem [+ slope + northness + twi]`, krige the residuals
  (variogram auto-fit via automap when present, else a spherical gstat
  model), sum drift + kriged residuals on the DEM grid. Without gstat,
  or with too few E-OBS cells, it **degrades to trend-only** (drift
  surface) — a documented fallback, never an error.

- `engine = "meteoland"` — the station-based interpolator (meteoland,
  Thornton 1997 + elevation, microclimat brief Option A / chantier P4).
  It interpolates the **daily** SAFRAN pseudo-station series (from
  [`build_safran_stations`](https://pobsteta.github.io/nemeton/reference/build_safran_stations.md))
  onto the DEM grid, aggregates each summer to an annual max, then
  reduces to the requested `statistic` — same output contract as KED,
  plus a `meta$cv` cross-validation block. Whenever meteoland is absent,
  GéoSAS is down, or too few pseudo-stations resolve, it **falls back to
  KED**, so the caller never branches on the engine. For a **daily**
  raster stack (e.g. the Tmin series feeding
  [`indicateur_r7_gel`](https://pobsteta.github.io/nemeton/reference/indicateur_r7_gel.md)),
  use
  [`meteoland_daily_grid`](https://pobsteta.github.io/nemeton/reference/meteoland_daily_grid.md)
  instead of a reduced statistic.

## References

E-OBS: Cornes et al. (2018). Regression-kriging: Hengl et al. (2007).
meteoland: De Cáceres et al. (2018).

## See also

[`tendances_estivales_eobs`](https://pobsteta.github.io/nemeton/reference/tendances_estivales_eobs.md),
[`microclimate_run`](https://pobsteta.github.io/nemeton/reference/microclimate_run.md)
