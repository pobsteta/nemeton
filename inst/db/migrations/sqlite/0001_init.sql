-- Migration 0001 — initial schema (SQLite variant)
--
-- Mirrors `pg/0001_init.sql` for projects that run the monitoring
-- subsystem on a local SQLite file (WAL mode) instead of PostgreSQL +
-- TimescaleDB + PostGIS. SQLite is the recommended local backend: in
-- WAL mode it supports one writer plus several concurrent readers
-- across processes, so the Shiny session and the ingestion worker can
-- share the file (unlike DuckDB, whose file write lock is exclusive).
--
-- Differences from the PG variant:
--
--   * No `CREATE EXTENSION` / `create_hypertable()` — SQLite has none.
--     (The PG variant used a hypertable only for the now-removed
--     `obs_pixel`; the remaining tables are plain on both backends.)
--   * `SERIAL` → `INTEGER PRIMARY KEY AUTOINCREMENT` (SQLite's rowid
--     alias). No sequences.
--   * `ON DELETE CASCADE` is dropped from FOREIGN KEY clauses (the
--     monitoring code never deletes plots/zones; documented restriction).
--   * `TIMESTAMPTZ` → `TIMESTAMP`, `DOUBLE PRECISION` → `DOUBLE`
--     (SQLite uses type affinity; both map to its NUMERIC/REAL classes).
--   * Foreign keys are only enforced when `PRAGMA foreign_keys = ON`,
--     which `db_connect()` sets on every connection.
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
    id         INTEGER   PRIMARY KEY AUTOINCREMENT,
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
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    zone_id    INTEGER NOT NULL REFERENCES monitoring_zone(id),
    plot_id    TEXT    NOT NULL,
    plot_type  TEXT,
    geom_wkt   TEXT    NOT NULL,
    radius_m   NUMERIC NOT NULL DEFAULT 15,
    UNIQUE (zone_id, plot_id)
);

CREATE INDEX IF NOT EXISTS plot_zone_idx ON plot (zone_id);

-- obs_pixel (per-placette NDVI/NBR table) was retired in v0.60.0: the
-- FAST diagnostic is now pure per-pixel over the COG cache
-- (read_fast_alert_raster, spec 017). Fresh databases never create the
-- table; existing databases drop it via migration 0004_drop_obs_pixel.

-- -----------------------------------------------------------------------
-- alert — drops detected by the legacy detect_alerts() (removed v0.60.0);
-- still written by the FORDEAD post-processing pipeline.
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS alert (
    id            INTEGER   PRIMARY KEY AUTOINCREMENT,
    plot_id       INTEGER   NOT NULL REFERENCES plot(id),
    alert_type    TEXT      NOT NULL,
    trigger_date  DATE      NOT NULL,
    value_before  DOUBLE,
    value_after   DOUBLE,
    delta         DOUBLE,
    created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (plot_id, alert_type, trigger_date)
);

CREATE INDEX IF NOT EXISTS alert_plot_idx    ON alert (plot_id);
CREATE INDEX IF NOT EXISTS alert_trigger_idx ON alert (trigger_date);
