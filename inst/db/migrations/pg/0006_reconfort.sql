-- Migration 0006 — RECONFORT broadleaf-dieback alerts (spec 021 / L3)
--
-- RECONFORT writes its alerts into the existing `alert` table with
-- `alert_type = 'reconfort_dieback'`, reusing the `confidence_class`
-- and `stress_index` columns added for FORDEAD in migration 0002. No
-- new column is therefore required (spec 021 §8.3).
--
-- The only addition is an index on `alert_type` so the per-method
-- filtering / JOINs (`reconfort_dieback`, `fordead_dieback`,
-- `ndvi_drop`, ...) used by the G2 fusion and the leaflet layers stay
-- cheap as the table grows.
--
-- (The spec drafted this as "0005_reconfort.sql"; 0005 was meanwhile
-- taken by spec 020 multi-zone, so RECONFORT lands on 0006.)
--
-- Idempotent: CREATE INDEX IF NOT EXISTS.

CREATE INDEX IF NOT EXISTS alert_type_idx ON alert (alert_type);
