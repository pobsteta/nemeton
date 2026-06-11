# FORDEAD 2.x output locators & status derivation (spec 008 §12)

Helpers that bridge the fordead 2.x on-disk layout
(\`\<out_dir\>/\<LAYER\>/fordead\_\<YYYYMMDD\>\_\<LAYER\>.tif\`) with
the existing postprocess pipeline (\[.postprocess_fordead_rasters()\]),
which expects a \`list(state, stress_index, first_dieback_date)\` of
raster paths or \`SpatRaster\` objects.

Three helpers :

\* \[.list_layer_files()\] / \[.latest_layer_file()\] — locate the
per-date GeoTIFFs FORDEAD writes for a given layer name. \*
\[.compute_first_dieback_date()\] — stack \`ANOMALY_CONFIRMED\` and call
\`fordead.utils.backward_start()\` to derive the first confirmed-anomaly
date per pixel. Returns a \`SpatRaster\` (in memory). \*
\[.fordead_2x_status_to_classes()\] — combine \`ANOMALY_CONFIRMED\`,
\`CONSECUTIVE_DETECTIONS\` and \`STOP_CONFIRMED\` into a single 0-4
\`SpatRaster\` consumable by the existing
\[.classify_pixels_to_classes()\] (which is reused intact). The
thresholds come from spec 008 §12.4 mapping table.
