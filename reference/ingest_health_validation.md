# Ingest a health-validation GPKG and update \`alert\` rows

Reads the \`placettes\` layer of \`gpkg_path\` (typically a GPKG edited
in QGIS Desktop or in QField on a tablet), snaps each plot to the
nearest alert of the given \`zone_id\` (within \`snap_distance_m\`),
maps the observer-selected \`stade_deperissement\` to
\`validation_status\` / \`validation_cause\`, and issues an \`UPDATE
alert\` per match. Plots without a \`stade_deperissement\` are skipped
(never edited in the field).

## Usage

``` r
ingest_health_validation(
  con,
  gpkg_path,
  zone_id,
  snap_distance_m = 50,
  validated_by = NULL,
  layer = "placettes"
)
```

## Arguments

- con:

  A \`DBIConnection\` to a TimescaleDB instance.

- gpkg_path:

  Character. Path to the GPKG returned by the field crew.

- zone_id:

  Integer. The monitoring zone whose alerts the validation targets.

- snap_distance_m:

  Numeric. Maximum distance (metres) for matching a plot to an alert.
  Default 50.

- validated_by:

  Character or \`NULL\`. Identity persisted on the alert (typically the
  OAuth subject of the ingesting user — defaults to the value present in
  \`obs_by\`, then to \`Sys.info()\[\["user"\]\]\`).

- layer:

  Character. GPKG layer name. Default \`"placettes"\`.

## Value

A list: \* \`n_updated\` (int), \`n_confirmed\` (int),
\`n_false_positive\` (int); \* \`n_unmatched\` (int) — plots without an
alert within \`snap_distance_m\`; \* \`n_skipped\` (int) — plots with no
\`stade_deperissement\`; \* \`details\` — a data.frame with one row per
processed plot.
