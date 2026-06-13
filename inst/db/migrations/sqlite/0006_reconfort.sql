-- Migration 0006 — RECONFORT broadleaf-dieback alerts (SQLite variant)
--
-- Mirrors `pg/0006_reconfort.sql`. See that file for the rationale
-- (spec 021 / L3): RECONFORT reuses the `alert` table with
-- `alert_type = 'reconfort_dieback'` and the FORDEAD columns
-- `confidence_class` / `stress_index` (migration 0002); the only
-- addition is an index on `alert_type`.
--
-- SQLite dialect notes:
--   * CREATE INDEX IF NOT EXISTS is supported.
--   * db_migrate() splits this file on `;` and runs each statement once.

CREATE INDEX IF NOT EXISTS alert_type_idx ON alert (alert_type);
