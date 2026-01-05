# NDVI Mean and Trend Analysis (C2)

Extracts mean NDVI from Sentinel-2 or equivalent satellite imagery.
Optionally calculates NDVI trend over multiple dates (requires temporal
rasters).

## Usage

``` r
indicator_carbon_ndvi(units, layers, ndvi_layer = "ndvi", trend = FALSE)
```

## Arguments

- units:

  nemeton_units object

- layers:

  nemeton_layers object containing NDVI raster(s)

- ndvi_layer:

  Character. Name of NDVI layer in layers object

- trend:

  Logical. Calculate temporal trend if multiple dates available? Default
  FALSE.

## Value

Numeric vector of NDVI mean values (0-1 scale), or list with mean and
trend if trend = TRUE

## Examples

``` r
if (FALSE) { # \dontrun{
# Single-date NDVI
layers <- nemeton_layers(rasters = list(ndvi = "sentinel2_ndvi.tif"))
results <- indicator_carbon_ndvi(units, layers, ndvi_layer = "ndvi")

# Multi-date NDVI with trend
results <- indicator_carbon_ndvi(units, layers, ndvi_layer = "ndvi", trend = TRUE)
} # }
```
