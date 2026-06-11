# Soil Fertility Index (F2)

Calculates soil fertility potential by combining TWI (water/nutrient
accumulation) and slope (erosion risk). Follows the tuto 03 methodology:
F2 = (twi_norm + slope_norm) / 2

## Usage

``` r
indicateur_f2_erosion(units, layers, dem_layer = "dem", texture = NULL)
```

## Arguments

- units:

  nemeton_units object

- layers:

  nemeton_layers object containing DEM raster

- dem_layer:

  Character. Name of DEM layer

- texture:

  Optional named list of `SpatRaster`s with elements `clay`, `silt`,
  `sand` (the Theia `theia_soil` products, loaded via
  [`load_raster_source`](https://pobsteta.github.io/nemeton/reference/load_raster_source.md)).
  When supplied, adds the texture erosion-resistance component. Default
  `NULL` (pre-existing TWI + slope behaviour).

## Value

Numeric vector of fertility scores (0-100, higher = more fertile)

## Details

TWI is computed via GRASS (fasterRaster) when available, terra D8
otherwise. Higher values indicate more fertile soil conditions.

When a Theia `theia_soil` texture raster set is supplied via `texture`
(chantier sources Theia phase 3b), a third component — texture-based
erosion resistance, see
[`texture_to_erosion_resistance`](https://pobsteta.github.io/nemeton/reference/texture_to_erosion_resistance.md)
— is averaged in: F2 = (twi_norm + slope_norm + resistance_norm) / 3.
Silt-rich soils are more erodible and lower the score.

## Examples

``` r
if (FALSE) { # \dontrun{
layers <- nemeton_layers(rasters = list(dem = "dem.tif"))
results <- indicateur_f2_erosion(units, layers)
} # }
```
