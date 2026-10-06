-- Migration 0001_initial_v1 — schéma initial (variante SQLite, nemeton 1.0.0)
--
-- Pendant SQLite de `pg/0001_initial_v1.sql` : remplace les migrations
-- 0001_init à 0008_project_lock (fusionnées), sans migration des bases
-- antérieures — db_migrate() refuse une base créée avant la 1.0.0
-- (« base antérieure à 1.0.0 : recréer »).
--
-- SQLite en mode WAL est le backend local : un écrivain + plusieurs
-- lecteurs concurrents entre processus (session Shiny + worker).
--
-- Différences de dialecte avec la variante PG :
--   * pas de `CREATE EXTENSION` (ni TimescaleDB, ni PostGIS) ;
--   * `SERIAL` → `INTEGER PRIMARY KEY AUTOINCREMENT` ;
--   * `TIMESTAMPTZ` → `TIMESTAMP` (UTC 'YYYY-MM-DD HH:MM:SS' : la
--     péremption de project_lock compare via datetime('now', '-N seconds')),
--     `DOUBLE PRECISION` → `DOUBLE`, `NOW()` → `CURRENT_TIMESTAMP` ;
--   * `plot.zone_id` n'a PAS de `ON DELETE CASCADE` (restriction
--     historique conservée : .delete_project_zones() supprime la chaîne
--     enfant d'abord, portable sur les deux moteurs) ;
--   * les clés étrangères ne sont appliquées qu'avec
--     `PRAGMA foreign_keys = ON`, que db_connect() pose à chaque connexion.
--
-- Nouveauté 1.0.0 : `alert.validation_status` est NOT NULL DEFAULT
-- 'pending', comme sous PostgreSQL (l'ancien ALTER TABLE … ADD COLUMN de
-- SQLite ne posait pas la contrainte).
--
-- db_migrate() découpe ce fichier sur `;` et exécute chaque instruction.

-- -----------------------------------------------------------------------
-- schema_migration — suivi des migrations appliquées
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS schema_migration (
    version    TEXT      PRIMARY KEY,
    applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------
-- monitoring_zone — zones de suivi (AOI)
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS monitoring_zone (
    id           INTEGER   PRIMARY KEY AUTOINCREMENT,
    name         TEXT      NOT NULL,
    zone_wkt     TEXT      NOT NULL,
    crs_epsg     INTEGER   NOT NULL DEFAULT 2154,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by   TEXT,
    project_uuid TEXT
);

-- Un projet peut porter plusieurs zones nommées (spec 020), jamais deux
-- zones de même nom ; index partiel : zones sans projet non contraintes.
CREATE UNIQUE INDEX IF NOT EXISTS monitoring_zone_project_name_uq
    ON monitoring_zone (project_uuid, name)
    WHERE project_uuid IS NOT NULL;

-- -----------------------------------------------------------------------
-- plot — placettes suivies (typiquement points GRTS)
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS plot (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    zone_id    INTEGER NOT NULL REFERENCES monitoring_zone(id),
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
CREATE TABLE IF NOT EXISTS alert (
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
    validation_status TEXT      NOT NULL DEFAULT 'pending',
    validation_cause  TEXT,
    validated_by      TEXT,
    validated_at      TIMESTAMP,
    value_before      DOUBLE,
    value_after       DOUBLE,
    delta             DOUBLE,
    created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (zone_id, alert_type, trigger_date, cluster_id)
);

CREATE INDEX IF NOT EXISTS alert_zone_idx              ON alert (zone_id);
CREATE INDEX IF NOT EXISTS alert_trigger_idx           ON alert (trigger_date);
CREATE INDEX IF NOT EXISTS alert_type_idx              ON alert (alert_type);
CREATE INDEX IF NOT EXISTS alert_validation_status_idx ON alert (validation_status);
CREATE INDEX IF NOT EXISTS alert_zone_date_type_idx    ON alert (zone_id, trigger_date, alert_type);

-- -----------------------------------------------------------------------
-- project_lock — verrou de projet (voir la variante pg/ pour le rationnel)
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS project_lock (
    project_id    TEXT      PRIMARY KEY,
    holder_id     TEXT      NOT NULL,
    holder_label  TEXT,
    acquired_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    heartbeat_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
