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
  \`n_pixels\`, \`area_m2\`. CRS assumed EPSG:2154 when absent.

- zone_id:

  Integer. Target monitoring zone.

- replace:

  Logical. When \`TRUE\` (default) every prior \`(zone_id, alert_type)\`
  alert is deleted before insertion, making the call idempotent across
  re-runs. When \`FALSE\`, rows are appended.

## Value

Number of rows inserted (integer).
