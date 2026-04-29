-- Migration 0002 — FORDEAD validation workflow (spec 008 / E6.c.2)
--
-- Idempotent: every statement uses IF NOT EXISTS so re-running the
-- migration on a database that already has the v0.21.0 schema is a
-- no-op.
--
-- Extends `alert` to support FORDEAD dieback alerts and the field
-- validation workflow (spec 008, garde-fous G1, G4):
--   - confidence_class : "1-faible" / "2-moyenne" / "3-forte" / "4-sol-nu"
--   - stress_index     : per-cluster mean of the FORDEAD harmonic
--                        anomaly score (numeric scalar)
--   - validation_*     : terrain validation columns updated by the
--                        QField ingest path (spec 008 §4)
--
-- The `alert_type` column intentionally stays free-form (no CHECK
-- constraint). Today's vocabulary is {ndvi_drop, nbr_drop,
-- fordead_dieback}; future health/risk pipelines will extend it.

ALTER TABLE alert
  ADD COLUMN IF NOT EXISTS confidence_class  TEXT,
  ADD COLUMN IF NOT EXISTS stress_index      DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS validation_status TEXT NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS validation_cause  TEXT,
  ADD COLUMN IF NOT EXISTS validated_by      TEXT,
  ADD COLUMN IF NOT EXISTS validated_at      TIMESTAMPTZ;

-- Filter alerts by validation status (UI: "pending only", "confirmed only", …).
CREATE INDEX IF NOT EXISTS alert_validation_status_idx
  ON alert (validation_status);

-- Composite index for the rolling-window × FORDEAD fusion (G2): join
-- alerts of the same plot inside a ±30-day window across alert_types.
CREATE INDEX IF NOT EXISTS alert_plot_date_type_idx
  ON alert (plot_id, trigger_date, alert_type);
