# Soil Fertility Index (F2)

Calculates soil fertility potential by combining TWI (water/nutrient
accumulation) and slope (erosion risk). Follows the tuto 03 methodology:
F2 = (twi_norm + slope_norm) / 2

## Usage

``` r
indicateur_f2_erosion(units, layers, dem_layer = "dem")
```

## Arguments

- units:

  nemeton_units object

- layers:

  nemeton_layers object containing DEM raster

- dem_layer:

  Character. Name of DEM layer

## Value

Numeric vector of fertility scores (0-100, higher = more fertile)

## Details

TWI is computed via GRASS (fasterRaster) when available, terra D8
otherwise. Higher values indicate more fertile soil conditions.

## Examples

``` r
if (FALSE) { # \dontrun{
layers <- nemeton_layers(rasters = list(dem = "dem.tif"))
results <- indicateur_f2_erosion(units, layers)
} # }
```
