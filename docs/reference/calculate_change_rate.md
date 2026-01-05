# Calculate Change Rates Between Periods

Computes annual change rates (absolute and relative) for indicators
across temporal periods.

## Usage

``` r
calculate_change_rate(
  temporal,
  indicators = "all",
  period_start = NULL,
  period_end = NULL,
  type = c("both", "absolute", "relative")
)
```

## Arguments

- temporal:

  A nemeton_temporal object created by
  [`nemeton_temporal`](https://pobsteta.github.io/nemeton/reference/nemeton_temporal.md).

- indicators:

  Character vector of indicator names to analyze. Default "all" uses all
  indicators present in the temporal dataset.

- period_start:

  Character. Label of starting period. Default uses first period.

- period_end:

  Character. Label of ending period. Default uses last period.

- type:

  Character. Type of change rate: "absolute", "relative", or "both".
  Default "both".

## Value

A nemeton_units sf object with added columns:

- \<indicator\>\_rate_abs:

  Absolute change per year (e.g., tC/ha/year)

- \<indicator\>\_rate_rel:

  Relative change per year (%/year)

## Examples

``` r
if (FALSE) { # \dontrun{
# Calculate carbon change rates
rates <- calculate_change_rate(
  temporal,
  indicators = c("C1", "W3"),
  type = "both"
)

# View change rates
summary(rates[, c("C1_rate_abs", "C1_rate_rel")])
} # }
```
