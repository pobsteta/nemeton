# Calculate Land Cover Change Rate Index (T2)

Computes annualized land cover change rate from multi-date rasters
(e.g., Corine Land Cover).

## Usage

``` r
indicator_temporal_change(
  units,
  land_cover_early,
  land_cover_late,
  years_elapsed,
  interpretation = "stability"
)
```

## Arguments

- units:

  An sf object with forest parcels.

- land_cover_early:

  A SpatRaster with early land cover classification.

- land_cover_late:

  A SpatRaster with late land cover classification.

- years_elapsed:

  Numeric. Number of years between the two land cover dates.

- interpretation:

  Character. How to interpret change:

  - "stability" (default): Low change = high score (conservation)

  - "dynamism": High change = high score (ecological dynamism)

## Value

The input sf object with added columns:

- T2: Annualized change rate (%/year)

- T2_norm: Normalized score (0-100). Depends on interpretation.

## Details

\*\*Formula\*\*: T2 = (changed_pixels / total_pixels) / years_elapsed ×
100

\*\*Normalization\*\*:

- stability: 0% change/yr = 100, 5%+ change/yr = 0

- dynamism: 0% change/yr = 0, 5%+ change/yr = 100

## See also

Other temporal-indicators:
[`indicator_temporal_age()`](https://pobsteta.github.io/nemeton/reference/indicator_temporal_age.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)
library(terra)

data(massif_demo_units)
units <- massif_demo_units[1:10, ]

lc_1990 <- rast("path/to/corine_1990.tif")
lc_2020 <- rast("path/to/corine_2020.tif")

# Stability interpretation (conservation)
result <- indicator_temporal_change(units, lc_1990, lc_2020, years_elapsed = 30, interpretation = "stability")
summary(result$T2)

# Dynamism interpretation (ecological change)
result <- indicator_temporal_change(units, lc_1990, lc_2020, years_elapsed = 30, interpretation = "dynamism")
} # }
```
