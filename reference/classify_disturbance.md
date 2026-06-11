# Tag each alert with the disturbance type it most likely reflects (G2)

Cross-references FORDEAD alerts with the rolling-window NDVI/NBR alerts
on the same plot. Adds a \`disturbance_type\` column:

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

The input enriched with a \`disturbance_type\` column.

## Details

- \`"mechanical"\` — FORDEAD alert with a \`ndvi_drop\` / \`nbr_drop\`
  companion within \`± window_days\`. Likely a clear-cut, chablis or
  fire scar.

- \`"progressive"\` — Lone FORDEAD alert. Likely scolyte /
  drought-driven dieback.

- \`"recent_event"\` — Lone NDVI/NBR drop without any FORDEAD echo.
  Recent perturbation, no confirmed dieback.

- \`NA_character\_\` — NDVI/NBR drop already paired with a FORDEAD alert
  (the FORDEAD row carries the verdict).

Computed in pure R: cost is O(n²) on a few thousand alerts max, so we
deliberately don't push it to SQL.
