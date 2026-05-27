# Spec 015 — Cache S2 buffer écriture (Solution C.3)

**Statut** : draft, à valider.
**Démarré** : 2026-05-27.
**Cible cœur** : minor à fixer au moment du code (v0.48.0 déjà publiée pour le lasR fallback ; vraisemblablement **v0.49.0** ou ultérieure quand spec 015 sera activée).
**Précédents** : spec 010 (cache COG initial v0.22.0), spec 012 (AOI alignment FAST/FORDEAD v0.45.0), v0.47.3-5 (tolérance + alignment).

## 1. Problème

L'ingestion S2 (`ingest_sentinel2_timeseries()` et
`ingest_s2_raw_bands_to_cache()`) écrit dans le cache COG un fichier
**cropé à l'AOI exacte** :

```r
# materialize closure dans `.get_s2_band_raster()` :
buf_native <- sf::st_transform(buf_plots, terra::crs(r0))
needed_ext <- terra::ext(terra::vect(buf_native))
r_cropped  <- terra::crop(r0, needed_ext, snap = "out")
```

Conséquence : **toute modification de l'AOI entre deux runs** (zone
re-registration, ajout/retrait d'une parcelle, dérive non-déterministe
de `sf::st_union()`) invalide le cache. Mitigations actuelles
(v0.47.3-5) :

- v0.47.3 : tolérance 1 pixel sur `.ext_contains()` au cache-hit.
- v0.47.4 : tolérance bumpée à 4 pixels (40 m / 80 m).
- v0.47.5 : `build_index_stack()` aligne sur l'intersection commune.

**Limite résiduelle** observée sur villards (2026-05-25) : la
re-registration de zone après le DB wipe a produit un polygone
légèrement différent ; certaines scènes (T31TFM) restent CACHE-STALE
malgré la tolérance 4 px, déclenchant des refetch lents (~1 min/bande).

## 2. Vision cible

Au moment de **l'écriture** du cache, **étendre l'AOI d'un buffer
fixe** (par défaut **±500 m**) avant le crop. Le fichier sur disque
couvre donc systématiquement `AOI + buffer`. Tout déplacement futur
de l'AOI **dans la bulle** est cache-HIT garanti, indépendamment de
la stabilité de `sf::st_union()`.

```r
# Nouveau materialize :
buf_native     <- sf::st_transform(buf_plots, terra::crs(r0))
aoi_ext        <- terra::ext(terra::vect(buf_native))
# Étendre d'un buffer fixe en unités CRS (typiquement mètres)
buffered_ext   <- terra::ext(
  terra::xmin(aoi_ext) - cache_buffer_m, terra::xmax(aoi_ext) + cache_buffer_m,
  terra::ymin(aoi_ext) - cache_buffer_m, terra::ymax(aoi_ext) + cache_buffer_m)
# Clipper au max extent du COG (sinon erreur hors-tuile)
buffered_ext   <- terra::intersect(buffered_ext, terra::ext(r0))
r_cropped      <- terra::crop(r0, buffered_ext, snap = "out")
```

Au moment de la **lecture** cache-hit : la tolérance v0.47.4 reste
en place (sécurité belt-and-suspenders). Le `terra::crop(r_cached,
needed_ext, snap = "out")` qui suit ré-coupe à l'AOI exacte
demandée par le caller, donc le **resultat retourné** est identique à
la sémantique pré-v0.48.0.

## 3. Décisions à acter

### 3.1 Valeur par défaut du buffer

Trois candidats :

| Valeur | Robustesse | Volume disque (villards) | Cible |
|---|---|---|---|
| ±100 m | absorbe la drift `sf::st_union()` quotidienne | × 2 (~10 MB) | dérive de FP négligeable |
| **±500 m** (recommandé) | absorbe une re-registration de zone avec parcelle limitrophe | **× 10 (~50 MB)** | sweet spot |
| ±1000 m | absorbe une extension de zone réelle (+1 ha collé) | × 25 (~125 MB) | si AOIs changent souvent |

**Proposition : 500 m par défaut**, override via :
- argument R : `cache_buffer_m = 500` (paramètre nouveau de
  `ingest_sentinel2_timeseries()` et `ingest_s2_raw_bands_to_cache()`,
  default 500)
- ENV : `NEMETON_S2_CACHE_BUFFER_M` (override global, surtout pour CI
  ou tests avec buffer = 0)

### 3.2 Coexistence avec les caches existants

Les fichiers cached **antérieurs à v0.48.0** ont été écrits sans
buffer (crop AOI exact). Deux comportements :

**Cas A** — AOI courante ⊆ extent cached existant :
- v0.47.4 tolérance 4 px : cache-HIT, OK.
- v0.48.0 nouveau : idem, lit le cache existant tel quel.

**Cas B** — AOI courante déborde extent cached existant :
- v0.47.4 tolérance 4 px : si débord ≤ 4 px → cache-HIT (avec NA bord) ;
  sinon CACHE-STALE → refetch (avec buffer en v0.48.0).
- v0.48.0 nouveau : refetch écrit avec buffer, devient durablement stable.

**Pas de migration** des caches existants requise. Au premier
refresh post-v0.48.0, chaque scène CACHE-STALE est réécrite avec
buffer ; à terme tout le cache passe en mode buffered. Documenté dans
NEWS.

### 3.3 Buffer = 0 ⇒ comportement pré-v0.48.0

Pour la rétrocompat des tests et des configurations strictes,
`cache_buffer_m = 0` désactive complètement le buffer.

## 4. Livrables cœur

### 4.1 API publique

Deux fonctions exportées gagnent un argument `cache_buffer_m` (par
défaut 500) :

```r
ingest_sentinel2_timeseries(
  con, zone_id, start, end,
  bands             = c("NDVI", "NBR"),
  max_cloud         = 20,
  skip_cached       = TRUE,
  cache_dir,
  cache_buffer_m    = 500L,        # <-- NOUVEAU
  progress_callback = NULL
)

ingest_s2_raw_bands_to_cache(
  con, zone_id, bands, start, end,
  cache_dir,
  cache_buffer_m    = 500L,        # <-- NOUVEAU
  max_cloud         = 20,
  progress_callback = NULL
)
```

Le paramètre est propagé jusqu'à `.get_s2_band_raster()` (helper
interne) qui l'utilise dans la closure `materialize`.

### 4.2 Helper interne

`.expand_extent_with_buffer(ext, buffer_m, max_ext)` :
- agrandit `ext` de `buffer_m` dans chaque direction
- intersecte avec `max_ext` (le COG complet) pour rester dans la tuile
- défensif sur `buffer_m = 0` (no-op)

### 4.3 ENV override

`NEMETON_S2_CACHE_BUFFER_M` : si set, override le default 500. Lu
**au moment de l'appel** (pas à load-time, pour permettre les tests).

### 4.4 Tests

- **Offline** : `.expand_extent_with_buffer()` arithmétique pure
  (expand + intersect avec max).
- **Intégration mockée** : `ingest_sentinel2_timeseries(..., cache_buffer_m = 500)` 
  écrit un fichier dont l'extent contient `AOI + 500 m`.
- **Régression** : `cache_buffer_m = 0` produit le comportement
  pré-v0.48.0 (crop AOI exact).
- **Stabilité cross-AOI** : écrire avec AOI A + buffer, relire avec
  AOI A' légèrement déplacée mais dans le buffer → cache-HIT (test
  end-to-end via `with_clean_db` ou mock).

## 5. Implémentation détaillée

### 5.1 Modification de `.get_s2_band_raster()`

Site critique dans `R/monitoring.R` autour de la ligne 880-900 :

```r
# v0.47.5 actuel
r <- .terra_rast_with_pc_retry(
  href, emit_fn = emit_fn, scene_id = scene_id, band = band,
  materialize = function(r0) {
    buf_native <- sf::st_transform(buf_plots, terra::crs(r0))
    needed_ext <- terra::ext(terra::vect(buf_native))
    r_cropped  <- terra::crop(r0, needed_ext, snap = "out")
    r_cropped + 0
  }
)

# v0.48.0 proposé
r <- .terra_rast_with_pc_retry(
  href, emit_fn = emit_fn, scene_id = scene_id, band = band,
  materialize = function(r0) {
    buf_native    <- sf::st_transform(buf_plots, terra::crs(r0))
    aoi_ext       <- terra::ext(terra::vect(buf_native))
    write_ext     <- .expand_extent_with_buffer(
      aoi_ext,
      buffer_m = cache_buffer_m,    # <-- propagé depuis le caller
      max_ext  = terra::ext(r0)
    )
    r_cropped     <- terra::crop(r0, write_ext, snap = "out")
    r_cropped + 0
  }
)
```

### 5.2 Modification de `.get_s2_band_raster()` signature

`.get_s2_band_raster(scene, band, buf_plots, cache_dir, emit,
cache_buffer_m = 500L)` — défaut interne sécurisé pour les callers
qui ne le passent pas explicitement (back-compat des mocks de tests).

### 5.3 ENV resolution

Au tout début de la fonction publique (avant tout appel à
`.get_s2_band_raster`), résoudre une fois :

```r
.resolve_cache_buffer <- function(arg) {
  env_val <- Sys.getenv("NEMETON_S2_CACHE_BUFFER_M", "")
  if (nzchar(env_val)) {
    v <- suppressWarnings(as.numeric(env_val))
    if (is.finite(v) && v >= 0) return(as.integer(round(v)))
  }
  as.integer(round(arg))
}
```

L'ENV gagne sur l'argument.

## 6. Hors scope V1

- **Buffer adaptatif** (e.g. 5 % de la dimension AOI) — la valeur fixe
  500 m est simple, prévisible. Si besoin d'adaptatif → spec 016.
- **Migration des caches existants** (réécriture forcée avec buffer
  d'un coup) — pas nécessaire, le refresh naturel y arrive.
- **Buffer par-bande** (e.g. 500 m pour B04/B08, 1000 m pour B12 à
  20 m) — un seul buffer pour toutes les bandes V1.
- **Helper public `purge_stale_cache(cache_dir)`** — utile pour repartir
  d'un cache propre, à considérer en V2 si la rétention disque pose
  problème.

## 7. Risques et mitigations

| Risque | Mitigation |
|---|---|
| Volume disque ×10-25 pour les projets existants | Documenté ; ENV `NEMETON_S2_CACHE_BUFFER_M=0` pour back-compat exacte ; helper purge en V2 |
| Première ingestion légèrement plus longue (data fetch ~10× plus de pixels) | Coût per-band dominé par overhead VSI (DNS + SAS-sign + GDAL headers), pas par la taille — impact ≪ ×10 en pratique |
| Edge AOI sur tuile MGRS (e.g. AOI à 100 m du bord) | `terra::intersect(buffered_ext, terra::ext(r0))` clippe — buffer effectif réduit dans cette direction, OK |
| Caches existants pré-v0.48.0 (sans buffer) ne sont pas migrés automatiquement | Le refresh naturel au prochain CACHE-STALE les remplace ; v0.47.4 tolérance les couvre dans l'intervalle |
| Tests offline avec mocks à back-compat | `cache_buffer_m = 0` rétablit comportement strict pré-v0.48.0 |

## 8. Tests d'acceptation

| AC | Description | Comment vérifier |
|---|---|---|
| AC.1 | `ingest_sentinel2_timeseries(..., cache_buffer_m = 500)` écrit un fichier dont l'extent contient `AOI + 500 m` (clippé au COG) | Lire le TIF écrit + comparer extent à `aoi + 500` |
| AC.2 | `cache_buffer_m = 0` produit le comportement pré-v0.48.0 (crop AOI strict) | Idem AC.1 avec valeur attendue = AOI exact |
| AC.3 | ENV `NEMETON_S2_CACHE_BUFFER_M=100` override l'argument R `cache_buffer_m = 500` | Inspecter l'extent écrit |
| AC.4 | Cache écrit avec buffer 500 m → un 2e run avec AOI déplacée de 300 m → cache-HIT (pas de refetch) | Counter de refetch dans les events `s2:*` |
| AC.5 | Cache écrit avec buffer 500 m → un 2e run avec AOI déplacée de 700 m → CACHE-STALE → refetch avec buffer | Vérifier le `s2:band_fetched` + nouvel extent buffered |
| AC.6 | Aucune régression sur les valeurs métier (`exact_extract` per-plot) — la sortie de `.extract_scene_obs()` est identique avec ou sans buffer | Test fixture : per-plot mean NDVI identique buffer=0 vs buffer=500 |
| AC.7 | `cache_buffer_m` argument propagé jusqu'à `.get_s2_band_raster()` sans changement de signature publique de `.get_s2_band_raster` (back-compat mocks) | Vérifier la signature `.get_s2_band_raster(scene, band, buf_plots, cache_dir, emit, cache_buffer_m = 500L)` |

## 9. Suite

Si la spec est validée :

- Release **minor** (changement de comportement par défaut, argument
  nouveau exporté). Numéro à fixer au moment du code — v0.48.0 déjà
  utilisée pour le lasR fallback.
- DESCRIPTION + NEWS + CHANGELOG + PLAN + README badge bumpés.
- Aucun changement côté `nemetonshiny` requis — le default 500 m
  prend automatiquement. Possibilité de surfacer le paramètre côté
  app en V2 (sidebar avancé).
- Estimation effort : ~1-2 sessions (~50 lignes de code + 7 tests +
  doc).
