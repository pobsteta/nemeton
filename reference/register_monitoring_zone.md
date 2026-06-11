# Register a monitoring zone and its plots in the database

Helper that inserts a \`monitoring_zone\` row and the associated
\`plot\` rows. Idempotent on \`(zone_id, plot_id)\` — within an existing
zone, re-registering the same \`plot_id\` is a no-op (UNIQUE
constraint + \`ON CONFLICT DO NOTHING\`). The \`monitoring_zone\` table
has no uniqueness on \`name\`, so calling this function twice with the
same \`zone_name\` creates two independent zones.

## Usage

``` r
register_monitoring_zone(
  con,
  zone_name,
  zone_polygon,
  placettes,
  radius_m = 15,
  project_uuid = NULL
)
```

## Arguments

- con:

  A \`DBIConnection\` returned by \[db_connect()\].

- zone_name:

  Character. Display name for the zone.

- zone_polygon:

  An sf POLYGON (any CRS — re-projected to WGS84 internally for
  storage).

- placettes:

  An sf POINT object with at least the columns \`plot_id\` (character)
  and optionally \`type\`.

- radius_m:

  Numeric. Sampling radius around each placette in metres. Default 15.

- project_uuid:

  Optional character scalar (or \`NULL\`, default). Opaque project
  identifier used by callers (\`nemetonshiny\`) to stably bind a project
  to its monitoring zone. When non-\`NULL\`, stored on
  \`monitoring_zone.project_uuid\` and queryable via
  \[find_zone_by_project()\]. UNIQUE on non-\`NULL\` values —
  registering a second zone with the same \`project_uuid\` raises a DB
  error. Available since spec 011 (migration \`0003_project_uuid\`).

## Value

The \`zone_id\` (integer) of the registered zone.
