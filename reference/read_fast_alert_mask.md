# Read the most recent FAST alert mask for a monitoring zone

Strict mirror of \[read_fordead_dieback_mask()\]: looks under
\`\<cache_dir\>/zone\_\<zone_id\>/\` for files matching
\`^fast_alert\_\[A-Za-z0-9.\_-\]+\\tif\$\` and returns the most recently
written or reused one (by mtime, ties broken by filename). Pass
\`run_id\` to read a specific persisted mask by its filename suffix.

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

  Optional character. Filename suffix after \`fast_alert\_\`:
  \`"\<INDEX\>\_\<mode\>\_\<hash16\>"\` since v0.198.0 (content
  addressed), or a \`"%Y%m%dT%H%M%S"\` timestamp for masks written by
  earlier versions. When \`NULL\`, the most recent persisted mask is
  returned.

- cache_dir:

  Path to the FAST mask cache root (typically
  \`\<project\>/cache/layers/fast\`).

## Value

A \`terra::SpatRaster\` (single layer, categorical 0-4) or \`NULL\`.

## Details

"Most recent" means the mask of the \*\*last call\*\* to
\[compute_fast_alert_mask()\] in that directory, whatever its index,
mode or threshold. A caller that needs a given mask should keep the path
returned by \[compute_fast_alert_mask()\] rather than rely on it.

Returns \`NULL\` when the directory or any matching file is absent — the
same dégradation pattern as \[read_fordead_dieback_mask()\] so the app
can \`is.null(mask)\` and show an empty state.

## See also

\[compute_fast_alert_mask()\] (the writer),
\[read_fordead_dieback_mask()\] (the FORDEAD mirror),
\[fordead_alert_mask()\] (the consumer that selects alert cells).
