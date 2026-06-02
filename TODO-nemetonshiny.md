# TODO — chantiers app `nemetonshiny` en attente de wiring cœur

**But** : note de hand-off (repo `nemeton` → repo `nemetonshiny`). Liste les
features cœur **déjà livrées et publiées** qui attendent leur câblage côté
app. Chaque entrée = ce qui est dispo côté cœur (release + fonctions), ce
qu'il reste à faire côté app, et le plancher `Imports`.

> Mettre à jour au fil des livraisons app. Les briefs détaillés ont été
> produits en session ; cette table en est l'index.

État repo `nemeton` à la création : **v0.62.0** (2026-06-02).
État repo `nemetonshiny` au départ : **v0.53.1**.

| # | Chantier app | Cœur requis | Statut app |
|---|--------------|-------------|------------|
| 1 | Pré-calcul FAST (navigation instantanée) | `nemeton (>= 0.61.0)` | ⬜ à faire |
| 2 | Perspectives IA sourcées (RAG) | `nemeton (>= 0.62.0)` | ⬜ à faire |
| 3 | Modal diagnostic pixel CRSWIR (L3) | `nemeton (>= 0.43.0)` | ⬜ à faire |
| 4 | Toggle « Mode rapide » (multi-cœur FAST) | `nemeton (>= 0.57.0)` | ⬜ à faire |
| 5 | Toggle indicateur NDVI/NBR + quartiles | `nemeton (>= 0.55.0)` | ⬜ à faire |

---

## 1. Pré-calcul des 4 cartes FAST (`feat`, MINOR)

**Cœur** : `nemeton@v0.61.0`. `ingest_sentinel2_timeseries()` gagne
`prewarm_alerts = FALSE` + `prewarm_mask_cache_dir = NULL`. Quand `TRUE`,
les 4 cartes FAST (`NDVI`/`NBR` × `count`/`rolling`) sont pré-calculées en
fin d'ingestion → onglet Alertes FAST instantané, plus de recalcul 5-30 s
au switch radio.

**À faire (app)** :
- `R/service_monitoring.R` (`run_ingestion_async`) : 2 nouveaux params
  forwardés à `ingest_sentinel2_timeseries()`.
- `R/mod_monitoring.R` (`fast_task$invoke`) : passer `prewarm_alerts = TRUE`
  + `prewarm_mask_cache_dir = file.path(proj_path, "cache", "layers", "fast_alert")`.
  **Doit être le même dossier** que le `result_cache_dir` que l'onglet
  Alertes FAST passe déjà à `read_fast_alert_raster()` (sinon cache raté).
- Observer progress : reconnaître les events `fast_prewarm:<index>_<mode>`
  / `_done` / `_failed` (champs `index`/`mode`) → toast localisé.
- i18n : `fast_mode_frequence` (count), `fast_mode_intensite` (rolling),
  `fast_prewarm_running/_done/_failed`.
- `Imports: nemeton (>= 0.61.0)`.
- Non-breaking (ingestion plus longue ~20-60 s, navigation instantanée
  derrière).

## 2. Perspectives IA sourcées — RAG (`feat`, MINOR)

**Cœur** : `nemeton@v0.62.0` (machinerie close). Fonctions :
`retrieve_knowledge(con, query, top_k, family_codes, profile_codes,
min_similarity, lang, embed_provider)`, `format_citations(chunks, format,
lang)`, `embed_query()`.

**Prérequis (hors code, une fois)** :
- `enable_rag(con)` sur la base prod (pgvector).
- Corpus construit : `Rscript data-raw/build_knowledge_corpus.R` (repo
  `nemeton`). ⚠️ Le build **ne** retombe **pas** automatiquement sur
  `NEMETON_DB_URL` (défaut sûr = SQLite local). Pour peupler la prod il
  faut le pointer **explicitement** : `export NEMETON_KNOWLEDGE_DB_URL="$NEMETON_DB_URL"`
  (évite toute écriture prod accidentelle, cf. garde-fous `NEMETON_DB_URL_TEST`).
- Clé d'embedding : `MISTRAL_API_KEY` (fallback reconnu — **pas** besoin de
  `NEMETON_MISTRAL_API_KEY`). Attention : le build tourne depuis le repo
  `nemeton`, donc la clé doit être dans `~/.Renviron` (utilisateur) ou
  exportée dans le shell, pas seulement dans `nemetonshiny/.Renviron`.

**BD knowledge — où ?** Le corpus est une connaissance **globale** (pas
per-projet). Adressée par `NEMETON_KNOWLEDGE_DB_URL` (découplée du build).
En prod : pointer cette URL sur le **même PG** que `NEMETON_DB_URL` (les
tables `knowledge_*` cohabitent ; pgvector). BD séparée = optionnel
(cycle de vie indépendant). **Ne jamais** mettre le corpus dans un SQLite
*par-projet* (duplication) — si backend local, un seul SQLite knowledge
partagé.

> **À écrire côté app** : il n'existe **aucun** fallback automatique
> `NEMETON_KNOWLEDGE_DB_URL → NEMETON_DB_URL` dans le cœur (les fonctions RAG
> prennent un `con` explicite ; le build retombe sur SQLite local). C'est
> donc à `service_rag.R` de le faire : utiliser la connexion dédiée si
> `NEMETON_KNOWLEDGE_DB_URL` est définie, sinon **réutiliser la connexion
> existante de l'app** (déjà ouverte sur `NEMETON_DB_URL`) — trivial et sûr
> en lecture.

**À faire (app)** :
- `R/service_rag.R` (nouveau, orchestration mince — appelle seulement le
  cœur, règles 1/3) : `rag_context()` → `list(chunks, prompt_block,
  sources_md)`. **Non-bloquant** : toute erreur RAG / corpus vide / clé
  absente → contexte vide, perspective générée sans sources.
- `R/llm_prompts.R` : préfixer le prompt avec `prompt_block` (chunks
  numérotés `[^n]`) + consigne de citation ; requête sémantique =
  résumé situation (profil + familles saillantes + faits marquants).
- `R/mod_synthesis.R` : rendre `sources_md` sous la perspective
  (`shiny::markdown`) ; badge « sourcée par N documents » optionnel.
- i18n : `rag_sourced_badge`, `rag_toggle_label` (le titre du bloc Sources
  vient du cœur via `format_citations(lang=)`).
- Provider d'embedding **identique** à l'ingestion (Mistral) — le cœur
  avertit si le corpus mélange des providers.
- `Imports: nemeton (>= 0.62.0)`. Opt-out via `getOption("nemeton.rag_enabled")`.

## 3. Modal diagnostic pixel CRSWIR — L3 (`feat`, MINOR)

**Cœur** : `nemeton@v0.43.0`. `read_fordead_pixel_series(con, zone_id, xy,
crs, run_id, cache_dir)` reconstruit la série + la prédiction harmonique
d'un pixel cliqué (lit le bundle diagnostic L1 v0.42.0).

**À faire (app)** : handler de clic sur `mod_monitoring_fordead_map` +
modal plotly affichant CRSWIR observé vs prédit + date de première
anomalie. Parité avec la Carte pixel FAST. `Imports: nemeton (>= 0.43.0)`.

## 4. Toggle « Mode rapide (multi-cœur) » FAST (`feat`, MINOR)

**Cœur** : `nemeton@v0.57.0` (spec 017 D4). `read_fast_alert_raster(...,
parallel = FALSE)` ; `parallel = TRUE` + `furrr` installé → calcul par
scène multi-cœur (résultats identiques au séquentiel).

**À faire (app)** : case à cocher « Mode rapide » → `parallel = TRUE` sur
les appels `read_fast_alert_raster()`. Nécessite un `future::plan()` côté
app (`multisession` en prod). `Imports: nemeton (>= 0.57.0)`.

## 5. Toggle indicateur NDVI/NBR + quartiles (`feat`/`fix`, MINOR)

**Cœur** : `nemeton@v0.55.0` (spec 017 D1-D2). `read_fast_alert_raster()`
est mono-indice (`index = c("NDVI","NBR")`, `threshold` unique) ;
`compute_fast_alert_mask()` rend des **quartiles** (classe 0 sain, 1-4).

**À faire (app)** : aligner l'UI Alertes FAST sur la signature
`index`/`threshold` (toggle NDVI/NBR), affichage en quartiles 0-4 ;
corriger tout reliquat appelant l'ancien « ingest per-placette » au lieu
de `read_fast_alert_raster()`. `Imports: nemeton (>= 0.55.0)`.

---

## Reliquats hors-app (côté Pascal / cœur)

- **Build réel du corpus RAG** : `Rscript data-raw/build_knowledge_corpus.R`
  avec `MISTRAL_API_KEY` + `NEMETON_KNOWLEDGE_DB_URL` (= `NEMETON_DB_URL`
  en prod). Lancer un `NEMETON_CORPUS_DRY_RUN=TRUE` d'abord.
- **Sourcer les lignes `full` sans source** du manifest (PDF/URL à
  attacher) et, optionnellement, lever le `to_confirm` des 4 papiers
  copyright pour les ingérer en `link_only`.
