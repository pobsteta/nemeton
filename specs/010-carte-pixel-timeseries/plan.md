# Plan technique : Carte pixel + time series interactive

**Version** : 0.1.0 (draft, suit `spec.md` v0.1.0)
**Date**    : 2026-05-15
**Statut**  : Draft — prêt pour `tasks.md` une fois validé
**Cible**   : `nemeton` v0.22.0
**Dépend de** : `nemeton` ≥ v0.21.12 (cache S2 fonctionnel)

---

## 1. Stack technique

### 1.1 Côté cœur `nemeton` (R)

| Composant | Rôle | Déjà dans Imports ? |
|-----------|------|---------------------|
| `terra` (≥ 1.7-0) | Lecture COG, arithmétique raster, resampling, extract | ✅ |
| `sf` (≥ 1.0-0) | Transformation de CRS sur le point cliqué | ✅ |
| `cli` (≥ 3.6.0) | Warnings agrégés pour scènes manquantes | ✅ |
| `rlang` | `arg_match` pour `index = c("NDVI", "NBR")` | ✅ |

**Pas de nouvelle dépendance.** L'ensemble du code de spec 010 réutilise ce qui est déjà chargé pour l'ingestion S2.

### 1.2 Côté app `nemetonshiny` (R) — pour mémoire, hors repo

| Composant | Rôle |
|-----------|------|
| `leaflet` + `leafem::addCOG` ou `addRasterImage` | Rendu de la couche raster en EPSG:3857 |
| `plotly` | Time series superposée NDVI + NBR au clic |
| `bslib::layout_sidebar` | Plotly en panneau latéral droit dans le sous-onglet "Carte pixel" |
| `shiny::observeEvent(input$pixel_map_click)` | Capture clic leaflet → appel `nemeton::extract_pixel_timeseries()` |

### 1.3 Données

- **Source** : cache disque `<project>/cache/layers/sentinel2/{scene_id}/{band}.tif` (déjà peuplé via `ingest_sentinel2_timeseries` depuis v0.21.12)
- **Aucune table DB nouvelle**, aucune migration
- **Lecture jointe** : la liste des scènes d'une zone vient de `obs_pixel` via la requête :

```sql
SELECT DISTINCT scene_id, obs_date, source, cloud_pct
FROM obs_pixel op
JOIN plot p ON p.id = op.plot_id
WHERE p.zone_id = ?
ORDER BY obs_date;
```

Ce reader **n'est PAS** ajouté côté cœur dans cette spec — il vit naturellement dans `nemetonshiny::service_monitoring.R` (déjà ouvert sur `obs_pixel` via `nemeton::read_obs_pixel()` introduit en v0.21.11). Si une demande d'API publique remonte, on l'ajoutera dans une spec ultérieure (`list_cached_scenes(con, zone_id)` candidat).

---

## 2. Architecture de la lecture

### 2.1 Flux complet

```
                 ┌──────────────────────────────────────────┐
                 │  nemetonshiny / mod_monitoring "pixel"   │
                 │                                          │
                 │ 1. obs_pixel → scenes_df (côté app)      │
                 │ 2. cache_dir = <project>/cache/...       │
                 │ 3. stack = nemeton::build_index_stack(   │
                 │       cache_dir, scenes_df, "NDVI")      │
                 │ 4. leaflet::addCOG(stack[[selected]])    │
                 │ 5. obs_click → input$pixel_map_click     │
                 │      → nemeton::extract_pixel_timeseries │
                 │      → plotly                            │
                 └─────────────────┬────────────────────────┘
                                   │ (RPC-style appels R)
                                   ▼
                 ┌──────────────────────────────────────────┐
                 │  nemeton (cœur)                          │
                 │                                          │
                 │  build_index_stack(cache, df, index)     │
                 │   ├─ for each row of df:                 │
                 │   │   ├─ read_s2_band_raster(cache, sid, │
                 │   │   │                      "B04")      │
                 │   │   ├─ read_s2_band_raster(cache, sid, │
                 │   │   │                      "B08")      │
                 │   │   ├─ if index == "NBR":              │
                 │   │   │   read B12 + resample → 10 m     │
                 │   │   └─ compute (NDVI ou NBR)           │
                 │   ├─ skip silently if any band is NULL   │
                 │   ├─ stack via terra::rast(list_of_rast) │
                 │   └─ name layers by obs_date             │
                 │                                          │
                 │  extract_pixel_timeseries(cache, df, xy, │
                 │                           crs, indices)  │
                 │   ├─ st_transform(xy 4326 → CRS S2)      │
                 │   ├─ for each scene:                     │
                 │   │   ├─ open required bands             │
                 │   │   ├─ terra::extract(point)           │
                 │   │   └─ compute requested indices       │
                 │   └─ assemble data.frame                 │
                 └──────────────────────────────────────────┘
                                   │ (lecture disque seule)
                                   ▼
                 ┌──────────────────────────────────────────┐
                 │  cache disque                            │
                 │  cache/layers/sentinel2/                 │
                 │    {scene_id}/B04.tif (10 m)             │
                 │    {scene_id}/B08.tif (10 m)             │
                 │    {scene_id}/B12.tif (20 m)             │
                 └──────────────────────────────────────────┘
```

### 2.2 Invariants

- **Aucun trafic HTTP**. Tout est local. Si un fichier manque, `read_s2_band_raster` retourne `NULL`, jamais d'erreur.
- **CRS conservé**. Le SpatRaster sort en CRS natif S2 (UTM, typiquement EPSG:32631 ou 32632 pour la France). Reprojection vers Web Mercator (EPSG:3857) est responsabilité de `leaflet`/`leafem` côté app.
- **Pas de cache mémoire dans le cœur**. Chaque appel à `build_index_stack` re-ouvre les COGs. Le caller (Shiny reactive) est responsable de la mémoïsation. Ce choix garde le cœur stateless et facile à tester.
- **Le buffer de placettes (E6.b phase 3) reste indépendant**. La vue per-pixel ne change rien à `obs_pixel` ni à `read_obs_pixel()`.

---

## 3. Détail d'implémentation

### 3.1 `read_s2_band_raster(cache_dir, scene_id, band)`

```r
read_s2_band_raster <- function(cache_dir, scene_id, band) {
  if (!is.character(cache_dir) || length(cache_dir) != 1L)
    stop("`cache_dir` must be a single character path.", call. = FALSE)
  if (!is.character(scene_id) || length(scene_id) != 1L)
    stop("`scene_id` must be a single character.", call. = FALSE)
  band <- rlang::arg_match(band, c("B04", "B08", "B12"))

  safe_id <- gsub("[^A-Za-z0-9._-]", "_", scene_id)   # même règle que
                                                        # .s2_band_cache_path
  path <- file.path(cache_dir, safe_id, paste0(band, ".tif"))
  if (!file.exists(path)) return(NULL)
  terra::rast(path)
}
```

**Couplage** : utilise la même fonction de sanitization `gsub("[^A-Za-z0-9._-]", "_", …)` que le helper privé `.s2_band_cache_path()` (R/monitoring.R:604). Pour garantir le couplage, on **extrait cette logique en helper interne partagé** (`.s2_safe_scene_id()`) — c'est un petit refactor de R/monitoring.R, sans modif de comportement.

### 3.2 `read_s2_band_stack(cache_dir, scenes_df, band)`

```r
read_s2_band_stack <- function(cache_dir, scenes_df, band) {
  # Validation
  if (!is.data.frame(scenes_df) ||
      !all(c("scene_id", "obs_date") %in% names(scenes_df)))
    stop("`scenes_df` must have columns `scene_id`, `obs_date`.",
         call. = FALSE)
  band <- rlang::arg_match(band, c("B04", "B08", "B12"))

  scenes_df <- scenes_df[order(scenes_df$obs_date), ]

  # Lecture, skip silencieux
  rasters <- lapply(seq_len(nrow(scenes_df)), function(i) {
    read_s2_band_raster(cache_dir, scenes_df$scene_id[i], band)
  })
  ok <- !vapply(rasters, is.null, logical(1))

  n_skipped <- sum(!ok)
  if (n_skipped > 0L) {
    cli::cli_warn(c(
      "Skipped {n_skipped}/{nrow(scenes_df)} scene{?s} (no cached {.field {band}}).",
      i = "Run {.fn ingest_sentinel2_timeseries} to refill the cache."
    ))
  }
  if (!any(ok)) return(NULL)

  out <- terra::rast(rasters[ok])
  names(out) <- as.character(scenes_df$obs_date[ok])
  terra::time(out) <- scenes_df$obs_date[ok]
  out
}
```

**Tolérance aux trous** : si **toutes** les scènes manquent, retour `NULL` (cas dégénéré, l'app affichera un état vide). Sinon, on émet **un seul** warning agrégé (jamais N warnings).

### 3.3 `build_index_stack(cache_dir, scenes_df, index)`

```r
build_index_stack <- function(cache_dir, scenes_df, index = c("NDVI", "NBR")) {
  index <- rlang::arg_match(index)
  # Validation comme §3.2 …

  bands_needed <- switch(index,
    NDVI = c("B04", "B08"),
    NBR  = c("B08", "B12")
  )

  scenes_df <- scenes_df[order(scenes_df$obs_date), ]

  layers <- lapply(seq_len(nrow(scenes_df)), function(i) {
    sid <- scenes_df$scene_id[i]
    rs <- lapply(bands_needed, function(b) read_s2_band_raster(cache_dir, sid, b))
    if (any(vapply(rs, is.null, logical(1)))) return(NULL)
    names(rs) <- bands_needed

    if (index == "NDVI") {
      (rs$B08 - rs$B04) / (rs$B08 + rs$B04)
    } else { # NBR
      # Resample B12 (20 m) onto B08 (10 m) — same idiom as .extract_scene_obs
      b12_10m <- terra::resample(rs$B12, rs$B08, method = "bilinear")
      (rs$B08 - b12_10m) / (rs$B08 + b12_10m)
    }
  })

  ok <- !vapply(layers, is.null, logical(1))
  n_skipped <- sum(!ok)
  if (n_skipped > 0L) {
    cli::cli_warn(c(
      "Skipped {n_skipped}/{nrow(scenes_df)} scene{?s} (incomplete cache for {.field {index}}).",
      i = "Check {.fn diagnose_s2_cache} for empty scene dirs."
    ))
  }
  if (!any(ok)) return(NULL)

  out <- terra::rast(layers[ok])
  names(out) <- as.character(scenes_df$obs_date[ok])
  terra::time(out) <- scenes_df$obs_date[ok]
  # Conserver l'indice et les dates en attributs pour debug / introspection
  attr(out, "index") <- index
  out
}
```

**Plafonnage des valeurs** : pas nécessaire — les indices `(a-b)/(a+b)` sont mathématiquement dans `[-1, 1]` quand a, b ≥ 0 (réflectances S2 toujours ≥ 0). Aucun `clamp()` requis.

### 3.4 `extract_pixel_timeseries(cache_dir, scenes_df, xy, crs, indices)`

```r
extract_pixel_timeseries <- function(cache_dir, scenes_df, xy,
                                     crs = 4326,
                                     indices = c("NDVI", "NBR")) {
  if (!is.numeric(xy) || length(xy) != 2L)
    stop("`xy` must be numeric(2).", call. = FALSE)
  indices <- rlang::arg_match(indices, c("NDVI", "NBR"), multiple = TRUE)
  if (length(indices) == 0L) indices <- c("NDVI", "NBR")

  scenes_df <- scenes_df[order(scenes_df$obs_date), ]

  # Construction du point sf une seule fois en CRS d'entrée
  pt_in <- sf::st_sfc(sf::st_point(xy), crs = crs)

  rows <- lapply(seq_len(nrow(scenes_df)), function(i) {
    sid <- scenes_df$scene_id[i]
    needed <- unique(unlist(lapply(indices, function(idx)
      if (idx == "NDVI") c("B04", "B08") else c("B08", "B12"))))
    rs <- setNames(
      lapply(needed, function(b) read_s2_band_raster(cache_dir, sid, b)),
      needed
    )
    if (any(vapply(rs, is.null, logical(1)))) {
      # Scène incomplète : retour NA pour tous les indices
      return(data.frame(
        obs_date = rep(scenes_df$obs_date[i], length(indices)),
        index    = indices,
        value    = NA_real_,
        stringsAsFactors = FALSE
      ))
    }
    # Transform pt vers le CRS du raster
    pt_native <- sf::st_transform(pt_in, terra::crs(rs[[1]]))
    pt_vect   <- terra::vect(pt_native)

    vals <- vapply(indices, function(idx) {
      if (idx == "NDVI") {
        b04 <- terra::extract(rs$B04, pt_vect)[1, 2]
        b08 <- terra::extract(rs$B08, pt_vect)[1, 2]
        (b08 - b04) / (b08 + b04)
      } else {
        b08 <- terra::extract(rs$B08, pt_vect)[1, 2]
        b12 <- terra::extract(rs$B12, pt_vect)[1, 2]   # natif 20 m,
        # pas besoin de resample pour un point unique
        (b08 - b12) / (b08 + b12)
      }
    }, numeric(1))

    data.frame(
      obs_date = rep(scenes_df$obs_date[i], length(indices)),
      index    = indices,
      value    = as.numeric(vals),
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  out[order(out$obs_date, out$index), ]
}
```

**Subtilité B12 vs B08** : pour un point unique, le resampling de B12 n'est pas nécessaire — `terra::extract(B12_20m, point)` renvoie la valeur du pixel 20 m qui contient le point. C'est ce que veut l'utilisateur (le pixel B12 sous le clic). Différence avec `build_index_stack` qui retourne un RASTER complet et doit donc aligner B12 sur la grille 10 m.

**Conséquence** : la valeur NBR d'`extract_pixel_timeseries(xy)` peut très légèrement différer de la valeur NBR au même point lue depuis `build_index_stack(...)` — différence sub-pixelaire due au resampling bilinéaire. C'est documenté en §4.4 de la spec et en roxygen.

---

## 4. Refactor préparatoire — `.s2_safe_scene_id()`

Avant l'ajout des 4 nouvelles fonctions, **un petit refactor** :

- **Avant** : la sanitization `gsub("[^A-Za-z0-9._-]", "_", as.character(scene_id))` est inlinée dans `.s2_band_cache_path()` (R/monitoring.R:604).
- **Après** : extraction en helper privé `.s2_safe_scene_id(scene_id)` réutilisé par `.s2_band_cache_path()` ET les 4 nouvelles fonctions exportées.

Bénéfice : couplage de contrat garanti — si on change la règle de sanitization un jour, on la change à un seul endroit. Sans ça, le risque est qu'un futur `scene_id` exotique (avec un caractère sanitisé d'un côté et pas de l'autre) crée un mismatch silencieux entre l'écriture cache et la lecture par `read_s2_band_raster()`.

**Tests à mettre à jour** : si un test existant teste le path sanitization en inline, il faut le porter sur le helper exporté. À auditer.

---

## 5. Performance attendue

### 5.1 Mesures de référence (à confirmer en bench)

Sur la machine de référence (`/home/pascal/dev/nemeton`, AOI 5 km², 26 scènes 2025-2026 — config typique de l'utilisateur) :

| Opération | Cible | Notes |
|-----------|-------|-------|
| `read_s2_band_raster` | < 10 ms | ouverture COG terra (lazy) |
| `read_s2_band_stack` (26 scènes, 1 bande) | < 300 ms | terra::rast(list) sur 26 fichiers |
| `build_index_stack` (26 scènes, NDVI) | < 1 s | arithmétique terra en RAM, ~270×500×26 = 3.5 M cellules |
| `build_index_stack` (26 scènes, NBR) | < 1.5 s | + resample B12 (cible : 26 × 20 ms) |
| `extract_pixel_timeseries` (26 scènes, NDVI+NBR) | < 500 ms | 26 × 4 extract = 104 point lookups |
| Premier render carte (cold cache) | < 2 s | build + leaflet/leafem render |
| Slider de date (warm cache) | < 200 ms | swap de layer terra, déjà en RAM |
| Clic pixel (warm cache) | < 500 ms | extract + plotly init |

### 5.2 Mémoire

- AOI 5 km² × 100 scènes × 1 indice → ~270 × 500 × 100 doubles ≈ 100 MB stack en RAM
- AOI 10 km² × 100 scènes → ~400 MB (tenable mais commence à pousser sur les serveurs Shiny basique)
- **Limite douce documentée** : 10 km² × 100 scènes. Au-delà, recommander à l'utilisateur de filtrer la fenêtre temporelle dans le slider (l'app passe alors un `scenes_df` filtré au build).

### 5.3 Optimisations envisagées (hors v1)

- **Parallélisation** via `furrr::future_map` sur `lapply(seq_len(nrow(scenes_df)), …)`. ROI faible (lectures locales déjà rapides). Hors scope.
- **Pré-export multi-bande COG** (spec 010.4) — utile si > 200 scènes ou > 10 km².
- **Cache mémoïsé côté app** via `shiny::bindCache()` sur le reactive du stack. Côté nemetonshiny, hors scope cœur.

---

## 6. Découpage en chantiers livrables

| # | Chantier | Livrables | Effort estimé |
|---|----------|-----------|---------------|
| **T1** | Refactor `.s2_safe_scene_id` | Helper privé extrait, `.s2_band_cache_path` mis à jour, tests existants verts | < 30 min |
| **T2** | `read_s2_band_raster()` + tests | R/pixel-map.R (nouveau fichier), 3-4 tests offline | ~1 h |
| **T3** | `read_s2_band_stack()` + tests | Idem + 4 tests (ordering, skip, attribut time, NULL si tout absent) | ~1 h |
| **T4** | `build_index_stack()` + tests | NDVI + NBR + 6 tests (formule, resample B12, NA propagation, skip incomplet) | ~2 h |
| **T5** | `extract_pixel_timeseries()` + tests | + 5 tests (CRS transform, multi-indices, NA pixel, point hors AOI) | ~2 h |
| **T6** | Export NAMESPACE + roxygen complets | `@export`, `@examples`, `@seealso`, génération doc | ~30 min |
| **T7** | Bench + ajustements perf | Script `data-raw/bench-pixel-map.R`, mesure sur AOI test | ~1 h |
| **T8** | Release v0.22.0 | DESCRIPTION + NEWS + PLAN + tag + GitHub release | ~30 min |

**Total estimé** : ~8 h de travail, livrable en une session (séquence linéaire, pas de blocage inter-chantier).

**Pas de chantier côté app dans ce repo.** L'intégration `mod_monitoring` (sous-onglet "Carte pixel") est suivie indépendamment dans le PLAN.md de `nemetonshiny`.

---

## 7. Dépendances et risques

### 7.1 Dépendances externes

| Dépendance | Version min | Disponibilité | Risque |
|------------|-------------|---------------|--------|
| `terra::rast(filepath)` | 1.7-0 | déjà Imports | nul |
| `terra::resample(method = "bilinear")` | 1.7-0 | idem | nul |
| `terra::extract(rast, vect)` | 1.7-0 | idem | nul |
| `sf::st_transform` | 1.0-0 | déjà Imports | nul |
| Cache disque peuplé | — | conditionné à v0.21.12 et à un run réel d'ingestion | géré par le NULL-return policy |

### 7.2 Risques identifiés (extension de spec §7)

| Risque | Détection | Mitigation |
|--------|-----------|------------|
| Helper `.s2_safe_scene_id` cassé pendant le refactor T1 | Tests existants `.s2_band_cache_path` rouges | Lancer la suite avant de toucher au reste |
| `terra::resample` rate sur certaines CRS atypiques | Test sur AOI à cheval sur UTM (rare) | Hors scope v1, documenter |
| Memory blow-up si scenes_df très long (e.g. 500 scènes) | Bench T7 | Documenter la limite douce 10 km² × 100 scènes |
| Click hors emprise du raster | Test T5 | `terra::extract` retourne NA → propagé en NA dans le data.frame, OK |
| Reprojection point 4326 → UTM pour AOI à cheval sur deux UTM | Test multi-tile | Hors scope v1 (cas non-cible) |
| `terra::time()` perd la time series après opérations dérivées | Test stack | Setter via `terra::time(out) <- dates` après chaque assemblage |

---

## 8. Plan de tests

### 8.1 Tests offline (`test-pixel-map.R`)

Couverture minimale, **15 tests** :

| # | Test | Cible |
|---|------|-------|
| 1 | `read_s2_band_raster` retourne SpatRaster sur fichier valide | A1 |
| 2 | `read_s2_band_raster` retourne NULL si fichier absent | A2 |
| 3 | `read_s2_band_raster` rejette `band` invalide | input validation |
| 4 | `read_s2_band_stack` ordonne par obs_date | A3 |
| 5 | `read_s2_band_stack` skip scènes manquantes + 1 warning | A4 |
| 6 | `read_s2_band_stack` retourne NULL si toutes scènes manquent | edge case |
| 7 | `read_s2_band_stack` pose `terra::time()` correctement | invariant |
| 8 | `build_index_stack("NDVI")` formule correcte | A5 |
| 9 | `build_index_stack("NBR")` resample B12 à la grille B08 | A6 |
| 10 | `build_index_stack` propage NA si B04 a NA au même pixel | NA propagation |
| 11 | `build_index_stack` skip silencieusement scène incomplète (e.g. B04 manquant) | tolérance |
| 12 | `extract_pixel_timeseries` transform 4326 → UTM correct | A7 |
| 13 | `extract_pixel_timeseries` multi-indices retourne data.frame trié | format |
| 14 | `extract_pixel_timeseries` point hors AOI retourne NAs | edge case |
| 15 | `extract_pixel_timeseries` scène incomplète → NAs pour cette date | tolérance |

### 8.2 Fixtures

Création d'une fixture minimale dans `helper-pixel-map.R` :

```r
# Génère un cache S2 synthétique avec 3 scènes, 3 bandes, sur l'AOI test.
make_fixture_s2_cache <- function(dir, scenes = 3, with_b12 = TRUE) {
  for (i in seq_len(scenes)) {
    sid <- sprintf("S2_FIX_%03d", i)
    scene_dir <- file.path(dir, sid)
    dir.create(scene_dir, recursive = TRUE)
    for (b in c("B04", "B08", if (with_b12) "B12")) {
      res <- if (b == "B12") 20 else 10
      r <- terra::rast(nrows = 30, ncols = 30,
                       xmin = 644000, xmax = 644000 + 30 * res,
                       ymin = 5235000, ymax = 5235000 + 30 * res,
                       crs = "EPSG:32631",
                       vals = runif(900, 0.05, 0.5))
      terra::writeRaster(r, file.path(scene_dir, paste0(b, ".tif")),
                         filetype = "GTiff", overwrite = TRUE)
    }
  }
  invisible(dir)
}
```

**Avantages** :
- Pas de dépendance réseau / PC SAS token
- Fixtures rapides (< 1 s pour 3 scènes)
- Permet de simuler scènes incomplètes en supprimant des `.tif` (test 11, 15)

### 8.3 Tests d'intégration (non-cœur, pour mémoire)

Hors scope cœur. Côté nemetonshiny, un smoke `shinytest2` validerait que :
- Le sous-onglet "Carte pixel" boote sans erreur
- Le slider de date change le layer affiché
- Un clic simulé via `AppDriver` ouvre le plotly

---

## 9. Critères d'acceptation v0.22.0

| # | Critère | Vérification |
|---|---------|--------------|
| 1 | DESCRIPTION = `Version: 0.22.0` | grep |
| 2 | NEWS.md a une section `# nemeton 0.22.0` | grep |
| 3 | PLAN.md (racine) mentionne v0.22.0 + spec 010 | grep |
| 4 | NAMESPACE exporte 4 nouvelles fonctions | grep |
| 5 | `devtools::check()` clean | run |
| 6 | `devtools::test()` passe (15 nouveaux + régression sur existants) | run |
| 7 | Tag git annoté `v0.22.0` poussé | gh release view |
| 8 | GitHub release créée avec auto-notes | gh release view |
| 9 | `man/*.Rd` régénérés | `devtools::document()` |
| 10 | Tests cœur ≥ 6020 PASS / 0 FAIL (vs 6015 baseline post-v0.21.12) | sortie testthat |

---

## 10. Hors-scope final / dette technique

- **Pas de `list_cached_scenes(con, zone_id)` exporté** dans cette spec. Si l'app a besoin du SQL `SELECT DISTINCT scene_id, obs_date FROM obs_pixel JOIN plot …`, elle peut le faire via `read_obs_pixel()` puis `unique(df[, c("scene_id", "obs_date")])` (légèrement gaspilleur mais zéro nouvelle API). Si la demande remonte, spec 010.6.
- **Pas de `compute_pixel_anomaly_score(...)`** (calcul d'un z-score par pixel basé sur la médiane historique). Possible spec 010.7 si l'utilisation par-pixel devient stable.
- **Pas de `export_index_stack_as_cog(...)`** (export du stack vers un COG multi-bande sur disque). Justifié seulement si perf live insuffisante — sera traité en spec 010.4 le cas échéant.

---

## 11. Validation

Prêt à passer à `tasks.md` une fois validé :

- [ ] Stack technique (§1) validé
- [ ] Architecture (§2) validée
- [ ] Détail d'implémentation (§3) validé
- [ ] Refactor `.s2_safe_scene_id` (§4) validé
- [ ] Budget perf (§5) validé
- [ ] Découpage T1-T8 (§6) validé
- [ ] Plan de tests (§8) validé
- [ ] Critères d'acceptation (§9) validés

**Validateur** : Pascal Obstétar
**Date validation** : _à remplir_
