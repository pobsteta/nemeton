# Derive the 0-4 confidence-class raster from fordead 2.x layers

fordead 2.x emits \`ANOMALY_CONFIRMED\` (boolean, 0/1) plus a count
raster \`CONSECUTIVE_DETECTIONS\` (integer, length of the current streak
of flagged anomalies) and a \`STOP_CONFIRMED\` flag (boolean, set when
the stress index has crossed the soil-nu threshold).

## Usage

``` r
.fordead_2x_status_to_classes(output_dir)
```

## Arguments

- output_dir:

  Character(1). Root FordeadProcess output dir.

## Value

A \`terra::SpatRaster\` of integer codes \`0..4\`, or \`NULL\` when the
mandatory \`ANOMALY_CONFIRMED\` layer is missing.

## Details

The 0-4 schema expected by \[.classify_pixels_to_classes()\] is then
assembled per pixel as :

\* \`STOP_CONFIRMED == 1\` → \`4\` (sol-nu) \* \`CONSECUTIVE_DETECTIONS
\>= 10\` → \`3\` (forte) \* \`CONSECUTIVE_DETECTIONS \>= 6\` → \`2\`
(moyenne) \* \`CONSECUTIVE_DETECTIONS \>= 3\` → \`1\` (faible) \* else →
\`0\` (sain)

Pixels where \`ANOMALY_CONFIRMED == 0\` are forced to \`0\` regardless
of the count (defensive — the count can persist after a transient
recovery in \`definitive_anomaly = False\` mode).

Thresholds match spec 008 §12.4. To be \*\*calibrated empirically\*\* in
v0.23.0 release prep (AC.12.3) against a real FORDEAD run; until then we
keep them as documented defaults.
