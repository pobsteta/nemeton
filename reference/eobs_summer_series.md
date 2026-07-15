# Summer E-OBS series at a point (year -\> value)

Extract the per-year summer (JJA) E-OBS value at a location, feeding
charts 1-3 of the regional-context click panel (spec 036): annual
series + trend line, annual anomalies, and regional distribution.
Reduction and acquisition already live in
[`load_eobs_source`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md);
this only extracts the per-year stack at `point`, so the app can pass an
already-loaded stack and answer every click without re-reducing the
daily netCDF.

## Usage

``` r
eobs_summer_series(stack, point)
```

## Arguments

- stack:

  A per-year summer `SpatRaster` (one layer per year, named by year), as
  returned by
  [`load_eobs_source`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md).

- point:

  An `sf`/`sfc` POINT, or `c(lon, lat)` in EPSG:4326 (the leaflet
  click).

## Value

A `data.frame(year, value)`, one row per layer ordered by year, NA-safe
(a masked/out-of-extent point yields `NA` values). Attributes: `var`,
`unit`. `var` is read from the stack's `varnames` when present.

## See also

[`eobs_monthly_climatology`](https://pobsteta.github.io/nemeton/reference/eobs_monthly_climatology.md),
[`eobs_trend_fit`](https://pobsteta.github.io/nemeton/reference/eobs_trend_fit.md),
[`load_eobs_source`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md)

## Examples

``` r
if (FALSE) { # \dontrun{
stk <- load_eobs_source(aoi, var = "tx", nc = "eobs_tx.nc", source = "nc")
eobs_summer_series(stk, c(6.1, 48.7))
} # }
```
