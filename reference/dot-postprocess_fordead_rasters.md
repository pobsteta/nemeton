# Top-level helper: turn FORDEAD raster outputs into an \`alerts_sf\`

Combines \[.classify_pixels_to_classes()\],
\[.cluster_anomaly_pixels()\] and \[.cluster_to_centroids()\] into a
single call. Used by \[run_fordead_dieback()\] and by tests.

## Usage

``` r
.postprocess_fordead_rasters(rasters, min_pixels = 5L, connectivity = 8L)
```

## Arguments

- rasters:

  Named list with character paths or \`SpatRaster\` objects under
  \`state\`, \`stress_index\`, \`first_dieback_date\`.

- min_pixels:

  Integer. Minimum patch size. Default 5.

- connectivity:

  Integer 4 or 8. Default 8.

## Value

An sf POINT (possibly empty).

## Details

Since v0.23.0 (fordead 2.x migration — spec 008 §12), the \`state\`
element is no longer the legacy \`DataAnomalies/state.tif\` integer
raster but a \`SpatRaster\` built in-memory by
\[.fordead_2x_status_to_classes()\] from the 2.x layers
(\`ANOMALY_CONFIRMED\`, \`CONSECUTIVE_DETECTIONS\`, \`STOP_CONFIRMED\`).
The accepted input shape (named list with 0-4 integer codes in
\`state\`) is unchanged so this helper itself didn't need a rewrite.
