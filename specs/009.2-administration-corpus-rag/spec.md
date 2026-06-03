# Spec 009.2 — Administration du corpus RAG depuis l'app (manifest éditable + import)

**Version** : 0.1.0 (draft — plan, à valider avant implémentation)
**Date**    : 2026-06-03
**Statut**  : Draft — en attente de validation pour passage à l'implémentation.
**Auteur**  : Pascal Obstétar (via Claude)
**Parent**  : `specs/009-rag-perspectives-ia/` (machinerie RAG, E7) +
`specs/009.1-corpus-connaissances-forestieres/` (corpus, manifest,
pipeline). 009.2 ne change ni le schéma DB (009) ni la politique de
curation/licence (009.1) : elle **promeut en API publique** la logique
d'orchestration qui vit aujourd'hui dans `data-raw/build_knowledge_corpus.R`,
pour qu'un onglet d'administration côté `nemetonshiny` puisse **éditer le
manifest** et **lancer l'import en base** sans réimplémenter de logique
métier.
**Cible cœur** : `nemeton@v0.63.0` (minor — nouvelle API publique).
**Cible app** : `nemetonshiny` (onglet RAG dans les paramètres — hors repo).

---

## 1. Problème

Aujourd'hui (cœur `v0.62.0`) :

- La **machinerie RAG** est exportée et opère document par document :
  `enable_rag`, `ingest_knowledge_document`, `ingest_knowledge_reference`,
  `embed_query`, `retrieve_knowledge`, `list_knowledge_documents`,
  `delete_knowledge_document`, `format_citations`.
- Mais toute la logique **« manifest → base »** vit dans
  `data-raw/build_knowledge_corpus.R` : un script qui n'est **pas installé**
  (absent de `inst/`), **pas exporté**, **pas appelable** depuis l'app, et
  conçu pour la CLI (`quit()`, `Sys.getenv()`, sorties `cli`).
- Le **vocabulaire contrôlé** qui sert à *valider* le manifest (licences,
  statuts, stratégies, doc_types, profils, regex famille) n'existe que dans
  le fichier de **test** `tests/testthat/test-knowledge-corpus-manifest.R`,
  donc indisponible à l'exécution.

Les **règles strictes 1-3 de CLAUDE.md** interdisent à `nemetonshiny` de
réimplémenter le parsing du manifest, le garde-fou licence (D5),
l'éligibilité, la résolution des sources ou la boucle d'ingestion. Un
onglet d'administration RAG suppose donc **du code cœur** : exposer cette
orchestration comme fonctions exportées, retournant des résultats
structurés exploitables par l'UI. L'app reste de la pure présentation.

## 2. Décisions actées

| # | Décision | Choix |
|---|----------|-------|
| **D1** | Source de vérité du manifest éditable | ✅ **CSV inscriptible (copie projet)**. Le CSV packagé `inst/extdata/knowledge_corpus_v1.csv` reste le **seed** versionné en git (lecture seule en package installé). L'app travaille sur une **copie inscriptible** dans un répertoire projet, créée par recopie du seed au premier accès. |
| **D2** | Nommage des nouvelles fonctions | ✅ **Anglais snake_case**, par cohérence avec la famille RAG existante (`ingest_knowledge_document`, `retrieve_knowledge`…) qui est entièrement en anglais. Dérogation assumée à la convention NMT française (CLAUDE.md autorise de ne pas diverger d'un module existant cohérent). |
| **D3** | Périmètre des colonnes du manifest | ✅ **Les 16 colonnes actuelles** (cf. §4.1). Les colonnes additionnelles évoquées en 009.1 §6.1 (`region_scope`, `essence_scope`, `corpus_version`, `ndp_relevant`) sont **hors scope 009.2** — extension ultérieure pour éviter le scope creep. |
| **D4** | Refactor vs réécriture | ✅ **Refactor** : extraire la logique réutilisable de `data-raw/build_knowledge_corpus.R` dans `R/knowledge-corpus.R`, et laisser le script `data-raw/` comme **mince wrapper CLI** par-dessus la nouvelle API. Comportement CLI préservé. |
| **D5** | Validation à l'écriture | ✅ `write_knowledge_manifest()` **valide avant d'écrire** (refuse les erreurs bloquantes par défaut, override explicite possible) pour qu'un manifest corrompu ne soit jamais persisté. |

## 3. Périmètre cœur (`nemeton`) — API publique à créer

Nouveau fichier `R/knowledge-corpus.R` (laisse `R/rag.R` focalisé sur les
primitives). Six fonctions exportées + helpers privés extraits du script.

### 3.1 `knowledge_manifest_path()`

```r
knowledge_manifest_path(writable = FALSE)
```

Résout le chemin du manifest selon D1 :

- `writable = FALSE` → le **seed packagé** via
  `system.file("extdata", "knowledge_corpus_v1.csv", package = "nemeton")`
  (fallback `inst/extdata/...` en dev / `load_all`).
- `writable = TRUE` → la **copie projet inscriptible**, résolue depuis
  `Sys.getenv("NEMETON_KNOWLEDGE_MANIFEST")` ou, à défaut, un chemin par
  défaut sous un répertoire de données projet (ex.
  `tools::R_user_dir("nemeton", "data")/knowledge_corpus.csv` ou
  `data-raw/`). Si la copie inscriptible n'existe pas encore, elle est
  **amorcée par recopie du seed** au premier appel (idempotent).

**Retour** : `character(1)` (chemin). Documenter clairement seed vs copie.

### 3.2 `read_knowledge_manifest()`

```r
read_knowledge_manifest(path = knowledge_manifest_path())
```

Lit le CSV → `data.frame` typé `character`, normalise `NA → ""` (même
contrat que le script et le test actuels). N'effectue **pas** de
validation (séparation lecture / validation). Vérifie seulement la
présence des 16 colonnes attendues (sinon `cli::cli_abort`).

**Retour** : `data.frame` 16 colonnes.

### 3.3 `knowledge_manifest_vocab()`

```r
knowledge_manifest_vocab()
```

**Source unique de vérité** des vocabulaires contrôlés (aujourd'hui
dupliqués dans le test). Le test `test-knowledge-corpus-manifest.R` sera
refactoré pour les **consommer depuis le package** au lieu de les
redéfinir.

**Retour** : `list(licenses, statuses, strategies, langs, doc_types,
profiles, family_regex)` — directement consommable par l'app pour peupler
les listes déroulantes des cellules enum de l'éditeur.

### 3.4 `validate_knowledge_manifest()`

```r
validate_knowledge_manifest(manifest)
```

Encode **tous** les invariants aujourd'hui répartis dans le test :

- colonnes exactes (16) ;
- `doc_id` unique, non vide, slug `^[a-z0-9_]+$` ;
- `title` non vide ;
- enums : `lang`, `status`, `ingest_strategy`, `doc_type`, `license`,
  `license_commercial_ok ∈ {TRUE, FALSE}` ;
- `family_codes` reconnus (regex `^(Toutes|[BCWAFLTRSPEN][0-9]?)$`) et non
  vides ; `profile_codes` reconnus (15 profils + `tous`) et non vides ;
- **garde-fou licence (D5 de 009.1)** : une ligne `cleared` n'a jamais une
  licence vide ni le placeholder `to-confirm` ;
- **garde-fou copyright** : `license == "copyright"` ⇒ jamais
  `ingest_strategy == "full"` (lien-seul / abstract uniquement) ;
- `local_path` non vide ⇒ extension ingérable (`.pdf|.rmd|.md|.markdown|.qmd`).

**Retour** : `data.frame` d'anomalies, colonnes `row`, `doc_id`,
`severity ∈ {error, warning}`, `field`, `message`. **0 ligne ⇒ manifest
valide.** (Pas d'`abort` : l'app affiche les anomalies inline ; l'écriture
décide quoi faire des `error`.)

### 3.5 `write_knowledge_manifest()`

```r
write_knowledge_manifest(manifest,
                         path = knowledge_manifest_path(writable = TRUE),
                         validate = TRUE)
```

Valide (D5) — si `validate` et qu'il reste des anomalies `error`,
`cli::cli_abort` avec le détail. Écrit le CSV de façon **déterministe**
(ordre de colonnes stable, quoting cohérent, encodage UTF-8) pour des
diffs git propres.

**Retour** : invisible `path`.

### 3.6 `build_knowledge_corpus()`

```r
build_knowledge_corpus(con,
                       manifest          = read_knowledge_manifest(),
                       provider          = c("mistral", "openai", "voyage"),
                       include_to_confirm = FALSE,
                       fresh             = FALSE,
                       dry_run           = FALSE,
                       pdf_dir           = NULL,
                       api_key           = NULL,
                       progress          = NULL)
```

L'orchestrateur extrait du script — **fonction R bloquante pure** (pas de
`quit()`, pas de lecture d'env interne : tout passe par arguments). Reprend
verbatim la logique actuelle : `enable_rag()` (si besoin), garde-fou
licence (D5), éligibilité `cleared` (+ `to_confirm` si `include_to_confirm`),
`fresh` (purge préalable), idempotence (skip si `title` déjà en base),
résolution `full` vs `abstract_only`/`link_only`, `resolve_source` (PDF
local / téléchargement / markdown nettoyé).

- `dry_run = TRUE` → renvoie le **plan** sans connexion DB ni appel
  embedding (équivalent du `NEMETON_CORPUS_DRY_RUN` actuel).
- `progress` → callback optionnel `function(i, n, row, result)` appelé
  après chaque ligne, pour piloter une barre de progression / `ExtendedTask`
  côté app.

**Retour** : `data.frame` **bilan**, une ligne par ligne du manifest :
`doc_id`, `action ∈ {ingested, skipped, error, planned}`, `reason`,
`mode ∈ {full, abstract_only, link_only, NA}`, `n_chunks`, `document_id`,
`duration_sec`. (Remplace les `cli::cli_alert_*` du script : l'app rend ce
tableau.)

### 3.7 Helpers privés extraits du script

`./.resolve_manifest_source()`, `.clean_markdown()`, `.split_manifest_codes()`,
`.is_reference_strategy()`, logique d'éligibilité — déplacés dans
`R/knowledge-corpus.R`, testables unitairement.

### 3.8 `data-raw/build_knowledge_corpus.R` — wrapper mince

Réduit à : lire les env vars (`NEMETON_KNOWLEDGE_DB_URL`,
`NEMETON_CORPUS_PROVIDER`, `NEMETON_CORPUS_DRY_RUN`, `NEMETON_CORPUS_FRESH`,
`NEMETON_CORPUS_INGEST_TO_CONFIRM`), `db_connect()`, appeler
`build_knowledge_corpus()`, puis imprimer le bilan via `cli`. **CLI et
sémantique des variables d'environnement strictement préservées** (la
règle de sécurité « pas de fallback vers `NEMETON_DB_URL` » reste).

## 4. Manifest — rappel structure (inchangée, D3)

### 4.1 Les 16 colonnes actuelles

`doc_id`, `title`, `author`, `publisher`, `pub_date`, `lang`, `doc_type`,
`source_url`, `license`, `license_commercial_ok`, `family_codes`,
`profile_codes`, `ingest_strategy`, `local_path`, `status`, `notes`.

Aucune migration de schéma DB. Aucune colonne ajoutée/retirée.

## 5. Périmètre app (`nemetonshiny`) — pour mémoire, hors repo

Onglet « RAG » dans les paramètres, **uniquement de la présentation**,
appelant l'API §3 :

1. **Éditeur de manifest** — `read_knowledge_manifest()` → table éditable
   (DT / rhandsontable / réactif) ; cellules enum alimentées par
   `knowledge_manifest_vocab()`.
2. **Validation inline** — `validate_knowledge_manifest()` à chaque
   édition → surlignage des lignes/champs en `error`/`warning`.
3. **Enregistrer** — `write_knowledge_manifest()` (bouton « Enregistrer »),
   refus si erreurs bloquantes.
4. **Prévisualiser le plan** — `build_knowledge_corpus(con, dry_run = TRUE)`
   → tableau « ce qui sera ingéré / sauté / sans source ».
5. **Importer** — `build_knowledge_corpus(con, …, progress = )` dans une
   `ExtendedTask` (l'embedding est un appel réseau batch, donc asynchrone
   côté app) → barre de progression + tableau bilan.
6. **État de la base** — `list_knowledge_documents()` (inventaire),
   `delete_knowledge_document()` (retrait d'un document).

Aucune logique métier dans `mod_*.R` (règles 1-3). Tous les textes via
`i18n$t()` (clés FR/EN à ajouter côté `nemetonshiny`).

## 6. Tests (cœur)

- **`test-knowledge-corpus-manifest.R`** — refactoré pour consommer
  `knowledge_manifest_vocab()` et `validate_knowledge_manifest()` au lieu de
  redéfinir les vocabulaires (supprime la duplication ; le packagé devient
  l'unique source).
- **`test-knowledge-manifest-api.R`** (nouveau) :
  - `validate_knowledge_manifest()` détecte chacun des invariants
    (enum invalide, `doc_id` dupliqué/non-slug, `cleared` + `to-confirm`,
    `copyright` + `full`, extension `local_path` non ingérable, code
    famille/profil inconnu, colonne manquante) ;
  - round-trip `read → write → read` (identité, diff stable) ;
  - `knowledge_manifest_path(writable = TRUE)` amorce la copie depuis le
    seed au premier appel (via `withr::with_tempdir` + env var).
- **`test-build-corpus.R`** (nouveau, SQLite + `.embed_texts` mocké via
  `testthat::local_mocked_bindings()`) :
  - `dry_run = TRUE` → plan correct, aucun écrit DB ;
  - ingestion `full` d'un mini-manifest → bilan `ingested`, chunks créés ;
  - **idempotence** : re-run → `skipped (already ingested)` ;
  - **garde-fou licence** : ligne `to_confirm` exclue sauf
    `include_to_confirm = TRUE` ;
  - ligne `link_only`/`abstract_only` → 1 chunk de référence ;
  - `progress` callback appelé n fois.
- `devtools::check()` clean (0 ERROR / 0 WARNING / 0 NOTE nouveau).

## 7. Critères d'acceptation (cœur)

- [ ] **A1** — 6 fonctions exportées + roxygen complet en anglais.
- [ ] **A2** — `knowledge_manifest_vocab()` est l'unique source des
  vocabulaires ; le test manifest ne les duplique plus.
- [ ] **A3** — `validate_knowledge_manifest()` renvoie un `data.frame`
  d'anomalies typé ; 0 ligne sur le manifest packagé actuel
  (il passe déjà tous les tests d'intégrité).
- [ ] **A4** — `write_knowledge_manifest()` refuse un manifest avec
  erreurs bloquantes ; round-trip stable.
- [ ] **A5** — `build_knowledge_corpus()` reproduit le comportement du
  script (mêmes ingestions/skips sur le manifest packagé en `dry_run`),
  retour structuré, `progress` fonctionnel.
- [ ] **A6** — `data-raw/build_knowledge_corpus.R` réduit à un wrapper, CLI
  et env vars inchangées.
- [ ] **A7** — Couverture : ≥ 15 tests nouveaux/refactorés ; `check()` clean.

## 8. Livraison & release (consignes CLAUDE.md)

- `feat:` → bump **minor** : `0.62.0 → 0.63.0` (DESCRIPTION, NEWS.md daté,
  CITATION.cff, CHANGELOG.md le cas échéant).
- Tag annoté `v0.63.0` + release GitHub (sur demande explicite).
- `PLAN.md` : entrée datée au journal E7 + ligne « Administration corpus
  (API manifest + build) » dans la table d'avancement du chantier. Ne pas
  clore E7 (le wiring app reste).

## 9. Hors scope 009.2

- L'**onglet UI** lui-même (`nemetonshiny`, repo séparé).
- Le **wiring du retrieval** dans le prompt LLM (déjà cadré spec 009 §2.2 /
  reliquat E7).
- Les colonnes additionnelles du manifest (`region_scope`, `essence_scope`,
  `corpus_version`, `ndp_relevant`) — extension future (D3).
- Toute **édition directe en base** du corpus (D1 a tranché pour le CSV
  inscriptible ; l'option base-directe est écartée pour cette spec).
- La **gouvernance/versionnage** du corpus (`corpus_v1` → `v2`) — reste
  gérée par git sur le manifest (009.1 §9).

## 10. Validation

- [ ] Décisions §2 (D1-D5) confirmées
- [ ] API §3 approuvée (signatures, retours structurés)
- [ ] Frontière cœur/app §5 approuvée
- [ ] Plan de tests §6 approuvé
- [ ] Cible release §8 (`v0.63.0`) confirmée

**Validateur** : Pascal Obstétar
**Date validation** : _à remplir_
