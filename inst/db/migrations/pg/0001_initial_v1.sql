-- Migration 0001_initial_v1 — schéma initial de la base de suivi (nemeton 1.0.0)
--
-- La 1.0.0 repart de zéro, sans migration des bases antérieures : ce
-- fichier unique remplace les migrations 0001_init à 0008_project_lock
-- (fusionnées) et produit exactement le schéma qu'elles laissaient, à une
-- différence près : TimescaleDB devient OPTIONNEL.
--
-- Une base créée par une version antérieure (versions 0001_init…0008_*
-- dans schema_migration, ou tables de suivi sans schema_migration) est
-- refusée par db_migrate() (« base antérieure à 1.0.0 : recréer ») : elle
-- n'est jamais migrée.
--
-- Extensions :
--   * timescaledb — optionnelle. Activée seulement si le serveur la propose
--     (pg_available_extensions) et qu'elle se charge ; sinon un NOTICE et
--     on continue. Aucune table n'en dépend : le schéma ne crée aucune
--     hypertable (la seule, obs_pixel, a été retirée en v0.60.0). Une
--     future hypertable devra elle aussi être conditionnelle
--     (`IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'timescaledb')`).
--   * postgis — requise, comme avant (ADR-002). Les géométries restent
--     stockées en WKT (TEXT).
-- pgvector est apporté par la migration opt-in rag/0004_rag.sql
-- (enable_rag()).

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'timescaledb') THEN
        BEGIN
            CREATE EXTENSION IF NOT EXISTS timescaledb;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'timescaledb is available but could not be enabled (%); continuing with plain tables', SQLERRM;
        END;
    ELSE
        RAISE NOTICE 'timescaledb is not available; continuing with plain tables';
    END IF;
END
$$;

CREATE EXTENSION IF NOT EXISTS postgis;

-- -----------------------------------------------------------------------
-- schema_migration — suivi des migrations appliquées
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS schema_migration (
    version    TEXT        PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------
-- monitoring_zone — zones de suivi (AOI)
-- -----------------------------------------------------------------------
-- `project_uuid` (spec 011) : identifiant opaque du projet nemetonshiny
-- (TEXT, pas UUID). Un projet porte jusqu'à 4 zones de strates
-- (`<projet>_tot/_feu/_res/_mix`, spec 020) : unicité sur
-- (project_uuid, name), partielle pour laisser libres les zones sans projet.
CREATE TABLE IF NOT EXISTS monitoring_zone (
    id           SERIAL      PRIMARY KEY,
    name         TEXT        NOT NULL,
    zone_wkt     TEXT        NOT NULL,
    crs_epsg     INTEGER     NOT NULL DEFAULT 2154,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by   TEXT,
    project_uuid TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS monitoring_zone_project_name_uq
    ON monitoring_zone (project_uuid, name)
    WHERE project_uuid IS NOT NULL;

-- -----------------------------------------------------------------------
-- plot — placettes suivies (typiquement points GRTS)
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS plot (
    id         SERIAL  PRIMARY KEY,
    zone_id    INTEGER NOT NULL REFERENCES monitoring_zone(id) ON DELETE CASCADE,
    plot_id    TEXT    NOT NULL,
    plot_type  TEXT,
    geom_wkt   TEXT    NOT NULL,
    radius_m   NUMERIC NOT NULL DEFAULT 15,
    UNIQUE (zone_id, plot_id)
);

CREATE INDEX IF NOT EXISTS plot_zone_idx ON plot (zone_id);

-- -----------------------------------------------------------------------
-- alert — alertes santé, entité pixel/cluster (spec 008 §15, ADR-013 A5)
-- -----------------------------------------------------------------------
-- Géoréférencée par le centroïde de cluster (`geom_wkt`, EPSG:4326) et
-- rattachée à la zone ; la placette est optionnelle. `alert_type` est
-- libre (ndvi_drop, nbr_drop, fordead_dieback, reconfort_dieback, …).
-- Colonnes de validation terrain : spec 008 §4, garde-fous G1/G4.
CREATE TABLE IF NOT EXISTS alert (
    id                SERIAL           PRIMARY KEY,
    zone_id           INTEGER          NOT NULL REFERENCES monitoring_zone(id) ON DELETE CASCADE,
    plot_id           INTEGER          REFERENCES plot(id) ON DELETE SET NULL,
    alert_type        TEXT             NOT NULL,
    trigger_date      DATE             NOT NULL,
    geom_wkt          TEXT,                              -- centroïde POINT, EPSG:4326
    n_pixels          INTEGER,
    area_m2           DOUBLE PRECISION,
    cluster_id        INTEGER,                           -- séquence intra-run
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
    -- Garde-fou intra-run : l'idempotence inter-runs est assurée par la
    -- stratégie « replace-by-window » côté R, pas par cette clé.
    UNIQUE (zone_id, alert_type, trigger_date, cluster_id)
);

CREATE INDEX IF NOT EXISTS alert_zone_idx              ON alert (zone_id);
CREATE INDEX IF NOT EXISTS alert_trigger_idx           ON alert (trigger_date);
CREATE INDEX IF NOT EXISTS alert_type_idx              ON alert (alert_type);
CREATE INDEX IF NOT EXISTS alert_validation_status_idx ON alert (validation_status);
-- Fusion multi-méthodes G2 (proximité spatiale + fenêtre temporelle).
CREATE INDEX IF NOT EXISTS alert_zone_date_type_idx    ON alert (zone_id, trigger_date, alert_type);

-- -----------------------------------------------------------------------
-- project_lock — verrou de projet (usage serveur multi-utilisateurs)
-- -----------------------------------------------------------------------
-- Matérialisé en table (pas un pg_advisory_lock) : l'app ouvre/ferme sa
-- connexion à chaque opération. Tenue par heartbeat, péremption par TTL
-- évaluée à la lecture (`now() - heartbeat_at > ttl`). `project_id` en
-- clé primaire : un projet = au plus un verrou ; pas de FK.
CREATE TABLE IF NOT EXISTS project_lock (
    project_id    TEXT        PRIMARY KEY,
    holder_id     TEXT        NOT NULL,        -- identité stable (email OAuth)
    holder_label  TEXT,                        -- nom affichable
    acquired_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    heartbeat_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
