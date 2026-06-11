# Compute the R5 dieback indicator

Adds an \`R5\` column (0-100 score, higher = more dieback) and a
diagnostic \`r5_status\` column (\`"calculated"\`,
\`"skipped_no_resineux"\`, \`"skipped_no_fordead"\`) to the input forest
units. The score is the confidence-weighted fraction of the unit area
covered by FORDEAD anomaly clusters, capped at 1 and rescaled to 0-100
to align with the rest of the radar.

## Usage

``` r
indicateur_r5_deperissement(
  units,
  fordead_results = NULL,
  weights = FORDEAD_CONFIDENCE_WEIGHTS,
  min_resineux = 0.3,
  include_low_classes = FALSE,
  resineux_col = NULL
)
```

## Arguments

- units:

  An \`sf\` of forest management units, with at least a species column
  (one of \`essence_dominante\`, \`essence\`, \`species_label\`,
  \`species\`, \`essence_principale\`).

- fordead_results:

  The list returned by \[run_fordead_dieback()\]. Only
  \`fordead_results\$alerts_sf\` is consumed here. \`NULL\` (default)
  means R5 is set to NA for every unit with status
  \`"skipped_no_fordead"\`.

- weights:

  Named numeric vector. Per-class weights used to combine the cluster
  surfaces. Default \[\`FORDEAD_CONFIDENCE_WEIGHTS\`\].

- min_resineux:

  Numeric in \`\[0, 1\]\`. Minimum spruce + fir share required to
  compute R5 on a unit. Below this threshold, R5 is \`NA\` with status
  \`"skipped_no_resineux"\`. Default 0.3.

- include_low_classes:

  Logical. When \`FALSE\` (default), only classes \`3-forte\` and
  \`4-sol-nu\` are considered (G1).

- resineux_col:

  Optional character. Name of a column on \`units\` carrying a per-unit
  conifer share in \`\[0, 1\]\`. When absent, the share is derived from
  the dominant species column via \[\`.is_epicea()\`\] /
  \[\`.is_sapin_pectine()\`\] (then 1 if the unit is dominated by spruce
  or fir, else 0).

## Value

The input \`units\` with two added columns: \`R5\` (numeric, 0-100, NA
where skipped) and \`r5_status\` (character).

## Details

By default, only classes \`3-forte\` and \`4-sol-nu\` contribute (G1 in
spec 008 — classes 1-faible and 2-moyenne carry 50 Set
\`include_low_classes = TRUE\` to include them, in which case the
per-class weights from \`FORDEAD_CONFIDENCE_WEIGHTS\` apply.
