# Brief `nemetonshiny` — CRS Lambert-93 « sans autorité » sur les rasters LiDAR HD

**Cœur requis** : `nemeton (>= 0.138.1)`.
**But** : réparer le CRS dégénéré des rasters LiDAR HD cachés pour que **R1/R2/R3
et W3** retrouvent leur DEM (symptôme : « No DEM available », indices NA).

---

## 1. Le bug (constaté en exécutant R3 sur RECONFORT)

Les GeoTIFF LiDAR HD IGN cachés (dalles `lidar_mnt/`, mosaïque
`lidar_mnt_mosaic.tif`, et le TWI dérivé `twi.tif`) sont lus par GDAL/PROJ avec
un **WKT dégénéré** :

```
PROJCRS["EPSG:2154",
    BASEGEOGCRS["unknown",
        DATUM["unnamed",
            ELLIPSOID["unretrievable - using WGS84", ...]]]  # aucune autorité EPSG
```

Le code EPSG est dans le **nom** mais **sans autorité** rattachée →
`terra::crs(r, describe=TRUE)$code` = `NA`. Conséquences en chaîne :

1. **`.lidar_mosaic_covers_bbox()`** (`service_compute.R:3112`) fait
   `sf::st_transform(req_poly, sf::st_crs(r_crs))` vers ce CRS dégénéré → échoue
   / renvoie FALSE → **la mosaïque est rejetée**, jamais enregistrée dans
   `layers$rasters$lidar_mnt` → `get_dem_raster()` renvoie NULL → **« No DEM
   available »** (R1/R2/R3/W3 = NA).
2. Même quand le DEM est chargé, l'extraction sur les UGF (EPSG:4326) échoue
   (« CRS do not match ») → NA.
3. Le `twi.tif` caché hérite du même CRS dégénéré → `compareGeom` FALSE →
   resample → **NA** → `topo_risk` NA → R3 NA (même DEM réparé).

> `dem.tif` (BD ALTI) du projet RECONFORT est en plus **corrompu** (141×199,
> emprise [2..48]) — à régénérer ; mais `lidar_mnt` est de toute façon prioritaire.

## 2. Ce que le cœur fait déjà (v0.138.1)

Le cœur **récupère l'autorité EPSG depuis le nom du WKT** (`.normalize_crs()`,
interne) aux points de consommation : `get_dem_raster()`,
`get_or_compute_twi()`, et à l'entrée `dem` de R1/R2/R3/W3. Donc **dès que le
raster atteint un indicateur**, son CRS est réparé (R3 validé : 0 NA, range
60-67 sur les 30 UGF, sans aucune retouche des fichiers).

**Mais** le cœur n'intervient qu'**après** l'enregistrement dans `layers`. Le
rejet au contrôle de couverture (point 1.1) se produit **avant**, côté app. Il
reste donc **une** correction app indispensable.

## 3. Correctif app « en place » pour les futurs projets (2 points exacts)

Le produit LiDAR HD est **par définition EPSG:2154**. Point d'insertion unique et
minimal, repéré dans `service_compute.R` :

**(a) Sortie fraîche — dans `mosaic_lidar_tiles()`** (appelée par
`resolve_lidar_layer()` : `result <- mosaic_lidar_tiles(downloaded_files,
mosaic_cache)`). Juste avant d'écrire / de retourner la mosaïque :

```r
# LiDAR HD = EPSG:2154 ; récupère l'autorité si GDAL a lu un WKT « sans autorité ».
if (is.na(terra::crs(mos, describe = TRUE)$code)) terra::crs(mos) <- "EPSG:2154"
terra::writeRaster(mos, mosaic_cache, overwrite = TRUE)
```

**(b) Retour cache — ligne ~3207** (`return(terra::rast(mosaic_cache))`) : ne pas
retourner un CRS dégénéré :

```r
r <- terra::rast(mosaic_cache)
if (is.na(terra::crs(r, describe = TRUE)$code)) terra::crs(r) <- "EPSG:2154"
return(r)
```

**(c) Contrôle de couverture — `.lidar_mosaic_covers_bbox()` (l.3112)** : même
garde avant le `st_transform`, sinon la mosaïque dégénérée est rejetée et
re-téléchargée à chaque run (coûteux, même si le cœur v0.138.1 sauve ensuite
l'extraction) :

```r
r <- terra::rast(mosaic_path)
if (is.na(terra::crs(r, describe = TRUE)$code)) terra::crs(r) <- "EPSG:2154"
```

Les trois gardes sont la **même ligne**. (a)+(b) suffisent à la correction ;
(c) supprime les re-téléchargements inutiles. Le cœur v0.138.1 reste le filet
côté indicateurs.

## 4. Caches existants (RECONFORT & co.)

Les projets déjà téléchargés ont des fichiers au CRS dégénéré. Deux voies :
- re-télécharger/re-cacher (déclenche le correctif (a)) ;
- ou un **one-shot de réparation** au chargement d'un projet existant :
  re-tamponner `EPSG:2154` sur `cache/layers/lidar_mnt_mosaic.tif`,
  `lidar_mnh_mosaic.tif`, `twi.tif` quand `describe$code` est `NA`.

## 5. Validation (après correctif app)

Projet RECONFORT → « Lancer l'analyse » :
- plus de « No DEM available » ; R1/R2/R3/W3 non-NA ;
- carte R3 (risque sécheresse) colorée (vérifié cœur : R3 ~60-67, 0 NA).

## 6. Règles

1. Le cœur répare à la consommation (filet) ; l'app répare à la **source**
   (cache), là où le contrôle de couverture s'exécute.
2. Ne jamais supposer un CRS ailleurs que pour le LiDAR HD (2154 avéré). Pour un
   raster générique, garder la réparation « autorité récupérée depuis le nom ».
