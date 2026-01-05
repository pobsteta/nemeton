# Topographic Wetness Index (W3)

Calculates TWI using whitebox (D-infinity algorithm) or terra fallback
(D8). Higher values indicate areas with greater water accumulation
potential.

## Usage

``` r
indicator_water_twi(
  units,
  layers,
  dem_layer = "dem",
  method = c("auto", "dinf", "d8")
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

  Character. TWI calculation method: "auto" (prefer whitebox), "dinf"
  (whitebox D-infinity), or "d8" (terra D8). Default "auto".

## Value

Numeric vector of TWI mean values

## Examples

``` r
if (FALSE) { # \dontrun{
layers <- nemeton_layers(rasters = list(dem = "dem_25m.tif"))
results <- indicator_water_twi(units, layers, dem_layer = "dem")
} # }
```
