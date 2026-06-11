# Get a sub-product of a multi-product datasource

Several datasources (e.g. the Theia products `forms_t`, `theia_soil`,
`theia_snow`) bundle more than one raster product under a `products`
block — for `forms_t`, the `height`, `volume` and `biomass`
sub-products. This helper returns the metadata of one named sub-product
(resolution, unit, value range, conversion notes), so a caller can pick
the right product and apply any documented unit conversion before
feeding it to an indicator.

## Usage

``` r
get_datasource_product(source_key, product, country = "FR")
```

## Arguments

- source_key:

  Character. The datasource key (e.g., `"forms_t"`).

- product:

  Character. The sub-product name (e.g., `"height"`).

- country:

  Character. ISO country code. Default `"FR"`.

## Value

A list with the sub-product configuration.

## Examples

``` r
h <- get_datasource_product("forms_t", "height", "FR")
h$unit          # "cm"
#> [1] "cm"
h$resolution_m  # 10
#> [1] 10
```
