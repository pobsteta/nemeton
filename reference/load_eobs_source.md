# Acquire E-OBS per-year summer fields (Tmax / precipitation) for an AOI

Build the per-year summer `SpatRaster` (one layer per year, named by
year) that
[`microclimate_detect_years`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md)
and
[`tendances_estivales_eobs`](https://pobsteta.github.io/nemeton/reference/tendances_estivales_eobs.md)
consume, from the European E-OBS gridded dataset (ECA&D / Copernicus).
Two paths (spec 034):

- **Injection (`nc`)** — pass a daily E-OBS netCDF path (downloaded from
  the CDS web interface or ECA&D) or a dated `SpatRaster`; the core
  reduces it to summer-per-year. This is the tested contract.

- **CDS (`source = "cds"`)** — best-effort automatic download via ecmwfr
  (dataset `insitu-gridded-observations-europe`, the same CDS key as
  ERA5). Not runnable in CI; validated on real data. Degrades to `NULL`.

## Usage

``` r
load_eobs_source(
  aoi,
  var = "tx",
  years = NULL,
  months = 6:8,
  source = "cds",
  reducer = NULL,
  nc = NULL,
  cache_dir = NULL,
  version = "28.0e",
  resolution = "0.1deg",
  period = NULL,
  ...
)
```

## Arguments

- aoi:

  An sf/sfc of the management units (their union crops E-OBS).

- var:

  E-OBS variable: `"tx"` (max temperature, default), `"tg"` (mean
  temperature) or `"rr"` (precipitation).

- years:

  Optional integer years to keep (default: all years present).

- months:

  Summer months to reduce over (default `6:8`, JJA).

- source:

  `"cds"` for the automatic Copernicus download, anything else requires
  `nc`.

- reducer:

  Temporal reducer over the summer days: default `"mean"` for `tx`/`tg`,
  `"sum"` for `rr`. Also `"max"`, `"median"`.

- nc:

  A daily E-OBS netCDF path (or a dated `SpatRaster`) to use instead of
  the CDS download.

- cache_dir:

  Directory for the CDS download / unzip (default
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html)).

- version, resolution:

  E-OBS product version (default `"28.0e"`) and grid resolution (default
  `"0.1deg"`) for the CDS request.

- period:

  Optional explicit CDS period block (e.g. `"2011_2024"`); inferred from
  `years` when `NULL`.

- ...:

  Ignored (forward-compat).

## Value

A per-year summer `SpatRaster` (layers named by year), or `NULL` on
graceful degradation.

## See also

[`microclimate_detect_years`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md),
[`tendances_estivales_eobs`](https://pobsteta.github.io/nemeton/reference/tendances_estivales_eobs.md)
