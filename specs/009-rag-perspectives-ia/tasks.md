# Tâches d'implémentation : RAG pour perspectives IA (spec 009)

**Version** : 0.1.0
**Date**    : 2026-05-15
**Spec**    : `spec.md` v0.1.0 · **Plan** : `plan.md` v0.1.0
**Cible**   : `nemeton` v0.23.0
**Total**   : 56 tâches (toutes cœur — chantier app `nemetonshiny` suivi séparément, cf. §Hors scope)

Conventions :
- `[P]` = parallélisable avec les autres `[P]` du même chantier (mêmes pré-requis)
- IDs : `T{chantier}.{n}` (ex. T3.4 = chantier T3, tâche 4)
- Réfs fichier : `path:line` quand connue, sinon `path`
- Statut : `[ ]` à faire, `[x]` fait, `[~]` en cours
- Effort estimé : `(S)` < 30 min, `(M)` 30 min – 1 h, `(L)` 1 – 2 h, `(XL)` > 2 h

---

## Vue d'ensemble

```
T1 (migration)
   └─► T2 (helpers privés)
          ├─► T3 (chunking)   ─┐
          └─► T4 (Mistral)    ─┼─► T5 (OpenAI + Voyage + padding)
                               │       └─► T6 (ingest orchestrator)
                               │               └─► T7 (retrieve)
                               │                       └─► T8 (list / delete / citations)
                               │                               ├─► T9 (corpus v1)
                               │                               └─► T10 (doc + NAMESPACE)
                               │                                       └─► T11 (bench)
                               │                                               └─► T12 (release)
```

T3 et T4 sont parallélisables (deux fichiers distincts, pas de dépendance mutuelle). T5 dépend de T4 (étend `R/rag-embeddings.R`). Tous les autres en séquence linéaire.

T9 (curation corpus) a une part d'effort humain non-codable (téléchargement + tagging des ~5-30 PDFs). Peut être commencé en parallèle de T6/T7 si l'utilisateur souhaite avancer en double-piste.

---

## Chantier T1 — Migration `0003_rag.sql`

Branche : `feat/009-rag-perspectives-ia` (toute la spec sur la même branche)

### 1.1 Migration PG

- [ ] **T1.1 (S)** Lire `R/db.R::db_migrate` pour confirmer la convention de lookup `inst/db/migrations/{backend}/` par ordre alphanumérique (déjà acquis en v0.21.0). Pas de modification du code R nécessaire.
- [ ] **T1.2 (M)** Créer `inst/db/migrations/pg/0003_rag.sql` selon plan.md §2.1 :
  - `CREATE EXTENSION IF NOT EXISTS vector;`
  - `CREATE TABLE IF NOT EXISTS knowledge_document (...)` — 12 colonnes, `id SERIAL PRIMARY KEY`
  - `CREATE TABLE IF NOT EXISTS knowledge_chunk (...)` — `embedding vector(3072)`, `UNIQUE (document_id, chunk_index)`, `ON DELETE CASCADE`
  - 5 index : `lang_idx`, `doc_type_idx`, `family_gin` (GIN), `profile_gin` (GIN), `knowledge_chunk_doc_idx` (B-tree)
  - 1 index ANN : `knowledge_chunk_embedding_idx USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)`
  - Tous `IF NOT EXISTS` → idempotent
- [ ] **T1.3 (S)** Header de commentaires en tête du fichier : description, version cible, ref spec 009, date.

### 1.2 Stub DuckDB

- [ ] **T1.4 (S)** Créer `inst/db/migrations/duckdb/0003_rag.sql` avec un seul commentaire `-- RAG features require PostgreSQL + pgvector. DuckDB backend has no RAG support; this migration is a no-op.`

### 1.3 Tests d'intégration

- [ ] **T1.5 (M)** Créer `tests/testthat/test-rag-migration.R` avec 2 tests :
  - **Test 1** : `with_clean_db` → `db_migrate()` → vérifier présence de `knowledge_document` + `knowledge_chunk` via `DBI::dbListTables` ; vérifier l'index ivfflat via `SELECT indexname FROM pg_indexes WHERE tablename = 'knowledge_chunk'`
  - **Test 2** : re-jouer `db_migrate()` doit être idempotent (pas d'erreur, pas de doublon de tables)
- [ ] **T1.6 (S)** Commit `feat(db): add 0003_rag.sql migration (knowledge_document + knowledge_chunk + ivfflat)`. Pas de bump version (chantier non terminé).

**Critères de sortie T1** :
- Migration présente côté PG et stub côté DuckDB
- 2 tests intégration verts (rejouent contre `NEMETON_DB_URL_TEST`)
- 1 commit isolé sur la branche

---

## Chantier T2 — Helpers privés partagés

### 2.1 Création du module

- [ ] **T2.1 (S)** Créer `R/rag-helpers.R` avec header roxygen général : « Internal helpers shared across the RAG module (assertions, encoding, validation). Not exported. »

### 2.2 Implémentations

- [ ] **T2.2 (M)** `.assert_pgvector(con)` :
  - Vérifie via `SELECT 1 FROM pg_extension WHERE extname = 'vector'` (PG only)
  - Si `con` est `duckdb_connection` → `cli::cli_abort("RAG features require PostgreSQL + pgvector. Switch backend or skip RAG.")`
  - Si pgvector absent → message clair `Run: CREATE EXTENSION vector;`
- [ ] **T2.3 (S)** `.pg_vector_literal(v)` :
  - Input `numeric(n)`, retour `character(1)` formaté `"[v1,v2,...]"`
  - `formatC(v, format = "g", digits = 8)` pour preserver la précision sans gonfler la taille
  - Garde-fou : `stopifnot(is.numeric(v), length(v) > 0)`
- [ ] **T2.4 (M)** `.validate_ingest_metadata(metadata)` :
  - Vérifie présence des champs requis : `title`, `lang`, `doc_type`, `license`
  - `doc_type ∈ {paper, report, regulation, manual, note, web}` via `rlang::arg_match`
  - `lang` ∈ ISO 639-1 court (2 char) → regex `^[a-z]{2}$`
  - `family_codes` (si présent) : tous valides (cf. `R/family-system.R::INDICATOR_FAMILIES`)
  - `pub_date` coercible via `as.Date()` si fourni
  - Sortie : `invisible(TRUE)` ou `cli::cli_abort()` avec liste des champs invalides
- [ ] **T2.5 (S)** `.empty_retrieved_chunks()` :
  - Retourne un `data.frame` à 0 lignes avec exactement les 11 colonnes typées de §5.3 spec : `chunk_id (int), document_id (int), title (chr), author (chr), pub_date (Date), source_url (chr), lang (chr), chunk_index (int), page_number (int), text (chr), similarity (num)`
  - Réutilisable comme shape canonique pour les retours vides

### 2.3 Tests offline

- [ ] **T2.6 (M)** Créer `tests/testthat/test-rag-helpers.R` avec 4 tests :
  - **Test 1** : `.pg_vector_literal(c(0.1, 0.2, 0.3))` → `"[0.1,0.2,0.3]"`
  - **Test 2** : `.validate_ingest_metadata` rejette `doc_type = "xxx"` avec message explicite
  - **Test 3** : `.empty_retrieved_chunks()` a `nrow == 0` ET les bons types via `vapply(..., class, ...)`
  - **Test 4** : `.assert_pgvector` sur `duckdb_connection` mockée → erreur claire « PostgreSQL + pgvector required »
- [ ] **T2.7 (S)** Commit `feat(rag): add private helpers for RAG module`. Pas de bump.

**Critères de sortie T2** :
- 4 helpers privés en place, non exportés
- 4 tests offline verts
- 1 commit isolé

---

## Chantier T3 — Chunking [P avec T4]

### 3.1 Module chunking

- [ ] **T3.1 (S)** Créer `R/rag-chunking.R` avec header roxygen : « Source reading, token estimation, and sliding-window chunking for RAG ingestion. Not exported (internal pipeline only). »

### 3.2 Implémentations

- [ ] **T3.2 (M)** `.read_source(source)` selon plan.md §3.2 Phase 1 :
  - Routing par extension : `.pdf` → `pdftools::pdf_text(source, encoding = "UTF-8")`, `.txt|.md` → `readLines(source) |> paste(collapse = "\n")`, sinon → texte direct
  - Sortie normalisée : `data.frame(page_number int, text chr)` (NA pour non-PDF)
  - Vérifier `pdftools` disponible via `requireNamespace("pdftools", quietly = TRUE)` pour les PDF, message d'erreur clair sinon avec suggestion de fallback `.txt`
  - Validation : `nchar(text_total) > 100` minimum, sinon warning « source seems empty or OCR-only — check the PDF »
- [ ] **T3.3 (S)** `.estimate_tokens(text)` :
  - Heuristique simple `nchar(text) %/% 4L` (acceptable pour Mistral/OpenAI en FR/EN — cf. plan.md §3.2)
  - Retour `integer(1)`
- [ ] **T3.4 (L)** `.chunk_text(text_df, size = 512L, overlap = 50L)` :
  - Itère sur `text_df` page par page (préserve `page_number`)
  - Découpage *sliding window par tokens estimés* : pour chaque page, génère des chunks de ~`size` tokens avec recouvrement `overlap`
  - Calcule `text_hash = digest::digest(text, algo = "sha256")` par chunk pour dédup intra-doc
  - Sortie : `list` de `list(text chr, page_number int|NA, token_count int, text_hash chr)`
  - Edge case : page < `size` tokens → 1 seul chunk
  - Edge case : `size <= overlap` → erreur typée
  - Edge case : texte vide → liste vide (pas d'erreur, l'orchestrateur décide)

### 3.3 Tests offline

- [ ] **T3.5 (M)** Créer `tests/testthat/test-rag-chunking.R` avec 6 tests :
  - **Test 1** : `.estimate_tokens("Bonjour le monde")` ~ 4 tokens (`16 %/% 4`)
  - **Test 2** : `.chunk_text` sur un texte court (< `size`) → 1 chunk, `nchar(text) > 0`, `text_hash` non-vide
  - **Test 3** : `.chunk_text` sur un texte long → `length(chunks) > 1`, recouvrement vérifié (les derniers tokens du chunk N apparaissent au début du chunk N+1)
  - **Test 4** : `.chunk_text(..., size = 10, overlap = 10)` → erreur `size <= overlap`
  - **Test 5** : `.read_source` sur fichier `.txt` temporaire → data.frame 1 ligne, `page_number = NA`
  - **Test 6** : `.read_source` sur PDF fixture (créer un PDF synthétique 2 pages via `pdftools` reverse ou fixture pré-générée) → data.frame 2 lignes, `page_number = c(1, 2)`. Skip avec `skip_if_not_installed("pdftools")`.

- [ ] **T3.6 (S)** Commit `feat(rag): add chunking and source reading helpers`.

**Critères de sortie T3** :
- `.read_source`, `.estimate_tokens`, `.chunk_text` fonctionnels
- 6 tests offline verts (1 skippé si poppler absent)
- 1 commit isolé

---

## Chantier T4 — Mistral embeddings + `embed_query()` [P avec T3]

### 4.1 Module embeddings

- [ ] **T4.1 (S)** Créer `R/rag-embeddings.R` avec header roxygen : « Embedding providers abstraction layer. Mistral (default), OpenAI, Voyage (Anthropic ecosystem). Plus zero-padding to RAG_TARGET_DIM for cross-provider schema compatibility. »
- [ ] **T4.2 (S)** Définir les constantes privées plan.md §5.1 :
  - `.RAG_PROVIDER_DIMS <- list(mistral = 1024L, voyage = 1024L, openai = 3072L)`
  - `.RAG_TARGET_DIM <- 3072L`
  - `.RAG_PROVIDER_MODELS <- list(mistral = "mistral-embed-v1", voyage = "voyage-3-large", openai = "text-embedding-3-large")`

### 4.2 Implémentation Mistral

- [ ] **T4.3 (L)** `.embed_batch_mistral(texts, api_key = NULL, batch_size = 32L)` selon plan.md §5.3 :
  - Récupère `api_key` via `Sys.getenv("MISTRAL_API_KEY", "")` si NULL
  - Erreur typée + URL `https://console.mistral.ai` si manquante
  - Boucle batch (≤ 32) sur `httr2::request("https://api.mistral.ai/v1/embeddings")` avec `req_auth_bearer_token`, `req_body_json(list(model = "mistral-embed", input = batch))`
  - Parse `resp$data[[i]]$embedding` → matrice `n × 1024`
  - Progress bar `cli::cli_progress_bar()` si `length(texts) > batch_size`
- [ ] **T4.4 (M)** Retry exponentiel sur 429 / 5xx :
  - `httr2::req_retry(max_tries = 3L, backoff = ~ min(60, 2 ^ .x))` natif `httr2`
  - Honorer header `Retry-After` si présent
  - Sur échec persistant après 3 tentatives → `cli::cli_abort` (transaction parente rollback)
- [ ] **T4.5 (M)** `embed_query(text, provider = "mistral", api_key = NULL, lang = NULL)` exporté :
  - Validation `text` chr(1) non-vide
  - Délègue à `.embed_batch_*(text, provider, ...)` puis prend la première (et unique) ligne de la matrice
  - Applique `.pad_to_target_dim` (cf. T5) → retourne `numeric(.RAG_TARGET_DIM)` (`3072`)
  - Roxygen complet : `@param`, `@return`, `@examples \dontrun{}`, `@seealso retrieve_knowledge`. `@export`.

### 4.3 Tests offline (mockés)

- [ ] **T4.6 (M)** Créer `tests/testthat/test-rag-embeddings.R` avec 5 tests Mistral :
  - **Test 1** : `.embed_batch_mistral` happy path (batch unique) — `local_mocked_bindings(req_perform = mock_resp_ok, .package = "httr2")` retournant un body JSON déterministe
  - **Test 2** : batch boundary — 33 textes → 2 appels API, vérifier matrix `33 × 1024`
  - **Test 3** : 429 retry — mock qui retourne 429 puis 200 → `expect_no_error`, observability via `expect_message`
  - **Test 4** : 5xx fail définitif après 3 tentatives → `expect_error`
  - **Test 5** : api_key manquante → `expect_error("MISTRAL_API_KEY")`
- [ ] **T4.7 (S)** Helper test : `mock_resp_ok(req)` qui retourne un `httr2::response()` synthétique avec un body JSON cohérent (dim 1024, vecteurs normés).
- [ ] **T4.8 (S)** Commit `feat(rag): add Mistral embedding backend with retry`.

**Critères de sortie T4** :
- `embed_query` exporté + roxygen
- `.embed_batch_mistral` fonctionnel avec retry
- 5 tests offline verts
- 1 commit isolé

---

## Chantier T5 — OpenAI + Voyage + padding (étend T4)

### 5.1 Padding

- [ ] **T5.1 (M)** `.pad_to_target_dim(m, target = .RAG_TARGET_DIM)` dans `R/rag-embeddings.R` selon plan.md §5.2 :
  - Si `ncol(m) == target` → return identique
  - Si `ncol(m) > target` → `cli::cli_abort` avec hint `dimensions` API param
  - Sinon → `cbind(m, matrix(0, nrow = nrow(m), ncol = target - ncol(m)))`
  - Garde-fou : `is.matrix(m) && is.numeric(m)` sinon erreur typée

### 5.2 OpenAI

- [ ] **T5.2 (L)** `.embed_batch_openai(texts, api_key = NULL, batch_size = 100L)` :
  - Récupère `api_key` via `Sys.getenv("OPENAI_API_KEY", "")`
  - URL `https://api.openai.com/v1/embeddings`, body `list(model = "text-embedding-3-large", input = batch)`
  - Retour matrice `n × 3072` (natif, pas de padding requis)
  - Retry identique à Mistral (`httr2::req_retry`)
  - Erreur typée + URL `https://platform.openai.com/api-keys` si manquante

### 5.3 Voyage (Anthropic ecosystem)

- [ ] **T5.3 (L)** `.embed_batch_voyage(texts, api_key = NULL, batch_size = 128L)` :
  - Récupère `api_key` via `Sys.getenv("VOYAGE_API_KEY", "")`
  - URL `https://api.voyageai.com/v1/embeddings`
  - Body `list(model = "voyage-3-large", input = batch, input_type = "document")` — `input_type` ∈ {"document","query"} (cf. plan.md §5.3, mémo dans le code)
  - Retour matrice `n × 1024`
  - Idem retry / erreur typée + URL `https://dash.voyageai.com`

### 5.4 Dispatcher `.embed_batch`

- [ ] **T5.4 (M)** `.embed_batch(texts, provider, api_key, batch_size = 32L)` :
  - `switch(provider, mistral = ..., openai = ..., voyage = ...)` selon plan.md §5.2
  - Applique `.pad_to_target_dim` à la matrice retournée
  - Validation `provider %in% names(.RAG_PROVIDER_DIMS)`
- [ ] **T5.5 (S)** Patch `embed_query` (T4.5) : passer par `.embed_batch` au lieu d'appeler directement `.embed_batch_mistral`.
  - Pour `input_type` Voyage : `embed_query` passe `input_type = "query"` (différent de l'ingest), à câbler via un argument privé.

### 5.5 Tests offline

- [ ] **T5.6 (M)** Étendre `test-rag-embeddings.R` avec 6 tests supplémentaires (total 11) :
  - **Test 6** : `.pad_to_target_dim(matrix 5×1024, 3072)` → matrice 5×3072, colonnes 1025-3072 toutes à 0
  - **Test 7** : `.pad_to_target_dim(matrix 5×3072, 3072)` → no-op (identité)
  - **Test 8** : `.pad_to_target_dim(matrix 5×4096, 3072)` → erreur typée
  - **Test 9** : `.embed_batch_openai` happy path mocké, vérifier dim native 3072 ressort intacte
  - **Test 10** : `.embed_batch_voyage` happy path mocké, vérifier `input_type = "document"` est dans le body envoyé (capturer le request via le mock)
  - **Test 11** : `.embed_batch` dispatcher route correctement vers le bon backend et padde
- [ ] **T5.7 (S)** Commit `feat(rag): add OpenAI and Voyage embedding backends with dimension padding`.

**Critères de sortie T5** :
- 3 providers fonctionnels + padding
- 11 tests embeddings cumulés
- 1 commit isolé

---

## Chantier T6 — `ingest_knowledge_document()` orchestrateur

### 6.1 Module ingest

- [ ] **T6.1 (S)** Créer `R/rag-ingest.R` avec header roxygen général.

### 6.2 Orchestrateur

- [ ] **T6.2 (XL)** `ingest_knowledge_document(con, source, metadata, chunk_size = 512L, chunk_overlap = 50L, embed_provider = c("mistral", "openai", "voyage"), api_key = NULL)` selon plan.md §3.1 :
  - `embed_provider <- match.arg(embed_provider)`
  - `.assert_pgvector(con)` + `.validate_ingest_metadata(metadata)`
  - **Phase 1** : `text_df <- .read_source(source)`
  - **Phase 2** : `chunks <- .chunk_text(text_df, size, overlap)`
  - **Phase 3** : `texts <- vapply(chunks, '[[', character(1), 'text')` → `embeds <- .embed_batch(texts, provider, api_key, batch_size = 32L)`
  - **Phase 4** : `DBI::dbWithTransaction(con, { doc_id <- .insert_knowledge_document(...); .insert_knowledge_chunks(...); doc_id })`
  - Sortie : `invisible(list(document_id = int, n_chunks = int, n_tokens_est = int, duration_sec = num))`
  - Timing optionnel via `Sys.time()` avant/après pour `duration_sec`
- [ ] **T6.3 (S)** Roxygen complet : `@param` détaillé, `@return`, `@examples \dontrun{}` montrant ingest d'un .txt court, `@seealso retrieve_knowledge`, `@export`. Note dans `@details` sur la procédure de re-embedding (cf. plan §5.5).

### 6.3 Helpers INSERT

- [ ] **T6.4 (M)** `.insert_knowledge_document(con, metadata)` :
  - INSERT INTO `knowledge_document` avec 11 colonnes + `metadata jsonb` (cf. plan §2.1)
  - Stocker `provider` choisi dans `metadata.embed_model` (utilise `.RAG_PROVIDER_MODELS`) ← **clé pour la détection multi-provider en retrieve**
  - `RETURNING id` → coerce `integer(1)`
  - Sérialiser `metadata.extra` (si présent) via `jsonlite::toJSON(auto_unbox = TRUE)`
  - Sérialiser `family_codes` / `profile_codes` via helper `.pg_text_array` (déjà présent dans `R/db.R` depuis v0.20.1, sinon vérifier l'existence et factoriser)
- [ ] **T6.5 (L)** `.insert_knowledge_chunks(con, doc_id, chunks, embeds)` :
  - Construit un `data.frame` avec colonnes `document_id, chunk_index, page_number, text, text_hash, token_count, embedding`
  - `embedding` formaté via `.pg_vector_literal` par ligne → `character(n)`
  - Bulk INSERT : soit `DBI::dbAppendTable(con, "knowledge_chunk", df)` si le pilote `RPostgres` supporte le type `text` pour la colonne `vector` (test à valider à T6.6), soit fallback `INSERT INTO ... VALUES (...)` paramétré ligne par ligne (acceptable pour 50-200 chunks)
  - Idempotent : `ON CONFLICT (document_id, chunk_index) DO NOTHING` (au cas où l'utilisateur relance sans avoir delete d'abord — graceful)
- [ ] **T6.6 (S)** Vérifier interactivement le typage `vector` côté RPostgres : si `dbAppendTable` ne formatte pas bien, garder le fallback `INSERT … VALUES` et documenter.

### 6.4 Tests intégration

- [ ] **T6.7 (M)** Créer `tests/testthat/test-rag-ingest.R` avec helper `mock_embed_batch` (cf. plan §9.3) :
  - `mock_mistral_embed <- function(texts) { vapply(texts, function(t) { h <- digest::digest(t, algo = "sha256"); set.seed(strtoi(substr(h, 1, 8), 16L)); v <- rnorm(1024); v / sqrt(sum(v^2)) }, numeric(1024)) |> t() }`
  - Déterministe : même texte → même embedding (utile pour les assertions de retrieve)
- [ ] **T6.8 (M)** **Test 1** : ingest sur con DuckDB → erreur claire « PostgreSQL + pgvector required »
- [ ] **T6.9 (M)** **Test 2** : ingest texte raw OK (`with_clean_db` + mock embed) :
  - Vérifier `n_chunks > 0`, `document_id` retourné > 0
  - Vérifier présence des rows dans `knowledge_document` ET `knowledge_chunk` (count = n_chunks)
  - Vérifier `metadata->>'embed_model' = 'mistral-embed-v1'`
- [ ] **T6.10 (M)** **Test 3** : rollback si embedding fail — mock qui throw à mi-chemin → vérifier 0 row dans `knowledge_document` ET 0 dans `knowledge_chunk`
- [ ] **T6.11 (M)** **Test 4** : UNIQUE (doc_id, chunk_idx) — relancer le même ingest 2x → 2 documents distincts (pas de fusion), mais l'INSERT chunks idempotent dans le 2e doc grâce au ON CONFLICT
- [ ] **T6.12 (M)** **Test 5** : metadata invalide (`doc_type = "xxx"`) → erreur avant tout INSERT, vérifier 0 row inséré

- [ ] **T6.13 (S)** Commit `feat(rag): add ingest_knowledge_document() orchestrator`.

**Critères de sortie T6** :
- `ingest_knowledge_document` exporté + roxygen
- 5 tests intégration verts (skipped si pas de `NEMETON_DB_URL_TEST`)
- Transaction atomique vérifiée
- 1 commit isolé

---

## Chantier T7 — `retrieve_knowledge()` + SQL ANN

### 7.1 Module retrieve

- [ ] **T7.1 (S)** Créer `R/rag-retrieve.R` avec header roxygen.

### 7.2 Implémentation principale

- [ ] **T7.2 (XL)** `retrieve_knowledge(con, query, top_k = 8L, family_codes = NULL, profile_codes = NULL, min_similarity = 0.7, lang = NULL, embed_provider = "mistral")` selon plan.md §4.1 :
  - `.assert_pgvector(con)` + validation query non-vide
  - `q_emb <- embed_query(query, provider = embed_provider)` → 3072 floats
  - SQL ANN avec opérateur `<=>` (cosine distance pgvector) et `1 - distance` → similarity
  - Filtres optionnels : `family_codes && $2::text[]`, `profile_codes && $3::text[]`, `lang = $4`, `LIMIT $5`
  - Encodage params : `.pg_vector_literal(q_emb)`, `.pg_text_array` pour les arrays, NA_character_ si NULL
  - Post-filter R `rs <- rs[rs$similarity >= min_similarity, , drop = FALSE]`
  - Si 0 row après filter → `.empty_retrieved_chunks()`
  - Sinon : `rs$pub_date <- as.Date(rs$pub_date)` + tri `order(-similarity)`
- [ ] **T7.3 (S)** Roxygen complet : `@param`, `@return data.frame` avec les 11 colonnes typées, `@examples \dontrun{}`, `@seealso ingest_knowledge_document, format_citations, embed_query`. `@export`.

### 7.3 Détection multi-provider

- [ ] **T7.4 (M)** Helper privé `.check_corpus_embed_models(con, family_codes, profile_codes, lang)` :
  - SQL `SELECT DISTINCT metadata->>'embed_model' AS m FROM knowledge_document WHERE ...` avec mêmes filtres
  - Retourne `character` de modèles distincts
  - Appelé par `retrieve_knowledge` avant `embed_query` :
    - 0 modèle (corpus vide après filtre) → `.empty_retrieved_chunks()` direct, pas d'appel API
    - 1 modèle → tout va bien, l'utilisateur a passé un `embed_provider` cohérent (warning si mismatch avec `.RAG_PROVIDER_MODELS[[embed_provider]]`)
    - ≥ 2 modèles → `cli::cli_warn` « Corpus mixes embed models (X, Y). Results may mix semantically incompatible chunks. » + best-effort

### 7.4 Tests intégration

- [ ] **T7.5 (M)** Étendre `tests/testthat/test-rag-retrieve.R`. Helper `make_fake_corpus(con, n_docs = 3, chunks_per_doc = 5)` (plan §9.3) qui insère directement via `INSERT INTO ...` (bypass embed API), embeddings déterministes par seed.
- [ ] **T7.6 (M)** **Test 1** : corpus vide → `retrieve_knowledge` retourne data.frame 0 ligne avec les 11 colonnes typées
- [ ] **T7.7 (M)** **Test 2** : retrieve match — insérer 3 docs, query déterministe corrélée avec un doc précis → top-1 est ce doc, similarity > 0.7
- [ ] **T7.8 (M)** **Test 3** : filtre `family_codes = c("R")` ne retourne que les docs taggés famille R
- [ ] **T7.9 (M)** **Test 4** : filtre `lang = "fr"` exclut les docs `lang = "en"`
- [ ] **T7.10 (M)** **Test 5** : `min_similarity = 0.99` ne retourne rien (post-filter actif)
- [ ] **T7.11 (M)** **Test 6** : `top_k = 3` borne la sortie même si plus de chunks dépassent `min_similarity`
- [ ] **T7.12 (S)** **Test 7** : multi-provider warning — corpus avec `metadata.embed_model` distincts → `expect_warning(retrieve_knowledge(...), "mixes embed models")`

- [ ] **T7.13 (S)** Commit `feat(rag): add retrieve_knowledge() with ANN cosine search and provider warning`.

**Critères de sortie T7** :
- `retrieve_knowledge` exporté
- 7 tests intégration verts
- Latence mesurée ≤ 200 ms sur corpus de 30 docs (à confirmer dans T11)
- 1 commit isolé

---

## Chantier T8 — `list_knowledge_documents`, `delete_knowledge_document`, `format_citations`

### 8.1 Implémentation

- [ ] **T8.1 (M)** `list_knowledge_documents(con, lang = NULL, doc_type = NULL, family = NULL)` dans `R/rag-retrieve.R` (ou nouveau `R/rag-admin.R`) :
  - SQL `SELECT * FROM knowledge_document WHERE ... ORDER BY ingested_at DESC`
  - Filtres optionnels : `lang = $`, `doc_type = $`, `$ = ANY(family_codes)`
  - Retour `data.frame` 12 colonnes + `n_chunks` calculée par sub-query LEFT JOIN `(SELECT document_id, count(*) FROM knowledge_chunk GROUP BY document_id)`
  - Roxygen complet, `@export`
- [ ] **T8.2 (S)** `delete_knowledge_document(con, document_id)` :
  - `DELETE FROM knowledge_document WHERE id = $1` (cascade FK supprime les chunks)
  - Retour `invisible(integer(1))` — nombre de chunks supprimés (récupéré via `SELECT count(*) FROM knowledge_chunk WHERE document_id = $` AVANT le DELETE)
  - Idempotent : delete sur id inexistant → retour `0L`, pas d'erreur
  - Roxygen, `@export`
- [ ] **T8.3 (L)** `format_citations(retrieved_chunks, format = c("markdown", "html"), lang = "fr")` :
  - Validation : `retrieved_chunks` doit avoir les 11 colonnes (sinon erreur typée)
  - Markdown format selon spec §3.3 :
    ```
    ## Sources documentaires
    
    [^1] *<author>, <year>* — « <title> », <publisher>. p. <page>.
    ```
  - HTML format : `<ol class="citations"><li id="cite-1">...</li></ol>`
  - i18n simple : `lang = "en"` → header `## Source documents`, etc. (lookup interne, pas de `shiny.i18n` côté cœur)
  - Edge case : `nrow == 0` → retour `""` (empty string) ou `"<aucune source>"` selon `lang`
  - Pure (pas d'IO)
  - Roxygen, `@export`

### 8.2 Tests

- [ ] **T8.4 (M)** Créer `tests/testthat/test-rag-delete-list.R` avec 4 tests :
  - **Test 1** : `list_knowledge_documents` retourne docs ingérés (mock corpus 3 docs) avec colonne `n_chunks` correcte
  - **Test 2** : `list_knowledge_documents(con, family = "R")` filtre effectivement
  - **Test 3** : `delete_knowledge_document` cascade → 0 chunks restants pour le doc supprimé
  - **Test 4** : delete idempotent re-delete → retour `0L`, pas d'erreur
- [ ] **T8.5 (M)** Créer `tests/testthat/test-rag-format-citations.R` avec 3 tests :
  - **Test 1** : Markdown valide, contient les 3 citations attendues, footnotes `[^1]` `[^2]` `[^3]` séquentielles
  - **Test 2** : HTML valide, contient `<ol class="citations">` + 3 `<li>`
  - **Test 3** : input vide (nrow=0) → retour `""` (ou message localisé `lang = "fr"|"en"`)

- [ ] **T8.6 (S)** Commit `feat(rag): add list/delete/format_citations admin helpers`.

**Critères de sortie T8** :
- 3 fonctions exportées
- 7 tests verts (4 intégration + 3 offline)
- 1 commit isolé

---

## Chantier T9 — Corpus initial v1 [peut commencer en // de T6/T7]

### 9.1 Manifest CSV

- [ ] **T9.1 (M)** Créer `inst/extdata/knowledge_corpus_v1.csv` avec colonnes : `title, author, publisher, pub_date, lang, doc_type, source_url, license, family_codes, profile_codes, local_path`
- [ ] **T9.2 (L)** Curer **au moins 5 documents seed** parmi les candidats spec §3.4 :
  - **(Obligatoire)** Bernard & Doridant 2024 ONF/DSF — `family_codes = "R"`, `profile_codes = "gestionnaire_onf;naturaliste"`, license OGL
  - **(Obligatoire)** Code forestier — sélection articles L121-1, L122-2 — `family_codes = "S;P"`, license OGL
  - **(Recommandé)** Duplat & Tran-Ha 1997 — `family_codes = "P"`, license « autorisation explicite Tran-Ha avril 2026 » (cf. CLAUDE.md)
  - **(Recommandé)** Larrieu & al. 2018 IBP — `family_codes = "B;N"`, license à vérifier (probable CC-BY)
  - **(Recommandé)** IPCC AFOLU 2019 résumé pour décideurs — `family_codes = "C;E"`, license public-domain
- [ ] **T9.3 (S)** Backlog : compléter jusqu'à ~30 docs en patch v0.23.1 si pression temporelle (spec §3.4 — Forrester biomasse, BD Forêt v2 IGN, Vallauri 2020, Mouret 2022, etc.)

### 9.2 Script de build

- [ ] **T9.4 (L)** Créer `data-raw/build_knowledge_corpus.R` :
  - Lit `inst/extdata/knowledge_corpus_v1.csv`
  - Pour chaque ligne avec `local_path` non-vide ET fichier présent → appelle `ingest_knowledge_document(con, source = local_path, metadata = list_from_row, embed_provider = "mistral")`
  - Pour les lignes avec `source_url` seulement et license permettant le téléchargement (`OGL` / `CC-BY` / `public-domain`) → `download.file(url, tempfile())` puis ingest
  - Skip les docs sous license `unknown` / `restricted` avec un message — l'utilisateur doit les fournir manuellement dans `local_path`
  - Idempotent : appelle d'abord `list_knowledge_documents` et skip les titres déjà présents (matching par `title + author`)
  - Progress bar `cli::cli_progress_bar()`
  - Log final : `n_added`, `n_skipped`, `n_errors`, `total_chunks`, `total_tokens_est`

### 9.3 Smoke ingest

- [ ] **T9.5 (M)** Lancer `Rscript data-raw/build_knowledge_corpus.R` contre la DB de dev (PG locale).
  - Doit ingérer ≥ 5 docs seed sans erreur
  - Vérifier via `list_knowledge_documents` : ≥ 5 rows
  - Vérifier via `retrieve_knowledge(con, "scolyte épicéa Vosges", top_k = 5)` : ≥ 1 résultat avec `similarity > 0.7`
- [ ] **T9.6 (S)** Documenter le résultat du smoke dans `data-raw/build_knowledge_corpus_results.log` (gitignore).
- [ ] **T9.7 (S)** Commit `feat(rag): add seed knowledge corpus v1 (5+ documents)`.

**Critères de sortie T9** :
- CSV + script présents
- ≥ 5 documents seed ingérés sur la DB de dev
- 1 query smoke retourne des résultats pertinents
- 1 commit isolé

---

## Chantier T10 — Documentation + NAMESPACE

### 10.1 Régénération doc

- [ ] **T10.1 (S)** `Rscript -e 'devtools::document()'` — régénère `man/*.Rd` pour les 6 nouvelles fonctions exportées
- [ ] **T10.2 (S)** Vérifier `NAMESPACE` : 6 nouveaux `export(...)` dans l'ordre alphabétique :
  - `export(delete_knowledge_document)`
  - `export(embed_query)`
  - `export(format_citations)`
  - `export(ingest_knowledge_document)`
  - `export(list_knowledge_documents)`
  - `export(retrieve_knowledge)`
- [ ] **T10.3 (S)** Vérifier `Imports: digest` et `Suggests: pdftools` dans DESCRIPTION

### 10.2 Cross-links @seealso

- [ ] **T10.4 (S)** Vérifier que chaque fonction RAG a un `@seealso` qui pointe vers les autres :
  - `ingest_knowledge_document` → `retrieve_knowledge`, `list_knowledge_documents`, `delete_knowledge_document`
  - `retrieve_knowledge` → `embed_query`, `format_citations`, `ingest_knowledge_document`
  - `format_citations` → `retrieve_knowledge`
  - etc.

### 10.3 Vignette (optionnel v1)

- [ ] **T10.5 (XL, optionnel)** Créer `vignettes/rag-perspectives.Rmd` — tutoriel end-to-end (ingest 1 doc → retrieve → format_citations → exemple d'injection dans prompt LLM). **Hors scope v1 si pression temporelle ; livrable patch v0.23.1.**

### 10.4 Smoke `?` interactif

- [ ] **T10.6 (S)** Lancer `?retrieve_knowledge` dans une session R, vérifier le rendu lisible. Idem pour les 5 autres.
- [ ] **T10.7 (S)** Commit `docs(rag): regenerate Rd files and ensure @seealso cross-links`.

**Critères de sortie T10** :
- 6 exports + 6 Rd files générés
- NAMESPACE clean, alphabétique
- `?retrieve_knowledge` lisible
- 1 commit isolé

---

## Chantier T11 — Bench + perf

### 11.1 Script de bench

- [ ] **T11.1 (M)** Créer `data-raw/bench-rag.R` :
  - Setup : DB locale propre, corpus seed v1 ingéré
  - Mesure `system.time()` sur :
    - `ingest_knowledge_document(con, "small.pdf")` — 1 PDF court (cible §7 : ~5 s)
    - `embed_query("scolyte épicéa")` cold puis warm — cible §7 : ~100 ms warm
    - `retrieve_knowledge(con, q, top_k = 8)` cold puis warm — cible §7 : ~180 ms cold, ~100 ms warm
    - `list_knowledge_documents(con)` — cible §7 : < 50 ms
    - `delete_knowledge_document(con, id)` — cible §7 : < 1 s
    - `format_citations(retrieved_chunks)` 8 chunks — cible §7 : < 5 ms
  - Sortie : tableau printé + sauvegarde dans `data-raw/bench-rag-results.csv`
- [ ] **T11.2 (S)** Documenter résultats dans `NEWS.md` v0.23.0 si dérive < 2× (sinon T11.3)

### 11.2 Ajustements éventuels

- [ ] **T11.3 (?, conditionnel)** Si une cible est dépassée :
  - Profiler avec `profvis::profvis()` la fonction lente
  - Identifier le bottleneck (SQL ? API ? format conversion ?)
  - Ajuster : `lists` ivfflat, batch_size embeddings, etc.
  - Documenter dans la spec §7 si compromis tenu

**Critères de sortie T11** :
- Bench documenté, results.csv versionné
- Dans les budgets §7 ou écart justifié
- Pas de commit (data-raw/ pas suivi par défaut, sauf le `.R` du script)
- Commit éventuel : `chore(rag): add benchmark script`

---

## Chantier T12 — Release v0.23.0

### 12.1 Préparation

- [ ] **T12.1 (S)** DESCRIPTION : `Version: 0.23.0` (bump minor — 6 nouvelles fonctions exportées, nouveau schéma DB)
- [ ] **T12.2 (S)** DESCRIPTION : ajouter `digest` à `Imports`, `pdftools` à `Suggests` (cf. plan §8.1)
- [ ] **T12.3 (M)** `NEWS.md` : nouvelle section `# nemeton 0.23.0 (YYYY-MM-DD)` avec sous-sections :
  - **Added** : les 6 fonctions + le pourquoi (E7 walking skeleton — RAG perspectives IA)
  - **Database** : nouvelle migration `0003_rag.sql` (pgvector requis)
  - **Dependencies** : `digest` (Imports), `pdftools` (Suggests)
  - Mention que DuckDB ne supporte pas RAG (graceful error)
- [ ] **T12.4 (M)** `PLAN.md` à la racine :
  - Cocher E7 dans la table d'avancement walking skeleton
  - Mettre à jour la légende si nouveau statut introduit
  - Ajouter entrée journal datée avec résumé : ce qui a changé, baseline tests, points d'attention
- [ ] **T12.5 (S)** `CITATION.cff` à jour de la nouvelle version (si présent à la racine)
- [ ] **T12.6 (S)** Marquer §11 « Validation » dans `spec.md` ET `plan.md` ET `tasks.md` avec les checkboxes cochées + date.

### 12.2 Tests + check

- [ ] **T12.7 (M)** `Rscript -e 'devtools::test()'` complet — cible **≥ 6015 + 37 = 6052 PASS / 0 FAIL** (baseline post-v0.22.1 = 6015, + 37 RAG = 6052, marge sur tests intégration parfois skippés en l'absence de `NEMETON_DB_URL_TEST` / `MISTRAL_API_KEY`)
- [ ] **T12.8 (M)** `Rscript -e 'devtools::check()'` — 0 ERROR / 0 WARNING. Les NOTEs nouvelles doivent être justifiées (typiquement aucune attendue ; tolérée si `pdftools` ou `digest` génère une dépendance système exotique)
- [ ] **T12.9 (S)** `Rscript -e 'covr::package_coverage()'` — pas de chute > 1 % vs baseline

### 12.3 Release

- [ ] **T12.10 (S)** Merge `feat/009-rag-perspectives-ia` sur `main` (PR ou FF — historique linéaire favorisé, cf. spec 010 convention)
- [ ] **T12.11 (S)** Tag annoté `v0.23.0` :
  ```
  git tag -a v0.23.0 -m "Release 0.23.0 — RAG perspectives IA (spec 009)"
  git push origin v0.23.0
  ```
- [ ] **T12.12 (S)** `gh release create v0.23.0 --generate-notes`
- [ ] **T12.13 (S)** Supprimer la branche `feat/009-rag-perspectives-ia` (local + remote)
- [ ] **T12.14 (S)** Vérifier que les badges README pointent vers `v0.23.0` (cf. consignes de release CLAUDE.md §6)
- [ ] **T12.15 (S)** Update `spec.md` + `plan.md` + `tasks.md` : section §11 / §12 validation cochée + date

**Critères de sortie T12** :
- Release publiée sur GitHub
- DESCRIPTION + tag + release strictement alignés (`v0.23.0`)
- Branche supprimée, working tree clean sur main
- PLAN.md racine reflète E7 livré

---

## Hors scope — Côté app `nemetonshiny`

Pour mémoire (suivi côté repo app, **pas ici**) :

- Wiring `retrieve_knowledge` dans `R/llm_prompts.R` avant chaque appel LLM
- Injection du bloc `## Sources documentaires` dans le prompt LLM
- Instruction LLM : « Cite tes sources avec `[^1]`, `[^2]`… »
- Rendu UI du bloc "Sources" sous chaque perspective dans `mod_synthesis.R`
- Hover/click sur footnote → texte du chunk + lien `source_url`
- Smoke `shinytest2` sur la génération de perspective avec citations
- i18n keys nouvelles (FR/EN) pour "Sources documentaires", "Aucune source trouvée", etc.
- Bump `Imports: nemeton (>= 0.23.0)` + `Remotes: pobsteta/nemeton@v0.23.0`
- Bump minor `nemetonshiny` (probable `v0.29.0`)
- (Optionnel) Nouvelle vue "Knowledge search" pour les chercheurs (user story §4.2) — peut être patch ultérieur

---

## Critères d'acceptation globaux (rappel spec.md §6.1)

À cocher au moment du T12 :

- [ ] **A1** — Migration `0003_rag.sql` ajoute les 2 tables + ivfflat (T1)
- [ ] **A2** — `ingest_knowledge_document` PDF ≤ 10 pages en < 30 s (T11 bench)
- [ ] **A3** — `embed_query` retourne `numeric(3072)` non-NA en < 1 s (T11 bench)
- [ ] **A4** — `retrieve_knowledge` retourne ≥ 1 chunk `similarity ≥ 0.7` en < 200 ms warm (T11 bench)
- [ ] **A5** — `retrieve_knowledge(family_codes = "R")` filtre correctement (T7.8)
- [ ] **A6** — `format_citations` Markdown valide (T8.5 test 1)
- [ ] **A7** — `delete_knowledge_document` cascade en < 1 s (T8.4 + T11 bench)
- [ ] **A8** — `list_knowledge_documents` trié desc par ingest_at (T8.4)
- [ ] **A9** — 6 fonctions exportées + roxygen complet (T10)
- [ ] **A10** — ≥ 20 tests `test-rag-*.R` (37 prévus : 21 offline + 16 intégration)
- [ ] **A11** — `devtools::check()` clean (T12.8)
- [ ] **A12** — Corpus seed v1 (≥ 5 docs) ingéré avec succès (T9.5)

---

## Comptage des tâches

| Chantier | Tâches | Effort cumulé approx |
|----------|--------|----------------------|
| T1 — Migration `0003_rag.sql` | 6 | ~1 h |
| T2 — Helpers privés | 7 | ~1.5 h |
| T3 — Chunking | 6 | ~2 h |
| T4 — Mistral + `embed_query` | 8 | ~2 h |
| T5 — OpenAI + Voyage + padding | 7 | ~2 h |
| T6 — `ingest_knowledge_document` | 7 | ~2.5 h |
| T7 — `retrieve_knowledge` + ANN | 9 | ~2.5 h |
| T8 — list / delete / format_citations | 6 | ~1.5 h |
| T9 — Corpus seed v1 | 7 | ~3 h (curation) |
| T10 — Doc + NAMESPACE | 7 | ~1 h |
| T11 — Bench | 3 | ~1 h |
| T12 — Release | 15 | ~1 h |
| **Total** | **88** | **~21 h** |

(Estimation revue à la hausse vs plan.md §6 — 21 h plutôt que 20 h, marge pour debug PG/pgvector côté tests intégration et curation T9.)

**Note** : 88 sous-tâches au comptage fin, regroupées sous 56 « unités logiques » référencées en en-tête. Les `[P]` parallèles (T3 ↔ T4) gagnent ~2 h sur le total chronologique.

---

## Convention de branche et commits

- **Branche unique** : `feat/009-rag-perspectives-ia` (depuis `main` post-v0.22.1)
- **Commits granulaires** : un par chantier minimum, plusieurs si le chantier est long (T6, T7)
- **Messages** : Conventional Commits — `feat(db): …` pour T1, `feat(rag): …` pour T2-T9, `docs(rag): …` pour T10, `chore(rag): …` pour bench, `chore(release): …` pour T12
- **Pas de squash final** : on garde l'historique granulaire pour faciliter le bisect futur
- **Pas de force-push** : la branche est partagée même si solo (CI / collaborateurs futurs)

---

## Dépendances externes à valider avant T1

- [ ] **PG.1** — Image Docker `timescale/timescaledb-ha:pg16` active dans `docker-compose.yml` (acquis depuis 2026-05-05)
- [ ] **PG.2** — Vérifier que pgvector est bien dispo : `docker compose exec timescaledb psql -U postgres -c "SELECT extversion FROM pg_extension WHERE extname = 'vector';"` → devrait retourner ≥ 0.7
- [ ] **API.1** — Clé `MISTRAL_API_KEY` dans `.Renviron` (gitignore) pour le smoke T9
- [ ] **API.2** — (Optionnel) Clé `OPENAI_API_KEY` et/ou `VOYAGE_API_KEY` pour smoke multi-provider

---

## Validation

- [ ] `tasks.md` relu et validé par Pascal Obstétar
- [ ] Branche `feat/009-rag-perspectives-ia` créée
- [ ] T1 commencé

**Validateur** : Pascal Obstétar
**Date validation** : _à remplir_
