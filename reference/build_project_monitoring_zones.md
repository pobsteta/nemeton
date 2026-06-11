# Build a project's monitoring zones from UGF x BD Forêt v2 strata

Creates up to four monitoring zones for a project (spec 020):

## Usage

``` r
build_project_monitoring_zones(
  con,
  project_name,
  project_uuid,
  ugf,
  bdforet,
  strata = c("tot", "feu", "res", "mix"),
  work_crs = 2154L,
  replace = TRUE
)
```

## Arguments

- con:

  A \`DBIConnection\` returned by \[db_connect()\].

- project_name:

  Character scalar. Human project name; slugged for the zone names.

- project_uuid:

  Non-empty character scalar. Opaque project id that binds the created
  zones (uniqueness on \`(project_uuid, name)\`).

- ugf:

  An \`sf\`/\`sfc\` of the project's UGF (management unit) polygons.

- bdforet:

  An \`sf\` of BD Forêt v2 polygons, carrying \`tfv_g11\` (and/or
  \`essence\`).

- strata:

  Character vector, subset of \`c("tot","feu","res","mix")\`. Default
  all four.

- work_crs:

  Numeric EPSG of the working projected CRS for the geometry operations.
  Default 2154 (Lambert-93).

- replace:

  Logical. When \`TRUE\` (default) the project's existing zones are
  deleted before (re)creating (idempotent upsert).

## Value

A named \`list\` mapping each created stratum (\`"tot"\`, \`"feu"\`,
\`"res"\`, \`"mix"\`) to its new zone id. Skipped (empty) strata are
absent from the list.

## Details

\* \`\<project\>\_tot\` — union of the UGFs; \* \`\<project\>\_feu\` —
that union intersected with BD Forêt v2 broadleaf; \*
\`\<project\>\_res\` — intersected with BD Forêt v2 conifer; \*
\`\<project\>\_mix\` — intersected with BD Forêt v2 mixed forest.

\`\<project\>\` is the project name as an NMT slug (lowercase, accents
transliterated). BD Forêt polygons are classified by their \`tfv_g11\`
field (fallback \`essence\`). A stratum with no surface is
\*\*skipped\*\* with a warning (D4): a project therefore owns 1 to 4
zones. When \`replace = TRUE\` (default, D5) the project's existing
zones are deleted first, so re-running refreshes them.

All geometry is computed in \`work_crs\` (a projected CRS, for valid
area-based intersection); \[create_monitoring_zone()\] stores each zone
in EPSG:4326. Zones carry no placettes (see
\[create_monitoring_zone()\]).

## See also

\[create_monitoring_zone()\], \[find_zones_by_project()\].
