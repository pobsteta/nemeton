# Erosion Risk Index (F2)

Calculates erosion risk by combining slope (from DEM) with land cover
protection. Higher values indicate greater erosion risk.

## Usage

``` r
indicator_soil_erosion(
  units,
  layers,
  dem_layer = "dem",
  landcover_layer = "landcover",
  forest_values = c(1, 2, 3)
)
```

## Arguments

- units:

  nemeton_units object

- layers:

  nemeton_layers object containing DEM and land cover

- dem_layer:

  Character. Name of DEM layer

- landcover_layer:

  Character. Name of land cover layer

- forest_values:

  Numeric vector. Land cover codes for forest (protective cover)

## Value

Numeric vector of erosion risk scores (0-100, higher = more risk)

## Examples

``` r
if (FALSE) { # \dontrun{
layers <- nemeton_layers(
  rasters = list(dem = "dem.tif", landcover = "landcover.tif")
)
results <- indicator_soil_erosion(units, layers, forest_values = c(1, 2, 3))
} # }
```
