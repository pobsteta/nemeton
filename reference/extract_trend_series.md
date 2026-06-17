# Zone-level trend trajectory (yearly composite series + Theil-Sen fit)

Companion to \[read_fast_alert_raster()\] \`mode = "trend"\`. The trend
map reduces each pixel's multi-year history to a single slope magnitude
and so carries **no onset information** — it cannot say *when* a decline
set in. This returns the intermediate **yearly seasonal composite
series** for the whole zone plus the Theil-Sen / Mann-Kendall fit, so a
caller (e.g. \`nemetonshiny\`) can plot the trajectory and read off when
the index starts dropping (the year the curve breaks downward).

## Usage

``` r
extract_trend_series(
  con,
  zone_id,
  index = c("NDRE", "NDMI", "NDVI", "NBR"),
  date_from,
  date_to,
  cache_dir,
  months = 6:9,
  min_years = 4L,
  min_obs_per_year = 2L,
  alpha = 0.05,
  min_slope = 0.005,
  apply_zone_mask = TRUE,
  mask_polygon = NULL,
  parallel = FALSE
)
```

## Arguments

- con:

  A \`DBIConnection\`. Used only to resolve the UGF zone polygon for the
  optional mask (spec 016) — \*\*not\*\* for scene enumeration (spec
  017: scenes come from the COG cache, so the diagnostic is independent
  of \`obs_pixel\` / placettes).

- zone_id:

  Integer scalar. Existing zone in \`monitoring_zone\`.

- index:

  One of \`"NDRE"\`, \`"NDMI"\`, \`"NDVI"\`, \`"NBR"\`. Default
  \`"NDRE"\` (the red-edge early-stress marker the trend mode targets).

- date_from, date_to:

  Date (or character \`"YYYY-MM-DD"\`) bounding the analysis window.

- cache_dir:

  Character scalar. Path to the COG cache root (typically
  \`\<project\>/cache/layers/sentinel2\`). Must exist.

- months:

  Integer vector in \`1:12\`. The seasonal window kept for the yearly
  composite. Default \`6:9\` (summer, when water stress is most
  legible).

- min_years:

  Integer scalar. Minimum number of valid composite years required
  before a Theil-Sen / Mann-Kendall fit is returned. Default \`4\`.

- min_obs_per_year:

  Integer scalar. Minimum number of clear observations a pixel needs
  within a year for that year's median to count (else that year is
  \`NA\` for the pixel). Default \`2\`.

- alpha:

  Numeric scalar in \`(0, 1)\`. Mann-Kendall significance level. Default
  \`0.05\`.

- min_slope:

  Numeric \`\>= 0\`. Minimum decline magnitude (index units per year)
  for the fit to be flagged \`significant\` (\`abs(slope) \>=
  min_slope\`), filtering Mann-Kendall's sensitivity on long series.
  Default \`0.005\`; set \`0\` for the pure significance test.

- apply_zone_mask:

  Logical. When \`TRUE\` (default) the composite is masked to the UGF
  zone polygon before the spatial mean (spec 016).

- mask_polygon:

  An \`sf\` / \`sfc\` polygon overriding the zone mask, or \`NULL\`
  (default) to resolve it from \`con\` / \`zone_id\`.

- parallel:

  Logical (spec 017 D4). Passed to \[build_index_stack()\].

## Value

\`NULL\` when no in-season scene exists in the window. Otherwise a
\`list\`:

- \`series\`:

  a \`data.frame\`, one row per year (ascending), with \`year\`
  (integer), \`n_scenes\` (distinct in-season acquisitions that year),
  \`value\` (zone-mean composite; \`NA\` for a year with no valid pixel)
  and \`fitted\` (Theil-Sen fitted value, \`NA\` when the fit is
  undefined).

- \`fit\`:

  \`NULL\` when fewer than \`min_years\` valid years, else a \`list\`
  with \`slope\`, \`intercept\`, \`p_value\`, \`tau\`, \`n_years\`,
  \`significant\` (\`slope \< 0\` **and** \`p_value \< alpha\`) and
  \`alert\` (\`abs(slope)\` when \`significant\`, else \`0\` — the same
  magnitude the trend map bins into classes 1-4).

- \`index\`, \`months\`, \`alpha\`, \`min_slope\`:

  the parameters used.

## Details

For every year in \`\[date_from, date_to\]\`, the in-season (\`months\`)
scenes are reduced to a per-pixel median composite (a year with fewer
than \`min_obs_per_year\` clear observations is dropped for that pixel),
masked to the UGF zone, and spatially averaged to one value. The
\`(year, value)\` series is then fitted with the SAME Theil-Sen slope +
Mann-Kendall test the trend map runs per pixel, so the zone trajectory
and the map agree by construction. Multi-tile AOIs are combined as a
valid-pixel-count-weighted mean per year.

## See also

\[read_fast_alert_raster()\] (\`mode = "trend"\`, the per-pixel map),
\[compute_fast_alert_mask()\] (the 0-4 discretiser).

## Examples

``` r
if (FALSE) { # \dontrun{
  con <- db_connect(Sys.getenv("NEMETON_DB_URL"))
  on.exit(db_disconnect(con), add = TRUE)
  tr <- extract_trend_series(
    con, zone_id = 1L, index = "NDRE",
    date_from = "2017-01-01", date_to = "2024-12-31",
    cache_dir = "/proj/cache/layers/sentinel2")
  plot(tr$series$year, tr$series$value, type = "b")   # trajectory
  lines(tr$series$year, tr$series$fitted)             # Theil-Sen fit
  tr$fit$significant                                  # is the decline real?
} # }
```
