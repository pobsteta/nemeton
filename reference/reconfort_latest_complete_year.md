# Most recent RECONFORT \`s2_year\` whose season is already complete

RECONFORT classifies a pixel's model-bound ~2-year index trajectory; the
analysis window ends at \`s2_year\<edate\>\` (\`10-29\` for the 2-year
models, \`05-31\` for \`v3_early_may\` – see
[`RECONFORT_MODELS`](https://pobsteta.github.io/nemeton/reference/RECONFORT_MODELS.md)).
Running a run for a \`s2_year\` whose window has not fully elapsed
yields a truncated final season and a degraded classification. This
helper returns the latest \`s2_year\` for which the window end date has
already passed, so callers (notably the app's year picker) can default
to – and cap at – a year that produces a complete run.

## Usage

``` r
reconfort_latest_complete_year(v_model = "v3", today = Sys.Date(), lag_days = 0L)
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

A single integer year: the current year when its window end date (plus
\`lag_days\`) is on or before \`today\`, otherwise the previous year.

## See also

[`reconfort_year_bounds`](https://pobsteta.github.io/nemeton/reference/reconfort_year_bounds.md),
[`run_reconfort_dieback`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)

## Examples

``` r
# Oak 2-year model: complete only once 29 Oct of the year has passed.
reconfort_latest_complete_year("v3", today = as.Date("2026-07-01")) # 2025
#> [1] 2025
reconfort_latest_complete_year("v3", today = as.Date("2026-11-15")) # 2026
#> [1] 2026
# early-May model: complete from June onwards.
reconfort_latest_complete_year("v3_early_may", today = as.Date("2026-07-01")) # 2026
#> [1] 2026
```
