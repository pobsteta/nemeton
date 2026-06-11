# Read the most recent FAST alert mask for a monitoring zone

Strict mirror of \[read_fordead_dieback_mask()\]: looks under
\`\<cache_dir\>/zone\_\<zone_id\>/\` for files matching
\`^fast_alert\_\[A-Za-z0-9.\_-\]+\\tif\$\` and returns the latest one
(chronological by filename, fallback mtime). Pass \`run_id\` to read a
specific persisted mask by its timestamp suffix.

## Usage

``` r
read_fast_alert_mask(
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

  A \`DBIConnection\`. Currently unused (the function reads from disk
  only) but kept in the signature for symmetry with
  \[read_fordead_dieback_mask()\] and future SQL-side filtering.

- zone_id:

  Integer scalar.

- run_id:

  Optional character. Timestamp suffix used at write time
  (\`format(Sys.time(), " most recent persisted mask is returned.

- cache_dir:

  Path to the FAST mask cache root (typically
  \`\<project\>/cache/layers/fast\`).

## Value

A \`terra::SpatRaster\` (single layer, categorical 0-4) or \`NULL\`.

## Details

Returns \`NULL\` when the directory or any matching file is absent — the
same dégradation pattern as \[read_fordead_dieback_mask()\] so the app
can \`is.null(mask)\` and show an empty state.

## See also

\[compute_fast_alert_mask()\] (the writer),
\[read_fordead_dieback_mask()\] (the FORDEAD mirror),
\[fordead_alert_mask()\] (the consumer that selects alert cells).
