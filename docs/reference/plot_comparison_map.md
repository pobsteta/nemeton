# Create comparison map (before/after or scenarios)

Compares two sets of indicator values side-by-side.

## Usage

``` r
plot_comparison_map(
  data1,
  data2,
  indicator,
  labels = c("Scenario 1", "Scenario 2"),
  palette = "viridis",
  title = NULL,
  ...
)
```

## Arguments

- data1:

  First sf object (e.g., "before" scenario)

- data2:

  Second sf object (e.g., "after" scenario)

- indicator:

  Character. Indicator column name to compare

- labels:

  Character vector of length 2. Labels for scenarios. Default
  c("Scenario 1", "Scenario 2").

- palette:

  Color palette (same options as plot_indicators_map)

- title:

  Plot title

- ...:

  Additional arguments passed to plot_indicators_map

## Value

A ggplot object with side-by-side comparison

## Examples

``` r
if (FALSE) { # \dontrun{
plot_comparison_map(
  current_state,
  future_scenario,
  indicator = "ecosystem_health",
  labels = c("Current (2024)", "Future (2050)"),
  palette = "RdYlGn"
)
} # }
```
