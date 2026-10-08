# Read placettes + arbres layers from a field-returned GPKG

Reads a GeoPackage written by either QGIS Desktop or QField (or any
other client speaking the same GPKG schema) into a list of two \`sf\`
objects.

## Usage

``` r
import_qgis_gpkg(path)
```

## Arguments

- path:

  Character. Path to the GeoPackage.

## Value

A list with `placettes` (an sf POINT) and `arbres` (an sf POINT; an
empty data.frame if the layer is absent).

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).
