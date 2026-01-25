# Contract: Tutorial Helpers API

**Feature**: 001-learnr-tutorial
**Module**: Helper Functions (R/tutorial-helpers.R, R/tutorial-validation.R, R/tutorial-demo-data.R)
**Date**: 2026-01-06

## Purpose

Définit les contrats API pour les fonctions helpers utilisées par le tutorial learnr. Ces fonctions sont exportées et réutilisables hors du tutorial pour workflows personnalisés utilisateurs.

## Acquisition Functions

### tutorial_download_cadastre()

**Purpose**: Télécharger parcelles cadastrales via API IGN avec fallback automatique.

**Signature**:
```r
tutorial_download_cadastre(
  commune,
  output_dir = tempdir(),
  timeout = 30,
  verbose = TRUE
)
```

**Parameters**:
- `commune` (character, required): Nom de commune OU code INSEE (ex: "CIRON" ou "36053")
- `output_dir` (character, optional): Répertoire sortie. Défaut: `tempdir()`
- `timeout` (numeric, optional): Timeout API en secondes. Défaut: 30
- `verbose` (logical, optional): Afficher messages progress. Défaut: TRUE

**Returns**:
- Success: `sf` object avec parcelles cadastrales (EPSG:2154)
- Failure: `sf` object avec données demo CIRON (fallback automatique)

**Output Structure**:
```r
sf::st_sf(
  geo_parcelle = character(),    # Code parcelle cadastrale
  idu = character(),              # Identifiant unique
  commune = character(),          # Nom commune
  code_insee = character(),       # Code INSEE
  surface_geo = numeric(),        # Surface m²
  geometry = st_sfc()            # Polygones EPSG:2154
)
```

**Behavior**:
1. Validate `commune` (doit être non-vide, longueur 3-50 char)
2. Attempt API call via `happign::get_wfs()` with timeout
3. If success: Transform to EPSG:2154 if needed, return sf
4. If fail (timeout/error/empty): Load demo data, return with warning

**Messages**:
- ℹ️ `cli::cli_alert_info()`: "Téléchargement cadastre depuis API IGN..."
- ✓ `cli::cli_alert_success()`: "Cadastre téléchargé: {nrow(result)} parcelles"
- ⚠️ `cli::cli_alert_warning()`: "API IGN indisponible, utilisation données demo CIRON"

**Errors**:
- `cli::cli_abort()` si `commune` vide ou invalide
- `cli::cli_abort()` si `output_dir` non-writable
- `cli::cli_warn()` si API fail (mais continue avec fallback, pas d'abort)

**Examples**:
```r
# Succès API
parcelles <- tutorial_download_cadastre("CIRON")

# Force fallback (commune invalide → warning → demo data)
demo_parcelles <- tutorial_download_cadastre("INVALID_COMMUNE")

# Custom output dir
parcelles <- tutorial_download_cadastre("36053", output_dir = "~/data")
```

**Dependencies**: happign, sf, cli

---

### tutorial_download_mnt()

**Purpose**: Télécharger MNT RGE Alti via API IGN avec fallback automatique.

**Signature**:
```r
tutorial_download_mnt(
  bbox,
  resolution = 5,
  output_dir = tempdir(),
  timeout = 60,
  verbose = TRUE
)
```

**Parameters**:
- `bbox` (bbox or sf, required): Emprise spatiale. Peut être objet `bbox` ou `sf` (bbox sera extrait)
- `resolution` (numeric, optional): Résolution en mètres. Options: 1, 5, 25. Défaut: 5
- `output_dir` (character, optional): Répertoire sortie. Défaut: `tempdir()`
- `timeout` (numeric, optional): Timeout API en secondes. Défaut: 60
- `verbose` (logical, optional): Afficher messages progress. Défaut: TRUE

**Returns**:
- Success: `SpatRaster` object (EPSG:2154)
- Failure: `SpatRaster` demo CIRON (fallback automatique)

**Output Structure**:
```r
terra::rast(
  resolution = c(5, 5),          # Résolution X, Y (m)
  crs = "EPSG:2154",             # Lambert-93
  extent = ext(...),             # Emprise
  names = "elevation",           # Nom couche
  units = "meters",              # Unité
  nodata = -9999                 # Valeur no-data
)
```

**Behavior**:
1. Validate `bbox` (must be valid bbox with extent)
2. Validate `resolution` (must be 1, 5, or 25)
3. Attempt API call via `happign::get_wcs()` with timeout
4. If success: Transform to EPSG:2154 if needed, return SpatRaster
5. If fail: Load demo MNT CIRON, crop to bbox, return with warning

**Messages**:
- ℹ️ `cli::cli_alert_info()`: "Téléchargement MNT résolution {resolution}m..."
- ✓ `cli::cli_alert_success()`: "MNT téléchargé: {ncell(result)} cellules"
- ⚠️ `cli::cli_alert_warning()`: "API IGN indisponible, utilisation MNT demo CIRON"

**Errors**:
- `cli::cli_abort()` si `bbox` invalide (non-bbox, emprise nulle)
- `cli::cli_abort()` si `resolution` pas dans {1, 5, 25}
- `cli::cli_warn()` si API fail (continue avec fallback)

**Examples**:
```r
# From parcels bbox
mnt <- tutorial_download_mnt(st_bbox(parcelles), resolution = 5)

# From sf object directly
mnt <- tutorial_download_mnt(parcelles, resolution = 1)

# Custom output dir
mnt <- tutorial_download_mnt(bbox, output_dir = "~/data")
```

**Dependencies**: happign, terra, sf, cli

---

### tutorial_download_lidar()

**Purpose**: Télécharger dalles LiDAR HD IGN pour parcelles avec fallback automatique.

**Signature**:
```r
tutorial_download_lidar(
  parcels,
  output_dir = tempdir(),
  timeout = 120,
  verbose = TRUE
)
```

**Parameters**:
- `parcels` (sf, required): Parcelles forestières (objet sf)
- `output_dir` (character, optional): Répertoire sortie. Défaut: `tempdir()`
- `timeout` (numeric, optional): Timeout API en secondes. Défaut: 120
- `verbose` (logical, optional): Afficher messages progress. Défaut: TRUE

**Returns**:
- Success: `LAScatalog` object (EPSG:2154) avec dalles couvrant parcelles
- Failure: `LAScatalog` demo CIRON (fallback automatique)

**Output Structure**:
```r
lidR::LAScatalog(
  files = character(),           # Chemins fichiers .laz
  crs = "EPSG:2154",             # Lambert-93
  extent = ext(...),             # Emprise totale
  point_density = numeric(),     # Points/m² moyen
  classification = list(...)     # Classes LAS disponibles
)
```

**Behavior**:
1. Validate `parcels` (must be sf with valid geometries)
2. Compute bbox from parcels
3. Attempt API call via `lidarHD::get_lidar()` with timeout
4. If success: Return LAScatalog
5. If fail: Load demo LiDAR CIRON, return with warning

**Messages**:
- ℹ️ `cli::cli_alert_info()`: "Téléchargement LiDAR HD pour {nrow(parcels)} parcelles..."
- ⏳ `cli::cli_progress_bar()`: Progress bar téléchargement dalles
- ✓ `cli::cli_alert_success()`: "LiDAR téléchargé: {n_tiles} dalles, {total_points}M points"
- ⚠️ `cli::cli_alert_warning()`: "API IGN indisponible, utilisation LiDAR demo CIRON"

**Errors**:
- `cli::cli_abort()` si `parcels` invalide (non-sf, géométries invalides)
- `cli::cli_abort()` si emprise parcelles hors couverture LiDAR HD
- `cli::cli_warn()` si API fail (continue avec fallback)

**Examples**:
```r
# Download LiDAR for parcels
las_catalog <- tutorial_download_lidar(parcelles)

# Custom output dir
las <- tutorial_download_lidar(parcelles, output_dir = "~/lidar")
```

**Dependencies**: lidarHD, lidR, sf, cli

---

## Demo Data Loading Functions

### load_demo_cadastre()

**Purpose**: Charger données cadastrales demo CIRON pré-téléchargées.

**Signature**:
```r
load_demo_cadastre(verbose = TRUE)
```

**Parameters**:
- `verbose` (logical, optional): Afficher messages. Défaut: TRUE

**Returns**:
- `sf` object avec 27 parcelles CIRON (EPSG:2154)

**Behavior**:
1. Locate file via `system.file("extdata/tutorial_data/ciron_parcelles.gpkg", package = "nemeton")`
2. Check file exists, abort if missing
3. Load with `sf::st_read()`, quiet = !verbose
4. Return sf object

**Messages**:
- ℹ️ `cli::cli_alert_info()`: "Chargement données demo CIRON: 27 parcelles"

**Errors**:
- `cli::cli_abort()` si fichier demo absent (package installation incomplete)

**Examples**:
```r
demo_parcelles <- load_demo_cadastre()
```

---

### load_demo_mnt()

**Purpose**: Charger MNT demo CIRON pré-téléchargé.

**Signature**:
```r
load_demo_mnt(verbose = TRUE)
```

**Parameters**:
- `verbose` (logical, optional): Afficher messages. Défaut: TRUE

**Returns**:
- `SpatRaster` MNT CIRON 5m resolution (EPSG:2154)

**Behavior**:
1. Locate file via `system.file("extdata/tutorial_data/ciron_mnt.tif", package = "nemeton")`
2. Check file exists, abort if missing
3. Load with `terra::rast()`
4. Return SpatRaster

**Messages**:
- ℹ️ `cli::cli_alert_info()`: "Chargement MNT demo CIRON: résolution 5m"

**Errors**:
- `cli::cli_abort()` si fichier demo absent

**Examples**:
```r
demo_mnt <- load_demo_mnt()
```

---

### load_demo_lidar()

**Purpose**: Charger dalles LiDAR demo CIRON pré-téléchargées.

**Signature**:
```r
load_demo_lidar(tile_ids = NULL, verbose = TRUE)
```

**Parameters**:
- `tile_ids` (character, optional): IDs dalles à charger (ex: c("0845_6560", "0850_6560")). Si NULL, charge toutes dalles. Défaut: NULL
- `verbose` (logical, optional): Afficher messages. Défaut: TRUE

**Returns**:
- `LAScatalog` ou `LAS` selon nombre dalles
  - Si `tile_ids` = NULL ou plusieurs dalles: `LAScatalog`
  - Si une seule dalle: `LAS` object chargé en mémoire

**Behavior**:
1. Locate directory via `system.file("extdata/tutorial_data/ciron_lidar/", package = "nemeton")`
2. List .laz files, filter by `tile_ids` if provided
3. If multiple tiles: Create LAScatalog
4. If single tile: Load as LAS with `lidR::readLAS()`
5. Return catalog or LAS

**Messages**:
- ℹ️ `cli::cli_alert_info()`: "Chargement LiDAR demo CIRON: {n_tiles} dalles"

**Errors**:
- `cli::cli_abort()` si directory demo absent
- `cli::cli_abort()` si `tile_ids` spécifiés mais fichiers absents

**Examples**:
```r
# Load all tiles as catalog
catalog <- load_demo_lidar()

# Load specific tiles
las <- load_demo_lidar(tile_ids = "0845_6560")  # Single LAS

# Load multiple tiles
catalog <- load_demo_lidar(tile_ids = c("0845_6560", "0850_6560"))
```

---

## Validation Functions

### validate_parcels()

**Purpose**: Valider que parcelles sont prêtes pour analyse.

**Signature**:
```r
validate_parcels(parcels, verbose = TRUE)
```

**Parameters**:
- `parcels` (sf, required): Parcelles forestières
- `verbose` (logical, optional): Afficher messages détaillés. Défaut: TRUE

**Returns**:
- List with validation results:
```r
list(
  is_valid = logical(1),         # TRUE si tous checks passent
  n_parcels = integer(1),         # Nombre parcelles
  checks = list(
    has_geometry = logical(1),    # A des géométries
    correct_crs = logical(1),     # CRS = EPSG:2154
    valid_geometries = logical(1),# Toutes géométries valides
    has_area = logical(1),        # Colonne area_ha existe
    area_positive = logical(1)    # Toutes areas > 0
  ),
  messages = character(),         # Messages validation
  warnings = character()          # Warnings (non-bloquants)
)
```

**Behavior**:
1. Check is sf object
2. Check has geometry column
3. Check CRS = EPSG:2154 (warn if not, not blocking)
4. Check all geometries valid (`st_is_valid()`)
5. Check has area_ha column (calculate if missing)
6. Check all areas > 0
7. Compile results and messages

**Messages** (if `verbose = TRUE`):
- ✓ `cli::cli_alert_success()`: "Validation réussie: {n_parcels} parcelles valides"
- ✗ `cli::cli_alert_danger()`: "Validation échouée: {n_issues} problèmes détectés"
- ⚠️ `cli::cli_alert_warning()`: Warnings individuels

**Errors**:
- Does NOT abort. Returns `is_valid = FALSE` avec messages détaillés.

**Examples**:
```r
validation <- validate_parcels(parcelles)
if (!validation$is_valid) {
  cat(validation$messages, sep = "\n")
}
```

---

### validate_lidar_metrics()

**Purpose**: Valider que métriques LiDAR sont cohérentes.

**Signature**:
```r
validate_lidar_metrics(metrics, parcels = NULL, verbose = TRUE)
```

**Parameters**:
- `metrics` (data.frame, required): Métriques LiDAR par parcelle
- `parcels` (sf, optional): Parcelles de référence (pour vérifier correspondance parcel_id). Défaut: NULL
- `verbose` (logical, optional): Afficher messages. Défaut: TRUE

**Returns**:
- List with validation results:
```r
list(
  is_valid = logical(1),
  n_parcels = integer(1),
  checks = list(
    has_parcel_id = logical(1),       # Colonne parcel_id existe
    parcel_ids_match = logical(1),    # IDs matchent parcels (si fourni)
    heights_valid = logical(1),       # z_p95 entre 0-50m
    density_valid = logical(1),       # point_density > 5/m²
    cover_valid = logical(1),         # canopy_cover_pct 0-100%
    no_missing = logical(1)           # Pas de NA dans colonnes critiques
  ),
  messages = character(),
  warnings = character()
)
```

**Behavior**:
1. Check is data.frame
2. Check has parcel_id column
3. If `parcels` provided: Check all IDs match
4. Check z_p95 in 0-50m range
5. Check point_density > 5/m²
6. Check canopy_cover_pct in 0-100%
7. Check no NA in critical columns (z_p95, point_density, canopy_cover_pct)

**Messages** (if `verbose = TRUE`):
- ✓ Success message if valid
- ✗ Error messages with details if invalid
- ⚠️ Warnings if values suspicious (ex: z_p95 > 40m but <50m)

**Errors**:
- Does NOT abort. Returns `is_valid = FALSE` avec messages.

**Examples**:
```r
validation <- validate_lidar_metrics(metrics, parcelles)
if (!validation$is_valid) {
  stop("Métriques LiDAR invalides: ", validation$messages)
}
```

---

## Tutorial State Management Functions (Optionnel v0.4.1)

### init_tutorial_session()

**Purpose**: Initialiser session tutorial pour tracking progression.

**Signature**:
```r
init_tutorial_session(user_name = "anonymous")
```

**Parameters**:
- `user_name` (character, optional): Nom utilisateur. Défaut: "anonymous"

**Returns**:
- `nemeton_tutorial_session` object (S3 class) avec structure data-model.md

**Behavior**:
1. Generate UUID for session_id
2. Initialize empty modules_progress and exercises_results data.frames
3. Set start_time = Sys.time()
4. Return S3 object

**Examples**:
```r
session <- init_tutorial_session("John Doe")
```

---

### save_exercise_result()

**Purpose**: Enregistrer résultat exercice dans session.

**Signature**:
```r
save_exercise_result(session, exercise_id, result)
```

**Parameters**:
- `session` (nemeton_tutorial_session, required): Session active
- `exercise_id` (character, required): ID exercice (format: "ex-{module}-{numero}")
- `result` (list, required): Résultat validation gradethis

**Returns**:
- Updated `nemeton_tutorial_session` object

**Behavior**:
1. Validate session is nemeton_tutorial_session
2. Parse module_id from exercise_id
3. Increment attempt_number for this exercise_id
4. Extract validation_status, feedback from result
5. Append row to session$exercises_results
6. Return updated session

**Examples**:
```r
session <- save_exercise_result(session, "ex-1-1",
                                 list(pass = TRUE, feedback = "Correct!"))
```

---

### get_module_progress()

**Purpose**: Récupérer état progression pour un module.

**Signature**:
```r
get_module_progress(session, module_id)
```

**Parameters**:
- `session` (nemeton_tutorial_session, required): Session active
- `module_id` (character, required): ID module (ex: "module-1")

**Returns**:
- One-row data.frame avec ModuleProgress structure (see data-model.md)

**Behavior**:
1. Validate session and module_id
2. Filter session$modules_progress by module_id
3. If not found: Initialize new row with status = "not_started"
4. Return progress data.frame

**Examples**:
```r
progress <- get_module_progress(session, "module-1")
cat("Status:", progress$status, "\n")
cat("Exercises completed:", progress$exercises_completed, "/",
    progress$exercises_total, "\n")
```

---

## Error Handling Strategy

**Acquisition Functions** (download_*):
- **Network errors**: Retry 2x avec exponential backoff (2s, 4s)
- **Timeout**: Configurable via parameter, défaut: 30-120s
- **API errors**: Catch, warn, fallback demo data automatiquement
- **Never abort**: Toujours retourner données (API ou demo)

**Validation Functions** (validate_*):
- **Never abort**: Return `is_valid = FALSE` avec messages détaillés
- **User responsibility**: Utilisateur décide si continuer ou corriger

**Demo Data Loading** (load_demo_*):
- **File missing**: Abort avec message clair (installation package incomplete)
- **Corruption**: Abort avec suggestion réinstaller package

**State Management** (tutorial session):
- **Optionnel v0.4.1**: Pas de gestion erreurs complexe
- **Graceful degradation**: Tutorial fonctionne sans state tracking

## Testing Strategy

**Unit Tests** (testthat):
- Test each function independently avec mocks pour APIs
- Test fallback logic (simulate API fail)
- Test validation logic avec fixtures (valid/invalid data)
- Test error handling (invalid inputs, missing files)

**Integration Tests**:
- Test workflow complet: download → validate → process
- Test fallback end-to-end (disable APIs, verify demo data used)
- Test cross-platform (Windows, macOS, Linux)

**Coverage Target**: >= 80% pour helpers (fonctions critiques)
