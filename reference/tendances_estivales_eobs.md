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

  Optional numeric years matching the raster layers (default
  `seq_len(nlyr)`).

- buffer_m:

  Numeric buffer radius in metres around the units. Default `25000`
  (§10.4).

- breaks:

  Optional `list(tmax=, precip=)` of two cut points each for a fixed
  classification; `NULL` → tertiles.

- precomputed:

  Optional pre-built trends: an `sf` with `trend_tmax` / `trend_precip`,
  or a 2-layer `SpatRaster` named `trend_tmax`/`trend_precip`.

- ...:

  Reserved.

## Value

An `sf` of E-OBS cell-centre points within the buffered area, with
`trend_tmax`, `trend_precip`, `classe_tmax`, `classe_precip` (1-3) and
`classe_bivariee` (1-9).

## Details

Trends are the least-squares slope of the per-year summer values against
the year. Classes are tertiles by default (data-driven over the cropped
area), or fixed `breaks`. `classe_bivariee` runs 1-9 with
`(classe_tmax - 1) * 3 + classe_precip`; "hot & dry" is
`classe_tmax == 3 & classe_precip == 1`.

**Data path & degradation**: E-OBS NetCDF is external (research, non
commercial). Supply `tx` / `rr` as per-year summer `SpatRaster`s to
compute the trends, or a `precomputed` result to only crop + classify.
With neither, the function fails cleanly.

## See also

[`indice_priorite_regen`](https://pobsteta.github.io/nemeton/reference/indice_priorite_regen.md)
