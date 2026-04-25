-- Migration 0001 — initial schema for monitoring (spec 007 / E6.a)
--
-- Idempotent: safe to re-run. db_migrate() also tracks applied versions
-- in schema_migration so this would normally only execute once.

CREATE EXTENSION IF NOT EXISTS timescaledb;

-- -----------------------------------------------------------------------
-- Migration tracking
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS schema_migration (
    version    TEXT        PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------
-- monitoring_zone — registered AOIs
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS monitoring_zone (
    id         SERIAL      PRIMARY KEY,
    name       TEXT        NOT NULL,
    zone_wkt   TEXT        NOT NULL,
    crs_epsg   INTEGER     NOT NULL DEFAULT 2154,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by TEXT
);

-- -----------------------------------------------------------------------
-- plot — monitored plots (typically GRTS sampling points)
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS plot (
    id         SERIAL  PRIMARY KEY,
    zone_id    INTEGER NOT NULL REFERENCES monitoring_zone(id) ON DELETE CASCADE,
    plot_id    TEXT    NOT NULL,
    plot_type  TEXT,
    geom_wkt   TEXT    NOT NULL,
    radius_m   NUMERIC NOT NULL DEFAULT 15,
    UNIQUE (zone_id, plot_id)
);

CREATE INDEX IF NOT EXISTS plot_zone_idx ON plot (zone_id);

-- -----------------------------------------------------------------------
-- obs_pixel — Sentinel-2 derived observations (NDVI, NBR per plot per date)
-- -----------------------------------------------------------------------
-- Hypertable chunked by 7-day intervals. With one S2 revisit every
-- 2-5 days, that's 1-3 observations per chunk per (plot, band).
CREATE TABLE IF NOT EXISTS obs_pixel (
    plot_id   INTEGER          NOT NULL REFERENCES plot(id) ON DELETE CASCADE,
    obs_date  DATE             NOT NULL,
    band      TEXT             NOT NULL,
    value     DOUBLE PRECISION,
    cloud_pct NUMERIC,
    source    TEXT             NOT NULL,
    scene_id  TEXT,
    PRIMARY KEY (plot_id, obs_date, band)
);

-- Convert to a TimescaleDB hypertable. if_not_exists is necessary for
-- migration idempotence (re-running the file must be a no-op).
SELECT create_hypertable(
    'obs_pixel',
    'obs_date',
    chunk_time_interval => INTERVAL '7 days',
    if_not_exists       => TRUE
);

-- -----------------------------------------------------------------------
-- alert — drops detected by detect_alerts()
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS alert (
    id            SERIAL           PRIMARY KEY,
    plot_id       INTEGER          NOT NULL REFERENCES plot(id) ON DELETE CASCADE,
    alert_type    TEXT             NOT NULL,
    trigger_date  DATE             NOT NULL,
    value_before  DOUBLE PRECISION,
    value_after   DOUBLE PRECISION,
    delta         DOUBLE PRECISION,
    created_at    TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    UNIQUE (plot_id, alert_type, trigger_date)
);

CREATE INDEX IF NOT EXISTS alert_plot_idx     ON alert (plot_id);
CREATE INDEX IF NOT EXISTS alert_trigger_idx  ON alert (trigger_date);
