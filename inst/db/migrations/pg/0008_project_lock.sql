-- Migration 0008 — verrou de projet pour usage serveur multi-utilisateurs.
--
-- Décision produit : un projet ouvert est verrouillé sur un seul
-- utilisateur (édition) ; les autres l'ouvrent en lecture seule.
--
-- Le verrou est matérialisé EN TABLE (pas un pg_advisory_lock) parce que
-- l'app ouvre/ferme sa connexion à chaque opération : un advisory lock,
-- lié à la durée de la connexion, serait relâché aussitôt. La tenue du
-- verrou pendant toute une session Shiny passe donc par un heartbeat
-- périodique + une péremption par TTL évaluée À LA LECTURE
-- (`now() - heartbeat_at > ttl`) — aucune colonne d'expiration, aucun job
-- de nettoyage. Un crash / une fermeture d'onglet stoppe le heartbeat →
-- le verrou devient périmé → un autre peut le reprendre (« vol »).
--
-- `project_id` en clé primaire : un projet = au plus un verrou.
-- Pas de FK vers une table `project` : le verrou est orthogonal au cycle
-- de vie du projet et `project_id` est l'identifiant applicatif (TEXT).

CREATE TABLE IF NOT EXISTS project_lock (
    project_id    TEXT        PRIMARY KEY,
    holder_id     TEXT        NOT NULL,        -- identité stable (email OAuth)
    holder_label  TEXT,                        -- nom affichable ("Prénom Nom")
    acquired_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    heartbeat_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
