-- Migration 0003 — project_uuid binding for monitoring_zone (DuckDB variant)
--
-- Mirrors `pg/0003_project_uuid.sql`. See that file for the full
-- rationale (spec 011).
--
-- Unlike PostgreSQL, DuckDB does NOT support partial indexes
-- ("Creating partial indexes is not supported currently"), so the
-- `WHERE project_uuid IS NOT NULL` clause used in the PG variant is
-- dropped here. A *full* UNIQUE index gives the same semantics: DuckDB
-- follows the SQL standard where NULLs are distinct for uniqueness
-- (NULLS DISTINCT), so multiple legacy rows with a NULL project_uuid
-- are tolerated while non-NULL values stay unique — which is exactly
-- what the partial index expresses on PG.
--
-- Idempotent.

ALTER TABLE monitoring_zone
    ADD COLUMN IF NOT EXISTS project_uuid TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS monitoring_zone_project_uuid_uq
    ON monitoring_zone (project_uuid);
