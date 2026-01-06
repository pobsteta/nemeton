# Identify Pareto Optimal Solutions

Identifies parcels that are Pareto optimal (non-dominated) across
multiple objectives. A parcel is Pareto optimal if no other parcel
performs better on all objectives simultaneously. This function supports
both maximization and minimization objectives.

## Usage

``` r
identify_pareto_optimal(
  data,
  objectives,
  maximize = rep(TRUE, length(objectives))
)
```

## Arguments

- data:

  An sf object or data.frame containing the parcels to analyze

- objectives:

  Character vector of column names representing the objectives to
  optimize (e.g., `c("family_C", "family_B", "family_P")`)

- maximize:

  Logical vector of same length as `objectives`, indicating whether each
  objective should be maximized (`TRUE`) or minimized (`FALSE`). Default
  is to maximize all objectives.

## Value

The input data with an additional `is_optimal` logical column indicating
whether each parcel is Pareto optimal. If input is sf object, output
preserves the sf class and geometry.

## Details

\## Pareto Dominance

For maximization objectives: - Parcel A dominates parcel B if A ≥ B on
all objectives AND A \> B on at least one objective

For minimization objectives: - Parcel A dominates parcel B if A ≤ B on
all objectives AND A \< B on at least one objective

A parcel is \*\*Pareto optimal\*\* if it is not dominated by any other
parcel.

\## Applications

Pareto analysis is useful for: - Multi-criteria decision making (e.g.,
balancing production vs conservation) - Identifying trade-off frontiers
between ecosystem services - Selecting parcels for diverse management
objectives - Benchmarking parcel performance across multiple dimensions

## Examples

``` r
if (FALSE) { # \dontrun{
# Load demo dataset
data("massif_demo_units_extended")

# Find parcels that are optimal for carbon, biodiversity, and production
result <- identify_pareto_optimal(
  massif_demo_units_extended,
  objectives = c("family_C", "family_B", "family_P"),
  maximize = c(TRUE, TRUE, TRUE)
)

# How many are Pareto optimal?
sum(result$is_optimal)

# Mixed objectives: maximize carbon and biodiversity, minimize fire risk
result_mixed <- identify_pareto_optimal(
  massif_demo_units_extended,
  objectives = c("family_C", "family_B", "family_R"),
  maximize = c(TRUE, TRUE, FALSE)
)

# Visualize optimal parcels
library(ggplot2)
ggplot(result, aes(x = family_C, y = family_B, color = is_optimal)) +
  geom_point(size = 3) +
  scale_color_manual(values = c("gray", "red")) +
  labs(title = "Pareto Optimal Parcels",
       x = "Carbon Storage", y = "Biodiversity")
} # }
```
