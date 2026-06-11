# WGS-84 bbox of an AOI, length-4 numeric

WGS-84 bbox of an AOI, length-4 numeric

## Usage

``` r
.aoi_bbox_4326(aoi)
```

## Arguments

- aoi:

  An \`sf\` or \`sfc\` object in any CRS. Is transformed to EPSG:4326
  internally.

## Value

\`numeric(4)\` in \`(xmin, ymin, xmax, ymax)\` order.
