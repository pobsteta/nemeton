# Plot Temporal Heatmap

Creates a heatmap showing all indicator values across periods for a
specific unit.

## Usage

``` r
plot_temporal_heatmap(
  temporal,
  unit_id,
  indicators = NULL,
  id_column = "parcel_id",
  normalize = FALSE,
  title = NULL
)
```

## Arguments

- temporal:

  A nemeton_temporal object created by
  [`nemeton_temporal`](https://pobsteta.github.io/nemeton/reference/nemeton_temporal.md).

- unit_id:

  Character. ID of the unit to visualize.

- indicators:

  Character vector of indicators to include. Default NULL uses all.

- id_column:

  Character. Column containing unit IDs. Default "parcel_id".

- normalize:

  Logical. If TRUE, normalize indicators to 0-100 scale. Default FALSE.

- title:

  Character. Plot title. Default auto-generated.

## Value

A ggplot object

## Examples

``` r
if (FALSE) { # \dontrun{
# Create temporal dataset
temporal <- nemeton_temporal(
  periods = list("2015" = units_2015, "2020" = units_2020),
  id_column = "parcel_id"
)

# Plot heatmap for unit P1
plot_temporal_heatmap(temporal, unit_id = "P1")

# With normalization
plot_temporal_heatmap(temporal, unit_id = "P1", normalize = TRUE)
} # }
```
