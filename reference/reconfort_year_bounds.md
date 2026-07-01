# Bounds for a RECONFORT \`s2_year\` picker

Convenience wrapper returning the \`min\`, \`max\` and \`default\` a UI
year picker should use for \`s2_year\`. \`min\` is the first Sentinel-2
dense-coverage year (2016); \`max\` and \`default\` are both
[`reconfort_latest_complete_year`](https://pobsteta.github.io/nemeton/reference/reconfort_latest_complete_year.md)
so the current, still-incomplete year is neither the default nor
selectable through the bounds.

## Usage

``` r
reconfort_year_bounds(v_model = "v3", today = Sys.Date(), lag_days = 0L)
```

## Arguments

- v_model:

  Model version (see
  [`RECONFORT_MODELS`](https://pobsteta.github.io/nemeton/reference/RECONFORT_MODELS.md)).
  Default \`"v3"\`.

- today:

  Reference date. Default
  [`Sys.Date`](https://rdrr.io/r/base/Sys.time.html); injectable for
  tests.

- lag_days:

  Extra buffer (days) added to the window end date to account for the
  Theia/Sentinel-2 processing latency before the last acquisitions of
  the window are ingestible. Default \`0L\` (the window end date
  itself). Pass a positive value to be conservative.

## Value

A named list of three integers: \`min\`, \`max\`, \`default\`.

## See also

[`reconfort_latest_complete_year`](https://pobsteta.github.io/nemeton/reference/reconfort_latest_complete_year.md)

## Examples

``` r
reconfort_year_bounds("v3", today = as.Date("2026-07-01"))
#> $min
#> [1] 2016
#> 
#> $max
#> [1] 2025
#> 
#> $default
#> [1] 2025
#> 
# $min 2016  $max 2025  $default 2025
```
