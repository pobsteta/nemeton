# Read the RECONFORT CRswir/CRre pixel diagnostic series

For a clicked pixel of a monitoring zone, returns the observed CRswir
and CRre time series persisted by \[run_reconfort_dieback()\] (L5).
Unlike the FORDEAD diagnostic there is no harmonic model to reconstruct,
so no Python / reticulate is involved.

## Usage

``` r
read_reconfort_pixel_series(
  con,
  zone_id,
  xy,
  crs = 4326,
  run_id = NULL,
  cache_dir
)
```

## Arguments

- con:

  A \`DBI\` connection or \`NULL\`. Reserved (see below).

- zone_id:

  Integer. \`monitoring_zone.id\`.

- xy:

  Numeric(2). Coordinates of the clicked pixel, in \`crs\`.

- crs:

  EPSG code of \`xy\`. Default \`4326\` (leaflet convention).

- run_id:

  Optional character/integer. When supplied, the bundle
  \`run\_\<run_id\>/\` is read directly; when \`NULL\` (default) the
  most recent bundle of the zone is used.

- cache_dir:

  Character(1). Root of the RECONFORT cache, typically
  \`\<project\>/cache/layers/reconfort\`. Required.

## Value

A \`data.frame\` ordered by \`obs_date\`, with columns \`obs_date\`
(Date), \`crswir_obs\` (numeric, NA on a masked date) and \`crre_obs\`
(numeric). Attributes: \`species\`, \`v_model\`, \`n_classes\`,
\`date_from\`, \`date_to\`, \`dans_zone_validite\` (advisory G3 via
\[check_reconfort_validity()\]).

Returns \`NULL\` (without error) when no bundle is found or the pixel is
outside the extent.

## \`con\` parameter

Reserved for a future \`reconfort_run\` tracking table — **not**
consulted in this release (discovery is filesystem-based). \`NULL\` is
accepted.

## See also

\[run_reconfort_dieback()\], \[read_fordead_pixel_series()\].
