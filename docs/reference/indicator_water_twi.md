# Topographic Wetness Index (W3)

Calculates TWI using fasterRaster/GRASS GIS (preferred) or terra
fallback (D8). Higher values indicate areas with greater water
accumulation potential.

## Usage

``` r
indicator_water_twi(
  units,
  layers,
  dem_layer = "dem",
  method = c("auto", "grass", "d8")
)
```

## Arguments

- units:

  nemeton_units object

- layers:

  nemeton_layers object containing DEM raster

- dem_layer:

  Character. Name of DEM layer in layers object

- method:

  Character. TWI calculation method: "auto" (prefer GRASS), "grass"
  (fasterRaster/GRASS GIS), or "d8" (terra D8). Default "auto".

## Value

Numeric vector of TWI mean values

## Details

The GRASS method (via fasterRaster) performs proper hydrological
conditioning: depression filling, flow direction, flow accumulation,
then TWI = ln(SCA / tan(slope)). The terra D8 method is a simpler
approximation used as fallback.

## Examples

``` r
if (FALSE) { # \dontrun{
layers <- nemeton_layers(rasters = list(dem = "dem_25m.tif"))
results <- indicator_water_twi(units, layers, dem_layer = "dem")
} # }
```
