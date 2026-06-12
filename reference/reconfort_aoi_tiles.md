# Sentinel-2 MGRS tile(s) covering an AOI

Intersects an area of interest with the bundled France Sentinel-2 tiling
grid and returns the MGRS tile code(s) the RECONFORT/IOTA² chain must
fetch. Entirely local (no network).

## Usage

``` r
reconfort_aoi_tiles(aoi, prefix = TRUE)
```

## Arguments

- aoi:

  An \`sf\`/\`sfc\` polygon (any CRS).

- prefix:

  Prefix codes with \`"T"\` (e.g. \`"T31UDP"\`), as IOTA² and
  \`list_tiles\` expect. Default \`TRUE\`. \`FALSE\` returns the bare
  MGRS code (\`"31UDP"\`).

## Value

Character vector of tile codes (sorted, deduplicated). Empty (with a
warning) when the AOI falls outside the bundled grid — RECONFORT is
calibrated on Centre-Val de Loire, and the grid covers metropolitan
France.
