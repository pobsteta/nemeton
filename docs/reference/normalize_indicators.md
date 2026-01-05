# Normalize indicator values

Transforms indicator values to a common scale for comparison and
aggregation.

## Usage

``` r
normalize_indicators(
  data,
  indicators = NULL,
  method = c("minmax", "zscore", "quantile"),
  suffix = "_norm",
  keep_original = TRUE,
  na.rm = TRUE,
  reference_data = NULL,
  by_family = FALSE
)
```

## Arguments

- data:

  An `sf` object or data.frame containing indicator values

- indicators:

  Character vector of indicator column names to normalize. If NULL,
  auto-detects indicator columns.

- method:

  Character. Normalization method. Options:

  - "minmax" - Min-max normalization to 0-100 scale (default)

  - "zscore" - Z-score standardization (mean=0, sd=1)

  - "quantile" - Quantile normalization (0-100 based on percentile rank)

- suffix:

  Character. Suffix to add to normalized column names. Default "\_norm".

- keep_original:

  Logical. Keep original indicator columns? Default TRUE.

- na.rm:

  Logical. Remove NA values before normalization? Default TRUE.

- reference_data:

  Optional data.frame with reference values for normalization. Useful
  for normalizing new data using parameters from a reference dataset.

- by_family:

  Logical. If TRUE, normalize indicators within each family using
  family-wide parameters (e.g., all Carbon indicators C1, C2 share the
  same min/max). This makes indicators within a family directly
  comparable. Default FALSE.

## Value

The input data with added normalized columns

## Details

**Normalization methods:**

- **Min-max (0-100)**: `norm = (value - min) / (max - min) * 100` -
  Preserves the original distribution shape - Sensitive to outliers -
  Interpretable scale (0 = worst, 100 = best)

- **Z-score**: `norm = (value - mean) / sd` - Centers data around 0 -
  Units in standard deviations - Less sensitive to outliers

- **Quantile**: `norm = percentile_rank * 100` - Robust to outliers -
  Creates uniform distribution - 0 = lowest percentile, 100 = highest

## See also

[`create_composite_index`](https://pobsteta.github.io/nemeton/reference/create_composite_index.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Normalize all indicators with min-max
normalized <- normalize_indicators(
  results,
  indicators = c("carbon", "biodiversity", "water"),
  method = "minmax"
)

# Z-score normalization
normalized_z <- normalize_indicators(
  results,
  method = "zscore",
  suffix = "_z"
)

# Normalize using reference dataset
new_normalized <- normalize_indicators(
  new_data,
  indicators = c("carbon", "water"),
  reference_data = reference_results
)
} # }
```
