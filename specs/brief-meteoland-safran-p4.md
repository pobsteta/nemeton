# Brief nemeton (cœur) — Moteur meteoland alimenté par SAFRAN (chantier microclimat P4)

- **Repo cible : `nemeton` (cœur).** À traiter dans une session dev dédiée cœur.
- **Statut :** cadrage. À valider avant sprint. **meteoland absent de l'environnement CI** → moteur validé sur données réelles (chez Pascal), comme microclimf/biljouR.
- **Dépend de :** `eobs_downscale()` (v0.149.0, le rail `engine = "meteoland"` est déjà en place), `.biljou_forcing_safran()` (acquisition SAFRAN déjà écrite et testée pour BILJOU).

## 1. Objet

Concrétiser la branche `engine = "meteoland"` d'`eobs_downscale()`, aujourd'hui un **rail gardé qui retombe sur KED** (`.eobs_ds_run_meteoland()` renvoie `NULL`). Le remplacer par une vraie interpolation **station-based** (meteoland : Thornton et al. 1997 + correction altitude + calibration LOO), à **contrat de sortie identique** au moteur KED — l'app ne teste jamais le moteur.

C'est l'Option A du brief microclimat (`brief-microclimat-nemeton.md`), phasée après le KED (Option B, livrée).

## 2. La donnée : SAFRAN via GéoSAS — déjà branché

Point clé, qui tranche la question « meteoland a-t-il des stations ? » : **SAFRAN n'est pas un réseau de stations**, c'est une réanalyse maillée ~8 km (elle assimile les stations Météo-France, mais sort une grille). **Cela suffit à meteoland** : chaque maille SAFRAN devient une pseudo-station (série journalière + altitude), et c'est exactement ce que `create_meteo_interpolator()` attend en référence.

Et cette donnée est **déjà acquise dans le cœur** : `.biljou_forcing_safran(points, years)` interroge l'OGC API-EDR GéoSAS (`https://api.geosas.fr/edr/collections/safran-isba/position`, sans authentification, `R/load_biljou.R`) et renvoie une liste nommée de `data.frame` bruts par point (colonnes `time`/`DATE` + variables `_Q`). **On réutilise ce helper**, on n'ajoute pas de source.

### 2.1 Réserve à lever — Tmin/Tmax manquants

Le jeu SAFRAN actuellement demandé (`.BILJOU_SAFRAN_PARAMS`) est orienté bilan hydrique :
`ETP_Q, PRELIQ_Q, PRENEI_Q, T_Q, SSI_Q, FF_Q, HU_Q` — **`T_Q` est la température moyenne**. Or les débouchés régénération de meteoland (§5 du brief microclimat) exigent :
- **Tmin** → gel tardif (dernière gelée printanière) ;
- **Tmax** → stress thermique estival.

**À faire** : étendre la requête EDR aux variables SAFRAN **min/max journalières** (vérifier les noms exposés par la collection `safran-isba` — vraisemblablement `TINF_Q`/`TSUP_Q` ou équivalent ; **ne pas présumer, lire le `/collections/safran-isba` de l'EDR**). Sans elles, le moteur meteoland se limite à Tmoy/précip/PET, ce qui ne débloque pas le gel ni le stress thermique.

### 2.2 Altitude des pseudo-stations

meteoland impose `elevation` par point de référence. Deux options :
- **(recommandé)** extraire l'altitude du **MNT** (déjà passé à `eobs_downscale()`) au centre de chaque maille SAFRAN → cohérent avec le moteur KED, aucune donnée en plus ;
- ou lire l'altitude de référence SAFRAN si l'EDR l'expose (à vérifier).

`slope`/`aspect` (covariables meteoland optionnelles) : dérivées du MNT comme dans `.eobs_ds_covariates()`.

## 3. Contrat — identique à `eobs_downscale()` (CRITIQUE)

`.eobs_ds_run_meteoland(var, eobs, dem, aoi, buffer_m, resolution, covariates, statistic, years, max_cells, cache_path)` doit renvoyer **exactement** la même forme que le moteur KED :

```r
list(raster = <SpatRaster mono-couche, CRS du MNT>, meta = list(
  status = "ok", engine = "meteoland", method = "meteoland",
  var, statistic, crs, unit, value_label,
  palette = list(low=, high=, sense = "hot_unfavorable"),
  n_points,               # nombre de mailles SAFRAN de référence
  cv = list(r2=, rmse=)   # NOUVEAU : validation croisée LOO (métadonnée de confiance)
))
```

Ainsi `eobs_downscale(engine = "meteoland")` cesse de retomber sur KED, et l'app rend le raster sans rien changer (elle lit `meta`). En cas d'indisponibilité (meteoland absent, réseau GéoSAS KO, < N mailles) → **retour `NULL`**, l'appelant retombe sur KED comme aujourd'hui : **le moteur ne casse jamais la sortie.**

## 4. Pipeline meteoland (API v2.2, refonte sf/stars)

Le nerf : meteoland interpole une **variable journalière**, pas une tendance réduite. Pour honorer `statistic = "trend"`, on interpole **par année** puis on recompose la statistique sur la grille fine.

```r
# 1. Grille de pseudo-stations SAFRAN sur AOI + buffer (mailles ~8 km intersectant).
#    points = centres de maille ; series = .biljou_forcing_safran(points, years).
#    -> sf "stations" : geometry + elevation (MNT) + série journalière (Tmin/Tmax/…).
stations <- build_safran_stations(aoi, buffer_m, years, dem)   # NOUVEAU helper

# 2. Interpolateur + calibration LOO (coûteuse -> cache/versionnement).
interp <- meteoland::create_meteo_interpolator(meteoland::with_meteo(stations))
interp <- meteoland::interpolator_calibration(interp, variable = "MaxTemperature") |>
          meteoland::set_interpolation_params(interp)

# 3. Grille cible = MNT (bornée max_cells, comme KED) en `stars`.
grid <- stars_from_dem(dem, max_cells)                         # NOUVEAU helper

# 4. Interpolation journalière par été, agrégée à l'année.
per_year <- lapply(years, function(y) {
  d <- meteoland::interpolate_data(grid, interp, dates = summer_dates(y))
  meteoland::summarise_interpolated_data(d, fun = "max", frequency = "year")  # tx estival
})

# 5. Recomposition de la statistique sur la grille fine :
#    - "value"/"mean" : moyenne des couches annuelles ;
#    - "trend"        : pente OLS/décennie par pixel (réutiliser .eobs_ds_slope).
raster <- reduce_statistic(per_year, statistic, years)         # même sémantique que KED

# 6. Validation croisée -> cv (confiance / NDP).
cv <- meteoland::interpolation_cross_validation(interp)$stats   # R², RMSE, biais
```

**Réutilisation maximale du cœur existant** : `.eobs_ds_slope()`, `.eobs_ds_agg_factor()` (cap cellules), `.eobs_aoi_buffer()`, la palette/quantiles du contrat. Seuls `build_safran_stations()`, `stars_from_dem()` et le glue meteoland sont neufs.

## 5. Garde-fous (brief microclimat §11)

- **Densité de stations** : plancher de mailles SAFRAN dans le buffer (sinon `NULL` → repli KED). SAFRAN à 8 km est dense partout en France métropolitaine, mais un très petit buffer peut n'en capter qu'une poignée.
- **Enveloppe convexe** : meteoland alerte hors enveloppe des stations → les pixels du MNT en bordure de réseau sont extrapolés ; les masquer ou les flagguer.
- **Coût de calibration LOO** : lourde. **Cacher l'interpolateur** (façon `pai.tif`) sous `cache/regeneration/meteoland/`, versionné par emprise + années.
- **NDP** : sortie meteoland ≈ **NDP 1** (interpolation multi-source, confiance ~25 %). Le documenter dans `meta$cv` + la confiance φ. Ne **pas** sur-promettre du microclimat sous couvert (cf. §6).

## 6. Le piège de fond, à écrire noir sur blanc

SAFRAN (ou toute station Météo-France) mesure une météo **de plein champ / au-dessus de la canopée**. meteoland gagne le **détail topographique** (gradient altitudinal), **pas** l'effet tampon du couvert. Le microclimat forestier réel (T° sous canopée, VPD sous couvert) reste le domaine de `microclimate_run()` (microclimf + LiDAR HD, spec 027). **Les deux échelles restent séparées** : meteoland = contexte régional NDP 1 ; microclimf = parcelle NDP 2+. Ne pas les confondre dans l'UI ni les prompts LLM.

## 7. Vraies stations en option (montée en NDP)

Si un jour on veut mieux que SAFRAN : depuis 2024, **Météo-France a ouvert ses données climatologiques quotidiennes** (stations RADOME, via l'API publique / `meteo.data.gouv.fr`) — vraies mesures ponctuelles à altitudes variées, non lissées à 8 km. `build_safran_stations()` doit rester **agnostique à la source** (SAFRAN par défaut, stations réelles en option) pour préparer cette montée. Hors périmètre P4.

## 8. Tests (testthat)

Contrainte : **meteoland absent en CI** → le pipeline meteoland n'est pas exécutable en CI (comme microclimf). Ce qui EST testable :

- `build_safran_stations()` avec un `.biljou_forcing_safran` **mocké** (`local_mocked_bindings`) → sf de stations avec `elevation`, série journalière, CRS correct.
- Extraction d'altitude MNT aux points SAFRAN.
- `reduce_statistic()` (réutilise `.eobs_ds_slope`) : tendance 0,3 °C/an → 3 °C/décennie (déjà couvert côté KED, à répliquer sur le chemin meteoland).
- Garde-fous : < N mailles → `NULL` (repli KED) ; hors enveloppe → masqué.
- Contrat : `meta$engine == "meteoland"`, `meta$cv` présent, même clés que KED.
- Le pipeline meteoland complet : `skip_if_not_installed("meteoland")` (skippé en CI, tourne chez Pascal).

## 9. Dépendances

`meteoland (>= 2.2.0)` **déjà en Suggests** (ajouté en v0.149.0). GPL — **compatible** cœur GPL-3 (la réserve licence du brief microclimat datait de l'ère MIT, obsolète). `stars` à ajouter en Suggests (grille meteoland). `sf`/`terra` déjà présents.

## 10. Livrables & release

- `.eobs_ds_run_meteoland()` **réellement implémenté** (remplace le stub `NULL`).
- Helpers `build_safran_stations()`, `stars_from_dem()`, `reduce_statistic()` (ou factorisation depuis KED).
- Extension `.BILJOU_SAFRAN_PARAMS` (ou jeu dédié) avec Tmin/Tmax — **après lecture de l'EDR**.
- `meta$cv` (validation croisée) ajouté au contrat des DEUX moteurs (KED : `cv = NULL`).
- Tests (mock SAFRAN + skip meteoland).
- Bump **mineur** (nouveau moteur, contrat élargi non cassant). Reporter dans `nemetonshiny` (aucun changement app requis : `engine = "meteoland"` marche déjà via le contrat).

## 11. Non-goals (P4)

- Microclimat sous couvert (→ `microclimate_run()`).
- `rr` (précipitations) reste hors scope, comme le KED v1.
- Stations Météo-France réelles (préparé §7, pas livré).
- Réimplémentation MLRK (Option B du brief microclimat, chantier distinct).
