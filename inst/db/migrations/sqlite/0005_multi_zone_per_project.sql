-- Migration 0005 — multiple monitoring zones per project (SQLite variant)
--
-- Mirrors `pg/0005_multi_zone_per_project.sql`. See that file for the
-- full rationale (spec 020): a project may own up to 4 strata zones
-- (`<project>_tot/_feu/_res/_mix`) sharing one `project_uuid`, so the
-- spec-011 uniqueness on `project_uuid` alone is relaxed to
-- `(project_uuid, name)`.
--
-- SQLite dialect notes:
--   * DROP INDEX IF EXISTS and partial UNIQUE indexes are both supported.
--   * db_migrate() splits this file on `;` and runs each statement once.

DROP INDEX IF EXISTS monitoring_zone_project_uuid_uq;

CREATE UNIQUE INDEX IF NOT EXISTS monitoring_zone_project_name_uq
    ON monitoring_zone (project_uuid, name)
    WHERE project_uuid IS NOT NULL;
