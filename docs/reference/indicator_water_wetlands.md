# Wetland Coverage (W2)

Calculates percentage of parcel area classified as wetland or riparian
zone.

## Usage

``` r
indicator_water_wetlands(
  units,
  layers,
  wetland_layer = "landcover",
  wetland_values = NULL
)
```

## Arguments

- units:

  nemeton_units object

- layers:

  nemeton_layers object containing land cover raster or wetland vector

- wetland_layer:

  Character. Name of wetland layer in layers object

- wetland_values:

  Numeric vector. Land cover codes representing wetlands. Default NULL
  (auto-detect if possible).

## Value

Numeric vector of wetland coverage (0-100%)

## Examples

``` r
if (FALSE) { # \dontrun{
layers <- nemeton_layers(rasters = list(landcover = "landcover.tif"))
results <- indicator_water_wetlands(units, layers, wetland_values = c(50, 51, 52))
} # }
```
