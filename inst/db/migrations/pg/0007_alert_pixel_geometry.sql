-- Migration 0007 — l'alerte santé devient une entité pixel/cluster
-- (spec 008 §15 Phase B, ADR-013 A5, décisions D-B1 à D-B4).
--
-- La placette est découplée du suivi sanitaire : l'alerte n'est plus
-- ancrée sur `plot` mais géoréférencée par le centroïde de cluster
-- (`geom_wkt`, EPSG:4326, D-B2) et rattachée à la zone de suivi
-- (`zone_id`). `plot_id` devient optionnel.
--
-- Mécanique D-B3 : DROP + CREATE. La table `alert` est VIDE (contrat
-- Phase A, v0.92.0 — `TRUNCATE` + plus aucune insertion) et n'a aucun
-- enfant FK : la recréer est sûr et portable, sans les écueils de
-- `ALTER` (SQLite ne sait pas DROP NOT NULL / DROP CONSTRAINT) ni des
-- FK différées sous la transaction unique de db_migrate().
--
-- PRÉ-VOL DE DÉPLOIEMENT : vérifier `SELECT count(*) FROM alert = 0`
-- avant d'appliquer cette migration sur une base de production.

DROP TABLE IF EXISTS alert;

CREATE TABLE alert (
    id                SERIAL           PRIMARY KEY,
    zone_id           INTEGER          NOT NULL REFERENCES monitoring_zone(id) ON DELETE CASCADE,
    plot_id           INTEGER          REFERENCES plot(id) ON DELETE SET NULL,
    alert_type        TEXT             NOT NULL,
    trigger_date      DATE             NOT NULL,
    geom_wkt          TEXT,                              -- centroïde POINT, EPSG:4326 (D-B2)
    n_pixels          INTEGER,
    area_m2           DOUBLE PRECISION,
    cluster_id        INTEGER,                           -- séquence intra-run (cf. garde-fou UNIQUE)
    confidence_class  TEXT,
    stress_index      DOUBLE PRECISION,
    validation_status TEXT             NOT NULL DEFAULT 'pending',
    validation_cause  TEXT,
    validated_by      TEXT,
    validated_at      TIMESTAMPTZ,
    value_before      DOUBLE PRECISION,
    value_after       DOUBLE PRECISION,
    delta             DOUBLE PRECISION,
    created_at        TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    -- Garde-fou intra-run (D-B1) : l'idempotence inter-runs est assurée
    -- par la stratégie « replace-by-window » côté R, pas par cette clé.
    UNIQUE (zone_id, alert_type, trigger_date, cluster_id)
);

CREATE INDEX alert_zone_idx              ON alert (zone_id);
CREATE INDEX alert_trigger_idx           ON alert (trigger_date);
CREATE INDEX alert_type_idx              ON alert (alert_type);
CREATE INDEX alert_validation_status_idx ON alert (validation_status);
-- Fusion multi-méthodes G2 (proximité spatiale + fenêtre temporelle).
CREATE INDEX alert_zone_date_type_idx    ON alert (zone_id, trigger_date, alert_type);
