# Brief `nemetonshiny` — Nettoyages basse priorité (CRS sources + Theia)

**Note unique regroupant 3 chantiers app non bloquants.** Aucun n'empêche
l'app de fonctionner : le cœur compense déjà (CRS normalisé à la lecture depuis
v0.138.1/0.138.2 ; `theia_configure_s3()` déprécié n'émet qu'un avertissement).
Ce sont des corrections **à la source** (hygiène du cache, retrait d'un appel
mort) à faire quand tu passes en session `nemetonshiny`.

**Cœur requis** : `nemeton (>= 0.140.0)` (déjà le plancher app). Aucun changement cœur.

Briefs détaillés d'origine (contexte complet, conservés) :
- `specs/027-regeneration-microclimat/brief-nemetonshiny-lidar-crs.md`
- `specs/027-regeneration-microclimat/brief-nemetonshiny-wms-crs.md`
- `specs/033-lai-prosail-sentinel2/brief-nemetonshiny-theia-migration.md`

> **Règle d'or transversale** : le CRS correct **dépend de la source**.
> LiDAR HD → **EPSG:2154** ; WMS NDP 0 → **EPSG:4326**. **Ne jamais tamponner
> 2154 en aveugle** (sur un projet WMS en degrés, ça enverrait le raster au large
> de l'Afrique). Le garde ne stampe **que** si `terra::crs(r, describe=TRUE)$code`
> est `NA`.

---

## 1. CRS LiDAR HD « sans autorité » → stamp **EPSG:2154** à la source

**Fichier** : `service_compute.R`. Les GeoTIFF LiDAR HD IGN sont lus avec un WKT
dégénéré (`PROJCRS["EPSG:2154", … DATUM["unnamed"]]`, `describe$code = NA`). Le
contrôle de couverture `.lidar_mosaic_covers_bbox()` rejette alors la mosaïque
**avant** que le cœur ne la voie → « No DEM available » + re-téléchargements.

Même ligne de garde à 3 endroits (LiDAR HD = 2154 par définition) :

**(a) `mosaic_lidar_tiles()`** — avant `writeRaster` de la mosaïque :
```r
if (is.na(terra::crs(mos, describe = TRUE)$code)) terra::crs(mos) <- "EPSG:2154"
terra::writeRaster(mos, mosaic_cache, overwrite = TRUE)
```
**(b) retour cache** (~l.3207, `return(terra::rast(mosaic_cache))`) :
```r
r <- terra::rast(mosaic_cache)
if (is.na(terra::crs(r, describe = TRUE)$code)) terra::crs(r) <- "EPSG:2154"
return(r)
```
**(c) `.lidar_mosaic_covers_bbox()`** (~l.3112) — avant le `st_transform` :
```r
r <- terra::rast(mosaic_path)
if (is.na(terra::crs(r, describe = TRUE)$code)) terra::crs(r) <- "EPSG:2154"
```
(a)+(b) corrigent ; (c) supprime les re-téléchargements. Le cœur v0.138.1 reste
le filet côté indicateurs.

---

## 2. CRS WMS NDP 0 « unknown » → réassigner **EPSG:4326** après download

**Fichier** : `service_compute.R`. Le WMS IGN sert des GeoTIFF au datum ambigu
(`GEOGCRS["unknown"]`, `code = NA`) alors que la requête demande `CRS=EPSG:4326`
et que les coordonnées **sont** en 4326 (couche sœur `forest_cover.tif` = 4326).
L'app ne réassigne pas le CRS demandé après lecture.

**(a) `download_ign_dem()`** (~l.2892) :
```r
rast <- suppressWarnings(terra::rast(temp_file))
if (is.na(terra::crs(rast, describe = TRUE)$code)) terra::crs(rast) <- "EPSG:4326"
terra::writeRaster(rast, cache_file, overwrite = TRUE)
```
**(b) `download_ign_irc_ndvi()`** (~l.2990) :
```r
irc <- suppressWarnings(terra::rast(temp_file))
if (is.na(terra::crs(irc, describe = TRUE)$code)) terra::crs(irc) <- "EPSG:4326"
```
`ndvi.tif` (dérivé IRC) et `twi.tif` (dérivé DEM) héritent → pas de garde en plus.
Idéalement lire la valeur du paramètre `CRS=` de l'URL WMS plutôt que coder 4326
en dur (si le WMS passe un jour à un autre CRS).

> **Hors CRS** : sur RECONFORT, `dem.tif` (WMS) est aussi **dégénéré en dimensions**
> (141×199, emprise [2..48]) — réponse WMS invalide, pas qu'un CRS. Sans impact
> (le projet utilise `lidar_mnt`) ; à traiter si le BD ALTI de repli est requis.

---

## 3. Theia : retirer `theia_configure_s3()` (déprécié) + commentaires périmés

Le cœur signe désormais en interne via la gateway `signing.stac.teledetection.fr`
(pur R). `theia_configure_s3()` est **déprécié** (n'active rien, avertit).

**(a) `service_compute.R:1207`** (bloc SUFOSAT / coupes rases) — retirer l'appel :
```r
# AVANT : ok <- tryCatch({ nemeton::theia_configure_s3(); TRUE }, error = ...)
#         if (!ok) return(NULL)
# APRÈS : garder seulement le garde amont theia_key_configured() (TLD_* non vides),
#         puis directement load_theia_source("sufosat", aoi_2154, asset = ...).
fetched <- tryCatch(list(
  dates = nemeton::load_theia_source("sufosat", aoi_2154, asset = "dates"),
  proba = nemeton::load_theia_source("sufosat", aoi_2154, asset = "proba")),
  error = function(e) { cli::cli_warn("Coupes rases : load_theia_source a échoué : {conditionMessage(e)}"); NULL })
```
**(b) Commentaires périmés** (reticulate n'est plus utilisé pour THEIA `year`) :
- `service_theia.R` (~l.51/62) : « signs … through reticulate » → via la gateway (R pur).
- `service_compute.R` (~l.539) : « bug load_theia_source côté reticulate » → n'est plus reticulate.
(`reticulate` reste requis ailleurs — FORDEAD/RECONFORT — **ne pas** le retirer.)

**(c) À vérifier — badge canopée** : si `regen_canopy_provenance()`
(`service_regeneration.R`) n'utilise pas déjà `nemeton::canopy_provenance()`
(clés `"lidar_hd"`/`"prosail_s2"`/`"opencanopy"`), basculer dessus (cf.
brief theia-migration §3). Le lecteur `canopy_source` semble en place — juste
confirmer que les clés du `switch()` du badge + i18n sont alignées.

---

## 4. Caches existants (réparation one-shot au chargement de projet)

Les projets déjà en cache portent le CRS cassé. Réparation ponctuelle, **CRS
selon la source**, seulement si `describe$code` est `NA` :

```r
# LiDAR HD -> 2154
for (f in c("lidar_mnt_mosaic.tif","lidar_mnh_mosaic.tif","twi.tif")) {
  p <- file.path(L, f); if (!file.exists(p)) next
  r <- terra::rast(p)
  if (is.na(terra::crs(r, describe = TRUE)$code)) { terra::crs(r) <- "EPSG:2154"; terra::writeRaster(r, p, overwrite = TRUE) }
}
# WMS NDP 0 -> 4326 (seulement si une couche sœur, ex. forest_cover.tif, confirme 4326)
for (f in c("dem.tif","irc.tif","ndvi.tif","twi.tif")) {
  p <- file.path(L, f); if (!file.exists(p)) next
  r <- terra::rast(p)
  if (is.na(terra::crs(r, describe = TRUE)$code)) { terra::crs(r) <- "EPSG:4326"; terra::writeRaster(r, p, overwrite = TRUE) }
}
```
> Ne pas appliquer les DEUX boucles au même dossier : choisir 2154 (projet LiDAR)
> **ou** 4326 (projet WMS) selon la nature du projet. Déjà réparés à la main :
> RECONFORT (→2154), Fordead (→4326).

---

## 5. Validation

- **LiDAR** : projet RECONFORT → « Lancer l'analyse » → plus de « No DEM available »,
  R1/R2/R3/W3 non-NA, carte R3 colorée (~60-67).
- **WMS** : projet Fordead → C2/NDVI et R1/R2/R3/W3 non-NA (plus de « CRS do not match »).
- **Theia** : run coupes rases (T3) → acquiert SUFOSAT **sans** `theia_configure_s3`.

## 6. Priorité / ordre suggéré

1. **Theia §3(a)** — 2 lignes, débloque proprement le chemin SUFOSAT (le plus visible).
2. **LiDAR §1** + **WMS §2** — hygiène du cache, évite de re-produire des CRS cassés.
3. **§4** one-shot — seulement pour les projets déjà en cache qu'on veut rejouer.

Aucun n'est urgent : sans ces correctifs, le cœur normalise à la lecture et T3
fonctionne (l'appel déprécié n'échoue pas). C'est du nettoyage à la source.
