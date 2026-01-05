# Calculate Tree Coverage Buffer Index (A1)

Computes forest coverage percentage within a buffer around each parcel
to assess local air quality and microclimate regulation potential.

## Usage

``` r
indicator_air_coverage(
  units,
  land_cover,
  forest_classes = c(311, 312, 313),
  buffer_radius = 1000
)
```

## Arguments

- units:

  An sf object with forest parcels.

- land_cover:

  A SpatRaster with land cover classification.

- forest_classes:

  Numeric vector. Land cover class codes for forests (e.g., Corine codes
  311, 312, 313). Default c(311, 312, 313).

- buffer_radius:

  Numeric. Buffer radius in meters. Default 1000.

## Value

The input sf object with added column:

- A1: Forest coverage percentage (0-100) within buffer.

## Details

\*\*Formula\*\*: A1 = (forest_area_in_buffer / total_buffer_area) × 100

\*\*Interpretation\*\*:

- 0-20%: Low forest coverage (poor air quality regulation)

- 20-50%: Moderate forest coverage

- 50-80%: Good forest coverage

- 80-100%: Excellent forest coverage (optimal air quality)

## See also

Other air-indicators:
[`indicator_air_quality()`](https://pobsteta.github.io/nemeton/reference/indicator_air_quality.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)
library(terra)

data(massif_demo_units)
units <- massif_demo_units[1:10, ]

land_cover <- rast("path/to/corine_land_cover.tif")

# Calculate A1 with 1km buffer
result <- indicator_air_coverage(units, land_cover = land_cover, buffer_radius = 1000)
summary(result$A1)

# Calculate with 500m buffer
result <- indicator_air_coverage(units, land_cover = land_cover, buffer_radius = 500)
} # }
```
