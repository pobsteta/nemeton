# Plan technique : RAG pour perspectives IA

**Version** : 0.1.0 (draft, suit `spec.md` v0.1.0)
**Date**    : 2026-05-15
**Statut**  : Draft — prêt pour `tasks.md` une fois validé
**Cible**   : `nemeton` v0.23.0
**Dépend de** : `nemeton` ≥ v0.22.0 (pas d'incompatibilité), image `timescaledb-ha:pg16` (pgvector embarqué depuis 2026-05-05)

---

## 1. Stack technique

### 1.1 Côté cœur `nemeton` (R)

| Composant | Rôle | État |
|-----------|------|------|
| `DBI` (≥ 1.0) | Connexions PostgreSQL / DuckDB | déjà Suggests |
| `RPostgres` (≥ 1.4) | Pilote PG natif pour pgvector | déjà Suggests |
| `httr2` (≥ 1.0) | Appels HTTP Mistral / OpenAI embeddings | déjà Suggests |
| `pdftools` (≥ 3.0) | Extraction texte PDF | **à ajouter en Suggests** |
| `digest` (≥ 0.6) | sha256 des chunks pour dédup | **à ajouter en Imports** |
| `jsonlite` (≥ 1.8) | Serialisation JSONB metadata | déjà Imports |
| `cli` (≥ 3.6) | Progress bar batch ingestion | déjà Imports |
| `tibble` (optionnel) | Pretty-print du `retrieve_knowledge` retour | déjà transitif |

### 1.2 PostgreSQL extensions

- **pgvector** ≥ 0.7 (image `timescaledb-ha:pg16` embarque 0.8). Vérifié dispo sur la stack actuelle (`SELECT extname FROM pg_extension WHERE extname = 'vector'`).
- **postgis** déjà actif (depuis v0.21.0).
- **timescaledb** déjà actif (depuis v0.20.0).

### 1.3 APIs externes

| API | Endpoint | Modèle | Dim native | Coût indicatif |
|-----|----------|--------|------------|----------------|
| Mistral (default) | `https://api.mistral.ai/v1/embeddings` | `mistral-embed` | **1024** | ~0.10 €/M tokens |
| OpenAI | `https://api.openai.com/v1/embeddings` | `text-embedding-3-large` | **3072** | ~0.13 $/M tokens |
| OpenAI (light) | idem | `text-embedding-3-small` | **1536** | ~0.02 $/M tokens |
| Voyage (Anthropic) | `https://api.voyageai.com/v1/embeddings` | `voyage-3-large` | **1024** (Matryoshka jusqu'à 2048) | ~0.12 $/M tokens |

**Anthropic / Claude** : pas d'endpoint embeddings. Pour rester dans l'écosystème Anthropic, on route vers Voyage AI (recommandation officielle Anthropic depuis 2024).

**Stockage en `vector(3072)`** : tous les vecteurs sont **zero-paddés à 3072** au moment de l'INSERT. Coût : 3× le stockage par vecteur (~12 MB pour 1500 chunks vs ~4 MB) — négligeable. Bénéfice : changement de provider sans migration de schéma.

**Estimation budget** : un corpus de 30 documents × ~20 pages × ~500 tokens/page × 1 embed/chunk de 512 tokens ≈ 300 000 tokens → ~0.03 € avec Mistral. Re-ingestion complète mensuelle bénigne. Pour passer à OpenAI : ~0.04 $ pour le même corpus.

### 1.4 DuckDB ne supporte PAS pgvector

Décision tranchée : **RAG = PostgreSQL only**. Quand `con` est une `duckdb_connection`, toutes les fonctions RAG lèvent un message clair :

```
RAG features require PostgreSQL + pgvector. Switch backend or skip RAG.
```

Ce n'est pas un revirement d'ADR-002 (qui acceptait DuckDB comme alternative locale) : le RAG est une feature optionnelle non couverte par DuckDB. Documenté dans le man `retrieve_knowledge`.

---

## 2. Schéma DB et migration `0003_rag.sql`

### 2.1 Migration

Fichier : `inst/db/migrations/pg/0003_rag.sql` (variante DuckDB : `inst/db/migrations/duckdb/0003_rag.sql` contient seulement un commentaire « RAG not supported on DuckDB; skipping. » pour rester idempotent).

```sql
-- Idempotent: re-running 0003 must be a no-op.
CREATE EXTENSION IF NOT EXISTS vector;

-- ----------------------------------------------------------------------
-- knowledge_document — one row per source document (PDF, paper, ...)
-- ----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge_document (
  id            SERIAL       PRIMARY KEY,
  title         TEXT         NOT NULL,
  author        TEXT,
  publisher     TEXT,
  pub_date      DATE,
  lang          TEXT         NOT NULL,
  doc_type      TEXT         NOT NULL,
  source_url    TEXT,
  license       TEXT         NOT NULL,
  family_codes  TEXT[],
  profile_codes TEXT[],
  metadata      JSONB        NOT NULL DEFAULT '{}'::jsonb,
  ingested_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
  ingested_by   TEXT
);

CREATE INDEX IF NOT EXISTS knowledge_document_lang_idx
  ON knowledge_document (lang);
CREATE INDEX IF NOT EXISTS knowledge_document_doc_type_idx
  ON knowledge_document (doc_type);
CREATE INDEX IF NOT EXISTS knowledge_document_family_gin
  ON knowledge_document USING GIN (family_codes);
CREATE INDEX IF NOT EXISTS knowledge_document_profile_gin
  ON knowledge_document USING GIN (profile_codes);

-- ----------------------------------------------------------------------
-- knowledge_chunk — vectorised passages, one row per chunk
-- ----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge_chunk (
  id            SERIAL          PRIMARY KEY,
  document_id   INTEGER         NOT NULL
                                REFERENCES knowledge_document(id)
                                ON DELETE CASCADE,
  chunk_index   INTEGER         NOT NULL,
  page_number   INTEGER,
  text          TEXT            NOT NULL,
  text_hash     TEXT            NOT NULL,
  token_count   INTEGER,
  embedding     vector(3072),                 -- widest reasonable target:
                                              -- OpenAI text-embedding-3-large
                                              -- native, Mistral / Voyage 1024
                                              -- zero-padded, OpenAI small 1536
                                              -- padded. Provider switch w/o
                                              -- schema migration (re-embedding
                                              -- of corpus still required).
  UNIQUE (document_id, chunk_index)
);

CREATE INDEX IF NOT EXISTS knowledge_chunk_doc_idx
  ON knowledge_chunk (document_id);

-- ivfflat with lists=100 is fine up to ~100k chunks. For larger
-- corpora, switch to HNSW (pgvector ≥ 0.7) via a future migration.
CREATE INDEX IF NOT EXISTS knowledge_chunk_embedding_idx
  ON knowledge_chunk USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);
```

### 2.2 Pas de hypertable

`knowledge_chunk` n'est PAS chunked par date (pas de dimension temporelle nécessaire). On reste sur une table PG classique. Aucun bénéfice à hyper-chunker un corpus de < 1M chunks.

### 2.3 Coupling avec `db_migrate()`

La logique de migration côté R (`R/db.R::db_migrate`) lit déjà les fichiers `.sql` de `inst/db/migrations/{backend}/` par ordre alphanumérique. Aucun changement à faire — il suffit de déposer `0003_rag.sql` au bon endroit.

---

## 3. Pipeline d'ingestion — séquence détaillée

### 3.1 Fonction d'orchestration

```r
ingest_knowledge_document <- function(
    con,
    source,
    metadata,
    chunk_size      = 512L,
    chunk_overlap   = 50L,
    embed_provider  = c("mistral", "openai"),
    api_key         = NULL
) {
  embed_provider <- match.arg(embed_provider)
  .assert_pgvector(con)
  .validate_ingest_metadata(metadata)

  # Phase 1 — lecture
  text <- .read_source(source)        # PDF / .txt / .md / raw

  # Phase 2 — découpage
  chunks <- .chunk_text(text, size = chunk_size, overlap = chunk_overlap)
  # chunks : list of named list(text, page_number?, token_count, text_hash)

  # Phase 3 — embeddings par batch (Mistral max 32 inputs/req)
  texts <- vapply(chunks, `[[`, character(1), "text")
  embeds <- .embed_batch(texts, provider = embed_provider,
                         api_key = api_key, batch_size = 32L)

  # Phase 4 — persistance atomique
  doc_id <- DBI::dbWithTransaction(con, {
    doc_id <- .insert_knowledge_document(con, metadata)
    .insert_knowledge_chunks(con, doc_id, chunks, embeds)
    doc_id
  })

  invisible(list(
    document_id    = as.integer(doc_id),
    n_chunks       = length(chunks),
    n_tokens_est   = sum(vapply(chunks, `[[`, integer(1), "token_count")),
    duration_sec   = NULL  # rempli par un wrapper timing si verbose
  ))
}
```

### 3.2 Phases internes

#### Phase 1 — `.read_source(source)`

- Si `endsWith(source, ".pdf")` → `pdftools::pdf_text(source)` retourne un vecteur de pages (1 chr par page). On garde le mapping page → texte pour conserver le `page_number` côté chunks.
- Si `endsWith(source, c(".txt", ".md"))` → `readLines() |> paste(collapse = "\n")`.
- Sinon → `source` est traité comme du texte direct (utile pour tests + ingestion programmatique).

Retour normalisé : `data.frame(page_number int, text chr)`. Pour un .txt / texte direct, `page_number = NA`.

#### Phase 2 — `.chunk_text(text_df, size, overlap)`

Découpage **sliding-window par tokens estimés** (`nchar / 4` ~ tokens Mistral) :

```
pour chaque page p:
  pour chaque chunk c de p (sliding window):
    token_count = .estimate_tokens(c)
    text_hash   = digest::digest(c, algo = "sha256")
    chunk <- list(text = c, page_number = p, token_count, text_hash)
```

Recouvrement = 50 tokens par défaut → assure continuité sémantique entre chunks. Empêche un cas où une phrase clé est coupée pile à la frontière. Conséquence : un texte de N tokens produit ⌈N / (size - overlap)⌉ chunks, pas N/size.

Retour : `list(chunks)`, chunk = `list(text, page_number, token_count, text_hash)`.

#### Phase 3 — `.embed_batch(texts, provider, api_key, batch_size)`

Mistral embeddings API :

```http
POST https://api.mistral.ai/v1/embeddings
Authorization: Bearer $MISTRAL_API_KEY
Content-Type: application/json

{
  "model": "mistral-embed",
  "input": ["text 1", "text 2", ...]   # batch max 32
}
```

Retour API : `{ "data": [ { "embedding": [...1024 floats...] }, ... ] }`.

Stratégie :
- Boucle sur `texts` par groupes de `batch_size = 32`
- Retry exponentiel 3 fois sur 429 (rate limit) / 5xx, avec `Retry-After` honoré si présent
- Sur échec persistant : `cli::cli_abort()` — l'ingestion est rollback par la transaction parente
- Progress bar `cli::cli_progress_bar()` sur le nombre total de batches

Retour : matrice `n × 1024` de doubles.

#### Phase 4 — Persistance

```r
.insert_knowledge_document(con, metadata) -> doc_id
  # INSERT INTO knowledge_document (...) VALUES (...) RETURNING id

.insert_knowledge_chunks(con, doc_id, chunks, embeds)
  # Build a data.frame with columns: document_id, chunk_index, page_number,
  # text, text_hash, token_count, embedding (as pgvector literal '[...]')
  # → DBI::dbAppendTable, or staging table + INSERT … SELECT for atomicity
```

**Encodage embeddings pour DBI** : pgvector accepte les littéraux `'[0.1,0.2,...]'`. RPostgres ne typage pas automatiquement → on passe chaque embedding comme `character(1)` formaté et la colonne cible est `vector(1024)` qui parse côté PG. Helper :

```r
.pg_vector_literal <- function(v) {
  sprintf("[%s]", paste(formatC(v, format = "g", digits = 8), collapse = ","))
}
```

### 3.3 Performance attendue (ingestion)

| Étape | 1 document (20 p., 50 chunks) | 30 documents (corpus v1) |
|-------|-------------------------------|--------------------------|
| Lecture PDF | < 1 s | < 5 s |
| Chunking | < 100 ms | < 3 s |
| Embeddings Mistral (batch 32) | ~3 s (2 appels API) | ~60 s (~50 appels API) |
| INSERT DB | < 500 ms | ~10 s |
| **Total** | **~5 s** | **~90 s** |

Coût Mistral : 0.10 €/M tokens × ~300 k tokens corpus complet ≈ **0.03 €**.

---

## 4. Pipeline de recherche — séquence détaillée

### 4.1 Fonction `retrieve_knowledge()`

```r
retrieve_knowledge <- function(
    con,
    query,
    top_k          = 8L,
    family_codes   = NULL,
    profile_codes  = NULL,
    min_similarity = 0.7,
    lang           = NULL,
    embed_provider = "mistral"
) {
  .assert_pgvector(con)
  if (!is.character(query) || length(query) != 1L || !nzchar(query))
    stop("`query` must be a single non-empty character.", call. = FALSE)

  # 1. Embed the query
  q_emb <- embed_query(query, provider = embed_provider)

  # 2. SQL: ANN top-k with optional filters
  sql <- "
    SELECT c.id          AS chunk_id,
           c.document_id,
           c.chunk_index,
           c.page_number,
           c.text,
           d.title,
           d.author,
           d.pub_date,
           d.source_url,
           d.lang,
           1 - (c.embedding <=> $1::vector) AS similarity
      FROM knowledge_chunk    c
      JOIN knowledge_document d ON d.id = c.document_id
     WHERE ($2::text[] IS NULL OR d.family_codes  && $2::text[])
       AND ($3::text[] IS NULL OR d.profile_codes && $3::text[])
       AND ($4::text   IS NULL OR d.lang = $4)
     ORDER BY c.embedding <=> $1::vector
     LIMIT $5"

  params <- list(
    .pg_vector_literal(q_emb),
    if (is.null(family_codes))  NA_character_ else .pg_text_array(con, family_codes),
    if (is.null(profile_codes)) NA_character_ else .pg_text_array(con, profile_codes),
    lang %||% NA_character_,
    as.integer(top_k)
  )

  rs <- DBI::dbGetQuery(con, sql, params = params)

  # 3. Post-filter by min_similarity (the ORDER BY couldn't filter
  # because the operator <=> returns a *distance*, not similarity)
  rs <- rs[rs$similarity >= min_similarity, , drop = FALSE]
  if (!nrow(rs)) return(.empty_retrieved_chunks())

  # 4. Type coercion + sort by similarity desc
  rs$pub_date <- as.Date(rs$pub_date)
  rs[order(-rs$similarity), , drop = FALSE]
}
```

### 4.2 Index ivfflat — réglage

Au moment de la migration, l'index est créé avec `lists = 100`. Pour optimiser la recherche, PG accepte un paramètre de query : `SET LOCAL ivfflat.probes = 10;` qui balaye 10 listes au lieu de la moyenne. Default = 1 (rapide, recall faible). Pour notre cas (30 docs × ~50 chunks = 1500 chunks), default suffit. Documentation : `?retrieve_knowledge` mentionnera l'option pour les power users.

### 4.3 Performance attendue (recherche)

| Étape | Temps |
|-------|-------|
| `embed_query` API Mistral (1024 dim natif) | ~150 ms (cold), ~80 ms (warm) |
| `.pad_to_target_dim` (1024 → 3072, query unique) | < 0.1 ms |
| SQL ANN sur `vector(3072)` | ~40 ms (3× plus lent que sur `vector(1024)` pour le même corpus, mais reste dans le budget) |
| Coercion + sort R | < 5 ms |
| **Total** | **~200 ms cold, ~125 ms warm** |

Cible §6 A4 : `< 200 ms`. Atteint à la limite côté warm — confortable. Côté cold (1er appel après démarrage R / cache HTTP froid) on est exactement à 200 ms. Si la dégradation est sensible en pratique, on peut :
- réduire `lists` de l'index ivfflat (compromis recall ↓ / latency ↓)
- envisager HNSW (extension 009.x) qui scale mieux en dim élevée
- réintroduire un cache LRU des query embeddings (mentioned §4.4)

### 4.4 Cache embeddings de requêtes

**Hors scope v1** mais à garder en tête : un cache `(query_hash → embedding)` LRU local pourrait éliminer l'appel API pour les queries répétées (le profil + indicateurs sont déterministes). Extension simple à ajouter.

---

## 5. Provider d'embeddings — abstraction

### 5.1 Constantes de configuration

```r
# Native dimensions by provider/model (source of truth)
.RAG_PROVIDER_DIMS <- list(
  mistral = 1024L,    # mistral-embed
  voyage  = 1024L,    # voyage-3-large (Matryoshka up to 2048 but we use 1024)
  openai  = 3072L     # text-embedding-3-large
)

# Target storage dimension — widest of the above so all providers
# fit without schema migration. Padded with zeros for smaller embeds.
.RAG_TARGET_DIM <- 3072L

# Model-version strings stored in knowledge_document.metadata.embed_model
.RAG_PROVIDER_MODELS <- list(
  mistral = "mistral-embed-v1",
  voyage  = "voyage-3-large",
  openai  = "text-embedding-3-large"
)
```

### 5.2 Interface interne unifiée

```r
.embed_batch <- function(texts, provider, api_key, batch_size = 32L) {
  raw <- switch(provider,
    mistral = .embed_batch_mistral(texts, api_key, batch_size),
    openai  = .embed_batch_openai(texts, api_key, batch_size),
    voyage  = .embed_batch_voyage(texts, api_key, batch_size)
  )
  # raw : matrix n × dim_native(provider)
  .pad_to_target_dim(raw, target = .RAG_TARGET_DIM)
}

# Zero-pad a matrix of embeddings to the target dimension. Padding
# preserves cosine similarity within the same provider (the zeros
# contribute 0 to both sides of the dot product). Mixing across
# providers is still mathematically meaningless — that's enforced
# at the metadata.embed_model level, not by the padding scheme.
.pad_to_target_dim <- function(m, target = .RAG_TARGET_DIM) {
  d <- ncol(m)
  if (d == target) return(m)
  if (d > target) {
    cli::cli_abort(c(
      "Embedding dimension {d} > target {target}.",
      i = "Reduce via the provider's `dimensions` API parameter, or widen the column."
    ))
  }
  # Right-pad with zeros
  pad <- matrix(0, nrow = nrow(m), ncol = target - d)
  cbind(m, pad)
}
```

### 5.3 Implémentations par provider

#### Mistral (default)

```r
.embed_batch_mistral <- function(texts, api_key = NULL, batch_size = 32L) {
  if (is.null(api_key)) api_key <- Sys.getenv("MISTRAL_API_KEY", "")
  if (!nzchar(api_key)) {
    cli::cli_abort(c(
      "Mistral API key missing.",
      i = "Set {.envvar MISTRAL_API_KEY} or pass {.arg api_key}.",
      i = "Get one at {.url https://console.mistral.ai}"
    ))
  }
  # POST https://api.mistral.ai/v1/embeddings
  # body: { "model": "mistral-embed", "input": [text1, text2, ...] }
  # Loop batches (≤ 32), accumulate matrix n × 1024
  ...
}
```

#### Voyage (Anthropic ecosystem)

```r
.embed_batch_voyage <- function(texts, api_key = NULL, batch_size = 128L) {
  if (is.null(api_key)) api_key <- Sys.getenv("VOYAGE_API_KEY", "")
  if (!nzchar(api_key)) cli::cli_abort(...)  # idem
  # POST https://api.voyageai.com/v1/embeddings
  # body: { "model": "voyage-3-large", "input": [...], "input_type": "document" }
  # `input_type` ∈ {"document","query"} — Voyage applique un instruction
  # prompt different selon. Documenté côté `embed_query` aussi.
  # Batch max 128 (plus généreux que Mistral)
  ...
}
```

#### OpenAI

```r
.embed_batch_openai <- function(texts, api_key = NULL, batch_size = 100L) {
  if (is.null(api_key)) api_key <- Sys.getenv("OPENAI_API_KEY", "")
  if (!nzchar(api_key)) cli::cli_abort(...)
  # POST https://api.openai.com/v1/embeddings
  # body: { "model": "text-embedding-3-large", "input": [...] }
  # Pas de paramètre `dimensions` — on garde le natif 3072 puisque
  # c'est aussi notre target. Pour text-embedding-3-small (1536),
  # zero-pad côté .pad_to_target_dim.
  ...
}
```

### 5.4 Provider model tracking

Au moment de `ingest_knowledge_document`, l'orchestrateur écrit dans `metadata.embed_model` la version du modèle utilisé (`mistral-embed-v1`, `voyage-3-large`, `text-embedding-3-large`). Côté `retrieve_knowledge`, l'orchestrateur :

1. Liste les `embed_model` distincts présents dans le corpus filtré
2. Si UN seul → embed la query avec le même provider → cosine valide → retourne le top-k
3. Si PLUSIEURS (corpus mixte) → warning et embed avec le provider passé en argument → résultats potentiellement mixés sémantiquement → l'utilisateur est informé

**Comportement v1 :** mixage toléré avec warning. **Évolution v2 (009 patch)** : partition automatique par provider (recherche dans chaque sous-espace, fusion des scores).

### 5.5 Re-embedding du corpus pour bascule de provider

Procédure documentée dans `?ingest_knowledge_document` :

```r
# 1. Backup metadata (URL, license, tags, ...) — they're independent of the model
docs <- list_knowledge_documents(con)
# 2. Wipe chunks (keeps docs row, just drops embeddings)
DBI::dbExecute(con, "DELETE FROM knowledge_chunk")
# 3. Re-ingest each PDF with the new provider
for (path in docs$source_url) {
  ingest_knowledge_document(con, path, metadata = ..., embed_provider = "openai")
}
```

Pas de helper exporté pour cette procédure en v1 — geste explicite, rarement déclenché.

### 5.6 Pas de fallback local en v1

Le local fallback via `sentence-transformers` Python (reticulate) est listé en extension **009.6** mais hors scope v1. Raison : ajouter une dépendance Python coûte cher en setup (cf. retex FORDEAD), et la résilience couvre déjà beaucoup via le retry exponentiel + les 3 providers commerciaux.

---

## 6. Découpage en chantiers livrables

| # | Chantier | Livrables | Effort estimé |
|---|----------|-----------|---------------|
| **T1** | Migration `0003_rag.sql` (PG + DuckDB stub) | `inst/db/migrations/{pg,duckdb}/0003_rag.sql` + tests `with_clean_db` | ~1 h |
| **T2** | Helpers : `.assert_pgvector`, `.pg_vector_literal`, `.validate_ingest_metadata`, `.empty_retrieved_chunks` | `R/rag-helpers.R` + tests offline | ~1.5 h |
| **T3** | `.chunk_text()` + `.estimate_tokens()` + `.read_source()` | `R/rag-chunking.R` + tests offline (5-7 tests) | ~2 h |
| **T4** | `.embed_batch_mistral()` + retry/backoff + `embed_query()` exporté | `R/rag-embeddings.R` + tests avec `local_mocked_bindings(req_perform)` | ~2 h |
| **T5** | `.embed_batch_openai()` + `.embed_batch_voyage()` + `.pad_to_target_dim()` | `R/rag-embeddings.R` étendu + tests | ~2 h |
| **T6** | `ingest_knowledge_document()` orchestrateur + ses INSERT helpers | `R/rag-ingest.R` + tests intégration `with_clean_db` (5 tests) | ~2.5 h |
| **T7** | `retrieve_knowledge()` + SQL ANN + post-filter | `R/rag-retrieve.R` + tests intégration (6 tests) | ~2.5 h |
| **T8** | `list_knowledge_documents()` + `delete_knowledge_document()` + `format_citations()` | Idem + 4 tests | ~1.5 h |
| **T9** | Corpus initial v1 : CSV manifest + script `data-raw/build_knowledge_corpus.R` | `inst/extdata/knowledge_corpus_v1.csv` + script | ~3 h (curation des docs incluse) |
| **T10** | Doc roxygen + NAMESPACE + cross-links | Doc + NAMESPACE | ~1 h |
| **T11** | Bench + ajustements perf | `data-raw/bench-rag.R` | ~1 h |
| **T12** | Release v0.23.0 | DESCRIPTION + NEWS + PLAN + tag + release | ~30 min |

**Total estimé** : ~20 h.

**Séquence** : T1 → T2 → (T3, T4 parallèles) → T5 → T6 → T7 → T8 → T9 → T10 → T11 → T12.

T9 (curation corpus) est le seul chantier avec une part d'effort humain non-codable — il faut juste télécharger / récupérer les ~30 PDFs et les tagger correctement dans le CSV. **Peut être livré progressivement post-v0.23.0** si pression temporelle : la release v0.23.0 livre l'API + un corpus seed minimal (5 docs au moins, FORDEAD inclus), les 25 autres docs peuvent venir en patch v0.23.1.

---

## 7. Performance attendue (résumé global)

| Opération | Cible | Notes |
|-----------|-------|-------|
| Migration `0003_rag.sql` | < 1 s | extension + 2 tables + 5 index |
| Ingest 1 PDF (20 pages, 50 chunks) | ~5 s | dominated by 2 API calls Mistral |
| Ingest corpus initial (30 docs) | ~90 s | one-shot, mostly API time |
| `embed_query` | ~100 ms warm | 1 appel API ≤ 1024 chars query |
| `retrieve_knowledge` top-8 | ~180 ms cold, ~100 ms warm | API + SQL |
| `list_knowledge_documents` | < 50 ms | scan séquentiel < 30 docs |
| `delete_knowledge_document` (cascade 50 chunks) | < 1 s | CASCADE FK + REINDEX optionnel |
| `format_citations` (Markdown, 8 chunks) | < 5 ms | string format pur |

---

## 8. Dépendances et risques

### 8.1 Nouvelles dépendances

| Package | Compartiment | Justification |
|---------|--------------|---------------|
| `digest` | **Imports** | sha256 chunks (utilisé en hot path d'ingestion, ne peut pas être lazy) |
| `pdftools` | **Suggests** | Ingestion offline seulement, runtime perspective n'en a pas besoin |

### 8.2 Risques (extension de spec §9)

| Risque | Détection | Mitigation |
|--------|-----------|------------|
| Migration `0003_rag.sql` échoue parce que pgvector manquant sur une DB legacy | `CREATE EXTENSION` ne plante pas idempotent — mais `vector(1024)` plante | `.assert_pgvector(con)` haut de chaque fonction RAG, message clair `"Run: CREATE EXTENSION vector;"` |
| `pdftools` indisponible (système sans poppler) | Échec à `library(pdftools)` au runtime | Détection au `requireNamespace`, fallback message + suggestion `.txt` |
| Encodage UTF-8 perdu sur PDF avec accents | Texte mal lu, embeddings dégradés | `pdf_text(pdf, encoding = "UTF-8")` explicite, test sur PDF FR avec accents |
| Recouvrement de chunks crée des doublons sémantiques en retrieval | Top-k contient les mêmes infos 2× | Acceptable v1 ; mitigation future : MMR (Maximal Marginal Relevance) — extension 009.2 |
| Embedding dérive si Mistral met à jour `mistral-embed` | Embeddings nouveaux non-compatibles avec ceux en DB | Stocker `metadata.embed_model_version` côté `knowledge_document`, message si mismatch détecté à `retrieve_knowledge`. À spec'er en 009.9 si problème. |
| Recall faible parce que ivfflat probes trop bas | Utilisateur rapporte "je sais que c'est dans le corpus mais pas trouvé" | Documenter `SET ivfflat.probes = N` ; envisager HNSW en 009 patch |
| Race condition INSERT concurrent (deux ingestions parallèles) | INSERT échoue sur UNIQUE (document_id, chunk_index) | Pas un cas réel v1 (ingestion = batch offline, pas concurrent). Documenté. |
| Corpus contient un PDF scanné (OCR raté) | Texte vide ou bruit | Validation en T9 : `nchar(text) > 1000` minimum par doc, sinon warning à l'utilisateur |

---

## 9. Plan de tests

### 9.1 Tests offline (sans réseau, sans DB)

| Fichier | Tests | Couvre |
|---------|-------|--------|
| `test-rag-chunking.R` | 6 | `.chunk_text` (taille, overlap, sliding window), `.estimate_tokens`, `.read_source` PDF + txt + raw |
| `test-rag-helpers.R` | 4 | `.pg_vector_literal`, `.validate_ingest_metadata`, `.empty_retrieved_chunks`, `.assert_pgvector` (mock) |
| `test-rag-embeddings.R` | 8 | `.embed_batch_mistral` mocked (happy, 429 retry, 5xx fail, empty input, batch boundary), `.embed_batch_openai` mocked, `.embed_batch_voyage` mocked (incl. `input_type` param), `.pad_to_target_dim` (1024→3072, 3072→3072 noop, 4096→3072 error) |
| `test-rag-format-citations.R` | 3 | `format_citations` Markdown + HTML + empty input |

Sous-total offline : **21 tests** (18 + 3 padding/Voyage).

### 9.2 Tests intégration (`with_clean_db`)

| Fichier | Tests | Couvre |
|---------|-------|--------|
| `test-rag-migration.R` | 2 | `db_migrate` ajoute les 2 tables + index ivfflat (DESCRIBE) ; idempotent re-run |
| `test-rag-ingest.R` | 4 | Ingest texte raw OK ; ingest sur con sans pgvector → erreur claire ; rollback si embedding fail (mocked) ; uniq (doc_id, chunk_idx) |
| `test-rag-retrieve.R` | 6 | Empty corpus → empty df ; retrieve match ; filtre family_codes ; filtre lang ; min_similarity filter ; top_k bound |
| `test-rag-delete-list.R` | 4 | `list` retourne docs ingérés ; `delete` cascade chunks ; idempotent re-delete ; `list` filtre family |

Sous-total intégration : **16 tests**.

**Total nouveaux tests v0.23.0** : **37 tests** (21 offline + 16 intégration).

### 9.3 Fixtures

```r
# helper-rag.R  — fixture builders
make_fake_embedding <- function(n = 1024, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  v <- rnorm(n); v / sqrt(sum(v^2))  # unit-normalised
}

make_fake_corpus <- function(con, n_docs = 3, chunks_per_doc = 5) {
  for (d in seq_len(n_docs)) {
    title <- sprintf("Test doc %d", d)
    # Direct INSERT bypassing the embed API
    doc_id <- DBI::dbGetQuery(con, "...", params = list(title, ...))$id
    for (c in seq_len(chunks_per_doc)) {
      emb <- make_fake_embedding(seed = d * 100L + c)
      DBI::dbExecute(con, "INSERT INTO knowledge_chunk (...) VALUES (...)",
                     params = list(doc_id, c, ..., .pg_vector_literal(emb)))
    }
  }
}

mock_mistral_embed <- function(texts) {
  # Deterministic stub : same text → same embedding (hash-based)
  vapply(texts, function(t) {
    h <- digest::digest(t, algo = "sha256", serialize = FALSE)
    set.seed(strtoi(substr(h, 1, 8), 16L))
    make_fake_embedding()
  }, numeric(1024)) |> t()
}
```

Approche : `local_mocked_bindings(.embed_batch_mistral = mock_mistral_embed, .package = "nemeton")` dans chaque test qui appelle `ingest_knowledge_document`. Aucun call API réel pendant la suite.

---

## 10. Critères d'acceptation v0.23.0

| # | Critère | Vérification |
|---|---------|--------------|
| 1 | DESCRIPTION = `Version: 0.23.0` | grep |
| 2 | NEWS.md a section `# nemeton 0.23.0` | grep |
| 3 | PLAN.md (racine) coche E7 + journal daté | grep |
| 4 | NAMESPACE exporte 6 nouvelles fonctions | grep |
| 5 | Migration `0003_rag.sql` présente (PG + DuckDB stub) | ls |
| 6 | `devtools::check()` 0 ERROR / 0 WARNING / 0 NOTE nouveau | run |
| 7 | `devtools::test()` ≥ 6030 + 37 = 6067 PASS (baseline post-v0.22.0 + nouveaux) | run |
| 8 | Tests d'intégration RAG rejouent contre `NEMETON_DB_URL_TEST` | run |
| 9 | `Imports: digest` ajouté à DESCRIPTION | grep |
| 10 | `Suggests: pdftools` ajouté à DESCRIPTION | grep |
| 11 | `inst/extdata/knowledge_corpus_v1.csv` présent, ≥ 5 docs | wc |
| 12 | Tag annoté `v0.23.0` poussé + GitHub release | gh release view |

---

## 11. Hors-scope final / dette technique

- **Pas de `chunk_strategy`** paramétrable (sentence-split vs sliding window). Sliding window 512/50 figé v1.
- **Pas de re-embedding automatique** quand `mistral-embed` est mis à jour. Procédure manuelle documentée : `delete_knowledge_document(con, all = TRUE)` puis re-ingest.
- **Pas de soft-delete** sur `knowledge_document` (DELETE physique, cascade). Suffisant v1.
- **Pas de version de chunking** stockée. Si on change `chunk_size` plus tard, le user qui re-ingère un doc obtient un découpage différent — comportement acceptable, le delete/re-ingest est explicite.
- **Pas de RBAC** sur la lecture (toute session a accès à tous les chunks). À traiter si multi-tenant — extension 009.7.

---

## 12. Validation

Prêt à passer à `tasks.md` une fois validé :

- [ ] Stack technique (§1) approuvé
- [ ] Schéma DB (§2) approuvé
- [ ] Pipelines d'ingestion (§3) et de recherche (§4) approuvés
- [ ] Provider strategy (§5) approuvée (Mistral + OpenAI, pas de local v1)
- [ ] Découpage T1-T12 (§6) approuvé
- [ ] Performance budget (§7) approuvé
- [ ] Plan de tests (§9) approuvé — 34 tests cible
- [ ] Critères d'acceptation (§10) approuvés

**Validateur** : Pascal Obstétar
**Date validation** : _à remplir_
