# Spécification Fonctionnelle : RAG pour perspectives IA (E7)

**Version** : 0.1.1 (draft)
**Date**    : 2026-05-15 (cible version actualisée 2026-05-29)
**Statut**  : Draft — en attente de validation pour `plan.md`
**Auteur**  : Pascal Obstétar (via Claude)
**Cible**   : à fixer au démarrage du chantier (les versions v0.23.0 / v0.29.0 mentionnées à la rédaction initiale 2026-05-15 sont périmées — le cœur est à v0.51.0 et l'app à v0.50.1 au 2026-05-29 ; cibler vraisemblablement `nemeton` v0.52.0+). Dépend de la **spec fille 009.1** (constitution du corpus) qui doit livrer le manifest + le pipeline d'ingestion avant que le RAG ait quelque chose à interroger.
**Lien**    : ferme l'épaississement **E7** du walking skeleton (PLAN.md). Préfigure ADR-012 (extensions PG futures — pgvector). Aboutissement de la chaîne *acteur → indicateurs → perspective IA* déjà câblée pour les 13 profils experts (E3, livré).

---

## 1. Résumé exécutif

### 1.1 Vision

Aujourd'hui (E3, livré), une perspective IA pour un acteur — disons un *gestionnaire ONF* — est générée par un appel direct à un LLM (Mistral / OpenAI / Anthropic via `ellmer`) avec en entrée :

- le profil expert (`inst/experts/gestionnaire_onf.yml`, FR/EN)
- les 31 indicateurs normalisés de la zone
- le score global pondéré Fibonacci

Le LLM produit un texte libre, intéressant mais **sans appui documentaire**. Aucune citation, aucun ancrage scientifique, aucune référence aux taux de validation FORDEAD du rapport ONF/DSF, aux courbes de Duplat & Tran-Ha pour le site index, à la BD Forêt v2, au Code forestier, etc. L'utilisateur expert — typiquement un chercheur ou un technicien forestier — n'a aucun moyen de remonter à la source.

La **RAG** (Retrieval-Augmented Generation) corrige ça : avant l'appel LLM, on récupère depuis une base de connaissances forestière vectorisée les passages les plus pertinents pour la requête (profil + indicateurs), et on les **injecte dans le contexte** de l'appel. Le LLM est instruit de produire ses recommandations avec des **citations explicites** vers les passages récupérés. L'app affiche les citations sous la perspective avec un lien vers le document source.

### 1.2 Principe — pipeline en 3 étages

```
   ┌────────────────────────────────────────────────────────────────┐
   │ INGESTION (offline, batch)                                     │
   │                                                                │
   │  PDF / texte → découpage chunks → embeddings → pgvector        │
   │                (~512 tokens)        (1024 dim)                 │
   └────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼  (table knowledge_chunk dans la DB nemeton)
   ┌────────────────────────────────────────────────────────────────┐
   │ RECHERCHE (à chaque demande de perspective, ~50-200 ms)        │
   │                                                                │
   │  query texte → embedding → ANN search top-k → chunks scorés    │
   │  (profil + indicateurs ciblés)                                 │
   └────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼  (8-12 chunks au max, ~3-5 k tokens)
   ┌────────────────────────────────────────────────────────────────┐
   │ GÉNÉRATION (LLM, déjà existante, augmentée)                    │
   │                                                                │
   │  prompt = profil + indicateurs + chunks récupérés              │
   │  → LLM (Mistral par défaut, ADR-004)                            │
   │  → texte avec citations [^1] [^2] vers les chunks               │
   │  → app affiche perspective + bloc "Sources"                    │
   └────────────────────────────────────────────────────────────────┘
```

### 1.3 Objectifs métier

| Objectif | Métrique de succès |
|----------|-------------------|
| Ancrer chaque perspective IA dans une base de connaissances vérifiable | Toute perspective émise affiche ≥ 3 citations, chacune cliquable vers le passage source |
| Souveraineté des données | Embeddings via Mistral (FR, ADR-004). Corpus stocké en local (pgvector). Pas d'envoi du corpus à un tiers. |
| Recherche < 200 ms | ANN cosine via index ivfflat sur `vector(1024)` |
| Mise à jour incrémentale | Ajouter un PDF → ingestion idempotente (re-run safe), pas de re-calcul des embeddings existants |
| Filtrage thématique | Recherche restreinte par famille d'indicateurs (`R`, `C`, `B`…) et par profil acteur |
| Multilingue | Corpus mixte FR + EN (papiers scientifiques internationaux). Recherche dans la langue de la requête, citations dans la langue source. |
| Audit | Quelle perspective a cité quels chunks, quand, avec quel score de similarité — traçable côté DB pour évaluation qualité |

### 1.4 Hors-scope (cette spec)

- **L'appel LLM lui-même** (déjà câblé côté `nemetonshiny` via `ellmer`, multi-provider). Spec 009 ne touche pas à `R/llm_prompts.R` de l'app — elle se branche en amont, en injectant les chunks dans le `context` passé au prompt builder.
- **L'UI de citation** (bloc "Sources" sous la perspective). Côté app, hors scope cœur. Mentionné §2.2.
- **Curation manuelle du corpus** (validation éditoriale des PDF qu'on ingère). Voir spec fille 009.1 si besoin.
- **Multi-modalité** (images, graphiques, tableaux extraits du PDF). v1 = texte seul. Extension §7.
- **Fine-tuning** des embeddings sur le domaine forestier. v1 = modèle Mistral générique. Extension §7.
- **Réranking** (cross-encoder pour scorer les top-k de l'ANN). v1 = similarité cosinus brute. Extension §7.

---

## 2. Scope

### 2.1 Périmètre cœur (`nemeton`)

#### 2.1.1 Schéma DB (migration `0003_rag.sql`)

Deux nouvelles tables dans le schéma `nemeton` :

```sql
-- Documents source (PDF, article, rapport, etc.)
CREATE TABLE knowledge_document (
  id            SERIAL       PRIMARY KEY,
  title         TEXT         NOT NULL,
  author        TEXT,
  publisher     TEXT,
  pub_date      DATE,
  lang          TEXT         NOT NULL,        -- ISO 639-1 ('fr', 'en', 'de', …)
  doc_type      TEXT         NOT NULL,        -- 'paper' | 'report' | 'regulation'
                                              -- | 'manual' | 'note' | 'web'
  source_url    TEXT,                         -- canonical URL si applicable
  license       TEXT         NOT NULL,        -- 'CC-BY' | 'OGL' | 'public-domain'
                                              -- | 'unknown' | 'restricted'
  family_codes  TEXT[],                       -- ['B','R'] ou indicateur ['R5']
  profile_codes TEXT[],                       -- ['gestionnaire_onf', ...]
  metadata      JSONB        NOT NULL DEFAULT '{}'::jsonb,
  ingested_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
  ingested_by   TEXT
);

CREATE INDEX knowledge_document_lang_idx     ON knowledge_document (lang);
CREATE INDEX knowledge_document_doc_type_idx ON knowledge_document (doc_type);
CREATE INDEX knowledge_document_family_gin   ON knowledge_document USING GIN (family_codes);

-- Chunks vectorisés
CREATE TABLE knowledge_chunk (
  id            SERIAL          PRIMARY KEY,
  document_id   INTEGER         NOT NULL REFERENCES knowledge_document(id)
                                ON DELETE CASCADE,
  chunk_index   INTEGER         NOT NULL,     -- 0..N-1 par document
  page_number   INTEGER,                      -- pour PDF, NULL sinon
  text          TEXT            NOT NULL,
  text_hash     TEXT            NOT NULL,     -- sha256 hex du texte, dédup intra-doc
  token_count   INTEGER,
  embedding     vector(3072),                 -- dim « plus large » : couvre OpenAI
                                              -- text-embedding-3-large natif (3072)
                                              -- et zero-pad Mistral / Voyage 1024
                                              -- et OpenAI small 1536. Switch de
                                              -- provider possible sans migration
                                              -- du schéma (mais re-embedding du
                                              -- corpus reste obligatoire).
  UNIQUE (document_id, chunk_index)
);

CREATE INDEX knowledge_chunk_doc_idx ON knowledge_chunk (document_id);
CREATE INDEX knowledge_chunk_embedding_idx
  ON knowledge_chunk USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);
```

**Décision tranchée** : colonne `vector(3072)` — choix « plus large » qui accommode les trois familles de providers commerciaux (OpenAI natif, Mistral / Voyage zero-paddés). Permet de **basculer de provider sans migration du schéma DB**. Re-embedding du corpus reste obligatoire (les vecteurs Mistral et OpenAI vivent dans des espaces vectoriels différents — leur cosine n'a pas de sens sémantique entre providers). Cf. §8 D2 pour les détails et §9 pour le risque associé.

**Note Claude / Anthropic** : Claude (Anthropic) n'a pas d'endpoint embeddings. Pour rester dans l'écosystème Anthropic, on utilise **Voyage AI** (modèle `voyage-3-large` ou `voyage-multilingual-2`, recommandé par Anthropic). Voyage est traité comme un 3e provider dans l'API `embed_provider = c("mistral", "openai", "voyage")`.

#### 2.1.2 API publique (R)

| Fonction | Rôle | Effet de bord |
|----------|------|--------------|
| `ingest_knowledge_document(con, source, metadata, chunk_size, chunk_overlap)` | Ingère un PDF / fichier .txt / chaîne markdown → chunks → embeddings → DB | INSERT dans `knowledge_document` + `knowledge_chunk` |
| `embed_query(text, provider, lang)` | Calcule l'embedding d'une chaîne (utile pour debug + retrieval) | Appel API (Mistral par défaut) |
| `retrieve_knowledge(con, query, top_k, family_codes, profile_codes, min_similarity, lang)` | ANN cosine top-k, retourne chunks scorés filtrés | Lecture seule |
| `list_knowledge_documents(con, lang, doc_type, family)` | Inventaire de la base | Lecture seule |
| `delete_knowledge_document(con, document_id)` | Supprime un document + ses chunks (cascade FK) | DELETE |
| `format_citations(retrieved_chunks)` | Formatte un bloc Markdown "Sources" prêt à concaténer à la perspective | Pure |

Détails contractuels en §5.

#### 2.1.3 Helpers internes (privés)

- `.chunk_text(text, size, overlap)` — découpage en chunks de ~`size` tokens avec recouvrement
- `.mistral_embed(text_vec, api_key)` — appel HTTP à `https://api.mistral.ai/v1/embeddings`
- `.pdf_to_text(path)` — extraction texte via `pdftools::pdf_text()` (déjà disponible si `pdftools` est en Suggests)
- `.estimate_tokens(text)` — heuristique `nchar / 4` pour le count par chunk (assez précis pour Mistral en FR/EN)

### 2.2 Périmètre app (`nemetonshiny`) — hors repo

Pour mémoire :

- **Wiring du retrieval** dans `R/llm_prompts.R` :
  - Avant chaque appel LLM, `retrieve_knowledge(con, query = profile_context, …)` avec `family_codes = profile.priority_families`
  - Injection des chunks dans le prompt sous une section `\n## Sources documentaires\n…`
  - Instruction au LLM : *"Cite tes sources avec [^1], [^2]… qui correspondent aux passages numérotés ci-dessus."*
- **UI block "Sources"** sous chaque perspective :
  - Liste des chunks cités, avec `title`, `author`, `pub_date`, lien `source_url`
  - Hover → texte du chunk en tooltip
  - Cf. `mod_synthesis.R` pour le point d'insertion

### 2.3 Hors scope

Déjà listé §1.4.

---

## 3. Architecture détaillée

### 3.1 Flux d'ingestion

```
Source (PDF / .txt / .md)
        │
        ▼
.pdf_to_text() / lecture brute
        │
        ▼
.chunk_text(size = 512, overlap = 50)
        │  (liste de chr, chacun ~512 tokens)
        ▼
.estimate_tokens() + sha256(text)
        │
        ▼
.mistral_embed(text_vec)              ← API HTTP Mistral, batch 32
        │  (matrice n×1024)
        ▼
INSERT knowledge_document (return id)
INSERT knowledge_chunk    (foreach chunk_index, embedding, …)
        │
        ▼
return invisible(list(document_id, n_chunks, n_tokens))
```

Idempotence : si `text_hash` existe déjà sous le même `document_id`, l'insertion est skippée (`ON CONFLICT (document_id, chunk_index) DO NOTHING`). Pour re-ingérer un document avec une stratégie de chunking différente, l'utilisateur passe explicitement par `delete_knowledge_document()` d'abord.

### 3.2 Flux de retrieval

```
Query texte (ex: "scolyte épicéa nord-est France")
        │
        ▼
.mistral_embed(query)                 ← 1 appel API, dim 1024
        │
        ▼
SQL :
  SELECT c.*, d.title, d.source_url, d.pub_date, d.lang,
         1 - (c.embedding <=> $1::vector) AS similarity
  FROM knowledge_chunk c
  JOIN knowledge_document d ON d.id = c.document_id
  WHERE ($2::text[] IS NULL OR d.family_codes && $2::text[])
    AND ($3::text[] IS NULL OR d.profile_codes && $3::text[])
    AND ($4::text IS NULL OR d.lang = $4)
  ORDER BY c.embedding <=> $1::vector       -- index ivfflat
  LIMIT $5;
        │
        ▼
Post-filter : ne garder que similarity ≥ min_similarity (default 0.7)
        │
        ▼
data.frame(chunk_id, document_id, title, author, pub_date, source_url,
           lang, chunk_index, page_number, text, similarity)
```

**Choix d'index** : `ivfflat` avec `lists = 100`. Pour < 100k chunks, suffisant et build rapide. Au-delà, on bascule sur `hnsw` (PG 16 le supporte via pgvector ≥ 0.7) — décision ADR-012 future.

### 3.3 Format de citation

Les chunks retournés sont sérialisés en bloc Markdown avant injection :

```markdown
## Sources documentaires

[^1] *Bernard & Doridant, 2024* — « Méthode FORDEAD: analyse de la
validité des détections… », ONF/DSF. p. 23-25, classe 4-sol nu : 70%
de bonne détection (n=146 placettes).

[^2] *Duplat & Tran-Ha, 1997* — « Modélisation de la croissance en
hauteur dominante du chêne sessile en France », Rev. For. Fr. p. 12.
Courbe de site index hauteur dominante par classe d'âge.

[^3] Code forestier (FR), art. L121-1 — gestion durable et
multifonctionnelle des forêts.
```

Le LLM reçoit ce bloc, puis génère sa perspective avec `[^1]`, `[^2]` aux endroits appropriés. L'app rend ces footnotes en hyperliens cliquables vers le bloc Sources de la perspective.

### 3.4 Corpus initial (v0.23.0)

Cible minimale pour la release : **20-30 documents** structurants, déjà identifiés dans le projet :

| Catégorie | Documents (estimation) | Famille(s) couverte(s) |
|-----------|------------------------|------------------------|
| FORDEAD | Bernard & Doridant 2024 (ONF/DSF) ; Mouret & al. 2022 (papier méthode) | R5 |
| Site index | Duplat & Tran-Ha 1997 (chêne, autorisation explicite) ; courbes essences | P2 |
| Biomasse | Forrester & al. 2017 (allométrie pan-EU) ; IGN biomasse FR 2018 | C1 |
| Naturalité | Larrieu & al. 2018 (IBP) ; Vallauri 2020 (forêts anciennes) | N1, N2, N3 |
| Carbone | IPCC AFOLU 2019 ; CITEPA inventaires FR | C1, E2 |
| BD Forêt v2 | IGN guide méthodo ; règles de regroupement essences | Toutes |
| Code forestier | Articles L121-1, L122-2, … | S, P |
| Stratégie forêts UE | Communication COM(2021) 572 | Toutes |

**Curation** : la liste exacte sera figée dans `inst/extdata/knowledge_corpus_v1.csv` (titre, auteur, URL, license, family_codes, profile_codes) + un script `data-raw/build_knowledge_corpus.R` qui télécharge les PDFs (ceux dont la license le permet) et appelle `ingest_knowledge_document` en boucle. Reproductible et idempotent.

---

## 4. User stories

### 4.1 Gestionnaire ONF — perspectives sourcées

> En tant que **gestionnaire ONF**, après le calcul des 31 indicateurs sur ma forêt domaniale des Vosges, je veux que la perspective IA me cite explicitement le rapport ONF/DSF 2024 quand elle parle des taux de validation FORDEAD de mon R5, pour que je puisse vérifier l'argument avant de m'en servir en réunion.

**Workflow** : clic sur "Générer perspective" → app récupère 8 chunks pertinents (FORDEAD, vosges, scolyte, épicéa) → LLM produit le texte avec `[^1]` → UI rend la perspective + bloc Sources.

**Critère** : la mention « 82% de bonne détection en classe 3-forte » dans la perspective est marquée d'une footnote `[^1]` qui pointe vers le chunk extrait de Bernard & Doridant 2024 p.42.

### 4.2 Chercheur — recherche thématique directe

> En tant que **chercheur**, je veux pouvoir lancer une recherche libre dans la base de connaissances depuis l'interface (sans passer par une perspective complète) pour trouver les passages discutant d'un sujet précis comme « calibration CRSWIR sapin pectiné ».

**Workflow** : nouvelle vue "Knowledge search" dans l'UI app (hors scope cœur mais débloquée par cette spec) → tape la requête → `retrieve_knowledge(con, query, top_k = 20)` → table des chunks scorés avec lien vers le document source.

**Critère** : recherche cosine retourne ≥ 1 résultat pertinent (similarity ≥ 0.7) en < 500 ms sur un corpus de 30 documents.

### 4.3 Forestier privé — perspective vulgarisée

> En tant que **propriétaire privé**, je veux que la perspective utilise un vocabulaire accessible mais qu'elle reste vérifiable. Quand elle parle de "la directive UE", je veux pouvoir cliquer et lire l'article concret.

**Workflow** : profil `proprietaire_prive` → retrieve filtré par `profile_codes && {'proprietaire_prive'}` (chunks pré-taggés "accessible" éventuellement, voir extension 009.2) → texte LLM + Sources.

**Critère** : perspectives `proprietaire_prive` citent en priorité les notes IGN / ministère (lectorat grand public) plutôt que les papiers scientifiques.

### 4.4 Administrateur — audit qualité

> En tant qu'**administrateur**, je veux savoir quelle perspective a cité quels chunks, avec quels scores, pour évaluer si le retrieval est pertinent et si certains documents devraient être retirés ou repondérés.

**Workflow** : table `perspective_citation` (créée optionnellement, voir §5.6) logue chaque retrieval avec `(perspective_id, chunk_id, similarity, timestamp)`. Vue SQL ad-hoc côté admin.

**Critère** : v1 trace au moins les chunks utilisés dans la perspective (la perspective elle-même n'est pas persistée — décidé hors scope, voir extension 009.3).

---

## 5. API cœur — contrats détaillés

### 5.1 `ingest_knowledge_document()`

```r
ingest_knowledge_document(
  con,                              # DBI connection
  source,                           # chr(1) : path PDF/.txt/.md, ou raw text si nchar > 200
  metadata = list(                  # named list, mandatory fields
    title         = ...,            # chr(1), required
    lang          = "fr",           # ISO 639-1, required
    doc_type      = "report",       # chr(1) in {paper,report,regulation,manual,note,web}
    license       = "unknown",
    author        = NULL,
    publisher     = NULL,
    pub_date      = NULL,           # Date ou coercible
    source_url    = NULL,
    family_codes  = NULL,           # chr vector, valid family/indicator codes
    profile_codes = NULL,           # chr vector, valid profile ids
    extra         = list()          # → JSONB metadata.extra
  ),
  chunk_size      = 512L,           # tokens cibles
  chunk_overlap   = 50L,            # tokens
  embed_provider  = c("mistral", "openai"),  # default mistral
  api_key         = NULL            # default Sys.getenv(NEMETON_<PROVIDER>_API_KEY)
)
```

**Retour** : invisible `list(document_id = int, n_chunks = int, n_tokens_est = int, duration_sec = num)`.

**Comportement** :
- Détection PDF vs texte brut : `endsWith(source, ".pdf")` → `pdftools::pdf_text()`, sinon `endsWith(".txt"|".md")` → `readLines()`, sinon traite `source` comme texte direct.
- Validation `metadata` stricte : champs requis manquants → `stop()`.
- Découpage en chunks via `.chunk_text(size = 512, overlap = 50)`, méthode *sliding window par tokens estimés*.
- Embedding batch de 32 chunks → 1 appel API.
- Tx unique : INSERT document + INSERT chunks, rollback si embedding échoue.

**Error policy** : api_key manquante → message clair + URL pour en obtenir une. Erreur réseau → retry exponentiel (max 3 tentatives) puis rollback.

### 5.2 `embed_query()`

```r
embed_query(
  text,                             # chr(1)
  provider = c("mistral", "openai"),
  api_key  = NULL,
  lang     = NULL                   # 'fr' / 'en' ; influence le modèle pour OpenAI
)
```

**Retour** : `numeric(1024)` (dimension Mistral). Pour OpenAI, projection vers 1024 via troncation ou padding documenté en man page.

**Usage principal** : interne (depuis `retrieve_knowledge`) mais exporté pour debug et batch indexing.

### 5.3 `retrieve_knowledge()`

```r
retrieve_knowledge(
  con,
  query,                            # chr(1) — requête en langue naturelle
  top_k          = 8L,              # nombre max de chunks à retourner
  family_codes   = NULL,            # filtre `family_codes && $`
  profile_codes  = NULL,            # filtre `profile_codes && $`
  min_similarity = 0.7,             # post-filter cosine similarity
  lang           = NULL,            # filtre `d.lang = $`
  embed_provider = "mistral"
)
```

**Retour** : `data.frame` trié par `similarity` décroissant, colonnes :

| Colonne | Type | Description |
|---------|------|-------------|
| `chunk_id` | int | FK chunk |
| `document_id` | int | FK doc |
| `title` | chr | Titre du doc |
| `author` | chr | Auteur(s) |
| `pub_date` | Date | Date publi |
| `source_url` | chr | URL si dispo |
| `lang` | chr | Langue |
| `chunk_index` | int | Position dans doc |
| `page_number` | int | Page PDF si dispo |
| `text` | chr | Contenu du chunk |
| `similarity` | num | Cosine ∈ [-1, 1] mais en pratique [0, 1] |

**Garanties** :
- 0 row possible (retour vide canonique avec les mêmes colonnes typées) si rien ne franchit `min_similarity`.
- Pas d'erreur si pgvector absent du schéma → message explicite "Run db_migrate() to enable RAG schema".

### 5.4 `list_knowledge_documents()`

```r
list_knowledge_documents(
  con,
  lang     = NULL,
  doc_type = NULL,
  family   = NULL                   # élément de family_codes
)
```

**Retour** : `data.frame` complet de `knowledge_document` (sans les chunks), trié par `ingested_at` décroissant.

### 5.5 `delete_knowledge_document()`

```r
delete_knowledge_document(con, document_id)
```

**Retour** : invisible int — nombre de chunks supprimés (cascade FK `ON DELETE CASCADE`).

### 5.6 `format_citations()`

```r
format_citations(
  retrieved_chunks,                 # data.frame retour de retrieve_knowledge
  format = c("markdown", "html"),
  lang   = "fr"
)
```

**Retour** : chr(1) — bloc Markdown ou HTML prêt à concaténer.

**Format Markdown produit** :

```
## Sources documentaires

[^1] *<author>, <year>* — « <title> »<sep><publisher>. <page>.
[^2] ...
```

`<page>` présent si `page_number` non-NULL. `<sep>` = `", "` si publisher présent, sinon `". "`.

### 5.7 [Optionnel — voir D5] `log_perspective_citations()`

Pour le user story §4.4 (audit) — décision §8 à valider. Table `perspective_citation` si retenue :

```sql
CREATE TABLE perspective_citation (
  id            SERIAL      PRIMARY KEY,
  generated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  profile_code  TEXT,
  zone_id       INTEGER     REFERENCES monitoring_zone(id),
  chunk_id      INTEGER     NOT NULL REFERENCES knowledge_chunk(id),
  similarity    DOUBLE PRECISION NOT NULL
);
```

API :

```r
log_perspective_citations(con, profile_code, zone_id, retrieved_chunks)
```

---

## 6. Critères d'acceptation

### 6.1 Côté cœur (cette spec)

- [ ] **A1** — Migration `0003_rag.sql` ajoute `knowledge_document` + `knowledge_chunk` avec index ivfflat. Idempotente (`IF NOT EXISTS`).
- [ ] **A2** — `ingest_knowledge_document()` ingère un PDF test (1 papier court, ≤ 10 pages) en < 30 s.
- [ ] **A3** — `embed_query("scolyte épicéa")` retourne `numeric(1024)` non-NA, en < 1 s.
- [ ] **A4** — `retrieve_knowledge(con, "scolyte épicéa")` sur un corpus de 5 documents retourne ≥ 1 chunk avec `similarity ≥ 0.7`, en < 200 ms (hors cold start API).
- [ ] **A5** — `retrieve_knowledge(..., family_codes = c("R"))` filtre effectivement par tag de famille.
- [ ] **A6** — `format_citations(...)` produit un Markdown valide consommable par `marked.js` / `pandoc`.
- [ ] **A7** — `delete_knowledge_document(con, id)` supprime le doc + les chunks (cascade) en < 1 s.
- [ ] **A8** — `list_knowledge_documents(con)` retourne la liste triée par date d'ingestion décroissante.
- [ ] **A9** — Toutes les fonctions sont exportées + roxygen complet.
- [ ] **A10** — Au moins **20 tests** dans `test-rag.R` couvrant : chunking, hashing, mock embedding API, retrieval ranking, filtres, format citations, suppression cascade. 6 unit + 14 intégration `with_clean_db`.
- [ ] **A11** — `devtools::check()` clean (0 ERROR / 0 WARNING / 0 NOTE nouveau).
- [ ] **A12** — Corpus initial v1 (`inst/extdata/knowledge_corpus_v1.csv` + `data-raw/build_knowledge_corpus.R`) ingéré avec succès sur la DB de dev (smoke).

### 6.2 Côté app (pour mémoire — hors repo)

- [ ] **B1** — Wiring `retrieve_knowledge` dans `R/llm_prompts.R` côté app
- [ ] **B2** — Bloc "Sources" rendu sous chaque perspective (Mod synthesis)
- [ ] **B3** — Smoke shinytest2 sur la génération de perspective avec citations

---

## 7. Extensions (post-v0.23.0)

Numérotées pour devenir des specs filles si livrées :

- **009.1** — *Curation interface* : UI admin pour rajouter des documents au corpus, valider, tagger
- **009.2** — *Reranking* : cross-encoder (BGE-reranker) sur les top-k de l'ANN
- **009.3** — *Perspective persistence* : table `perspective` qui stocke chaque perspective générée + ses citations
- **009.4** — *Multi-modalité* : extraction des figures/tableaux PDF, embeddings CLIP, retrieval images
- **009.5** — *Fine-tuning embeddings* sur le domaine forestier (corpus large auto-collecté)
- **009.6** — *Local embeddings fallback* : sentence-transformers via reticulate si Mistral indispo
- **009.7** — *Multi-DB tenancy* : un corpus par utilisateur (privacy)

---

## 8. Décisions à valider

| ID | Décision | Default proposé | À confirmer |
|----|----------|-----------------|-------------|
| **D1** | Embedding provider par défaut | Mistral `mistral-embed` (1024 dim natif, multilingue, ADR-004 souveraineté). Fallback OpenAI + Voyage (écosystème Anthropic) supportés. | ✅ |
| **D2** | Dimension vectorielle stockée | **3072** (« plus large » — couvre OpenAI text-embedding-3-large natif, Mistral / Voyage 1024 zero-paddés, OpenAI small 1536 paddé). Permet de changer de provider sans migration de schéma. Le re-embedding du corpus reste nécessaire si on change de provider (les espaces vectoriels ne sont pas interchangeables). | ✅ |
| **D3** | Chunk size / overlap | 512 / 50 tokens | ✅ |
| **D4** | Top-k retrieval | 8 | ✅ |
| **D5** | Logger les citations (`perspective_citation`) | NON v1 (extension 009.3) | ✅ |
| **D6** | Inclure Code forestier dans le corpus | OUI (license OGL France, donc libre) | ✅ |
| **D7** | Inclure documents en allemand / espagnol | NON v1 (FR + EN seulement) — préparation européenne en extension future | ✅ |
| **D8** | Index ANN | `ivfflat` avec `lists=100` | ✅ |
| **D9** | Cible release | `nemeton@v0.23.0` (minor — extensions API publique majeure) | ✅ |
| **D10** | `pdftools` en Imports ou Suggests | **Suggests** (ingestion offline, l'app de runtime n'en a pas besoin) | ✅ |
| **D11** | Stocker le texte plein des chunks en DB | OUI (nécessaire pour le rendu de citations, et le re-embedding éventuel) | ✅ |
| **D12** | Re-embedding sur changement de modèle | Procédure documentée (delete all + re-ingest) — pas d'automatisation v1 | ✅ |

---

## 9. Risques et mitigations

| Risque | Probabilité | Impact | Mitigation |
|--------|------------|--------|------------|
| API Mistral indisponible / down | Moyenne | Bloque perspectives RAG | Cache embedding queries (LRU local) ; fallback `provider = "openai"` accepté par `retrieve_knowledge` ; perspective dégradée sans citations si tout fail (graceful degradation, déjà code path existant E3) |
| Coût d'embedding sur gros corpus | Faible | < 1€ pour 30 documents avec Mistral | Documenter le coût estimé ; option `embed_provider = "openai"` si l'utilisateur a déjà du crédit |
| LLM hallucine des citations | Élevée | Citations erronées | Le LLM ne peut citer que les chunks injectés dans son contexte (instructions strictes). Vérification possible côté UI : si une `[^N]` n'a pas de correspondance → afficher en gris/désactivé |
| Pgvector absent de la DB | Moyenne en dev / Faible en prod | `retrieve_knowledge` plante | Helper `assert_pgvector(con)` en haut de chaque fonction RAG → message d'erreur explicite avec la commande migration |
| Embeddings calculés mais index ivfflat pas reconstruit | Faible | Retrieval lent | Index reconstruit dans la migration ; documenter `REINDEX INDEX CONCURRENTLY ...` pour bulk ingest |
| **Mélange de providers dans un même corpus** (chunks A embedded Mistral, chunks B embedded OpenAI → cosine inter-provider insensé) | Moyenne (oubli de re-embed après switch) | Retrieval qualité dégradée silencieusement | Stocker `metadata.embed_model` côté `knowledge_document` ; `retrieve_knowledge` lève un warning si le corpus contient ≥ 2 valeurs distinctes de `embed_model` et que la requête n'a pas spécifié explicitement quel provider utiliser. v1 = warning + best-effort ; v2 (009 patch) = partition par provider |
| Padding zéro Mistral 1024 → 3072 dégrade la qualité | Très faible | Recall ~identique | Mathématiquement transparent intra-provider (les zéros se compensent dans le produit scalaire) ; le seul coût est ~3× le stockage vecteur. Vérifié : ~12 MB pour 1500 chunks vs ~4 MB sans padding. Acceptable. |
| Chunk size trop court → perte de contexte ; trop long → moins précis | Moyenne | Qualité retrieval | 512 = compromis défensif (cf. littérature RAG). Tunable via arg. Métriques de qualité futures : recall@k sur questions test |
| Multilingue : chunk FR retrouvé pour query EN ? | Faible (Mistral multilingue) | Mauvaise pertinence | Tester sur queries cross-langue. Si nécessaire, `lang` filter strict. |
| Licence des documents ingérés | Moyenne | Légal | Champ `license` obligatoire ; UI admin doit l'afficher ; v1 corpus uniquement docs OGL / CC-BY / public domain |
| RGPD si le corpus contient des données nominatives | Faible (papiers scientifiques) | Légal | Documenter : ne pas ingérer de documents contenant des données personnelles |

---

## 10. Documents liés

- `PLAN.md` racine — E7 walking skeleton
- ADR-004 (LLM Mistral souveraineté FR) — `platform_nemeton/docs/`
- ADR-012 (extensions PG futures — TimescaleDB, pgvector) — `platform_nemeton/docs/`
- `nemetonshiny/inst/experts/*.yml` — 13 profils experts (à enrichir avec un champ `prefer_doc_types` ?)
- Spec 008 (`specs/008-suivi-sanitaire/spec.md`) — fournit le rapport ONF/DSF, premier document candidat à l'ingestion
- Spec 010 (`specs/010-carte-pixel-timeseries/spec.md`) — la perspective IA peut citer la carte pixel comme une "preuve visuelle" complémentaire (extension 009.4 multi-modale)

---

## 11. Validation

Prêt à passer à `plan.md` une fois validé :

- [ ] Vision (§1) approuvée
- [ ] Scope (§2) approuvé — *en particulier la frontière cœur/app : qui appelle `retrieve_knowledge`*
- [ ] Schéma DB (§2.1.1) approuvé — *colonnes, types, index*
- [ ] User stories (§4) approuvées
- [ ] API contracts (§5) approuvés — *6 fonctions exportées (+ 1 optionnelle §5.7)*
- [ ] Décisions §8 toutes validées (12 décisions, defaults proposés)
- [ ] Risques §9 acceptés ou mitigations à étoffer

**Validateur** : Pascal Obstétar
**Date validation** : _à remplir_
