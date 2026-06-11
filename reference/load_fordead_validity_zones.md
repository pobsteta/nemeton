# Load the FORDEAD validity zones layer

Reads \`inst/extdata/fordead_validity_zones.geojson\` (five department
polygons in EPSG:4326) and caches the result for the lifetime of the R
session.

## Usage

``` r
load_fordead_validity_zones()
```

## Value

An \`sf\` object with columns \`code_dept\`, \`nom_dept\`, \`source\`,
\`reference\` and \`geometry\` (MULTIPOLYGON, EPSG:4326).
