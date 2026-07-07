# Brief `nemetonshiny` — Moteur microclimf : passer la structure de végétation (`las`/`pai`)

**Priorité : HAUTE** (le moteur d'exposition microclimatique ne produit JAMAIS de
sortie réelle en l'état). **Aucun changement cœur requis** : `nemeton (>= 0.140.0)`
suffit. C'est un fix **strictement app**.

## Symptôme

« Lancer le moteur réel » (reGénération) : `microclimf/` reste **vide**,
`sensibilite.gpkg` **absent**, bandeau « Sensibilité microclimatique non
calculée ». BILJOU (R3), lui, aboutit normalement.

## Cause racine (diagnostiquée + reproduite)

`service_regeneration.R`, bloc microclimf (~l.459), appelle :

```r
nemeton::regen_sensibilite(res, mnt = grid$mnt_dir, mnh = grid$mnh_dir,
  annees_moy = cfg$year_moyenne, annees_canic = cfg$year_canicule,
  cache_dir = micro_cache)          # <- ni `las`, ni `pai`
```

Or `regen_sensibilite()` **exige la structure de végétation** (PAI). Sans `las`
ni `pai`, il abandonne immédiatement (avant tout ERA5/microclimf) :

```
regen_sensibilite() engine path needs `mnt`, `mnh`, `annees_moy`, `annees_canic`,
and either `las` (LiDAR HD) or `pai` (S2/PROSAIL LAI fallback, spec 033).
```

L'abort est capturé en warning « microclimf: … » (l.463) → `sens = NULL` → rien
n'est écrit. Le dossier `micro_cache` est créé **avant** l'appel (l.457) → il
reste vide, ce qui masque la vraie raison.

**Reproduit hors app** (repro `regen_sensibilite`) : mêmes `mnt`+`mnh` sans
`las`/`pai` → abort identique. **Fix vérifié end-to-end** : en ajoutant
`las = <dossier .laz>` (dalle nuage du projet), le garde passe,
`pai_depuis_nuage()` (via `lasR`) dérive le PAI, puis microclimf tourne
(téléchargement ERA5 en cours, PAI OK). C'est donc **le seul** blocage.

> Le projet a pourtant le nuage LiDAR (`cache/layers/lidar_nuage/`, dalles
> `.copc.laz`). Mais `resolve_regen_lidar_grid()` (l.358) ne résout que
> `mnt_dir` + `mnh_dir` — il **ignore le nuage**, jamais transmis au cœur.

## Rappel API cœur (inchangée)

```r
regen_sensibilite(units, mnt, mnh,
  las   = <chemin d'un DOSSIER de dalles .las/.laz/.copc.laz>,  # OU
  pai   = <SpatRaster LAI/PAI (S2/PROSAIL, spec 033)>,          # repli NDP 0
  annees_moy, annees_canic, cache_dir, ...)
```

- `las` : **dossier** (pas un fichier). `pai_depuis_nuage()` liste les `.las/.laz`
  dedans et rasterise le PAI via `lasR` (dépendance `lasR`, déjà présente).
  Chemin **privilégié** (structure LiDAR HD réelle, spec 033).
- `pai` : `SpatRaster` LAI Sentinel-2/PROSAIL (proxy dégradé). Le bloc BILJOU le
  produit **déjà** via `.regen_lai_fallback(res, out_dir, cfg)` (caché en
  `out_dir/lai_prosail.tif`) — **à réutiliser tel quel**.

## Fix demandé

### 1. `resolve_regen_lidar_grid()` — résoudre aussi le nuage (`l.358`)

```r
resolve_regen_lidar_grid <- function(project_path) {
  if (is.null(project_path)) return(NULL)
  base <- file.path(project_path, "cache", "layers")
  mnt_dir <- file.path(base, "lidar_mnt")
  mnh_dir <- file.path(base, "lidar_mnh")
  las_dir <- file.path(base, "lidar_nuage")
  has_tif <- function(d) dir.exists(d) &&
    length(list.files(d, pattern = "\\.tif$", ignore.case = TRUE)) > 0L
  has_las <- function(d) dir.exists(d) &&
    length(list.files(d, pattern = "\\.(las|laz)$", ignore.case = TRUE)) > 0L
  if (has_tif(mnt_dir) && has_tif(mnh_dir)) {
    return(list(mnt_dir = mnt_dir, mnh_dir = mnh_dir,
                las_dir = if (has_las(las_dir)) las_dir else NULL))  # NULL si absent
  }
  NULL
}
```

### 2. Bloc microclimf (`~l.455-473`) — passer `las`, sinon `pai`

```r
if (!is.null(grid) && regen_cds_credentials_ready()) {
  # Structure de végétation : LiDAR HD (nuage) prioritaire, sinon repli LAI S2.
  veg_args <- list()
  if (!is.null(grid$las_dir)) {
    veg_args$las <- grid$las_dir            # PAI dérivé du nuage (spec 033, LiDAR)
    canopy <- "lidar"
  } else {
    lai_r <- .regen_lai_fallback(res, out_dir, cfg)   # SpatRaster LAI S2/PROSAIL, caché
    if (!is.null(lai_r)) { veg_args$pai <- lai_r; canopy <- "satellite" }
  }

  if (length(veg_args)) {                   # au moins une source de structure
    micro_cache <- file.path(out_dir, "microclimf")
    if (!dir.exists(micro_cache)) dir.create(micro_cache, recursive = TRUE)
    sens <- tryCatch(
      do.call(nemeton::regen_sensibilite, c(list(res,
        mnt = grid$mnt_dir, mnh = grid$mnh_dir,
        annees_moy = cfg$year_moyenne, annees_canic = cfg$year_canicule,
        cache_dir = micro_cache), veg_args)),
      error = function(e) {
        warnings <<- c(warnings, .strip_ansi(sprintf("microclimf: %s", conditionMessage(e))))
        NULL
      })
    if (inherits(sens, "sf")) {
      res <- sens
      tryCatch(sf::st_write(res, file.path(out_dir, "sensibilite.gpkg"),
                            quiet = TRUE, delete_dsn = TRUE),
               error = function(e) cli::cli_warn("regen engine: sensibilite cache not written"))
      cached <- c(cached, "sensibilite")
    }
  } else {
    warnings <- c(warnings, i18n$t("regen_engine_no_vegetation_structure"))  # nouvelle clé i18n
  }
}
```

Nouvelle clé i18n FR/EN, ex. :
`regen_engine_no_vegetation_structure` = « Sensibilité microclimatique : aucune
structure de végétation disponible (ni nuage LiDAR, ni LAI Sentinel-2). » /
« Microclimatic sensitivity: no vegetation structure available (neither LiDAR
point cloud nor Sentinel-2 LAI). »

## Notes / réserves

1. **Perf sur gros projets.** `las = <dossier nuage>` fait lire par `lasR`
   **toutes** les dalles du dossier (ex. 25 × ~138 Mo). `regen_sensibilite()`
   n'utilise pas (encore) le clip `parcelle`/`fenetre` de `pai_depuis_nuage()` →
   la dérivation PAI porte sur toute l'emprise du nuage. Correct mais lourd sur
   un grand massif. Si c'est un problème UX, deux pistes : (a) prévoir un
   sous-dossier de dalles restreint aux UGF, (b) demander au cœur d'exposer
   `parcelle`/`fenetre` via `regen_sensibilite()` (petit brief cœur ultérieur).
   Le repli `pai` (S2, déjà caché) est nettement plus léger.
2. **Hygiène dossier vide.** Créer `micro_cache` seulement quand on va
   réellement appeler le moteur (déjà le cas ci-dessus, dans la branche
   `length(veg_args)`), et éventuellement `unlink()` le dossier s'il reste vide
   après un échec — évite de laisser croire qu'un run a eu lieu.
3. **Badge provenance canopée.** `canopy <- "lidar"` / `"satellite"` déjà posé —
   vérifier l'alignement avec `regen_canopy_provenance()` /
   `nemeton::canopy_provenance()` (clés `"lidar_hd"` / `"prosail_s2"`).
4. **Prérequis inchangés** : `regen_cds_credentials_ready()` (ERA5-Land, licence
   CDS acceptée — confirmée OK) + `microclimf`/`mcera5`/`lasR` installés.

## Validation

Projet LiDAR (avec `lidar_nuage/`) → « Lancer le moteur réel » →
`cache/regeneration/sensibilite.gpkg` écrit, `microclimf/` peuplé (`era5_*.nc`,
`cache_<année>_tmax.tif`/`_vpd.tif`), bandeau « non calculée » disparu, carte
sensibilité colorée. Projet sans nuage mais S2 disponible → même résultat via
le repli `pai` (badge provenance « satellite »).
