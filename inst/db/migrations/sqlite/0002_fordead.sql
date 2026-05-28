-- Migration 0002 — FORDEAD validation workflow (SQLite variant)
--
-- Mirrors `pg/0002_fordead.sql`. SQLite dialect notes:
--   * `TIMESTAMPTZ` → `TIMESTAMP`.
--   * SQLite `ALTER TABLE ... ADD COLUMN` does NOT support `IF NOT
--     EXISTS`, and only adds one column per statement (already the
--     case). `db_migrate()` never re-applies a recorded migration
--     (schema_migration), so a plain ADD COLUMN is safe and runs once.
--
-- Adds the FORDEAD validation columns and the two supporting indexes.

ALTER TABLE alert ADD COLUMN confidence_class  TEXT;
ALTER TABLE alert ADD COLUMN stress_index      DOUBLE;
ALTER TABLE alert ADD COLUMN validation_status TEXT DEFAULT 'pending';
ALTER TABLE alert ADD COLUMN validation_cause  TEXT;
ALTER TABLE alert ADD COLUMN validated_by      TEXT;
ALTER TABLE alert ADD COLUMN validated_at      TIMESTAMP;

-- Filter alerts by validation status (UI: "pending only", "confirmed only", …).
CREATE INDEX IF NOT EXISTS alert_validation_status_idx
  ON alert (validation_status);

-- Composite index for the rolling-window × FORDEAD fusion (G2): join
-- alerts of the same plot inside a ±30-day window across alert_types.
CREATE INDEX IF NOT EXISTS alert_plot_date_type_idx
  ON alert (plot_id, trigger_date, alert_type);
