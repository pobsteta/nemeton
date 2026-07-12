# Downscale a daily meteoland variable to a fine raster stack

Interpolate a **daily** meteorological variable (e.g. daily minimum
temperature) from SAFRAN pseudo-stations onto the DEM grid with
meteoland (Thornton 1997 + elevation), returning a `SpatRaster` with one
layer per day and
[`terra::time()`](https://rspatial.github.io/terra/reference/time.html)
set. This is the real-data feeder for
[`indicateur_r7_gel`](https://pobsteta.github.io/nemeton/reference/indicateur_r7_gel.md)
(late-frost risk needs a daily Tmin series) and for any downstream
daily-climate use; the reduced-statistic context map goes through
[`eobs_downscale`](https://pobsteta.github.io/nemeton/reference/eobs_downscale.md)
instead.

meteoland lives in Suggests and is **absent from CI** — like microclimf,
this path is validated on real data. Any failure (package absent, GéoSAS
down, too few stations) returns `NULL`, never an error, so callers
degrade gracefully.

## Usage

``` r
meteoland_daily_grid(
  aoi,
  dem,
  years,
  variable = "MinTemperature",
  dates = NULL,
  doy_range = c(60L, 180L),
  buffer_m = 25000,
  max_cells = 5e5,
  min_stations = 5L,
  calibrate = FALSE,
  ...
)
```

## Arguments

- aoi:

  An `sf`/`sfc` of the management units.

- dem:

  A `SpatRaster` DEM — the target grid; the output shares its CRS.

- years:

  Integer year(s) of the SAFRAN series to interpolate.

- variable:

  meteoland variable to return (default `"MinTemperature"`; also
  `"MaxTemperature"`, `"MeanTemperature"`, `"Precipitation"`, …).

- dates:

  Optional explicit `Date` vector; when `NULL`, the spring window
  (day-of-year `doy_range`) of each year is used — the season that
  matters for late frost.

- doy_range:

  Integer length-2 day-of-year window used when `dates` is `NULL`
  (default `c(60, 180)` ≈ 1 March–end June).

- buffer_m:

  Context buffer (metres) for sampling SAFRAN stations (default 25000).

- max_cells:

  Cell cap for the target grid (default `5e5`).

- min_stations:

  Minimum SAFRAN pseudo-stations required (default 5).

- calibrate:

  Run the (expensive) meteoland LOO calibration first (default `FALSE`).

- ...:

  Ignored (forward-compat).

## Value

A daily `SpatRaster` (one layer per interpolated day,
[`terra::time()`](https://rspatial.github.io/terra/reference/time.html)
set, DEM CRS), ready to pass as `tmin =` to
[`indicateur_r7_gel`](https://pobsteta.github.io/nemeton/reference/indicateur_r7_gel.md);
or `NULL` when unavailable.

## See also

[`eobs_downscale`](https://pobsteta.github.io/nemeton/reference/eobs_downscale.md),
[`indicateur_r7_gel`](https://pobsteta.github.io/nemeton/reference/indicateur_r7_gel.md),
[`build_safran_stations`](https://pobsteta.github.io/nemeton/reference/build_safran_stations.md)
