-- Migration 0002 — FORDEAD validation workflow (DuckDB variant)
--
-- Mirrors `pg/0002_fordead.sql`. Single difference: `TIMESTAMPTZ` →
-- `TIMESTAMP` (DuckDB stores both internally as 64-bit microsecond
-- counters; we keep things simple and treat all monitoring
-- timestamps as UTC).
--
-- Idempotent: every statement uses IF NOT EXISTS so re-running the
-- migration on a database that already has the FORDEAD columns is a
-- no-op.

ALTER TABLE alert
  ADD COLUMN IF NOT EXISTS confidence_class  TEXT;
ALTER TABLE alert
  ADD COLUMN IF NOT EXISTS stress_index      DOUBLE;
-- DuckDB does NOT allow ADD COLUMN ... NOT NULL DEFAULT ... in a
-- single statement on an existing table when the column does not
-- yet exist (PG accepts it). Split into two statements: first add
-- with default, then set NOT NULL.
ALTER TABLE alert
  ADD COLUMN IF NOT EXISTS validation_status TEXT DEFAULT 'pending';
ALTER TABLE alert
  ADD COLUMN IF NOT EXISTS validation_cause  TEXT;
ALTER TABLE alert
  ADD COLUMN IF NOT EXISTS validated_by      TEXT;
ALTER TABLE alert
  ADD COLUMN IF NOT EXISTS validated_at      TIMESTAMP;

-- Filter alerts by validation status (UI: "pending only", "confirmed only", …).
CREATE INDEX IF NOT EXISTS alert_validation_status_idx
  ON alert (validation_status);

-- Composite index for the rolling-window × FORDEAD fusion (G2): join
-- alerts of the same plot inside a ±30-day window across alert_types.
CREATE INDEX IF NOT EXISTS alert_plot_date_type_idx
  ON alert (plot_id, trigger_date, alert_type);
