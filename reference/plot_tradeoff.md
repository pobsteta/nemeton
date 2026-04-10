# Plot Trade-off Analysis Between Two Objectives

Creates a 2D scatterplot visualizing trade-offs between two ecosystem
service families or indicators. Optionally overlays the Pareto optimal
frontier to highlight non-dominated solutions.

## Usage

``` r
plot_tradeoff(
  data,
  x,
  y,
  color = NULL,
  size = NULL,
  pareto_frontier = FALSE,
  label = NULL,
  xlab = NULL,
  ylab = NULL,
  title = NULL
)
```

## Arguments

- data:

  An sf object or data.frame containing the parcels to visualize

- x:

  Character string specifying the column name for the x-axis variable

- y:

  Character string specifying the column name for the y-axis variable

- color:

  Optional character string specifying a column for color mapping (e.g.,
  to show a third dimension)

- size:

  Optional character string specifying a column for size mapping

- pareto_frontier:

  Logical indicating whether to overlay the Pareto optimal frontier.
  Requires an `is_optimal` column in the data (default: `FALSE`)

- label:

  Optional character string specifying column for point labels

- xlab:

  Custom x-axis label (default: variable name)

- ylab:

  Custom y-axis label (default: variable name)

- title:

  Custom plot title (default: auto-generated)

## Value

A ggplot2 object that can be further customized or printed

## Details

\## Trade-off Analysis

Trade-off plots reveal relationships between ecosystem services: -
\*\*Synergies\*\*: Both variables increase together (positive
correlation) - \*\*Trade-offs\*\*: One increases while the other
decreases (negative correlation) - \*\*No relationship\*\*: Variables
are independent

\## Pareto Frontier

When `pareto_frontier = TRUE`, Pareto optimal parcels are highlighted
and connected to show the efficiency frontier. These parcels represent
the best possible trade-offs - improving one objective requires
sacrificing another.

\## Visualization Tips

\- Use `color` to add a third dimension (e.g., color by fire risk) - Use
`size` to emphasize important parcels (e.g., size by area) - Use `label`
to identify specific parcels of interest - Combine with faceting for
multi-scenario comparisons

## Examples

``` r
if (FALSE) { # \dontrun{
# Load demo dataset
data("massif_demo_units")

# Basic trade-off plot: carbon vs biodiversity
plot_tradeoff(
  massif_demo_units,
  x = "famille_carbone",
  y = "famille_biodiversite"
)

# Add color for a third dimension (production)
plot_tradeoff(
  massif_demo_units,
  x = "famille_carbone",
  y = "famille_biodiversite",
  color = "famille_production",
  title = "Carbon-Biodiversity Trade-off (colored by Production)"
)

# Overlay Pareto frontier
result <- identify_pareto_optimal(
  massif_demo_units,
  objectives = c("famille_carbone", "famille_biodiversite", "famille_production"),
  maximize = rep(TRUE, 3)
)

plot_tradeoff(
  result,
  x = "famille_carbone",
  y = "famille_biodiversite",
  pareto_frontier = TRUE
)

# With labels for Pareto optimal parcels
plot_tradeoff(
  result,
  x = "famille_carbone",
  y = "famille_biodiversite",
  pareto_frontier = TRUE,
  label = "name"
)

# Multiple trade-off comparisons
library(patchwork)
p1 <- plot_tradeoff(massif_demo_units, "famille_carbone", "famille_biodiversite")
p2 <- plot_tradeoff(massif_demo_units, "famille_carbone", "famille_production")
p3 <- plot_tradeoff(massif_demo_units, "famille_biodiversite", "famille_production")
p1 + p2 + p3
} # }
```
