# Persist FORDEAD alert centroids in the \`alert\` table

Bulk-inserts the rows of \`alerts_sf\` as \`alert_type =
'fordead_dieback'\` records, with \`confidence_class\` and
\`stress_index\` populated. Idempotent thanks to the existing UNIQUE
\`(plot_id, alert_type, trigger_date)\` constraint and \`ON CONFLICT DO
NOTHING\`.

## Usage

``` r
.insert_fordead_alerts(con, alerts_sf, zone_id, radius_m = 200)
```

## Arguments

- con:

  A \`DBIConnection\`.

- alerts_sf:

  An sf POINT returned by \[.postprocess_fordead_rasters()\].

- zone_id:

  Integer. Target monitoring zone.

- radius_m:

  Numeric. Maximum allowed centroid → plot distance, in metres. Default
  200.

## Value

Number of rows inserted (integer).

## Details

Each centroid is snapped to the nearest plot of the zone (we do not
invent a new \`plot\` row per cluster — the plot model is the grain of
all existing alerts). Centroids with no plot within \`radius_m\` are
skipped with a warning.
