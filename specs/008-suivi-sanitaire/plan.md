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
  fordead==2.1.4
  xarray>=2024.0
  dask[complete]>=2024.0
  rasterio>=1.3.0
  eodag>=3.0
  numpy>=1.26
  pandas>=2.0
  geopandas>=0.14
  shapely>=2.0
  ```
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
