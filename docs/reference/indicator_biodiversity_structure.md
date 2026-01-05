# Calculate Structural Diversity (B2)

Computes forest structural diversity using Shannon diversity index
applied to canopy strata and age class distributions.

## Usage

``` r
indicator_biodiversity_structure(
  units,
  strata_field = "strata",
  age_class_field = "age_class",
  species_field = NULL,
  method = "shannon",
  weights = c(strata = 0.4, age = 0.3, species = 0.3),
  use_height_cv = FALSE
)
```

## Arguments

- units:

  An sf object with forest parcels.

- strata_field:

  Character. Column name containing canopy strata classes (e.g.,
  "Emergent", "Dominant", "Intermediate", "Suppressed").

- age_class_field:

  Character. Column name containing age classes (e.g., "young",
  "mature", "old", "ancient").

- species_field:

  Character. Optional column name containing species names. If NULL,
  species diversity is not included in calculation. Default NULL.

- method:

  Character. Diversity calculation method. Currently only "shannon" is
  supported.

- weights:

  Named numeric vector. Weights for strata, age, and species components.
  Default c(strata = 0.4, age = 0.3, species = 0.3).

- use_height_cv:

  Logical. If TRUE and strata_field is NULL, use coefficient of
  variation of height as proxy for vertical diversity. Default FALSE.

## Value

The input sf object with added column:

- B2: Structural diversity index (0-100). Higher = more diverse.

## Details

\*\*Formula\*\*: B2 = w1 × H_strata_norm + w2 × H_age_norm

Where H is Shannon diversity index, normalized to 0-100 scale.

\*\*Interpretation\*\*: Multi-layered, multi-age stands score high
(\>75). Monocultures or even-aged stands score low (\<25).

## See also

Other biodiversity-indicators:
[`indicator_biodiversity_connectivity()`](https://pobsteta.github.io/nemeton/reference/indicator_biodiversity_connectivity.md),
[`indicator_biodiversity_protection()`](https://pobsteta.github.io/nemeton/reference/indicator_biodiversity_protection.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)

data(massif_demo_units)
units <- massif_demo_units

# Add structure attributes (normally from BD Forêt)
units$strata <- sample(c("Emergent", "Dominant", "Intermediate"),
                       nrow(units), replace = TRUE)
units$age_class <- sample(c("Young", "Mature", "Old"),
                          nrow(units), replace = TRUE)

result <- indicator_biodiversity_structure(
  units,
  strata_field = "strata",
  age_class_field = "age_class",
  species_field = "species"
)

hist(result$B2, main = "Structural Diversity Distribution")
} # }
```
