# Create a validation sampling plan over an alert raster (spec 014 A3)

Generates a sampling plan made of two parts:

## Usage

``` r
create_validation_sampling_plan(
  zone,
  alert_raster,
  n_validation = 20L,
  n_control = 5L,
  classes = c(3L, 4L),
  control_classes = c(0L),
  buffer_m = 0,
  source = c("FORDEAD", "FAST", "RECONFORT"),
  weighting = c("uniform", "continuous"),
  weight_raster = NULL,
  seed = NULL
)
```

## Arguments

- zone:

  An \`sf\` POLYGON in EPSG:2154. Defines the geographic AOI of the
  monitoring zone (used to intersect candidate cells; not used for the
  alert/control selection itself, which comes from \`alert_raster\`).

- alert_raster:

  A \`terra::SpatRaster\` (single layer) with integer class values in
  \`\[0, 4\]\`. Typically \[read_fordead_dieback_mask()\] or
  \[read_fast_alert_mask()\].

- n_validation:

  Integer scalar. Target number of plots in the alert zone. Default
  \`20L\`. \*\*Target only\*\* (GRTS does not always return the exact
  count when the candidate frame is small).

- n_control:

  Integer scalar. Target number of plots in the healthy zone
  (\`alert_raster == 0\`). Default \`5L\`.

- classes:

  Integer vector. Alert classes retained for the validation draw.
  Default \`c(3L, 4L)\`. In \`weighting = "continuous"\` mode this acts
  as a pure eligibility mask (no per-class stratification).

- control_classes:

  Integer vector. Raster classes eligible for the control plots. Default
  \`c(0L)\` (strictly healthy). Relax (e.g. \`c(0L, 1L)\`) when no
  class-0 cell exists.

- buffer_m:

  Numeric in metres. Optional dilation around alert cells before drawing
  (cf. \[fordead_alert_mask()\]). Default \`0\`.

- source:

  Character. Tag stored on every row (\`"FORDEAD"\`, \`"FAST"\` or
  \`"RECONFORT"\`) so the field crew knows which pipeline raised the
  alert. Default \`"FORDEAD"\`. The function samples any single-layer
  categorical \`alert_raster\` by \`classes\`; for \`"RECONFORT"\` the
  caller passes the broadleaf class raster (codes 1 sain / 2 dépérissant
  / 3 très-dépérissant) with \`classes = c(2, 3)\`, \`control_classes =
  c(1)\`.

- weighting:

  One of \`"uniform"\` (default) or \`"continuous"\`. \`"uniform"\`
  keeps the historical per-class unequal-probability GRTS.
  \`"continuous"\` weights inclusion by an external continuous severity
  raster (\`weight_raster\`) — parity with
  \[create_trend_sanitary_plan()\] (FAST \`\|slope\|\`).

- weight_raster:

  A single-layer \`terra::SpatRaster\` of continuous severity (e.g.
  FORDEAD \`anomaly_index\`, or a RECONFORT score / probability),
  \*\*required\*\* when \`weighting = "continuous"\` (a \`NULL\` is an
  explicit error). Aligned onto the alert grid (reprojected / resampled
  if needed); a raster without a CRS or not reprojectable raises a typed
  \`validation_weight_raster_mismatch\` error. Ignored when \`weighting
  = "uniform"\`.

- seed:

  Integer or \`NULL\`. When non-\`NULL\`, makes the GRTS draw
  reproducible.

## Value

An \`sf\` POINT object in EPSG:2154 with the following columns:

- \`plot_id\`:

  Character. Identifier \`V01\`, \`V02\`, ... for validation plots,
  \`T01\`, \`T02\`, ... for controls.

- \`type\`:

  Character. \`"Validation"\` or \`"Temoin"\`.

- \`alert_class\`:

  Integer. Class value of the cell under the plot (0 for controls; in
  \`classes\` for validation; \`min(classes)\` for plots that fall on a
  buffer-added cell).

- \`alert_weight\`:

  Numeric. \*\*Only when \`weighting = "continuous"\`.\*\* Raw value of
  \`weight_raster\` at the drawn point (the severity that drove
  inclusion), for traceability. Absent in uniform mode.

- \`visit_order\`:

  Integer. TSP-optimised order over the union of the two samples.

- \`source\`:

  Character. Echo of \`source\`.

- \`classes\`:

  Character. Comma-separated echo of \`classes\`.

- \`seed\`:

  Integer or \`NA\`. Echo of \`seed\`.

## Details

1\. \*\*Validation plots\*\* — drawn over the alert cells of the
\`alert_raster\` (selected by \[fordead_alert_mask()\] with the given
\`classes\` and optional \`buffer_m\`) using an \*\*unequal-probability
GRTS\*\* that weights inclusion by the alert intensity (class value): a
cell of class 4 has a higher inclusion probability than a class 3 cell.
2. \*\*Control plots\*\* — drawn over the \*healthy\* cells (class 0 of
\`alert_raster\`) using equiprobable GRTS, to serve as the reference
against which a validating field crew can compare the alert plots.

The output is a single \`sf\` POINT object combining both samples,
tagged by a \`type\` column (\`"Validation"\` / \`"Temoin"\`), with a
\`visit_order\` column for a single TSP tour over the union (so the
field crew minimises driving).

Application-level provenance (\`zone_id\`, \`fordead_run_id\` /
\`mask_timestamp\`, \`generated_at\`) is \*\*not\*\* added here — it
lives upstream in the app layer.

## Edge case — empty alert mask

When no cell of \`alert_raster\` falls in \`classes\` (e.g. the zone is
currently healthy), the function raises a typed error of class
\`nemeton_empty_alert_mask\` so the app can render a clean message
(“Zone saine, rien à valider”) rather than producing a degenerate plan.
In \`weighting = "continuous"\` mode the same typed error is raised when
\`weight_raster\` has no finite or no varying value over the alert cells
(empty / all-NA / constant); a \`weight_raster\` that cannot be aligned
onto the alert grid raises the distinct
\`validation_weight_raster_mismatch\` error instead.

## See also

\[fordead_alert_mask()\] (the cell selector),
\[read_fordead_dieback_mask()\] / \[read_fast_alert_mask()\] (the raster
sources), \[create_sampling_plan()\] (the systemic sampling plan for
unbiased inventory).

## Examples

``` r
if (FALSE) { # \dontrun{
  mask <- read_fordead_dieback_mask(con, 1L, cache_dir = cd_fordead)
  zone <- # an sf POLYGON in EPSG:2154
  plan <- create_validation_sampling_plan(
    zone, alert_raster = mask,
    n_validation = 30L, n_control = 8L,
    source = "FORDEAD", seed = 42L)
  table(plan$type)
} # }
```
