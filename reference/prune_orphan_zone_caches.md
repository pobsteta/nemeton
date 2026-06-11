# Remove cache directories of monitoring zones that no longer exist

Scans the per-zone cache directories under \`cache_root\` and removes
every \`zone\_\<id\>/\` folder whose \`id\` is no longer present in
\`monitoring_zone\`. Such orphans appear after a zone upsert (spec 020,
\[build_project_monitoring_zones()\] with \`replace = TRUE\`):
re-created zones get \*\*new\*\* ids, so the previous
\`zone\_\<old_id\>/\` caches are stranded. The per-zone LRU GCs
(\`nemeton.fast_raster_keep\`, \`nemeton.fast_mask_keep\`) only trim
\*within\* a live zone dir, never a whole stale dir — hence this
housekeeping helper.

## Usage

``` r
prune_orphan_zone_caches(
  con,
  cache_root,
  subdirs = c("fast_alert", "fast_alert_mask", "fast_sampling", "fast", "fast_raster",
    "fordead"),
  dry_run = FALSE
)
```

## Arguments

- con:

  A \`DBIConnection\` returned by \[db_connect()\].

- cache_root:

  Character scalar. Path to \`\<project\>/cache/layers\` (the parent of
  the per-zone cache subdirs).

- subdirs:

  Character vector of cache subdirectory names that hold
  \`zone\_\<id\>/\` folders. Default covers the FAST continuous
  (\`fast_alert\`, \`fast_raster\`), FAST 0-4 mask (\`fast_alert_mask\`,
  \`fast\`), validation-sampling (\`fast_sampling\`) and FORDEAD
  (\`fordead\`) caches.

- dry_run:

  Logical. When \`TRUE\`, report what would be removed without deleting
  anything. Default \`FALSE\`.

## Value

A \`data.frame\` (\`path\`, \`zone_id\`, \`removed\`) of the orphan
directories found, invisibly. \`removed\` is \`FALSE\` on a dry-run or a
failed unlink.

## Details

Only directories named exactly \`zone\_\<integer\>\` under the listed
\`subdirs\` are considered; everything else (shared \`sentinel2/\`,
\`lidar\_\*\`, …) is left untouched.

## See also

\[build_project_monitoring_zones()\] (the upsert that strands the
caches), \[find_zones_by_project()\].
