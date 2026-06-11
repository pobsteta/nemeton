# STAC assembly + FordeadConfig helpers (spec 008 §12, v0.23.0)

Internal helpers used by \[run_fordead_dieback()\] to bridge the nemeton
STAC COG cache (produced by \[ingest_sentinel2_timeseries()\]) and the
fordead 2.x pipeline (\`fordead.workflow.FordeadProcess\`).

Three responsibilities, three helpers :

\* \[.aoi_bbox_4326()\] — extract a 4-numeric WGS-84 bbox from an \`sf\`
AOI (input to \`FordeadProcess(bbox=...)\`). \*
\[.aoi_geometry_reticulate()\] — build a \`shapely.geometry\` Python
object from the same AOI (input to \`FordeadProcess(geometry=...)\`,
takes precedence over \`bbox\` when both are provided). \*
\[.build_fordead_config()\] — construct a
\`fordead.config.FordeadConfig\` Python object overriding the four
R-exposed knobs (\`dates_training\`, \`dates_monitoring\`,
\`vegetation_index\`, \`threshold_anomaly\`). Everything else stays at
the fordead 2.x defaults — which, per ADR-013 A1 §12.6, match exactly
the ONF/DSF calibration (CRSWIR, 0.16, 3 anomalies, 2-year training). \*
\[.build_stac_collection_for_aoi()\] — walk a \`scenes_df\` (the same
shape consumed by \[read_s2_band_stack()\] / spec 010) and build a
\`simplestac.ItemCollection\` of one \`pystac.Item\` per scene, with
band assets pointing at local cache COGs.

None of these helpers initialise Python at module load time —
\[reticulate::import()\] is called lazily inside each helper, so
devtools::load_all() / R CMD check do not require fordead to be
available.
