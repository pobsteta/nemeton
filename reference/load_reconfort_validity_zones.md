# Load the RECONFORT validity zones layer

Reads \`inst/extdata/reconfort_validity_zones.geojson\` (the six
Centre-Val de Loire department polygons in EPSG:4326) and caches the
result for the lifetime of the R session.

## Usage

``` r
load_reconfort_validity_zones()
```

## Value

An \`sf\` object with columns \`code_dept\`, \`nom_dept\`, \`source\`,
\`reference\` and \`geometry\` (MULTIPOLYGON, EPSG:4326).
