# Compute the R5 dieback indicator (unified FORDEAD / RECONFORT)

Adds an \`R5\` column (0-100 score, higher = more dieback) and a
diagnostic \`r5_status\` column to the input forest units. R5 is the
confidence-weighted fraction of the unit area covered by dieback
clusters, capped at 1 and rescaled to 0-100.

## Usage

``` r
indicateur_r5_deperissement(
  units,
  fordead_results = NULL,
  reconfort_results = NULL,
  weights = FORDEAD_CONFIDENCE_WEIGHTS,
  weights_reconfort = RECONFORT_CONFIDENCE_WEIGHTS$CHE[-1L],
  min_resineux = 0.3,
  min_feuillus = 0.3,
  include_low_classes = FALSE,
  resineux_col = NULL,
  feuillus_col = NULL
)
```

## Arguments

- units:

  An \`sf\` of forest management units, with at least a species column
  (one of \`essence_dominante\`, \`essence\`, \`species_label\`,
  \`species\`, \`essence_principale\`).

- fordead_results:

  The list returned by \[run_fordead_dieback()\] (only \`\$alerts_sf\`
  is consumed). Used for \*\*conifer\*\* units (spruce / fir).

- reconfort_results:

  The list returned by \[run_reconfort_dieback()\] (only \`\$alerts_sf\`
  is consumed). Used for \*\*oak / chestnut / Scots pine\*\* units (spec
  021 L4).

- weights:

  Named numeric vector. Per-class FORDEAD weights. Default
  \[\`FORDEAD_CONFIDENCE_WEIGHTS\`\].

- weights_reconfort:

  Named numeric vector. Per-class RECONFORT weights (dieback classes).
  Default = the oak subset of \[\`RECONFORT_CONFIDENCE_WEIGHTS\`\]
  (provisional, see that object).

- min_resineux:

  Numeric in \`\[0, 1\]\`. Minimum conifer share to route a unit to
  FORDEAD. Default 0.3.

- min_feuillus:

  Numeric in \`\[0, 1\]\`. Minimum oak/chestnut/Scots-pine share to
  route a unit to RECONFORT. Default 0.3.

- include_low_classes:

  Logical. When \`FALSE\` (default), only FORDEAD classes \`3-forte\`
  and \`4-sol-nu\` are considered (G1).

- resineux_col:

  Optional character. Column carrying a per-unit conifer share in \`\[0,
  1\]\`; pins the unit to the FORDEAD method.

- feuillus_col:

  Optional character. Column carrying a per-unit oak/chestnut/Scots-pine
  share in \`\[0, 1\]\`; pins the unit to the RECONFORT method.

## Value

The input \`units\` with two added columns: \`R5\` (numeric, 0-100, NA
where skipped) and \`r5_status\` (character).

## Details

\*\*Routing by dominant species (spec 021 §4)\*\*: each unit is scored
by the method calibrated for its species — RECONFORT for oak / chestnut
/ Scots pine, FORDEAD for spruce / fir. \`r5_status\` is one of
\`"calculated"\` (FORDEAD), \`"calculated_reconfort"\` (RECONFORT),
\`"skipped_no_fordead"\` / \`"skipped_no_reconfort"\` (method applies
but its run is missing), or \`"skipped_no_method"\` (species matches
neither).

By default, only the trustworthy classes contribute (G1): FORDEAD
\`3-forte\` / \`4-sol-nu\` (set \`include_low_classes = TRUE\` to add
the low classes) and RECONFORT \[\`RECONFORT_ALERT_CLASSES\`\].
