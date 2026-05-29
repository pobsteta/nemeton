-- Migration 0004_rag — RAG knowledge base (spec 009 / E7), PostgreSQL variant
--
-- OPT-IN migration: this file lives in the `rag/` subdirectory and is
-- therefore NOT picked up by the default db_migrate() sequence (which
-- lists only the top-level pg/ directory). It is applied explicitly by
-- enable_rag(con).
--
-- Why opt-in: this migration requires the `vector` extension (pgvector).
-- Existing TimescaleDB deployments (e.g. the production monitoring DB)
-- do not necessarily have pgvector installed at the server level, and
-- folding `CREATE EXTENSION vector` into the auto-applied sequence would
-- make the next db_migrate() fail there. RAG stays a feature you turn on
-- when the server is ready for it (ADR-012).
--
-- Idempotent: every statement is IF NOT EXISTS. db_migrate() also records
-- the applied version in schema_migration so this normally runs once.

CREATE EXTENSION IF NOT EXISTS vector;

-- -----------------------------------------------------------------------
-- knowledge_document — source documents (paper, report, regulation, …)
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge_document (
    id            SERIAL       PRIMARY KEY,
    title         TEXT         NOT NULL,
    author        TEXT,
    publisher     TEXT,
    pub_date      DATE,
    lang          TEXT         NOT NULL,         -- ISO 639-1 ('fr', 'en', …)
    doc_type      TEXT         NOT NULL,         -- paper|report|regulation|manual|note|web
    source_url    TEXT,
    license       TEXT         NOT NULL,         -- CC-BY|OGL|public-domain|unknown|restricted
    family_codes  TEXT[],                        -- ['B','R'] or indicator ['R5']
    profile_codes TEXT[],                        -- ['gestionnaire_onf', ...]
    embed_model   TEXT,                          -- provider:model used for embeddings
    metadata      JSONB        NOT NULL DEFAULT '{}'::jsonb,
    ingested_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    ingested_by   TEXT
);

CREATE INDEX IF NOT EXISTS knowledge_document_lang_idx     ON knowledge_document (lang);
CREATE INDEX IF NOT EXISTS knowledge_document_doc_type_idx ON knowledge_document (doc_type);
CREATE INDEX IF NOT EXISTS knowledge_document_family_gin   ON knowledge_document USING GIN (family_codes);

-- -----------------------------------------------------------------------
-- knowledge_chunk — vectorised text chunks
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge_chunk (
    id            SERIAL          PRIMARY KEY,
    document_id   INTEGER         NOT NULL REFERENCES knowledge_document(id)
                                  ON DELETE CASCADE,
    chunk_index   INTEGER         NOT NULL,      -- 0..N-1 per document
    page_number   INTEGER,                       -- for PDFs, NULL otherwise
    text          TEXT            NOT NULL,
    text_hash     TEXT            NOT NULL,       -- hash of text, intra-doc dedup
    token_count   INTEGER,
    embedding     vector(3072),                  -- widest dim: accommodates OpenAI
                                                  -- text-embedding-3-large native
                                                  -- (3072) and zero-padded Mistral /
                                                  -- Voyage (1024) / OpenAI small (1536).
                                                  -- Provider switch needs no schema
                                                  -- migration (re-embedding required).
    UNIQUE (document_id, chunk_index)
);

CREATE INDEX IF NOT EXISTS knowledge_chunk_doc_idx ON knowledge_chunk (document_id);

-- NOTE — no ANN index on `embedding`.
--
-- The spec proposed `ivfflat (embedding vector_cosine_ops)`, but pgvector's
-- ivfflat AND hnsw indexes cap at 2000 dimensions, while the column is
-- vector(3072) (the "widest provider" decision). A 3072-dim column simply
-- cannot carry an ivfflat/hnsw index. retrieve_knowledge() therefore runs an
-- EXACT cosine KNN (`<=>` over a seq scan), which is sub-50 ms for a V1
-- corpus of a few thousand chunks.
--
-- When the corpus outgrows exact search, switch to `halfvec(3072)` +
-- `hnsw (... halfvec_cosine_ops)` (pgvector >= 0.7 supports halfvec up to
-- 4000 dims) in a follow-up migration — tracked under ADR-012.
