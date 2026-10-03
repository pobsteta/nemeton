# BRIEF — nemeton 0.209.0 : robustesse des données (audit 1.0, vague 2)

> **Émis le 2026-10-03** par la session `nemeton`. **Packages** : `nemeton`
> (livré en **v0.209.0**), `nemetonshiny` (demandeur). Rapport à jour :
> https://claude.ai/artifact/EDFFCM5SmJ78DAAeuzTYs2

## 1. À faire côté app

1. **`prune_orphan_zone_caches(con, cache_dir, project_uuid = , force = FALSE)`**
   — deux nouveaux arguments. Sans `project_uuid`, la purge est refusée
   seulement si la base n'a aucune zone. Passer `project_uuid = <uuid du
   projet>` dans `mod_monitoring.R` (vers la ligne 1402, appel actuel) active
   le contrôle par projet : rien n'est purgé si la base connectée ne connaît
   aucune zone de ce projet (cas d'une app pointée sur une autre base).
2. Plancher `Imports: nemeton (>= 0.209.0)`.

## 2. Comportements qui changent à l'écran

| Où | Effet |
|---|---|
| Suivi sanitaire, liste des alertes | Un run FORDEAD/RECONFORT **réussi sans alerte** purge les alertes `pending` précédentes (les validées restent). |
| Import des validations QField | `ingest_health_validation()` peut avertir ; `details$reason` peut valoir `"unknown_stade"`. `"sain "` (espace finale) est accepté au lieu de valoir « confirmé ». |
| Ingestion Sentinel-2, projets multi-zones | Des scènes autrefois sautées « en cache » sont retraitées (emprise contrôlée) : l'événement `s2:cache_lookup` peut annoncer moins de scènes en cache. |
| Événements `s2:band_fetch_failed` | `href` et `error_message` n'ont plus de query string (jeton retiré). |
| reGénération, E-OBS | Un été incomplet (souvent l'été en cours) disparaît des séries, avec avertissement. `eobs:unavailable` porte un champ `message`. BILJOU : payloads `biljou:complete` / `biljou:unavailable` avec `missing_ids` et `reason`. |
| Diagramme ombrothermique | Cumul mensuel de pluie sur mois complets seulement (hausse là où des jours manquaient). |
| `tendances_estivales_eobs()` | Pentes **par décennie** (× 10). Non appelée par l'app (vérifié) ; à savoir si elle l'est un jour. |
| LiDAR (`compute_dtm_chm_from_laz(aoi = )`) | Avec une AOI, les chemins renvoyés pointent vers des copies rognées `aoi/<dtm|chm>_<hash>.tif` ; le cache partagé reste complet. |

## 3. Caches recalculés une fois

ERA5 (`era5_<lon>_<lat>_<annee>…`), microclimat, vent NASA POWER, MNT/MNH LiDAR
sans clé, dossiers de diversité spectrale sans clé, marqueurs RECONFORT
`.done`. Les anciens fichiers restent sur le disque mais ne sont plus relus.
Premier run après mise à jour plus long.
