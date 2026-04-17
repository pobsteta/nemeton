# Plan d'Implémentation : Intégration produits globaux pré-calculés

**Spec associée** : `spec.md` (v0.2.0, validé le 2026-04-17)
**Cible** : nemeton v0.17.0 (après spec 005 mergé en v0.16.0)
**Statut** : Draft
**Auteur** : Pascal Obstétar (via Claude)

---

## 1. Vue d'ensemble

### 1.1 Scope technique

| Couche | Impact |
|--------|--------|
| **R/** (cœur) | 2 nouveaux fichiers (`remote_data.R`, `remote_cache.R`), 5 fichiers modifiés |
| **DESCRIPTION** | +3 Suggests : `rstac`, `httr2`, validation de `rappdirs` |
| **inst/** | `inst/NOTICE` étendu (4 produits ajoutés) |
| **tests/testthat/** | 5 nouveaux fichiers de tests, tous `skip_if_offline` |
| **vignettes/** | 1 nouvelle vignette « Remote data sources » |

### 1.2 Dépendance à spec 005

Spec 006 **présuppose** que spec 005 est mergée :
- `sanitize_chm()` est disponible pour nettoyer les CHM Meta/WRI exactement comme les CHM `opencanopy`
- `compute_site_index()` est disponible et accepte n'importe quel raster H
- Flag `augmented = "height_ml"` dans `detect_ndp()` fonctionne
- `inst/NOTICE` existe (on étend, pas créer)

Si spec 005 glisse, spec 006 peut démarrer la **Phase 1** (infra `fetch_remote_raster`) sans bloquer, mais la Phase 2 (Meta/WRI → P1/P2) attend.

### 1.3 Architecture cible (fichiers impactés)

```
nemeton/
├── R/
│   ├── remote_data.R               [NEW]   fetch_remote_raster, auto_select_chm_source
│   ├── remote_cache.R              [NEW]   get_cache_dir, cache_get, cache_put, index DuckDB
│   ├── datasources.R               [MODIF] +4 entrées (meta, worldcover, dw, potapov)
│   ├── utils-chm.R                 [MODIF] cross_validate_chm()
│   ├── indicators-air.R            [MODIF] A1 branche worldcover
│   ├── indicators-landscape.R      [MODIF] L1/L2 branche worldcover
│   ├── indicators-temporal.R       [MODIF] T2 branche Dynamic World
│   └── indicators-biodiversity.R   [MODIF] B3 branche worldcover
├── inst/
│   └── NOTICE                      [MODIF] +Meta/WRI, ESA WorldCover, Dynamic World, Potapov
├── tests/testthat/
│   ├── test-remote-data.R          [NEW]   fetch_remote_raster, auto-select
│   ├── test-remote-cache.R         [NEW]   cache hit/miss, purge, index
│   ├── test-cross-validate-chm.R   [NEW]   divergence opencanopy vs Meta/WRI
│   ├── test-indicators-remote.R    [NEW]   A1, L1, L2, B3, T2 avec sources distantes
│   └── helpers/
│       └── fixture_remote.R        [NEW]   mocks HTTP/S3 pour tests offline
├── vignettes/
│   └── remote-data-sources_fr.Rmd  [NEW]   workflow produits globaux
└── NEWS.md                         [MODIF]
```

---

## 2. Phases et ordonnancement

### 2.1 Dépendances entre phases

```
Phase 1 (infra fetch + cache + datasources)
   │
   ├──► Phase 2 (Meta/WRI → CHM-consumers P1/P2/C1/B2/R2)
   │       │
   │       ├──► Phase 3 (ESA WorldCover → A1/L1/L2/B3)
   │       │
   │       └──► Phase 4 (Dynamic World → T2)
   │
   ├──► Phase 5 (Potapov 30m fallback)
   │
   └──► Phase 6 (cross_validate_chm diagnostic)
```

Phase 1 est **strictement bloquante**. Les phases 2-6 sont **indépendantes entre elles** → parallélisables si plusieurs contributeurs.

### 2.2 Découpage en versions

| Version | Contenu | Tag cible |
|---------|---------|-----------|
| v0.16.x intermédiaire | Phase 1 seule (infra réseau + cache, pas d'indicateur modifié) | — |
| v0.17.0 | Phases 2 + 3 + 4 (CHM Meta/WRI, WorldCover, Dynamic World) | **v0.17.0** |
| v0.17.1 | Phases 5 + 6 (Potapov, validation croisée) | v0.17.1 |

### 2.3 Stratégie de branches

Une branche par phase, PR indépendants :
- `feat/006-phase1-remote-infra`
- `feat/006-phase2-meta-chm`
- `feat/006-phase3-worldcover`
- `feat/006-phase4-dynamic-world`
- `feat/006-phase5-potapov`
- `feat/006-phase6-cross-validate`

Toutes mergeables sur `main` indépendamment après Phase 1.

---

## 3. Phase 1 — Infrastructure fetch + cache + datasources

**Objectif** : poser la plomberie réseau + cache sans toucher aux indicateurs. À l'issue de cette phase, on peut lire un CHM Meta/WRI par fenêtre depuis S3 via `fetch_remote_raster("canopy_height_meta", aoi)`.

### 3.1 Livrables

| Fichier | Action | Contenu |
|---------|--------|---------|
| `R/remote_cache.R` | NEW | `get_cache_dir()` avec hiérarchie option/env/rappdirs ; `cache_get(source, key)` ; `cache_put(source, key, path)` ; index DuckDB |
| `R/remote_data.R` | NEW | `fetch_remote_raster(source, aoi, crs, cache, ...)` ; dispatch selon `access` (gdal_vsis3 / rstac_signed / httr2_download) |
| `R/remote_data.R` | NEW | `auto_select_chm_source(aoi, prefer_resolution)` |
| `R/remote_data.R` | NEW | `aoi_in_france_metro()`, `aoi_in_dom_tom()`, `aoi_in_europe()` helpers |
| `R/datasources.R` | MODIF | Ajout 4 entrées : `canopy_height_meta`, `landcover_worldcover`, `landcover_dynamic_world`, `canopy_height_potapov` (cf. spec §5.1) |
| `DESCRIPTION` | MODIF | Ajout `rstac`, `httr2` en Suggests |
| `inst/NOTICE` | MODIF | Attributions Meta/WRI, ESA, Dynamic World, Potapov |
| `tests/testthat/helpers/fixture_remote.R` | NEW | Mock HTTP responses via `httptest2` ou fichiers fixtures COG locaux |
| `tests/testthat/test-remote-cache.R` | NEW | 15-20 tests : hiérarchie config, cache hit/miss, purge, corruption checksum |
| `tests/testthat/test-remote-data.R` | NEW | 10-12 tests : dispatch access, auto-select, vérification runtime des Suggests |

### 3.2 API publique introduite

```r
# Fonction principale
fetch_remote_raster(
  source = "canopy_height_meta",
  aoi,
  crs    = NULL,         # reprojection vers ce CRS si fourni
  cache  = TRUE,
  force  = FALSE         # rafraîchir cache
)
# → SpatRaster

# Sélection auto
auto_select_chm_source(aoi, prefer_resolution = TRUE)
# → list(source, reason)

# Gestion cache
clean_remote_cache(max_age_days = 180, max_size_gb = 20)
get_cache_info()         # stats: source × nb fichiers × taille
```

### 3.3 Critères d'acceptation phase 1

- [ ] `fetch_remote_raster("canopy_height_meta", aoi)` retourne un `SpatRaster` valide pour une AOI fictive en France (test avec fixture locale)
- [ ] `auto_select_chm_source()` choisit bien `opencanopy` en France métro + `canopy_height_meta` ailleurs (tests avec AOI synthétiques)
- [ ] Cache hit après premier fetch : pas d'appel réseau
- [ ] Runtime check clair si `rstac` absent : `install.packages("rstac")` affiché dans le message d'erreur
- [ ] Tous les tests `skip_on_cran()` et `skip_if_offline()` passent en local, skippent en CI sans réseau
- [ ] R CMD check : 0 error, 0 warning
- [ ] Couverture `remote_*.R` ≥ 85 % (inférieur aux 90 % habituels car les branches réseau sont difficiles à couvrir sans mocks complets)

### 3.4 Effort estimé

~4-5 jours. Le gros du temps : gestion fine des timeouts, reprises, corrigés CRS, mocks de tests offline.

### 3.5 Risques phase 1

| Risque | Probabilité | Mitigation |
|--------|-------------|------------|
| Endpoint S3 Meta/WRI change | Faible | Endpoint versioné, `datasources.R` point central |
| Timeout S3 selon latence réseau | Moyen | `GDAL_HTTP_TIMEOUT` configurable + retry avec backoff |
| Tests réseau flaky en CI | Élevé | Tous marqués `skip_on_cran()` + `skip_if_offline()`, fixtures locales pour tests déterministes |
| Incompatibilité GDAL ancien (`/vsis3/` buggé) | Faible | Pinner `terra >= 1.7-29` (version avec GDAL >= 3.4) |
| Cache DuckDB verrouillé en accès concurrent | Moyen | Utiliser `DBI::dbConnect(..., read_only = FALSE)` avec wait ; documenter limite single-writer |

---

## 4. Phase 2 — Meta/WRI CHM → consommateurs existants

**Objectif** : faire en sorte que les indicateurs P1, P2, C1, B2, R2 (déjà adaptés en spec 005) puissent consommer un CHM Meta/WRI via `fetch_remote_raster()`.

### 4.1 Livrables

| Fichier | Action | Contenu |
|---------|--------|---------|
| `R/remote_data.R` | MODIF | Helper `prepare_chm_for_aoi(aoi, source, sanitize = TRUE)` qui enchaîne fetch + sanitize_chm + masquage |
| Pas de modif indicateurs | — | Les indicateurs acceptent déjà n'importe quel CHM en entrée |
| `tests/testthat/test-chm-meta.R` | NEW | Tests P1, P2, C1, B2, R2 avec CHM Meta/WRI fixture |
| `vignettes/remote-data-sources_fr.Rmd` | NEW | Workflow : AOI → fetch Meta/WRI → sanitize → nemeton_compute |

### 4.2 Critères d'acceptation phase 2

- [ ] P1 et P2 donnent des résultats cohérents avec Meta/WRI sur fixture AOI (corrélation > 0.6 avec même AOI en mode opencanopy)
- [ ] Si `opencanopy` installé et AOI en France → `opencanopy` automatiquement préféré, Meta/WRI silencieusement ignoré
- [ ] Si AOI en Guyane → Meta/WRI automatiquement sélectionné, message informatif
- [ ] Métadonnées `attr(result, "chm_source_chosen")` reflètent la source effective
- [ ] Vignette construit sans warning

### 4.3 Effort estimé

~2 jours. Plus léger que prévu parce que tout le travail sur P1/P2/C1/B2/R2 est déjà fait en spec 005.

### 4.4 Risques

| Risque | Probabilité | Mitigation |
|--------|-------------|------------|
| Meta/WRI valeurs aberrantes (zones urbaines, eau) | Moyen | `sanitize_chm()` obligatoire après fetch, warning si `pct_masked > 0.5` |
| RMSE Meta/WRI supérieure à opencanopy sur forêts françaises | Moyen | Documenté dans vignette, `cross_validate_chm()` phase 6 pour diagnostic |

---

## 5. Phase 3 — ESA WorldCover → A1/L1/L2/B3

**Objectif** : remplacer les sources OSM/OSO locales par ESA WorldCover 10 m mondial pour les indicateurs d'occupation.

### 5.1 Livrables

| Fichier | Action | Contenu |
|---------|--------|---------|
| `R/indicators-air.R::indicator_air_coverage()` | MODIF | Branche `source = "worldcover"` : classe 10 (tree cover) |
| `R/indicators-landscape.R::indicator_landscape_fragmentation()` | MODIF | Branche worldcover : patches depuis classe tree cover |
| `R/indicators-landscape.R::indicator_landscape_edge()` | MODIF | Branche worldcover |
| `R/indicators-biodiversity.R::indicator_biodiversity_connectivity()` | MODIF | Branche worldcover pour continuité forestière |
| `tests/testthat/test-indicators-worldcover.R` | NEW | Tests sur fixture WorldCover locale |

### 5.2 Critères d'acceptation

- [ ] A1 avec WorldCover vs OSO sur massif_demo : corrélation > 0.7
- [ ] L1 fragmentation avec WorldCover donne des résultats plausibles (tuiles touchées correctement agrégées)
- [ ] Pas de régression : si source OSO présente, comportement actuel inchangé

### 5.3 Effort estimé

~2-3 jours.

### 5.4 Risques

| Risque | Probabilité | Mitigation |
|--------|-------------|------------|
| WorldCover classes non bijectives avec classes locales FR (OSO, BD Forêt) | Élevé | Table de correspondance documentée en début de vignette ; user peut choisir la source |
| Patches mal détectés sur AOI à cheval sur tuiles WorldCover 3° | Moyen | Récupérer toutes les tuiles nécessaires via bbox union |

---

## 6. Phase 4 — Dynamic World → T2 changement

**Objectif** : enrichir T2 (changement d'occupation) avec les séries temporelles Dynamic World hebdomadaires.

### 6.1 Livrables

| Fichier | Action | Contenu |
|---------|--------|---------|
| `R/indicators-temporal.R::indicator_temporal_change()` | MODIF | Branche `source = "dynamic_world"` avec paramètres `date_start, date_end` |
| `R/remote_data.R` | MODIF | `fetch_dynamic_world(aoi, date_start, date_end, composite = "median")` via STAC + rstac |
| `tests/testthat/test-indicators-dynamic-world.R` | NEW | Tests sur fixture DW |
| `vignettes/remote-data-sources_fr.Rmd` | MODIF | Section « Détection de changement continue avec Dynamic World » |

### 6.2 Critères d'acceptation

- [ ] `fetch_dynamic_world()` récupère un composite médian sur une période donnée
- [ ] T2 avec Dynamic World détecte un changement simulé (fixture avec différence)
- [ ] Si `rstac` absent, message d'erreur actionnable
- [ ] Signed URLs Planetary Computer fonctionnent avec et sans token utilisateur

### 6.3 Effort estimé

~3 jours.

### 6.4 Risques

| Risque | Probabilité | Mitigation |
|--------|-------------|------------|
| Rate limit Planetary Computer | Faible | 500k req/mois — largement suffisant ; documenter dans vignette |
| STAC schema change côté MS | Moyen | `rstac` maintenu, abstraction via `datasources.R` |
| Nuages non masqués dans composite | Élevé | Utiliser l'asset `probability_nodata` de DW, masquage intégré |

---

## 7. Phase 5 — Potapov 30 m fallback

**Objectif** : offrir un fallback tertiaire quand ni `opencanopy` ni Meta/WRI ne sont disponibles (zones reculées, serveurs down).

### 7.1 Livrables

| Fichier | Action | Contenu |
|---------|--------|---------|
| `R/remote_data.R` | MODIF | Dispatch `access = "httr2_download"` pour tuiles 10° × 10° |
| `R/remote_data.R` | MODIF | `auto_select_chm_source()` : priorité opencanopy > Meta/WRI > Potapov |
| `tests/testthat/test-chm-potapov.R` | NEW | Tests fixture Potapov |

### 7.2 Critères d'acceptation

- [ ] Téléchargement Potapov fonctionnel avec cache local
- [ ] `auto_select_chm_source()` fallback vers Potapov si Meta/WRI indisponible (simulé via mock erreur 503)
- [ ] Warning affiché : « Using Potapov 30 m. Resolution limited, consider opencanopy or Meta/WRI if available. »

### 7.3 Effort estimé

~1-2 jours.

---

## 8. Phase 6 — cross_validate_chm diagnostic

**Objectif** : outil d'analyse comparative quand deux sources CHM sont disponibles simultanément pour la même AOI.

### 8.1 Livrables

| Fichier | Action | Contenu |
|---------|--------|---------|
| `R/utils-chm.R` | MODIF | `cross_validate_chm(chm_a, chm_b, method = c("absolute", "relative"))` |
| `R/utils-chm.R` | MODIF | Retourne `list(mean_abs_diff, rmse, pixelwise_diff, agreement_pct, agreement_raster)` |
| `tests/testthat/test-cross-validate-chm.R` | NEW | Tests cas triviaux (rasters identiques, différents, NA, CRS distincts) |
| `vignettes/remote-data-sources_fr.Rmd` | MODIF | Section « Validation croisée Meta/WRI vs opencanopy » |

### 8.2 Critères d'acceptation

- [ ] Rasters identiques → `agreement_pct = 100`, `rmse = 0`
- [ ] Rasters reprojetés automatiquement si CRS différents
- [ ] `pixelwise_diff` est un SpatRaster utilisable pour cartographie
- [ ] Vignette illustre un cas réel France métro avec les deux sources

### 8.3 Effort estimé

~1 jour.

---

## 9. Stratégie de test

### 9.1 Fixtures offline (crucial)

Le défi principal : tester du code réseau **sans dépendre du réseau en CI**. Approches combinées :

1. **Fichiers COG locaux** comme « mini Meta/WRI » — AOI réduite, 1-2 tuiles à ~1 Mo chacune, stockées dans `tests/testthat/fixtures/remote/`
2. **Redirection via `options(nemeton.remote.endpoint.test = "file://...")`** — les fonctions `fetch_remote_raster` supportent un endpoint override en test
3. **Tests marqués `skip_on_cran()` + `skip_if_offline()`** pour les scénarios vrai réseau (exécutés en local + CI avec réseau)
4. **Mocks avec `httptest2`** ou équivalent pour STAC queries

### 9.2 Test matrix

| Niveau | Cible | Dépendance réseau |
|--------|-------|-------------------|
| Unit | `get_cache_dir`, `auto_select_chm_source`, `cross_validate_chm` | Aucune |
| Integration local | `fetch_remote_raster` avec endpoint file:// | Aucune |
| Integration réseau | `fetch_remote_raster` vrai S3 | Skip en CI sans réseau |
| E2E | Vignettes build | Doit passer offline avec fixtures |

### 9.3 Pas de test E2E cloud

On ne teste pas la connectivité AWS/Microsoft en CI. Si `opencanopy` ne produit pas d'authentication, `nemeton` non plus. C'est à l'admin système de vérifier la connectivité avant production.

---

## 10. Stratégie de documentation

### 10.1 Vignette « Remote data sources »

Structure :
1. Vue d'ensemble des 4 produits (Meta, WorldCover, DW, Potapov)
2. Configuration du cache
3. Exemple complet : AOI en Guyane → CHM Meta/WRI → P1/P2
4. Exemple complet : AOI en France → auto-select opencanopy
5. Section « Diagnostic : cross_validate_chm »
6. Section « Usage offline / air-gapped » (cache pré-rempli)

### 10.2 CLAUDE.md

Ajouter une section « Sources de données distantes » listant les 4 produits et les règles de sélection.

### 10.3 README.md

Section courte « NDP 0 mondial via produits pré-calculés » avec 5 lignes d'exemple.

### 10.4 Roxygen

Toutes les fonctions `fetch_*`, `cache_*` documentées avec exemples `\dontrun{}` (car dépend du réseau) + exemples runnable via fixture.

---

## 11. Risques globaux et mitigations

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| Tests CI flaky | Élevé | Moyen | skip_if_offline + fixtures locales + endpoint override |
| Endpoints cloud disparaissent | Faible | Élevé | Abstraction `datasources.R` centralisée, fallback Potapov |
| Coûts de bande passante élevés en production | Moyen | Moyen | Cache obligatoire + limites configurables + `clean_remote_cache()` |
| Divergence Meta vs opencanopy perçue comme bug par user | Moyen | Faible | Documenter dans vignette ; `cross_validate_chm()` pour transparence |
| Maxar licence mal comprise | Faible | Moyen | NOTICE explicite : CHM dérivé OK, imagerie Maxar interdite à la redistribution |

---

## 12. Critères globaux de succès v0.17.0

- [ ] Phases 1-4 livrées, mergées dans `main`
- [ ] R CMD check : 0 error, 0 warning
- [ ] Couverture globale ≥ 92 % (baseline 94.3 %, on peut tolérer -2 points à cause des branches réseau difficiles à couvrir)
- [ ] Tous les tests passent en offline (via fixtures)
- [ ] Tous les tests passent en réseau (vrai S3 / vrai STAC)
- [ ] Vignette « Remote data sources » build OK
- [ ] pkgdown à jour
- [ ] NOTICE étendu avec 4 attributions
- [ ] CLAUDE.md et README.md à jour
- [ ] Démo end-to-end : AOI en Guyane française → Meta/WRI CHM → P1/P2 indicateurs calculés sans installation Python

---

## 13. Ce qui vient après (v0.17.1 et au-delà)

- **Phase 5** : Potapov 30 m fallback (v0.17.1)
- **Phase 6** : `cross_validate_chm` diagnostic (v0.17.1)
- **Extensions** : CCI Biomass, Hansen Global Forest Change, Copernicus HRL Forest (spec 007 potentiel)
- **Sentinel time-series natif** : si besoin d'inférence S1/S2 custom non couverte par les produits pré-calculés → nouveau package `sentinel_nemeton` (spec 008 potentiel)
- **S3 Néméton privé** : rasters pré-calculés par Néméton pour tiers (ADR-002 section S3), via cette même infrastructure
