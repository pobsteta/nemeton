# Create difference map (change visualization)

Visualizes the difference between two scenarios.

## Usage

``` r
plot_difference_map(
  data1,
  data2,
  indicator,
  type = c("absolute", "relative"),
  palette = "RdBu",
  title = NULL,
  legend_title = NULL,
  ...
)
```

## Arguments

- data1:

  First sf object (baseline)

- data2:

  Second sf object (comparison)

- indicator:

  Indicator column name

- type:

  Character. Type of difference: "absolute" (data2 - data1) or
  "relative" ((data2-data1)/data1 \* 100)

- palette:

  Color palette. Default "RdBu" (diverging red-blue)

- title:

  Plot title

- legend_title:

  Legend title

- ...:

  Additional arguments

## Value

A ggplot object showing differences

## Examples

``` r
if (FALSE) { # \dontrun{
plot_difference_map(
  current_state,
  future_scenario,
  indicator = "carbon",
  type = "relative",
  title = "Carbon Stock Change (%)"
)
} # }
```
