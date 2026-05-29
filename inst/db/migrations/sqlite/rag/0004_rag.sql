-- Migration 0004_rag — RAG knowledge base (spec 009 / E7), SQLite variant
--
-- Mirrors pg/rag/0004_rag.sql for the local SQLite backend. Like the PG
-- variant it is OPT-IN (lives in the rag/ subdir, applied by enable_rag()),
-- though SQLite needs no extension — the opt-in keeps the two backends
-- symmetrical and lets a project enable RAG independently of the base
-- monitoring schema.
--
-- Differences from the PG variant:
--
--   * No `CREATE EXTENSION vector` — SQLite has no pgvector. Embeddings are
--     stored as a JSON array of floats in a TEXT column; retrieve_knowledge()
--     computes the cosine similarity in R (fine for a single-project corpus).
--   * `TEXT[]` (family_codes / profile_codes) → TEXT holding a JSON array,
--     since SQLite has no array type. Filtering is done in R.
--   * `JSONB` → TEXT holding JSON.
--   * `SERIAL` → `INTEGER PRIMARY KEY AUTOINCREMENT`.
--   * `ON DELETE CASCADE` is KEPT here (unlike the monitoring tables): RAG
--     does delete documents via delete_knowledge_document(), and the cascade
--     to knowledge_chunk is enforced because db_connect() sets
--     `PRAGMA foreign_keys = ON` on every connection.
--
-- Idempotent: every statement is IF NOT EXISTS.

-- -----------------------------------------------------------------------
-- knowledge_document — source documents (paper, report, regulation, …)
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge_document (
    id            INTEGER   PRIMARY KEY AUTOINCREMENT,
    title         TEXT      NOT NULL,
    author        TEXT,
    publisher     TEXT,
    pub_date      DATE,
    lang          TEXT      NOT NULL,            -- ISO 639-1 ('fr', 'en', …)
    doc_type      TEXT      NOT NULL,            -- paper|report|regulation|manual|note|web
    source_url    TEXT,
    license       TEXT      NOT NULL,            -- CC-BY|OGL|public-domain|unknown|restricted
    family_codes  TEXT,                          -- JSON array, e.g. '["B","R"]'
    profile_codes TEXT,                          -- JSON array
    embed_model   TEXT,                          -- provider:model used for embeddings
    metadata      TEXT      NOT NULL DEFAULT '{}',-- JSON object
    ingested_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ingested_by   TEXT
);

CREATE INDEX IF NOT EXISTS knowledge_document_lang_idx     ON knowledge_document (lang);
CREATE INDEX IF NOT EXISTS knowledge_document_doc_type_idx ON knowledge_document (doc_type);

-- -----------------------------------------------------------------------
-- knowledge_chunk — text chunks with JSON-encoded embeddings
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge_chunk (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id   INTEGER NOT NULL REFERENCES knowledge_document(id)
                          ON DELETE CASCADE,
    chunk_index   INTEGER NOT NULL,              -- 0..N-1 per document
    page_number   INTEGER,                       -- for PDFs, NULL otherwise
    text          TEXT    NOT NULL,
    text_hash     TEXT    NOT NULL,              -- hash of text, intra-doc dedup
    token_count   INTEGER,
    embedding     TEXT,                          -- JSON array of floats
    UNIQUE (document_id, chunk_index)
);

CREATE INDEX IF NOT EXISTS knowledge_chunk_doc_idx ON knowledge_chunk (document_id);
