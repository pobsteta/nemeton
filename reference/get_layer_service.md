# Get service URL for a layer

Resolves the full service URL for a given layer by looking up the
service reference in the layer configuration.

## Usage

``` r
get_layer_service(layer_key, country = "FR")
```

## Arguments

- layer_key:

  Character. The layer key (e.g., "dem", "roads").

- country:

  Character. ISO country code. Default "FR".

## Value

A list with `url` (service URL) and `layer` or `typename` (layer
identifier), or NULL.

## Examples

``` r
info <- get_layer_service("dem", "FR")
info$url    # "https://data.geopf.fr/wms-r/wms"
#> [1] "https://data.geopf.fr/wms-r/wms"
info$layer  # "ELEVATION.ELEVATIONGRIDCOVERAGE"
#> [1] "ELEVATION.ELEVATIONGRIDCOVERAGE"
```
