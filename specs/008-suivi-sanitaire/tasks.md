# Tâches d'implémentation : Suivi sanitaire (spec 008)

**Version** : 0.1.0
**Date**    : 2026-04-26
**Spec**    : `spec.md` v0.1.0 · **Plan** : `plan.md` v0.1.0
**Cible**   : `nemeton` v0.21.0 + `nemetonshiny` v0.21.0
**Total**   : 71 tâches (53 cœur + 18 app)

Conventions :
- `[P]` = parallélisable avec les autres `[P]` du même chantier
- IDs : `T{chantier}.{n}` (ex. T6c1.3 = chantier E6.c.1, tâche 3)
- Réfs fichier : `path:line` quand connue, sinon `path`

---

## Chantier E6.b phases 2-6 (`nemetonshiny`)

Couvre l'achèvement de la couche **Surveillance rapide** (mode 1) commencée en E6.b phase 1. Doit être livré avant ou en parallèle d'E6.c. Détails dans le PLAN.md à la racine du repo `nemeton`.

(Hors scope spec 008, listé pour rappel.)

---

## Chantier E6.c.1 — Pipeline FORDEAD via reticulate (cœur)

Branche : `feat/008-fordead-pipeline`

### 1.1 Helpers reticulate

- [ ] T6c1.1 Créer `R/fordead_python.R` avec squelette + roxygen header
- [ ] T6c1.2 `.ensure_fordead_python(env_name = "nemeton-fordead")` : crée le venv si absent, installe `inst/python/requirements.txt`, retourne le module fordead. Idempotent.
- [ ] T6c1.3 `.use_fordead_env()` : bascule reticulate sur le bon venv (`reticulate::use_virtualenv()`)
- [ ] T6c1.4 [P] Créer `inst/python/requirements.txt` avec versions pinnées (cf. plan.md §1.3)
- [ ] T6c1.5 Vérification système : Python ≥ 3.10 requis, message d'erreur explicite si absent
- [ ] T6c1.6 Tests `tests/testthat/test-fordead-python.R` (5-8 tests, mocked) : skip if reticulate absent ; idempotence ; gestion d'erreur si Python missing

### 1.2 Orchestrateur `run_fordead_dieback`

- [ ] T6c1.7 Créer `R/fordead_pipeline.R` avec squelette + roxygen header
- [ ] T6c1.8 Signature `run_fordead_dieback(aoi, dates_training, dates_monitoring, vegetation_index = "CRSWIR", threshold_anomaly = 0.16, forest_mask = NULL, output_dir = tempfile(), python_env = NULL, con = NULL)` (cf. plan.md §2.1)
- [ ] T6c1.9 Validation des arguments : aoi sf POLYGON EPSG:2154 ; dates valides et chronologiques ; threshold_anomaly ∈ [0.05, 0.50] ; vegetation_index ∈ {"CRSWIR", "NDVI", "NDWI"}
- [ ] T6c1.10 Phase 1 : compute_masked_vegetationindex (appel Python via reticulate)
- [ ] T6c1.11 Phase 2 : train_model
- [ ] T6c1.12 Phase 3 : forest_mask (cache local BD Forêt v2 si non fourni). Helper `.download_or_use_cached_bd_foret(aoi)`
- [ ] T6c1.13 Phase 4 : dieback_detection
- [ ] T6c1.14 Phase 5 : export_results
- [ ] T6c1.15 Capture des logs Python via `reticulate::py_capture_output()` → cli_alert_info pendant l'exécution
- [ ] T6c1.16 Retour structuré (`list(status, output_dir, rasters, alerts_sf, n_alerts_inserted, duration_sec, python_env, fordead_version)`)
- [ ] T6c1.17 Gestion d'erreurs : tryCatch global, retour `status = "error"` + message
- [ ] T6c1.18 Doc roxygen complète + 1 exemple `\dontrun{}`

### 1.3 Tests d'orchestration

- [ ] T6c1.19 `tests/testthat/test-fordead-pipeline.R` : 8-12 tests avec phases mockées (`local_mocked_bindings` sur les calls reticulate). Vérifie l'ordre, la propagation d'erreur, le format de retour.

---

## Chantier E6.c.2 — Post-processing + intégration DB (cœur)

Branche : `feat/008-fordead-postprocess`

### 2.1 Migration SQL

- [ ] T6c2.1 Créer `inst/db/migrations/0002_fordead.sql` (cf. spec.md §8.3)
- [ ] T6c2.2 Vérifier la migration en intégration : ajouter un test à `tests/testthat/test-db.R` (idempotence, présence des nouvelles colonnes)
- [ ] T6c2.3 Mettre à jour `with_clean_db()` dans `helper-monitoring.R` pour drop les nouveaux index

### 2.2 Constantes et coefficients

- [ ] T6c2.4 Créer `R/fordead_postprocess.R` avec roxygen header
- [ ] T6c2.5 Constante `FORDEAD_CONFIDENCE_WEIGHTS` documentée (cite Bernard & Doridant 2024)
- [ ] T6c2.6 Constante `FORDEAD_CLASSES` (vecteur ordonné des 5 classes : "0-hors-anomalie" → "4-sol-nu")

### 2.3 Conversion raster → POINT clusters

- [ ] T6c2.7 `.classify_pixels_to_classes(state_raster)` : réinterprète les valeurs de state en classes ordinales
- [ ] T6c2.8 `.cluster_anomaly_pixels(class_raster, min_pixels = 5, connectivity = 8)` : agrège les pixels en clusters via `terra::patches()`
- [ ] T6c2.9 `.cluster_to_centroids(clusters, stress_index_raster, first_dieback_date_raster)` : retourne sf POINT enrichi de `confidence_class`, `stress_index`, `trigger_date`, `n_pixels`, `area_m2`
- [ ] T6c2.10 [P] Tests : `tests/testthat/test-fordead-postprocess.R` (12-15 tests) avec rasters synthétiques

### 2.4 Insertion dans `alert`

- [ ] T6c2.11 `.insert_fordead_alerts(con, alerts_sf, zone_id)` : INSERT en bulk via TEMP staging + ON CONFLICT DO NOTHING
- [ ] T6c2.12 `alert_type = "fordead_dieback"` ; `confidence_class` mappée ; `stress_index` populé
- [ ] T6c2.13 Test d'intégration (`with_clean_db`) : insertion + idempotence + vérification des champs

### 2.5 Logique de fusion

- [ ] T6c2.14 `classify_disturbance(alerts_df, window_days = 30)` exporté (cf. plan.md §3)
- [ ] T6c2.15 [P] Tests : 8-10 tests sur des dataframes synthétiques

### 2.6 Helper de listing pour l'UI

- [ ] T6c2.16 `list_alerts(con, zone_id, classes = c("3-forte", "4-sol-nu"), validation_status = NULL, period = NULL)` exporté
- [ ] T6c2.17 [P] Test d'intégration : 5-6 cas

---

## Chantier E6.c.3 — Validity zones (cœur)

Branche : `feat/008-fordead-validity`

### 3.1 Construction de `fordead_validity_zones.geojson`

- [ ] T6c3.1 Créer `data-raw/build_fordead_validity_zones.R` :
  - fetch geo.api.gouv.fr pour codes 88, 39, 01, 73, 74
  - union, simplification (dTolerance = 100), reprojection EPSG:4326
  - écriture `inst/extdata/fordead_validity_zones.geojson`
  - script reproductible, fait partie du repo
- [ ] T6c3.2 Lancer le script et committer le GeoJSON résultat
- [ ] T6c3.3 Test `tests/testthat/test-fordead-validity-zones.R` : le fichier charge, contient au minimum 5 polygones (ou 1 multipolygon = union des 5 départements), surface totale dans la fourchette attendue

### 3.2 Helper de vérification

- [ ] T6c3.4 Créer `R/fordead_validity.R` avec roxygen header
- [ ] T6c3.5 `load_fordead_validity_zones()` : charge et cache la geojson (sf, EPSG:4326)
- [ ] T6c3.6 `check_fordead_validity(aoi, units = NULL, threshold_geo = 0.5, threshold_species = 0.7, min_resineux = 0.3)` retourne :
  ```r
  list(geo_valid = TRUE/FALSE, geo_intersection_pct = 0.87,
       species_valid = TRUE/FALSE, species_resineux_pct = 0.78,
       species_epc_pct = 0.42, species_sap_pct = 0.36,
       overall_valid = TRUE/FALSE)
  ```
- [ ] T6c3.7 La logique espèce s'appuie sur des attributs `essence_dominante` ou `composition` sur les units. Documenter le contrat d'entrée.
- [ ] T6c3.8 Tests `tests/testthat/test-fordead-validity.R` (10-12 tests) : Vosges → valid ; Massif Central → géo invalid ; Brie → géo invalid ET espèces invalid ; mix → flags partiels

---

## Chantier E6.d — Indicateur R5 dépérissement (cœur)

Branche : `feat/008-r5-deperissement`

### 4.1 Calcul

- [ ] T6d.1 Créer `R/indicators-deperissement.R` avec roxygen header
- [ ] T6d.2 `indicateur_r5_deperissement(units, fordead_results, weights = FORDEAD_CONFIDENCE_WEIGHTS, min_resineux = 0.3, include_low_classes = FALSE)`
- [ ] T6d.3 Validation : `units` est sf, `fordead_results$alerts_sf` ou raster `state` doit être présent
- [ ] T6d.4 Pour chaque UGF : check_fordead_validity (espèces seulement, géo déjà filtré en amont) ; si invalide → R5 = NA
- [ ] T6d.5 Pour chaque UGF valide : intersection avec les clusters d'anomalie (par classe), somme pondérée des surfaces, divisé par surface UGF, plafonné à 1
- [ ] T6d.6 Retour : sf identique à `units` avec colonnes `r5_deperissement` (numeric) et `r5_status` (`"calculated" | "skipped_no_resineux" | "skipped_no_fordead"`)
- [ ] T6d.7 Doc roxygen + exemple

### 4.2 Intégration radar

- [ ] T6d.8 Mettre à jour `R/family-system.R::compute_family_index(family = "R", ...)` : si la colonne `r5_deperissement` existe et n'est pas tout NA, l'inclure dans la moyenne R1..R5 ; sinon R1..R4
- [ ] T6d.9 [P] Vérifier que `compute_general_index_mixed()` (NDP augmenté) propage le flag `health_fordead`

### 4.3 Tests

- [ ] T6d.10 `tests/testthat/test-indicators-deperissement.R` : 18-20 assertions
  - cas vide (pas de fordead_results) → R5 = NA partout
  - cas mono-classe (100% classe 3-forte couvrant 50% de l'UGF) → R5 = 0.41
  - cas multi-classes
  - UGF avec < 30% résineux → R5 = NA, status = `skipped_no_resineux`
  - inclusion des classes 1-2 via `include_low_classes = TRUE`
  - plafonnement (ne dépasse jamais 1.0)

---

## Chantier E6.c.4 — Workflow QField de validation (cœur)

Branche : `feat/008-health-validation`

### 5.1 Schéma de saisie

- [ ] T6c4.1 Créer `R/health_validation.R` avec roxygen header
- [ ] T6c4.2 `get_health_validation_schema(region = "FR", lang = "fr")` retourne une liste de champs avec types/contraintes :
  - `stade_deperissement` : ValueMap = ["Sain", "Sain_scolyte_vert_indif", "Scolyte_vert", "Scolyte_rouge", "Scolyte_gris", "Scolyte_rouge_gris_indif", "Coupe_rase"]
  - `cause` : ValueMap libre (Scolyte / Sécheresse / Casse_cime / Coupe / Chablis / Phénologie / Autre)
  - `taux_couvert` : Range [0, 100], unité %
  - `essence_dominante` : ValueMap depuis `list_species_classes("FR")`
  - `commentaires` : TextEdit multi-line
  - `photo_houppier` : ExternalResource (image)
  - `obs_date` : DateTime (default = now)
  - `obs_by` : TextEdit (auto-rempli par OAuth si dispo)
- [ ] T6c4.3 Cohérence avec `get_placette_schema()` existant : mêmes types de champs, mêmes conventions de naming
- [ ] T6c4.4 Tests `tests/testthat/test-health-validation-schema.R` (8-10 tests)

### 5.2 Génération de placettes de vérification

- [ ] T6c4.5 `generate_health_validation_plots(alerts_sf, n = 30, method = "grts", crs = 2154)` : échantillonnage GRTS sur les centroïdes des clusters d'alertes (réutilise `R/sampling_plan.R`)
- [ ] T6c4.6 Stratification par `confidence_class` si possible (au moins 1 placette par classe représentée)
- [ ] T6c4.7 Retour : sf POINT EPSG:2154 avec `plot_id`, `confidence_class`, `stress_index`, `trigger_date`, `geometry`
- [ ] T6c4.8 Tests `tests/testthat/test-generate-health-validation-plots.R` (6-8 tests)

### 5.3 Ingestion de la validation

- [ ] T6c4.9 `ingest_health_validation(con, gpkg_path, zone_id, snap_distance_m = 50, validated_by = NULL)` :
  - lit le GPKG (couche `placettes` avec champs sanitaires)
  - pour chaque placette saisie, trouve l'alerte la plus proche dans `zone_id` (distance ≤ `snap_distance_m`)
  - mappe `stade_deperissement` → `validation_status` :
    - "Sain" → `false_positive` (cause = "sain_terrain")
    - "Coupe_rase" → `confirmed` ou `false_positive` selon la classe initiale (4-sol-nu = confirmed cohérent ; 3-forte = confirmed mécanique ; 1-2 = false_positive)
    - autres → `confirmed`
  - UPDATE alert SET validation_status, validation_cause, validated_by, validated_at WHERE id = ...
- [ ] T6c4.10 Retour : tibble avec `n_confirmed`, `n_false_positive`, `n_unmatched` (placettes sans alerte proche), détail
- [ ] T6c4.11 Logging : cli_alert_success par batch
- [ ] T6c4.12 Test d'intégration `tests/testthat/test-ingest-health-validation.R` (10-12 tests, `with_clean_db`)

---

## Chantier E6.c.5 — UI Mode sanitaire (`nemetonshiny`)

Branche : `feat/008-mod-monitoring-sanitaire`

### 6.1 Mode toggle

- [ ] T6app.1 Étendre `R/mod_monitoring.R` UI : `radioButtons` ou `bslib::input_switch` pour `mode` (« Surveillance rapide » / « Diagnostic sanitaire »)
- [ ] T6app.2 Côté server, réagir au mode : afficher/cacher des panneaux (date_training visible en mode sanitaire, paramètres seuils différents)
- [ ] T6app.3 Activer le bouton « Lancer ingestion » (rendu enable/disable selon mode + zones disponibles)

### 6.2 Bannières G3

- [ ] T6app.4 Helper `mod_monitoring_warnings_ui(validity_check)` : génère la liste des bannières (géo, espèces) selon le retour de `nemeton::check_fordead_validity()`
- [ ] T6app.5 Reactive sur AOI courante → calcule `validity_check` au chargement du projet
- [ ] T6app.6 Affichage en haut du main panel, au-dessus de la time series

### 6.3 Async run FORDEAD

- [ ] T6app.7 `shiny::ExtendedTask$new(function(aoi, dates_training, dates_monitoring, threshold) { promises::future_promise(nemeton::run_fordead_dieback(...)) })`
- [ ] T6app.8 Toast notifications : démarrage, fin, erreur. Indication de durée estimée.
- [ ] T6app.9 Tests : mock `nemeton::run_fordead_dieback` en `with_mocked_bindings`, vérifier l'invocation et la propagation des résultats

### 6.4 Time series + carte alertes

- [ ] T6app.10 [P] Plotly time series :
  - Mode rapide : NDVI/NBR (déjà en E6.b phase 3)
  - Mode sanitaire : CRSWIR observed + courbe modèle harmonique + seuil
- [ ] T6app.11 Carte leaflet alertes :
  - Couches par classe (color-coded : 1-faible jaune pâle, 2-moyenne orange, 3-forte rouge, 4-sol-nu noir)
  - Filtre par défaut classe 3+4
  - Toggle « Inclure faible/moyenne » avec bannière warning
  - Popup : classe, stress_index, trigger_date, validation_status, boutons « Valider » / « Faux positif » (rapides)

### 6.5 Workflow validation (UI)

- [ ] T6app.12 Bouton « Générer placettes QField pour vérification » → appelle `nemeton::generate_health_validation_plots()` puis `nemeton::create_qfield_project()`, downloadHandler `.qgz`
- [ ] T6app.13 Sous-onglet « Validation sanitaire » dans `mod_field_ingest` :
  - reuse de la mécanique GPKG fileInput
  - parse via `nemeton::ingest_health_validation()`
  - rapport (compteurs + table erreurs)
  - notification de mise à jour des alertes

### 6.6 Persistance config

- [ ] T6app.14 [P] `update_project_metadata(project_id, list(monitoring_mode = "sanitaire", monitoring_threshold = 0.16, monitoring_dates_training = c(...), monitoring_validity_zones_intersection_pct = 0.87, ...))`
- [ ] T6app.15 Restore depuis `metadata.json` au chargement du projet

### 6.7 i18n

- [ ] T6app.16 ~30 nouvelles clés dans `R/utils_i18n.R` :
  - `tab_monitoring` (renommé « Suivi sanitaire » / « Forest health monitoring »)
  - `monitoring_mode_*`, `monitoring_warning_*`, `monitoring_class_*`
  - `health_validation_*` (workflow QField)
  - `r5_*` (futurs labels du radar)
- [ ] T6app.17 Encodage \uXXXX (cohérence repo)

### 6.8 Tests

- [ ] T6app.18 Étendre `test-mod_monitoring.R` : 10-15 nouveaux test_that (mode toggle, bannières, async mocked, génération placettes)

---

## Chantier E6.f — Smoke + release (`nemetonshiny`)

- [ ] T6f.1 Scénario shinytest2 E2E : ouvrir un projet de fixture, basculer mode sanitaire, lancer FORDEAD (mocké), vérifier alertes leaflet, générer placettes, simuler upload GPKG validation, vérifier rapport
- [ ] T6f.2 Polish UI (espacement, copy)
- [ ] T6f.3 Mise à jour des badges README pour v0.21.0
- [ ] T6f.4 NEWS, DESCRIPTION, CITATION cœur + app à v0.21.0
- [ ] T6f.5 PLAN.md mis à jour : E6.b/c/d ✅, journal du 2026-XX-XX
- [ ] T6f.6 Tag v0.21.0, push, gh release create
- [ ] T6f.7 Bump dev cycle 0.21.0.9000

---

## Critères d'acceptation globaux

(cf. spec.md §11 et plan.md §8)

Tâches totales : 71 (53 cœur, 18 app). Estimation effort : ~10 sessions de travail, ~2-3 semaines en rythme normal.
