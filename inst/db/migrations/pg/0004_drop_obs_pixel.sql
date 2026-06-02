-- Migration 0004 — drop obs_pixel hypertable
-- Spec 017 finalisé : le diagnostic FAST est désormais purement
-- per-pixel sur le cache COG (read_fast_alert_raster). obs_pixel
-- (per-placette) n'a plus de consommateur depuis nemetonshiny@v0.52.16,
-- et l'ingestion S2 (ingest_sentinel2_timeseries) n'y écrit plus
-- depuis nemeton v0.58.0.
DROP TABLE IF EXISTS obs_pixel CASCADE;
