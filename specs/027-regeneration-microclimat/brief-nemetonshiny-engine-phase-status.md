# Brief `nemetonshiny` — Message de phase en cours du moteur reGénération (bas-droite)

**Cœur requis** : `nemeton (>= 0.144.0)` — ajoute l'événement de phase
`regen_expo:pai` (`source = "lidar"|"raster"`) à `regen_sensibilite()`, en plus
des `regen_expo:microclimf` / `:era5` / `:complete` et `regen_biljou:start` /
`:complete` déjà émis (v0.142.0). **Correctif purement app** (`service_regeneration.R`
+ `mod_regeneration.R` + ~8 clés i18n). Pas de nouvelle dépendance.

**Demande** (usage réel) : au lancement du **moteur réel**, afficher **en bas à
droite** un message de la **phase en cours** (grille → PAI → microclimf étés
moyens → microclimf canicule → exposition → BILJOU), plutôt qu'une notif
indéterminée « moteur en cours… » figée plusieurs minutes.

Ce brief **lève la réserve** posée au §5 de `brief-nemetonshiny-engine-feedback.md`
(« Pas de progression pas-à-pas… exigerait un canal fichier + poll — hors
périmètre »). Le canal est ici spécifié.

---

## 0. Rappel de l'obstacle (et pourquoi un fichier d'état)

`run_regeneration_engine()` tourne dans un **worker `future`** (`engine_task`,
`ExtendedTask` + `future_promise`). Les événements `progress_callback`
(`on_prog`) se produisent **dans le worker** : ils ne peuvent pas écrire un
`reactiveVal` de la session principale. `engine_task$status()` ne donne que
`running / success / error`. Le worker pousse déjà vers **ntfy** (effet de bord
réseau) — mais ntfy est externe, pas la notif in-app.

**Solution** (déjà éprouvée pour E-OBS dans ce module : `invalidateLater(1000)`) :
le worker **écrit la phase courante dans un fichier**
`<project>/cache/regeneration/engine_status.json`, la session principale le
**poll** chaque seconde et rend la phase dans la notif persistante bas-droite.
Le worker et le module connaissent tous deux `project_path` → chemin partagé,
zéro dépendance.

---

## 1. Modèle de phases (6 + états terminaux)

| # | Phase (clé JSON `phase`) | Source | Libellé i18n |
|---|---|---|---|
| 1 | `grille` | app, au démarrage du worker | « Préparation grille LiDAR HD… » |
| 2 | `pai` | cœur `regen_expo:pai` (`source`) | « Structure de végétation (PAI {source})… » |
| 3 | `microclimf_moyenne` | cœur `regen_expo:microclimf`/`:era5` (cat. moyenne) | « Microclimat — étés moyens {year} ({i}/{n})… » |
| 4 | `microclimf_canicule` | cœur idem (cat. canicule) | « Microclimat — étés canicule {year} ({i}/{n})… » |
| 5 | `exposition` | cœur `regen_expo:complete` | « Agrégation de l'exposition… » |
| 6 | `biljou` | cœur `regen_biljou:start`/`:complete` | « Bilan hydrique du sol (BILJOU)… » |
| — | `microclimf_skipped` | app (branche sautée) | « Exposition microclimf ignorée : {reason} » |
| — | `done` | app, en fin de worker | (notif retirée) |

> **Phase sautée = information de premier plan.** Sur le projet RECONFORT
> diagnostiqué, microclimf ne démarre pas (pas de clé CDS au run, ou pas de
> structure de végétation) : `pai_depuis_nuage()` n'est jamais appelé, aucun
> `microclimf/` n'est créé, et `sensibilite.gpkg` reste absent. Le bandeau doit
> alors afficher **`microclimf_skipped`** (BILJOU en SAFRAN peut, lui, réussir),
> et non rester bloqué sur une phase antérieure.

Format du fichier (une ligne, réécrit à chaque phase) :

```json
{"phase":"microclimf_moyenne","year":2019,"i":2,"n":5,"source":null,"ts":1751990400}
```

`ts` = epoch (pour détecter un fichier périmé). Champs `year`/`i`/`n`/`source`
optionnels selon la phase.

---

## 2. Côté worker — écrire `engine_status.json` (`service_regeneration.R`)

`on_prog` (aujourd'hui l. ~469-484) mappe déjà les événements cœur → ntfy.
**Ajouter** l'écriture du fichier d'état à côté du push (ne pas remplacer ntfy).

### 2.1 Helper d'écriture (module-local, worker-safe)

```r
# Écrit atomiquement la phase courante dans engine_status.json (worker future).
# `now` est fourni par l'appelant (le worker n'a pas de Sys.time() interdit ici,
# mais on centralise pour tester). Jamais fatal.
.regen_write_phase <- function(out_dir, phase, extra = list()) {
  tryCatch({
    payload <- c(list(phase = phase, ts = as.integer(Sys.time())), extra)
    tmp <- file.path(out_dir, ".engine_status.json.tmp")
    fin <- file.path(out_dir, "engine_status.json")
    writeLines(jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null"), tmp)
    file.rename(tmp, fin)   # rename atomique -> pas de lecture partielle côté poll
  }, error = function(e) invisible(NULL))
}
```

`jsonlite` est déjà dans les `Imports` de `nemetonshiny`. Écriture via
`tmp`+`rename` pour que le poll ne lise jamais un JSON tronqué.

### 2.2 Brancher dans `on_prog`

`out_dir` (= `file.path(project_path, "cache", "regeneration")`) est déjà
défini en tête de `run_regeneration_engine()`. Étendre la closure :

```r
on_prog <- function(p) {
  cur <- p$current %||% ""
  # (a) fichier d'état pour la notif in-app
  switch(cur,
    "regen_expo:pai" =
      .regen_write_phase(out_dir, "pai", list(source = p$source %||% NA)),
    "regen_expo:microclimf" =
      .regen_write_phase(out_dir, paste0("microclimf_", p$category)),
    "regen_expo:era5" =
      .regen_write_phase(out_dir, paste0("microclimf_", p$category),
                         list(year = p$year, i = p$i, n = p$n)),
    "regen_expo:complete" = .regen_write_phase(out_dir, "exposition"),
    "regen_biljou:start"  = .regen_write_phase(out_dir, "biljou",
                                               list(n = p$n)),
    "regen_biljou:complete" = .regen_write_phase(out_dir, "biljou"),
    NULL)
  # (b) push ntfy existant (inchangé) …
  ...
}
```

### 2.3 États d'app (hors emit cœur) — écrire directement

- **Au tout début** de `run_regeneration_engine()`, après création de `out_dir` :
  ```r
  .regen_write_phase(out_dir, "grille")
  ```
- **Branche microclimf sautée.** Quand le bloc microclimf ne s'exécute pas OU
  quand `veg_args` est vide (pas de `las_dir` + repli LAI en échec), écrire la
  raison avant de passer à BILJOU :
  ```r
  # (branche `if (!is.null(grid) && regen_cds_credentials_ready())` fausse,
  #  ou `length(veg_args) == 0`)
  .regen_write_phase(out_dir, "microclimf_skipped",
                     list(reason = i18n$t("regen_phase_skip_reason_cds")))  # ou _structure
  ```
- **En fin de worker**, avant `return(list(...))` :
  ```r
  .regen_write_phase(out_dir, "done")
  ```

> Ne PAS supprimer le fichier dans le worker à la fin : c'est le module qui le
> nettoie (§3.3), pour éviter une course où le poll lit après `done`.

---

## 3. Côté module — poll + rendu bas-droite (`mod_regeneration.R`)

### 3.1 Lecture (helper module-local)

```r
# Lit engine_status.json ; NULL si absent/illisible/périmé (> 2 min sans MAJ).
.regen_read_phase <- function(project_path) {
  if (is.null(project_path)) return(NULL)
  f <- file.path(project_path, "cache", "regeneration", "engine_status.json")
  if (!file.exists(f)) return(NULL)
  st <- tryCatch(jsonlite::fromJSON(f), error = function(e) NULL)
  if (is.null(st) || is.null(st$phase)) return(NULL)
  if (!is.null(st$ts) && as.integer(Sys.time()) - st$ts > 120L) return(NULL)
  st
}
```

### 3.2 Libellé i18n d'une phase

```r
.regen_phase_label <- function(i18n, st) {
  switch(st$phase %||% "",
    "grille"     = i18n$t("regen_phase_grille"),
    "pai"        = sprintf(i18n$t("regen_phase_pai"),
                           i18n$t(if (identical(st$source, "lidar"))
                                    "regen_phase_pai_lidar" else "regen_phase_pai_raster")),
    "microclimf_moyenne"  = .regen_micro_lbl(i18n, "regen_phase_micro_moy", st),
    "microclimf_canicule" = .regen_micro_lbl(i18n, "regen_phase_micro_can", st),
    "exposition" = i18n$t("regen_phase_exposition"),
    "biljou"     = i18n$t("regen_phase_biljou"),
    "microclimf_skipped" = sprintf(i18n$t("regen_phase_micro_skip"),
                                   st$reason %||% ""),
    "done"       = "",
    "")
}
# « … {year} ({i}/{n}) » seulement si l'événement era5 a fourni l'année.
.regen_micro_lbl <- function(i18n, key, st) {
  base <- i18n$t(key)
  if (!is.null(st$year) && !is.null(st$i) && !is.null(st$n))
    sprintf("%s %s (%d/%d)", base, st$year, as.integer(st$i), as.integer(st$n))
  else base
}
```

### 3.3 Rendu — refléter la phase dans la notif persistante bas-droite

Le module a déjà (cf. brief engine-feedback §3/§3bis) : la notif persistante
`engine_notif` (`duration = NULL`, posée à l'invoke, retirée en fin) et le pattern
`invalidateLater(1000)`. **Rafraîchir la notif** sur le tick avec le libellé de
phase, en réutilisant le **même `id`** (Shiny remplace le contenu en place) :

```r
shiny::observe({
  if (!isTRUE(rv$engine_running)) return()
  shiny::invalidateLater(1000)
  project_path <- tryCatch(app_state$current_project$path, error = function(e) NULL)
  st  <- .regen_read_phase(project_path)
  lbl <- if (is.null(st)) i18n$t("regen_engine_running") else .regen_phase_label(i18n, st)
  if (!nzchar(lbl)) lbl <- i18n$t("regen_engine_running")   # done / illisible
  shiny::showNotification(
    htmltools::span(
      bsicons::bs_icon("hourglass-split", class = "me-1"), lbl, " — ",
      htmltools::tags$span(class = "font-monospace", .fmt_elapsed(rv$engine_start))),
    id = session$ns("engine_notif"), type = "message", duration = NULL)
})
```

`.fmt_elapsed()` = helper chrono déjà introduit par le brief engine-feedback
§3bis.2. On peut aussi refléter la phase sous le bouton (`output$engine_status`)
— optionnel, la notif bas-droite est le siège demandé.

### 3.4 Nettoyage du fichier

Dans `observeEvent(engine_task$status(), …)`, branches `success` **et** `error`
(là où `removeNotification(session$ns("engine_notif"))` est déjà appelé) :

```r
project_path <- tryCatch(app_state$current_project$path, error = function(e) NULL)
if (!is.null(project_path))
  unlink(file.path(project_path, "cache", "regeneration", "engine_status.json"))
```

Et **à l'invoke** (avant `engine_task$invoke(...)`), supprimer un fichier périmé
d'un run précédent pour ne pas afficher une phase fantôme au démarrage.

---

## 4. i18n (`utils_i18n.R`, FR/EN)

| Clé | FR | EN |
|---|---|---|
| `regen_phase_grille` | « Préparation grille LiDAR HD… » | "Preparing LiDAR-HD grid…" |
| `regen_phase_pai` | « Structure de végétation (PAI %s)… » | "Vegetation structure (PAI %s)…" |
| `regen_phase_pai_lidar` | « LiDAR » | "LiDAR" |
| `regen_phase_pai_raster` | « satellite » | "satellite" |
| `regen_phase_micro_moy` | « Microclimat — étés moyens » | "Microclimate — average summers" |
| `regen_phase_micro_can` | « Microclimat — étés canicule » | "Microclimate — heatwave summers" |
| `regen_phase_exposition` | « Agrégation de l'exposition… » | "Aggregating exposure…" |
| `regen_phase_biljou` | « Bilan hydrique du sol (BILJOU)… » | "Soil water balance (BILJOU)…" |
| `regen_phase_micro_skip` | « Exposition microclimf ignorée : %s » | "microclimf exposure skipped: %s" |
| `regen_phase_skip_reason_cds` | « clé CDS/ERA5 absente » | "no CDS/ERA5 key" |
| `regen_phase_skip_reason_structure` | « structure de végétation manquante » | "missing vegetation structure" |

La clé longue `regen_engine_running` (fallback avant la 1re phase / après `done`)
reste inchangée.

---

## 5. Ce qu'on ne fait PAS

- **Pas de barre 0-100 %** : les phases ne sont pas de durées comparables (ERA5
  domine). Un libellé de phase + un chrono est le bon niveau. Le sous-compteur
  `{i}/{n}` d'ERA5 donne déjà une granularité par année.
- **Pas de canal socket/DB** : le fichier JSON polling à 1 s suffit (le run dure
  des minutes), reste cohérent avec le pattern E-OBS du module, et survit à un
  worker qui meurt (dernière phase lisible).
- **Pas de mois-par-mois (mcera5) ni point-par-point (BILJOU)** : internes aux
  paquets amont, hors portée (déjà acté dans le brief cœur des callbacks).

---

## 6. Test app (smoke)

- Lancer le moteur (projet + prérequis OK) : la notif bas-droite **change de
  libellé** au fil des phases (grille → PAI → microclimat étés moyens `year (i/n)`
  → canicule → exposition → BILJOU), chrono qui ticke ; à la fin la notif
  disparaît et `engine_status.json` est supprimé.
- Cas microclimf sauté (retirer la clé CDS) : la notif affiche **« Exposition
  microclimf ignorée : clé CDS/ERA5 absente »** puis passe à BILJOU (SAFRAN) —
  pas de blocage sur une phase antérieure.
- Deux runs successifs : au 2ᵉ invoke, aucune phase fantôme du 1er run (fichier
  périmé supprimé à l'invoke).

---

## 7. Résumé des points de retouche

| Fichier | Retouche |
|---|---|
| `service_regeneration.R` | helper `.regen_write_phase()` ; écriture dans `on_prog` (5 clés cœur → phases) ; `grille` au démarrage, `microclimf_skipped` sur branche sautée, `done` en fin |
| `mod_regeneration.R` | helpers `.regen_read_phase()` / `.regen_phase_label()` / `.regen_micro_lbl()` ; `observe(invalidateLater)` rafraîchissant `engine_notif` avec la phase + chrono ; `unlink()` du fichier à l'invoke et en success/error |
| `utils_i18n.R` | 11 clés `regen_phase_*` FR/EN |
| DESCRIPTION | `Imports: nemeton (>= 0.144.0)` (jsonlite/bslib déjà présents) |

> **Dépend de** `brief-nemetonshiny-engine-feedback.md` (notif persistante `id`,
> `.fmt_elapsed`, `invalidateLater`) — appliquer d'abord si ce n'est pas fait.
