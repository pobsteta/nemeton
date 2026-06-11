# Draw a stratified sample of alerts to be validated in the field

Stratifies on \`confidence_class\` so every observed class lands in the
validation set (with at least one plot per class), then uses GRTS via
\[spsurvey::grts()\] when available for spatial balance, and falls back
to a per-stratum random draw when \`spsurvey\` is not installed.

## Usage

``` r
generate_health_validation_plots(
  alerts_sf,
  n = 30L,
  method = c("grts", "random"),
  crs = 2154
)
```

## Arguments

- alerts_sf:

  An \`sf\` POINT layer of alert centroids. Must carry at least the
  \`id\`, \`confidence_class\`, \`stress_index\` and \`trigger_date\`
  columns produced by \[list_alerts()\] / \[.insert_fordead_alerts()\].

- n:

  Integer. Total number of validation plots to draw.

- method:

  Character. \`"grts"\` (default) or \`"random"\`. GRTS silently
  degrades to random when \`spsurvey\` is missing.

- crs:

  CRS the result is reprojected into. Default 2154 (Lambert-93) — the
  CRS the downstream QGIS / QField project uses to render the placettes
  layer.

## Value

An \`sf\` POINT layer with columns \`plot_id\`, \`alert_id\`,
\`confidence_class\`, \`stress_index\`, \`trigger_date\`,
\`sampling_method\`, plus the schema's editable columns pre-allocated as
typed NAs.

## Details

The returned \`sf\` is shaped to feed \`create_qgis_project()\` through
\[get_health_validation_schema()\].
