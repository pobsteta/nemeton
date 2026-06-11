# Read the FORDEAD CRSWIR pixel diagnostic series

For a clicked pixel of a monitoring zone, returns the time series behind
the FORDEAD detection: the observed (masked) CRSWIR, the harmonic-model
prediction, the anomaly-threshold band and the per-date anomaly flag.
Consumes the diagnostic bundle persisted by \[run_fordead_dieback()\]
(spec 008 section 14.3).

## Usage

``` r
read_fordead_pixel_series(
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

  A \`DBI\` connection or \`NULL\`. Reserved (see above).

- zone_id:

  Integer. \`monitoring_zone.id\`.

- xy:

  Numeric(2). Coordinates of the clicked pixel, in \`crs\`.

- crs:

  EPSG code of \`xy\`. Default \`4326\` (leaflet convention).

- run_id:

  Optional character/integer. When supplied, the bundle
  \`model\_\<run_id\>/\` is read directly; when \`NULL\` (default) the
  most recent bundle of the zone is used.

- cache_dir:

  Character(1). Root of the FORDEAD cache, typically
  \`\<project\>/cache/layers/fordead\`. Required.

## Value

A \`data.frame\` ordered by \`obs_date\`, with columns:

- obs_date:

  \`Date\` - observation date.

- crswir_obs:

  \`numeric\` - observed masked CRSWIR (\`NA\` on a masked date - kept,
  not dropped).

- crswir_pred:

  \`numeric\` - harmonic-model prediction.

- seuil_haut:

  \`numeric\` - \`crswir_pred + threshold_anomaly\`.

- anomalie:

  \`logical\` - \`crswir_obs \> seuil_haut\`.

Attributes carried on the data frame: \`threshold_anomaly\`,
\`premiere_detection\` (\`Date\` or \`NA\`), \`dans_zone_validite\`
(\`logical\` or \`NA\`, via \[check_fordead_validity()\]),
\`vegetation_index\`.

Returns \`NULL\` (without error) when no bundle is found, the pixel is
outside the modelled extent, or the FORDEAD Python environment is
unavailable.

## Details

Modelled on \[extract_pixel_timeseries()\] (the FAST pixel map) and on
\[read_fordead_dieback_mask()\] for the path / \`run_id\` conventions.

## \`con\` parameter

Reserved for a future \`fordead_run\` tracking table - \*\*not\*\*
consulted in this release (discovery is filesystem-based). Kept in the
signature for forward compatibility, exactly as
\[read_fordead_dieback_mask()\]. \`NULL\` is accepted.

## See also

\[run_fordead_dieback()\], \[read_fordead_dieback_mask()\].

## Examples

``` r
if (FALSE) { # \dontrun{
  s <- read_fordead_pixel_series(
    con       = NULL,
    zone_id   = 1L,
    xy        = c(6.42, 46.71),
    cache_dir = file.path(project_dir, "cache/layers/fordead")
  )
  if (!is.null(s)) {
    plot(s$obs_date, s$crswir_obs)
    lines(s$obs_date, s$crswir_pred)
  }
} # }
```
