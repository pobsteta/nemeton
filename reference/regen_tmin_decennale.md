# Station winter cold (ten-year minimum) from E-OBS

Adds to `units` the ten-year minimum temperature (`tmin_decennale`, °C):
the `prob` quantile (default 0.1, a winter that comes back once in ten
years) of the annual absolute minimum temperatures over `years` (default
1991-2020), read from the E-OBS daily minimum temperature (`tn`, via
[`load_eobs_source()`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md)),
and the number of complete years behind it (`tmin_decennale_n_annees`).
This is the station input of the winter-cold filter of
[`regen_rank_species()`](https://pobsteta.github.io/nemeton/reference/regen_rank_species.md):
a species whose `frost_winter_min_c` is warmer than `tmin_decennale` is
excluded.

Each unit takes the E-OBS cell (0.1°, about 11 km) under a point on its
surface: the value describes the local climate, not the unit itself
(frost hollows can be colder).

## Usage

``` r
regen_tmin_decennale(
  units,
  tn = NULL,
  years = 1991:2020,
  prob = 0.1,
  source = "knmi",
  cache_dir = NULL,
  version = NULL,
  progress_callback = NULL
)
```

## Arguments

- units:

  An `sf` of management units.

- tn:

  Optional daily E-OBS `tn` netCDF path (for instance the full-period
  ECA&D file `tn_ens_mean_0.1deg_reg_v<version>.nc`) or a dated
  `SpatRaster`, used instead of the CDS download.

- years:

  Integer years used (default `1991:2020`). A year with less than 90% of
  its days is dropped.

- prob:

  Quantile of the annual minima (default `0.1`, the ten-year minimum;
  `0` gives the absolute minimum of the period, `0.5` the median).

- source:

  `"knmi"` (default) downloads once the full-period daily file from the
  public KNMI (ECA&D) store into `cache_dir`, as for the E-OBS climate
  context; `"cds"` downloads the Copernicus CDS blocks covering `years`
  through
  [`load_eobs_source()`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md).
  Ignored when `tn` is given.

- cache_dir:

  Directory of the downloaded files (default: the shared machine cache,
  `file.path(get_global_cache_dir(), "eobs")`).

- version:

  E-OBS version (default `"33.0e"` for KNMI, `"30.0e"` for the CDS).

- progress_callback:

  Optional progress callback (see
  [`load_eobs_source()`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md)).

## Value

`units` with `tmin_decennale` (°C, rounded to 0.1) and
`tmin_decennale_n_annees`. When E-OBS is unavailable (warning from
[`load_eobs_source()`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md)),
both are `NA` / `0`, and the filter of
[`regen_rank_species()`](https://pobsteta.github.io/nemeton/reference/regen_rank_species.md)
is skipped.

## Lifecycle

Experimental: may change in any release, without deprecation (spec 057).

## See also

[`regen_rank_species()`](https://pobsteta.github.io/nemeton/reference/regen_rank_species.md),
[`load_eobs_source()`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md),
[`european_species_tolerances()`](https://pobsteta.github.io/nemeton/reference/european_species_tolerances.md)

## Examples

``` r
if (FALSE) { # \dontrun{
  units <- regen_tmin_decennale(units, tn = "tn_ens_mean_0.1deg_reg_v33.0e.nc")
  regen_rank_species(units)
} # }
```
