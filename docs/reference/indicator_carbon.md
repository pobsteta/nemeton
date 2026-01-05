# Calculate carbon stock indicator

Estimates above-ground carbon stock from biomass raster data.

## Usage

``` r
indicator_carbon(
  units,
  layers,
  biomass_layer = "biomass",
  conversion_factor = 0.47,
  fun = "mean",
  ...
)
```

## Arguments

- units:

  A `nemeton_units` or `sf` object representing analysis units

- layers:

  A `nemeton_layers` object containing spatial data

- biomass_layer:

  Character. Name of the biomass raster layer in layers. Default
  "biomass".

- conversion_factor:

  Numeric. Conversion factor from biomass to carbon (default 0.47 for
  forests)

- fun:

  Character. Summary function for zonal extraction. Default "mean".
  Options: "mean", "sum", "median", "min", "max"

- ...:

  Additional arguments (not used)

## Value

Numeric vector of carbon stock values (tonnes C/ha or similar units)

## Details

The function performs the following steps:

1.  Extracts biomass values from raster using exact zonal statistics

2.  Applies conversion factor to convert biomass to carbon stock

3.  Returns summary statistic per unit (default: mean)

The default conversion factor (0.47) is based on IPCC guidelines for
forest biomass. Adjust this value based on your biomass data units and
carbon estimation method.

## See also

[`nemeton_compute`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md)

## Examples

``` r
if (FALSE) { # \dontrun{
carbon <- indicator_carbon(units, layers, biomass_layer = "agb")
} # }
```
