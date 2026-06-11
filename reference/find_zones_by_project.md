# List the monitoring zones bound to a project UUID

Returns every \`monitoring_zone\` row carrying \`project_uuid\`, ordered
by name. Since spec 020 a project may own several zones
(\`\<project\>\_tot/\_feu/\_res/\_mix\`), so prefer this over
\[find_zone_by_project()\] (which returns only the first id).

## Usage

``` r
find_zones_by_project(con, project_uuid)
```

## Arguments

- con:

  A \`DBIConnection\` returned by \[db_connect()\].

- project_uuid:

  Non-empty character scalar. Opaque project id.

## Value

A \`data.frame\` with columns \`id\` (integer) and \`name\` (character),
ordered by \`name\`; zero rows when no zone matches.

## See also

\[find_zone_by_project()\], \[build_project_monitoring_zones()\].
