# Calculate Tree Coverage Buffer Index (A1)

Computes forest coverage percentage within a buffer around each parcel
to assess local air quality and microclimate regulation potential.

## Usage

``` r
indicateur_a1_couverture(
  units,
  land_cover = NULL,
  forest_classes = c(16, 17, 18),
  buffer_radius = 1000,
  fvc = NULL
)
```

## Arguments

- units:

  An sf object with forest parcels.

- land_cover:

  A SpatRaster with land cover classification. Required in legacy mode;
  may be `NULL` when `fvc` is supplied.

- forest_classes:

  Numeric vector. Land cover class codes for forests (OSO codes: 16 =
  coniferous, 17 = broadleaf, 18 = mixed). Default c(16, 17, 18).

- buffer_radius:

  Numeric. Buffer radius in meters. Default 1000.

- fvc:

  Optional `SpatRaster` of Fractional Vegetation Cover in `[0, 1]`
  (typically the Theia `s2_biophysical` FVC product, loaded via
  [`load_raster_source`](https://pobsteta.github.io/nemeton/reference/load_raster_source.md)).
  When supplied, activates FVC mode: A1 is the per-buffer mean FVC
  rescaled to a 0-100 percentage, and `land_cover` is ignored. The
  raster is expected in the CRS of `units`.

## Value

The input sf object with added column:

- A1: Forest coverage percentage (0-100) within buffer.

## Details

\*\*Formula\*\* (legacy mode): A1 = (forest_area_in_buffer /
total_buffer_area) × 100

\*\*FVC mode\*\* (Theia `s2_biophysical`, phase 3a): A1 = mean(FVC) ×
100 over the buffer.

\*\*Interpretation\*\*:

- 0-20%: Low forest coverage (poor air quality regulation)

- 20-50%: Moderate forest coverage

- 50-80%: Good forest coverage

- 80-100%: Excellent forest coverage (optimal air quality)

## See also

Other air-indicators:
[`indicateur_a2_qualite_air()`](https://pobsteta.github.io/nemeton/reference/indicateur_a2_qualite_air.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)
library(terra)

data(massif_demo_units)
units <- massif_demo_units[1:10, ]

land_cover <- rast("path/to/corine_land_cover.tif")

# Calculate A1 with 1km buffer
result <- indicateur_a1_couverture(units, land_cover = land_cover, buffer_radius = 1000)
summary(result$A1)

# Calculate with 500m buffer
result <- indicateur_a1_couverture(units, land_cover = land_cover, buffer_radius = 500)
} # }
```
