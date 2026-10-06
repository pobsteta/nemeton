# List available countries

Returns the country codes for which data source configurations exist.

## Usage

``` r
list_countries()
```

## Value

Character vector of ISO country codes.

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

## Examples

``` r
list_countries()  # c("EU", "FR")
#> [1] "EU" "FR"
```
