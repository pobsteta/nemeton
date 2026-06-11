# Apply the UGF zone mask to a SpatRaster

Internal helper introduced in spec 016 (v0.49.0). Sets to \`NA\` every
pixel of \`raster\` that falls outside the polygon \`zone_polygon\`
(typically the UGF envelope returned by \[\`.get_zone_aoi\`()\]).
Returns the raster unchanged when \`zone_polygon\` is \`NULL\`.

## Usage

``` r
.apply_zone_mask(raster, zone_polygon)
```

## Arguments

- raster:

  A \`terra::SpatRaster\`.

- zone_polygon:

  An \`sf\` POLYGON (or \`sfc\`), typically \`.get_zone_aoi(con,
  zone_id)\`. \`NULL\` is a no-op.

## Value

A \`terra::SpatRaster\` (masked or unchanged).

## Details

Transparently reprojects \`zone_polygon\` to the raster's CRS if they
differ. Wraps \`terra::mask()\` with a small \`tryCatch\` so that a
failure (mismatched CRS, malformed polygon, …) does not abort the entire
pipeline — only \`cli_warn\` and return the raster unmasked, which is
the strictly less-restrictive behaviour (back-compat semantics).
