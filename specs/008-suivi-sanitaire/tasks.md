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

- [x] T6c1.1 Créer `R/fordead_python.R` avec squelette + roxygen header
- [x] T6c1.2 `.ensure_fordead_python(env_name = "nemeton-fordead")` : crée le venv si absent, installe `inst/python/requirements.txt`, retourne le module fordead. Idempotent.
- [x] T6c1.3 `.use_fordead_env()` : bascule reticulate sur le bon venv (`reticulate::use_virtualenv()`)
- [x] T6c1.4 [P] Créer `inst/python/requirements.txt` avec versions pinnées (cf. plan.md §1.3)
- [x] T6c1.5 Vérification système : Python ≥ 3.10 requis, message d'erreur explicite si absent
- [x] T6c1.6 Tests `tests/testthat/test-fordead-python.R` (5-8 tests, mocked) : skip if reticulate absent ; idempotence ; gestion d'erreur si Python missing

### 1.2 Orchestrateur `run_fordead_dieback`

- [x] T6c1.7 Créer `R/fordead_pipeline.R` avec squelette + roxygen header
- [x] T6c1.8 Signature `run_fordead_dieback(aoi, dates_training, dates_monitoring, vegetation_index = "CRSWIR", threshold_anomaly = 0.16, forest_mask = NULL, output_dir = tempfile(), python_env = NULL, con = NULL)` (cf. plan.md §2.1)
- [x] T6c1.9 Validation des arguments : aoi sf POLYGON EPSG:2154 ; dates valides et chronologiques ; threshold_anomaly ∈ [0.05, 0.50] ; vegetation_index ∈ {"CRSWIR", "NDVI", "NDWI"}
- [x] T6c1.10 Phase 1 : compute_masked_vegetationindex (appel Python via reticulate)
- [x] T6c1.11 Phase 2 : train_model
- [x] T6c1.12 Phase 3 : forest_mask (cache local BD Forêt v2 si non fourni). Helper `.download_or_use_cached_bd_foret(aoi)` — **stub jusqu'à E6.c.3**
- [x] T6c1.13 Phase 4 : dieback_detection
- [x] T6c1.14 Phase 5 : export_results
- [x] T6c1.15 Capture des logs Python via `reticulate::py_capture_output()` → cli_alert_info pendant l'exécution
- [x] T6c1.16 Retour structuré (`list(status, output_dir, rasters, alerts_sf, n_alerts_inserted, duration_sec, python_env, fordead_version)`)
- [x] T6c1.17 Gestion d'erreurs : tryCatch global, retour `status = "error"` + message
- [x] T6c1.18 Doc roxygen complète + 1 exemple `\dontrun{}`

### 1.3 Tests d'orchestration

- [x] T6c1.19 `tests/testthat/test-fordead-pipeline.R` : 8-12 tests avec phases mockées (`local_mocked_bindings` sur les calls reticulate). Vérifie l'ordre, la propagation d'erreur, le format de retour.

---

## Chantier E6.c.2 — Post-processing + intégration DB (cœur)

Branche : `feat/008-fordead-postprocess`

### 2.1 Migration SQL

- [x] T6c2.1 Créer `inst/db/migrations/0002_fordead.sql` (cf. spec.md §8.3)
- [x] T6c2.2 Vérifier la migration en intégration : ajouter un test à `tests/testthat/test-db.R` (idempotence, présence des nouvelles colonnes)
- [x] T6c2.3 Mettre à jour `with_clean_db()` dans `helper-monitoring.R` pour drop les nouveaux index — **no-op** : `DROP TABLE alert CASCADE` enlève déjà les nouveaux index avec la table

### 2.2 Constantes et coefficients

- [x] T6c2.4 Créer `R/fordead_postprocess.R` avec roxygen header
- [x] T6c2.5 Constante `FORDEAD_CONFIDENCE_WEIGHTS` documentée (cite Bernard & Doridant 2024)
- [x] T6c2.6 Constante `FORDEAD_CLASSES` (vecteur ordonné des 5 classes : "0-hors-anomalie" → "4-sol-nu")

### 2.3 Conversion raster → POINT clusters

- [x] T6c2.7 `.classify_pixels_to_classes(state_raster)` : réinterprète les valeurs de state en classes ordinales
- [x] T6c2.8 `.cluster_anomaly_pixels(class_raster, min_pixels = 5, connectivity = 8)` : agrège les pixels en clusters via `terra::patches()`
- [x] T6c2.9 `.cluster_to_centroids(clusters, stress_index_raster, first_dieback_date_raster)` : retourne sf POINT enrichi de `confidence_class`, `stress_index`, `trigger_date`, `n_pixels`, `area_m2`
- [x] T6c2.10 [P] Tests : `tests/testthat/test-fordead-postprocess.R` (12-15 tests) avec rasters synthétiques

### 2.4 Insertion dans `alert`

- [x] T6c2.11 `.insert_fordead_alerts(con, alerts_sf, zone_id)` : INSERT en bulk via TEMP staging + ON CONFLICT DO NOTHING
- [x] T6c2.12 `alert_type = "fordead_dieback"` ; `confidence_class` mappée ; `stress_index` populé
- [x] T6c2.13 Test d'intégration (`with_clean_db`) : insertion + idempotence + vérification des champs

### 2.5 Logique de fusion

- [x] T6c2.14 `classify_disturbance(alerts_df, window_days = 30)` exporté (cf. plan.md §3)
- [x] T6c2.15 [P] Tests : 8-10 tests sur des dataframes synthétiques

### 2.6 Helper de listing pour l'UI

- [x] T6c2.16 `list_alerts(con, zone_id, classes = c("3-forte", "4-sol-nu"), validation_status = NULL, period = NULL)` exporté
- [x] T6c2.17 [P] Test d'intégration : 5-6 cas

---

## Chantier E6.c.3 — Validity zones (cœur)

Branche : `feat/008-fordead-validity`

### 3.1 Construction de `fordead_validity_zones.geojson`

- [x] T6c3.1 Créer `data-raw/build_fordead_validity_zones.R` :
  - fetch via le mirror static `gregoiredavid/france-geojson` (snapshot IGN ADMIN-EXPRESS, Etalab 2.0) — `geo.api.gouv.fr/format=geojson&geometry=contour` ne sert plus le contour depuis 2025
  - union, simplification (dTolerance = 100 m en Lambert-93), reprojection EPSG:4326
  - écriture `inst/extdata/fordead_validity_zones.geojson`
  - script reproductible, fait partie du repo
- [x] T6c3.2 Lancer le script et committer le GeoJSON résultat (5 features, ~27 500 km², 80 ko)
- [x] T6c3.3 Test `tests/testthat/test-fordead-validity-zones.R` : le fichier charge, contient les 5 polygones, surface totale dans la fourchette attendue (4 tests)

### 3.2 Helper de vérification

- [x] T6c3.4 Créer `R/fordead_validity.R` avec roxygen header
- [x] T6c3.5 `load_fordead_validity_zones()` : charge et cache la geojson (sf, EPSG:4326)
- [x] T6c3.6 `check_fordead_validity(aoi, units = NULL, threshold_geo = 0.5, threshold_species = 0.7, min_resineux = 0.3)` retourne :
  ```r
  list(geo_valid, geo_intersection_pct, geo_dept_codes,
       species_valid, species_resineux_pct,
       species_epc_pct, species_sap_pct,
       overall_valid, thresholds)
  ```
- [x] T6c3.7 La logique espèce s'appuie sur les colonnes `essence_dominante` / `essence` / `species_label` / `species` / `essence_principale` (priorité dans cet ordre). Helpers `.is_epicea()` et `.is_sapin_pectine()` gèrent les codes ONF/DSF (EPC, SAP), les noms français (épicéa, sapin pectiné) et latins (Picea abies, Abies alba), avec exclusion explicite de Pseudotsuga menziesii / "Sapin de Douglas" et résolution de la collision latine "abies" entre genre et espèce.
- [x] T6c3.8 Tests `tests/testthat/test-fordead-validity.R` (12 tests) : Vosges valid, Jura valid sans units, Massif Central géo invalid, Brie géo+espèces invalid, AOI à cheval (seuil), seuil 70%, distinction Picea/Abies/Douglas, units vides, units sans colonne espèce (warning), erreurs typées, colonnes alternatives, thresholds échoés

---

## Chantier E6.d — Indicateur R5 dépérissement (cœur)

Branche : `feat/008-r5-deperissement`

### 4.1 Calcul

- [x] T6d.1 Créer `R/indicators-deperissement.R` avec roxygen header
- [x] T6d.2 `indicateur_r5_deperissement(units, fordead_results = NULL, weights = FORDEAD_CONFIDENCE_WEIGHTS, min_resineux = 0.3, include_low_classes = FALSE, resineux_col = NULL)` — argument supplémentaire `resineux_col` pour brancher une fraction résineux pré-calculée (sinon dérivée du dominant species via `.is_epicea` / `.is_sapin_pectine`).
- [x] T6d.3 Validation : `units` est sf (sinon abort typé) ; `fordead_results$alerts_sf` doit avoir les colonnes `confidence_class` + `area_m2` (sinon abort typé). `fordead_results = NULL` ou `alerts_sf` vide → R5 = NA partout (status `skipped_no_fordead`).
- [x] T6d.4 Per-UGF : helper `.resolve_resineux_share(units_m, resineux_col)` produit une fraction résineux par UGF (1/0 binaire si dérivée du dominant species, ou la valeur clampée [0,1] si `resineux_col` est fourni). `< min_resineux` → R5 = NA, status `skipped_no_resineux`.
- [x] T6d.5 Per-UGF valide : intersection POINT-in-polygon entre les centroïdes de clusters et l'UGF, somme pondérée `weights[class] × area_m2`, divisé par surface UGF (Lambert-93), plafonné à 1, rescalé en 0-100 pour cohérence radar (R1..R4 sont déjà en 0-100).
- [x] T6d.6 Retour : sf identique à `units` avec deux colonnes ajoutées — `R5` (numeric 0-100, NA si skip — convention `R[0-9]` reprise des 4 autres indicateurs de la famille R) et `r5_status` (character ∈ `{"calculated", "skipped_no_resineux", "skipped_no_fordead"}`).
- [x] T6d.7 Doc roxygen complète : `@param`, `@return`, justification G1 (exclusion 1-faible/2-moyenne par défaut), pointeur vers `FORDEAD_CONFIDENCE_WEIGHTS`.

### 4.2 Intégration radar

- [x] T6d.8 `INDICATOR_FAMILIES$R` étendu à 5 indicateurs (`R1..R5`) avec `column_names`, `indicator_labels` (FR/EN) et `indicator_tooltips` (FR/EN). `create_family_index()` détecte automatiquement `R5` via la regex `^R[0-9]` existante — pas de changement à `R/family-system.R` nécessaire. Validé dans le test : la colonne `famille_risque` reflète bien R1..R5 quand R5 est présent, et reste finie quand R5 est NA.
- [x] T6d.9 [P] `normalize_indicator()` n'a pas besoin de switch case dédié pour `R5` : la valeur est déjà en 0-100 et le default `pmin(100, pmax(0, values))` la conserve telle quelle, comme R1..R4.

### 4.3 Tests

- [x] T6d.10 `tests/testthat/test-indicators-deperissement.R` — 18 tests : cas vide → NA partout, mono-classe 50% × 3-forte → R5 = 41 (0.82 × 0.5 × 100), multi-classes additif (3-forte + 4-sol-nu), Quercus → skipped_no_resineux, classes 1-faible/2-moyenne ignorées par défaut (G1), `include_low_classes = TRUE` les rajoute, plafonnement à 100, clusters hors UGF ne contribuent pas, `resineux_col` custom (override + clamp [0,1]), `min_resineux` honoré, `weights` custom, sf vide retourne sf vide avec colonnes, erreur typée sur non-sf, erreur typée sur `alerts_sf` mal formé, intégration radar via `create_family_index(family_codes = "R")` (R5 picked up + NA non poison la moyenne quand R1..R4 sont là).

---

## Chantier E6.c.4 — Workflow QField de validation (cœur)

Branche : `feat/008-health-validation`

### 5.1 Schéma de saisie

- [x] T6c4.1 Créer `R/health_validation.R` avec roxygen header
- [x] T6c4.2 `get_health_validation_schema(region = "BFC", lang = "fr")` retourne 11 champs `.field()` (réutilise le constructeur de `R/field_schema.R`) : `plot_id` (required), `alert_id`, `confidence_class`, `stade_deperissement` (required, ValueMap = `HEALTH_VALIDATION_STADES`), `cause` (ValueMap = `HEALTH_VALIDATION_CAUSES`), `taux_couvert` (Range [0, 100]), `essence_dominante` (ValueMap depuis `list_species_classes`, fallback texte si config manquante), `commentaires` (TextEdit), `photo_houppier` (ExternalResource), `obs_date` (DateTime), `obs_by` (TextEdit). Constantes `HEALTH_VALIDATION_STADES` et `HEALTH_VALIDATION_CAUSES` exportées.
- [x] T6c4.3 Cohérence avec `get_placette_schema()` : mêmes widgets QGIS (`TextEdit`, `Range`, `DateTime`, `ValueMap`, `ExternalResource`), même structure de retour `.field()`, mêmes conventions snake_case NMT (sans accent).
- [x] T6c4.4 Tests `tests/testthat/test-health-validation-schema.R` — 10 tests : présence des champs, vocabulaire DSF, bornes, fallback `essence_dominante`, mapping stade→status incluant la règle `coupe_rase` × `confidence_class`.

### 5.2 Génération de placettes de vérification

- [x] T6c4.5 `generate_health_validation_plots(alerts_sf, n = 30, method = c("grts", "random"), crs = 2154)` : échantillonnage stratifié par `confidence_class`. GRTS via `spsurvey::grts()` quand le package est disponible (helper repris de `R/sampling_plan.R`), repli silencieux sur tirage aléatoire intra-strate sinon. Allocation par strate : `.allocate_health_strata()` (au moins 1 placette par classe présente, reste réparti à la plus grande fraction restante avec capping par capacité de strate).
- [x] T6c4.6 Stratification par `confidence_class` : couvre toutes les classes représentées dans l'input ; si `n < k_classes`, on garde les `n` plus grandes strates.
- [x] T6c4.7 Retour : sf POINT EPSG:2154 (configurable) avec `plot_id` (`HV-0001`...), `alert_id`, `confidence_class`, `stress_index`, `trigger_date`, `sampling_method` (`grts` ou `random`), plus colonnes éditables pré-allouées en NA typés (`stade_deperissement`, `cause`, `taux_couvert`, `essence_dominante`, `commentaires`, `photo_houppier`, `obs_date`, `obs_by`).
- [x] T6c4.8 Tests `tests/testthat/test-generate-health-validation-plots.R` — 11 tests : allocation par strate (`>=1` partout, capping, cas `n < k`), nombre exact de plots tirés, reprojection, couverture des classes, NA typés, fallback GRTS→random via `local_mocked_bindings(requireNamespace)`, sf vide, colonne manquante, erreurs typées.

### 5.3 Ingestion de la validation

- [x] T6c4.9 `ingest_health_validation(con, gpkg_path, zone_id, snap_distance_m = 50, validated_by = NULL, layer = "placettes")` : lit la couche GPKG, snap par plus-proche-voisin (distance euclidienne en Lambert-93), mappe `stade_deperissement` → `(validation_status, validation_cause)` via le helper privé `.health_stade_to_status()` qui respecte la règle `coupe_rase` × `confidence_class` (1-faible / 2-moyenne → false_positive ; 3-forte / 4-sol-nu → confirmed). UPDATE atomique par alerte. Précédence `validated_by` : argument > champ `obs_by` du GPKG > `Sys.info()`. La cause libre du terrain (champ `cause`) écrase la cause auto-mappée si elle est non-vide.
- [x] T6c4.10 Retour : `list(n_updated, n_confirmed, n_false_positive, n_unmatched, n_skipped, details)`. `details` est un data.frame avec une ligne par placette traitée (`plot_id`, `alert_id`, `distance_m`, `stade`, `status`, `cause`, `reason ∈ {ok, no_alert_within_snap, missing_stade}`).
- [x] T6c4.11 Logging : `cli::cli_alert_success` post-batch avec compteurs et pluralisation.
- [x] T6c4.12 Test d'intégration `tests/testthat/test-ingest-health-validation.R` — 10 tests via `with_clean_db` : sain → false_positive, scolyte → confirmed/scolyte_terrain, coupe_rase × classe, snap distance, plots sans stade (skipped), précédence `validated_by`, cause libre du terrain, zone sans alertes, GPKG manquant, colonne `stade_deperissement` manquante, structure de `details`.

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
