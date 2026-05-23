-- Migration 0003 — project_uuid binding for monitoring_zone (spec 011)
--
-- Stable link between a `nemetonshiny` project and the monitoring zone
-- it registered. Lets the app re-hydrate `monitoring_zone_id` from the
-- core DB when a project is reloaded but its `metadata.json` does not
-- carry the id (e.g. project moved between machines, metadata wiped,
-- zone registered before the field existed). See spec 011.
--
-- Idempotent: every statement uses IF NOT EXISTS so re-running the
-- migration on a database that already has the column is a no-op.
--
-- `project_uuid` is opaque to the core: the app sets it to whatever
-- identity it uses for projects (UUID v4, `<ts>_<rand>`, …) hence
-- TEXT, not UUID. NULL is allowed so legacy zones registered before
-- this migration keep working; the partial UNIQUE index makes the
-- uniqueness constraint apply only to non-NULL rows.

ALTER TABLE monitoring_zone
    ADD COLUMN IF NOT EXISTS project_uuid TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS monitoring_zone_project_uuid_uq
    ON monitoring_zone (project_uuid)
    WHERE project_uuid IS NOT NULL;
