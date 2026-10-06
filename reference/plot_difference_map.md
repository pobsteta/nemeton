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
  id_column = NULL,
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

- id_column:

  Character or NULL. Identifier column shared by `data1` and `data2`,
  used to align units before subtracting. If NULL (default), the first
  of `"nemeton_id"`, `"parcel_id"`, `"id"` present in both is used.
  Without a shared identifier, both datasets must have the same number
  of rows and are aligned by position. Units of `data1` without a match
  get a NA difference (with a warning).

- ...:

  Additional arguments

## Value

A ggplot object showing differences

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

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
