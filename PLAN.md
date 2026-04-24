# PLAN — Épaississement 5 : intégration QField

**Démarré** : 2026-04-23
**État global** : E5.a **livré des deux côtés** ; E5.b **cœur livré** (commit `a8ff2cf`) ; reste le module d'ingestion côté `nemetonshiny`
**Branche** : `main` (nemeton tip `a8ff2cf` + renommages `qfield_*` → `qgis_*`, nemetonshiny tip `f074105`)

## Contexte

Le tutoriel `inst/tutorials/09-sampling/` produit déjà un plan d'échantillonnage GRTS + parcours TSP exportés en GeoPackage / GPX / CSV. Il manque le dernier maillon : un **projet QField prêt à l'emploi** pour que les agents terrain saisissent directement les données dendrométriques, et le **chemin de retour** pour réingérer les mesures dans les indicateurs et faire monter le NDP.

Les Bounded Contexts concernés :
- **Inventaire** (E5.a aval, E5.b amont)
- **Interopérabilité** (export/import QField — ligne 110 de CLAUDE.md)
- **Analyse systémique** (réingestion déclenche recalcul P1/P2/B2/C1/R2)

## Découpage

### E5.a — Export QField (Néméton → terrain) — **livré**
Capitalise directement sur les sorties du tuto 09.

**Côté `nemeton`** — livré (`9df1484`, renommage `qgis_*` dans un commit suivant)
- [x] `R/field_schema.R` — `get_placette_schema()` (10 champs), `get_arbre_schema()` (9 + attachement labels), `schema_to_df()`, `empty_sf_from_schema()`. Domaine espèces branché sur `list_species_classes()`.
- [x] `R/qgis_export.R` (ex `qfield_export.R`) — `create_qfield_project(placettes, zone_etude, parcours_tsp, output_dir, project_name, crs, region, lang, overwrite)` : `.qgz` (ZIP `.qgs` XML + GPKG) ; zéro nouvelle dépendance.
  - [x] `.qgs` avec `projectCrs`, `layer-tree-group`, `projectlayers`, edit widgets (TextEdit / Range / DateTime / ValueMap / ExternalResource / CheckBox), aliases, NotNull, symbologie categorisée Base/Over
  - [x] GPKG avec `placettes` / `arbres` / `zone_etude` / `parcours_tsp`
  - [x] Emballage via `utils::zip()` avec chemins relatifs
- [x] Tuto 09 : Section 6 « Export QField » + 5e quiz + README mis à jour
- [x] Tests `tests/testthat/test-qgis-export.R` : 30 assertions, toutes vertes.
- [x] Doc roxygen + NAMESPACE regénérés ; 7 pages d'aide créées

**Côté `nemetonshiny`** — livré (commit `f074105`, branche `main`)
- [x] `R/mod_sampling.R` — UI formulaire + carte leaflet + `downloadHandler` QField. Tirage `st_sample()` spatial aléatoire (première itération ; sera remplacé par `create_sampling_plan()` exporté par le cœur depuis E5.a bis).
- [x] 14 nouvelles clés i18n `tab_sampling` / `sampling_*` / `qfield_*` (FR/EN)
- [x] Entrée navbar « Terrain » (icône `crosshair`) entre Synthèse et Familles
- [x] `testServer()` sur `mod_sampling` : 23 assertions vertes, suite complète 1053 / 0 failure
- [x] Bump `nemetonshiny` 0.16.0.9000, `Imports: nemeton (>= 0.18.0.9000)`

### E5.a bis — GRTS côté cœur — **livré**
- [x] `R/sampling_plan.R` — `create_sampling_plan()` exporté : tirage GRTS + parcours TSP + métadonnées, sortie réutilisable directement par `create_qfield_project()`.
- [x] Tests `tests/testthat/test-sampling-plan.R`.

### E5.b — Réingestion QField (terrain → Néméton) — **livré côté cœur**

**Côté `nemeton`** — livré (commit `a8ff2cf`)
- [x] `R/qgis_import.R` (ex `qfield_import.R`) — `import_qfield_gpkg(path)`, `validate_field_data()`, `aggregate_plot_metrics()`, `attach_field_data_to_units()`, `tag_field_data_sources()`
- [x] Ajout source `field_qfield` dans `inst/datasources/FR.json`
- [x] Mise à jour `detect_ndp()` : placettes → NDP 2, inventaire arbre complet → NDP 3
- [x] Tests : `test-qgis-import.R`, `test-ndp-field.R` (13 assertions sur le chemin alternatif)

**Côté `nemetonshiny`** — à faire
- [ ] `R/mod_field_ingest.R` — dépôt GPKG, rapport de validation, déclenchement recalcul
- [ ] Affichage de la montée de NDP (badge + barre φ)
- [ ] Remplacement de `st_sample()` dans `mod_sampling.R` par `nemeton::create_sampling_plan()` (tirage GRTS réel)

## Décisions

- **Pas de dépendance lourde pour le `.qgz`** : le format est un simple ZIP d'un `.qgs` XML et du GPKG. On le génère à la main pour rester léger. `happign`, `leaflet` etc. restent en `Suggests`.
- **Deux couches, pas trois** : `placettes` (points GRTS) et `arbres` (saisie terrain), liées par `plot_id`. Le parcours TSP est purement documentaire (couche en lecture seule).
- **Vocabulaire espèces** : réutiliser `R/species-config.R` pour les domaines QField plutôt qu'un hard-code — une seule source de vérité.
- **CRS de sortie** : EPSG:2154 (Lambert-93) pour les GPKG. QField accepte sans souci et c'est l'écosystème IGN natif.
- **Le TSP reste dans le tuto** pour la pédagogie, mais la fonction `create_sampling_plan()` du cœur peut aussi le produire.
- **Nommage fichiers `qgis_*`** (2026-04-24) : le format produit est un projet QGIS/QField générique, pas spécifique à QField. Les fonctions exportées (`create_qfield_project`, `import_qfield_gpkg`) gardent leur nom — seuls les fichiers sources sont renommés pour refléter la techno sous-jacente.

## Prochaine étape

Côté `nemetonshiny` : implémenter `mod_field_ingest.R` (dépôt GPKG → `validate_field_data()` → rapport → recalcul indicateurs → mise à jour badge NDP). Remplacer `st_sample()` par `create_sampling_plan()` dans `mod_sampling.R` par la même occasion.

Ensuite : Épaississement 6 (monitoring TimescaleDB) ou 7 (RAG pgvector) selon priorité.

## Journal

- **2026-04-23** — PLAN.md créé. `tree_sat` et `maestro` retirés de l'Épaississement 5 dans CLAUDE.md. Épaississement 5 = QField uniquement désormais.
- **2026-04-23** — E5.a côté `nemeton` livré : `R/field_schema.R`, `R/qfield_export.R`, tests (30 expect OK), tuto 09 Section 6, NEWS + bump dev 0.18.0.9000, doc roxygen regénérée. Suite de tests complète : 1911 / 0 failure / 0 error. Committé `9df1484`, poussé sur `origin/main`.
- **2026-04-23** — E5.a côté `nemetonshiny` livré : `R/mod_sampling.R` (UI + server + downloadHandler), intégration navbar, 14 clés i18n, 23 tests verts. Suite complète 1053 / 0 failure. Bump 0.16.0.9000 avec dépendance `nemeton (>= 0.18.0.9000)`. Committé `f074105`, poussé sur `origin/main`.
- **2026-04-23** — E5.a bis + E5.b côté cœur livrés : `R/sampling_plan.R` (365 l.), `R/qfield_import.R` (403 l.), `detect_ndp()` étendu (placettes → NDP 2, inventaire arbre complet → NDP 3), source `field_qfield` dans `FR.json`, 3 fichiers de tests (`test-sampling-plan.R`, `test-qfield-import.R`, `test-ndp-qfield.R`). Commit `a8ff2cf`.
- **2026-04-24** — Renommage `R/qfield_*.R` → `R/qgis_*.R` et tests correspondants (`test-qgis-export.R`, `test-qgis-import.R`, `test-ndp-field.R`). Les noms de fichiers reflètent désormais la techno sous-jacente (projet QGIS / GPKG) ; les fonctions exportées conservent leurs noms historiques (`create_qfield_project`, `import_qfield_gpkg`).
