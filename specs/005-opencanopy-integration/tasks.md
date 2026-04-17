# Tâches d'Implémentation : Intégration Open-Canopy

**Version** : 0.1.0
**Date** : 2026-04-17
**Spec** : `spec.md` v0.2.0 · **Plan** : `plan.md`
**Cible** : nemeton v0.16.0 (phases 1-4)
**Total estimé** : 76 tâches (54 pour v0.16.0 + 22 post-MVP)
**Progression** : 0/76

Conventions :
- `[P]` = parallélisable avec les autres tâches `[P]` de la même section
- Les IDs suivent le pattern `T{phase}.{n}` (ex. T1.3 = phase 1, tâche 3)
- Réfs fichier : `path:line` quand la ligne est connue, `path` sinon

---

## Phase 1 — Tuyauterie cœur + ADR-011 amendé

Branche : `feat/005-phase1-tuyauterie`

### 1.1 ADR-011 amendement (platform_nemeton)

- [ ] T1.1 Ouvrir un PR dans `platform_nemeton` amendant ADR-011 : section « Augmentation ML » avec flag vectoriel `augmented`
- [ ] T1.2 Documenter que la confiance φ Fibonacci **reste inchangée** au niveau global ; la granularité par-indicateur passe par `compute_general_index_mixed()`
- [ ] T1.3 Lister les flags reconnus : `"height_ml"`, `"species_ml"`, `"texture_ml"` + règle d'extension
- [ ] T1.4 Merger le PR platform_nemeton avant de commencer T1.6 (l'ADR doit être la référence officielle)

### 1.2 Détection NDP augmentée

- [ ] T1.5 Lire `R/ndp.R::detect_ndp()` et identifier tous les appelants (grep repo + `nemetonShiny`)
- [ ] T1.6 Refactor `detect_ndp()` : retourne `list(level, confidence, augmented, sources)` au lieu d'un simple entier
- [ ] T1.7 Accesseur de commodité : `get_ndp_augmented(ndp_result)` exporté
- [ ] T1.8 [P] Adapter les appelants actuels de `detect_ndp()` pour accepter la nouvelle structure (rétrocompatible : accès `$level`)
- [ ] T1.9 [P] Logique de détection : si `attr(units, "chm_source") == "opencanopy"` alors `augmented <- c(augmented, "height_ml")`
- [ ] T1.10 Doc roxygen FR/EN + exemples

### 1.3 Abstraction source de données

- [ ] T1.11 Enrichir `R/datasources.R` avec entrée `chm_opencanopy` (cf. spec §4.1) : type, format COG, CRS, bornes, provenance, licence
- [ ] T1.12 Ajouter champs `license` (structure imbriquée `bd_ortho` + `open_canopy` + `derived`) sur les autres sources pour cohérence
- [ ] T1.13 Fonction `get_data_source("chm_opencanopy")` retourne les métadonnées
- [ ] T1.14 Test `test-datasources.R` : nouvelle source listée, champs obligatoires présents

### 1.4 sanitize_chm + helpers

- [ ] T1.15 Créer `R/utils-chm.R` avec squelette + roxygen header
- [ ] T1.16 Implémenter `sanitize_chm(chm, forest_mask, buildings, water, ndvi, max_height = 50, slope = NULL, ndvi_threshold = 0.3)` — 5 étapes séquentielles
- [ ] T1.17 Étape 1 : masque forêt (obligatoire si fourni) — `chm[!forest_mask] <- NA`
- [ ] T1.18 Étape 2 : masque bâti + eau — utiliser `sf::st_intersects()` ou rasterisation
- [ ] T1.19 Étape 3 : seuillage NDVI (si NDVI fourni) — `chm[ndvi < ndvi_threshold] <- NA`
- [ ] T1.20 Étape 4 : bornes plausibles — `chm[chm > max_height | chm < 0] <- NA`
- [ ] T1.21 Étape 5 : cohérence pente (si pente fournie) — `chm[slope > 60] <- NA`
- [ ] T1.22 Calculer `pct_masked = 1 - (n_valid_after / n_valid_before)` et émettre `cli::cli_warn()` si > 0.5
- [ ] T1.23 Retour : `list(chm_clean, pct_masked, steps_applied)` où `steps_applied` est le vecteur des étapes effectivement exécutées
- [ ] T1.24 Doc roxygen complète avec 2 exemples (avec/sans NDVI)

### 1.5 Fixture CHM synthétique

- [ ] T1.25 Créer `tests/testthat/helpers/fixture_chm.R` avec `make_fixture_chm(size_m = 200, res_m = 1.5, seed = 42)`
- [ ] T1.26 Le raster doit être COG — `terra::writeRaster(..., filetype = "COG")` + validation `gdalinfo` dans un test
- [ ] T1.27 CRS fixé à EPSG:2154, valeurs ~ mélange forêt (H ∈ [5, 35]) + trous (NA) + éventuel artefact > 50 m
- [ ] T1.28 Fonction jumelle `make_fixture_masks(chm)` générant forest_mask, buildings, water pour les tests

### 1.6 Tests

- [ ] T1.29 `tests/testthat/test-ndp-augmented.R` : 10 tests minimum (structure retour, flag height_ml détecté, absent sinon, backward compat sur $level)
- [ ] T1.30 `tests/testthat/test-utils-chm.R` : 15-20 tests (chaque étape isolée + intégration, pct_masked, warning > 0.5, rétrocompat sans masques)
- [ ] T1.31 Tester la fixture elle-même : CHM COG lisible, CRS correct, bornes plausibles
- [ ] T1.32 Vérifier couverture via `covr::file_coverage()` : utils-chm.R ≥ 90 %, ndp.R ≥ 90 %

### 1.7 Licences et attributions

- [ ] T1.33 Vérifier la licence réelle d'Open-Canopy sur HF (https://huggingface.co/datasets/AI4Forest/Open-Canopy) et le repo GitHub — documenter précisément
- [ ] T1.34 Créer `inst/NOTICE` avec : attribution IGN BD ORTHO (Etalab 2.0), attribution Fogel et al. 2024, mention du CHM dérivé
- [ ] T1.35 Mettre à jour `LICENSE.md` avec mention « Third-party data attributions: see inst/NOTICE »
- [ ] T1.36 Ajouter NOTICE à `.Rbuildignore` ? Non — on veut qu'il soit installé avec le package

### 1.8 Closure phase 1

- [ ] T1.37 Mettre à jour `NEWS.md` — section dev version : « Foundation for Open-Canopy integration (ADR-011 amended) »
- [ ] T1.38 R CMD check doit être 0 error / 0 warning — rerun avant PR
- [ ] T1.39 PR `feat/005-phase1-tuyauterie` → `main`, description référence spec + plan
- [ ] T1.40 Merger ; tag intermédiaire optionnel `v0.15.2.9000`

---

## Phase 2 — P2 Indice de station

Branche : `feat/005-phase2-station`  
Dépend de : **phase 1 mergée**.

### 2.1 Courbes de station (données)

- [ ] T2.1 Vérifier la redistribuabilité de Duplat & Tran-Ha 1997 (contacter IFN si nécessaire, documenter dans commentaires)
- [ ] T2.2 Si bloquant, préparer un fallback sur Bontemps et al. (publications open-access)
- [ ] T2.3 Créer `data-raw/site_index_curves.R` — script de génération du CSV, avec références précises de chaque source par espèce
- [ ] T2.4 Saisir les courbes pour les 10 essences MVP × âges 10-150 par pas de 5 × 5 classes fertilité
- [ ] T2.5 Exporter vers `inst/extdata/site_index_curves.csv` (format : species, age, class_1..class_5)
- [ ] T2.6 Tests de sanité sur le CSV : monotonie H(âge) croissante, min/max plausibles, pas de NA inattendus, toutes espèces présentes

### 2.2 Fonction compute_site_index

- [ ] T2.7 Créer `R/site_index.R` avec imports + roxygen
- [ ] T2.8 `read_site_index_curves()` interne — lit le CSV, cache sur `.nemeton.env`
- [ ] T2.9 `compute_site_index(H_dom, age, species, reference_age = 50)` — signature vectorisée
- [ ] T2.10 Logique : lookup espèce (fallback chêne sessile pour feuillus, épicéa pour résineux), interpolation bilinéaire (H, âge) → classe de fertilité → H₀ @ reference_age
- [ ] T2.11 Gestion des NA (H ou âge manquant → NA, pas d'erreur)
- [ ] T2.12 Helper `list_site_index_species()` exporté pour introspection
- [ ] T2.13 Roxygen complète avec exemple sur chêne et épicéa

### 2.3 Indicateur P2 mode CHM

- [ ] T2.14 Lire `R/indicators-productive.R::indicator_productive_station()` actuel, identifier la signature et le contrat de sortie
- [ ] T2.15 Ajouter branche `if (!is.null(chm)) { ... }` : extraction `H_dom = extract_h_dom(chm, units)` (fonction helper dans utils-chm.R)
- [ ] T2.16 Helper `extract_h_dom(chm, units, percentile = 0.9)` dans `R/utils-chm.R` — hauteur dominante = percentile 90 des pixels par unité
- [ ] T2.17 Brancher `compute_site_index(H_dom, age, species)` dans la branche CHM
- [ ] T2.18 Conserver le comportement actuel (proxy climat × sol) si CHM absent — rétrocompatibilité

### 2.4 Tests P2

- [ ] T2.19 `tests/testthat/test-site-index.R` : 15-20 tests (monotonie, fallback, interpolation, valeurs extrêmes, NA handling, vectorisation)
- [ ] T2.20 `tests/testthat/test-indicators-productive-chm.R` : tests P2 avec CHM fixture + sans CHM (régression)
- [ ] T2.21 Test de cohérence : P2 mode CHM et P2 mode legacy doivent être corrélés (r > 0.6 sur massif_demo augmenté)

### 2.5 Vignette

- [ ] T2.22 Créer `vignettes/site-index-open-canopy_fr.Rmd` : workflow complet depuis un CHM fictif jusqu'à l'indice de station sur `massif_demo`
- [ ] T2.23 Section « limites et précautions » (RMSE ~2-3 m, importance de `sanitize_chm`, dépendance aux BD Forêt/OSO)
- [ ] T2.24 Build vignette sans warning : `devtools::build_vignettes()`

### 2.6 Closure phase 2

- [ ] T2.25 NEWS.md : bloc « New feature — P2 site index via Open-Canopy CHM »
- [ ] T2.26 pkgdown : ajouter `compute_site_index`, `list_site_index_species`, `extract_h_dom` dans `_pkgdown.yml`
- [ ] T2.27 PR `feat/005-phase2-station` → `main`

---

## Phase 3 — P1 Volume bois

Branche : `feat/005-phase3-volume`  
Dépend de : **phase 2 mergée**.

### 3.1 Coefficients allométriques V(D, H)

- [ ] T3.1 Rechercher les allométries IFN publiées (Vallet, Deleuze) pour V = f(D, H, espèce) sur les 10 essences MVP
- [ ] T3.2 Créer `data-raw/allometric_volume.R` : table avec `species, a, b, c, source, notes`
- [ ] T3.3 Stocker les coefficients dans `R/sysdata.rda` (même fichier que les coefficients biomasse existants)
- [ ] T3.4 Helper interne `get_volume_coefficients(species)` avec fallback chêne/épicéa

### 3.2 Indicateur P1 mode CHM

- [ ] T3.5 Lire `indicator_productive_volume()` actuel, documenter la branche legacy
- [ ] T3.6 Ajouter branche `if (!is.null(chm)) { ... V = a × D^b × H^c ... }`
- [ ] T3.7 Pour les unités sans données D connues, utiliser `D_proxy` depuis BD Forêt v2 (densité × âge)
- [ ] T3.8 Warning si `pct_masked > 0.3` (CHM trop dégradé pour P1 fiable)

### 3.3 Tests P1

- [ ] T3.9 Étendre `test-indicators-productive-chm.R` : scénarios P1 avec CHM sur 3 espèces (chêne, hêtre, épicéa)
- [ ] T3.10 Test RMSE : mode CHM vs mode legacy sur massif_demo, rapport dans NEWS
- [ ] T3.11 Test rétrocompatibilité : P1 sans CHM = comportement v0.15.1 identique

### 3.4 Closure phase 3

- [ ] T3.12 Documenter dans la vignette `complete-referential_fr.Rmd` le mode CHM P1
- [ ] T3.13 NEWS.md bloc phase 3
- [ ] T3.14 PR `feat/005-phase3-volume` → `main`

---

## Phase 4 — C1 biomasse, B2 structure, R2 tempête

Branche : `feat/005-phase4-connexes`  
Dépend de : **phase 3 mergée**. Tâches internes parallélisables par indicateur.

### 4.1 C1 biomasse mode H-based

- [ ] T4.1 [P] Dans `R/indicators-core.R::indicator_carbon_biomass()`, ajouter branche allométrique H-based `biomass = a × D^b × H^c` (Zianis et al. ou Vallet)
- [ ] T4.2 [P] Ajouter coefficients biomasse-H si différents des coefficients volume — sinon réutiliser
- [ ] T4.3 [P] Tests dans `test-indicators-carbon.R` : mode CHM + fallback
- [ ] T4.4 [P] Corrélation CHM-mode vs age-mode ≥ 0.5 sur massif_demo

### 4.2 B2 structure — composante CV CHM

- [ ] T4.5 [P] Dans `R/indicators-biodiversity.R::indicator_biodiversity_structure()`, ajouter paramètre `cv_chm_weight = 0.2` (configurable)
- [ ] T4.6 [P] Calculer `cv_chm = sd(chm_values, na.rm = TRUE) / mean(chm_values, na.rm = TRUE)` par unité
- [ ] T4.7 [P] Intégrer dans le score Shannon multi-strates selon le poids — doc le rationale dans roxygen
- [ ] T4.8 [P] Test `test-indicators-biodiversity.R` : mode CHM cohérent (peuplements hétérogènes → cv élevé → score B2 plus élevé)
- [ ] T4.9 [P] Analyse de sensibilité dans vignette `biodiversity-resilience_fr.Rmd` : impact du poids `cv_chm_weight`

### 4.3 R2 tempête — calibration directe H

- [ ] T4.10 [P] Dans `R/indicators-risk.R::indicator_risk_storm()`, remplacer proxy âge par `vulnerability = f(H_CHM, species, slope)` en mode CHM
- [ ] T4.11 [P] Coefficients `vulnerability` par espèce (résineux > feuillus à H égale) — source à documenter
- [ ] T4.12 [P] Tests R2 avec CHM : H élevée → score R2 élevé, cohérence avec `indicator_risk_storm()` legacy
- [ ] T4.13 [P] Pas de sur-alerte en peuplement adulte homogène (validation sur massif_demo)

### 4.4 Closure phase 4

- [ ] T4.14 Mettre à jour `biodiversity-resilience_fr.Rmd` et `complete-referential_fr.Rmd`
- [ ] T4.15 NEWS.md bloc phase 4 — mentionne les 3 indicateurs et gains constatés
- [ ] T4.16 PR `feat/005-phase4-connexes` → `main`
- [ ] T4.17 Tag `v0.16.0` une fois mergé ; release notes depuis NEWS.md

---

## Closure v0.16.0 (critique)

- [ ] T0.1 R CMD check : 0 error / 0 warning sur l'ensemble
- [ ] T0.2 Couverture globale ≥ 94 % (baseline 94.3 %)
- [ ] T0.3 Mettre à jour `CLAUDE.md` : flag `augmented`, `sanitize_chm`, `compute_site_index`, `opencanopy` comme source externe
- [ ] T0.4 Mettre à jour README.md : section « NDP augmenté » + exemple court
- [ ] T0.5 Régénérer pkgdown (`pkgdown::build_site()`) et vérifier déploiement gh-pages
- [ ] T0.6 Démo end-to-end reproductible documentée dans le README : `opencanopy::pipeline_aoi_to_chm()` → `nemeton_compute()` → P1/P2 améliorés
- [ ] T0.7 Communiquer la release v0.16.0 (GitHub release notes + éventuels canaux forestiers)

---

## Post-MVP (v0.16.1, v0.17.0)

### Phase 5 — NDVI bonus (v0.16.1)

- [ ] T5.1 Extension `indicator_carbon_ndvi()` : accepter NDVI produit par `opencanopy`
- [ ] T5.2 `indicator_air_coverage()` : mode NDVI alternatif à OSO
- [ ] T5.3 `indicator_soil_erosion()` : facteur protection `mean(NDVI)` continu au lieu de binaire
- [ ] T5.4 Tests sur chaque indicateur
- [ ] T5.5 Mise à jour NEWS.md
- [ ] T5.6 PR → main, tag v0.16.1

### Phase 6 — UI nemetonShiny (v0.17.0)

Hors repo courant, planning dans `nemetonShiny`.

- [ ] T6.1 Sélecteur source CHM dans `R/mod_home.R` : None / Open-Canopy / LiDAR HD
- [ ] T6.2 Badge « ⚡ hauteur ML » dans `R/mod_synthesis.R` à côté du badge NDP
- [ ] T6.3 Traductions FR/EN : `inst/app/i18n/*.json`
- [ ] T6.4 Intégration du flag `augmented` dans prompts LLM experts (gestionnaire, chercheur)
- [ ] T6.5 Vignette `nemetonShiny::vignette("augmented-ndp")`
- [ ] T6.6 PR dans nemetonShiny

### Phase 7 — Mosaïquage à l'échelle (v0.17.0)

- [ ] T7.1 Créer `R/chm_cache.R` : schema DuckDB pour index cache
- [ ] T7.2 `chm_cache_get(dalle_id)`, `chm_cache_put(dalle_id, path)`
- [ ] T7.3 `load_chm_for_aoi(aoi)` : assemble les dalles IGN depuis cache
- [ ] T7.4 Invalidation par checksum (regénération si ortho IGN plus récente)
- [ ] T7.5 Tests unit + integration sur cache
- [ ] T7.6 Documentation dans vignette dédiée

---

## Résumé par phase

| Phase | Tâches | Cible | Statut |
|-------|--------|-------|--------|
| 1 — Tuyauterie cœur | 40 | v0.15.2.9000 intermédiaire | ⬜ 0/40 |
| 2 — P2 station | 27 | intermédiaire | ⬜ 0/27 |
| 3 — P1 volume | 14 | intermédiaire | ⬜ 0/14 |
| 4 — C1, B2, R2 | 17 | **v0.16.0** | ⬜ 0/17 |
| Closure v0.16.0 | 7 | v0.16.0 | ⬜ 0/7 |
| 5 — NDVI | 6 | v0.16.1 | ⬜ 0/6 |
| 6 — UI Shiny | 6 | v0.17.0 (hors repo) | ⬜ 0/6 |
| 7 — Cache dalles | 6 | v0.17.0 | ⬜ 0/6 |

**Chemin critique v0.16.0** : 1 → 2 → 3 → 4 → closure, strictement séquentiel. Environ 15-20 jours de dev concentré.
