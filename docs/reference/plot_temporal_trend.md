# Plot Temporal Trend (Time-Series)

Creates line plots showing indicator evolution over time periods.

## Usage

``` r
plot_temporal_trend(
  temporal,
  indicator,
  units = NULL,
  id_column = "parcel_id",
  title = NULL,
  show_mean = FALSE
)
```

## Arguments

- temporal:

  A nemeton_temporal object created by
  [`nemeton_temporal`](https://pobsteta.github.io/nemeton/reference/nemeton_temporal.md).

- indicator:

  Character vector of one or more indicator names to plot.

- units:

  Character vector of unit IDs to include. Default NULL uses all units.

- id_column:

  Character. Column containing unit IDs. Default "parcel_id".

- title:

  Character. Plot title. Default auto-generated.

- show_mean:

  Logical. If TRUE, adds mean trend line. Default FALSE.

## Value

A ggplot object

## Examples

``` r
if (FALSE) { # \dontrun{
# Create temporal dataset
temporal <- nemeton_temporal(
  periods = list("2015" = units_2015, "2020" = units_2020)
)

# Plot carbon trend
plot_temporal_trend(temporal, indicator = "C1")

# Multiple indicators
plot_temporal_trend(temporal, indicator = c("C1", "W1"))
} # }
```
