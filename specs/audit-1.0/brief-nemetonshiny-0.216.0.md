# BRIEF `nemetonshiny` — nemeton 0.216.0 : n° 64-66 livrés dans le cœur

> **Émis le 2026-10-05** par la session `nemeton`, en réponse à
> `2026-10-05-logique-metier-a-rapatrier.md`. Cœur publié en **v0.216.0**.

## 1. Les trois fonctions

| n° | Remplace côté app | Fonction cœur |
|---|---|---|
| 64 | `build_s2_ndvi_layer()` (choix des scènes + médiane + bornage) | `nemeton::build_ndvi_season_composite(s2_dir, mask_polygon = aoi)` |
| 65 | `.regen_ctx_ombro_stats()` | `nemeton::climate_ombrothermic_indices(clim_rr, clim_t)` |
| 66 | `project_family_means()` | `nemeton::aggregate_family_scores(indicators_sf, weights = "surface")` |

- **n° 64** : mêmes réglages par défaut que l'app (saison DOY 152-273, 12
  scènes les plus récentes, médiane, `clamp = c(0, 1)`). `scenes = NULL` liste
  le cache comme `.scan_s2_cache_scenes()`. Le résultat porte l'attribut
  `"scenes"` (`scene_id`, `obs_date`) pour le message « N scènes, du … au … ».
  Rend `NULL` quand aucune scène n'est exploitable. L'app garde son cache
  `ndvi_s2.tif` et l'appel.
- **n° 65** : même sortie `list(dry_idx, dry_months, demartonne)`, mêmes règles
  NA. Seul écart : `dry_idx` et `dry_months` sont des entiers, et De Martonne
  vaut NA si la température moyenne est exactement -10 °C.
- **n° 66** : vecteur nommé, un score par colonne `famille_*`, avec un attribut
  `"weighting"` (`"surface"` ou `"none"`, la pondération réellement appliquée).
  Surface lue dans `surface_m2`, sinon calculée depuis la géométrie ; si une UGF
  n'a pas de surface exploitable, la fonction prend la moyenne simple et
  avertit. `weights = "none"` redonne exactement l'ancien calcul (utile pour
  les tests d'équivalence).

## 2. À faire côté app

1. Plancher `Imports: nemeton (>= 0.216.0)`.
2. Remplacer les trois calculs locaux par les appels cœur. Tests
   d'équivalence : l'onglet Synthèse, `projet_etat()` et le serveur MCP rendent
   le même score.
3. NEWS app : **les scores de famille et le score global affichés changent**
   avec la pondération par la surface. `indicator_sense_version` ne bouge pas,
   parce que les valeurs des indicateurs restent les mêmes.
4. **À ne pas oublier : le cache `ndvi_s2.tif`** (composite C2) n'a pas de clé
   de version. Les composites calculés avant la 0.215.0 portent l'offset
   Sentinel-2 (NDVI sous-estimé d'environ 0,3 en forêt) et resteraient servis.
   Il faut l'invalider une fois, par exemple en versionnant le nom du fichier
   (`ndvi_s2_v2.tif`) ou en le supprimant à la migration.
5. Ajouter ces trois fonctions à `specs/audit-1.0/exports-consommes-app.md`
   (côté cœur) dans le prochain brief PLAN, une fois l'adoption faite.
