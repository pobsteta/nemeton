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
--   * `SERIAL` → explicit `SEQUENCE` + `INTEGER PRIMARY KEY DEFAULT
--     nextval('<seq>')`. DuckDB's SQL parser does not accept the
--     SQL-standard `GENERATED ALWAYS AS IDENTITY` clause (it raises
--     a `Parser Error: syntax error at or near "GENERATED"`), so we
--     fall back to the portable sequence-based pattern, which is
--     functionally equivalent and idempotent thanks to
--     `CREATE SEQUENCE IF NOT EXISTS`.
--   * `ON DELETE CASCADE` is dropped from FOREIGN KEY clauses:
--     DuckDB enforces FK existence but rejects cascade / SET NULL /
--     SET DEFAULT referential actions at parse time. Deletes that
--     need to clear children must do so explicitly from R (none of
--     the current monitoring code paths delete plots or zones, so
--     this is documented restriction rather than a behavioural gap).
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
CREATE SEQUENCE IF NOT EXISTS monitoring_zone_id_seq START 1;
CREATE TABLE IF NOT EXISTS monitoring_zone (
    id         INTEGER   PRIMARY KEY DEFAULT nextval('monitoring_zone_id_seq'),
    name       TEXT      NOT NULL,
    zone_wkt   TEXT      NOT NULL,
    crs_epsg   INTEGER   NOT NULL DEFAULT 2154,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT
);

-- -----------------------------------------------------------------------
-- plot — monitored plots (typically GRTS sampling points)
-- -----------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS plot_id_seq START 1;
CREATE TABLE IF NOT EXISTS plot (
    id         INTEGER PRIMARY KEY DEFAULT nextval('plot_id_seq'),
    zone_id    INTEGER NOT NULL REFERENCES monitoring_zone(id),
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
    plot_id   INTEGER          NOT NULL REFERENCES plot(id),
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
CREATE SEQUENCE IF NOT EXISTS alert_id_seq START 1;
CREATE TABLE IF NOT EXISTS alert (
    id            INTEGER   PRIMARY KEY DEFAULT nextval('alert_id_seq'),
    plot_id       INTEGER   NOT NULL REFERENCES plot(id),
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
