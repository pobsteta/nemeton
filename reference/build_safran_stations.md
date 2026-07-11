# Build the SAFRAN pseudo-station grid for the meteoland engine (spec P4)

Sample SAFRAN cells over the AOI + buffer as **pseudo-stations** for the
meteoland interpolator: a point grid at `spacing_m` (SAFRAN ~8 km), each
point carrying its DEM elevation and its daily SAFRAN series (fetched
from the same GéoSAS OGC API-EDR already used for BILJOU). SAFRAN is a
gridded reanalysis, not a station network, but that is exactly what
meteoland needs as reference — see the P4 brief. The data source is thus
already wired; no new one.

## Usage

``` r
build_safran_stations(aoi, buffer_m, years, dem, spacing_m = 8000, fetch = NULL)
```

## Arguments

- aoi:

  An `sf`/`sfc` of the management units.

- buffer_m:

  Context buffer (metres) sampled around the AOI.

- years:

  Integer year(s) of the SAFRAN series.

- dem:

  A `SpatRaster` DEM, sampled for each point's `elevation`.

- spacing_m:

  Pseudo-station grid step in metres (default 8000, SAFRAN resolution).

- fetch:

  Acquisition function (for testing); defaults to the internal GéoSAS
  SAFRAN reader. Signature `function(points, years)` returning a named
  list of raw daily data frames keyed by `points$id`.

## Value

A list `list(points, series)`: `points` an `sf` of pseudo-stations
(`id`, `elevation`, geometry in the DEM CRS) restricted to those with a
non-empty series and a finite elevation; `series` the matching named
list. `NULL` if none resolve.

## See also

[`eobs_downscale`](https://pobsteta.github.io/nemeton/reference/eobs_downscale.md),
[`load_biljou_forcing`](https://pobsteta.github.io/nemeton/reference/load_biljou_forcing.md)
