-- Migration 0006 — ensure ON DELETE CASCADE on the monitoring_zone FK
-- chain (PostgreSQL variant)
--
-- The PG schema (0001_init.sql) already declares
--   plot.zone_id  -> monitoring_zone(id) ON DELETE CASCADE
--   alert.plot_id -> plot(id)            ON DELETE CASCADE
-- so the upsert in build_project_monitoring_zones(replace = TRUE) already
-- works on PostgreSQL. This migration is the PG counterpart of the SQLite
-- 0006 (which rebuilds the tables to *add* the missing CASCADE): it simply
-- guarantees the cascade is present, idempotently, on any PG database that
-- might predate it. On a schema created by 0001 it drops and re-adds the
-- two FK constraints unchanged (the inline REFERENCES in 0001 produces the
-- default constraint names `plot_zone_id_fkey` / `alert_plot_id_fkey`).

ALTER TABLE plot  DROP CONSTRAINT IF EXISTS plot_zone_id_fkey;
ALTER TABLE plot  ADD  CONSTRAINT plot_zone_id_fkey
    FOREIGN KEY (zone_id) REFERENCES monitoring_zone(id) ON DELETE CASCADE;

ALTER TABLE alert DROP CONSTRAINT IF EXISTS alert_plot_id_fkey;
ALTER TABLE alert ADD  CONSTRAINT alert_plot_id_fkey
    FOREIGN KEY (plot_id) REFERENCES plot(id) ON DELETE CASCADE;
