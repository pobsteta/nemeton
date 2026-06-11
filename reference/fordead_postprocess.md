# FORDEAD Post-Processing: Rasters to Alert Clusters (E6.c.2, spec 008)

Turns the GeoTIFF outputs of \[run_fordead_dieback()\] into a sf POINT
layer of cluster centroids and persists them into the \`alert\` table.
The flow is:

1.  \`state.tif\` (per-pixel anomaly class, 0–4) is reclassified into
    the canonical \[\`FORDEAD_CLASSES\`\] vocabulary.

2.  Connected pixel patches are extracted (\`terra::patches\`,
    8-neighbour by default) per class. Patches smaller than
    \`min_pixels\` are dropped.

3.  Each cluster yields a centroid enriched with \`confidence_class\`,
    \`stress_index\`, \`trigger_date\`, \`n_pixels\`, \`area_m2\`.

Confidence weights are calibrated on the ONF/DSF FORDEAD validation
report (Bernard & Doridant 2024) — see
\[\`FORDEAD_CONFIDENCE_WEIGHTS\`\] and ADR-013 §G5.
