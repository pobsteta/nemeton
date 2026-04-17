# Tâches d'Implémentation : Produits globaux pré-calculés

**Version** : 0.1.0
**Date** : 2026-04-17
**Spec** : `spec.md` v0.2.0 · **Plan** : `plan.md`
**Cible** : nemeton v0.17.0 (phases 1-4)
**Total estimé** : 71 tâches (58 pour v0.17.0 + 13 v0.17.1)
**Progression** : 0/71

Conventions identiques à spec 005 :
- `[P]` = parallélisable avec les autres tâches `[P]` de la même section
- IDs : `T{phase}.{n}` (ex. T1.3 = phase 1, tâche 3)
- Réfs fichier : `path:line` quand connue, `path` sinon

Pré-requis : **spec 005 mergée** (v0.16.0) pour consommer `sanitize_chm()`, `compute_site_index()`, flag `augmented`.

---

## Phase 1 — Infra fetch + cache + datasources

Branche : `feat/006-phase1-remote-infra`
**Strictement bloquante** pour les phases 2-6.

### 1.1 Cache cross-OS

- [ ] T1.1 Créer `R/remote_cache.R` avec roxygen header et imports
- [ ] T1.2 `get_cache_dir()` — hiérarchie option R → env var → `rappdirs::user_cache_dir("nemeton")`
- [ ] T1.3 [P] `ensure_cache_dir(source)` crée le sous-dossier et initialise `index.duckdb` si absent
- [ ] T1.4 [P] Schéma DuckDB : `source, key, path, fetched_at, checksum, size_bytes` + index sur `(source, key)`
- [ ] T1.5 `cache_get(source, key)` — retourne le path si présent et checksum valide, NULL sinon
- [ ] T1.6 `cache_put(source, key, path)` — copie vers cache_dir, calcule checksum, insère dans index
- [ ] T1.7 `clean_remote_cache(max_age_days = 180, max_size_gb = 20)` — purge LRU + limite taille
- [ ] T1.8 `get_cache_info()` — stats par source (nb fichiers, taille, âge médian)
- [ ] T1.9 Documentation roxygen complète avec exemples

### 1.2 Helpers géographiques

- [ ] T1.10 [P] `aoi_in_france_metro(aoi)` — bbox vs polygon France métropolitaine simplifié (~50 sommets)
- [ ] T1.11 [P] `aoi_in_dom_tom(aoi)` — Guyane / Antilles / Réunion / Mayotte / NC / PF
- [ ] T1.12 [P] `aoi_in_europe(aoi)` — bbox européenne large
- [ ] T1.13 Ajouter une fixture `inst/extdata/geo_regions.gpkg` avec polygones simplifiés
- [ ] T1.14 Tests `test-geo-regions.R` : AOI Paris → FR metro, AOI Cayenne → DOM-TOM, AOI Berlin → Europe

### 1.3 fetch_remote_raster — dispatch par access

- [ ] T1.15 Créer `R/remote_data.R` avec roxygen header
- [ ] T1.16 `fetch_remote_raster(source, aoi, crs = NULL, cache = TRUE, force = FALSE, ...)` — signature publique
- [ ] T1.17 Lookup `get_data_source(source)`, extraire le champ `access`
- [ ] T1.18 Dispatch vers `fetch_via_gdal_vsis3()` si `access = "gdal_vsis3"`
- [ ] T1.19 Dispatch vers `fetch_via_rstac_signed()` si `access = "rstac_signed"`
- [ ] T1.20 Dispatch vers `fetch_via_httr2_download()` si `access = "httr2_download"`
- [ ] T1.21 Calcul `aoi_hash = digest(aoi)` pour clé de cache
- [ ] T1.22 Check cache avant fetch si `cache = TRUE && !force`
- [ ] T1.23 Après fetch, `cache_put()` + reprojection vers `crs` si fourni
- [ ] T1.24 Retour : `SpatRaster` avec attribut `source_info = list(source, access, url, fetched_at)`

### 1.4 Backend GDAL `/vsis3/`

- [ ] T1.25 `fetch_via_gdal_vsis3(source_info, aoi, ...)` — setEnv `AWS_NO_SIGN_REQUEST=YES` si `anonymous = TRUE`
- [ ] T1.26 Calcul bbox de l'AOI → rasterExt + marge optionnelle
- [ ] T1.27 `terra::rast(url)` + `terra::crop(., bbox)` — lecture par fenêtre COG
- [ ] T1.28 Gestion erreur : retry 3× avec backoff exponentiel si timeout
- [ ] T1.29 Test : retry après 2 erreurs 503 puis succès (mock)

### 1.5 Backend STAC (rstac)

- [ ] T1.30 Vérification runtime `requireNamespace("rstac")` avec message actionnable
- [ ] T1.31 `fetch_via_rstac_signed(source_info, aoi, date_start = NULL, date_end = NULL)` 
- [ ] T1.32 Construction requête STAC : collection + bbox + datetime
- [ ] T1.33 `rstac::items_sign(items)` pour signer les URLs Planetary Computer
- [ ] T1.34 Lecture asset via `terra::rast()` sur URL signée
- [ ] T1.35 Si plusieurs items → composite médian (ou autre selon paramètre)

### 1.6 Backend HTTPS (httr2)

- [ ] T1.36 Vérification runtime `requireNamespace("httr2")` avec message actionnable
- [ ] T1.37 `fetch_via_httr2_download(source_info, aoi, ...)` — identification tuiles à partir de AOI + schéma source
- [ ] T1.38 Téléchargement avec `httr2::req_perform()` + progress bar CLI
- [ ] T1.39 Assemblage multi-tuiles via `terra::merge()` si AOI traverse plusieurs tuiles

### 1.7 auto_select_chm_source

- [ ] T1.40 `auto_select_chm_source(aoi, prefer_resolution = TRUE)` — logique selon spec §11.1
- [ ] T1.41 Retourne `list(source = ..., reason = ...)` pour traçabilité
- [ ] T1.42 Helper `has_opencanopy_cache_for_aoi(aoi)` — check des CHM `opencanopy` déjà produits

### 1.8 datasources.R enrichi

- [ ] T1.43 Ajouter entrée `canopy_height_meta` (cf. spec §5.1, avec `access = "gdal_vsis3"`)
- [ ] T1.44 Ajouter entrée `landcover_worldcover`
- [ ] T1.45 Ajouter entrée `landcover_dynamic_world` (access `rstac_signed`)
- [ ] T1.46 Ajouter entrée `canopy_height_potapov` (access `httr2_download`)
- [ ] T1.47 Ajouter champ `access` sur toutes les sources existantes pour cohérence

### 1.9 Dependencies et NOTICE

- [ ] T1.48 `DESCRIPTION` : ajouter `rstac` et `httr2` en Suggests
- [ ] T1.49 Vérifier `rappdirs` en Suggests ; si absent, l'ajouter
- [ ] T1.50 Mettre à jour `inst/NOTICE` : 4 nouvelles attributions (Meta/WRI, ESA WorldCover, Dynamic World, Potapov)
- [ ] T1.51 Clarifier mention Maxar : CHM dérivé OK, imagerie Maxar interdite de redistribution

### 1.10 Tests

- [ ] T1.52 Créer `tests/testthat/fixtures/remote/` avec COG réduits (~1 Mo) pour Meta/WRI, WorldCover, Potapov
- [ ] T1.53 `tests/testthat/helpers/fixture_remote.R` : helper `use_local_fixture(source)` qui redirige l'endpoint vers file://
- [ ] T1.54 `test-remote-cache.R` : 15 tests — hiérarchie config, cache hit/miss, checksum, purge, corruption
- [ ] T1.55 `test-remote-data.R` : 12 tests — dispatch access, fetch offline via fixtures, runtime check des Suggests
- [ ] T1.56 `test-geo-regions.R` : 8 tests — appartenance AOI à FR metro / DOM-TOM / Europe / monde
- [ ] T1.57 Tous les tests réseau marqués `skip_on_cran()` + `skip_if_offline()`
- [ ] T1.58 Vérifier couverture `remote_cache.R` + `remote_data.R` ≥ 85 %

### 1.11 Closure phase 1

- [ ] T1.59 Mettre à jour `NEWS.md` : « Infrastructure for remote data sources (phase 1 of spec 006) »
- [ ] T1.60 PR `feat/006-phase1-remote-infra` → `main`
- [ ] T1.61 R CMD check 0/0/max 1 note avant merge
- [ ] T1.62 Merger ; pas de tag intermédiaire (phase non user-facing)

---

## Phase 2 — Meta/WRI CHM

Branche : `feat/006-phase2-meta-chm`
Dépend de : **phase 1 + spec 005 mergées**.

### 2.1 Helper prepare_chm_for_aoi

- [ ] T2.1 Dans `R/remote_data.R`, ajouter `prepare_chm_for_aoi(aoi, source = "auto", sanitize = TRUE, ...)`
- [ ] T2.2 Si `source = "auto"` → appelle `auto_select_chm_source(aoi)`
- [ ] T2.3 Appelle `fetch_remote_raster(source, aoi)`
- [ ] T2.4 Si `sanitize = TRUE` → appelle `sanitize_chm()` (de spec 005)
- [ ] T2.5 Retourne `list(chm, source_used, pct_masked, sanitize_steps)`
- [ ] T2.6 Tests sur fixture Meta/WRI locale

### 2.2 Intégration dans nemeton_compute

- [ ] T2.7 Lire `R/nemeton-class.R::nemeton_compute()` et identifier où `layers$chm` est consommé
- [ ] T2.8 Ajouter support de `layers$chm_source = "auto" | "opencanopy" | "canopy_height_meta"` en plus du chemin direct
- [ ] T2.9 Si `chm_source` fourni sans `chm` explicite → appelle `prepare_chm_for_aoi()` automatiquement
- [ ] T2.10 Métadonnées : `attr(result, "chm_source_chosen") <- ...`

### 2.3 Tests P1/P2/C1/B2/R2 avec Meta/WRI

- [ ] T2.11 `tests/testthat/test-chm-meta.R` — fixture AOI en Guyane (synthétique)
- [ ] T2.12 [P] Test P1 : volume cohérent avec CHM Meta
- [ ] T2.13 [P] Test P2 : indice de station via `compute_site_index()` alimenté par CHM Meta
- [ ] T2.14 [P] Test C1 : biomasse mode H-based avec CHM Meta
- [ ] T2.15 [P] Test B2 : cv_chm composante avec CHM Meta
- [ ] T2.16 [P] Test R2 : vulnérabilité tempête avec CHM Meta
- [ ] T2.17 Test auto-select : AOI France métro → opencanopy, AOI Guyane → Meta/WRI

### 2.4 Vignette

- [ ] T2.18 Créer `vignettes/remote-data-sources_fr.Rmd`
- [ ] T2.19 Section 1 : vue d'ensemble des 4 produits
- [ ] T2.20 Section 2 : configuration cache
- [ ] T2.21 Section 3 : workflow AOI Guyane → Meta/WRI → indicateurs P1/P2
- [ ] T2.22 Section 4 : workflow AOI France → auto-select opencanopy (mentionner fallback Meta si opencanopy absent)
- [ ] T2.23 Section 5 : recommandations par zone géographique

### 2.5 Closure phase 2

- [ ] T2.24 `NEWS.md` : bloc « Meta/WRI CHM integration — CHM available worldwide »
- [ ] T2.25 pkgdown : ajouter `fetch_remote_raster`, `prepare_chm_for_aoi`, `auto_select_chm_source`, `cross_validate_chm` (préparation phase 6)
- [ ] T2.26 PR `feat/006-phase2-meta-chm` → `main`

---

## Phase 3 — ESA WorldCover → A1, L1, L2, B3

Branche : `feat/006-phase3-worldcover`
Dépend de : phase 1 mergée.

### 3.1 Table de correspondance classes

- [ ] T3.1 Documenter dans `inst/extdata/worldcover_classes.csv` : 11 classes ESA (code, nom FR, nom EN, correspondance OSO/BD Forêt quand existe)
- [ ] T3.2 Helper interne `worldcover_is_forest(raster, value = 10)` — masque booléen tree cover

### 3.2 Modifications indicateurs

- [ ] T3.3 [P] `indicator_air_coverage()` : ajouter paramètre `source = c("local", "worldcover")`
- [ ] T3.4 [P] `indicator_landscape_fragmentation()` : ajouter branche worldcover
- [ ] T3.5 [P] `indicator_landscape_edge()` : ajouter branche worldcover
- [ ] T3.6 [P] `indicator_biodiversity_connectivity()` : ajouter branche worldcover pour continuité forestière

### 3.3 Tests

- [ ] T3.7 `test-indicators-worldcover.R` — fixture WorldCover locale
- [ ] T3.8 Test A1 : corrélation avec mode OSO > 0.7 sur massif_demo
- [ ] T3.9 Test L1 : patches détectés correctement sur AOI à cheval sur 2 tuiles WC
- [ ] T3.10 Test B3 : continuité cohérente

### 3.4 Closure phase 3

- [ ] T3.11 Vignette `remote-data-sources_fr.Rmd` : ajouter section « Occupation du sol mondiale avec WorldCover »
- [ ] T3.12 `NEWS.md` bloc phase 3
- [ ] T3.13 PR `feat/006-phase3-worldcover` → `main`

---

## Phase 4 — Dynamic World → T2

Branche : `feat/006-phase4-dynamic-world`
Dépend de : phase 1 mergée.

### 4.1 fetch_dynamic_world

- [ ] T4.1 `fetch_dynamic_world(aoi, date_start, date_end, composite = c("median", "latest", "mode"))` dans `R/remote_data.R`
- [ ] T4.2 Construction requête STAC Planetary Computer `io-lulc-annual-v02`
- [ ] T4.3 Signed URLs via `rstac::items_sign(items, sign_fn = rstac::sign_planetary_computer())`
- [ ] T4.4 Composite médian pixel-wise sur la période
- [ ] T4.5 Masquage nuages via asset `probability_nodata`
- [ ] T4.6 Tests sur fixture DW locale

### 4.2 indicator_temporal_change

- [ ] T4.7 Lire `indicator_temporal_change()` actuel
- [ ] T4.8 Ajouter branche `source = "dynamic_world"` avec paramètres temporels
- [ ] T4.9 Calcul changement : classe majoritaire période 1 vs période 2
- [ ] T4.10 Retour : % changement + raster de changement par classe

### 4.3 Tests

- [ ] T4.11 `test-indicators-dynamic-world.R` — fixture DW pré/post
- [ ] T4.12 Test T2 : détection d'un changement simulé (fixture avec 20% de classes différentes)
- [ ] T4.13 Test runtime check : message clair si `rstac` absent

### 4.4 Closure phase 4

- [ ] T4.14 Vignette section « Détection de changement continue avec Dynamic World »
- [ ] T4.15 Doc : explication rate limit Planetary Computer
- [ ] T4.16 `NEWS.md` bloc phase 4
- [ ] T4.17 PR `feat/006-phase4-dynamic-world` → `main`

---

## Closure v0.17.0 (critique)

- [ ] T0.1 R CMD check : 0 error / 0 warning sur l'ensemble
- [ ] T0.2 Couverture globale ≥ 92 % (tolérance -2 points par rapport à baseline)
- [ ] T0.3 Vignette `remote-data-sources_fr.Rmd` build sans warning en offline (fixtures)
- [ ] T0.4 Tous les tests réseau passent en CI avec réseau, skippent sans
- [ ] T0.5 Mettre à jour `CLAUDE.md` : section « Sources de données distantes »
- [ ] T0.6 Mettre à jour `README.md` : section « NDP 0 mondial » avec 5 lignes d'exemple
- [ ] T0.7 Régénérer pkgdown
- [ ] T0.8 Démo reproductible : AOI Guyane → Meta/WRI → P1/P2, sans installation Python
- [ ] T0.9 Tag `v0.17.0` ; release notes depuis NEWS.md
- [ ] T0.10 GitHub release + annonce

---

## Post-MVP (v0.17.1)

### Phase 5 — Potapov 30 m fallback

- [ ] T5.1 Implémenter `fetch_via_httr2_download` pour Potapov (tuiles 10° × 10°)
- [ ] T5.2 Endpoint GLAD/UMD, parser de nommage des tuiles
- [ ] T5.3 Test fixture Potapov locale
- [ ] T5.4 `auto_select_chm_source()` : fallback tertiaire vers Potapov si Meta/WRI indisponible (mock 503)
- [ ] T5.5 Warning utilisateur quand Potapov sélectionné (résolution dégradée)
- [ ] T5.6 Vignette section Potapov
- [ ] T5.7 `NEWS.md` + PR

### Phase 6 — cross_validate_chm diagnostic

- [ ] T6.1 `cross_validate_chm(chm_a, chm_b, method = c("absolute", "relative"))` dans `R/utils-chm.R`
- [ ] T6.2 Reprojection automatique si CRS différents
- [ ] T6.3 Aligne les grids avec `terra::resample()` si résolutions différentes
- [ ] T6.4 Retour : `list(mean_abs_diff, rmse, pixelwise_diff, agreement_pct, agreement_raster)`
- [ ] T6.5 Tests `test-cross-validate-chm.R` — rasters identiques, différents, CRS variés
- [ ] T6.6 Vignette section « Validation croisée Meta/WRI vs opencanopy »
- [ ] T6.7 PR `feat/006-phase6-cross-validate` → `main`

---

## Résumé par phase

| Phase | Tâches | Cible | Statut |
|-------|--------|-------|--------|
| 1 — Infra fetch + cache | 62 | intermédiaire | ⬜ 0/62 |
| 2 — Meta/WRI CHM | 26 | v0.17.0 | ⬜ 0/26 |
| 3 — ESA WorldCover | 13 | v0.17.0 | ⬜ 0/13 |
| 4 — Dynamic World T2 | 17 | v0.17.0 | ⬜ 0/17 |
| Closure v0.17.0 | 10 | v0.17.0 | ⬜ 0/10 |
| 5 — Potapov | 7 | v0.17.1 | ⬜ 0/7 |
| 6 — cross_validate_chm | 7 | v0.17.1 | ⬜ 0/7 |

**Chemin critique v0.17.0** : 1 → (2, 3, 4 en parallèle) → closure. Environ 10-14 jours de dev concentré si mené séquentiellement, ~7-8 jours avec parallélisation des phases 2-4.
