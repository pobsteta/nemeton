# Tâches d'implémentation : Carte pixel + time series interactive (spec 010)

**Version** : 0.1.0
**Date**    : 2026-05-15
**Spec**    : `spec.md` v0.1.0 · **Plan** : `plan.md` v0.1.0
**Cible**   : `nemeton` v0.22.0
**Total**   : 26 tâches (toutes cœur — chantier app suivi séparément côté `nemetonshiny`)

Conventions :
- `[P]` = parallélisable avec les autres `[P]` du même chantier (mêmes pré-requis)
- IDs : `T{chantier}.{n}` (ex. T2.3 = chantier T2, tâche 3)
- Réfs fichier : `path:line` quand connue, sinon `path`
- Statut : `[ ]` à faire, `[x]` fait, `[~]` en cours
- Effort estimé : `(S)` < 30 min, `(M)` 30 min - 1 h, `(L)` 1-2 h, `(XL)` > 2 h

---

## Vue d'ensemble

```
T1 (refactor)  ─┬─► T2 ─► T3 ─► T4 ─► T5 ─► T6 ─► T7 ─► T8
                │     ^      ^      ^      ^
                │     │      │      │      │
                └─ helper privé partagé entre T2/T3/T4/T5
```

Séquence linéaire — chaque chantier dépend du précédent (sauf T1 qui doit être committé avant T2). Pas de blocage inter-chantier hors séquence : tout est dans le cœur, pas de coordination app.

---

## Chantier T1 — Refactor préparatoire `.s2_safe_scene_id`

Branche : `feat/010-pixel-map` (toute la spec sur la même branche, le refactor en premier commit pour isolation)

### 1.1 Extraction du helper privé

- [ ] **T1.1 (S)** Lire `R/monitoring.R:602-606` (corps actuel de `.s2_band_cache_path`) pour confirmer la règle de sanitization en place
- [ ] **T1.2 (S)** Créer le helper privé `.s2_safe_scene_id(scene_id)` dans `R/monitoring.R` juste avant `.s2_band_cache_path`. Corps : `gsub("[^A-Za-z0-9._-]", "_", as.character(scene_id))`. Roxygen interne (pas d'`@export`).
- [ ] **T1.3 (S)** Refacto `.s2_band_cache_path` : remplacer le `gsub(...)` inline par un appel à `.s2_safe_scene_id(scene_id)`. Vérifier que le comportement est identique.

### 1.2 Tests existants verts

- [ ] **T1.4 (S)** Lancer la suite `test-monitoring.R` (au moins les tests touchant `.s2_band_cache_path`, `.get_s2_band_raster`, et `diagnose_s2_cache`). Doit être 100 % vert avant de passer à T2.
- [ ] **T1.5 (S)** Commit `refactor(monitoring): extract .s2_safe_scene_id helper for pixel-map sharing`. Pas de bump de version (refactor pur).

**Critères de sortie T1** :
- Helper `.s2_safe_scene_id` accessible aux 4 nouvelles fonctions de T2-T5
- Aucune régression sur la suite existante
- 1 commit isolé sur la branche

---

## Chantier T2 — `read_s2_band_raster()`

### 2.1 Implémentation

- [ ] **T2.1 (S)** Créer `R/pixel-map.R` avec header roxygen général (description du module : « Helpers for per-pixel Sentinel-2 visualization on the monitoring tab. … »)
- [ ] **T2.2 (M)** Implémenter `read_s2_band_raster(cache_dir, scene_id, band)` selon plan.md §3.1 :
  - Validation : `cache_dir` chr(1), `scene_id` chr(1), `band` ∈ {"B04", "B08", "B12"} via `rlang::arg_match()`
  - Path résolu via `.s2_safe_scene_id` + `file.path` (réutilise T1.2)
  - `file.exists()` → `terra::rast(path)` ou `NULL`
- [ ] **T2.3 (S)** Roxygen complet : `@param`, `@return` (SpatRaster ou NULL), `@examples \dontrun{}`, `@seealso` vers `ingest_sentinel2_timeseries`, `read_s2_band_stack`, `diagnose_s2_cache`. `@export`.

### 2.2 Tests

- [ ] **T2.4 (M)** Créer `tests/testthat/test-pixel-map.R` avec header + helper de fixture `make_fixture_s2_cache(dir, scenes, with_b12)` (cf. plan.md §8.2)
- [ ] **T2.5 (M)** **Test 1** : retourne SpatRaster valide sur fichier existant (fixture + assertions `terra::ncell`, `terra::nlyr`)
- [ ] **T2.6 (S)** **Test 2** : retourne NULL si fichier absent (scene_id inconnu)
- [ ] **T2.7 (S)** **Test 3** : rejette band invalide (`expect_error(...., "must be one of")`)

**Critère de sortie T2** : 3 tests verts, fonction exportée et documentée.

---

## Chantier T3 — `read_s2_band_stack()`

### 3.1 Implémentation

- [ ] **T3.1 (M)** Implémenter `read_s2_band_stack(cache_dir, scenes_df, band)` selon plan.md §3.2 :
  - Validation `scenes_df` : data.frame avec colonnes `scene_id` (chr) et `obs_date` (Date)
  - Tri par `obs_date` croissant
  - `lapply` sur les scènes → `read_s2_band_raster`
  - Skip silencieux des `NULL`, warning agrégé via `cli::cli_warn` (un seul, même si N scènes manquent)
  - Retour `NULL` si toutes les scènes manquent
  - `terra::rast(list)` + `names(out)` + `terra::time(out)` correctement posés
- [ ] **T3.2 (S)** Roxygen complet, `@export`

### 3.2 Tests (continuent dans `test-pixel-map.R`)

- [ ] **T3.3 (M)** **Test 4** : ordering — fixture avec dates dans le désordre, vérifier que `terra::time(stack)` ressort en ordre croissant
- [ ] **T3.4 (M)** **Test 5** : skip silencieux — fixture avec 3 scènes mais un scene_dir absent, vérifier 1 seul warning ET stack à N-1 layers ET `expect_warning(..., "Skipped 1/3")`
- [ ] **T3.5 (S)** **Test 6** : NULL si toutes manquent (scenes_df pointant sur des `scene_id` inexistants)
- [ ] **T3.6 (S)** **Test 7** : `terra::time(stack)` correctement posé (assertion `expect_equal(terra::time(out), expected_dates)`)

**Critère de sortie T3** : 4 nouveaux tests verts (7 cumulés).

---

## Chantier T4 — `build_index_stack()`

### 4.1 Implémentation

- [ ] **T4.1 (L)** Implémenter `build_index_stack(cache_dir, scenes_df, index = c("NDVI", "NBR"))` selon plan.md §3.3 :
  - `rlang::arg_match(index)`
  - Détermine bandes nécessaires : NDVI → B04+B08, NBR → B08+B12
  - Loop scène-par-scène : ouvre les bandes via `read_s2_band_raster`, skip si une est NULL
  - NDVI : `(B08 - B04) / (B08 + B04)`
  - NBR : `terra::resample(B12, B08, method = "bilinear")` puis `(B08 - B12r) / (B08 + B12r)`
  - Assemble stack, `names` = dates, `terra::time` = dates, `attr(out, "index") <- index`
- [ ] **T4.2 (S)** Roxygen complet, `@export`, `@seealso` vers `extract_pixel_timeseries`

### 4.2 Tests

- [ ] **T4.3 (M)** **Test 8** : NDVI — fixture 3 scènes complètes, calcul manuel sur 1 pixel pour valider la formule (`expected = (b08 - b04)/(b08 + b04)`)
- [ ] **T4.4 (M)** **Test 9** : NBR — vérifier qu'avec B12 natif 20 m le stack sort en 10 m (`terra::res(out)[1] == 10`)
- [ ] **T4.5 (M)** **Test 10** : NA propagation — fixture avec NA injecté dans B04 d'un pixel, vérifier que NDVI a NA au même pixel
- [ ] **T4.6 (M)** **Test 11** : scène incomplète — fixture avec une scène où on supprime `B12.tif` après création, demander NBR, vérifier que la scène est skippée silencieusement (+ 1 warning agrégé)

**Critère de sortie T4** : 4 nouveaux tests verts (11 cumulés).

---

## Chantier T5 — `extract_pixel_timeseries()`

### 5.1 Implémentation

- [ ] **T5.1 (XL)** Implémenter `extract_pixel_timeseries(cache_dir, scenes_df, xy, crs = 4326, indices = c("NDVI", "NBR"))` selon plan.md §3.4 :
  - Validation : `xy` numeric(2), `indices` non-vide, `arg_match` multiple
  - Tri par `obs_date`
  - Construction `pt_in <- sf::st_sfc(sf::st_point(xy), crs = crs)` UNE SEULE FOIS
  - Loop scène : détermine bandes nécessaires (union des indices), ouvre, transform du point vers CRS S2 natif via `terra::crs(rs[[1]])`, `terra::extract`, calcule indices
  - Scène incomplète → data.frame de NAs pour cette date (pas un skip — l'utilisateur veut voir le trou)
  - Pour NBR : extract directement sur B12 natif 20 m (PAS de resample, on est sur un point)
  - `do.call(rbind, …)` et tri final `(obs_date, index)`
- [ ] **T5.2 (S)** Roxygen complet, `@export`, note explicite sur la différence sub-pixelaire avec `build_index_stack`

### 5.2 Tests

- [ ] **T5.3 (M)** **Test 12** : CRS transform — fixture avec un pixel à valeur connue, fournir xy en 4326, vérifier que la valeur extraite correspond
- [ ] **T5.4 (M)** **Test 13** : multi-indices — demander `c("NDVI", "NBR")`, vérifier le format de retour (3 colonnes `obs_date`, `index`, `value`), tri stable
- [ ] **T5.5 (M)** **Test 14** : point hors AOI — xy à l'extérieur du raster, vérifier que `value` est NA pour toutes les dates
- [ ] **T5.6 (M)** **Test 15** : scène incomplète — fixture avec une scène où B08 manque, vérifier que cette `obs_date` est présente dans le retour avec `value = NA` (pas absente)

**Critère de sortie T5** : 4 nouveaux tests verts (15 cumulés).

---

## Chantier T6 — Doc + NAMESPACE

### 6.1 Génération de la doc

- [ ] **T6.1 (S)** `Rscript -e 'devtools::document()'` — régénère `man/*.Rd` pour les 4 nouvelles fonctions
- [ ] **T6.2 (S)** Vérifier `NAMESPACE` : 4 nouveaux `export(...)`. Ordre alphabétique.
- [ ] **T6.3 (S)** `R CMD Rd2pdf man/read_s2_band_raster.Rd` (optionnel, smoke visuel) — ou consulter via `?read_s2_band_raster` dans une session

### 6.2 Lien transverse

- [ ] **T6.4 (S)** Ajouter une mention de la section "Carte pixel" dans `R/zzz-package.R` ou équivalent (si présent) — sinon skip
- [ ] **T6.5 (S)** Mettre à jour le `@seealso` de `read_obs_pixel` (R/read_obs_pixel.R) pour pointer vers `extract_pixel_timeseries`

**Critère de sortie T6** : `?read_s2_band_raster` s'affiche proprement, NAMESPACE clean.

---

## Chantier T7 — Bench + perf

### 7.1 Script de bench

- [ ] **T7.1 (M)** Créer `data-raw/bench-pixel-map.R` :
  - Setup : 26 scènes synthétiques au format S2 typique (5 km² à 10 m, ~270×500)
  - Mesure `system.time()` sur les 4 fonctions
  - Comparer aux cibles plan.md §5.1
  - Sortie : tableau printé + sauvegarde dans `data-raw/bench-pixel-map-results.csv`
- [ ] **T7.2 (S)** Documenter résultats dans la spec si dérive significative (> 2× la cible)

### 7.2 Ajustements éventuels

- [ ] **T7.3 (?)** Si une cible est dépassée : profiler avec `profvis::profvis()`, identifier le bottleneck, ajuster. Sinon skip.

**Critère de sortie T7** : bench documenté, dans les budgets ou écart justifié.

---

## Chantier T8 — Release v0.22.0

### 8.1 Préparation

- [ ] **T8.1 (S)** DESCRIPTION : `Version: 0.22.0` (bump minor, justifié par 4 nouvelles fonctions exportées)
- [ ] **T8.2 (M)** NEWS.md : nouvelle section `# nemeton 0.22.0 (YYYY-MM-DD)` avec sous-sections **Added** (les 4 fonctions) et le pourquoi (extension UI pixel-map de l'onglet suivi sanitaire)
- [ ] **T8.3 (M)** PLAN.md à la racine : ajouter une ligne dans la table d'avancement walking skeleton (ou une ligne "hors-skeleton" comme pour Plan d'actions) + entrée journal datée
- [ ] **T8.4 (S)** Vérifier que CITATION.cff (s'il existe) est à jour

### 8.2 Tests + check

- [ ] **T8.5 (M)** `Rscript -e 'devtools::test()'` complet — doit être ≥ 6020 PASS / 0 FAIL (baseline post-v0.21.12 = 6015 + 15 nouveaux = 6030 espéré, marge sur tests intégration parfois skippés)
- [ ] **T8.6 (M)** `Rscript -e 'devtools::check()'` — 0 ERROR / 0 WARNING. Les NOTEs nouvelles doivent être justifiées (typiquement aucune attendue).
- [ ] **T8.7 (S)** `Rscript -e 'covr::package_coverage()'` — viser ≥ couverture baseline (pas de chute > 1%)

### 8.3 Release

- [ ] **T8.8 (S)** Commit final de la branche `feat/010-pixel-map` avec message conventional `feat(monitoring): per-pixel S2 readers and pixel time-series extraction (spec 010)`
- [ ] **T8.9 (S)** Merge sur main (PR ou FF selon préférence — historique linéaire favorisé)
- [ ] **T8.10 (S)** Tag annoté `v0.22.0` + push tag
- [ ] **T8.11 (S)** `gh release create v0.22.0 --generate-notes`
- [ ] **T8.12 (S)** Supprimer la branche `feat/010-pixel-map` (local + remote)
- [ ] **T8.13 (S)** Update spec 010 + plan 010 : section §11 validation cochée + date

**Critère de sortie T8** : release publiée, branche supprimée, working tree clean sur main.

---

## Hors scope — Côté app `nemetonshiny`

Pour mémoire (ne pas tracker ici, suivi côté repo app) :

- Nouveau sous-onglet "Carte pixel" dans `mod_monitoring`
- Slider de date + toggle NDVI/NBR
- Clic pixel → plotly via `nemeton::extract_pixel_timeseries`
- Smoke test `shinytest2` sur le sous-onglet
- i18n keys nouvelles
- Bump `nemetonshiny` minor (probable v0.28.0)
- Bump `Imports: nemeton (>= 0.22.0)` côté app

---

## Critères d'acceptation globaux (rappel spec.md §5.1)

À cocher au moment du T8 :

- [ ] A1 — `read_s2_band_raster` retourne SpatRaster valide (Test 1 — T2.5)
- [ ] A2 — `read_s2_band_raster` retourne NULL sur absent (Test 2 — T2.6)
- [ ] A3 — `read_s2_band_stack` ordonne par obs_date (Test 4 — T3.3)
- [ ] A4 — `read_s2_band_stack` skip + 1 warning agrégé (Test 5 — T3.4)
- [ ] A5 — `build_index_stack("NDVI")` ∈ [-1, 1] (Test 8 — T4.3)
- [ ] A6 — `build_index_stack("NBR")` resample B12 à 10 m (Test 9 — T4.4)
- [ ] A7 — `extract_pixel_timeseries` CRS transform correct (Test 12 — T5.3)
- [ ] A8 — Toutes les fonctions exportées + roxygen complet (T6)
- [ ] A9 — ≥ 10 tests dans test-pixel-map.R (15 prévus, T2-T5)
- [ ] A10 — `devtools::check()` clean (T8.6)

---

## Comptage des tâches

| Chantier | Tâches | Effort cumulé approx |
|----------|--------|----------------------|
| T1 — Refactor | 5 | ~30 min |
| T2 — `read_s2_band_raster` | 4 | ~1 h |
| T3 — `read_s2_band_stack` | 5 | ~1.5 h |
| T4 — `build_index_stack` | 5 | ~2.5 h |
| T5 — `extract_pixel_timeseries` | 5 | ~2.5 h |
| T6 — Doc + NAMESPACE | 5 | ~30 min |
| T7 — Bench | 3 | ~1 h |
| T8 — Release | 13 | ~1 h |
| **Total** | **26** | **~10 h** |

(Estimation revue à la hausse vs plan.md §6 — 10 h plutôt que 8 h, marge pour debug terra et ajustements de fixtures.)

---

## Convention de branche et commits

- **Branche unique** : `feat/010-pixel-map` (depuis `main` post-v0.21.12)
- **Commits granulaires** : un par chantier minimum, deux ou trois si le chantier est long (T4, T5)
- **Messages** : Conventional Commits — `refactor(monitoring): …` pour T1, `feat(monitoring): …` pour T2-T5, `docs: …` pour T6, `chore(release): …` pour T8
- **Pas de squash final** : on garde l'historique granulaire pour faciliter le bisect futur
- **Pas de force-push** : la branche est partagée même si solo (CI / collaborateurs futurs)

---

## Validation

- [ ] tasks.md relu et validé par Pascal Obstétar
- [ ] Branche `feat/010-pixel-map` créée
- [ ] T1 commencé

**Validateur** : Pascal Obstétar
**Date validation** : _à remplir_
