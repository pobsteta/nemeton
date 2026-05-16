# Plan technique : Suivi sanitaire (spec 008)

**Version** : 0.1.0
**Date**    : 2026-04-26
**Spec**    : `spec.md` v0.1.0
**Cible**   : `nemeton` v0.21.0, `nemetonshiny` v0.21.0

Ce document traduit la spec 008 en architecture technique exécutable. Pour le « quoi » et le « pourquoi », voir `spec.md`.

---

## 1. Stack technique

### 1.1 Côté cœur `nemeton` (R)

- **Existant réutilisé** : `R/db.R`, `R/sentinel2.R`, `R/monitoring.R`, `R/alerts.R` (tous v0.20.x), `R/qgis_export.R`, `R/qgis_import.R` (E5.b), `R/sampling_plan.R`
- **Nouveau** :
  - `R/fordead_python.R` — gestion du venv reticulate (idempotent, premier appel = création + install)
  - `R/fordead_pipeline.R` — orchestrateur `run_fordead_dieback()` (5 étapes FORDEAD via reticulate)
  - `R/fordead_postprocess.R` — rasters → POINT clusters → table `alert` ; `FORDEAD_CONFIDENCE_WEIGHTS` ; `classify_disturbance()`
  - `R/fordead_validity.R` — `check_fordead_validity(aoi, units)` ; chargement de `fordead_validity_zones.geojson`
  - `R/indicators-deperissement.R` — `indicateur_r5_deperissement(units, fordead_results, ...)`
  - `R/health_validation.R` — `get_health_validation_schema()`, `generate_health_validation_plots()`, `ingest_health_validation()`
- **Schéma SQL** : `inst/db/migrations/0002_fordead.sql` (extension de la table `alert`)

### 1.2 Côté app `nemetonshiny` (R)

- **Existant réutilisé** : `R/mod_monitoring.R` (E6.b phase 1, scaffold), `R/mod_field_ingest.R` (E5.b), `R/service_monitoring_db.R`
- **Nouveau** :
  - Extension de `mod_monitoring.R` : toggle `mode = c("rapide", "sanitaire")`, bannières conditionnelles, génération QField, validation
  - Extension de `mod_field_ingest.R` : sous-onglet « Validation sanitaire » utilisant `nemeton::ingest_health_validation()`
- **i18n** : ~30 nouvelles clés (`monitoring_mode_*`, `monitoring_warning_*`, `health_validation_*`, `r5_*`)

### 1.3 Python (isolé via reticulate)

- **Env virtuel** : `~/.virtualenvs/nemeton-fordead/`
- **Création** : à la première utilisation, déclenchée par `.ensure_fordead_python()`
- **Dépendances** : pinned dans `inst/python/requirements.txt`
  ```
  fordead @ git+https://gitlab.com/fordead/fordead_package@v1.11.4
  xarray>=2024.0
  dask[complete]>=2024.0
  rasterio>=1.3.0
  eodag>=3.0
  numpy>=1.26
  pandas>=2.0
  geopandas>=0.14
  shapely>=2.0
  ```
  Note (corrigé v0.22.2) : `fordead` n'est pas publié sur PyPI. La
  procédure d'install officielle (docs INRAE) passe par un URL pin
  PEP 508 vers le dépôt GitLab.
  Note (corrigé v0.22.5) : pin sur la branche **1.x** (dernier tag
  `v1.11.4`, sortie 2025-08-13). fordead 2.x a refactoré l'API du
  pipeline — `fordead.steps.step1_*..step5_*` (1.x) → classe
  `fordead.workflow.FordeadProcess` (2.x). Le côté R (`R/fordead_pipeline.R`)
  appelle l'API 1.x. La migration vers 2.x est un chantier séparé
  (amendement spec 008 / ADR-013 à venir).
- **Vérification système** : Python ≥ 3.10 requis, `cli::cli_abort` explicite si absent

### 1.4 Données embarquées

- `inst/extdata/fordead_validity_zones.geojson` (~50-150 ko après simplification)
  - **Construction** : script `data-raw/build_fordead_validity_zones.R` qui :
    1. Fetch `https://geo.api.gouv.fr/departements/{code}?format=geojson&geometry=contour` pour les codes 88, 39, 01, 73, 74
    2. Union via `sf::st_union()`
    3. Simplification `sf::st_simplify(dTolerance = 100, preserveTopology = TRUE)`
    4. Reprojection EPSG:4326
    5. Écriture `sf::st_write(..., driver = "GeoJSON")`
  - Le script est checked-in et reproductible. Le GeoJSON résultat est aussi checked-in (pas de download au moment du build du package).

---

## 2. Pipeline FORDEAD côté R — séquence d'appels

### 2.1 Fonction d'orchestration

```r
run_fordead_dieback(
  aoi,                              # sf POLYGON, EPSG:2154
  dates_training = c("2016-01-01", "2017-12-31"),
  dates_monitoring = c("2018-01-01", Sys.Date()),
  vegetation_index = "CRSWIR",
  threshold_anomaly = 0.16,
  forest_mask = NULL,               # path GeoTIFF ou sf, défaut = BD Forêt v2 IGN
  output_dir = tempfile("fordead_"),
  python_env = NULL,                # défaut : ~/.virtualenvs/nemeton-fordead
  con = NULL                        # DBIConnection vers TimescaleDB ; si fourni, persiste les alertes
)
```

Retourne une liste structurée :
```r
list(
  status        = "success",
  output_dir    = "/tmp/.../fordead_xyz",
  rasters       = list(state = "...state.tif", first_dieback_date = "...", stress_index = "..."),
  alerts_sf     = sf POINT,         # un POINT par cluster d'anomalie
  n_alerts_inserted = 42,           # si con fourni
  duration_sec  = 187.3,
  python_env    = "~/.virtualenvs/nemeton-fordead",
  fordead_version = "2.1.4"
)
```

### 2.2 Phases internes

```r
run_fordead_dieback <- function(...) {
  fd <- .ensure_fordead_python()     # reticulate::import("fordead.steps")

  # 1. Compute masked vegetation index
  fd$step1_compute_masked_vegetationindex$compute_masked_vegetationindex(
     input_directory = ...,
     vegetation_index = vegetation_index,
     ...
  )

  # 2. Train model
  fd$step2_train_model$train_model(
     input_directory = ...,
     dates_training = dates_training,
     ...
  )

  # 3. Forest mask (BD Forêt v2 si non fourni)
  if (is.null(forest_mask)) {
    forest_mask <- .download_or_use_cached_bd_foret(aoi)
  }

  # 4. Dieback detection
  fd$step3_dieback_detection$dieback_detection(
     input_directory = ...,
     threshold_anomaly = threshold_anomaly,
     ...
  )

  # 5. Export results
  fd$step5_export_results$export_results(...)

  # 6. Post-processing R : raster → POINT clusters → INSERT alert
  alerts_sf <- .postprocess_fordead_rasters(output_dir)
  if (!is.null(con)) .insert_fordead_alerts(con, alerts_sf, zone_id)

  list(status = "success", ..., alerts_sf = alerts_sf)
}
```

### 2.3 Performance attendue

Sur une AOI de **10 ha** (typique parcelle), 4 ans de S2 (~150 acquisitions valides) :
- Compute VI + masque : 30-60s
- Train model : 10-30s
- Dieback detection : 60-120s
- Export : 5-10s
- **Total : 2-4 minutes** sur un poste R/Python avec dask local

Sur une AOI de **100 km²** (massif), 4 ans :
- Total : 30-90 minutes (dépend très fort du nombre de cœurs et de la mémoire)

Au-delà : tiling explicite par dalle S2 (33TYM, etc.) — mais cas hors scope v0.21.0.

---

## 3. Logique de fusion (G2)

```r
classify_disturbance <- function(alerts_df) {
  # Pour chaque alerte FORDEAD, chercher une rolling-window (NDVI/NBR drop)
  # sur le même plot dans une fenêtre de ±30 jours.
  alerts_df$disturbance_type <- vapply(seq_len(nrow(alerts_df)), function(i) {
    a <- alerts_df[i, ]
    if (a$alert_type == "fordead_dieback") {
      same_plot_recent <- alerts_df$plot_id == a$plot_id &
        alerts_df$alert_type %in% c("ndvi_drop", "nbr_drop") &
        abs(as.numeric(alerts_df$trigger_date - a$trigger_date)) <= 30
      if (any(same_plot_recent)) "mechanical" else "progressive"
    } else if (a$alert_type %in% c("ndvi_drop", "nbr_drop")) {
      same_plot_fordead <- alerts_df$plot_id == a$plot_id &
        alerts_df$alert_type == "fordead_dieback" &
        abs(as.numeric(alerts_df$trigger_date - a$trigger_date)) <= 30
      if (any(same_plot_fordead)) NA_character_ else "recent_event"
    } else NA_character_
  }, character(1))
  alerts_df
}
```

Pas de persistance — recalculé à chaque requête. Coût : O(n²) sur un dataframe de quelques milliers d'alertes max → négligeable.

---

## 4. Workflow de validation terrain (G4) — séquence

```
[mod_monitoring]                         [DB]                    [QField/agent]
     |                                    |                            |
     | run_fordead_dieback() ──────────►  | INSERT alert × N           |
     |                                    | (status=pending)           |
     |                                    |                            |
     | "Générer placettes"                |                            |
     | generate_health_validation_plots(  |                            |
     |   alerts_sf, n=30) ──► .qgz        |                            |
     |                                    |                            |
     | (téléchargement par utilisateur) ─────────────────────────────►|
     |                                    |                            |
     |                                    |              (saisie OFFLINE)
     |                                    |                            |
     | (upload GPKG par utilisateur) ◄──────────────────────────────  |
     |                                    |                            |
     | mod_field_ingest "Validation       |                            |
     |  sanitaire" ──► ingest_health_     |                            |
     |   validation(con, gpkg, zone) ──►  | UPDATE alert SET           |
     |                                    |   validation_status = ...  |
     |                                    |   validation_cause = ...   |
     |                                    |   validated_by = ...       |
     |                                    |   WHERE id IN (...)        |
     |                                    |                            |
     | "Rapport validation : 23           |                            |
     |  confirmées, 5 faux positifs,      |                            |
     |  2 sans correspondance" ◄──────────|                            |
```

---

## 5. Découpage en chantiers livrables

| Chantier | Repo | Cœur de la livraison | Release | Estimation |
|----------|------|----------------------|---------|------------|
| **E6.b phase 2-6** | `nemetonshiny` | Mode toggle, async ingestion E6.a, plotly, leaflet alertes, persistance config | v0.21.0-rc1 | 2-3 sessions |
| **E6.c.1** | `nemeton` | `R/fordead_python.R`, `R/fordead_pipeline.R` (mocké), tests d'orchestration | v0.21.0 (cœur) | 1-2 sessions |
| **E6.c.2** | `nemeton` | `R/fordead_postprocess.R`, `FORDEAD_CONFIDENCE_WEIGHTS`, `classify_disturbance`, migration `0002_fordead.sql` | v0.21.0 (cœur) | 1 session |
| **E6.c.3** | `nemeton` | `R/fordead_validity.R`, `inst/extdata/fordead_validity_zones.geojson`, script `data-raw/` | v0.21.0 (cœur) | 1 session |
| **E6.d** | `nemeton` | `R/indicators-deperissement.R` (R5), tests | v0.21.0 (cœur) | 1 session |
| **E6.c.4** | `nemeton` | `R/health_validation.R` (schéma QField sanitaire, génération placettes, ingestion validation) | v0.21.0 (cœur) | 1-2 sessions |
| **E6.c.5** | `nemetonshiny` | Mode sanitaire dans `mod_monitoring`, bannières G3, génération placettes via UI, sous-onglet Validation dans `mod_field_ingest` | v0.21.0 (app) | 2 sessions |
| **E6.f** | `nemetonshiny` | Smoke `shinytest2`, polish, release v0.21.0 | v0.21.0 | court |

---

## 6. Dépendances et risques

### 6.1 Dépendances externes

- **fordead** (PyPI, GPL-3) : verrouillé sur 2.1.x. Si breaking change en 2.2 → spec 008 v0.2.0 et adapter.
- **CDSE** (Copernicus Data Space Ecosystem) : déjà utilisé via E6.a. fordead peut aussi consommer ces images (eodag avec provider configuré).
- **BD Forêt v2 IGN** : déjà cité dans nemeton (`R/datasources.R`). Ajout d'un cache local pour le forest_mask.
- **API geo.api.gouv.fr** : utilisée une seule fois pour construire `fordead_validity_zones.geojson`. Pas de dépendance runtime.

### 6.2 Risques identifiés et mitigations

| Risque | Probabilité | Mitigation |
|--------|-------------|------------|
| reticulate / Python venv mal configuré sur poste utilisateur | élevée | `.ensure_fordead_python()` idempotent + message d'erreur exhaustif (versions, paths, comment installer) |
| GPL-3 contamine MIT | faible | Appel runtime, pas linking. fordead en `Suggests`, pas `Imports`. Avis dans `inst/NOTICE`. |
| FORDEAD trop lent sur grosse AOI | moyenne | Documenter limites de scaling ; ExtendedTask + future_promise pour ne pas bloquer l'UI ; v+1 = tiling explicite |
| Migration `0002_fordead.sql` casse l'existant | faible | `ADD COLUMN IF NOT EXISTS` partout ; compatible avec installations v0.20.x ; testé en intégration |
| Calibration FORDEAD invalide pour la zone utilisateur | élevée | G3 (bannières) + filtrage par défaut classes 3+4 (G1) + R5 NA hors zone validité (G5) |
| Confusion utilisateur entre les 2 modes | moyenne | UI explicite (toggle visible, descriptions intégrées, exemples dans la doc utilisateur) |

---

## 7. Plan de tests

Voir `spec.md` §9 pour la liste détaillée. Récap :

- ~120 nouvelles assertions cœur (8 nouveaux fichiers test)
- ~60 nouvelles assertions app (extensions `test-mod_monitoring`, `test-mod_field_ingest`)
- 1 scénario shinytest2 E2E (mocké pour FORDEAD car run réel = trop long pour CI)

Couverture cible : **85%** sur les nouveaux fichiers (objectif aligné avec spec 005).

---

## 8. Critères d'acceptation v0.21.0

- ☐ `nemeton::run_fordead_dieback()` fonctionne sur l'AOI test (Vosges, ~10 ha, données figées dans `tests/fixtures/`)
- ☐ Les 5 garde-fous G1-G5 sont opérationnels et testés
- ☐ La migration `0002_fordead.sql` s'applique sans erreur sur une DB v0.20.x existante
- ☐ R5 figure dans le radar quand FORDEAD a tourné, NA sinon
- ☐ Le workflow QField de validation est exécutable de bout en bout (UI + cœur + DB)
- ☐ Les bannières géo + essences s'affichent correctement (3 cas test : Vosges OK, Massif Central avertissement, Brie invalide)
- ☐ La suite complète passe : nemeton 5800+ PASS, nemetonshiny 5400+ PASS
- ☐ NEWS, DESCRIPTION, CITATION, PLAN.md à jour
- ☐ Tag `v0.21.0` poussé, GitHub release publiée

---

## 9. Migration fordead 2.x (cible v0.23.0)

**Statut** : paperwork validé 2026-05-16. Code à venir. Référence : spec 008 §12.

### 9.1 Stack — diffs

`inst/python/requirements.txt` :

```
- fordead @ git+https://gitlab.com/fordead/fordead_package@v1.11.4
+ fordead @ git+https://gitlab.com/fordead/fordead_package@v2.1.1
  # simplestac est pulled comme dépendance transitive de fordead 2.x.
  # On l'épingle aussi en explicite pour traçabilité.
+ simplestac @ git+https://forge.inrae.fr/umr-tetis/stac/simplestac@v1.2.5
```

Le reste des deps (xarray, dask, rasterio, eodag, numpy, pandas, geopandas, shapely) reste identique — fordead 2.x les a toujours en transitif.

### 9.2 Pipeline R — réécriture de §2.2

```r
run_fordead_dieback <- function(aoi, dates_training, dates_monitoring,
                                vegetation_index = "CRSWIR",
                                threshold_anomaly = 0.16,
                                output_dir = tempfile("fordead_"),
                                cache_dir = NULL,       # NEW — chemin vers
                                                        # ingest_sentinel2_timeseries cache
                                ...,
                                progress_callback = NULL) {

  fd       <- .ensure_fordead_python(verbose = verbose)  # fordead 2.x module
  simplestac <- reticulate::import("simplestac", convert = FALSE)
  pystac     <- reticulate::import("pystac",     convert = FALSE)

  # Phase 1 — STAC ASSEMBLY (R side)
  begin_phase("stac_assembly")
  items <- .build_stac_collection_for_aoi(
    aoi              = aoi,
    dates            = c(dates_training, dates_monitoring),
    cache_dir        = cache_dir,
    bands_required   = c("B02","B04","B05","B8A","B11","B12")
  )
  # items est une list R de pystac.Item Python objects, chaque item ayant :
  #   - id    = "fordead_YYYYMMDD"
  #   - datetime, geometry, bbox
  #   - assets["B02"]..["B12"] = pystac.Asset(href = "<cache_dir>/{scene}/B0X.tif",
  #                                            roles = ["data"],
  #                                            extra_fields = {nodata, scale, offset})
  collection <- simplestac$ItemCollection(items)
  end_phase("stac_assembly")

  # Phase 2 — FordeadProcess construction + fit (training)
  cfg <- .build_fordead_config(dates_training, dates_monitoring,
                               vegetation_index, threshold_anomaly)
  fp <- fd$workflow$FordeadProcess(
    collection = collection,
    output_dir = output_dir,
    bbox       = .aoi_bbox_4326(aoi),
    geometry   = .aoi_geometry_reticulate(aoi),
    config     = cfg
  )

  begin_phase("fit")
  .capture("fit", { fp$fit() })            # writes fit/model.tif, fit/modelled_pixels.tif
  end_phase("fit")

  # Phase 3 — predict (monitoring)
  begin_phase("predict")
  .capture("predict", { fp$predict() })    # writes ANOMALY_CONFIRMED, ANOMALY_INDEX, etc.
  end_phase("predict")

  # Phase 4 — postprocess (E6.c.2 adapté aux nouveaux chemins)
  begin_phase("postprocess")
  alerts_sf <- .postprocess_fordead_rasters(
    output_dir,
    status_layer = "ANOMALY_CONFIRMED",
    stress_layer = "ANOMALY_INDEX",
    fordead_utils = fd$utils      # pour backward_start()
  )
  if (!is.null(con)) .insert_fordead_alerts(con, alerts_sf, zone_id)
  end_phase("postprocess")

  list(status = "success",
       output_dir = output_dir,
       rasters    = list(
         state              = .latest_layer_file(output_dir, "ANOMALY_CONFIRMED"),
         first_dieback_date = .compute_first_dieback_date(output_dir, fd$utils),
         stress_index       = .latest_layer_file(output_dir, "ANOMALY_INDEX")
       ),
       alerts_sf  = alerts_sf,
       fordead_version = "2.1.1",
       duration_sec    = as.numeric(Sys.time() - t0, units = "secs"))
}
```

Trois nouveaux helpers privés :

* **`.build_stac_collection_for_aoi(aoi, dates, cache_dir, bands_required)`** — itère sur `cache_dir/{scene_id}/{band}.tif` qui matchent les dates, construit un `pystac.Item` par scène via reticulate (`pystac$Item(id=..., geometry=..., bbox=..., datetime=..., properties=list(...))` + `item$add_asset(band, pystac$Asset(href=..., extra_fields=...))`). Le `obs_pixel` DB n'est pas utilisé directement — on lit depuis le cache disque (les obs_pixel rows sont juste agrégées par placette ; pour fordead on a besoin du raster scène complet).
* **`.aoi_bbox_4326(aoi)`** — utilitaire qui retourne `c(xmin, ymin, xmax, ymax)` de `aoi` reproj en EPSG:4326.
* **`.aoi_geometry_reticulate(aoi)`** — convertit l'`sf` polygone en `shapely.geometry` via `reticulate::r_to_py()` ou via WKT round-trip. Permet de clipper précisément (fordead 2.x supporte une `geometry` shapely en plus du bbox).
* **`.build_fordead_config(...)`** — construit le `FordeadConfig` Python en surchargeant uniquement les champs exposés en API R (training dates, monitoring dates, threshold, vegetation_index). Le reste vient des défauts ONF/DSF — conformes à ADR-013.
* **`.latest_layer_file(output_dir, layer)`** — renvoie `<output_dir>/<layer>/fordead_<max(YYYYMMDD)>_<layer>.tif`.
* **`.compute_first_dieback_date(output_dir, fd_utils)`** — pile les rasters `ANOMALY_CONFIRMED/*.tif` en RAM, appelle `fd_utils$backward_start(arr)` (équivalent fordead du `first_dieback_date` 1.x), retourne un SpatRaster en mémoire.

### 9.3 Postprocess (§E6.c.2) — diffs

`R/fordead_postprocess.R::.classify_pixels_to_classes()` lit les valeurs 0-3 de `state.tif` (1.x) et les mappe sur 4 classes de confiance. Avec fordead 2.x, le raster `ANOMALY_CONFIRMED` contient des valeurs 0-1 (binaire confirmed/not), et `CONSECUTIVE_DETECTIONS` contient le compteur. Mapping mis à jour :

```r
# 1.x : state ∈ {0, 1, 2, 3}  →  classe ∈ {0=sain, 1=faible, 2=moyen, 3=fort}
# 2.x : status = ANOMALY_CONFIRMED * CONSECUTIVE_DETECTIONS_capped
#       0      → sain
#       1-3    → 1=faible
#       4-6    → 2=moyenne
#       7-9    → 3=forte
#       ≥10    → 4=sol_nu  (avec STOP_CONFIRMED == TRUE)
```

À calibrer empiriquement sur un AOI test ; intégré dans AC.12.3.

### 9.4 Tests — refonte

`test-fordead-pipeline.R` (44 tests offline mockés) :
- ❌ Suppression des fixtures `step` (`step1_compute_masked_vegetationindex`, etc.) — ces submodules n'existent plus.
- ✅ Remplacement par un fixture `fp_class_factory()` qui retourne une stub R6-like avec méthodes `fit()`, `predict()`, `export_layer()` enregistrables et inspectables.
- ✅ 12 nouveaux tests offline : construction `ItemCollection`, propagation des kwargs vers `FordeadConfig`, capture des phases `stac_assembly / fit / predict / postprocess`, gestion d'erreur (StacAssembly fail → status="error", phase="stac_assembly").

`test-fordead-integration.R` (NOUVEAU, ≥ 2 tests `skip_if_no_fordead()`) :
- Test 1 : pipeline complet sur fixture mini (5 dates synthétiques, 100×100 px, CRSWIR pré-calculé). Vérifier qu'au moins un fichier `<out>/ANOMALY_CONFIRMED/*.tif` existe et que `terra::rast()` l'ouvre.
- Test 2 : pipeline avec AOI à l'extérieur de la collection → erreur explicite, pas de crash silencieux.

Helper `skip_if_no_fordead()` :

```r
skip_if_no_fordead <- function() {
  testthat::skip_if_not_installed("reticulate")
  ok <- tryCatch({
    fd <- reticulate::import("fordead", convert = FALSE)
    !is.null(reticulate::py_get_attr(fd, "workflow", silent = TRUE))
  }, error = function(e) FALSE)
  if (!isTRUE(ok)) testthat::skip("fordead.workflow not importable")
}
```

### 9.5 Risque résiduels — mitigations

| Risque | Mitigation |
|--------|------------|
| `simplestac` v1.2.5 est aussi pin git-only (forge.inra.fr) — disponibilité du serveur | Identique au pin fordead. Si forge.inra.fr down, install échoue avec erreur clair (réseau). Pas spécifique à 2.x. |
| Hrefs PC SAS expirent pendant `fp$fit()` (run long) | fordead 2.x délègue à `simplestac.ItemCollection.to_xarray()` qui utilise xarray + rasterio lazy load. À l'évaluation effective (compute_spectral_index), les hrefs déjà signés peuvent expirer si > 30 min. **Mitigation** : `cache_dir` local (les COGs sont déjà sur disque grâce à `ingest_sentinel2_timeseries(..., cache_dir = ...)`) → les hrefs passés au `pystac.Asset` sont des chemins locaux, pas des URLs PC. Plus de problème de SAS expiry. **Conséquence** : `run_fordead_dieback(cache_dir = ...)` devient quasi-obligatoire si on veut éviter les re-téléchargements VSI. |
| FordeadConfig pydantic — validation stricte | Construire la config en Python via `fd$config$FordeadConfig(...)` avec named args — pas via `reticulate::r_to_py(list(...))` qui peut échouer sur certains types. |
| Backward compat des tests R5 (`test-indicators-deperissement.R`) | Le mapping confidence_class du postprocess change (§9.3). Fixture des alertes doit être régénérée. AC.12.4 vérifie qu'on reste vert. |

### 9.6 Estimation effort

| Lot | Effort |
|-----|--------|
| `.build_stac_collection_for_aoi` + helpers reticulate | 4 h |
| `.build_fordead_config` + plumbing kwargs | 2 h |
| Refonte `run_fordead_dieback` (les 4 phases) | 3 h |
| Postprocess remapping confidence (§9.3) | 3 h |
| Tests offline refactor (12 nouveaux) | 3 h |
| Tests intégration `skip_if_no_fordead` (2) | 2 h |
| NEWS + DESCRIPTION + PLAN + release | 1 h |
| **Total** | **~18 h** (2-3 sessions) |

---

## 10. Amendement A2 — Intégration FORDEAD ↔ ingest FAST (cible v0.24.0)

**Date** : 2026-05-16
**Spec correspondante** : `spec.md` §13
**Statut** : approuvé (paperwork avant code, règle utilisateur du 2026-04-26)
**Concerne** : §9 (amendement A1 / v0.23.0) — refonte de la signature publique de `run_fordead_dieback()` et ajout d'une phase d'ingest interne. Aucun garde-fou G1-G5 (§5 spec), aucune logique R5 (§6 spec), aucune calibration ADR-013 ne change.

### 10.1 Objectif

Traduire la décision §13.2 de la spec en :

1. Une nouvelle signature publique pour `run_fordead_dieback()` (con + zone_id + cache_dir au lieu de aoi + scenes_df + cache_dir).
2. Un nouveau helper `.get_zone_aoi(con, zone_id)` qui dérive l'AOI sf depuis la table `monitoring_zone`.
3. Une constante exportée `FORDEAD_BANDS` qui matérialise la liste des 6 bandes Sentinel-2 requises par CRSWIR + masques fordead 2.x.
4. Une phase d'ingest interne qui délègue à `ingest_sentinel2_timeseries()` (skip_cached partial-coverage-aware) et propage ses événements `s2:*` au callback utilisateur.

Tout le reste — helpers de session 1 v0.23.0 (`.build_stac_collection_for_aoi`, `.build_fordead_config`, `.aoi_bbox_4326`, `.aoi_geometry_reticulate`), helpers de session 2 v0.23.0 (`.list_layer_files`, `.latest_layer_file`, `.fordead_2x_status_to_classes`, `.compute_first_dieback_date`, `.postprocess_fordead_rasters`), postprocess mapping (§9.3) — strictement inchangé.

### 10.2 Pipeline R — réécriture de §9.2

```r
#' Constante exportée — liste des bandes Sentinel-2 requises par FORDEAD 2.x
#' (CRSWIR + masques). Diffère de FAST (qui utilise B04, B08, B12).
#' @export
FORDEAD_BANDS <- c("B02", "B04", "B05", "B8A", "B11", "B12")

run_fordead_dieback <- function(con,                       # NEW required
                                zone_id,                   # NEW required
                                cache_dir,                 # required
                                dates_training,
                                dates_monitoring,
                                vegetation_index   = "CRSWIR",
                                threshold_anomaly  = 0.16,
                                output_dir         = tempfile("fordead_"),
                                min_pixels         = 30L,
                                connectivity       = 8L,
                                verbose            = FALSE,
                                progress_callback  = NULL) {

  t0 <- Sys.time()
  .check_dates_pair(dates_training,   "dates_training")
  .check_dates_pair(dates_monitoring, "dates_monitoring")
  stopifnot(inherits(con, "DBIConnection"))
  stopifnot(is.character(zone_id), length(zone_id) == 1L, nzchar(zone_id))
  stopifnot(is.character(cache_dir), length(cache_dir) == 1L, nzchar(cache_dir))

  emit <- .make_phase_emitter(progress_callback)
  emit("fordead:start", list(zone_id = zone_id))

  # ---- PHASE 0 — ingest (NOUVEAU v0.24.0) -----------------------------
  emit("fordead:phase",      list(phase = "ingest"))
  ingest_res <- ingest_sentinel2_timeseries(
    con               = con,
    zone_id           = zone_id,
    bands             = FORDEAD_BANDS,
    date_from         = dates_training[1],
    date_to           = dates_monitoring[2],
    cache_dir         = cache_dir,
    skip_cached       = TRUE,
    progress_callback = progress_callback   # s2:* events traversent directement
  )
  scenes_df <- ingest_res$scenes_df
  emit("fordead:phase_done", list(phase = "ingest",
                                  n_scenes = nrow(scenes_df)))

  # ---- PHASE 1 — stac_assembly (inchangé v0.23.0) ---------------------
  emit("fordead:phase", list(phase = "stac_assembly"))
  aoi <- .get_zone_aoi(con, zone_id)                       # NEW helper
  collection <- .build_stac_collection_for_aoi(
    aoi             = aoi,
    scenes_df       = scenes_df,
    cache_dir       = cache_dir,
    bands_required  = FORDEAD_BANDS
  )
  cfg <- .build_fordead_config(dates_training, dates_monitoring,
                               vegetation_index, threshold_anomaly)
  emit("fordead:phase_done", list(phase = "stac_assembly"))

  # ---- PHASES 2-4 — fit / predict / postprocess (inchangé v0.23.0) ----
  fd <- .ensure_fordead_python(verbose = verbose)
  fp <- fd$workflow$FordeadProcess(
    collection = collection,
    output_dir = output_dir,
    bbox       = .aoi_bbox_4326(aoi),
    geometry   = .aoi_geometry_reticulate(aoi),
    config     = cfg
  )

  emit("fordead:phase", list(phase = "fit"));        fp$fit();        emit("fordead:phase_done", list(phase = "fit"))
  emit("fordead:phase", list(phase = "predict"));    fp$predict();    emit("fordead:phase_done", list(phase = "predict"))

  emit("fordead:phase", list(phase = "postprocess"))
  alerts_sf <- .postprocess_fordead_rasters(output_dir, fordead_utils = fd$utils)
  .insert_fordead_alerts(con, alerts_sf, zone_id)
  emit("fordead:phase_done", list(phase = "postprocess"))

  emit("fordead:complete", list(duration_sec = as.numeric(Sys.time() - t0, units = "secs")))

  list(
    status          = "success",
    output_dir      = output_dir,
    zone_id         = zone_id,
    n_scenes        = nrow(scenes_df),
    rasters         = list(
      state              = .latest_layer_file(output_dir, "ANOMALY_CONFIRMED"),
      first_dieback_date = .compute_first_dieback_date(output_dir, fd$utils),
      stress_index       = .latest_layer_file(output_dir, "ANOMALY_INDEX")
    ),
    alerts_sf       = alerts_sf,
    fordead_version = "2.1.1",
    duration_sec    = as.numeric(Sys.time() - t0, units = "secs")
  )
}
```

### 10.3 Helper `.get_zone_aoi(con, zone_id)` — nouveau

Fichier : `R/fordead_pipeline.R` (à côté de `run_fordead_dieback`, pas un fichier dédié — trop court).

```r
.get_zone_aoi <- function(con, zone_id) {
  stopifnot(inherits(con, "DBIConnection"),
            is.character(zone_id), length(zone_id) == 1L, nzchar(zone_id))

  row <- DBI::dbGetQuery(con,
    "SELECT id, ST_AsText(aoi) AS wkt, ST_SRID(aoi) AS srid
       FROM monitoring_zone
      WHERE id = $1", params = list(zone_id))

  if (nrow(row) == 0L) {
    cli::cli_abort(c("Zone de suivi inconnue.",
                     "x" = "zone_id = {.val {zone_id}}",
                     "i" = "Vérifier {.fun list_monitoring_zones}."))
  }

  sf_obj <- sf::st_sf(
    geometry = sf::st_sfc(sf::st_as_sfc(row$wkt)[[1L]], crs = row$srid),
    crs      = row$srid
  )
  if (sf::st_crs(sf_obj)$epsg != 2154L) {
    sf_obj <- sf::st_transform(sf_obj, 2154L)
  }
  sf_obj
}
```

Notes :

* La table `monitoring_zone` est créée par migration `0002_fordead.sql` (cf. §8.3 spec). Colonne `aoi` est `geometry(POLYGON, 2154)` mais on lit en WKT + SRID pour découpler du driver.
* En cas de zone manquante, message d'erreur typé via `cli::cli_abort()` — déjà le pattern utilisé partout dans `nemeton`.
* Test mocké : `local_mocked_bindings(dbGetQuery = function(...) data.frame(id="Z1", wkt="POLYGON((...))", srid=2154L), .package = "DBI")`.

### 10.4 Constante exportée `FORDEAD_BANDS`

Déclarée en tête de `R/fordead_pipeline.R` avec roxygen :

```r
#' Bandes Sentinel-2 requises par FORDEAD 2.x
#'
#' Liste des 6 bandes nécessaires pour calculer l'indice CRSWIR
#' (B11, B8A, B12) et les masques de qualité (B02 réflectance bleue,
#' B04 rouge, B05 vegetation red edge). Diffère du pipeline rapide
#' FAST (qui utilise B04, B08, B12 pour NDVI/NBR).
#'
#' La phase d'ingest interne de [run_fordead_dieback()] passe cette
#' liste à [ingest_sentinel2_timeseries()] avec `skip_cached = TRUE`,
#' de sorte que les bandes déjà téléchargées par FAST (B04, B12) sont
#' réutilisées et seules les manquantes (B02, B05, B8A, B11) sont
#' descendues.
#'
#' @export
#' @examples
#' FORDEAD_BANDS
FORDEAD_BANDS <- c("B02", "B04", "B05", "B8A", "B11", "B12")
```

Ajouté à NAMESPACE via `@export` après `devtools::document()`.

### 10.5 Tests — refonte

`test-fordead-pipeline.R` — adaptations :

* ❌ Supprimer les fixtures `aoi` et `scenes_df` passés en paramètre.
* ✅ Mock `ingest_sentinel2_timeseries` via `local_mocked_bindings()` pour retourner un `scenes_df` stub avec 5 scènes synthétiques.
* ✅ Mock `.get_zone_aoi` via `local_mocked_bindings()` pour retourner un `sf` POLYGON synthétique en EPSG:2154.
* ✅ 4 nouveaux tests :
  * `run_fordead_dieback() émet fordead:phase(ingest) en premier` — vérifier ordre des événements `fordead:*`.
  * `phase ingest propage s2:* events au callback` — observer que les événements `s2:scene_cached` passent intacts.
  * `run_fordead_dieback() erreur si zone_id inconnu` — `.get_zone_aoi` lance cli_abort.
  * `FORDEAD_BANDS contient les 6 bandes attendues` — sanity check de la constante exportée.

`test-fordead-stac.R` — inchangé (les helpers `.build_stac_collection_for_aoi`, `.build_fordead_config`, `.aoi_bbox_4326` sont indépendants de la signature publique).

`test-fordead-outputs.R` — inchangé.

`test-fordead-integration.R` (NOUVEAU en v0.23.0, mis à jour) :

* Test 1 : call `run_fordead_dieback(con = test_con, zone_id = "Z_DEMO", cache_dir = cache_dir, dates_training = ..., dates_monitoring = ...)` avec `test_con` une connexion SQLite/DuckDB jetable (cf. fixture `setup_test_db()` partagée avec `test-monitoring-*.R`). Vérifier `status == "success"`.
* Test 2 : zone_id inconnu → erreur `"Zone de suivi inconnue"`.

Helper `setup_test_db()` factorisé dans `tests/testthat/helper-test-db.R` (déjà utilisé par `test-monitoring-*.R` depuis v0.22.0 — pas un ajout v0.24.0).

### 10.6 Risques résiduels et mitigations

| Risque | Mitigation |
|--------|------------|
| `ingest_sentinel2_timeseries(skip_cached=TRUE)` ne respecte pas la garantie partial-coverage par bande | Couvert par les tests v0.21.3 dans `test-monitoring-ingest.R` — pas de régression à craindre. AC.13.3 le re-vérifie à l'usage. |
| Hrefs PC SAS expirent pendant la phase 0 ingest puis le STAC pointe vers du cache local (pas d'expiry après) | Inchangé vs v0.23.0 — déjà mitigé par cache_dir local en phase stac_assembly. |
| `monitoring_zone` n'existe pas (utilisateur sur DB < v0.21.0) | `.get_zone_aoi` retourne 0 row → cli_abort typé. Le caller (app) doit avoir tourné la migration `0002_fordead.sql`. À tester explicitement par AC.13.1 sur la zone de prod de l'utilisateur. |
| Breaking change non documenté côté app → erreur runtime | AC.13.5 + section §13.8 de la spec : migration côté `nemetonshiny@v0.33.0` synchronisée. Le NEWS.md `0.24.0` mentionne explicitement le breaking. |
| Phase 0 longue (téléchargement de 4 bandes manquantes × N scènes) sans feedback | Les événements `s2:*` traversent le callback utilisateur — l'app affiche déjà les toasts pour FAST depuis v0.32.0, donc 0 dev côté UI pour avoir le feedback. |

### 10.7 Migration côté app `nemetonshiny@v0.33.0`

Diff prévisible côté `R/mod_monitoring.R` :

```diff
- res <- nemeton::run_fordead_dieback(
-   aoi              = aoi,
-   scenes_df        = scenes_df,
-   cache_dir        = cache_dir,
-   dates_training   = input$training_dates,
-   dates_monitoring = input$monitoring_dates,
-   progress_callback = fordead_progress_cb()
- )
+ res <- nemeton::run_fordead_dieback(
+   con              = con,
+   zone_id          = input$zone_id,
+   cache_dir        = cache_dir,
+   dates_training   = input$training_dates,
+   dates_monitoring = input$monitoring_dates,
+   progress_callback = fordead_progress_cb()
+ )
```

Clé i18n à ajouter (FR / EN) :

```r
monitoring_fordead_phase_ingest = c(
  fr = "Téléchargement des bandes manquantes...",
  en = "Downloading missing bands..."
)
```

Aucun rework du composant toast — il est déjà générique sur les événements `fordead:phase`.

### 10.8 Estimation effort

| Lot | Effort |
|-----|--------|
| `FORDEAD_BANDS` constante + `.get_zone_aoi()` helper + roxygen + export | 1 h |
| Refonte signature `run_fordead_dieback()` + phase ingest + plumbing emit | 2 h |
| Tests offline mockés (4 nouveaux + adaptation des existants) | 2 h |
| Tests intégration `test-fordead-integration.R` mise à jour | 1 h |
| NEWS + DESCRIPTION + PLAN journal + release v0.24.0 | 1 h |
| **Total** | **~7 h** (1 session) |
