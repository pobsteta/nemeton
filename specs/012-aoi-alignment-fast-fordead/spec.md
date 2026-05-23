# Spec 012 — AOI alignment FAST ↔ FORDEAD

**Statut** : draft, à valider.
**Démarré** : 2026-05-23.
**Cible cœur** : `nemeton` modif `ingest_sentinel2_timeseries()`.
**Cible release** : minor (changement de comportement, pas d'API).

## 1. Problème observé

Sur le projet villards (zone_id 1, 155 placettes, ~17 000 ha d'UGF),
les pipelines FAST et FORDEAD travaillent sur des **AOI différentes** :

| Pipeline | Source AOI | Footprint réel |
|---|---|---|
| **FORDEAD** | `monitoring_zone.zone_wkt` lu par `.get_zone_aoi()` (`R/fordead_pipeline.R:483`) | enveloppe des **UGF** (`st_union(project$indicators_sf)` côté app) — large |
| **FAST** | `sf::st_bbox(plots)` calculé à la volée (`R/monitoring.R:288`) | bbox des **points placettes** GRTS — étroite, contenue dans l'enveloppe FORDEAD |

Conséquences mesurées dans le cache S2 de villards (chemins
`<project>/cache/layers/sentinel2/<scene_id>/<band>.tif`) :

- 195 dossiers tuile T31TFM + 188 tuile T31TGM + 1 tuile T31TFN —
  bandes FORDEAD (B02/B04/B05/B11/B12/B8A) ;
- au lancement d'un FAST sur les mêmes plots, chaque `B04.tif` déjà
  écrit par FORDEAD est marqué **CACHE-STALE** (« extent does not
  cover AOI ») parce que le crop FORDEAD (UGF) ne contient pas
  forcément la bbox des plots — non, l'inverse : la bbox des plots
  étant *contenue* dans l'UGF, on s'attendrait à un cache-hit. Le
  fait que le check échoue suggère que la comparaison `.ext_contains`
  est asymétrique (cf. ci-dessous, à confirmer) ou que les CRS
  divergent entre FORDEAD (EPSG:2154 forcé par `.get_zone_aoi`) et
  FAST (CRS natif du scene COG, EPSG:32631 pour T31).
- coût par cache-stale observé : ~1 min 43 s par bande (B04 +
  B08 + B12 = ~5 min par scène, × 116 scènes = **~9 h** pour clore
  un FAST sur 6 parcelles).

Au-delà du cache, les deux pipelines décrivent en réalité la même
question (« qu'est-ce qui se passe sur ces forêts ? ») et devraient
partager leur lecture du COG. C'est l'invariant à rétablir.

## 2. Décision

**FAST adopte l'AOI FORDEAD** : `ingest_sentinel2_timeseries()` lit
`monitoring_zone.zone_wkt` (via `.get_zone_aoi()` extrait en helper
partagé) et utilise ce polygone — pas la bbox des plots — pour :

1. la recherche STAC (bbox passé à `stac_search_s2()`) ;
2. le crop des bands COG (passé à `.get_s2_band_raster()` → cache
   COG aligné avec FORDEAD).

L'extraction *per-plot* (buffer 15 m via `exactextractr::exact_extract`)
continue d'utiliser `plots` — c'est ce qui distingue les valeurs par
placette dans `obs_pixel`. Seul l'**étage AOI / cache** change.

### Pourquoi pas l'inverse (FORDEAD adopte la bbox plots) ?

- `zone_wkt` est l'invariant sémantique enregistré une fois par
  `register_monitoring_zone()` ; les plots peuvent évoluer (ajout
  d'une placette de validation) sans modifier la zone.
- FORDEAD a *besoin* de l'AOI complète des UGF pour calibrer son
  modèle harmonique sur la totalité du peuplement, pas seulement
  autour des points GRTS.
- L'union des UGF est ce que l'utilisateur **voit** sur la carte du
  projet — c'est l'AOI mentale.

## 3. Livrables cœur

### 3.1 Refactor `.get_zone_aoi()` (rendu interne partagé)

Aujourd'hui privé à `fordead_pipeline.R`, le déplacer dans un fichier
neutre (`R/zone_aoi.R`) avec la même signature. Pas de changement
sémantique.

### 3.2 `ingest_sentinel2_timeseries()` — bbox via zone_wkt

Remplacer `R/monitoring.R:288` :

```r
bbox <- sf::st_as_sfc(sf::st_bbox(plots))
```

par :

```r
aoi  <- .get_zone_aoi(con, zone_id)          # EPSG:2154
bbox <- sf::st_as_sfc(sf::st_bbox(sf::st_transform(aoi, 4326)))
```

Et passer la même `aoi` (en CRS COG, projetée à la volée) en argument
de `.get_s2_band_raster()` qui sert au crop — au lieu de la bbox des
plots actuellement passée. Vérifier que tous les sites d'appel à
`.get_s2_band_raster()` reçoivent désormais `aoi` (UGF) et non
`plots` (points).

### 3.3 Fallback de transition

Si `monitoring_zone.zone_wkt` est NULL ou vide (cas pathologique :
zone créée par un script externe), conserver le comportement v0.43.x
avec un `cli_warn` explicite. Pas de plantage.

### 3.4 Cache existant — purge documentée

Les caches déjà peuplés par FAST v0.43.x ont été écrits avec la bbox
plots ; ils sont obsolètes après spec 012 (la nouvelle AOI les
englobera et déclenchera CACHE-STALE → re-fetch). C'est attendu et
ponctuel (une fois par projet déjà actif). Documenter dans le NEWS
qu'une purge manuelle de `<project>/cache/layers/sentinel2/` est
optionnelle mais recommandée pour éviter une vague unique de
re-fetches.

### 3.5 Tests

- `tests/testthat/test-aoi-alignment.R` :
  - unitaire : `.get_zone_aoi(con, zone_id)` renvoie un sf POLYGON en
    EPSG:2154 ; erreur typée si zone inconnue (déjà couvert par
    tests FORDEAD, à factoriser) ;
  - intégration `with_clean_db` : `register_monitoring_zone(zone_polygon =
    UGF_union)` puis `ingest_sentinel2_timeseries(zone_id)` avec
    STAC mocké, on vérifie que la bbox passée à `stac_search_s2()`
    correspond à l'UGF, **pas** aux plots ;
  - régression : `ingest_sentinel2_timeseries(zone_id)` sur une zone
    avec `zone_wkt` NULL → `cli_warn` + fallback historique.

### 3.6 Investigation parallèle (sous-tâche, non bloquante)

Le journal v0.21.8 documente un fix `.ext_contains()` (`R/monitoring.R:
~640`). Vérifier que la comparaison d'extents est bien CRS-aware :
le COG natif est en EPSG:32631, l'AOI FORDEAD est en EPSG:2154, et
le check « cached extent contains AOI » doit se faire dans un CRS
commun. Si ce n'est pas le cas, le CACHE-STALE permanent pourrait
être un bug indépendant à corriger dans la même release.

## 4. Risques

| Risque | Mitigation |
|---|---|
| Première ingestion FAST plus longue (bbox UGF >> bbox plots) | Une fois cachée, partagée avec FORDEAD — gain net dès le 2e run |
| Caches v0.43.x obsolètes sur projets actifs | Documenté + script `diagnose_s2_cache()` déjà disponible pour audit |
| Plots hors UGF (cas pathologique : placette de validation hors propriété) | Géré côté `exact_extract` qui retourne NA quand le buffer sort du raster ; pas de régression |
| `monitoring_zone.zone_wkt` vide pour zones legacy | Fallback explicite avec warn |

## 5. Hors scope

- Stratégie de cache à granule MGRS complet (au lieu de cropped-AOI)
  — futur chantier potentiel si la pénalité « première ingestion »
  reste prohibitive.
- Parallélisation des 3 bandes d'une scène — futures déjà chargés
  côté app, optimisation orthogonale.
- Modification de `register_monitoring_zone()` — la signature reste
  inchangée ; seule la *consommation* du `zone_wkt` change.

## 6. Suite

Si la spec est validée :

- 1 release minor cœur (ex. **v0.45.0**) — change de comportement
  observable de FAST, justifie un minor même si l'API est stable.
- L'app `nemetonshiny` n'a rien à modifier : elle continue d'appeler
  `ingest_sentinel2_timeseries(con, zone_id, ...)` sans changement.
- Synergie avec spec 011 : le binding `project_uuid` permet de
  retrouver la zone du projet courant, l'alignement AOI permet à
  cette zone d'avoir un cache cohérent entre FAST et FORDEAD.
