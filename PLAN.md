# PLAN — Épaississement 5 : intégration QField

**Démarré** : 2026-04-23
**État global** : E5.a **livré des deux côtés** (cœur `nemeton` + app `nemetonshiny`, poussés sur `main`) ; E5.b (réingestion + montée NDP) à faire
**Branche** : `main` (nemeton tip `9df1484`, nemetonshiny tip `f074105`)

## Contexte

Le tutoriel `inst/tutorials/09-sampling/` produit déjà un plan d'échantillonnage GRTS + parcours TSP exportés en GeoPackage / GPX / CSV. Il manque le dernier maillon : un **projet QField prêt à l'emploi** pour que les agents terrain saisissent directement les données dendrométriques, et le **chemin de retour** pour réingérer les mesures dans les indicateurs et faire monter le NDP.

Les Bounded Contexts concernés :
- **Inventaire** (E5.a aval, E5.b amont)
- **Interopérabilité** (export/import QField — ligne 110 de CLAUDE.md)
- **Analyse systémique** (réingestion déclenche recalcul P1/P2/B2/C1/R2)

## Découpage

### E5.a — Export QField (Néméton → terrain)
Capitalise directement sur les sorties du tuto 09.

**Côté `nemeton`** — livré
- [x] `R/field_schema.R` — `get_placette_schema()` (10 champs), `get_arbre_schema()` (9 + attachement labels), `schema_to_df()`, `empty_sf_from_schema()`. Domaine espèces branché sur `list_species_classes()`.
- [x] `R/qfield_export.R` — `create_qfield_project(placettes, zone_etude, parcours_tsp, output_dir, project_name, crs, region, lang, overwrite)` : `.qgz` (ZIP `.qgs` XML + GPKG) ; zéro nouvelle dépendance.
  - [x] `.qgs` avec `projectCrs`, `layer-tree-group`, `projectlayers`, edit widgets (TextEdit / Range / DateTime / ValueMap / ExternalResource / CheckBox), aliases, NotNull, symbologie categorisée Base/Over
  - [x] GPKG avec `placettes` / `arbres` / `zone_etude` / `parcours_tsp`
  - [x] Emballage via `utils::zip()` avec chemins relatifs
- [x] Tuto 09 : Section 6 « Export QField » + 5e quiz + README mis à jour
- [x] Tests `tests/testthat/test-qfield-export.R` : 30 assertions, toutes vertes. Full suite 1911/0 failure.
- [x] Doc roxygen + NAMESPACE regénérés ; 7 pages d'aide créées

**Côté `nemetonshiny`** — livré (commit `f074105`, branche `main`)
- [x] `R/mod_sampling.R` — UI formulaire + carte leaflet + `downloadHandler` QField. Tirage `st_sample()` spatial aléatoire (première itération ; upgrade GRTS via future `create_sampling_plan()` côté cœur).
- [x] 14 nouvelles clés i18n `tab_sampling` / `sampling_*` / `qfield_*` (FR/EN)
- [x] Entrée navbar « Terrain » (icône `crosshair`) entre Synthèse et Familles
- [x] `testServer()` sur `mod_sampling` : 23 assertions vertes, suite complète 1053 / 0 failure
- [x] Bump `nemetonshiny` 0.16.0.9000, `Imports: nemeton (>= 0.18.0.9000)`

### E5.b — Réingestion QField (terrain → Néméton)

**Côté `nemeton`**
- [ ] `R/qfield_import.R` — `import_qfield_gpkg(path)` + `validate_field_data()` + `aggregate_plot_metrics()`
- [ ] Ajout source `field_qfield` dans `inst/datasources/FR.json`
- [ ] Mise à jour `detect_ndp()` : placettes → NDP 2, inventaire arbre complet → NDP 3
- [ ] Hooks indicateurs : P1/P2/B2 consomment agrégats par placette quand dispo
- [ ] Tests : `test-qfield-import.R`, `test-ndp-qfield.R`

**Côté `nemetonshiny`**
- [ ] `R/mod_field_ingest.R` — dépôt GPKG, rapport de validation, déclenchement recalcul
- [ ] Affichage de la montée de NDP (badge + barre φ)

## Décisions

- **Pas de dépendance lourde pour le `.qgz`** : le format est un simple ZIP d'un `.qgs` XML et du GPKG. On le génère à la main pour rester léger. `happign`, `leaflet` etc. restent en `Suggests`.
- **Deux couches, pas trois** : `placettes` (points GRTS) et `arbres` (saisie terrain), liées par `plot_id`. Le parcours TSP est purement documentaire (couche en lecture seule).
- **Vocabulaire espèces** : réutiliser `R/species-config.R` pour les domaines QField plutôt qu'un hard-code — une seule source de vérité.
- **CRS de sortie** : EPSG:2154 (Lambert-93) pour les GPKG. QField accepte sans souci et c'est l'écosystème IGN natif.
- **Le TSP reste dans le tuto** : on ne déplace pas cette logique vers le cœur pour cette itération (le tuto est la « documentation vivante » de la méthode).

## Prochaine étape

Démarrer E5.a par `R/field_schema.R` (définition du modèle placettes/arbres + domaines), puis `R/qfield_export.R` (.qgs XML + assemblage .qgz).

## Journal

- **2026-04-23** — PLAN.md créé. `tree_sat` et `maestro` retirés de l'Épaississement 5 dans CLAUDE.md (modif locale non committée). Épaississement 5 = QField uniquement désormais.
- **2026-04-23** — E5.a côté `nemeton` livré : `R/field_schema.R`, `R/qfield_export.R`, tests (30 expect OK), tuto 09 Section 6, NEWS + bump dev 0.18.0.9000, doc roxygen regénérée. Suite de tests complète : 1911 / 0 failure / 0 error. Committé `9df1484`, poussé sur `origin/main`.
- **2026-04-23** — E5.a côté `nemetonshiny` livré : `R/mod_sampling.R` (UI + server + downloadHandler), intégration navbar, 14 clés i18n, 23 tests verts. Suite complète 1053 / 0 failure. Bump 0.16.0.9000 avec dépendance `nemeton (>= 0.18.0.9000)`. Committé `f074105`, poussé sur `origin/main`.
