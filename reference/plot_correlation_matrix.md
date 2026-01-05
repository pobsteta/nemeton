# Plot Correlation Matrix Heatmap

Visualizes pairwise correlations between family indices as a heatmap
with color-coded correlation coefficients.

## Usage

``` r
plot_correlation_matrix(
  corr_matrix,
  method = "circle",
  title = NULL,
  palette = "RdBu"
)
```

## Arguments

- corr_matrix:

  Correlation matrix from \[compute_family_correlations()\]

- method:

  Display method: "circle" (default), "square", "number", or "color"

- title:

  Plot title. If NULL, generates automatic title

- palette:

  Color palette: "RdBu" (default, red-blue diverging) or "viridis"

## Value

ggplot2 object

## Details

Creates a publication-ready correlation heatmap with: - Color intensity
proportional to correlation strength - Diverging palette (blue =
negative, red = positive) - Correlation coefficients displayed on
cells - Hierarchical clustering (optional)

\*\*Interpretation\*\*: - \*\*Strong positive\*\* (red, \>0.5):
Synergies (services co-occur) - \*\*Strong negative\*\* (blue, \<-0.5):
Trade-offs (services conflict) - \*\*Weak\*\* (white, ~0): Independence

## Bilingual Support

This function supports bilingual labels via \`nemeton_set_language()\`.

## See also

\[compute_family_correlations()\], \[identify_hotspots()\]

## Examples

``` r
if (FALSE) { # \dontrun{
# Compute correlations
data(massif_demo_units)
units <- massif_demo_units
units$family_B <- runif(nrow(units), 30, 90)
units$family_T <- runif(nrow(units), 40, 85)
units$family_C <- runif(nrow(units), 45, 80)

corr_matrix <- compute_family_correlations(units)

# Plot correlation heatmap
plot_correlation_matrix(corr_matrix)

# Customize appearance
plot_correlation_matrix(
  corr_matrix,
  method = "number",
  title = "Ecosystem Service Synergies & Trade-offs"
)
} # }
```
