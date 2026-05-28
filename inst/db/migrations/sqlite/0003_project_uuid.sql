-- Migration 0003 — project_uuid binding for monitoring_zone (SQLite variant)
--
-- Mirrors `pg/0003_project_uuid.sql`. See that file for the full
-- rationale (spec 011).
--
-- SQLite dialect notes:
--   * `ALTER TABLE ... ADD COLUMN` has no `IF NOT EXISTS`; db_migrate()
--     runs each migration once (schema_migration), so a plain ADD
--     COLUMN is safe.
--   * SQLite SUPPORTS partial indexes, so the `WHERE project_uuid IS
--     NOT NULL` clause from the PG variant is kept verbatim: the
--     uniqueness constraint applies only to non-NULL rows, while legacy
--     zones with a NULL project_uuid remain unconstrained.

ALTER TABLE monitoring_zone ADD COLUMN project_uuid TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS monitoring_zone_project_uuid_uq
    ON monitoring_zone (project_uuid)
    WHERE project_uuid IS NOT NULL;
