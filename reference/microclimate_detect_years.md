# Detect the average / heatwave reference years for R6 (spec 027 §6bis)

Picks the **average** and **heatwave** summers used by
[`indicateur_r6_sensibilite`](https://pobsteta.github.io/nemeton/reference/indicateur_r6_sensibilite.md),
from the E-OBS summer (JJA) heat series over the AOI. Auto-detection is
the default; the result is meant to pre-fill the app's two year
selectors, which the user can override.

## Usage

``` r
microclimate_detect_years(eobs = NULL, aoi = NULL, year_window = NULL,
  lidar_year = NULL)
```

## Arguments

- eobs:

  The E-OBS summer-heat series. A **named numeric**
  (`year -> summer-heat index`, e.g. mean JJA Tmax) is used directly;
  raster/netcdf extraction over `aoi` is deferred (data-bound).

- aoi:

  Optional `sf`/`sfc` AOI (used by the deferred raster path).

- year_window:

  Optional. A single integer `n` (last `n` years) or a `c(from, to)`
  range to restrict the candidate years.

- lidar_year:

  Optional integer; on a tie for the average year, prefer the candidate
  nearest the LiDAR acquisition (limits the frozen-canopy bias).

## Value

A list: `year_moyenne`, `year_canicule` (integers) and `index` (named
numeric, the summer-heat index per candidate year).

## See also

[`indicateur_r6_sensibilite`](https://pobsteta.github.io/nemeton/reference/indicateur_r6_sensibilite.md)
