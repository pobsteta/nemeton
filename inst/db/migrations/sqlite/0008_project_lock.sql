-- Migration 0008 — verrou de projet (voir la version pg/ pour le rationnel).
-- Portage SQLite : TIMESTAMPTZ → TIMESTAMP, NOW() → CURRENT_TIMESTAMP.
-- Les timestamps SQLite sont stockés en UTC ('YYYY-MM-DD HH:MM:SS'), donc
-- la comparaison de péremption via datetime('now', '-N seconds') est correcte.

CREATE TABLE IF NOT EXISTS project_lock (
    project_id    TEXT      PRIMARY KEY,
    holder_id     TEXT      NOT NULL,
    holder_label  TEXT,
    acquired_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    heartbeat_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
