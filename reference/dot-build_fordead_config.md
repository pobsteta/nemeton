# Build a \`fordead.config.FordeadConfig\` from R-exposed parameters

Overrides only the four fields exposed in \[run_fordead_dieback()\]
(\`dates_training\`, \`dates_monitoring\`, \`vegetation_index\`,
\`threshold_anomaly\`). The remaining fields keep their fordead 2.x
defaults, which match ADR-013 §G5 calibration (CRSWIR formula, threshold
0.16 wired by default, 3 consecutive anomalies, definitive stop, count
type "v2").

## Usage

``` r
.build_fordead_config(
  dates_training,
  dates_monitoring,
  vegetation_index = "CRSWIR",
  threshold_anomaly = 0.16
)
```

## Arguments

- dates_training:

  Character(2) — start and end of the training period (ISO yyyy-mm-dd).

- dates_monitoring:

  Character(2) — start and end of the monitoring period. The end may be
  \`NA_character\_\` to mean "open".

- vegetation_index:

  Character(1). Default \`"CRSWIR"\`.

- threshold_anomaly:

  Numeric(1) \> 0. Default \`0.16\`.

## Value

A Python \`FordeadConfig\` object.
