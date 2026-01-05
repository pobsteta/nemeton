# Create Family Composite Indices

Aggregates sub-indicators into family-level composite scores (e.g.,
score_carbon, score_water). Automatically detects indicator families
from column name prefixes (C\_, W\_, F\_, L\_, etc.) and computes
weighted averages.

## Usage

``` r
create_family_index(
  data,
  method = c("mean", "weighted", "geometric", "harmonic"),
  weights = NULL,
  na.rm = TRUE,
  family_codes = NULL
)
```

## Arguments

- data:

  An sf object containing indicator columns with family prefixes.

- method:

  Character. Aggregation method: "mean", "weighted", "geometric",
  "harmonic". Default "mean".

- weights:

  Named list of weight vectors per family. E.g.,
  `list(C = c(C1 = 0.6, C2 = 0.4), W = c(W1 = 0.5, W2 = 0.3, W3 = 0.2))`.
  If NULL, equal weights are used.

- na.rm:

  Logical. If TRUE, NA values are removed before aggregation. Default
  TRUE.

- family_codes:

  Character vector. Family codes to process. Default NULL (auto-detect).

## Value

The input sf object with added family\_\* columns (e.g., family_C,
family_W).

## Details

\*\*Family Detection\*\*: Automatically identifies indicators by prefix:

- C1, C2 → Carbon family (family_C)

- W1, W2, W3 → Water family (family_W)

- F1, F2 → Soil fertility family (family_F)

- L1, L2 → Landscape family (family_L)

- B1, B2, B3 → Biodiversity family (family_B)

- And 7 other families (A, T, R, S, P, E, N)

\*\*Aggregation Methods\*\*:

- mean: Simple arithmetic mean

- weighted: Weighted average using provided weights

- geometric: Geometric mean (product^(1/n))

- harmonic: Harmonic mean (n / sum(1/x))

## Examples

``` r
if (FALSE) { # \dontrun{
# Setup multi-family indicators
data(massif_demo_units)
units <- massif_demo_units[1:5, ]
units$C1 <- rnorm(5, 50, 10)  # Carbon biomass
units$C2 <- rnorm(5, 70, 10)  # Carbon NDVI
units$W1 <- rnorm(5, 15, 5)   # Water network

# Create family indices
units_fam <- create_family_index(units)

# With custom weights
units_fam <- create_family_index(
  units,
  weights = list(C = c(C1 = 0.7, C2 = 0.3))
)
} # }
```
