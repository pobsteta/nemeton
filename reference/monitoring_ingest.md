# Sentinel-2 Time Series Ingestion (E6 monitoring)

Fetch Sentinel-2 L2A scenes covering a monitoring zone over a date range
and prime the on-disk COG band cache (B04 / B08 / B12) that the
per-pixel FAST diagnostic (\[read_fast_alert_raster()\]) consumes. Since
v0.58.0 nothing is written to the database (the \`obs_pixel\` table was
dropped).

Triggered on demand: no cron worker is started by this function. One
call = one ingestion window.
