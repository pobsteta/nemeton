# Brief `nemetonshiny` — CRS « unknown » sur les rasters WMS NDP 0 (DEM / IRC / NDVI / TWI)

**Cœur requis** : aucun (correctif purement app).
**But** : que les rasters téléchargés par WMS (`download_ign_dem`,
`download_ign_irc_ndvi`) portent leur CRS **EPSG:4326** au lieu de `GEOGCRS["unknown"]`.

---

## 1. Le bug (constaté sur le projet Fordead)

Les rasters NDP 0 de Fordead (`dem.tif`, `irc.tif`, `ndvi.tif`, et `twi.tif`
dérivé) sont en `GEOGCRS["unknown"]` — coordonnées en **degrés** (emprise
[4.9, 5.0, 49.2, 49.2]) mais **sans autorité EPSG** (`describe$code = NA`). La
couche sœur `forest_cover.tif`, **même emprise**, est correctement en `EPSG:4326`
— preuve que le CRS attendu est bien 4326.

**Cause** (`service_compute.R`) : `download_ign_dem()` (~l.2860) et
`download_ign_irc_ndvi()` (~l.2967) demandent `&CRS=EPSG:4326` au WMS IGN et
`&FORMAT=image/geotiff`, mais le GeoTIFF WMS a des **tags CRS malformés** (le
code le note : « Re-write through terra to fix malformed GeoTIFF tags from WMS »).
Le raster est réécrit **sans réassigner le CRS** → `terra::rast()` le lit en
« unknown ».

Propagation :
- `irc.tif` unknown → **`ndvi.tif`** unknown (calculé depuis l'IRC).
- `dem.tif` unknown → **`twi.tif`** unknown (calculé par le cœur
  `get_or_compute_twi()` depuis le DEM, hérite du CRS).

Conséquence : « CRS do not match » sur les extractions (C2 NDVI, R1/R2/R3/W3),
indices NA — même famille de bug que le CRS LiDAR (brief
`brief-nemetonshiny-lidar-crs.md`), mais côté sources **publiques 4326**.

## 2. Correctif app (2 points, la même ligne)

Le WMS est **interrogé en 4326** : le raster retourné EST en 4326, il suffit de
le tamponner après lecture, avant cache / calcul.

**(a) `download_ign_dem()`** (~l.2892) :

```r
rast <- suppressWarnings(terra::rast(temp_file))
if (is.na(terra::crs(rast, describe = TRUE)$code)) terra::crs(rast) <- "EPSG:4326"
terra::writeRaster(rast, cache_file, overwrite = TRUE)
```

**(b) `download_ign_irc_ndvi()`** (~l.2990, après lecture du GeoTIFF IRC) :

```r
irc <- suppressWarnings(terra::rast(temp_file))
if (is.na(terra::crs(irc, describe = TRUE)$code)) terra::crs(irc) <- "EPSG:4326"
# ...writeRaster(irc, irc_cache_file) puis calcul NDVI -> hérite du CRS.
```

`ndvi.tif` et `twi.tif` héritent alors automatiquement du 4326 (pas de garde
supplémentaire nécessaire). Le CRS **demandé au WMS** (ici toujours `EPSG:4326`)
est la source de vérité — ne pas coder 4326 en dur si l'URL WMS passe un jour à
un autre CRS ; lire la valeur du paramètre `CRS=` de la requête.

## 3. Ne pas confondre avec le CRS LiDAR (2154)

Le CRS correct **dépend de la source** :
- LiDAR HD (`lidar_mnt`/`mnh`, mosaïques, TWI dérivé) → **EPSG:2154**
  (`brief-nemetonshiny-lidar-crs.md`).
- WMS NDP 0 (DEM BD ALTI, IRC BD ORTHO) → **EPSG:4326** (ce brief).

**Ne jamais tamponner 2154 en aveugle** : sur Fordead (coordonnées en degrés),
2154 placerait le raster près de l'origine Lambert-93 (au large de l'Afrique).

## 4. Caches existants

Déjà réparés à la main pour les projets sur disque :
- Fordead (`…_armn`) : `dem/irc/ndvi/twi.tif` → 4326.
Pour un projet NDP 0 existant, réparation ponctuelle (seulement si une couche
sœur confirme 4326) :
```r
for (f in c("dem.tif","irc.tif","ndvi.tif","twi.tif")) {
  p <- file.path(L, f); if (!file.exists(p)) next
  r <- terra::rast(p)
  if (is.na(terra::crs(r, describe = TRUE)$code)) {
    terra::crs(r) <- "EPSG:4326"; terra::writeRaster(r, p, overwrite = TRUE)
  }
}
```

## 5. À part — `dem.tif` corrompu (RECONFORT)

Sur RECONFORT, `dem.tif` (WMS) est en plus **dégénéré en dimensions**
(141×199, emprise [2..48]) : réponse WMS invalide, pas seulement un CRS. Sans
impact (le projet utilise `lidar_mnt`), mais le garde de (a) ne le « répare » pas
— à traiter séparément si le BD ALTI de repli est un jour requis.

## 6. Règles

1. Toujours réassigner le CRS **demandé** après un GetMap WMS `image/geotiff`
   (les tags GeoTIFF WMS d'IGN sont notoirement malformés).
2. CRS par source, jamais de 2154 par défaut hors LiDAR HD.
