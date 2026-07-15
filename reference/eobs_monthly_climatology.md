# Monthly E-OBS climatology at a point (month -\> value)

Twelve-month climatology (averaged over `years`) of an E-OBS variable at
a location, for the ombrothermic (Gaussen-Bagnouls) diagram — chart 4 of
the regional-context click panel (spec 036). Precipitation is summed
within each month then averaged across years (mm/month); temperature is
the monthly mean (°C). Reads the full-year daily field (a `SpatRaster`
with
[`terra::time`](https://rspatial.github.io/terra/reference/time.html)
set, or a cached netCDF path), so tx/rr need no new acquisition; the
Gaussen diagram proper wants mean temperature (`tg`), which has its own
netCDF (spec 036 §5.4).

## Usage

``` r
eobs_monthly_climatology(daily, point, var, years = NULL)
```

## Arguments

- daily:

  A daily E-OBS `SpatRaster` (full year,
  [`terra::time`](https://rspatial.github.io/terra/reference/time.html)
  set), or a path to the cached daily netCDF.

- point:

  An `sf`/`sfc` POINT, or `c(lon, lat)` in EPSG:4326.

- var:

  `"rr"` (monthly precipitation sum, mm) or `"tg"`/`"tx"` (monthly mean
  temperature, °C). Drives the within-month reducer.

- years:

  Optional integer years to average over (default: all present).

## Value

A `data.frame(month = 1:12, value)` (all twelve months, `NA` where a
month has no data). Attributes: `var`, `unit`, `reducer`.

## See also

[`eobs_summer_series`](https://pobsteta.github.io/nemeton/reference/eobs_summer_series.md),
[`load_eobs_source`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md)

## Examples

``` r
if (FALSE) { # \dontrun{
eobs_monthly_climatology("eobs_tg_daily.nc", c(6.1, 48.7), var = "tg")
} # }
```
