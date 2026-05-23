-- Migration 0003 — project_uuid binding for monitoring_zone (DuckDB variant)
--
-- Mirrors `pg/0003_project_uuid.sql`. See that file for the full
-- rationale (spec 011). DuckDB supports the same `ALTER TABLE … ADD
-- COLUMN IF NOT EXISTS` and partial UNIQUE index syntax as PG since
-- v0.5; in addition DuckDB follows the SQL standard NULLS DISTINCT
-- default for UNIQUE constraints so the partial WHERE is explicit but
-- not strictly required.
--
-- Idempotent.

ALTER TABLE monitoring_zone
    ADD COLUMN IF NOT EXISTS project_uuid TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS monitoring_zone_project_uuid_uq
    ON monitoring_zone (project_uuid)
    WHERE project_uuid IS NOT NULL;
