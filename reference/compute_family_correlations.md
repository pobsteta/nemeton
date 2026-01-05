# Compute Correlation Matrix Between Family Indices

Calculates pairwise correlations between family composite indices to
identify synergies and trade-offs across ecosystem service dimensions.

## Usage

``` r
compute_family_correlations(units, families = NULL, method = "pearson")
```

## Arguments

- units:

  sf object with computed family indices (family\_\*)

- families:

  Character vector of family column names to analyze. If NULL (default),
  auto-detects all columns starting with "family\_"

- method:

  Correlation method: "pearson" (default), "spearman", or "kendall"

## Value

Correlation matrix (class "matrix") with family names as row/column
names

## Details

The function computes pairwise correlations between selected family
indices to reveal ecological relationships: - \*\*Positive
correlations\*\* suggest synergies (e.g., Biodiversity × Age) -
\*\*Negative correlations\*\* indicate trade-offs (e.g., Protection ×
Risk) - \*\*Near-zero correlations\*\* show independence

Missing values (NA) are handled using pairwise complete observations.

## Bilingual Support

This function supports bilingual messages via
\`nemeton_set_language()\`.

## See also

\[identify_hotspots()\], \[plot_correlation_matrix()\]

Other analysis:
[`identify_hotspots()`](https://pobsteta.github.io/nemeton/reference/identify_hotspots.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Load demo data with family indices
data(massif_demo_units)
units <- massif_demo_units
units$family_B <- runif(nrow(units), 30, 90)
units$family_T <- runif(nrow(units), 40, 85)
units$family_C <- runif(nrow(units), 45, 80)

# Compute correlation matrix
corr_matrix <- compute_family_correlations(units)
print(corr_matrix)

# Use Spearman for non-linear relationships
corr_spearman <- compute_family_correlations(units, method = "spearman")

# Analyze specific families only
corr_subset <- compute_family_correlations(
  units,
  families = c("family_B", "family_T")
)
} # }
```
