-- Migration 0005 — multiple monitoring zones per project (spec 020)
--
-- Spec 020 builds up to 4 monitoring zones per project from the UGF
-- union crossed with BD Forêt v2 strata (`<project>_tot/_feu/_res/_mix`).
-- They share the same `project_uuid` and differ only by `name`, so the
-- spec-011 uniqueness on `project_uuid` alone (migration 0003) is too
-- strict. Replace it with uniqueness on `(project_uuid, name)`: a project
-- may own several named zones, but never two zones with the same name.
--
-- Idempotent: DROP INDEX IF EXISTS + CREATE UNIQUE INDEX IF NOT EXISTS.
-- The partial `WHERE project_uuid IS NOT NULL` clause is kept so legacy
-- zones with a NULL project_uuid stay unconstrained.

DROP INDEX IF EXISTS monitoring_zone_project_uuid_uq;

CREATE UNIQUE INDEX IF NOT EXISTS monitoring_zone_project_name_uq
    ON monitoring_zone (project_uuid, name)
    WHERE project_uuid IS NOT NULL;
