# Summer E-OBS climate trends over the project area (spec 027 §6, branch A)

Per-cell **summer trend** of maximum temperature and precipitation from
the **E-OBS** grid, over the **union of the units plus a buffer**
(decision §10.4, default 25 km — *not* national), with a **bivariate
classification** (warming × drying) for the reGénération context map
(spec 027 branch A). The core computes the trends and classes; the app
renders the bivariate map.

## Usage

``` r
tendances_estivales_eobs(
  aoi,
  tx = NULL,
  rr = NULL,
  years = NULL,
  buffer_m = 25000,
  breaks = NULL,
  precomputed = NULL,
  ...
)
```

## Arguments

- aoi:

  An `sf`/`sfc` of the management units (their union is buffered).

- tx:

  Per-year summer maximum-temperature `SpatRaster` (one layer per year).
  Engine path.

- rr:

  Per-year summer precipitation `SpatRaster` (one layer per year).

- years:

  Optional numeric years matching the raster layers (default: the years
  of `terra::time(tx)`, else `seq_len(nlyr)`).

- buffer_m:

  Numeric buffer radius in metres around the units. Default `25000`
  (§10.4).

- breaks:

  Optional `list(tmax=, precip=)` of two cut points each for a fixed
  classification, in °C/decade and mm/decade; `NULL` → tertiles.

- precomputed:

  Optional pre-built trends (per decade): an `sf` with `trend_tmax` /
  `trend_precip`, or a 2-layer `SpatRaster` named
  `trend_tmax`/`trend_precip`.

- ...:

  Reserved.

## Value

An `sf` of E-OBS cell-centre points within the buffered area, with
`trend_tmax` (°C/decade), `trend_precip` (mm/decade), `classe_tmax`,
`classe_precip` (1-3) and `classe_bivariee` (1-9).

## Details

Trends are the least-squares slope of the per-year summer values against
the year, expressed **per decade** (°C/decade for `trend_tmax`,
mm/decade for `trend_precip`) — the same unit as
[`eobs_downscale`](https://pobsteta.github.io/nemeton/reference/eobs_downscale.md)
and
[`eobs_trend_fit`](https://pobsteta.github.io/nemeton/reference/eobs_trend_fit.md).
Classes are tertiles by default (data-driven over the cropped area), or
fixed `breaks`. `classe_bivariee` runs 1-9 with
`(classe_tmax - 1) * 3 + classe_precip`; "hot & dry" is
`classe_tmax == 3 & classe_precip == 1`.

**Data path & degradation**: E-OBS NetCDF is external (research, non
commercial). Supply `tx` / `rr` as per-year summer `SpatRaster`s to
compute the trends, or a `precomputed` result to only crop + classify.
With neither, the function fails cleanly.

## Lifecycle

Experimental: may change in any release, without deprecation (spec 057).

## See also

[`indice_priorite_regen`](https://pobsteta.github.io/nemeton/reference/indice_priorite_regen.md)
