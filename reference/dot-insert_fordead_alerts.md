# Persist FORDEAD alert centroids in the \`alert\` table

Thin wrapper over \[.insert_health_alerts()\] with \`alert_type =
"fordead_dieback"\`. Pixel/cluster entity, no plot snapping (spec 008
§15 Phase B).

## Usage

``` r
.insert_fordead_alerts(con, alerts_sf, zone_id, replace = TRUE)
```

## Arguments

- con:

  A \`DBIConnection\`.

- alerts_sf:

  An sf POINT (centroids) with columns \`trigger_date\`,
  \`confidence_class\`, \`stress_index\` and, when available,
  \`n_pixels\`, \`area_m2\`. CRS assumed EPSG:2154 when absent. A
  zero-row sf means a successful run without alert: with \`replace =
  TRUE\` the prior \*\*pending\*\* alerts are still purged. \`NULL\`
  (failed post-processing) leaves the table untouched.

- zone_id:

  Integer. Target monitoring zone.

- replace:

  Logical. When \`TRUE\` (default) every prior \*\*pending\*\*
  \`(zone_id, alert_type)\` alert is deleted before insertion, making
  the call idempotent across re-runs. Alerts already validated in the
  field are kept, and a new alert within 50 m of one of them is not
  re-inserted (since 0.208.0). When \`FALSE\`, rows are appended (the
  caller is then responsible for avoiding key collisions).

## Value

Number of rows inserted (integer).
