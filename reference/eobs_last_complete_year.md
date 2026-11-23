# Last complete year covered by an E-OBS version

The last year whose months `months` an E-OBS version covers well enough
for
[`load_eobs_source()`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md)
to keep it (at least `min_frac` of the days; a shorter summer is dropped
there with a warning). Use it to end a window of years on the data
rather than on today's date: version 34.0e ends on 2026-06-30, so its
last complete June–August is 2025 even after 2027-01-01.

## Usage

``` r
eobs_last_complete_year(
  version = "34.0e",
  months = 6:8,
  var = NULL,
  resolution = "0.1deg",
  cache_dir = NULL,
  min_frac = 0.9
)
```

## Arguments

- version:

  E-OBS version, as in
  [`load_eobs_source()`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md)
  (default `"34.0e"`).

- months:

  Months that must be covered (default `6:8`, as in
  [`load_eobs_source()`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md)).

- var:

  E-OBS variable to look for in the cache, or `NULL` (default) for the
  first cached one among `"tx"`, `"tg"`, `"tn"`, `"rr"`. All variables
  of one version end on the same day.

- resolution, cache_dir:

  As in
  [`eobs_cached_file()`](https://pobsteta.github.io/nemeton/reference/eobs_cached_file.md).

- min_frac:

  Share of the days of `months` that must be present (default `0.9`, the
  rule of
  [`load_eobs_source()`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md)).

## Value

An integer year, or `NA_integer_`, with attributes `end_date` (the last
day of the series, a `Date`) and `source` (`"cache"`, `"table"` or
`NA`).

## Details

When the series of a variable of this version is in the cache (see
[`eobs_cached_file()`](https://pobsteta.github.io/nemeton/reference/eobs_cached_file.md)),
its dates are read from the netCDF (`source = "cache"`). Otherwise the
last day is taken from a table of versions whose files were measured
(`source = "table"`: 33.0e and 34.0e). An unknown version with nothing
cached gives `NA` with a warning.

## Lifecycle

Experimental.

## See also

[`load_eobs_source()`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md),
[`eobs_cached_file()`](https://pobsteta.github.io/nemeton/reference/eobs_cached_file.md)

## Examples

``` r
eobs_last_complete_year("34.0e") # 2025: the series stops on 2026-06-30
#> [1] 2025
#> attr(,"end_date")
#> [1] "2026-06-30"
#> attr(,"source")
#> [1] "table"
```
