# Brief détaillé — Wiring RAG « perspectives IA sourcées » (`nemetonshiny`)

**Repo cible** : `nemetonshiny` (séparé). **Repo source** : `nemeton@v0.62.0`.
**Type** : `feat:` → MINOR (app `v0.53.1` → prochaine MINOR).
**Pré-requis prod** : ✅ fait — corpus peuplé dans le PG prod (`NEMETON_DB_URL`),
19 docs / 1845 chunks, modèle unique `mistral:mistral-embed`, récupération
pgvector validée en réel.

---

## 1. Objectif

Aujourd'hui les perspectives IA par profil sont générées **sans sources**.
Ce wiring les rend **sourcées + citées** : avant l'appel LLM, on récupère
les passages de corpus les plus pertinents (`retrieve_knowledge`), on les
injecte dans le prompt, et on affiche un bloc « Sources documentaires »
(`format_citations`) sous la perspective.

**Toute la logique métier est dans le cœur** (embedding, similarité,
citations) — l'app ne fait qu'orchestrer (règles 1 & 3 de CLAUDE.md).

## 2. API cœur disponible (signatures exactes, `nemeton@v0.62.0`)

```r
retrieve_knowledge(con, query,
                   top_k = 8L,
                   family_codes = NULL,      # filtre métadonnée (intersection de tableaux)
                   profile_codes = NULL,     # filtre métadonnée
                   min_similarity = 0.7,
                   lang = NULL,
                   embed_provider = c("mistral","openai","voyage"),
                   api_key = NULL)
# -> data.frame trié par similarity desc, colonnes :
#    chunk_id, document_id, title, author, pub_date, source_url, lang,
#    chunk_index, page_number, text, similarity
#    (data.frame 0 ligne canonique si rien ne dépasse min_similarity)

format_citations(retrieved_chunks, format = c("markdown","html"), lang = "fr")
# -> bloc « Sources documentaires » (fr) / « Sources » (en). "" si 0 ligne.
#    Rend UNE entrée par LIGNE du data.frame -> dédupliquer par document avant.

embed_query(text, provider, api_key)   # bas niveau, appelé en interne
```

`enable_rag(con)`, `list_knowledge_documents(con)` existent aussi (utiles
pour un health-check au démarrage).

## 3. Architecture du flux

```
profil + UGF + indicateurs
        │
        ▼  (service_rag.R — orchestration mince)
 build_situation_summary()  ──►  query texte
        │
        ▼
 nemeton::retrieve_knowledge(con, query, profile_codes, family_codes,
                             min_similarity, embed_provider="mistral")
        │   (1 appel embedding Mistral + 1 requête pgvector ≈ 1 s)
        ├──► chunks (tous) ─────────────►  prompt_block  ──► prompt LLM (ellmer)
        └──► chunks dédupliqués/doc ────►  format_citations ──► bloc « Sources » (UI)
```

À exécuter **dans la tâche de calcul asynchrone** (`service_compute.R` /
`ExtendedTask`), pas dans le thread UI (latence réseau de l'embedding).

## 4. Fichiers à créer / modifier

### 4.1 `DESCRIPTION`
```
Imports:
    nemeton (>= 0.62.0),
    ...
```

### 4.2 `R/service_rag.R` — **nouveau** (orchestration mince)

```r
#' Résout une connexion vers la base de connaissances (corpus RAG).
#' Priorité : NEMETON_KNOWLEDGE_DB_URL (corpus dédié) ; sinon réutilise la
#' connexion applicative existante (déjà ouverte sur NEMETON_DB_URL), où le
#' corpus partagé est co-localisé avec le monitoring. Lecture seule -> sûr.
#' @return list(con, owned) — `owned=TRUE` si la connexion est à fermer par
#'   l'appelant (cas NEMETON_KNOWLEDGE_DB_URL).
rag_knowledge_con <- function(app_con = NULL) {
  url <- Sys.getenv("NEMETON_KNOWLEDGE_DB_URL", "")
  if (nzchar(url)) {
    con <- tryCatch(nemeton::db_connect(url), error = function(e) NULL)
    return(list(con = con, owned = !is.null(con)))
  }
  list(con = app_con, owned = FALSE)   # réutilise la connexion app
}

#' Construit le contexte RAG d'une perspective. TOUJOURS non-bloquant :
#' toute erreur / corpus vide / clé absente -> contexte vide, la perspective
#' est générée sans sources.
#' @param app_con connexion applicative (pool checkout) ou NULL.
#' @param profile_code code profil COURT (cf. §5.1), p.ex. "naturaliste".
#' @param family_codes vecteur de familles (cf. §5.2) — peut être NULL.
#' @param situation_text requête sémantique (cf. §5.3).
#' @return list(chunks, prompt_block, sources_md, n_sources)
rag_context <- function(app_con, profile_code, family_codes, situation_text,
                        lang = "fr", top_k = 8L, min_similarity = 0.55) {
  empty <- list(chunks = NULL, prompt_block = "", sources_md = "", n_sources = 0L)
  if (!isTRUE(getOption("nemeton.rag_enabled", TRUE))) return(empty)

  kc <- rag_knowledge_con(app_con)
  if (is.null(kc$con)) return(empty)
  on.exit(if (isTRUE(kc$owned)) try(nemeton::db_disconnect(kc$con), silent = TRUE), add = TRUE)

  chunks <- tryCatch(
    nemeton::retrieve_knowledge(
      kc$con, query = situation_text,
      top_k          = top_k,
      family_codes   = family_codes,    # NULL = pas de filtre famille (cf. §5.2)
      profile_codes  = profile_code,    # NULL accepté
      min_similarity = min_similarity,
      lang           = NULL,            # corpus FR+EN -> ne pas filtrer la langue
      embed_provider = "mistral"),      # DOIT matcher le provider d'ingestion
    error = function(e) NULL)
  if (is.null(chunks) || !nrow(chunks)) return(empty)

  # Bloc prompt : TOUS les chunks, numérotés [^n] (mêmes marqueurs que
  # format_citations -> la perspective peut citer [^1], [^2]…).
  lines <- vapply(seq_len(nrow(chunks)),
                  function(i) sprintf("[^%d] %s", i, chunks$text[i]), character(1))
  prompt_block <- paste0(
    if (lang == "fr") "## Documents de référence\n" else "## Reference documents\n",
    paste(lines, collapse = "\n\n"))

  # Bloc Sources : UNE citation par DOCUMENT (le test d'acceptation montre
  # que les top-k chunks viennent souvent du même doc -> sinon doublons).
  best_per_doc <- chunks[!duplicated(chunks$document_id), , drop = FALSE]
  sources_md <- nemeton::format_citations(best_per_doc, format = "markdown", lang = lang)

  list(chunks = chunks, prompt_block = prompt_block,
       sources_md = sources_md, n_sources = nrow(best_per_doc))
}
```

> **Pourquoi la dédup ?** `format_citations` rend une entrée par ligne. Le
> test réel a renvoyé 3 chunks tous issus de « Spec 008 » → 3 lignes de
> citation identiques. On déduplique par `document_id` pour le bloc Sources
> (mais on garde tous les chunks pour le prompt).

### 4.3 `R/llm_prompts.R` — injecter le contexte + consigne de citation

```r
ctx <- rag_context(
  app_con,
  profile_code   = rag_profile_code(profile_key),                 # §5.1
  family_codes   = NULL,                                          # §5.2 (V1 : NULL)
  situation_text = build_situation_summary(units, profile_key, lang),  # §5.3
  lang           = lang)

cite_rule <- if (!nzchar(ctx$prompt_block)) "" else if (lang == "fr")
  "Appuie-toi sur les Documents de référence ci-dessus quand ils sont pertinents et cite-les avec leurs marqueurs [^n]. N'invente jamais de source ni de numéro." else
  "Use the Reference documents above when relevant and cite them with their [^n] markers. Never invent a source or a number."

user_prompt <- paste(c(ctx$prompt_block, cite_rule, base_prompt),
                     collapse = "\n\n")
# ... appel ellmer inchangé ; renvoyer aussi ctx$sources_md / ctx$n_sources
#     au module pour l'affichage.
```

### 4.4 `R/mod_synthesis.R` — afficher le bloc « Sources »

```r
# UI
uiOutput(ns("ai_sources"))

# server (rag_ctx() = reactive portant le résultat de rag_context)
output$ai_sources <- renderUI({
  ctx <- rag_ctx()
  if (is.null(ctx) || !nzchar(ctx$sources_md)) return(NULL)
  tagList(
    tags$hr(),
    if (ctx$n_sources > 0)
      tags$p(class = "text-muted small",
             sprintf(i18n$t("rag_sourced_badge"), ctx$n_sources)),
    shiny::markdown(ctx$sources_md)   # format_citations gère déjà le titre i18n
  )
})
```

### 4.5 `R/utils_i18n.R` — clés (FR/EN)

| clé | FR | EN |
|---|---|---|
| `rag_sourced_badge` | Perspective appuyée sur %d source(s) documentaire(s) | Perspective backed by %d documentary source(s) |
| `rag_toggle_label` | Inclure les sources documentaires | Include documentary sources |

(Le titre du bloc — « Sources documentaires » — vient du cœur via
`format_citations(lang=)`, ne pas le redéfinir.)

## 5. Détails de mise en œuvre

### 5.1 Mapping profil app → code profil corpus
Le manifest tague les docs avec des **codes courts** (sans préfixe
`profil_`) : `proprietaire_prive`, `proprietaire_public`,
`gestionnaire_onf`, `gestionnaire_coop`, `gestionnaire_expert`,
`technicien`, `naturaliste`, `elu_local`, `elu_regional`, `chasseur`,
`industrie_bois`, `bucheron`, `chercheur`, `citoyen`, `investisseur`.
Si tes clés app sont `profil_naturaliste`, écris
`rag_profile_code <- function(k) sub("^profil_", "", k)`.

### 5.2 Filtre familles — **attention au piège des sous-codes**
`retrieve_knowledge(family_codes=)` filtre par **intersection exacte de
tableaux** : `"R"` matche un doc tagué `"R"` mais **pas** un doc tagué
seulement `"R5"`. Le manifest mélange lettres (`"R"`, `"C"`) et sous-codes
(`"R5"`, `"C1"`). **Recommandation V1 (corpus 19 docs)** : passer
`family_codes = NULL` (pas de filtre famille) et s'appuyer sur la
similarité sémantique + `profile_codes`. Sur-filtrer un petit corpus
renvoie souvent 0 résultat. Quand le corpus grossit, réintroduire un
filtre famille en **incluant lettre ET sous-codes** (`c("R","R5")`).

### 5.3 Requête sémantique `build_situation_summary()`
Phrase courte et concrète = meilleure récupération. Composer :
profil (en clair) + familles saillantes + 2-3 faits marquants (score
global, alerte R5/dépérissement, essence dominante, risque feu…). Ex. :
« Perspective pour un naturaliste. Forêt d'épicéas avec dépérissement
détecté (R5 élevé), faible naturalité, zone humide à proximité. »
Le LLM reçoit ensuite ce résumé + les chunks ; la requête sert à
**l'embedding**, pas à l'affichage.

### 5.4 Provider d'embedding
**Doit être `"mistral"`** (le corpus a été ingéré avec `mistral-embed`).
Le cœur avertit si le corpus mélange des providers ; ne pas changer sans
réembedder. Clé résolue côté cœur via `MISTRAL_API_KEY` (déjà dans le
`.Renviron` de l'app).

### 5.5 Réglages par défaut conseillés
`top_k = 8`, `min_similarity = 0.55` (le test réel donnait ~0.87 pour un
doc pertinent ; 0.55 garde une marge sans bruit). `family_codes = NULL`
(cf. 5.2). Exposer éventuellement un `getOption("nemeton.rag_top_k")`.

### 5.6 Connexion & santé
- En prod le corpus est dans `NEMETON_DB_URL` → `rag_context()` réutilise
  la connexion app (pas de `NEMETON_KNOWLEDGE_DB_URL` à définir).
- Health-check optionnel au démarrage : `nrow(list_knowledge_documents(con))`
  ; si 0 → logguer « corpus vide, perspectives non sourcées » et continuer.

### 5.7 Dégradation gracieuse — **impératif**
Tous ces cas → contexte vide, **perspective générée sans sources, aucune
exception UI** : RAG désactivé (`option`), pas de connexion, schéma
`knowledge_*` absent, corpus vide, clé Mistral absente, erreur réseau
embedding, 0 chunk au-dessus du seuil. `rag_context()` encapsule déjà tout
en `tryCatch`.

## 6. Tests (`tests/testthat/`)

- **`testServer(mod_synthesis)`** : mocker `nemeton::retrieve_knowledge`
  pour renvoyer un data.frame → le bloc `ai_sources` est rendu ; le prompt
  passé à ellmer contient `## Documents de référence` et `[^1]`.
- **Dégradation** : mock renvoyant 0 ligne **et** mock levant une erreur →
  pas de bloc Sources, **aucune exception**, perspective produite.
- **Unitaire `rag_context()`** : dédup par `document_id` (2 chunks même doc
  → 1 citation), `prompt_block` numéroté `[^n]`, `n_sources` correct.
- **Mapping** `rag_profile_code("profil_naturaliste") == "naturaliste"`.
- Mocker via `testthat::local_mocked_bindings(retrieve_knowledge = …,
  .package = "nemeton")` (les fonctions sont dans le namespace `nemeton`).

## 7. Release
- `feat:` MINOR. NEWS/CHANGELOG : « Perspectives IA sourcées : récupération
  RAG (`nemeton::retrieve_knowledge`) + bloc Sources (`format_citations`),
  non-bloquant, opt-out via `options(nemeton.rag_enabled=FALSE)`. »
- `Imports: nemeton (>= 0.62.0)`.

## 8. Pas de breaking change
Entièrement additif et dégradant : corpus absent / clé manquante / RAG
désactivé ⇒ comportement actuel inchangé (perspective sans sources).

## 9. Checklist d'acceptation
- [ ] Perspective d'un profil affiche un bloc « Sources documentaires »
      avec ≥1 citation cliquable quand le corpus a du contenu pertinent.
- [ ] Couper le réseau / vider le corpus / `options(nemeton.rag_enabled=FALSE)`
      → perspective toujours générée, sans bloc Sources, sans erreur.
- [ ] Pas de citations en double pour un même document.
- [ ] Le prompt envoyé au LLM contient les chunks `[^n]` et la consigne de
      citation.
- [ ] `Imports: nemeton (>= 0.62.0)` ; textes via `i18n$t()`.
```
