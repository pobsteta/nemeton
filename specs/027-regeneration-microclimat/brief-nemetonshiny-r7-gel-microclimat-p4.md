# Brief nemetonshiny — R7 gel tardif + moteur meteoland live (chantier microclimat P4)

- **Repo cible : `nemetonshiny` (app).** À traiter dans une session dev dédiée app.
- **Dépend de `nemeton` (cœur) ≥ v0.151.0** : `indicateur_r7_gel()`, `meteoland_daily_grid()`, `eobs_downscale(engine = "meteoland")` réellement branché, `build_safran_stations()`.
- **Statut :** cadrage. Le cœur est livré et **validé sur données réelles** (meteoland 2.2.7 installé chez Pascal : CRS Lambert-93 natif accepté, interpolate_data → summarise → terra OK). L'app n'a **aucune logique métier à écrire** — elle orchestre, cache, affiche.

## 0. TL;DR

Trois choses côté cœur sont désormais réelles :
1. **R7 « gel tardif »** — nouvel indicateur famille R (`indicateur_r7_gel(units, tmin = …)`), conditionnel comme R5/R6.
2. **`meteoland_daily_grid()`** — produit le raster **Tmin journalier** qui alimente R7 (interpolation SAFRAN → MNT).
3. **`eobs_downscale(engine = "meteoland")`** — l'ancien rail gardé retombait sur KED ; il **tourne** maintenant (Tmax estival, + `meta$cv`).

Côté app : brancher R7 sur le radar (auto), câbler un producteur Tmin **opt-in + caché**, exposer la carte de gel, et surfacer `meta$cv` comme indice de confiance. Rien de plus.

## 1. R7 sur le radar — quasi automatique

`indicateur_r7_gel(units, tmin, budburst_doy = 100, window_end_doy = 180, frost_threshold_c = 0, max_frost_days = 8)` renvoie `units` enrichi de :
- `R7` : score **0–100, haut = FAIBLE risque** de gel (peu de gelées post-débourrement) ;
- `r7_gel_days` : nombre moyen de gelées tardives par an (métrique brute) ;
- `r7_status` : `"calculated"` / `"skipped_no_tmin"`.

Points de câblage app :
- **Sens normal, PAS d'inversion.** R7 suit R1–R4/R6 (haut = bon). Ne **pas** le router comme R5 (seul indicateur haut = mauvais, déjà inversé côté cœur). Le radar qui auto-détecte `^R[0-9]` prend R7 tel quel.
- **Conditionnel.** Sans `tmin`, `R7 = NA` et `r7_status = "skipped_no_tmin"`. Traiter comme R5/R6 déjà absents : le radar doit **ignorer les familles/indicateurs NA** (comportement existant), pas afficher un 0.
- **i18n** : ajouter les libellés `R7` / tooltip « risque de gel tardif » (FR/EN) dans `utils_i18n.R`. Les clés cœur (`indicator-config.R`) portent déjà label/tooltip R7 côté data ; l'UI passe par i18n.

## 2. Produire le Tmin qui alimente R7 — `meteoland_daily_grid()`

C'est LE producteur temps réel. Signature :

```r
tmin <- meteoland_daily_grid(
  aoi, dem, years,
  variable   = "MinTemperature",   # Tmin journalier
  doy_range  = c(60L, 180L),       # ~1 mars – fin juin (fenêtre du gel tardif)
  buffer_m   = 25000,
  max_cells  = 5e5,
  calibrate  = FALSE               # calibration LOO meteoland = LOURDE, opt-in
)
# -> SpatRaster journalier (une couche/jour, terra::time() posé, CRS du MNT) ou NULL
units <- indicateur_r7_gel(units, tmin = tmin)
```

Règles d'orchestration :
- **Opt-in strict**, comme microclimf/biljou : déclenché uniquement par « Lancer l'analyse » (onglet reGénération), jamais au chargement. L'interpolation journalière sur une fenêtre printanière est coûteuse.
- **Cache obligatoire** (patron `pai.tif`) : écrire le stack Tmin sous `cache/regeneration/meteoland/tmin_<emprise>_<years>_<doyrange>.tif`, rechargé via `terra::rast()`. Clé = emprise UGF + années + fenêtre doy.
- **Repli gracieux** : `meteoland_daily_grid()` renvoie `NULL` si meteoland absent, GéoSAS KO, ou < 5 pseudo-stations. Dans ce cas → `indicateur_r7_gel(units, tmin = NULL)` → `r7_status = "skipped_no_tmin"` → R7 absent du radar. **Aucun crash**, jamais.
- **Feedback** : réutiliser le rail de progression/ntfy des autres moteurs (l'acquisition SAFRAN émet déjà via `emit` dans `.biljou_forcing_safran`). Prévoir un message « interpolation gel (meteoland) » distinct de biljou/microclimf.

## 3. Carte de gel

Deux rendus possibles, au choix (le plus simple d'abord) :
- **Choroplèthe par UGF** (immédiat) : colorier les UGF par `r7_gel_days` (gelées/an) ou par le score `R7`. Palette **rouge = critique** : beaucoup de gelées (`r7_gel_days` élevé / `R7` bas) = rouge. Données déjà jointes aux `units`, aucun raster à gérer.
- **Raster de gel** (optionnel) : si on veut une carte continue, dériver un raster « nombre de gelées » depuis le stack `tmin` (compter `tmin < 0` sur la fenêtre par pixel). Hors périmètre minimal — la choroplèthe UGF suffit au P4.

## 4. Moteur meteoland dans `eobs_downscale()` — carte de contexte Tmax

Indépendant de R7 : `eobs_downscale(engine = "meteoland")` produit la carte régionale de **Tmax estival** (tendance/moyenne), **même contrat de sortie que KED** — l'app rend `meta` sans brancher sur le moteur.

Nouveautés à surfacer (facultatif mais recommandé) :
- `meta$engine` vaut `"meteoland"` (idéal) **ou** `"ked"` avec `meta$engine_fallback = TRUE` / `meta$engine_requested = "meteoland"` (repli). Afficher lequel a réellement tourné.
- `meta$cv` (si appelé avec `cv = TRUE`) : `list(r2, mae_tmin, mae_tmax)` — **validation croisée LOO**, à afficher comme indice de confiance (≈ NDP 1, confiance ~25 %). `NULL` en KED.
- Options `calibrate = TRUE` (calibration LOO, meilleure qualité, coûteuse) et `cv = TRUE` (validation croisée, coûteuse) : à n'activer que sur demande explicite (case à cocher « qualité maximale »), pas par défaut.

Aucun changement obligatoire : si l'app appelle déjà `eobs_downscale(engine = "meteoland")`, elle bénéficie du moteur réel automatiquement.

## 5. Le piège de fond (à répéter dans l'UI / les prompts LLM)

meteoland/SAFRAN = météo **de plein champ / au-dessus canopée**, gain = détail **topographique** (gradient altitudinal), **pas** l'effet tampon du couvert. Le microclimat sous canopée réel reste le domaine de `microclimate_run()` (microclimf + LiDAR HD, NDP 2+). **Ne pas confondre les deux échelles** : R7/meteoland = contexte régional NDP 1 ; microclimf = parcelle NDP 2+. Le gel tardif R7 est un risque **de contexte**, à ne pas vendre comme une mesure sous-couvert.

## 6. Garde-fous / disponibilité

- **meteoland en Suggests** (absent possible) : `meteoland_daily_grid()` et le moteur retournent `NULL` proprement → R7 skip. Détecter `requireNamespace("meteoland")` côté app pour griser l'option si absente et l'expliquer à l'utilisateur.
- **GéoSAS SAFRAN** sans auth mais réseau requis : best-effort, repli KED / R7 skip.
- **Coût** : calibration/CV LOO = lourdes → opt-in ; interpolation journalière → cache impératif.

## 7. Non-goals (P4)

- Microclimat sous couvert (→ `microclimate_run()`).
- Stations Météo-France réelles (RADOME/`meteo.data.gouv.fr`) — le cœur est prêt à les accueillir (`build_safran_stations()` agnostique à la source), mais pas livré.
- `rr` (précipitations) hors scope du downscaling, inchangé.

## 8. Checklist app (résumé)

- [ ] i18n : libellés/tooltip R7 (FR/EN) dans `utils_i18n.R`.
- [ ] Radar : vérifier que R7 (NA-safe, sens normal) s'affiche sans routage spécial (contrairement à R5).
- [ ] Onglet reGénération : bouton/option « risque de gel (meteoland) » → `meteoland_daily_grid()` → `indicateur_r7_gel()`, opt-in + caché + repli NULL.
- [ ] Carte de gel : choroplèthe UGF `r7_gel_days` / `R7` (rouge = critique).
- [ ] Griser l'option si `meteoland` absent ; message explicatif.
- [ ] (Option) Surfacer `meta$engine` réel + `meta$cv` de `eobs_downscale(engine = "meteoland")` comme confiance.
- [ ] Feedback/ntfy : phase « interpolation gel » distincte.
