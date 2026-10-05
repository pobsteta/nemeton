# Aggregate family scores over a set of units

Reduces the per-unit family scores (\`famille\_\*\` columns of
\[create_family_index()\]) to one score per family for the whole
project, the input of \[compute_general_index()\].

With \`weights = "surface"\` (default) each unit weighs by its area, so
a 0.5 ha unit no longer counts as much as a 50 ha one. The area is read
from \`surface_col\`, or computed from the geometry of an \`sf\` object
when the column is absent. When no usable area is available (missing,
\`NA\`, or not strictly positive for some unit), the function falls back
to the simple mean and says so. Within each family, units whose score is
\`NA\` are left out and the remaining weights renormalised.

## Usage

``` r
aggregate_family_scores(
  units,
  weights = c("surface", "none"),
  surface_col = "surface_m2",
  family_pattern = "^famille_[a-z]"
)
```

## Arguments

- units:

  An \`sf\` object or \`data.frame\` with \`famille\_\*\` columns.

- weights:

  \`"surface"\` (default) or \`"none"\` (simple mean, the historical
  behaviour of the app).

- surface_col:

  Character(1). Column holding the unit area. Default \`"surface_m2"\`.

- family_pattern:

  Regular expression selecting the family columns. Default
  \`"^famille\_\[a-z\]"\`.

## Value

A named numeric vector, one score per family column (\`NA\` for a family
with no scored unit); \`numeric(0)\` when there is no family column.
Attribute \`"weighting"\`: \`"surface"\` or \`"none"\`, the weighting
actually applied.

## Examples

``` r
u <- data.frame(famille_carbone = c(80, 20), surface_m2 = c(450000, 5000))
aggregate_family_scores(u)                    # ~79.3, the large unit dominates
#> famille_carbone 
#>        79.34066 
#> attr(,"weighting")
#> [1] "surface"
aggregate_family_scores(u, weights = "none")  # 50
#> famille_carbone 
#>              50 
#> attr(,"weighting")
#> [1] "none"
```
