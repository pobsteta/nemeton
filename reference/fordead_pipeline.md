# FORDEAD Dieback Detection Pipeline (E6.c.1, spec 008)

R-side orchestrator that drives the five FORDEAD steps via reticulate.
The post-processing of output rasters into POINT clusters and the
persistence into the `alert` table live in
\[\`R/fordead_postprocess.R\`\] (chantier E6.c.2). When invoked here
without \`con\`, this function only produces the rasters and returns
their paths.

Calibration is \*\*frozen\*\* on the values published by the ONF/DSF
FORDEAD validation report (Bernard & Doridant 2024, cf. ADR-013 §G5):

- \`vegetation_index = "CRSWIR"\`

- \`threshold_anomaly = 0.16\`

- Two years of training, three consecutive anomalies for a confirmed
  detection.

These defaults are not exposed in the UI; advanced callers may still
override them programmatically.
