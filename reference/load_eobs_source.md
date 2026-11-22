# Acquire E-OBS per-year summer fields (Tmax / precipitation) for an AOI

Build the per-year summer `SpatRaster` (one layer per year, named by
year) that
[`microclimate_detect_years`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md)
and
[`eobs_summer_series`](https://pobsteta.github.io/nemeton/reference/eobs_summer_series.md)
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
  version = "34.0e",
  resolution = "0.1deg",
  period = NULL,
  progress_callback = NULL,
  ...
)
```

## Arguments

- aoi:

  An sf/sfc of the management units (their union crops E-OBS).

- var:

  E-OBS variable: `"tx"` (max temperature, default), `"tg"` (mean
  temperature), `"tn"` (min temperature, since 2026.11.32) or `"rr"`
  (precipitation).

- years:

  Optional integer years to keep (default: all years present).

- months:

  Summer months to reduce over (default `6:8`, JJA). A year with less
  than 90% of the days of these months is dropped with a warning.

- source:

  `"cds"` for the automatic Copernicus download, anything else requires
  `nc`.

- reducer:

  Temporal reducer over the summer days: default `"mean"` for
  `tx`/`tg`/`tn`, `"sum"` for `rr`. Also `"max"`, `"min"`, `"median"`.

- nc:

  A daily E-OBS netCDF path (or a dated `SpatRaster`) to use instead of
  the CDS download.

- cache_dir:

  Persistent directory for the CDS download / unzip. Defaults to
  `file.path(get_global_cache_dir(), "eobs")` so a given series
  (variable × version × resolution) is downloaded **once** and reused on
  later calls (cache-hit, no network). Pass a project-scoped path to
  isolate it.

- version, resolution:

  E-OBS product version (default `"34.0e"`; dots are normalised to the
  CDS underscore form, e.g. `34_0e`) and grid resolution (default
  `"0.1deg"`) for the CDS request. Since November 2026 the CDS delivers
  the **whole series** (1950 onwards) in one file per variable — about
  4.3 GB at 0.1°, 0.8 GB at 0.25° — and requires a licence type:
  `open_data_licence` from version 34.0e, `restricted_research_licence`
  (to accept once on the CDS) for versions 28.0e to 33.0e.

- period:

  Ignored since 2026.11.39: the CDS no longer splits E-OBS into period
  blocks. A non-`NULL` value warns once per session.

- progress_callback:

  Optional function called at each step with a
  `list(current = <key>, ...)` payload (monitoring pattern). Keys:
  `"eobs:cds_request"`, `"eobs:cds_download_done"`, `"eobs:unzip"`,
  `"eobs:read"`, `"eobs:reduce"`, `"eobs:complete"`,
  `"eobs:unavailable"` (`reason`, and `message` = the underlying error).
  The app maps these to bottom-right notifications.

- ...:

  Ignored (forward-compat).

## Value

A per-year summer `SpatRaster` (layers named by year), or `NULL` on
graceful degradation (with a warning carrying the underlying error
message).

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

## See also

[`microclimate_detect_years`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md),
[`eobs_summer_series`](https://pobsteta.github.io/nemeton/reference/eobs_summer_series.md)
