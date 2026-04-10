# Get metric CRS for a country

Returns the CRS to use for metric calculations (distances, areas). Uses
the national CRS for precision (Lambert-93 for France, UTM for others).

## Usage

``` r
get_metric_crs(country = "FR")
```

## Arguments

- country:

  Character. ISO country code. Default "FR".

## Value

Integer. EPSG code for metric calculations.

## Examples

``` r
get_metric_crs("FR")  # 2154 (Lambert-93)
#> [1] 2154
```
