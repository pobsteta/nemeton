# Diagnose an S2 band cache directory

Walks \`\<cache_dir\>/\<scene_id\>/\` and reports how many scene
directories are populated (contain at least one \`.tif\`) versus empty
(no \`.tif\`). Empty dirs are typically leftovers from the v0.21.4
eager-creation bug (fixed in v0.21.6) — they can be safely wiped. Use
this as a one-shot sanity check after running
\`ingest_sentinel2_timeseries(..., cache_dir = ...)\`.

## Usage

``` r
diagnose_s2_cache(cache_dir, verbose = TRUE)
```

## Arguments

- cache_dir:

  Character. Path to the S2 cache root, e.g.
  \`\<project\>/cache/layers/sentinel2\`.

- verbose:

  Logical. When \`TRUE\` (default), print a \`cli\` summary; when
  \`FALSE\` only return the result list invisibly.

## Value

Invisibly, a list with \`cache_dir\`, \`n_scenes\`, \`n_populated\`,
\`n_empty\`, \`total_bytes\`, \`bands_per_scene\` (mean), and
\`empty_dirs\` (character vector of paths).

## Examples

``` r
if (FALSE) { # \dontrun{
diagnose_s2_cache(file.path(project_path, "cache", "layers", "sentinel2"))
# i S2 cache at <project>/cache/layers/sentinel2
#   * Scene directories: 159
#   * Populated: 12 (3.4 MB)
#   * Empty: 147   <- leftover from v0.21.4 or active fetch failures
} # }
```
