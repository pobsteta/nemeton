-- Migration 0001 — initial schema (DuckDB variant)
--
-- Mirrors `pg/0001_init.sql` for projects that run the monitoring
-- subsystem on a local DuckDB file instead of PostgreSQL +
-- TimescaleDB + PostGIS. Differences from the PG variant:
--
--   * No `CREATE EXTENSION timescaledb` / `postgis` — DuckDB ships
--     all needed features in core (spatial extension is loaded by
--     `db_connect()` when geometry queries are issued, but the
--     monitoring schema only stores WKT TEXT so we do not require
--     it for ingest / list_alerts).
--   * No `SELECT create_hypertable(...)` — DuckDB has no equivalent.
--     `obs_pixel` stays a plain table with a composite primary key.
--     At the volumes we target (a single forestry project ⇒ at most
--     a few k plots × 100 dates ≈ 1 M rows) DuckDB's vectorized
--     scans are fast enough without time partitioning.
--   * `SERIAL` → `INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY`
--     (SQL-standard, supported by DuckDB ≥ 0.7).
--   * `TIMESTAMPTZ` → `TIMESTAMP` (DuckDB stores TIMESTAMPTZ as
--     UTC under a different name; we keep things simple and store
--     UTC implicitly).
--
-- Idempotent: safe to re-run. `db_migrate()` also tracks applied
-- versions in `schema_migration` so this normally only executes once.

-- -----------------------------------------------------------------------
-- Migration tracking
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS schema_migration (
    version    TEXT      PRIMARY KEY,
    applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------
-- monitoring_zone — registered AOIs
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS monitoring_zone (
    id         INTEGER   PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name       TEXT      NOT NULL,
    zone_wkt   TEXT      NOT NULL,
    crs_epsg   INTEGER   NOT NULL DEFAULT 2154,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT
);

-- -----------------------------------------------------------------------
-- plot — monitored plots (typically GRTS sampling points)
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS plot (
    id         INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
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
-- Plain table (no hypertable). Composite primary key gives us O(log n)
-- lookups on (plot_id, obs_date, band); DuckDB's columnar layout keeps
-- (obs_date, band) range scans efficient.
CREATE TABLE IF NOT EXISTS obs_pixel (
    plot_id   INTEGER          NOT NULL REFERENCES plot(id) ON DELETE CASCADE,
    obs_date  DATE             NOT NULL,
    band      TEXT             NOT NULL,
    value     DOUBLE,
    cloud_pct NUMERIC,
    source    TEXT             NOT NULL,
    scene_id  TEXT,
    PRIMARY KEY (plot_id, obs_date, band)
);

-- -----------------------------------------------------------------------
-- alert — drops detected by detect_alerts()
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS alert (
    id            INTEGER   PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    plot_id       INTEGER   NOT NULL REFERENCES plot(id) ON DELETE CASCADE,
    alert_type    TEXT      NOT NULL,
    trigger_date  DATE      NOT NULL,
    value_before  DOUBLE,
    value_after   DOUBLE,
    delta         DOUBLE,
    created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (plot_id, alert_type, trigger_date)
);

CREATE INDEX IF NOT EXISTS alert_plot_idx     ON alert (plot_id);
CREATE INDEX IF NOT EXISTS alert_trigger_idx  ON alert (trigger_date);
