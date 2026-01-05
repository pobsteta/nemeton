# Calculate water regulation indicator

Estimates water regulation capacity from topography and hydrography.

## Usage

``` r
indicator_water(
  units,
  layers,
  dem_layer = "dem",
  water_layer = "water",
  calculate_twi = TRUE,
  calculate_proximity = TRUE,
  max_distance = 1000,
  weights = c(0.6, 0.4),
  ...
)
```

## Arguments

- units:

  A `nemeton_units` or `sf` object representing analysis units

- layers:

  A `nemeton_layers` object containing spatial data

- dem_layer:

  Character. Name of Digital Elevation Model raster. Default "dem".

- water_layer:

  Character. Name of water bodies vector layer. Default "water".

- calculate_twi:

  Logical. Calculate Topographic Wetness Index? Default TRUE.

- calculate_proximity:

  Logical. Calculate proximity to water bodies? Default TRUE.

- max_distance:

  Numeric. Maximum distance to consider for proximity (meters). Default
  1000.

- weights:

  Numeric vector of length 2. Weights for TWI and proximity components.
  Default c(0.6, 0.4) (60% TWI, 40% proximity).

- ...:

  Additional arguments (not used)

## Value

Numeric vector of water regulation indicator values

## Details

The water regulation indicator combines two components: (1) Topographic
Wetness Index (TWI) - Simplified proxy from DEM slope; (2) Proximity to
water - Distance to nearest water body (inverse weighted).

For MVP (v0.1.0), TWI is approximated from slope. Future versions will
implement full flow accumulation analysis.

## See also

[`nemeton_compute`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md)

## Examples

``` r
if (FALSE) { # \dontrun{
water_reg <- indicator_water(units, layers)

# TWI only
twi <- indicator_water(
  units, layers,
  calculate_proximity = FALSE
)
} # }
```
