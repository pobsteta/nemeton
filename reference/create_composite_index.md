# Create composite index from multiple indicators

Aggregates normalized indicators into a single composite score.

## Usage

``` r
create_composite_index(
  data,
  indicators,
  weights = NULL,
  name = "composite_index",
  aggregation = c("weighted_mean", "geometric_mean", "min", "max"),
  na.rm = TRUE,
  scale_to_100 = NULL
)
```

## Arguments

- data:

  An `sf` object or data.frame with normalized indicators

- indicators:

  Character vector of indicator column names to include

- weights:

  Numeric vector of weights for each indicator (same length as
  indicators). If NULL, equal weights are used. Weights are
  automatically normalized to sum to 1.

- name:

  Character. Name for the composite index column. Default
  "composite_index".

- aggregation:

  Character. Aggregation method. Options:

  - "weighted_mean" - Weighted arithmetic mean (default)

  - "geometric_mean" - Weighted geometric mean (good for multiplicative
    effects)

  - "min" - Minimum value (conservative, limiting factor approach)

  - "max" - Maximum value (optimistic)

- na.rm:

  Logical. Remove NA values in aggregation? Default TRUE.

- scale_to_100:

  Logical. Scale result to 0-100? Default TRUE for weighted_mean, FALSE
  otherwise.

## Value

The input data with an added composite index column

## Details

The composite index combines multiple normalized indicators into a
single score.

**Aggregation methods:**

- **Weighted mean**: Standard linear combination, assumes indicators
  contribute additively

- **Geometric mean**: Better for indicators with multiplicative
  relationships

- **Min**: Conservative approach, final score limited by weakest
  indicator

- **Max**: Optimistic approach, final score driven by strongest
  indicator

**Weights** are normalized internally to sum to 1. For example:
`weights = c(2, 1, 1)` becomes `c(0.5, 0.25, 0.25)`

## See also

[`normalize_indicators`](https://pobsteta.github.io/nemeton/reference/normalize_indicators.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Equal weights
results <- create_composite_index(
  normalized_data,
  indicators = c("carbon_norm", "biodiversity_norm", "water_norm")
)

# Custom weights (carbon 50\%, biodiversity 30\%, water 20\%)
results <- create_composite_index(
  normalized_data,
  indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
  weights = c(0.5, 0.3, 0.2),
  name = "ecosystem_health"
)

# Geometric mean for multiplicative effects
results <- create_composite_index(
  normalized_data,
  indicators = c("carbon_norm", "water_norm"),
  aggregation = "geometric_mean"
)

# Limiting factor approach
results <- create_composite_index(
  normalized_data,
  indicators = c("carbon_norm", "biodiversity_norm"),
  aggregation = "min",
  name = "conservation_potential"
)
} # }
```
