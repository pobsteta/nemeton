# Per-pixel trend diagnostic at a point (composites + Theil-Sen / MK)

The single-pixel counterpart of the FAST \`trend\` raster: for the point
\`xy\`, returns the yearly seasonal composite series of \`index\` plus
the Theil-Sen / Mann-Kendall result, **strictly consistent** with
\`read_fast_alert_raster(mode = "trend")\` /
\`compute_fast_alert_mask()\` at the same pixel. This is what drives the
"why does this pixel have this colour" graph in \`nemetonshiny\`: the
clicked pixel's composite points, the fitted decline line and the
significance behind its severity class.

## Usage

``` r
extract_pixel_trend(
  cache_dir,
  scenes_df,
  xy,
  crs = 4326,
  index = c("NDRE", "NDMI", "NDVI", "NBR"),
  months = 6:9,
  min_years = 4L,
  min_obs_per_year = 2L,
  alpha = 0.05,
  zone_polygon = NULL,
  warn_outside_zone = TRUE
)
```

## Arguments

- cache_dir:

  Character scalar. COG cache root (must exist).

- scenes_df:

  A \`data.frame\` of cached scenes with at least \`scene_id\` and
  \`obs_date\`, as enumerated for the index (e.g. from \[list_alerts()\]
  / the monitoring cache). Passed through to
  \[extract_pixel_timeseries()\].

- xy:

  Length-2 numeric \`c(x, y)\` point coordinate in \`crs\`.

- crs:

  Coordinate reference of \`xy\`. Default \`4326\`.

- index:

  One of \`"NDRE"\`, \`"NDMI"\`, \`"NDVI"\`, \`"NBR"\`. Default
  \`"NDRE"\`.

- months, min_years, min_obs_per_year, alpha:

  Trend parameters, identical in meaning and default to
  \[read_fast_alert_raster()\] \`mode = "trend"\`.

- zone_polygon, warn_outside_zone:

  Optional UGF polygon and flag; forwarded to
  \[extract_pixel_timeseries()\] to warn when \`xy\` lies outside the
  managed perimeter (the series is still returned).

## Value

\`NULL\` when no cached scene carries the index bands. Otherwise a
\`list\`:

- \`index\`:

  the index.

- \`composites\`:

  \`data.frame(year, value)\` — the in-season median per year (\`value\`
  \`NA\` for a year below \`min_obs_per_year\`).

- \`n_years\`:

  count of valid composite years.

- \`theil_sen_slope\`, \`theil_sen_intercept\`:

  signed slope (index/yr) and intercept, for the fitted line.

- \`mann_kendall_p\`, \`mann_kendall_tau\`:

  significance test.

- \`significant_decline\`:

  \`enough_years\` **and** \`slope \< 0\` **and** \`p \< alpha\` — the
  raster's alert condition.

- \`alert_value\`:

  \`abs(slope)\` when \`significant_decline\`, \`0\` when not
  significant, \`NA\` when \`\< min_years\` valid years — the raster's
  pre-quartile value, NA-masked exactly like the map.

- \`enough_years\`:

  \`n_years \>= min_years\`.

The 0-4 severity class is NOT returned: its quartile breaks are
zone-wide, so read the class straight from the mask raster at the pixel.

## Details

The raw per-scene series is read with \[extract_pixel_timeseries()\] (a
scene-by-scene point extraction, **not** a zone-wide mosaic — so it is
immune to the multi-tile \`\[mosaic\] resolution does not match\`
failure the raster path guards against). It is then composited exactly
like the raster (in-season median per year, a year with fewer than
\`min_obs_per_year\` clear observations dropped) and fitted with the
shared Theil-Sen / Mann-Kendall the raster runs per pixel, so
\`alert_value\` equals the raster's pre-quartile value cell-for-cell.

## See also

\[read_fast_alert_raster()\] (\`mode = "trend"\`, the raster),
\[extract_trend_series()\] (the zone-level trajectory),
\[extract_pixel_timeseries()\] (the raw per-scene series).

## Examples

``` r
if (FALSE) { # \dontrun{
  # `scenes` = the cached scenes for the index (scene_id + obs_date).
  tr <- extract_pixel_trend(
    cache_dir = "/proj/cache/layers/sentinel2",
    scenes_df = scenes, xy = c(6.30, 46.40), index = "NDRE")
  plot(tr$composites$year, tr$composites$value, type = "b")
  abline(tr$theil_sen_intercept, tr$theil_sen_slope)
  tr$significant_decline; tr$alert_value
} # }
```
