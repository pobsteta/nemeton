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

  A \`DBI\` connection, or \`NULL\`. Only used to read the zone polygon
  for \`apply_zone_mask\` (see above).

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

- apply_zone_mask:

  Logical. When `TRUE` (default), pixels outside the monitoring zone
  polygon (the managed UGF perimeter) are set to `NA`.

- mask_polygon:

  Optional `sf`/`sfc` polygon used as the zone mask instead of the
  polygon stored for the zone in the database.

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

Mask files are written by the persist phase of \[run_fordead_dieback()\]
to the conventional layout :

    <cache_dir>/
      zone_<zone_id>/
        dieback_mask_<YYYYMMDDTHHMMSS>.tif

With \`replace = TRUE\` (default) a run prunes the masks of earlier runs
of the zone, so the directory usually holds a single file.

## \`con\` parameter

Discovery of the mask is filesystem-based: \`con\` is \*\*not\*\* used
to find it. It is only read to fetch the zone polygon when
\`apply_zone_mask = TRUE\` and no \`mask_polygon\` is given; with \`con
= NULL\` the zone mask is then skipped.

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
