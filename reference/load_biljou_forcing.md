# Acquire the BILJOU daily meteorological forcing for an AOI

Produce the `meteo` input of
[`regen_bilan_hydrique`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)
— a daily forcing at the biljouR format (`date`, `doy`, `pet`, `rain`) —
over `years` for `aoi`, from SAFRAN (French primary) or ERA5-Land
(fallback). Acquisition lives in the core (rule \#1); the app only
orchestrates and caches (pattern:
[`load_theia_source`](https://pobsteta.github.io/nemeton/reference/load_theia_source.md),
spec 027 §10.2).

Returns a **named list of per-unit `meteo` data frames** (keyed by the
same sequential ids as
[`regen_bilan_hydrique`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)'s
grid points), directly consumable by `biljou_run_grid()`; or a single
`data.frame` when a shared `raw` series is passed. Degrades to `NULL`
when the source is unavailable (no biljouR, no CDS key, network failure,
AOI outside coverage) so the caller can fall back.

## Usage

``` r
load_biljou_forcing(
  aoi,
  years,
  source = c("safran", "era5"),
  cache_dir = NULL,
  raw = NULL,
  points = NULL,
  latitude = NULL,
  altitude = 0,
  compute_pet = FALSE,
  ...
)
```

## Arguments

- aoi:

  An sf/sfc of the management units (their centroids are sampled).

- years:

  Integer year(s) to fetch.

- source:

  `"safran"` (default, France) or `"era5"` (fallback, mcera5).

- cache_dir:

  Directory for the SAFRAN/ERA5 downloads (default a tempdir).

- raw:

  Optional raw SAFRAN `data.frame` to convert instead of downloading
  (via
  [`safran_to_meteo`](https://pobsteta.github.io/biljouR/reference/safran_to_meteo.html))
  — the tested injection path.

- points:

  Optional pre-built `data.frame(id, lon, lat)` (defaults to the `aoi`
  centroids).

- latitude, altitude:

  Site latitude/altitude for PET when `raw`/ERA5 need a Penman estimate
  (`latitude` defaults to the AOI centroid).

- compute_pet:

  Passed to
  [`safran_to_meteo`](https://pobsteta.github.io/biljouR/reference/safran_to_meteo.html)
  for the `raw` path.

- ...:

  Passed to
  [`safran_download`](https://pobsteta.github.io/biljouR/reference/safran_download.html).

## Value

A per-unit named list of `meteo` data frames (or a single `data.frame`),
or `NULL` on graceful degradation.

## See also

[`regen_bilan_hydrique`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md),
[`build_biljou_soil`](https://pobsteta.github.io/nemeton/reference/build_biljou_soil.md)
