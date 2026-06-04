# Hand-off `nemetonshiny` — wiring des zones de suivi (spec 020, cœur livré)

> **Statut** : à câbler côté app `nemetonshiny`. Le cœur `nemeton` est
> **intégralement livré** (`v0.66.0` + `v0.67.0`). À retirer une fois
> transféré (convention hand-off).

## Contexte

Spec 020 : un projet porte désormais **jusqu'à 4 zones de suivi**
construites par croisement de l'union des UGFs avec les strates BD Forêt v2
(`<projet>_tot/_feu/_res/_mix`). Tout le métier est dans le cœur ; l'app
n'a plus qu'à **appeler** et **présenter**.

Bump plancher : `Imports: nemeton (>= 0.67.0)` (commit `chore(deps):`).

## 1. Bouton « Générer les zones de suivi »

Remplacer l'appel actuel de « Enregistrer ce projet comme zone de suivi »
(qui ne créait qu'une zone) par :

```r
nemeton::build_project_monitoring_zones(
  con,
  project_name = app_state$current_project$name,   # ex. "Mouthe"
  project_uuid = <project_uuid local>,             # le MÊME id que celui
                                                   # déjà stocké en project_uuid
                                                   # (cf. monitoring_zone.project_uuid)
  ugf     = units_sf,                              # sf des UGFs du projet
  bdforet = sf::st_read(bdforet_gpkg, quiet = TRUE) # cache/layers/bdforet.gpkg
)
# -> list nommée des strates créées : $tot, $feu, $res, $mix (zone ids).
#    Strate vide (ex. projet 100% feuillu) -> absente + un cli_warn.
#    replace=TRUE par défaut : upsert (supprime puis recrée les zones du projet).
```

- **BD Forêt** : `cache/layers/bdforet.gpkg` (produit au 1er calcul projet,
  `download_ign_bdforet`). Si absent → message « lancer le calcul du projet
  d'abord » (ne pas appeler la fonction).
- **`project_uuid`** : passer **exactement** l'identifiant que l'app utilise
  déjà comme `monitoring_zone.project_uuid` (format dossier local
  `<ts>_<rand>`, ex. `20260520_212017_btfe`) — c'est lui qui lie zones et
  projet. Ne PAS passer l'UUID de la table `projects` (différent).
- **Toast** : afficher les strates créées et celles éventuellement
  ignorées (vides). L'opération peut prendre quelques secondes
  (intersections sf) → spinner.

## 2. Sélecteur « Zone de suivi » (D6 — corrige le bug villards/Mouthe)

Le bug actuel : quand le projet chargé n'a pas de zone, le menu retombe sur
la **première zone de la base** (zone d'un autre projet, ex. `villards`).
Correctif :

```r
zones <- nemeton::find_zones_by_project(con, <project_uuid local>)
# data.frame(id integer, name character), trié par name, 0 ligne si aucune.

updateSelectInput(
  session, "zone_suivi",
  choices  = if (nrow(zones)) stats::setNames(zones$id, zones$name) else character(0),
  selected = zones$id[zones$name == paste0(.nmt_slug(project$name), "_tot")][1]  # défaut _tot
)
```

- **Choix unique** (pas de multi-select) ; la liste contient les **1 à 4
  zones du projet courant**.
- **Défaut** : la zone `*_tot`.
- **Plus de repli** sur une zone d'un autre projet : si `zones` est vide,
  menu vide + bandeau « générer les zones » (le bandeau existant).
- Le diagnostic (FAST/FORDEAD) tourne sur **la** zone `id` sélectionnée
  (cœur mono-zone, inchangé).

> Le slug du nom de projet pour matcher `_tot` : reproduire la règle NMT
> (lowercase, accents translittérés) ou, plus simple, sélectionner la zone
> dont le `name` se termine par `_tot`.

## 3. Nettoyage des caches orphelins (après upsert)

L'upsert (`replace = TRUE`) réassigne de **nouveaux `zone_id`** → les caches
`zone_<ancien_id>/` deviennent orphelins. Après un
`build_project_monitoring_zones()`, appeler (best-effort) :

```r
nemeton::prune_orphan_zone_caches(
  con,
  cache_root = file.path(project$path, "cache", "layers"))
# supprime fast_alert/zone_<old>/, fast_alert_mask/zone_<old>/,
# fast_sampling/zone_<old>/, fordead/zone_<old>/ … dont le zone_id
# n'existe plus en base. dry_run=TRUE pour prévisualiser.
# sentinel2/ et lidar_* ne sont jamais touchés.
```

(Optionnel : un bouton admin « Nettoyer les caches de zones » qui appelle
`prune_orphan_zone_caches(dry_run = TRUE)` puis confirme.)

## 4. Points UI

- **i18n** : libellés des 4 strates + messages via `i18n$t(...)`. Clés
  suggérées : `zone_tot`, `zone_feu`, `zone_res`, `zone_mix`,
  `zones_generate`, `zones_bdforet_missing`, `zones_empty_stratum`.
- **Affichage carte** : superposer le contour de la zone sélectionnée sur
  la carte (les 4 strates ont des emprises différentes).
- **Garde-fou composition** : le bandeau « essences hors domaine validé »
  (FORDEAD calibré résineux) devient plus pertinent — sur la zone `_res`
  il ne devrait plus se déclencher.

## API cœur livrée (v0.66.0 / v0.67.0)

| Fonction | Rôle |
|----------|------|
| `build_project_monitoring_zones(con, project_name, project_uuid, ugf, bdforet, strata, work_crs, replace)` | construit + upsert les 4 zones |
| `create_monitoring_zone(con, zone_name, zone_polygon, project_uuid)` | insert zone-seule (sans placette) |
| `find_zones_by_project(con, project_uuid)` | liste `(id, name)` des zones du projet |
| `prune_orphan_zone_caches(con, cache_root, subdirs, dry_run)` | purge des caches `zone_<old_id>/` |

Migration **0005** (appliquée par `db_migrate`) : unicité
`monitoring_zone (project_uuid, name)`.

## Références

- Spec : `nemeton/specs/020-zones-suivi-ugf-bdforet/spec.md`.
- App : `mod_monitoring.R` (sélecteur `find_zones_by_project`, bouton
  build ; helpers `.fast_alert_cache_dir`/`.fast_alert_mask_cache_dir`),
  `service_monitoring.R`. BD Forêt : `cache/layers/bdforet.gpkg`.
- Session source : `nemeton` dev session du 2026-06-04.
