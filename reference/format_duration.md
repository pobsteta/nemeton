# Format a duration as hours, then minutes, then seconds

Human-facing durations always lead with the largest meaningful unit: a
two-hour run reads \`"2 h 05 min 12 s"\`, never \`"7512 s"\`.
Machine-facing fields (\`duration_sec\`, \`elapsed_sec\` in results and
\`run_meta.json\`) stay in raw seconds — this is for messages only.

## Usage

``` r
format_duration(sec, with_seconds = TRUE)
```

## Arguments

- sec:

  Numeric. Duration in seconds. \`NULL\`, \`NA\` or a negative value
  yields \`"?"\`.

- with_seconds:

  Logical. Keep the seconds component above one minute. \`FALSE\` gives
  the coarser \`"2 h 05 min"\` used in push notifications.

## Value

A character scalar.

## Examples

``` r
format_duration(23)                        # "23 s"
#> [1] "23 s"
format_duration(819)                       # "13 min 39 s"
#> [1] "13 min 39 s"
format_duration(7512)                      # "2 h 05 min 12 s"
#> [1] "2 h 05 min 12 s"
format_duration(7512, with_seconds = FALSE) # "2 h 05 min"
#> [1] "2 h 05 min"
```
