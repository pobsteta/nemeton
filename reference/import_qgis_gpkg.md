# Read placettes + arbres layers from a field-returned GPKG

Reads a GeoPackage written by either QGIS Desktop or QField (or any
other client speaking the same GPKG schema) into a list of two \`sf\`
objects.

\`import_qfield_gpkg()\` is a deprecated alias kept for backwards
compatibility. It forwards to \[import_qgis_gpkg()\] and emits a
one-shot deprecation warning. New code should call
\[import_qgis_gpkg()\] directly.

## Usage

``` r
import_qgis_gpkg(path)

import_qfield_gpkg(path)
```

## Arguments

- path:

  Character. Path to the GeoPackage.

## Value

A list with `placettes` (an sf POINT) and `arbres` (an sf POINT; an
empty data.frame if the layer is absent).
