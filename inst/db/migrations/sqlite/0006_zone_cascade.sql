-- Migration 0006 — restore ON DELETE CASCADE on the monitoring_zone FK
-- chain (SQLite variant)
--
-- Bug fixed: build_project_monitoring_zones(..., replace = TRUE) deletes a
-- project's zones (DELETE FROM monitoring_zone WHERE project_uuid = ?)
-- before recreating them. The PostgreSQL schema (pg/0001_init.sql) carries
--   plot.zone_id  -> monitoring_zone(id) ON DELETE CASCADE
--   alert.plot_id -> plot(id)            ON DELETE CASCADE
-- so that delete cascades through plots and alerts. The SQLite variant
-- (0001_init.sql) deliberately dropped those CASCADE clauses, so with
-- PRAGMA foreign_keys = ON (set by db_connect() on every connection) the
-- same delete fails with "FOREIGN KEY constraint failed" as soon as a zone
-- already owns plot/alert rows — i.e. on the re-build of an
-- already-populated project. This migration brings the SQLite schema to
-- parity by rebuilding `plot` and `alert` with ON DELETE CASCADE.
--
-- SQLite cannot `ALTER TABLE ... ADD CONSTRAINT`, so each table is rebuilt
-- via the canonical procedure: CREATE <new> / INSERT … SELECT / DROP <old>
-- / ALTER … RENAME. db_migrate() already runs this file inside a
-- transaction; `PRAGMA foreign_keys` is a no-op mid-transaction, but
-- `PRAGMA defer_foreign_keys = ON` is honoured — it defers *all* FK
-- enforcement to COMMIT (and auto-resets there). Combined with a
-- parent-rename-before-child-rebuild ordering, no ON DELETE action fires
-- on the rows we keep (the OLD tables carry no CASCADE), every row is
-- copied, and COMMIT validates a consistent schema.
--
-- Idempotent at the file level: db_migrate() records the version in
-- schema_migration and never re-applies it; a mid-file failure rolls the
-- whole transaction back, leaving the previous schema intact.

PRAGMA defer_foreign_keys = ON;

-- 1. Rebuild `plot` with ON DELETE CASCADE -> monitoring_zone(id).
CREATE TABLE plot_new (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    zone_id    INTEGER NOT NULL REFERENCES monitoring_zone(id) ON DELETE CASCADE,
    plot_id    TEXT    NOT NULL,
    plot_type  TEXT,
    geom_wkt   TEXT    NOT NULL,
    radius_m   NUMERIC NOT NULL DEFAULT 15,
    UNIQUE (zone_id, plot_id)
);

INSERT INTO plot_new (id, zone_id, plot_id, plot_type, geom_wkt, radius_m)
    SELECT id, zone_id, plot_id, plot_type, geom_wkt, radius_m FROM plot;

DROP TABLE plot;
ALTER TABLE plot_new RENAME TO plot;

-- 2. Rebuild `alert` with ON DELETE CASCADE -> plot(id). Columns follow
--    the physical order produced by 0001 then the 0002 ADD COLUMNs.
CREATE TABLE alert_new (
    id                INTEGER   PRIMARY KEY AUTOINCREMENT,
    plot_id           INTEGER   NOT NULL REFERENCES plot(id) ON DELETE CASCADE,
    alert_type        TEXT      NOT NULL,
    trigger_date      DATE      NOT NULL,
    value_before      DOUBLE,
    value_after       DOUBLE,
    delta             DOUBLE,
    created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    confidence_class  TEXT,
    stress_index      DOUBLE,
    validation_status TEXT      DEFAULT 'pending',
    validation_cause  TEXT,
    validated_by      TEXT,
    validated_at      TIMESTAMP,
    UNIQUE (plot_id, alert_type, trigger_date)
);

INSERT INTO alert_new (id, plot_id, alert_type, trigger_date, value_before,
                       value_after, delta, created_at, confidence_class,
                       stress_index, validation_status, validation_cause,
                       validated_by, validated_at)
    SELECT id, plot_id, alert_type, trigger_date, value_before,
           value_after, delta, created_at, confidence_class,
           stress_index, validation_status, validation_cause,
           validated_by, validated_at FROM alert;

DROP TABLE alert;
ALTER TABLE alert_new RENAME TO alert;

-- 3. Recreate the indexes (dropped together with the old tables).
CREATE INDEX IF NOT EXISTS plot_zone_idx ON plot (zone_id);
CREATE INDEX IF NOT EXISTS alert_plot_idx    ON alert (plot_id);
CREATE INDEX IF NOT EXISTS alert_trigger_idx ON alert (trigger_date);
CREATE INDEX IF NOT EXISTS alert_validation_status_idx ON alert (validation_status);
CREATE INDEX IF NOT EXISTS alert_plot_date_type_idx    ON alert (plot_id, trigger_date, alert_type);
