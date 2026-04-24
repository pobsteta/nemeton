# PLAN — Épaississement 5 : intégration QField

**Démarré** : 2026-04-23
**Clôturé**  : 2026-04-24
**État global** : **E5 bouclé des deux côtés** (cœur `nemeton` + app `nemetonshiny`), tous les commits poussés sur `origin/main`.
**Branches** : `nemeton@main = 1e7c064`, `nemetonshiny@main = 4df5ad8`.

## Contexte

Le tutoriel `inst/tutorials/09-sampling/` produit un plan d'échantillonnage GRTS + parcours TSP exportés en GeoPackage / GPX / CSV. Il manquait deux maillons : un **projet QField prêt à l'emploi** pour que les agents terrain saisissent directement les données dendrométriques (E5.a), et le **chemin de retour** pour réingérer les mesures dans les indicateurs et faire monter le NDP (E5.b).

Les Bounded Contexts concernés :
- **Inventaire** (E5.a aval, E5.b amont)
- **Interopérabilité** (export/import QField — ligne 110 de CLAUDE.md)
- **Analyse systémique** (réingestion déclenche recalcul P1/P2/B2/C1/R2 au prochain compute)

## Découpage

### E5.a — Export QField (Néméton → terrain) — **livré**

**Côté `nemeton`** — commit `9df1484` (renommage `qgis_*` en `1e7c064`)
- [x] `R/field_schema.R` — `get_placette_schema()` (10 champs), `get_arbre_schema()` (9 + attachement labels), `schema_to_df()`, `empty_sf_from_schema()`. Domaine espèces branché sur `list_species_classes()`.
- [x] `R/qgis_export.R` (ex `qfield_export.R`) — `create_qfield_project(placettes, zone_etude, parcours_tsp, output_dir, project_name, crs, region, lang, overwrite)` : `.qgz` (ZIP `.qgs` XML + GPKG) ; zéro nouvelle dépendance.
  - [x] `.qgs` avec `projectCrs`, `layer-tree-group`, `projectlayers`, edit widgets (TextEdit / Range / DateTime / ValueMap / ExternalResource / CheckBox), aliases, NotNull, symbologie categorisée Base/Over
  - [x] GPKG avec `placettes` / `arbres` / `zone_etude` / `parcours_tsp`
  - [x] Emballage via `utils::zip()` avec chemins relatifs
- [x] Tuto 09 : Section 6 « Export QField » + 5e quiz + README mis à jour
- [x] Tests `tests/testthat/test-qgis-export.R` : 30 assertions vertes
- [x] Doc roxygen + NAMESPACE regénérés ; 7 pages d'aide créées

**Côté `nemetonshiny`** — commit `f074105`
- [x] `R/mod_sampling.R` — UI formulaire + carte leaflet + `downloadHandler` QField.
- [x] 14 nouvelles clés i18n `tab_sampling` / `sampling_*` / `qfield_*` (FR/EN)
- [x] Entrée navbar « Terrain » (icône `crosshair`) entre Synthèse et Familles
- [x] `testServer()` sur `mod_sampling` : 23 assertions vertes

### E5.a bis — GRTS côté cœur — **livré**

**Côté `nemeton`** — commit `a8ff2cf`
- [x] `R/sampling_plan.R` — `create_sampling_plan(zone, n_base, n_over, seed, chm, dem, forest_mask, ...)` exporté : GRTS stratifié quand CHM/DEM/BD Forêt sont fournis, fallback LPM2 (spatialement équilibré) puis aléatoire. Retourne une sf POINT avec attr `method` ∈ {`grts`, `lpm2`, `random`}.
- [x] Tests `tests/testthat/test-sampling-plan.R`

**Côté `nemetonshiny`** — commit `66e6613`
- [x] `mod_sampling` consomme désormais `nemeton::create_sampling_plan()` ; la notification de génération affiche la méthode (`GRTS` / `LPM2` / `RANDOM`)
- [x] Clé i18n `sampling_method_note` réécrite

### E5.b — Réingestion QField (terrain → Néméton) — **livré**

**Côté `nemeton`** — commit `a8ff2cf`
- [x] `R/qgis_import.R` (ex `qfield_import.R`) — `import_qfield_gpkg(path)`, `validate_field_data(placettes, arbres, region, lang)`, `aggregate_plot_metrics(placettes, arbres, plot_radius=15)`, `attach_field_data_to_units(units, field_agg)`, `tag_field_data_sources(data, placettes, arbres)`
- [x] Ajout source `field_qfield` dans `inst/datasources/FR.json`
- [x] Mise à jour `detect_ndp()` : chemin alternatif terrain — placettes → NDP 2, inventaire arbre complet (≥ 10 arbres/placette en moyenne) → NDP 3
- [x] Tests : `test-qgis-import.R`, `test-ndp-field.R`

**Côté `nemetonshiny`** — commit `4df5ad8`
- [x] `R/mod_field_ingest.R` — onglet « Ingestion terrain » : fileInput GPKG → `import_qfield_gpkg()` + `validate_field_data()` → rapport (compteurs + tables erreurs/warnings) → preview leaflet des placettes / arbres → badge NDP avant/après → bouton « Rattacher au projet ».
- [x] Sur rattachement : `aggregate_plot_metrics()` + `tag_field_data_sources()` + `attach_field_data_to_units()` → persistance `<project>/data/field_data.gpkg` + `update_project_metadata(ndp_level, field_data_plots, field_data_trees, field_data_imported_at)` → `load_project()` pour propager le nouveau NDP à tous les modules.
- [x] 22 nouvelles clés i18n (`tab_field_ingest`, `field_ingest_*`)
- [x] Tests `tests/testthat/test-mod_field_ingest.R` : 24 assertions vertes (UI, NULL state, validate flow sur un GPKG réel, attach flow avec persistance mockée)

## Décisions

- **Pas de dépendance lourde pour le `.qgz`** : le format est un simple ZIP d'un `.qgs` XML et du GPKG. On le génère à la main pour rester léger. `happign`, `leaflet` etc. restent en `Suggests`.
- **Deux couches, pas trois** : `placettes` (points GRTS) et `arbres` (saisie terrain), liées par `plot_id`. Le parcours TSP est purement documentaire (couche en lecture seule).
- **Vocabulaire espèces** : `R/species-config.R` pour les domaines QField — une seule source de vérité.
- **CRS de sortie** : EPSG:2154 (Lambert-93) pour les GPKG. QField accepte et c'est l'écosystème IGN natif.
- **Le TSP reste dans le tuto** pour la pédagogie, mais `create_sampling_plan()` peut aussi le produire.
- **Nommage fichiers `qgis_*`** : le format produit est un projet QGIS/QField générique, pas spécifique à QField. Les fonctions exportées (`create_qfield_project`, `import_qfield_gpkg`) gardent leur nom ; seuls les fichiers sources ont été renommés.
- **MVP ingest** : `mod_field_ingest` persiste la donnée terrain et fait monter le NDP, mais ne relance pas `compute_all_indicators()`. Les indicateurs consommant `field_*` (P1, P2, B2, C1, R2) le font au prochain compute via le Home tab. Suffisant pour fermer la boucle ; l'intégration dans `compute_all_indicators()` (lecture de `<project>/data/field_data.gpkg` au démarrage) est un chantier suivant, indépendant.

## Chantiers suivants (hors E5)

- **Épaississement 6** — Monitoring forestier continu : TimescaleDB + alertes Sentinel-2 (ADR-012).
- **Épaississement 7** — RAG perspectives IA : pgvector + base de connaissances forestière (ADR-012).
- **Dette technique suivie** :
  - Brancher `field_data.gpkg` dans `start_computation()` pour que les indicateurs P1/P2/B2/C1/R2 consomment automatiquement les agrégats terrain au prochain compute.
  - Rafraîchir les `@name qfield_export` / `qfield_import` côté cœur pour les aligner sur le nouveau nommage `qgis_*` (purement cosmétique — les tags servent de « famille » dans la doc roxygen).

## Journal

- **2026-04-23** — PLAN.md créé. `tree_sat` et `maestro` retirés de l'Épaississement 5 dans CLAUDE.md. Épaississement 5 = QField uniquement.
- **2026-04-23** — E5.a côté `nemeton` livré (`9df1484`). Suite `nemeton` : 1911 / 0 failure.
- **2026-04-23** — E5.a côté `nemetonshiny` livré (`f074105`). Suite `nemetonshiny` : 1053 / 0 failure.
- **2026-04-23** — E5.a bis + E5.b côté cœur livrés (`a8ff2cf`) : `sampling_plan.R`, `qfield_import.R`, `detect_ndp()` chemin alternatif, source `field_qfield`.
- **2026-04-24** — Renommage cœur `R/qfield_*.R` → `R/qgis_*.R` et tests (`1e7c064`, poussé).
- **2026-04-24** — E5.a bis côté app (`66e6613`) : `mod_sampling` branché sur `nemeton::create_sampling_plan()`.
- **2026-04-24** — E5.b côté app (`4df5ad8`) : `mod_field_ingest` livré, 24 assertions vertes. Suite `nemetonshiny` : 5089 / 0 failure.
- **2026-04-24** — Tous les commits des deux repos poussés sur `origin/main`. Épaississement 5 clos.
