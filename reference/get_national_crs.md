# Get national CRS for a country

Returns the EPSG code of the national coordinate reference system.

## Usage

``` r
get_national_crs(country = "FR")
```

## Arguments

- country:

  Character. ISO country code. Default "FR".

## Value

Integer. EPSG code (e.g., 2154 for France Lambert-93).

## Examples

``` r
get_national_crs("FR")  # 2154
#> [1] 2154
```
