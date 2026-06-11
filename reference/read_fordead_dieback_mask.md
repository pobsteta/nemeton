# Read the FORDEAD dieback classified raster for a zone

Returns the \*\*categorical\*\* 0-4 raster produced by
\[run_fordead_dieback()\] for the given monitoring zone. Values: \`0 =
sain\`, \`1 = faible\`, \`2 = moyenne\`, \`3 = forte\`, \`4 = sol nu\`,
\`NA\` outside the forest mask.

## Usage

``` r
read_fordead_dieback_mask(
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

  A \`DBI\` connection. Reserved (see above) — pass it for forward
  compatibility ; \`NULL\` is also accepted in this release.

- zone_id:

  Integer. \`monitoring_zone.id\`.

- run_id:

  Optional character or integer. When supplied, the file
  \`dieback_mask\_\<run_id\>.tif\` is read directly ; when \`NULL\`
  (default), the latest mask file by filename order is returned.

- cache_dir:

  Character(1). Root of the FORDEAD mask cache, typically
  \`\<project\>/cache/layers/fordead\`. Required — the spec'd signature
  \`(con, zone_id, run_id)\` cannot derive this from the connection in
  this release, so the argument is exposed directly. Pass the same path
  the app uses for its UI.

## Value

A \`terra::SpatRaster\` with a single integer band, or \`NULL\` when no
mask is available (no \`cache_dir\` provided, the directory doesn't
exist, or no file matches).

## Details

Looks up files under \`\<cache_dir\>/zone\_\<zone_id\>/\` matching the
pattern \`dieback_mask\_\<run_id\>.tif\`. When \`run_id\` is \`NULL\`,
the most recent file (lexicographic order on the YYYYMMDDTHHMMSS suffix
— which is also chronological) is returned.

## Path convention

Mask files are written by the postprocess phase of
\[run_fordead_dieback()\] (in a future release ; see PLAN.md) to the
conventional layout :

    <cache_dir>/
      zone_<zone_id>/
        dieback_mask_<YYYYMMDDTHHMMSS>.tif

Until the persist hook lands, this function returns \`NULL\` unless the
caller has manually placed a categorical GeoTIFF at that location.

## \`con\` parameter

The \`con\` argument is reserved for a future \`fordead_run\` tracking
table (DB-side index of completed runs per zone). It is \*\*not\*\*
consulted in this release — discovery is filesystem-based. The argument
is kept in the signature for forward compatibility so the call sites
don't need to change once the tracking table lands.

## See also

\[run_fordead_dieback()\] for the pipeline that produces the underlying
anomaly / dieback rasters.

## Examples

``` r
if (FALSE) { # \dontrun{
  r <- read_fordead_dieback_mask(
    con       = con,
    zone_id   = 1L,
    cache_dir = file.path(project_dir, "cache/layers/fordead")
  )
  if (!is.null(r)) terra::plot(r)
} # }
```
