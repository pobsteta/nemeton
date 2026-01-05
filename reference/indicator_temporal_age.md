# Calculate Stand Age Index (T1)

Computes stand age from direct age field or establishment year, with
log-scale normalization favoring ancient forests.

## Usage

``` r
indicator_temporal_age(
  units,
  age_field = "age",
  establishment_year_field = NULL,
  current_year = NULL
)
```

## Arguments

- units:

  An sf object with forest parcels.

- age_field:

  Character. Column name with stand age (years). Default "age".

- establishment_year_field:

  Character. Column name with establishment year. Used if age_field is
  NULL.

- current_year:

  Integer. Current year for age calculation from establishment year.
  Default uses current system year.

## Value

The input sf object with added columns:

- T1: Stand age (years)

- T1_norm: Normalized age score (0-100). Log scale, ancient forests
  score high.

## Details

\*\*Formula\*\*: T1 = age (direct) OR current_year - establishment_year

\*\*Normalization\*\*: Log scale to favor ancient forests

- 0-30 years: Young forest (0-30 score)

- 30-100 years: Mature forest (30-60 score)

- 100-200 years: Old forest (60-80 score)

- 200+ years: Ancient forest (80-100 score)

## See also

Other temporal-indicators:
[`indicator_temporal_change()`](https://pobsteta.github.io/nemeton/reference/indicator_temporal_change.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)

data(massif_demo_units)
units <- massif_demo_units
units$age <- runif(nrow(units), 20, 250)

result <- indicator_temporal_age(units, age_field = "age")
summary(result$T1)
summary(result$T1_norm)

# Using establishment year
units$planted <- sample(1850:2000, nrow(units), replace = TRUE)
result <- indicator_temporal_age(units, age_field = NULL, establishment_year_field = "planted", current_year = 2025)
} # }
```
