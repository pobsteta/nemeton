# Tag each alert with the disturbance type it most likely reflects (G2)

Garde-fou G2, extended to three methods since spec 021 (L3): FAST
(rolling-window \`ndvi_drop\` / \`nbr_drop\`) plus the two diagnostic
methods \`fordead_dieback\` (resineux) and \`reconfort_dieback\`
(feuillus). Adds a \`disturbance_type\` column (+ a \`method_overlap\`
flag):

## Usage

``` r
classify_disturbance(alerts_df, window_days = 30L)
```

## Arguments

- alerts_df:

  A data frame with columns \`plot_id\`, \`alert_type\`,
  \`trigger_date\`. The \`alerts_sf\` returned by \[list_alerts()\]
  works as-is.

- window_days:

  Integer. Half-width of the join window in days. Default 30.

## Value

The input enriched with a \`disturbance_type\` column and a logical
\`method_overlap\` column.

## Details

- \`"mechanical"\` — a diagnostic alert (FORDEAD or RECONFORT) with a
  FAST (\`ndvi_drop\` / \`nbr_drop\`) companion within \`±
  window_days\`. Likely a clear-cut, chablis or fire scar.

- \`"progressive"\` — a lone diagnostic alert (FORDEAD or RECONFORT)
  without a FAST companion. Likely scolyte / drought-driven dieback.

- \`"recent_event"\` — a lone FAST drop without any diagnostic echo.
  Recent perturbation, no confirmed dieback.

- \`NA_character\_\` — a FAST drop already paired with a diagnostic
  alert (the diagnostic row carries the verdict).

\`method_overlap\` is \`TRUE\` on a diagnostic alert when both FORDEAD
and RECONFORT fired on the same plot/window (mixed fringe): the type
stays \`"progressive"\` but the flag says "do not double-count".

Computed in pure R: cost is O(n²) on a few thousand alerts max, so we
deliberately don't push it to SQL.
