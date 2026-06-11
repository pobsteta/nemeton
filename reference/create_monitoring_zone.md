# Create a monitoring zone (geometry only, no placettes)

Inserts a single row into \`monitoring_zone\` from a polygon, optionally
bound to a project via \`project_uuid\` (spec 011). Unlike
\[register_monitoring_zone()\], it writes \*\*no\*\* placettes: since
spec 017 the FAST/FORDEAD diagnostic is computed per-pixel from the COG
cache and is placette-independent, so a monitoring zone needs only its
geometry. Validation-terrain placettes, if ever needed, are added
separately.

## Usage

``` r
create_monitoring_zone(con, zone_name, zone_polygon, project_uuid = NULL)
```

## Arguments

- con:

  A \`DBIConnection\` returned by \[db_connect()\].

- zone_name:

  Non-empty character scalar. Zone name (unique per \`project_uuid\`
  since migration 0005).

- zone_polygon:

  An \`sf\`/\`sfc\` object carrying the zone polygon (any CRS;
  reprojected to 4326 on insert).

- project_uuid:

  Optional character scalar (or \`NULL\`, default). Opaque project
  identifier; uniqueness is on \`(project_uuid, name)\`.

## Value

The new zone id (integer, invisibly).

## Details

The polygon is reprojected to EPSG:4326 and stored as WKT, consistent
with \[register_monitoring_zone()\].

## See also

\[build_project_monitoring_zones()\] (the strata builder that calls
this), \[find_zones_by_project()\], \[register_monitoring_zone()\].
