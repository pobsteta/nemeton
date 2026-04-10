# Get storage CRS (pan-European)

Returns the EPSG code used for internal data storage. EPSG:3035
(ETRS89/LAEA) is the pan-European standard (ADR-008).

## Usage

``` r
get_storage_crs()
```

## Value

Integer. EPSG code (3035).

## Examples

``` r
get_storage_crs()  # 3035
#> [1] 3035
```
