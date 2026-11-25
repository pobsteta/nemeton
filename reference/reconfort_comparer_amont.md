# Pixel-by-pixel agreement of a class map with the upstream RECONFORT map

Compares two classification rasters (classes 1, 2, 3; e.g. the map of
the spike model and the map of the upstream v3 model). The upstream map
is resampled (nearest neighbour) onto the grid of \`carte\` when the
grids differ. With \`placettes\`, the agreement of each map with
held-out field plots is also returned: this is the criterion to amend
spec 021 (the upstream model must agree with field plots kept aside).

## Usage

``` r
reconfort_comparer_amont(carte, amont, placettes = NULL)
```

## Arguments

- carte, amont:

  \[terra::SpatRaster\] objects or file paths of class maps.

- placettes:

  Optional \`data.frame\` with \`x\`, \`y\` (CRS of \`carte\`) and
  \`dep_cor\` (1 to 3) of plots kept aside.

## Value

A list: \`n\` (pixels compared, both non-\`NA\`), \`accord\` (share of
identical pixels), \`confusion\` (rows \`carte\`, columns \`amont\`)
and, with \`placettes\`, \`terrain\` (\`n\`, \`accord_carte\`,
\`accord_amont\`).
