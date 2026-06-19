# Read an auxiliary FORDEAD diagnostic raster (model bundle)

Loads one of the map-relevant single-band rasters written to the per-run
model bundle (\`zone\_\<id\>/model\_\<run_id\>/\`) by the persist phase
of \[run_fordead_dieback()\], and applies the UGF zone mask the same way
\[read_fordead_dieback_mask()\] does.

## Usage

``` r
read_fordead_layer(
  con,
  zone_id,
  layer,
  run_id = NULL,
  cache_dir = NULL,
  apply_zone_mask = TRUE,
  mask_polygon = NULL
)
```

## Arguments

- con:

  A \`DBIConnection\` or \`NULL\`. Used only to resolve the UGF AOI for
  the zone mask (skipped when \`NULL\`).

- zone_id:

  Integer. \`monitoring_zone.id\`.

- layer:

  Character. One of \`"first_anomaly"\`, \`"anomaly_index"\`,
  \`"modelled_pixels"\`.

- run_id:

  Character or \`NULL\`. Run timestamp; \`NULL\` picks the most recent
  bundle.

- cache_dir:

  Character. Project FORDEAD cache root
  (\`\<project\>/cache/layers/fordead\`), same as
  \[read_fordead_dieback_mask()\].

- apply_zone_mask:

  Logical. Restrict to the UGF perimeter (default \`TRUE\`).

- mask_polygon:

  Optional \`sf\`/\`sfc\` overriding the DB-resolved AOI.

## Value

A \`terra::SpatRaster\` (single band) or \`NULL\`.

## Details

Recognised layers:

- \`"first_anomaly"\`:

  First confirmed-anomaly date per pixel (days since 1970-01-01) — feeds
  the "date de première détection" display layer.

- \`"anomaly_index"\`:

  Latest continuous anomaly index — feeds the "indice d'anomalie /
  sévérité continue" display layer.

- \`"modelled_pixels"\`:

  Binary mask of pixels the harmonic model could be fitted on — feeds
  the "confiance / zone modélisée" display layer.

Returns \`NULL\` (never errors) when the cache, the zone, the bundle or
the layer file is missing — older runs predating a layer simply yield
\`NULL\`, so the caller degrades gracefully.

## See also

\[read_fordead_dieback_mask()\] for the categorical 0-4 mask,
\[read_fordead_pixel_series()\] for the per-pixel CRSWIR diagnostic.
