# Plan d'Implémentation : Intégration Open-Canopy

**Spec associée** : `spec.md` (v0.2.0, validé le 2026-04-17)
**Cible** : nemeton v0.16.0
**Statut** : Draft
**Auteur** : Pascal Obstétar (via Claude)

---

## 1. Vue d'ensemble

### 1.1 Scope technique

| Couche | Impact |
|--------|--------|
| **R/** (cœur) | 1 nouveau fichier (`utils-chm.R`), 5 fichiers modifiés |
| **inst/extdata/** | 1 nouveau CSV (courbes station) + 1 NOTICE |
| **tests/testthat/** | 4-6 nouveaux fichiers de tests |
| **vignettes/** | 1 nouvelle vignette (indice de station via Open-Canopy) |
| **data-raw/** | 1 script de génération des courbes site_index depuis sources brutes |
| **platform_nemeton** (hors repo) | Amendement ADR-011 |
| **nemetonshiny** (hors repo) | Phase 6 uniquement (badge UI) |

### 1.2 Dépendances externes

- Package R `opencanopy` : **pas de dépendance R directe** — le cœur consomme un artefact (raster COG). Le package est mentionné dans la provenance uniquement.
- Pas de nouvelle dépendance d'`Imports`/`Suggests` dans `DESCRIPTION`. Les opérations raster restent sur `terra` + `sf` déjà présents.

### 1.3 Architecture cible (fichiers impactés)

```
nemeton/
├── R/
│   ├── ndp.R                       [MODIF] detect_ndp() retourne `augmented`
│   ├── datasources.R               [MODIF] + type chm_opencanopy
│   ├── utils-chm.R                 [NEW]   sanitize_chm() + helpers
│   ├── indicators-productive.R     [MODIF] P1 + P2 (compute_site_index, branche CHM)
│   ├── indicators-core.R           [MODIF] C1 branche allométrique H-based
│   ├── indicators-biodiversity.R   [MODIF] B2 composante cv_chm
│   ├── indicators-risk.R           [MODIF] R2 calibration H-based
│   └── site_index.R                [NEW]   compute_site_index() + lecture CSV
├── inst/
│   ├── extdata/
│   │   └── site_index_curves.csv  [NEW]   Duplat & Tran-Ha, 10 essences
│   └── NOTICE                      [NEW]   attributions IGN BD ORTHO + Fogel et al.
├── data-raw/
│   └── site_index_curves.R         [NEW]   génération du CSV depuis sources brutes
├── tests/testthat/
│   ├── test-ndp-augmented.R        [NEW]   flag augmented dans detect_ndp()
│   ├── test-utils-chm.R            [NEW]   sanitize_chm, 5 étapes
│   ├── test-site-index.R           [NEW]   compute_site_index + interpolation
│   ├── test-indicators-productive-chm.R [NEW]  P1/P2 mode CHM
│   └── helpers/
│       └── fixture_chm.R           [NEW]   générateur CHM synthétique COG
├── vignettes/
│   └── site-index-open-canopy_fr.Rmd [NEW] vignette P2 via Open-Canopy
└── NEWS.md                         [MODIF]
```

---

## 2. Phases et ordonnancement

### 2.1 Dépendances entre phases

```
Phase 1 (tuyauterie + ADR-011 amendment)
   │
   ├──► Phase 2 (P2 station)   ◄── gain le plus élevé, prioritaire
   │       │
   │       └──► Phase 3 (P1 volume)
   │                │
   │                └──► Phase 4 (C1, B2, R2)
   │                         │
   │                         └──► Phase 5 (NDVI bonus, optionnel)
   │
   └──► Phase 6 (UI nemetonshiny, parallélisable avec P3-5)
              │
              └──► Phase 7 (mosaïquage à l'échelle, post-MVP)
```

Les phases 2-4 sont **séquentielles strictes** (P1 et les autres indicateurs dépendent de `sanitize_chm` et de `compute_site_index` pour certains). Phase 6 peut démarrer après Phase 2 (on a déjà un flag `augmented` à afficher). Phase 5 et 7 sont optionnelles pour v0.16.0.

### 2.2 Découpage proposé en versions

| Version | Contenu | Tag cible |
|---------|---------|-----------|
| v0.15.2.9000 → 0.16.0 | Phases 1-4 | **v0.16.0** |
| v0.16.x | Phase 5 (NDVI bonus) | v0.16.1 |
| v0.17.0 | Phase 6 (UI) + Phase 7 (cache dalles) | v0.17.0 |

### 2.3 Stratégie de branches

- Une branche par phase : `feat/005-phase1-tuyauterie`, `feat/005-phase2-station`, etc.
- PR séparés, mergés en séquence
- Pas de branch longue — chaque phase doit être mergeable indépendamment (tests verts, R CMD check propre)

---

## 3. Phase 1 — Tuyauterie cœur + ADR

**Objectif** : poser les fondations sans toucher aux indicateurs. Une fois cette phase mergée, on peut produire un CHM avec `opencanopy`, le faire ingérer par `nemeton` et afficher le bon NDP/augmented.

### 3.1 Livrables

| Fichier | Action | Contenu |
|---------|--------|---------|
| `R/ndp.R` | MODIF | `detect_ndp()` retourne une liste `list(level, confidence, augmented, sources)`. Rétrocompatibilité : les usages actuels de `detect_ndp()$level` continuent de fonctionner. |
| `R/datasources.R` | MODIF | Ajout de l'entrée `chm_opencanopy` (voir spec §4.1) |
| `R/utils-chm.R` | NEW | `sanitize_chm(chm, forest_mask, buildings, water, ndvi, max_height, slope, ndvi_threshold)` — pipeline 5 étapes + retour `list(chm_clean, pct_masked, steps_applied)` |
| `tests/testthat/helpers/fixture_chm.R` | NEW | `make_fixture_chm(size_m = 200, res_m = 1.5)` — CHM synthétique COG pour tests |
| `tests/testthat/test-ndp-augmented.R` | NEW | 8-10 tests : flag augmented détecté si `chm_source = "opencanopy"` dans attributs, absent sinon |
| `tests/testthat/test-utils-chm.R` | NEW | 15-20 tests : 5 étapes de sanitize_chm, `pct_masked`, warning seuil |
| `inst/NOTICE` | NEW | Attributions IGN BD ORTHO (Etalab 2.0) + Fogel et al. 2024 (MIT/CC-BY) |
| `NEWS.md` | MODIF | Entrée dev version : « Foundation for Open-Canopy integration (ADR-011 amended) » |

### 3.2 Amendement ADR-011 (repo `platform_nemeton`)

Rédiger un amendement à ADR-011 :
- Section « Augmentation ML » ajoutée
- Introduit le flag vectoriel `augmented` ∈ {`"height_ml"`, `"species_ml"`, `"texture_ml"`, ...}
- Précise que la confiance φ Fibonacci **n'est pas** modifiée globalement
- `compute_general_index_mixed()` peut pondérer par-indicateur avec un poids Fibonacci équivalent NDP+1 si le flag approprié est présent

### 3.3 Critères d'acceptation phase 1

- [ ] `detect_ndp()` retourne bien `augmented = "height_ml"` si `chm_source = "opencanopy"` présent dans les attributs
- [ ] `sanitize_chm()` applique les 5 étapes dans l'ordre, gère les masques optionnels, émet un warning si `pct_masked > 0.5`
- [ ] Fixture CHM COG lisible par `terra::rast()`, CRS EPSG:2154, format COG vérifié via `gdalinfo`
- [ ] 100 % des tests `test-ndp*.R` et `test-utils-chm.R` passent
- [ ] R CMD check : 0 error, 0 warning (max 1 note acceptée)
- [ ] Couverture utils-chm.R ≥ 90 %, ndp.R ≥ 90 %
- [ ] Amendement ADR-011 mergé dans platform_nemeton

### 3.4 Effort estimé

~2-3 jours de dev. Simple mais soigneux (fondation).

### 3.5 Risques

| Risque | Probabilité | Mitigation |
|--------|-------------|------------|
| Rétrocompatibilité `detect_ndp()` cassée | Moyen | Tests de régression sur tous les appelants existants avant merge |
| Format COG mal géré par `terra` anciennes versions | Faible | Pinner `terra >= 1.7-0` (déjà dans DESCRIPTION) |
| Confusion entre `augmented` et `NDP` chez un utilisateur | Moyen | Documentation claire + exemples ; pas d'impact code |

---

## 4. Phase 2 — P2 Station (gain le plus élevé)

**Objectif** : livrer la première value proposition concrète : indice de station textbook à NDP 0 via Duplat & Tran-Ha.

### 4.1 Livrables

| Fichier | Action | Contenu |
|---------|--------|---------|
| `data-raw/site_index_curves.R` | NEW | Script de génération du CSV depuis Duplat & Tran-Ha (et DSF pour douglas, CNPF pour peuplier) — documenté avec commentaires et références |
| `inst/extdata/site_index_curves.csv` | NEW | 10 essences × âges de 10 à 150 ans par pas de 5 ans × 5 classes de fertilité |
| `R/site_index.R` | NEW | `compute_site_index(H, age, species)` — interpolation bilinéaire dans la table, retourne classe 1-5 (H₀ @ 50 ans par convention) |
| `R/indicators-productive.R` | MODIF | `indicator_productive_station()` : nouvelle branche `if (!is.null(chm)) { ... compute_site_index() ... }` |
| `tests/testthat/test-site-index.R` | NEW | 15-20 tests : interpolation, fallback chêne/épicéa pour espèces inconnues, cohérence (plus vieux = plus haut), valeurs extrêmes |
| `tests/testthat/test-indicators-productive-chm.R` | NEW | Tests P2 mode CHM sur fixture |
| `vignettes/site-index-open-canopy_fr.Rmd` | NEW | Workflow complet : opencanopy → CHM → nemeton → indice de station |

### 4.2 Sources des courbes

**Fichier `data-raw/site_index_curves.R`** : script qui génère le CSV à partir de tables publiées.

- **Chênes, hêtre, châtaignier, épicéa, sapin, pin sylvestre** : tables Duplat & Tran-Ha (1997), à saisir depuis publication IFN.
- **Douglas** : tables DSF (Département de la Santé des Forêts) / IRSTEA.
- **Pin maritime** : courbes IFN Landes spécifiques.
- **Peuplier** : courbes CNPF pour cultivars I-214, I-45/51, Koster.

Format CSV :
```
species,age,class_1,class_2,class_3,class_4,class_5
quercus_petraea,20,3.2,5.1,7.0,8.9,10.8
quercus_petraea,50,7.8,12.4,17.0,21.6,26.2
...
```

### 4.3 Fonction `compute_site_index()`

```r
compute_site_index <- function(H_dom, age, species, reference_age = 50) {
  # 1. Lookup species (ou fallback chêne/épicéa)
  # 2. Charger les 5 courbes de fertilité pour cette espèce
  # 3. Interpoler H_dom à age → trouver classe de fertilité
  # 4. Retourner H₀ @ reference_age pour cette classe (= site index)
}
```

Vectorisé (accepte des vecteurs de H/age/species).

### 4.4 Critères d'acceptation phase 2

- [ ] CSV validé contre sources publiées (cohérence H croissante avec âge, min/max plausibles)
- [ ] `compute_site_index()` : 100 % des tests passent, inclut fallback espèces inconnues
- [ ] `indicator_productive_station()` : mode CHM et mode actuel produisent des résultats cohérents (corrélation >0.6 sur `massif_demo` même si valeurs absolues diffèrent)
- [ ] Vignette build sans warning
- [ ] Couverture site_index.R ≥ 90 %

### 4.5 Effort estimé

~4-5 jours. Le plus gros poste est la **saisie/validation des courbes Duplat & Tran-Ha**, qui demande un travail de documentation rigoureux.

### 4.6 Risques

| Risque | Probabilité | Mitigation |
|--------|-------------|------------|
| Courbes Duplat & Tran-Ha pas librement redistribuables | **Moyen-élevé** | Vérifier la licence des publications IFN ; demander au CNPF une validation ; fallback sur courbes publiées en open-access (Bontemps) |
| Divergence entre convention "classe de fertilité" (IFN : 5 classes) et "site index" (valeur continue à âge ref) | Moyen | Choisir **une seule convention** dans la doc, fournir helpers pour l'autre |
| Biais espèce : ortho IGN classifie mal certaines essences | Moyen | Documenter que l'espèce doit venir de BD Forêt v2 ou `tree_sat_nemeton`, pas déduite du CHM |

---

## 5. Phase 3 — P1 Volume

**Objectif** : étendre P1 pour utiliser H₍CHM₎ quand disponible.

### 5.1 Livrables

| Fichier | Action | Contenu |
|---------|--------|---------|
| `R/indicators-productive.R` | MODIF | `indicator_productive_volume()` : branche CHM-based `V = f(D, H, espèce)` via allométries IFN |
| `R/sysdata.rda` | MODIF | Ajout coefficients allométriques V(D, H) par espèce (déjà partiellement présents pour biomasse) |
| `tests/testthat/test-indicators-productive-chm.R` | MODIF | Ajout tests P1 mode CHM |
| `data-raw/allometric_volume.R` | NEW | Script de génération des coefficients allométriques V=f(D,H) depuis IFN |

### 5.2 Allométries

Modèle classique : `V = a × D^b × H^c` (Schumacher-Hall) ou `V = G × H × f` (factor-based).

Coefficients IFN par essence déjà publiés (Vallet et al.). Reprendre les 10 essences MVP de la phase 2.

### 5.3 Critères d'acceptation

- [ ] `indicator_productive_volume()` : mode CHM et mode actuel produisent des résultats, avec écart quantifié dans la vignette
- [ ] RMSE P1 sur `massif_demo` : mesurée avec et sans CHM, rapport écrit dans NEWS.md
- [ ] Tests passent sur au moins 3 espèces (chêne, hêtre, épicéa)
- [ ] Rétrocompatibilité : si `layers$chm` absent, comportement v0.15.1 inchangé

### 5.4 Effort estimé

~2-3 jours.

### 5.5 Risques

| Risque | Probabilité | Mitigation |
|--------|-------------|------------|
| Dégradation de P1 si CHM mal masqué (valeurs aberrantes) | Moyen | `sanitize_chm()` obligatoire en amont, warning si `pct_masked > 0.3` pour P1 |
| Incompatibilité allométrie V(D,H) / V(D) | Faible | Les deux modèles coexistent, choix par attribut `layers$has_chm` |

---

## 6. Phase 4 — C1, B2, R2

**Objectif** : étendre les gains CHM aux 3 indicateurs connexes identifiés.

### 6.1 Livrables

| Indicateur | Fichier | Modification |
|------------|---------|--------------|
| **C1 biomasse** | `R/indicators-core.R` | Branche allométrique H-based alternative à age-based. `biomass = a × D^b × H^c` (Zianis et al., Vallet et al.) |
| **B2 structure** | `R/indicators-biodiversity.R` | Composante `cv_chm = sd(H) / mean(H)` intégrée au Shannon multi-strates (poids configurable, défaut 0.2) |
| **R2 tempête** | `R/indicators-risk.R` | Calibration directe `vulnerability = f(H_CHM, species, slope)` au lieu du proxy âge |

Tests : compléter `test-indicators-*.R` avec des branches CHM.

### 6.2 Critères d'acceptation

- [ ] Chaque indicateur : rétrocompatible + branche CHM testée
- [ ] Corrélation (mode actuel, mode CHM) > 0.5 sur `massif_demo` — pas de renversement de signal
- [ ] Documentation mise à jour (roxygen + vignettes `biodiversity-resilience_fr.Rmd`)

### 6.3 Effort estimé

~3-4 jours au total (1 jour par indicateur + intégration).

### 6.4 Risques

| Risque | Probabilité | Mitigation |
|--------|-------------|------------|
| B2 : la composante cv_chm double-compte une info déjà présente (classes d'âge) | Moyen | Analyse de sensibilité dans la vignette, poids par défaut bas (0.2) |
| R2 : surestimation de la vulnérabilité en peuplement adulte homogène | Faible | Formule tient compte de `species` (résineux > feuillus pour H donné) |

---

## 7. Phase 5 — NDVI Bonus (optionnel)

**Objectif** : tirer parti des sorties NDVI/GNDVI/SAVI de `opencanopy` pour C2, A1, F2.

### 7.1 Livrables

| Indicateur | Modification |
|------------|--------------|
| **C2 NDVI** | `indicator_carbon_ndvi()` : accepter directement le NDVI d'`opencanopy` (déjà accepte un raster NDVI) |
| **A1 couverture** | Alternative `ndvi > threshold` en plus du masque OSO |
| **F2 érosion** | Facteur protection sol = `mean(NDVI)` plutôt que binaire forêt/non-forêt |

### 7.2 Statut

**Optionnel pour v0.16.0**. Peut être reporté à v0.16.1 si les phases 1-4 prennent plus de temps que prévu.

### 7.3 Effort estimé

~2 jours.

---

## 8. Phase 6 — UI (`nemetonshiny`)

**Objectif** : afficher l'augmentation ML dans l'interface.

### 8.1 Livrables (dans `nemetonshiny`)

| Fichier | Modification |
|---------|--------------|
| `R/mod_home.R` | Sélecteur de source CHM : « Aucun », « Open-Canopy (IGN ortho) », « LiDAR HD » |
| `R/mod_synthesis.R` | Badge supplémentaire « ⚡ hauteur ML » à côté du badge NDP |
| `inst/app/i18n/fr.json` | Nouvelles clés : `chm_source`, `chm_source_opencanopy`, `augmented_height_ml`, etc. |
| `inst/app/i18n/en.json` | Idem en anglais |
| `inst/experts/*.yml` | Intégrer info `augmented` dans les prompts LLM (profils gestionnaire, chercheur) |

### 8.2 Statut

Phase hors repo courant. À planifier dans `nemetonshiny` une fois phase 1 mergée côté cœur.

### 8.3 Effort estimé

~2-3 jours côté Shiny.

---

## 9. Phase 7 — Mosaïquage à l'échelle (post-MVP)

**Objectif** : passer du mode AOI-driven au cache par dalles IGN.

### 9.1 Livrables

| Fichier | Action | Contenu |
|---------|--------|---------|
| `R/chm_cache.R` | NEW | `chm_cache_get(dalle_id)`, `chm_cache_put(dalle_id, path)`, index DuckDB |
| `R/utils-chm.R` | MODIF | `load_chm_for_aoi(aoi)` — assemble plusieurs dalles depuis cache |
| `~/.local/share/nemeton/chm_cache/` | runtime | Stockage par dalle IGN (1 km × 1 km) |
| `inst/chm_cache_index.duckdb` | schema | Index `{dalle_id, path, model, model_version, created_at, checksum}` |

### 9.2 Statut

**Post-MVP** (v0.17.0). Pas bloquant pour valider l'intégration avec Open-Canopy.

---

## 10. Stratégie de test

### 10.1 Fixtures

- **CHM synthétique COG** (`tests/testthat/helpers/fixture_chm.R`) : générateur paramétrable (taille AOI, résolution, valeurs de hauteur). Utilisé partout pour éviter le poids d'un vrai CHM dans `data/`.
- **`massif_demo_units` étendu** : ajouter une colonne `has_chm = TRUE/FALSE` pour benchmark avec/sans CHM. Pas de régénération des 20 unités (évite un gros data regen).

### 10.2 Types de tests

| Niveau | Cible | Outil |
|--------|-------|-------|
| Unit | Fonctions pures (`sanitize_chm`, `compute_site_index`) | `testthat` |
| Integration | Pipeline complet fixture AOI → nemeton_compute | `testthat` + fixture |
| Régression | Valeurs indicateurs avant/après intégration | Comparaison sur `massif_demo` — écart quantifié |
| Coverage | ≥ 90 % pour chaque nouveau fichier | `covr` |

### 10.3 Pas de test E2E dans ce spec

Les tests E2E avec vrai CHM Open-Canopy sont dans `opencanopynemeton` côté, pas ici. `nemeton` reçoit un raster en entrée, point.

---

## 11. Stratégie de documentation

### 11.1 Roxygen

- Toute nouvelle fonction exportée : exemples exécutables avec la fixture CHM
- Note de rétrocompatibilité sur les fonctions modifiées (`@note Backward compatible: if layers$chm is NULL, falls back to v0.15.1 behavior.`)

### 11.2 Vignettes

- **Nouvelle** : `site-index-open-canopy_fr.Rmd` — workflow de bout en bout
- **À mettre à jour** : `biodiversity-resilience_fr.Rmd` (composante cv_chm pour B2), `complete-referential_fr.Rmd`

### 11.3 README et pkgdown

- Section README « NDP augmenté » expliquant le flag `augmented` et l'intégration Open-Canopy
- `_pkgdown.yml` : nouvelle catégorie « CHM / Open-Canopy » regroupant `sanitize_chm`, `compute_site_index`, etc.

### 11.4 CLAUDE.md

Mise à jour pour documenter :
- L'existence de `opencanopy` comme source externe
- Le flag `augmented` dans la détection NDP
- Les nouvelles fonctions cœur (`sanitize_chm`, `compute_site_index`)

---

## 12. Risques globaux et mitigations

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| Licence Duplat & Tran-Ha bloquante pour redistribution | Moyen | Élevé | Contacter IFN ; fallback open-access |
| Faible adoption par absence de pipeline intégré `opencanopy` → `nemeton` | Élevé | Moyen | Phase 6 critique pour UX ; planifier tôt |
| Régression silencieuse sur P1/P2 en mode sans CHM | Faible | Élevé | Suite de tests de régression sur `massif_demo` avant chaque PR |
| Dérive de scope (on ajoute sans cesse) | Moyen | Moyen | Freeze spec au début de chaque phase ; nouvelles idées → extensions (§6 spec) |

---

## 13. Critères globaux de succès v0.16.0

- [ ] Phases 1-4 livrées, mergées dans `main`
- [ ] R CMD check : 0 error, 0 warning
- [ ] Couverture globale ≥ 94 % (niveau actuel 94.3 %)
- [ ] Tous les tests passent (y compris nouveaux)
- [ ] Vignettes builds OK
- [ ] pkgdown site à jour
- [ ] Amendement ADR-011 mergé dans platform_nemeton
- [ ] NEWS.md documente l'intégration Open-Canopy
- [ ] CLAUDE.md mis à jour
- [ ] Démo end-to-end reproductible : `opencanopy::pipeline_aoi_to_chm(aoi)` → `nemeton_compute(units, layers = list(chm = ...))` → indicateurs P1/P2 améliorés

---

## 14. Ce qui vient après (v0.17.0 et au-delà)

- **Phase 5** : NDVI bonus (C2, A1, F2)
- **Phase 6** : UI `nemetonshiny` (sélecteur CHM, badge « ⚡ hauteur ML »)
- **Phase 7** : cache dalles IGN + index DuckDB
- **Open-Canopy-Δ** (nouveau spec 006) : détection de changement T2/R2/dynamique P
- **Fusion LiDAR HD + Open-Canopy** : priorité LiDAR quand disponible, Open-Canopy en complément
