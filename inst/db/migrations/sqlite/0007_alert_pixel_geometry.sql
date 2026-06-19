-- Migration 0007 — l'alerte santé devient une entité pixel/cluster
-- (spec 008 §15 Phase B, ADR-013 A5, décisions D-B1 à D-B4). Variante
-- SQLite de `pg/0007_alert_pixel_geometry.sql`.
--
-- Dialecte SQLite : `SERIAL` → `INTEGER PRIMARY KEY AUTOINCREMENT`,
-- `DOUBLE PRECISION` → `DOUBLE`, `TIMESTAMPTZ` → `TIMESTAMP`,
-- `NOW()` → `CURRENT_TIMESTAMP`.
--
-- Mécanique D-B3 : DROP + CREATE (table vide, contrat Phase A ; aucun
-- enfant FK). DROP TABLE supprime aussi ses index. PRÉ-VOL : la table
-- doit être vide avant déploiement.

DROP TABLE IF EXISTS alert;

CREATE TABLE alert (
    id                INTEGER   PRIMARY KEY AUTOINCREMENT,
    zone_id           INTEGER   NOT NULL REFERENCES monitoring_zone(id) ON DELETE CASCADE,
    plot_id           INTEGER   REFERENCES plot(id) ON DELETE SET NULL,
    alert_type        TEXT      NOT NULL,
    trigger_date      DATE      NOT NULL,
    geom_wkt          TEXT,
    n_pixels          INTEGER,
    area_m2           DOUBLE,
    cluster_id        INTEGER,
    confidence_class  TEXT,
    stress_index      DOUBLE,
    validation_status TEXT      DEFAULT 'pending',
    validation_cause  TEXT,
    validated_by      TEXT,
    validated_at      TIMESTAMP,
    value_before      DOUBLE,
    value_after       DOUBLE,
    delta             DOUBLE,
    created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (zone_id, alert_type, trigger_date, cluster_id)
);

CREATE INDEX alert_zone_idx              ON alert (zone_id);
CREATE INDEX alert_trigger_idx           ON alert (trigger_date);
CREATE INDEX alert_type_idx              ON alert (alert_type);
CREATE INDEX alert_validation_status_idx ON alert (validation_status);
CREATE INDEX alert_zone_date_type_idx    ON alert (zone_id, trigger_date, alert_type);
