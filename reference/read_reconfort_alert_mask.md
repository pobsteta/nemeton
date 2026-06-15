# Read the RECONFORT broadleaf-classification raster for a zone

Returns the **categorical** class raster produced by
\[run_reconfort_dieback()\] for the given monitoring zone. Values: \`1 =
sain\`, \`2 = dépérissant\`, \`3 = très dépérissant\`, \`0\`/\`NA\`
outside the broadleaf mask. The RECONFORT mirror of
\[read_fordead_dieback_mask()\] — it feeds
\[create_validation_sampling_plan()\] (\`source = "RECONFORT"\`,
\`classes = c(2, 3)\`, \`control_classes = c(1)\`) so the broadleaf
validation plan reuses the same raster sampling machinery as FORDEAD.

Looks up
\`\<cache_dir\>/zone\_\<zone_id\>/reconfort_mask\_\<run_id\>.tif\`
(written by the \`persist\` phase of \[run_reconfort_dieback()\]); when
\`run_id\` is \`NULL\` the most recent file (lexicographic, hence
chronological) is returned.

## Usage

``` r
read_reconfort_alert_mask(
  con,
  zone_id,
  run_id = NULL,
  cache_dir = NULL,
  apply_zone_mask = TRUE,
  mask_polygon = NULL
)
```

## Arguments

- con:

  A \`DBI\` connection or \`NULL\`. Used (when not \`NULL\`) to re-mask
  the raster to the zone AOI, like \[read_fordead_dieback_mask()\].

- zone_id:

  Integer. \`monitoring_zone.id\`.

- run_id:

  Optional character/integer. Explicit run selector.

- cache_dir:

  Character(1). Root of the RECONFORT cache, typically
  \`\<project\>/cache/layers/reconfort\`. Required.

- apply_zone_mask:

  Logical. Re-mask to the UGF zone AOI. Default \`TRUE\`.

- mask_polygon:

  Optional \`sf\`/\`sfc\` polygon overriding the AOI.

## Value

A single-band \`terra::SpatRaster\`, or \`NULL\` when no mask is
available.

## See also

\[read_fordead_dieback_mask()\], \[run_reconfort_dieback()\].
