# Create Multi-Period Temporal Dataset

Combines multiple nemeton_units objects from different time periods into
a temporal dataset structure for longitudinal analysis.

## Usage

``` r
nemeton_temporal(periods, dates = NULL, labels = NULL, id_column = NULL)
```

## Arguments

- periods:

  Named list of nemeton_units objects, one per period. Names should be
  period labels (e.g., "2015", "2020") and must be unique. Unnamed
  periods are named after `labels` when usable, otherwise "Period1",
  "Period2", ...

- dates:

  Character vector of ISO dates corresponding to each period (e.g.,
  c("2015-01-01", "2020-01-01")). Optional.

- labels:

  Character vector of descriptive labels for periods (e.g.,
  c("Baseline", "Current")). Optional, defaults to period names.

- id_column:

  Character or NULL. Name of the column containing unit IDs, used to
  align units across periods. If NULL (default), the first of
  `"nemeton_id"` (the identifier carried by nemeton units) and
  `"parcel_id"` present in every period is used; without such a column,
  units are aligned by row position.

## Value

A nemeton_temporal object (list) with components:

- periods:

  List of nemeton_units objects

- metadata:

  List with dates, period_labels, alignment info

## Examples

``` r
if (FALSE) { # \dontrun{
# Load demo data for two periods
data(massif_demo_units)
results_2015 <- nemeton_compute(massif_demo_units, layers_2015, indicators = "C1")
results_2020 <- nemeton_compute(massif_demo_units, layers_2020, indicators = "C1")

# Create temporal dataset
temporal <- nemeton_temporal(
  periods = list("2015" = results_2015, "2020" = results_2020),
  dates = c("2015-01-01", "2020-01-01"),
  labels = c("Baseline", "Current")
)
} # }
```
