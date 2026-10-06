#' Indicator Family Functions - v0.2.0 Extension
#'
#' Functions for calculating indicators across the 12-family framework:
#' B (Biodiversité/Vivant), W (Water/Infiltrée), A (Air/Vaporeuse),
#' F (Fertilité/Riche), C (Carbone/Énergétique), L (Landscape/Esthétique),
#' T (Trame/Nervurée), R (Résilience/Flexible), S (Santé/Ouverte),
#' P (Patrimoine/Radicale), E (Éducation/Éducative), N (Nuit/Ténébreuse)
#'
#' @name indicators-families
#' @keywords internal
NULL

# Package-level TWI cache (avoids recomputing for W2, W3, F2, R3)
.twi_cache <- new.env(parent = emptyenv())

# Package-level nasapower wind cache (avoids re-downloading for L1, R2)
.wind_cache <- new.env(parent = emptyenv())

# Nom du fichier cache du vent NASA POWER pour un point (lon/lat déjà arrondis
# ou non : arrondi à 0.01° ici).
.nasapower_wind_cache_file <- function(lon, lat) {
  enc <- function(x) {
    v <- sprintf("%.2f", round(as.numeric(x), 2) + 0)   # + 0 : pas de "-0.00"
    sub(".", "p", sub("^-", "m", v), fixed = TRUE)
  }
  sprintf("nasapower_wind_%s_%s.rds", enc(lon), enc(lat))
}

#' Get wind climatology from NASA POWER with caching
#'
#' Downloads monthly wind direction (WD10M) and speed (WS10M) climatology from
#' NASA POWER, with both in-memory and file-based caching. Returns the
#' speed-weighted mean wind direction in degrees.
#'
#' @param units An sf object (used to compute centroid location)
#' @param default_dir Numeric. Default wind direction (degrees) if unavailable.
#' @return Numeric. Dominant wind direction in degrees.
#' @keywords internal
#' @noRd
get_nasapower_wind <- function(units, default_dir = 270, cache_dir = NULL) {

  # Compute centroid in WGS84
  centroid <- suppressWarnings(sf::st_centroid(sf::st_union(units)))
  coords <- sf::st_coordinates(sf::st_transform(centroid, 4326))
  lon <- round(coords[1, 1], 2)
  lat <- round(coords[1, 2], 2)

  # In-memory cache key (rounded to ~1km grid)

  cache_key <- paste0("wind_", lon, "_", lat)

  if (exists(cache_key, envir = .wind_cache)) {
    wind_dir <- get(cache_key, envir = .wind_cache)
    cli::cli_alert_info("Wind: Using cached direction {wind_dir}\u00b0")
    return(wind_dir)
  }

  # File-based cache — per-project or global fallback
  if (is.null(cache_dir)) {
    cache_dir <- file.path(get_global_cache_dir(), "nasapower")
  }
  # Audit 1.0 : le fichier s'appelait `nasapower_wind.rds` quelle que soit la
  # position -> avec le cache global, le vent du premier projet était relu pour
  # tous les autres. Le nom porte désormais lon/lat arrondis (0.01°, comme la
  # clé mémoire), encodés sans `.` ni `-` (`4.5` -> `4p50`, `-1.2` -> `m1p20`).
  cache_file <- file.path(cache_dir, .nasapower_wind_cache_file(lon, lat))

  if (file.exists(cache_file)) {
    tryCatch({
      cached <- readRDS(cache_file)
      assign(cache_key, cached, envir = .wind_cache)
      cli::cli_alert_info("Wind: Loaded from file cache ({cached}\u00b0)")
      return(cached)
    }, error = function(e) NULL)
  }

  # Download from NASA POWER
  if (!requireNamespace("nasapower", quietly = TRUE)) {
    cli::cli_alert_info("Wind: nasapower not installed, using default {default_dir}\u00b0")
    return(default_dir)
  }

  wind_dir <- tryCatch({
    wind_data <- nasapower::get_power(
      community = "ag",
      lonlat = c(lon, lat),
      pars = c("WD10M", "WS10M"),
      temporal_api = "climatology"
    )
    wd_values <- as.numeric(wind_data[wind_data$PARAMETER == "WD10M", 4:15])
    ws_values <- as.numeric(wind_data[wind_data$PARAMETER == "WS10M", 4:15])

    if (length(wd_values) == 12 && length(ws_values) == 12 &&
        !all(is.na(wd_values)) && !all(is.na(ws_values))) {
      result <- round(stats::weighted.mean(wd_values, ws_values, na.rm = TRUE))

      # Save to file cache
      if (!dir.exists(cache_dir)) dir.create(cache_dir, recursive = TRUE)
      tryCatch(saveRDS(result, cache_file), error = function(e) NULL)

      # Save to memory cache
      assign(cache_key, result, envir = .wind_cache)
      cli::cli_alert_info("Wind: Downloaded from NASA POWER ({result}\u00b0), cached")
      result
    } else {
      default_dir
    }
  }, error = function(e) {
    cli::cli_alert_info("Wind: NASA POWER unavailable, using default {default_dir}\u00b0")
    default_dir
  })

  wind_dir
}

#' Get or compute TWI raster with caching
#'
#' Returns a cached TWI raster if one exists for the given DEM fingerprint,
#' otherwise computes it (GRASS preferred, terra D8 fallback) and caches.
#' @param dem A SpatRaster DEM
#' @param cache_dir Character. Directory for file cache (per-project).
#'   If NULL, falls back to global nemeton cache.
#' @return A SpatRaster with TWI values
#' @keywords internal
#' @noRd
# Répare un CRS Lambert-93 (ou tout CRS) « sans autorité » : certains GeoTIFF
# LiDAR HD IGN sont lus par GDAL/PROJ avec un WKT dégénéré
# (`PROJCRS["EPSG:2154", BASEGEOGCRS["unknown", DATUM["unnamed", ...]]`) où le
# code EPSG est présent dans le *nom* mais sans autorité rattachée. terra ne
# résout alors pas le code (`describe$code = NA`) et refuse les reprojections
# (« CRS do not match ») -> extractions NA (R1/R2/R3/W3, TWI). On récupère le
# code EPSG déclaré dans le WKT et on re-tamponne un CRS propre. No-op si le CRS
# a déjà une autorité, est vide, ou ne déclare pas d'EPSG.
.normalize_crs <- function(r) {
  if (is.null(r) || !inherits(r, "SpatRaster")) return(r)
  if (!is.na(terra::crs(r, describe = TRUE)$code)) return(r)  # autorité présente
  w <- terra::crs(r)
  if (!nzchar(w)) return(r)                                    # pas de CRS du tout
  m <- regmatches(w, regexpr("EPSG:[0-9]+", w))
  if (!length(m)) return(r)
  tryCatch({ terra::crs(r) <- m[[1]]; r }, error = function(e) r)
}

# Résolution de travail topographique par défaut, en mètres.
#
# 2 m est un compromis mesuré sur le MNT LiDAR HD de Dabo (3 000 ha, 12000 x
# 10000 à 0,5 m), l'écart étant exprimé en points de score R3 /100 contre une
# référence calculée à 0,5 m, grille TWI alignée à chaque résolution :
#
#   0,5 m  référence      265 s
#   1   m  0,81 pt        33 s     spill terra 329 Mo
#   2   m  1,40 pt        10 s     0 Mo — tient en RAM
#   5   m  2,33 pt         3 s     0 Mo
#
# La dégradation est monotone, mais « plus proche du 0,5 m » n'est pas « plus
# juste » : sur un MNT LiDAR en forêt, le pas fin capte les cloisonnements, les
# chablis et les fossés — de la micro-topographie qui n'est pas l'exposition du
# peuplement à la sécheresse. 2 m garde l'erreur sous 1,5 pt sans faire spiller
# terra. Réglable sans release du cœur :
#
#   options(nemeton.topo_target_res = 5)      # session
#   NEMETON_TOPO_TARGET_RES=5                 # environnement
#
.NEMETON_TOPO_TARGET_RES <- 2

.topo_target_res <- function() {
  v <- getOption("nemeton.topo_target_res", NULL)
  if (is.null(v)) {
    e <- Sys.getenv("NEMETON_TOPO_TARGET_RES", unset = "")
    if (!nzchar(e)) return(.NEMETON_TOPO_TARGET_RES)
    v <- e
  }
  v <- suppressWarnings(as.numeric(v)[1])
  # Un réglage illisible retombe sur le défaut plutôt que de désactiver le
  # garde-fou en silence ; pour calculer à la résolution native, on passe
  # explicitement `dem_target_res = NULL` à l'indicateur.
  if (is.na(v) || v <= 0) return(.NEMETON_TOPO_TARGET_RES)
  v
}

# Facteur d'agrégation entier ramenant `dem` à ~`target_res` (1 = no-op).
# On n'agrège jamais vers plus fin que la résolution native, ni sur un DEM en
# lon/lat (résolution en degrés, incompatible avec un pas métrique).
.dem_working_fact <- function(dem, target_res) {
  if (is.null(dem) || !inherits(dem, "SpatRaster")) return(1L)
  if (is.null(target_res) || !is.finite(target_res) || target_res <= 0) return(1L)
  if (terra::is.lonlat(dem)) return(1L)
  cur <- terra::res(dem)[1]
  if (!is.finite(cur) || cur <= 0) return(1L)
  fact <- floor(target_res / cur)
  if (fact < 2L) return(1L)
  as.integer(fact)
}

# Ramène un DEM à ~`target_res` m avant tout calcul dérivé du terrain.
#
# Un MNT LiDAR HD couvre un massif à 0,5 m : 12000 x 10000 = 120 M cellules. Les
# indicateurs qui en dérivent pente/exposition/TRI, une distance ou un TWI
# empilent une dizaine de couches plein format — R2 en aligne neuf — soit ~10 Go
# de rasters intermédiaires. Le 2026-08-06 cette pile a fait monter la session R
# à 21,2 Go sur une machine de 31 Go, et systemd-oomd a tué le scope entier
# (RStudio compris) pendant le calcul de R2 sur le projet Dabo.
#
# Un indice moyenné par unité de gestion ne gagne rien à une pente dérivée au
# demi-mètre : toute la structure sub-métrique est moyennée par polygone avant
# d'entrer dans le score. `target_res = NULL` désactive le garde-fou.
.dem_working_res <- function(dem, target_res = .topo_target_res(), context = NULL) {
  fact <- .dem_working_fact(dem, target_res)
  if (fact < 2L) return(dem)
  cur <- terra::res(dem)[1]
  out <- tryCatch(
    terra::aggregate(dem, fact = fact, fun = "mean", na.rm = TRUE),
    error = function(e) NULL
  )
  if (is.null(out)) return(dem)
  if (!is.null(context)) {
    cli::cli_alert_info(
      "{context}: DEM aggregated {cur}m -> {terra::res(out)[1]}m (factor {fact}) to bound memory"
    )
  }
  out
}

# Résolution qu'aura la grille de travail, sans matérialiser le raster. Sert de
# clé de cache TWI : deux indicateurs qui aboutissent à la même grille partagent
# alors le cache même si le `target_res` demandé diffère (sur un BD ALTI 25 m,
# toute cible <= 25 m est un no-op et rend le même TWI).
.dem_working_res_value <- function(dem, target_res) {
  if (is.null(dem) || !inherits(dem, "SpatRaster")) return(NA_real_)
  terra::res(dem)[1] * .dem_working_fact(dem, target_res)
}

# Historiquement propre au TWI, conservé comme alias : même opération, mêmes
# garde-fous. Le TWI reste appelé sur un DEM déjà ramené à la résolution de
# travail par l'indicateur appelant, l'agrégation y est alors un no-op.
.twi_aggregate_dem <- function(dem, target_res = .topo_target_res()) {
  .dem_working_res(dem, target_res = target_res)
}

# Version de la méthode TWI, portée par la clé de cache. À incrémenter dès que
# la valeur d'un TWI calculé sur le même MNT change : les caches des projets
# sont alors recalculés au lieu d'être relus (1.0.0 casse les anciens projets
# sans migration).
#   v2 (1.0.0, spec 056) : MNT lon/lat reprojeté en métrique avant le calcul,
#                          TWI ramené à la référence de 2 m (.twi_ref_2m).
.TWI_CACHE_VERSION <- "twi_v2"

# Résolution de référence du TWI (m) : celle du LiDAR HD ramené à la grille de
# travail du paquet (.NEMETON_TOPO_TARGET_RES).
.TWI_REF_RES <- 2

# TWI ramené à la référence de 2 m (spec 056, constat 2).
#
# L'aire spécifique d'une cellule vaut a = A / pas : à pente égale et à
# nombre de cellules drainées égal, TWI = ln(a / tan(pente)) croît donc de
# ln(pas) avec le pas de la grille. Mesuré sur les quatre projets LiDAR,
# TWI(2 m) − TWI(25 m) vaut −1,7 à −2,9, pour ln(25/2) = 2,53 attendu. Une
# fenêtre fixe de normalisation (W3, F2, R3 : [2,5 ; 9]) ne compare donc deux
# projets qu'à pas égal. On recentre :
#
#     TWI_2m = TWI_brut − ln(pas / 2)        (pas en mètres)
#
# Le recentrage est exact pour la composante de pas (même réseau, même pente) ;
# il ne corrige pas ce qu'un MNT grossier lisse du relief (talwegs, ruptures).
# Sans effet à 2 m, −2,53 à 25 m, +1,39 à 0,5 m (MNT natif, target_res = NULL).
.twi_ref_2m <- function(twi, step = terra::res(twi)[1]) {
  twi - log(step / .TWI_REF_RES)
}

# Fenêtre commune de normalisation du TWI (référence 2 m), partagée par W3
# (normalize_indicator), F2 (composante humidité) et R3 (composante topo) —
# décision Pascal 2026-10-06, spec 056. Bornes = quantiles 5-95 % poolés à poids
# égal sur les six projets en cache, grille métrique (q5 = 2,56, q95 = 8,99) :
# aucune UGF ne sature à 2 m. Remplace [2,5 ; 4,5] (W3, 75-100 % des UGF LiDAR
# à 100), [2,5 ; 10] (F2) et TWI / max(TWI de l'emprise) (R3).
.TWI_WINDOW <- c(lo = 2.5, hi = 9)

# TWI -> [0, 1] sur la fenêtre commune (vecteur ou SpatRaster).
.twi_norm <- function(twi) {
  lo <- .TWI_WINDOW[["lo"]]; hi <- .TWI_WINDOW[["hi"]]
  x <- (twi - lo) / (hi - lo)
  if (inherits(x, "SpatRaster")) return(terra::clamp(x, lower = 0, upper = 1))
  pmin(1, pmax(0, x))
}

# CRS métrique du TWI : celui des unités s'il est projeté, sinon ETRS89-LAEA
# (EPSG:3035, ADR-008). Même règle que le chemin fireexposuR de R1.
.twi_metric_crs <- function(units = NULL) {
  .fire_exp_metric_crs(units)
}

# Libellé stable d'un CRS (code d'autorité si possible) pour une clé de cache.
.crs_label <- function(crs) {
  code <- tryCatch(terra::crs(terra::rast(crs = crs), describe = TRUE)$code,
                   error = function(e) NA_character_)
  if (!is.na(code) && nzchar(code)) return(code)
  substr(rlang::hash(crs), 1, 12)
}

# MNT ramené dans un CRS métrique avant tout calcul de TWI.
#
# Le TWI = ln(a / tan(pente)) prend l'aire spécifique a = A / largeur dans
# l'unité du raster. Sur un MNT en EPSG:4326 (repli IGN WMS de Couchey et
# d'Aumur), cette unité est le DEGRÉ (pas ≈ 2,5e-4) : le TWI perdait
# ln(19 m / 2,5e-4) ≈ 11 unités et finissait écrêté à 0 — W3 = 0 sur les
# 76 UGF de Couchey, composante TWI de F2 = 0 (spec 056, constat 1). Même
# correctif que pour R1 (.fire_exp_working_dem) : reprojeter dans `crs`, à la
# résolution native que choisit terra. Un MNT déjà projeté est rendu tel quel.
.twi_metric_dem <- function(dem, crs = "EPSG:3035") {
  if (is.null(dem) || !inherits(dem, "SpatRaster")) return(dem)
  if (!terra::is.lonlat(dem)) return(dem)
  if (is.null(crs)) crs <- "EPSG:3035"
  deg <- terra::res(dem)[1]
  dem <- terra::project(dem, crs, method = "bilinear")
  cli::cli_alert_info(
    "TWI: lon/lat DEM ({signif(deg, 3)} deg) projected to a metric grid ({round(terra::res(dem)[1], 1)}m)"
  )
  dem
}

# Aligne un TWI sur la grille d'un autre raster (pente, exposition…). Le TWI
# d'un MNT lon/lat sort désormais sur une grille métrique : il faut alors le
# reprojeter, pas seulement le rééchantillonner.
.twi_on_grid <- function(twi, template) {
  if (terra::compareGeom(twi, template, stopOnError = FALSE)) return(twi)
  if (!terra::same.crs(twi, template)) {
    return(terra::project(twi, template, method = "bilinear"))
  }
  terra::resample(twi, template, method = "bilinear")
}

# Nom du cache fichier indexé sur l'empreinte du DEM (+ résolution cible). Un nom
# fixe « twi.tif » réutilisait à tort un TWI calculé depuis un AUTRE DEM (ex. WMS
# 25 m) même après acquisition du LiDAR HD : le fichier était rechargé quelle que
# soit l'empreinte courante. Le hash rend le cache auto-invalidant.
.twi_cache_file <- function(key) {
  paste0("twi_", substr(rlang::hash(key), 1, 12), ".tif")
}

get_or_compute_twi <- function(dem, cache_dir = NULL,
                               twi_target_res = .topo_target_res(),
                               crs = NULL) {
  dem <- .normalize_crs(dem)
  if (is.null(crs)) crs <- "EPSG:3035"
  # Key = empreinte DEM (dimensions + extent + CRS) + résolution TWI *effective*.
  # Effective et non demandée : sur un BD ALTI 25 m, `twi_target_res` 2 ou 10
  # produisent le même TWI, et deux indicateurs réglés différemment doivent
  # partager l'entrée de cache plutôt que recalculer à l'identique.
  # 1.0.0 (spec 056) : la clé porte la version de la méthode (.TWI_CACHE_VERSION)
  # — un TWI d'avant le correctif lon/lat ne doit jamais ressortir d'un cache —
  # et, pour un MNT lon/lat, le CRS métrique dans lequel il est reprojeté.
  key <- paste(.TWI_CACHE_VERSION,
               nrow(dem), ncol(dem),
               paste(as.vector(terra::ext(dem)), collapse = ","),
               terra::crs(dem, describe = TRUE)$code,
               signif(.dem_working_res_value(dem, twi_target_res), 6),
               if (terra::is.lonlat(dem)) .crs_label(crs) else "",
               sep = "|")

  # 1. Memory cache (instant)
  if (exists(key, envir = .twi_cache)) {
    cli::cli_alert_info("TWI: Using cached raster (memory)")
    return(get(key, envir = .twi_cache))
  }

  # 2. File cache (persists between sessions) — per-project or global fallback
  if (is.null(cache_dir)) {
    cache_dir <- file.path(get_global_cache_dir(), "twi")
  }
  # Nom indexé sur l'empreinte : invalide automatiquement un cache issu d'un
  # autre DEM (grossier -> LiDAR HD) ou d'une autre résolution cible.
  cache_file <- file.path(cache_dir, .twi_cache_file(key))

  if (file.exists(cache_file)) {
    tryCatch({
      twi_raster <- .normalize_crs(terra::rast(cache_file))
      assign(key, twi_raster, envir = .twi_cache)
      cli::cli_alert_info("TWI: Loaded from file cache")
      return(twi_raster)
    }, error = function(e) NULL)
  }

  # 3. Compute: prefer GRASS, fallback terra D8 (agrégation à twi_target_res)
  if (requireNamespace("fasterRaster", quietly = TRUE)) {
    twi_raster <- calculate_twi_grass(dem, target_res = twi_target_res, crs = crs)
  } else {
    twi_raster <- calculate_twi_terra(dem, target_res = twi_target_res, crs = crs)
  }

  # Save to both caches
  assign(key, twi_raster, envir = .twi_cache)
  tryCatch({
    if (!dir.exists(cache_dir)) dir.create(cache_dir, recursive = TRUE)
    terra::writeRaster(twi_raster, cache_file, overwrite = TRUE)
    cli::cli_alert_info("TWI: Saved to file cache")
  }, error = function(e) NULL)

  twi_raster
}

# ==============================================================================
# FAMILY C: CARBONE / ÉNERGÉTIQUE
# Stock de carbone aérien et souterrain, dynamique de stockage
# ==============================================================================

#' Carbon Stock via Biomass and Allometric Models (C1)
#'
#' Calculates aboveground carbon stock (tC/ha) using species-specific
#' allometric equations from IGN/IFN literature. Requires BD Forêt v2 data
#' (species, age, density) or equivalent attributes.
#'
#' @param units nemeton_units object with forest parcel geometries
#' @param layers nemeton_layers object (optional for future integration)
#' @param species_col Character. Column name for species (default "species")
#' @param age_col Character. Column name for stand age (default "age")
#' @param density_col Character. Column name for stand density as a 0-1
#'   canopy-cover FRACTION (default "density"), as returned by
#'   \code{\link{enrich_parcels_bdforet}}. Not stems/ha (unlike the
#'   \code{density_field} of \code{\link{indicateur_p1_volume}}): values
#'   outside 0-1 are set to NA with a warning.
#' @param chm Optional \code{SpatRaster} of canopy heights in
#'   metres. When supplied together with \code{dbh_col} and
#'   \code{species_col}, activates CHM mode (spec 005 phase 4):
#'   biomass is derived from the IFN tarif
#'   \eqn{V = a \cdot D^b \cdot H^c} combined with wood density,
#'   a biomass expansion factor (BEF) and the carbon fraction
#'   stored in \code{inst/extdata/wood_density.csv}.
#' @param dbh_col Character. Column name for mean stand DBH in
#'   cm. Used only in CHM mode. Default \code{"dbh"}.
#' @param stems_col Character. Column name for stand density in
#'   stems/ha. Used only in CHM mode. Default \code{"stems_ha"}.
#'   If missing, the value of \code{density_col} (treated as a
#'   0-1 fraction) is multiplied by 500 stems/ha to derive a
#'   rough stems/ha proxy.
#' @param h_dom_percentile Numeric in \code{[0, 1]}. Percentile
#'   of CHM pixels used to derive dominant height per unit.
#'   Default \code{0.9}. Ignored when \code{chm} is \code{NULL}.
#' @param bef Numeric. Biomass expansion factor converting stem
#'   volume to total aboveground dry biomass (branches, bark).
#'   Default \code{1.30} (IPCC 2006 temperate-forest default).
#'
#' @return The input \code{units} (same class, rows and order) with an added numeric column \code{C1}: carbon stock values (tC/ha)
#'
#' @section Lifecycle:
#' Stable: covered by the 1.0 API contract (spec 057).
#'
#' @export
#' @examples
#' \dontrun{
#' # With BD Forêt attributes
#' units$species <- c("Quercus", "Fagus", "Pinus")
#' units$age <- c(80, 60, 40)
#' units$density <- c(0.7, 0.8, 0.6)
#'
#' results <- indicateur_c1_biomasse(units)
#' }
indicateur_c1_biomasse <- function(units,
                                     layers = NULL,
                                     species_col = "species",
                                     age_col = "age",
                                     density_col = "density",
                                     chm = NULL,
                                     dbh_col = "dbh",
                                     stems_col = "stems_ha",
                                     h_dom_percentile = 0.9,
                                     bef = 1.30) {
  .indicateur_resultat(units, "C1", .c1_biomasse_valeur(
    units = units,
    layers = layers,
    species_col = species_col,
    age_col = age_col,
    density_col = density_col,
    chm = chm,
    dbh_col = dbh_col,
    stems_col = stems_col,
    h_dom_percentile = h_dom_percentile,
    bef = bef
  ))
}

# Calcul de C1 : rend le vecteur des valeurs, une par unite ; l'enveloppe
# exportee ci-dessus le range dans la colonne `C1` (contrat 1.0, spec 057).
.c1_biomasse_valeur <- function(units,
                                     layers = NULL,
                                     species_col = "species",
                                     age_col = "age",
                                     density_col = "density",
                                     chm = NULL,
                                     dbh_col = "dbh",
                                     stems_col = "stems_ha",
                                     h_dom_percentile = 0.9,
                                     bef = 1.30) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    cli::cli_abort("units must be an sf object")
  }

  # --- Path 0: CHM + DBH + species (spec 005 phase 4) -----------
  if (!is.null(chm) &&
      species_col %in% names(units) &&
      dbh_col %in% names(units)) {
    if (!inherits(chm, "SpatRaster")) {
      cli::cli_abort("chm must be a terra SpatRaster")
    }
    cli::cli_alert_info("C1: computing biomass via CHM + DBH (spec 005 phase 4)")
    h_dom <- extract_h_dom(chm, units, percentile = h_dom_percentile)

    # Stems per ha: prefer stems_col, else derive from density_col fraction
    if (stems_col %in% names(units)) {
      stems_ha <- as.numeric(units[[stems_col]])
    } else if (density_col %in% names(units)) {
      stems_ha <- .check_density_unit(units[[density_col]], "fraction",
                                      "C1") * 500
    } else {
      stems_ha <- rep(300, nrow(units))
    }

    sp  <- units[[species_col]]
    dbh <- as.numeric(units[[dbh_col]])

    biomass <- vapply(seq_len(nrow(units)), function(i) {
      if (is.na(sp[i]) || is.na(dbh[i]) || is.na(h_dom[i]) ||
          is.na(stems_ha[i])) return(NA_real_)
      fallback <- if (is_conifer(sp[i])) "conifer" else "broadleaf"
      eq <- lookup_ifn_equation(sp[i], fallback_genus = fallback)
      if (is.null(eq)) return(NA_real_)
      v_per_tree <- as.numeric(eq$a) * dbh[i]^as.numeric(eq$b) *
        h_dom[i]^as.numeric(eq$c)
      rho <- lookup_species_threshold(sp[i], "density_kg_m3",
                                      "wood_density")
      cf  <- lookup_species_threshold(sp[i], "carbon_content_fraction",
                                      "wood_density")
      if (is.na(rho) || is.na(cf)) return(NA_real_)
      # tC/ha = V_tree (m3) * rho (kg/m3) / 1000 * BEF * C_frac * stems/ha
      v_per_tree * rho / 1000 * bef * cf * stems_ha[i]
    }, numeric(1))

    return(biomass)
  }

  has_inventory <- species_col %in% names(units) &&
                   age_col %in% names(units) &&
                   density_col %in% names(units)

  # --- Path 1: Full inventory data (species/age/density columns) ---
  if (has_inventory) {
    species <- units[[species_col]]
    age <- units[[age_col]]
    # `density` est ici une fraction de couvert 0-1 (pas des tiges/ha)
    density <- .check_density_unit(units[[density_col]], "fraction", "C1")

    biomass <- calculate_allometric_biomass(species, age, density)
    msg_info("indicateur_c1_biomasse")
    return(biomass)
  }

  units_sf <- as_pure_sf(units)

  # --- Path 2: LiDAR MNH available → tutorial 02 allometric model ---
  mnh_raster <- if (!is.null(layers)) resolve_raster_layer(layers, "lidar_mnh") else NULL
  if (!is.null(mnh_raster)) {
    cli::cli_alert_info("Estimating C1 from LiDAR MNH (canopy height model)")
    # pzabove2: proportion of MNH pixels > 2m (canopy cover %)
    mnh_above2 <- mnh_raster > 2
    pzabove2 <- safe_extract(
      mnh_above2, units_sf, fun = "mean", progress = FALSE
    ) * 100
    # `zmean` est la hauteur moyenne DE LA CANOPÉE, pas celle de l'unité : le
    # modèle porte déjà la fraction de couvert dans `pzabove2`, et un zmean
    # calculé sur toutes les cellules compte donc les trouées deux fois. Sur un
    # peuplement ouvert l'écart est majeur — projet Fordead, parcelle 1 : 47 %
    # de cellules exactement à 0 m (sol nu, MNS = MNT), zmean 1,04 m sur l'unité
    # contre 6,03 m sur la canopée, soit un C1 de 0,14 au lieu de 1,91 tC/ha.
    # La formule n'était pas robuste aux peuplements hétérogènes : elle écrasait
    # le signal des îlots restants.
    mnh_canopy <- terra::ifel(mnh_raster > 2, mnh_raster, NA)
    zmean <- safe_extract(
      mnh_canopy, units_sf, fun = "mean", progress = FALSE
    )
    # Aucune cellule de canopée : la moyenne est NA, mais la biomasse est 0 —
    # une coupe rase n'est pas une donnée manquante.
    zmean[is.na(zmean) | is.nan(zmean)] <- 0
    # AGB = k * (pzabove2/100) * zmean^1.5  (tutorial 02 model)
    k_biomasse <- 2.5
    fraction_carbone <- 0.47
    agb <- k_biomasse * (pzabove2 / 100) * (pmax(0, zmean, na.rm = FALSE)^1.5)
    biomass <- agb * fraction_carbone
    return(biomass)
  }

  # --- Path 3: BD Forêt V2 → enrich parcels then allometric model ---
  bdforet_sf <- if (!is.null(layers)) resolve_vector_layer(layers, "bdforet") else NULL
  if (!is.null(bdforet_sf) && nrow(bdforet_sf) > 0) {
    cli::cli_alert_info("Enriching parcels with BD For\u00eat data for C1")
    enriched <- enrich_parcels_bdforet(units_sf, bdforet_sf)
    # Le modèle allométrique a besoin d'un âge, que la BD Forêt ne porte pas
    # (age = NA depuis 1.0.0, spec 056 ; c'était 60 ans inventés). Sans âge,
    # on passe au repli NDVI au lieu de rendre une biomasse fabriquée.
    if (any(!is.na(enriched$species) & !is.na(enriched$age))) {
      biomass <- calculate_allometric_biomass(
        enriched$species, enriched$age, enriched$density
      )
      return(biomass)
    }
  }

  # --- Path 4: NDVI fallback ---
  ndvi_raster <- if (!is.null(layers)) resolve_raster_layer(layers, "ndvi") else NULL
  if (!is.null(ndvi_raster)) {
    cli::cli_alert_info("No LiDAR/BD For\u00eat; estimating C1 from NDVI")
    ndvi_mean <- safe_extract(
      ndvi_raster, units_sf, fun = "mean", progress = FALSE
    )
    # NDVI-to-biomass proxy: scale NDVI (0-1) to approximate carbon stock
    # (tC/ha). Typical temperate forest: ~80-150 tC/ha at high NDVI.
    biomass <- pmax(0, ndvi_mean, na.rm = FALSE) * 150
    return(biomass)
  }

  # Last resort: return NA
  cli::cli_alert_warning(
    "C1: no inventory, LiDAR, BD For\u00eat, or NDVI data; returning NA"
  )
  rep(NA_real_, nrow(units))
}

#' NDVI Mean and Trend Analysis (C2)
#'
#' Extracts mean NDVI from Sentinel-2 or equivalent satellite imagery.
#' Optionally calculates NDVI trend over multiple dates (requires temporal rasters).
#'
#' In FAPAR mode (Theia \code{s2_biophysical}, phase 3a), when a
#' FAPAR raster is supplied via \code{fapar}, the per-unit mean
#' Fraction of Absorbed Photosynthetically Active Radiation is
#' returned instead of NDVI. FAPAR is a physically grounded
#' vitality measure on the same \code{[0, 1]} scale as NDVI, so
#' downstream normalization is unchanged. When \code{fapar} is
#' \code{NULL} the pre-existing NDVI behaviour is preserved.
#'
#' @param units nemeton_units object
#' @param layers nemeton_layers object containing NDVI raster(s)
#' @param ndvi_layer Character. Name of NDVI layer in layers object
#' @param trend Logical. Calculate temporal trend if multiple dates available?
#'   Default FALSE.
#' @param fapar Optional \code{SpatRaster} of FAPAR values in
#'   \code{[0, 1]} (typically the Theia \code{s2_biophysical}
#'   FAPAR product, loaded via \code{\link{load_raster_source}}).
#'   When supplied, activates FAPAR mode: the function returns the
#'   per-unit mean FAPAR and ignores \code{ndvi_layer}. The raster
#'   is expected in the CRS of \code{units}.
#'
#' @return The input \code{units} (same class, rows and order) with an added numeric column \code{C2}:
#'   mean NDVI (0-1 scale), or mean FAPAR in FAPAR mode.
#'
#' @section Lifecycle:
#' Stable: covered by the 1.0 API contract (spec 057).
#'
#' @export
#' @examples
#' \dontrun{
#' # Single-date NDVI
#' layers <- nemeton_layers(rasters = list(ndvi = "sentinel2_ndvi.tif"))
#' results <- indicateur_c2_ndvi(units, layers, ndvi_layer = "ndvi")
#'
#' # Multi-date NDVI with trend
#' results <- indicateur_c2_ndvi(units, layers, ndvi_layer = "ndvi", trend = TRUE)
#'
#' # FAPAR mode (Theia s2_biophysical)
#' fapar <- load_raster_source("s2_biophysical", "FR", path = "fapar_2023.tif")
#' results <- indicateur_c2_ndvi(units, layers, fapar = fapar)
#' }
indicateur_c2_ndvi <- function(units,
                                  layers,
                                  ndvi_layer = "ndvi",
                                  trend = FALSE,
                                  fapar = NULL) {
  .indicateur_resultat(units, "C2", .c2_ndvi_valeur(
    units = units,
    layers = layers,
    ndvi_layer = ndvi_layer,
    trend = trend,
    fapar = fapar
  ))
}

# Calcul de C2 : rend le vecteur des valeurs, une par unite ; l'enveloppe
# exportee ci-dessus le range dans la colonne `C2` (contrat 1.0, spec 057).
.c2_ndvi_valeur <- function(units,
                                  layers,
                                  ndvi_layer = "ndvi",
                                  trend = FALSE,
                                  fapar = NULL) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    cli::cli_abort("units must be an sf object")
  }

  if (!inherits(layers, "nemeton_layers")) {
    cli::cli_abort("layers must be a nemeton_layers object")
  }

  # --- FAPAR mode (Theia s2_biophysical, phase 3a) --------------
  if (!is.null(fapar)) {
    if (!inherits(fapar, "SpatRaster")) {
      cli::cli_abort("fapar must be a terra SpatRaster")
    }
    cli::cli_alert_info("C2: vitality from FAPAR (Theia s2_biophysical)")
    fapar_mean <- safe_extract(
      fapar,
      as_pure_sf(units),
      fun = "mean",
      progress = FALSE
    )
    msg_info("indicateur_c2_ndvi")
    return(fapar_mean)
  }

  # Get NDVI raster (resolve lazy-load)
  ndvi_raster <- resolve_raster_layer(layers, ndvi_layer)
  if (is.null(ndvi_raster)) {
    cli::cli_abort("NDVI layer '{ndvi_layer}' not found in layers")
  }

  # Extract mean NDVI for each unit
  ndvi_mean <- safe_extract(
    ndvi_raster,
    as_pure_sf(units),
    fun = "mean",
    progress = FALSE
  )

  # Handle trend calculation (future implementation)
  if (trend) {
    warning("NDVI trend calculation not yet implemented in v0.2.0 - returning single-date mean only",
      call. = FALSE
    )
    # In future: calculate Sen's slope or linear regression if multi-date raster
  }

  # Log calculation
  msg_info("indicateur_c2_ndvi")

  ndvi_mean
}

# ==============================================================================
# FAMILY W: WATER / INFILTRÉE
# Infiltration, stockage et restitution de l'eau, protection des sources
# ==============================================================================

#' Hydrographic Network Density (W1)
#'
#' Calculates stream/river network length density within or near forest parcels.
#' Includes a proximity bonus for parcels near watercourses (within 500m)
#' that are not directly crossed, reflecting the hydrological influence of
#' nearby streams on water table and microclimate.
#'
#' @param units nemeton_units object
#' @param layers nemeton_layers object containing watercourse vector layer
#' @param watercourse_layer Character. Name of watercourse layer in layers object
#' @param buffer Numeric. Buffer distance (meters) for proximity analysis. Default 0.
#' @param proximity_m Numeric. Maximum distance (m) for proximity bonus. Default 500.
#' @param proximity_ref Numeric. Equivalent density bonus (m/ha) at distance 0. Default 50.
#'
#' @return The input \code{units} (same class, rows and order) with an added numeric column \code{W1}: network density (m/ha). NA for every unit when
#'   the watercourse layer is missing (no measurement); a supplied but empty
#'   layer gives 0.
#'
#' @section Lifecycle:
#' Stable: covered by the 1.0 API contract (spec 057).
#'
#' @export
#' @examples
#' \dontrun{
#' layers <- nemeton_layers(vectors = list(streams = "watercourses.gpkg"))
#' results <- indicateur_w1_reseau(units, layers, watercourse_layer = "streams")
#' }
indicateur_w1_reseau <- function(units,
                                    layers,
                                    watercourse_layer = "water_network",
                                    buffer = 0,
                                    proximity_m = 500,
                                    proximity_ref = 50) {
  .indicateur_resultat(units, "W1", .w1_reseau_valeur(
    units = units,
    layers = layers,
    watercourse_layer = watercourse_layer,
    buffer = buffer,
    proximity_m = proximity_m,
    proximity_ref = proximity_ref
  ))
}

# Calcul de W1 : rend le vecteur des valeurs, une par unite ; l'enveloppe
# exportee ci-dessus le range dans la colonne `W1` (contrat 1.0, spec 057).
.w1_reseau_valeur <- function(units,
                                    layers,
                                    watercourse_layer = "water_network",
                                    buffer = 0,
                                    proximity_m = 500,
                                    proximity_ref = 50) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    cli::cli_abort("units must be an sf object")
  }

  if (!inherits(layers, "nemeton_layers")) {
    cli::cli_abort("layers must be a nemeton_layers object")
  }

  # Get watercourse vector layer (resolve lazy-load)
  watercourses <- resolve_vector_layer(layers, watercourse_layer)
  # Couche absente = pas de mesure : NA, pas 0. Le 0 disait « aucun cours
  # d'eau » et tirait la famille Eau vers le bas ; une couche fournie mais
  # vide reste, elle, une mesure (0).
  if (is.null(watercourses)) {
    cli::cli_warn("W1: No watercourse data available for this area. Returning NA (no measurement made).")
    return(rep(NA_real_, nrow(units)))
  }

  # Ensure CRS match
  if (!sf::st_crs(units) == sf::st_crs(watercourses)) {
    watercourses <- sf::st_transform(watercourses, sf::st_crs(units))
  }

  # Calculate density for each unit
  density <- numeric(nrow(units))

  for (i in seq_len(nrow(units))) {
    unit_geom <- units[i, ]

    # Apply buffer if requested
    if (buffer > 0) {
      unit_geom <- sf::st_buffer(unit_geom, dist = buffer)
    }

    # Intersect watercourses with unit
    intersected <- suppressWarnings(sf::st_intersection(watercourses, unit_geom))

    # Calculate total length of watercourses (in meters)
    if (nrow(intersected) > 0) {
      total_length_m <- as.numeric(sum(sf::st_length(intersected)))
    } else {
      total_length_m <- 0
    }

    # Calculate unit area (in ha)
    area_m2 <- as.numeric(sf::st_area(units[i, ]))
    area_ha <- area_m2 / 10000

    # Direct density = m / ha (consistent with tuto 03)
    direct_density <- total_length_m / area_ha

    # Proximity bonus: parcels near watercourses benefit from water table influence
    # Decreases linearly from proximity_ref at 0m to 0 at proximity_m
    if (total_length_m == 0 && proximity_m > 0) {
      min_dist <- as.numeric(min(sf::st_distance(units[i, ], watercourses)))
      if (min_dist < proximity_m) {
        proximity_bonus <- (1 - min_dist / proximity_m) * proximity_ref
      } else {
        proximity_bonus <- 0
      }
    } else {
      # Parcel already crossed by watercourse: full proximity bonus
      proximity_bonus <- proximity_ref
    }

    density[i] <- direct_density + proximity_bonus
  }

  # Log calculation
  msg_info("indicateur_w1_reseau")

  density
}

#' Wetland Coverage (W2)
#'
#' Calculates percentage of parcel area classified as wetland or riparian zone.
#' The wetland area is the UNION of several optional sources (a pixel counted
#' by two sources is counted once): BD TOPO water surfaces, a TWI threshold,
#' land-cover codes listed in \code{wetland_values}, and — when supplied — the
#' Theia \code{theia_water} water-occurrence product. Sources are evaluated
#' on a regular grid of points inside each unit; points where every source is
#' NA are left out, and a unit with no known point is NA.
#'
#' @param units nemeton_units object
#' @param layers nemeton_layers object containing land cover raster or wetland vector
#' @param wetland_layer Character. Name of wetland layer in layers object
#' @param wetland_values Numeric vector. Land cover codes representing wetlands.
#'   Default NULL: the land-cover source is not used (there is no
#'   auto-detection; the OSO nomenclature has no wetland class, only water,
#'   code 23).
#' @param water_occurrence Optional \code{SpatRaster} of water-occurrence
#'   frequency in percent (0-100) — the Theia \code{theia_water}
#'   \code{water_occurrence} product, loaded via
#'   \code{\link{load_raster_source}}. When supplied, pixels whose
#'   occurrence reaches \code{occurrence_threshold} contribute to the
#'   wetland coverage. Default \code{NULL}.
#' @param occurrence_threshold Numeric in \code{[0, 100]}. Minimum
#'   water-occurrence frequency (percent of observations) for a pixel to
#'   count as wetland. Default \code{25}. Ignored when
#'   \code{water_occurrence} is \code{NULL}.
#' @param dem_target_res Numeric. Working resolution (metres) the DEM is
#'   aggregated to before TWI is computed. The same value drives the TWI grid,
#'   so both coincide and the TWI is never resampled up to a finer grid. Keep
#'   it identical across W2/W3/F2/R3 to share a single cached TWI. Default: the
#'   package-wide topographic working resolution, 2 m — see
#'   \code{options("nemeton.topo_target_res")}; \code{NULL} keeps the native
#'   resolution.
#'
#' @return The input \code{units} (same class, rows and order) with an added numeric column \code{W2}: wetland coverage (0-100\%)
#'
#' @section Lifecycle:
#' Stable: covered by the 1.0 API contract (spec 057).
#'
#' @export
#' @examples
#' \dontrun{
#' layers <- nemeton_layers(rasters = list(landcover = "landcover.tif"))
#' results <- indicateur_w2_zones_humides(units, layers, wetland_values = c(50, 51, 52))
#' }
indicateur_w2_zones_humides <- function(units,
                                     layers,
                                     wetland_layer = "wetlands",
                                     wetland_values = NULL,
                                     water_occurrence = NULL,
                                     occurrence_threshold = 25,
                                     dem_target_res = .topo_target_res()) {
  .indicateur_resultat(units, "W2", .w2_zones_humides_valeur(
    units = units,
    layers = layers,
    wetland_layer = wetland_layer,
    wetland_values = wetland_values,
    water_occurrence = water_occurrence,
    occurrence_threshold = occurrence_threshold,
    dem_target_res = dem_target_res
  ))
}

# Calcul de W2 : rend le vecteur des valeurs, une par unite ; l'enveloppe
# exportee ci-dessus le range dans la colonne `W2` (contrat 1.0, spec 057).
.w2_zones_humides_valeur <- function(units,
                                     layers,
                                     wetland_layer = "wetlands",
                                     wetland_values = NULL,
                                     water_occurrence = NULL,
                                     occurrence_threshold = 25,
                                     dem_target_res = .topo_target_res()) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    cli::cli_abort("units must be an sf object")
  }

  if (!inherits(layers, "nemeton_layers")) {
    cli::cli_abort("layers must be a nemeton_layers object")
  }

  # Les quatre sources se recouvrent (une mare BD TOPO est aussi un TWI eleve
  # et une forte occurrence d'eau) : additionner leurs couvertures comptait
  # plusieurs fois la meme surface. W2 est desormais la couverture de
  # l'UNION des masques, evaluee sur une grille reguliere de points par unite
  # (robuste aux CRS differents des sources).

  # Source 1: BD TOPO water surfaces (mares, retenues, etangs)
  water_union <- NULL
  water_surfaces_sf <- resolve_vector_layer(layers, "water_surfaces")
  if (!is.null(water_surfaces_sf) && nrow(water_surfaces_sf) > 0) {
    cli::cli_alert_info("W2: Adding BD TOPO water surfaces coverage")
    water_union <- sf::st_union(sf::st_make_valid(
      sf::st_geometry(water_surfaces_sf)
    ))
  }

  # Masques raster : liste de fonctions (valeur -> humide TRUE/FALSE)
  raster_sources <- list()

  # Source 2: TWI threshold (TWI > 12 = potential wetland zones)
  dem <- .dem_working_res(get_dem_raster(layers),
                          target_res = dem_target_res, context = "W2")
  if (!is.null(dem)) {
    cli::cli_alert_info("W2: Adding TWI-based wetland zones (threshold > 12)")
    # `twi_target_res` suit la résolution de travail : les deux grilles
    # coïncident, le TWI n'est jamais rééchantillonné vers du plus fin.
    twi_raster <- get_or_compute_twi(dem, cache_dir = layers$cache_dir,
                                     twi_target_res = dem_target_res,
                                     crs = .twi_metric_crs(units))
    raster_sources$twi <- list(r = twi_raster, wet = function(v) v > 12)
  }

  # Source 3: land-cover wetland codes (only when wetland_values is given)
  lc_raster <- resolve_raster_layer(layers, wetland_layer)
  if (is.null(lc_raster)) lc_raster <- resolve_raster_layer(layers, "landcover")
  if (is.null(lc_raster)) lc_raster <- resolve_raster_layer(layers, "forest_cover")
  if (!is.null(wetland_values) && !is.null(lc_raster)) {
    cli::cli_alert_info("W2: Adding land-cover wetland coverage")
    raster_sources$landcover <- list(
      r = lc_raster, wet = function(v) v %in% wetland_values
    )
  }

  # Source 4: Theia theia_water occurrence frequency (phase 3d)
  if (!is.null(water_occurrence)) {
    if (!inherits(water_occurrence, "SpatRaster")) {
      cli::cli_abort("water_occurrence must be a terra SpatRaster")
    }
    cli::cli_alert_info("W2: Adding Theia theia_water occurrence coverage")
    raster_sources$occurrence <- list(
      r = water_occurrence, wet = function(v) v >= occurrence_threshold
    )
  }

  if (is.null(water_union) && length(raster_sources) == 0) {
    cli::cli_alert_warning("W2: No wetland data available (no vectors, DEM, or landcover)")
    return(rep(NA_real_, nrow(units)))
  }

  coverage <- vapply(seq_len(nrow(units)), function(i) {
    .w2_union_coverage(sf::st_geometry(units)[i], water_union, raster_sources)
  }, numeric(1))

  msg_info("indicateur_w2_zones_humides")
  pmin(coverage, 100)
}

#' W2: percentage of a unit covered by the union of wetland masks
#'
#' Evaluates every source on a regular grid of points inside the unit. A
#' point is wet when any source says so, dry when no source says wet and at
#' least one source has a value, unknown when every source is NA. Returns
#' 100 * wet / known, or NA when no point is known.
#' @noRd
.w2_union_coverage <- function(geom, water_union, raster_sources,
                               n_points = 4000) {
  geom <- sf::st_make_valid(geom)
  # Grille de points en metres (CRS geographique -> ETRS89-LAEA)
  g_m <- if (isTRUE(sf::st_is_longlat(geom))) sf::st_transform(geom, 3035) else geom
  pts <- suppressMessages(sf::st_sample(g_m, size = n_points, type = "regular"))
  if (length(pts) == 0) pts <- suppressWarnings(sf::st_point_on_surface(g_m))
  pts <- sf::st_transform(pts, sf::st_crs(geom))
  n <- length(pts)

  wet <- rep(FALSE, n)
  known <- rep(FALSE, n)

  if (!is.null(water_union)) {
    pts_v <- sf::st_transform(pts, sf::st_crs(water_union))
    wet <- wet | lengths(sf::st_intersects(pts_v, water_union)) > 0
    known[] <- TRUE
  }

  for (src in raster_sources) {
    r_crs <- terra::crs(src$r)
    pts_r <- if (nzchar(r_crs)) sf::st_transform(pts, r_crs) else pts
    v <- terra::extract(src$r, terra::vect(pts_r), ID = FALSE)[, 1]
    ok <- !is.na(v)
    w <- rep(FALSE, n)
    w[ok] <- as.logical(src$wet(v[ok]))
    wet <- wet | (ok & w)
    known <- known | ok
  }

  if (!any(known)) return(NA_real_)
  sum(wet & known) / sum(known) * 100
}

#' Topographic Wetness Index (W3)
#'
#' Calculates TWI using fasterRaster/GRASS GIS (preferred) or terra fallback (D8).
#' Higher values indicate areas with greater water accumulation potential.
#'
#' The GRASS method (via fasterRaster) performs proper hydrological conditioning:
#' depression filling, flow direction, flow accumulation, then TWI = ln(SCA / tan(slope)).
#' The terra D8 method is a simpler approximation used as fallback.
#'
#' A DEM in geographic coordinates is first projected to a metric CRS (the
#' units' CRS when projected, else EPSG:3035): the specific catchment area is
#' in metres, never in degrees. The TWI is then referenced to a 2 m grid,
#' \code{TWI_2m = TWI - ln(step / 2)} with \code{step} the computation grid
#' step in metres, because the specific catchment area scales with the step
#' (spec 056). Values from different DEM resolutions are thus on one scale.
#'
#' @param units nemeton_units object
#' @param layers nemeton_layers object containing DEM raster
#' @param dem_layer Character. Name of DEM layer in layers object
#' @param method Character. TWI calculation method: "auto" (prefer GRASS),
#'   "grass" (fasterRaster/GRASS GIS), or "d8" (terra D8). Default "auto".
#' @param dem_target_res Numeric. Working resolution (metres) the DEM is
#'   aggregated to before TWI is computed. The same value drives the TWI grid,
#'   so both coincide and the TWI is never resampled up to a finer grid. Keep
#'   it identical across W2/W3/F2/R3 to share a single cached TWI. Default: the
#'   package-wide topographic working resolution, 2 m — see
#'   \code{options("nemeton.topo_target_res")}; \code{NULL} keeps the native
#'   resolution.
#'
#' @return The input \code{units} (same class, rows and order) with an added numeric column \code{W3}: mean TWI, referenced to a 2 m grid.
#'
#' @section Lifecycle:
#' Stable: covered by the 1.0 API contract (spec 057).
#'
#' @export
#' @examples
#' \dontrun{
#' layers <- nemeton_layers(rasters = list(dem = "dem_25m.tif"))
#' results <- indicateur_w3_humidite(units, layers, dem_layer = "dem")
#' }
indicateur_w3_humidite <- function(units,
                                layers,
                                dem_layer = "dem",
                                method = c("auto", "grass", "d8"),
                                dem_target_res = .topo_target_res()) {
  .indicateur_resultat(units, "W3", .w3_humidite_valeur(
    units = units,
    layers = layers,
    dem_layer = dem_layer,
    method = method,
    dem_target_res = dem_target_res
  ))
}

# Calcul de W3 : rend le vecteur des valeurs, une par unite ; l'enveloppe
# exportee ci-dessus le range dans la colonne `W3` (contrat 1.0, spec 057).
.w3_humidite_valeur <- function(units,
                                layers,
                                dem_layer = "dem",
                                method = c("auto", "grass", "d8"),
                                dem_target_res = .topo_target_res()) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    cli::cli_abort("units must be an sf object")
  }

  if (!inherits(layers, "nemeton_layers")) {
    cli::cli_abort("layers must be a nemeton_layers object")
  }

  # Match and validate method
  method <- match.arg(method)

  # Get best available DEM (prefer LiDAR HD MNT over BD ALTI)
  dem <- get_dem_raster(layers)
  if (is.null(dem)) {
    dem <- .normalize_crs(resolve_raster_layer(layers, dem_layer))
  }
  if (is.null(dem)) {
    cli::cli_abort("No DEM layer available (tried lidar_mnt, {dem_layer})")
  }
  dem <- .dem_working_res(dem, target_res = dem_target_res, context = "W3")

  # Calculate TWI (cached across W2, W3, F2, R3)
  # `twi_target_res` suit la résolution de travail : le DEM reçu est déjà à la
  # bonne grille, l'agrégation interne au TWI est alors un no-op.
  twi_crs <- .twi_metric_crs(units)
  if (method == "d8") {
    twi_raster <- calculate_twi_terra(dem, target_res = dem_target_res,
                                      crs = twi_crs)
  } else {
    twi_raster <- get_or_compute_twi(dem, cache_dir = layers$cache_dir,
                                     twi_target_res = dem_target_res,
                                     crs = twi_crs)
  }

  # Extract mean TWI for each unit
  twi_mean <- safe_extract(
    twi_raster,
    as_pure_sf(units),
    fun = "mean",
    progress = FALSE
  )

  # Log calculation
  msg_info("indicateur_w3_humidite")

  twi_mean
}

#' Calculate TWI using terra (D8 algorithm)
#' @keywords internal
#' @noRd
calculate_twi_terra <- function(dem, target_res = .topo_target_res(),
                                crs = "EPSG:3035") {
  # Un MNT lon/lat est d'abord reprojeté en métrique (cf. .twi_metric_dem) :
  # l'aire spécifique ci-dessous est en mètres, jamais en degrés.
  dem <- .twi_metric_dem(dem, crs)
  # Agréger à la résolution cible : TWI hydrologiquement stable + calcul allégé
  # (cf. .twi_aggregate_dem). target_res = NULL -> pas d'agrégation (repli déjà agrégé).
  dem <- .twi_aggregate_dem(dem, target_res)
  # Calculate slope (in radians)
  slope_deg <- terra::terrain(dem, v = "slope", unit = "degrees")
  slope_rad <- slope_deg * pi / 180

  # Replace zero/very small slopes with small value to avoid division by zero
  # This handles flat areas
  slope_rad[slope_rad < 0.001] <- 0.001

  # Calculate flow direction (D8)
  flow_dir <- terra::terrain(dem, v = "flowdir", neighbors = 8)

  # Calculate flow accumulation (number of cells draining to each cell)
  flow_acc <- terra::flowAccumulation(flow_dir)

  # Get cell resolution (m)
  cell_res <- terra::res(dem)
  cell_area <- prod(cell_res) # resolution in x and y (m²)
  cell_width <- cell_res[1]

  # Specific catchment area (m²/m) = (flow_acc + 1) * cell_area / cell_width
  # +1 because flow_acc doesn't include the cell itself
  # This represents the contributing area per unit contour length
  catchment_area <- (flow_acc + 1) * cell_area / cell_width

  # Calculate TWI = ln(catchment_area / tan(slope))
  # TWI represents the tendency of water to accumulate at a location
  twi <- log(catchment_area / tan(slope_rad))

  # Handle edge cases:
  # - Infinite values can occur from numerical issues
  # - Negative TWI values shouldn't exist theoretically
  twi[is.infinite(twi)] <- NA
  twi[is.nan(twi)] <- NA

  # Set a reasonable range for TWI (typically 0-20 in natural landscapes)
  # Extreme values indicate calculation issues
  twi[twi > 50] <- NA # Flag suspiciously high values

  # Référence 2 m (cf. .twi_ref_2m), PUIS plancher à 0 : le TWI rendu est
  # toujours positif, sur la même échelle quel que soit le pas de calcul.
  twi <- .twi_ref_2m(twi, cell_width)
  twi[twi < 0] <- 0

  twi
}

#' Calculate TWI using fasterRaster/GRASS GIS
#'
#' Uses GRASS GIS via fasterRaster for proper hydrological TWI computation:
#' depression filling, flow direction/accumulation via wetness().
#' @keywords internal
#' @noRd
calculate_twi_grass <- function(dem, target_res = .topo_target_res(),
                                crs = "EPSG:3035") {
  # Reprojeter un MNT lon/lat AVANT d'agréger (l'agrégation est métrique), puis
  # agréger une seule fois ici ; les replis terra reçoivent déjà le DEM projeté
  # et agrégé (target_res = NULL) pour éviter une double agrégation.
  dem <- .twi_metric_dem(dem, crs)
  dem <- .twi_aggregate_dem(dem, target_res)
  if (!requireNamespace("fasterRaster", quietly = TRUE)) {
    cli::cli_abort("fasterRaster package required for GRASS TWI calculation")
  }

  # Detect GRASS installation
  grass_dir <- Sys.getenv("GRASS_DIR", unset = "")
  if (grass_dir == "") {
    # Common GRASS paths on Linux
    candidates <- c(
      "/usr/lib/grass84", "/usr/lib/grass83", "/usr/lib/grass82",
      "/usr/lib/grass", "/usr/local/grass"
    )
    for (path in candidates) {
      if (dir.exists(path)) {
        grass_dir <- path
        break
      }
    }
  }

  if (grass_dir == "" || !dir.exists(grass_dir)) {
    warning("GRASS GIS not found, falling back to terra D8", call. = FALSE)
    return(calculate_twi_terra(dem, target_res = NULL))
  }

  tryCatch({
    cli::cli_alert_info("W3: Computing TWI with fasterRaster/GRASS ({basename(grass_dir)})")

    # fasterRaster needs terra/sf/data.table loaded, and its namespace fully attached
    # to find internal .fasterRaster object (fails in Shiny without this)
    requireNamespace("terra", quietly = TRUE)
    requireNamespace("sf", quietly = TRUE)
    requireNamespace("data.table", quietly = TRUE)
    loadNamespace("fasterRaster")

    # Initialize GRASS session
    fasterRaster::faster(grassDir = grass_dir)

    # GRASS exige un CRS projeté : le MNT l'est déjà (.twi_metric_dem).

    # Convert terra raster to GRaster
    elev <- fasterRaster::fast(dem)

    # Compute TWI using GRASS r.topidx (handles depression filling internally)
    twi_grass <- fasterRaster::wetness(elev)

    # Convert back to terra raster
    twi_terra <- terra::rast(twi_grass)

    # Sanitize output, puis référence 2 m (cf. .twi_ref_2m) — r.topidx calcule
    # lui aussi l'aire spécifique en surface / pas.
    twi_terra[is.infinite(twi_terra)] <- NA
    twi_terra[is.nan(twi_terra)] <- NA
    twi_terra[twi_terra > 50] <- NA
    twi_terra <- .twi_ref_2m(twi_terra, terra::res(dem)[1])
    twi_terra[twi_terra < 0] <- 0

    cli::cli_alert_success("W3: GRASS TWI computed successfully")
    twi_terra
  }, error = function(e) {
    warning(
      sprintf("GRASS TWI failed (%s), falling back to terra D8", conditionMessage(e)),
      call. = FALSE
    )
    calculate_twi_terra(dem, target_res = NULL)
  })
}

# ==============================================================================
# FAMILY F: FERTILITÉ / RICHE
# Santé biologique, chimique et physique des sols
# ==============================================================================

#' Soil Fertility Class (F1)
#'
#' Extracts soil fertility from a user-supplied pedological layer, from
#' the SoilGrids 2.0 global CEC topsoil raster, or from a French RRP
#' polygon layer joined to the UTS → fertility crosswalk shipped in
#' \code{inst/extdata/uts_fertilite_fr.csv}.
#'
#' Three data sources are supported via \code{source}:
#' \itemize{
#'   \item \code{"layer"} (default) — read a raster or polygon layer from
#'     \code{layers} and map its values linearly from
#'     \code{fertility_range} to 0-100 (absolute score: a unit's value does
#'     not depend on the other units of the call). Polygon layers are
#'     area-weighted over the polygons that carry a value; units with no
#'     valued polygon are NA.
#'   \item \code{"soilgrids"} — fetch the 250 m SoilGrids 2.0 Cation
#'     Exchange Capacity raster (0-5 cm topsoil, mean) declared as
#'     \code{soilgrids_cec} in \code{inst/datasources/FR.json}, extract
#'     the per-unit mean and map it to 0-100 via
#'     \code{\link{cec_to_fertility_score}} (absolute score, comparable
#'     across projects). No inventory layer is needed.
#'   \item \code{"gissol"} — read a French RRP (Référentiel Régional
#'     Pédologique) polygon layer from \code{layers} that carries a
#'     pedological typology code (AFES 2008 Référentiel Pédologique),
#'     intersect it with \code{units}, join the AFES code against
#'     \code{\link{read_uts_fertility_table}}, and return an
#'     area-weighted fertility score per unit on the 0-100 scale.
#'     France metropolitan only. Unknown codes are silently dropped;
#'     units whose polygons carry only unknown codes return NA.
#'   \item \code{"theia_soil"} — derive fertility from a Theia
#'     \code{theia_soil} texture raster set passed via \code{texture}
#'     (a named list of clay / silt / sand, optionally
#'     \code{coarse_elements}, \code{SpatRaster}s). The per-unit mean
#'     texture is mapped to a 0-100 score via
#'     \code{\link{texture_to_fertility_score}}. No inventory layer
#'     is needed.
#' }
#'
#' SoilGrids is global — the \code{"soilgrids"} mode works for any AOI,
#' \code{country} only controls where the datasource entry is looked up.
#'
#' @param units nemeton_units object
#' @param layers nemeton_layers object containing soil data. Unused when
#'   \code{source = "soilgrids"}.
#' @param soil_layer Character. Name of soil layer in layers object.
#'   Unused when \code{source = "soilgrids"}.
#' @param fertility_col Character. Column/band name for fertility class
#'   in \code{"layer"} mode. Unused when \code{source} is
#'   \code{"soilgrids"} or \code{"gissol"}.
#' @param source Character. One of \code{"layer"} (default),
#'   \code{"soilgrids"}, \code{"gissol"}, or \code{"theia_soil"}.
#' @param country Character. Country code used to resolve the SoilGrids
#'   datasource entry. Default \code{"FR"}.
#' @param rpf_code_col Character. Column in the RRP layer that carries
#'   the AFES 2008 code (matching the \code{rpf_code} primary key of
#'   \code{\link{read_uts_fertility_table}}). Default
#'   \code{"rpf_code"}. Only used when \code{source = "gissol"}.
#' @param texture Optional named list of \code{SpatRaster}s with
#'   elements \code{clay}, \code{silt}, \code{sand} and optionally
#'   \code{coarse_elements} (the Theia \code{theia_soil} products,
#'   loaded via \code{\link{load_raster_source}}). Required when
#'   \code{source = "theia_soil"}, ignored otherwise.
#' @param fertility_range Numeric of length 2. Value range of the soil
#'   layer in \code{"layer"} mode, mapped linearly to 0-100 (lowest =
#'   least fertile). Default \code{c(0, 100)}: the layer is already a 0-100
#'   score. For fertility classes 1-5, pass \code{c(1, 5)}. Values outside
#'   the range are set to NA with a warning. Ignored by the other sources.
#'
#' @return The input \code{units} (same class, rows and order) with an added numeric column \code{F1}: fertility scores (0-100 scale, higher = more fertile)
#'
#' @section Lifecycle:
#' Stable: covered by the 1.0 API contract (spec 057).
#'
#' @export
#' @examples
#' \dontrun{
#' # Traditional path: user-supplied soil layer
#' layers <- nemeton_layers(vectors = list(soil = "bd_sol.gpkg"))
#' results <- indicateur_f1_fertilite(units, layers, soil_layer = "soil")
#'
#' # SoilGrids path: no soil layer needed
#' results <- indicateur_f1_fertilite(units, source = "soilgrids")
#'
#' # GIS Sol path: RRP polygons + AFES typology join
#' layers <- nemeton_layers(vectors = list(soil = "rrp_departement.gpkg"))
#' results <- indicateur_f1_fertilite(units, layers,
#'                                    source = "gissol",
#'                                    rpf_code_col = "UTSDom")
#' }
indicateur_f1_fertilite <- function(units,
                                     layers = NULL,
                                     soil_layer = "soil",
                                     fertility_col = "fertility",
                                     source = c("layer", "soilgrids", "gissol",
                                                "theia_soil"),
                                     country = "FR",
                                     rpf_code_col = "rpf_code",
                                     texture = NULL,
                                     fertility_range = c(0, 100)) {
  .indicateur_resultat(units, "F1", .f1_fertilite_valeur(
    units = units,
    layers = layers,
    soil_layer = soil_layer,
    fertility_col = fertility_col,
    source = source,
    country = country,
    rpf_code_col = rpf_code_col,
    texture = texture,
    fertility_range = fertility_range
  ))
}

# Calcul de F1 : rend le vecteur des valeurs, une par unite ; l'enveloppe
# exportee ci-dessus le range dans la colonne `F1` (contrat 1.0, spec 057).
.f1_fertilite_valeur <- function(units,
                                     layers = NULL,
                                     soil_layer = "soil",
                                     fertility_col = "fertility",
                                     source = c("layer", "soilgrids", "gissol",
                                                "theia_soil"),
                                     country = "FR",
                                     rpf_code_col = "rpf_code",
                                     texture = NULL,
                                     fertility_range = c(0, 100)) {
  source <- match.arg(source)

  if (!inherits(units, "sf")) {
    cli::cli_abort("units must be an sf object")
  }

  if (identical(source, "soilgrids")) {
    fertility <- extract_fertility_from_soilgrids(units, country = country)
    msg_info("indicateur_f1_fertilite")
    return(fertility)
  }

  if (identical(source, "theia_soil")) {
    if (is.null(texture)) {
      cli::cli_abort("source = 'theia_soil' requires a 'texture' list of rasters")
    }
    cli::cli_alert_info("F1: fertility from soil texture (Theia theia_soil)")
    fertility <- extract_fertility_from_theia_soil(units, texture)
    msg_info("indicateur_f1_fertilite")
    return(fertility)
  }

  if (identical(source, "gissol")) {
    if (!inherits(layers, "nemeton_layers")) {
      cli::cli_abort("layers must be a nemeton_layers object")
    }
    fertility <- extract_fertility_from_gissol(units, layers,
                                               soil_layer = soil_layer,
                                               rpf_code_col = rpf_code_col)
    msg_info("indicateur_f1_fertilite")
    return(fertility)
  }

  if (!inherits(layers, "nemeton_layers")) {
    cli::cli_abort("layers must be a nemeton_layers object")
  }

  is_raster <- !is.null(resolve_raster_layer(layers, soil_layer))
  is_vector <- !is.null(resolve_vector_layer(layers, soil_layer))

  if (!is_raster && !is_vector) {
    cli::cli_abort("Soil layer '{soil_layer}' not found in layers")
  }

  if (is_raster) {
    fertility <- extract_fertility_from_raster(units, layers, soil_layer,
                                               fertility_col, fertility_range)
  } else {
    fertility <- extract_fertility_from_vector(units, layers, soil_layer,
                                               fertility_col, fertility_range)
  }

  msg_info("indicateur_f1_fertilite")

  fertility
}

#' Extract fertility from raster layer
#' @keywords internal
#' @noRd
extract_fertility_from_raster <- function(units, layers, soil_layer, fertility_col,
                                          fertility_range = c(0, 100)) {
  # Get soil raster (resolve lazy-load)
  soil_raster <- resolve_raster_layer(layers, soil_layer)

  # Extract mean soil values for each unit
  soil_values <- safe_extract(
    soil_raster,
    as_pure_sf(units),
    fun = "mean",
    progress = FALSE
  )

  # Echelle ABSOLUE (fertility_range -> 0-100). L'ancien min-max sur le lot
  # rendait un score relatif : 0 et 100 aux extremes du lot quelle que soit
  # la fertilite reelle, 50 pour une unite seule.
  .f1_rescale(soil_values, fertility_range)
}

#' Map F1 soil-layer values from `fertility_range` to 0-100
#'
#' Linear and absolute; values outside the range are NA (with a warning).
#' @keywords internal
#' @noRd
.f1_rescale <- function(v, fertility_range = c(0, 100)) {
  if (!is.numeric(fertility_range) || length(fertility_range) != 2L ||
      anyNA(fertility_range) || fertility_range[2] <= fertility_range[1]) {
    cli::cli_abort("{.arg fertility_range} must be two increasing numbers.")
  }
  v <- as.numeric(v)
  v[is.nan(v)] <- NA_real_
  lo <- fertility_range[1]
  hi <- fertility_range[2]
  tol <- 1e-9 * (hi - lo)
  out <- !is.na(v) & (v < lo - tol | v > hi + tol)
  if (any(out)) {
    cli::cli_warn(c(
      "!" = "F1: {sum(out)} soil value{?s} outside {.arg fertility_range} \
             [{lo}, {hi}]; set to NA.",
      "i" = "Set {.arg fertility_range} to the value range of the soil layer \
             (e.g. {.code c(1, 5)} for fertility classes)."
    ))
    v[out] <- NA_real_
  }
  score <- (v - lo) / (hi - lo) * 100
  pmin(pmax(score, 0), 100)
}

#' Extract fertility from vector layer
#' @keywords internal
#' @noRd
extract_fertility_from_vector <- function(units, layers, soil_layer, fertility_col,
                                          fertility_range = c(0, 100)) {
  # Get soil vector layer (resolve lazy-load)
  soil_vector <- resolve_vector_layer(layers, soil_layer)

  # Ensure CRS match
  if (!sf::st_crs(units) == sf::st_crs(soil_vector)) {
    soil_vector <- sf::st_transform(soil_vector, sf::st_crs(units))
  }

  # Check if fertility column exists
  if (!fertility_col %in% names(soil_vector)) {
    cli::cli_abort("Fertility column '{fertility_col}' not found in soil layer")
  }

  # Intersect units with soil polygons and extract fertility
  fertility <- numeric(nrow(units))

  for (i in seq_len(nrow(units))) {
    unit_geom <- units[i, ]

    # Intersect with soil layer
    intersected <- suppressWarnings(sf::st_intersection(soil_vector, unit_geom))

    if (nrow(intersected) > 0) {
      # Moyenne ponderee par la surface des seuls polygones renseignes : une
      # surface sans valeur ne doit pas entrer au denominateur (elle tirait le
      # score vers 0), et une unite sans aucune valeur est NA, pas 0.
      area <- as.numeric(sf::st_area(intersected))
      fertility_values <- suppressWarnings(
        as.numeric(intersected[[fertility_col]])
      )
      ok <- !is.na(fertility_values) & area > 0
      fertility[i] <- if (any(ok)) {
        sum(fertility_values[ok] * area[ok]) / sum(area[ok])
      } else {
        NA_real_
      }
    } else {
      # No intersection - assign NA or default value
      fertility[i] <- NA_real_
    }
  }

  # Echelle absolue fertility_range -> 0-100 (valeurs hors plage -> NA)
  .f1_rescale(fertility, fertility_range)
}

#' Map SoilGrids CEC values to a 0-100 fertility score
#'
#' Cation Exchange Capacity (CEC) is the most common proxy for nutrient
#' retention in forest soils. SoilGrids 2.0 distributes CEC in
#' \eqn{cmol(c)/kg \times 10}; the raw raster value must be divided by
#' 10 to recover the physical unit. The mapping used here is linear on
#' the \eqn{[0, 30]\;cmol(c)/kg} window, capped at the bounds:
#' \itemize{
#'   \item < 3 cmol(c)/kg: very poor (acid podzols, sandy soils)
#'   \item 3-7:  poor
#'   \item 7-15: moderate
#'   \item 15-25: good
#'   \item > 25: rich (calcareous, alluvial, peaty)
#' }
#' Thresholds after Baize & Jabiol (1995), \emph{Guide pour la
#' description des sols}. NA in, NA out.
#'
#' @param cec_x10 Numeric. Raw SoilGrids CEC value (cmol(c)/kg x 10).
#' @return Numeric vector on the 0-100 scale (higher = more fertile).
#' @section Lifecycle:
#' Stable: covered by the 1.0 API contract (spec 057).
#'
#' @export
cec_to_fertility_score <- function(cec_x10) {
  cec <- cec_x10 / 10
  score <- (cec / 30) * 100
  pmin(pmax(score, 0), 100)
}

#' Extract fertility from SoilGrids 2.0 CEC topsoil raster
#' @keywords internal
#' @noRd
extract_fertility_from_soilgrids <- function(units, country = "FR") {
  cec_raster <- load_raster_source("soilgrids_cec", country = country,
                                   aoi = units)

  cec_values <- safe_extract(
    cec_raster,
    as_pure_sf(units),
    fun = "mean",
    progress = FALSE
  )

  cec_to_fertility_score(cec_values)
}

#' Map soil texture to a 0-100 fertility score
#'
#' First-pass heuristic converting a soil-texture composition into a
#' forest-fertility score on the 0-100 scale, used by
#' \code{\link{indicateur_f1_fertilite}} in \code{"theia_soil"} mode
#' (Theia \code{theia_soil} product, chantier sources Theia phase 3b).
#'
#' The texture triplet \code{clay} / \code{silt} / \code{sand} is
#' normalised internally to fractions summing to 1, so the inputs may
#' be given in any consistent unit (g/kg, percent, fraction). The
#' score is the proximity of the texture to the loam optimum
#' (clay 0.20, silt 0.40, sand 0.40) in the texture triangle: loam
#' scores ~100, pure sand ~50, pure silt ~30, heavy clay ~0
#' (waterlogging, root constraints). When \code{coarse_elements} is
#' supplied (percent of coarse fragments, 0-100), the score is
#' multiplied by \code{(1 - coarse/100)} — a stony soil has less fine
#' earth and retains fewer nutrients.
#'
#' This is a calibratable heuristic, not a validated pedotransfer
#' function; it is exported so a pedologist can audit and tune it.
#' NA in, NA out.
#'
#' @param clay,silt,sand Numeric vectors of the clay, silt and sand
#'   contents (any consistent unit — they are renormalised).
#' @param coarse_elements Optional numeric vector of coarse-element
#'   content in percent (0-100). Default \code{NULL} (no penalty).
#' @return Numeric vector on the 0-100 scale (higher = more fertile).
#' @section Lifecycle:
#' Stable: covered by the 1.0 API contract (spec 057).
#'
#' @export
texture_to_fertility_score <- function(clay, silt, sand,
                                       coarse_elements = NULL) {
  total <- clay + silt + sand
  clay_f <- clay / total
  silt_f <- silt / total
  # Distance to the loam optimum (clay 0.20, silt 0.40) in the
  # (clay, silt) plane; sand is the dependent third coordinate.
  d <- sqrt((clay_f - 0.20)^2 + (silt_f - 0.40)^2)
  score <- (1 - d / 0.9) * 100
  score <- pmin(pmax(score, 0), 100)

  if (!is.null(coarse_elements)) {
    coarse_frac <- pmin(pmax(coarse_elements / 100, 0), 1)
    score <- score * (1 - coarse_frac)
  }
  score
}

#' Map soil texture to a 0-100 erosion-resistance score
#'
#' First-pass heuristic converting a soil-texture composition into an
#' erosion-resistance score on the 0-100 scale (higher = more
#' resistant, less erodible), used by \code{\link{indicateur_f2_erosion}}
#' when a Theia \code{theia_soil} texture is supplied (chantier sources
#' Theia phase 3b).
#'
#' Following the USLE soil-erodibility logic, silt (and very fine
#' sand) is the most erodible fraction, clay resists through
#' aggregate cohesion, and coarse sand drains. The triplet is
#' renormalised to fractions; erodibility is
#' \code{(silt_f + 0.4 * sand_f) * (1 - 0.6 * clay_f)} on the 0-1
#' scale, and resistance is \code{100 * (1 - erodibility)}.
#'
#' Calibratable heuristic, exported for audit. NA in, NA out.
#'
#' @param clay,silt,sand Numeric vectors of the clay, silt and sand
#'   contents (any consistent unit — they are renormalised).
#' @return Numeric vector on the 0-100 scale (higher = more resistant
#'   to erosion).
#' @section Lifecycle:
#' Stable: covered by the 1.0 API contract (spec 057).
#'
#' @export
texture_to_erosion_resistance <- function(clay, silt, sand) {
  total <- clay + silt + sand
  clay_f <- clay / total
  silt_f <- silt / total
  sand_f <- sand / total
  erodibility <- (silt_f + 0.4 * sand_f) * (1 - 0.6 * clay_f)
  resistance <- (1 - pmin(pmax(erodibility, 0), 1)) * 100
  pmin(pmax(resistance, 0), 100)
}

#' Extract per-unit mean texture from a Theia theia_soil raster set
#' @keywords internal
#' @noRd
.extract_texture_means <- function(units, texture) {
  if (!is.list(texture)) {
    cli::cli_abort("texture must be a named list of SpatRasters")
  }
  required <- c("clay", "silt", "sand")
  missing <- setdiff(required, names(texture))
  if (length(missing) > 0) {
    cli::cli_abort(
      "texture is missing raster(s): {paste(missing, collapse = ', ')}"
    )
  }
  units_sf <- as_pure_sf(units)
  pick <- function(key) {
    r <- texture[[key]]
    if (is.null(r)) return(NULL)
    if (!inherits(r, "SpatRaster")) {
      cli::cli_abort("texture${key} must be a SpatRaster")
    }
    safe_extract(r, units_sf, fun = "mean", progress = FALSE)
  }
  list(
    clay = pick("clay"),
    silt = pick("silt"),
    sand = pick("sand"),
    coarse_elements = pick("coarse_elements")
  )
}

#' Extract fertility from a Theia theia_soil texture raster set
#' @keywords internal
#' @noRd
extract_fertility_from_theia_soil <- function(units, texture) {
  tm <- .extract_texture_means(units, texture)
  texture_to_fertility_score(tm$clay, tm$silt, tm$sand,
                             coarse_elements = tm$coarse_elements)
}

#' Read the UTS → fertility crosswalk shipped with the package
#'
#' Loads \code{inst/extdata/uts_fertilite_fr.csv}, the V1 French
#' typological-soil-unit to forest-fertility table (AFES 2008
#' Référentiel Pédologique, 54 rows covering the 14 Grands Ensembles
#' de Référence). Columns: \code{rpf_code} (primary key), \code{rpf_name},
#' \code{wrb_code} (WRB 2014 equivalent), \code{fertility_class} (1-5),
#' \code{fertility_score} (0-100), \code{texture_dom}, \code{drainage},
#' \code{depth_cm}, \code{ph_range}, \code{forest_note},
#' \code{source_biblio}, \code{notes}.
#'
#' The primary consumer is \code{\link{indicateur_f1_fertilite}} in
#' \code{"gissol"} mode. The table is exposed for external review
#' (pedologists auditing scores) and for users who want to join
#' arbitrary RRP vector data against the same crosswalk directly.
#'
#' @return A data.frame with 12 columns and 54 rows.
#' @section Lifecycle:
#' Stable: covered by the 1.0 API contract (spec 057).
#'
#' @export
read_uts_fertility_table <- function() {
  path <- system.file("extdata", "uts_fertilite_fr.csv",
                      package = "nemeton", mustWork = TRUE)
  utils::read.csv(path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

#' Extract fertility from an RRP polygon layer joined to the UTS table
#' @keywords internal
#' @noRd
extract_fertility_from_gissol <- function(units, layers,
                                          soil_layer = "soil",
                                          rpf_code_col = "rpf_code") {
  rrp <- resolve_vector_layer(layers, soil_layer)
  if (is.null(rrp)) {
    cli::cli_abort("Soil layer '{soil_layer}' not found in layers")
  }
  if (!rpf_code_col %in% names(rrp)) {
    cli::cli_abort(
      "RRP column '{rpf_code_col}' not found in layer '{soil_layer}'"
    )
  }

  if (!sf::st_crs(units) == sf::st_crs(rrp)) {
    rrp <- sf::st_transform(rrp, sf::st_crs(units))
  }

  uts_table <- read_uts_fertility_table()

  unmatched <- setdiff(
    unique(as.character(rrp[[rpf_code_col]])),
    uts_table$rpf_code
  )
  if (length(unmatched) > 0) {
    preview <- utils::head(unmatched, 5)
    suffix <- if (length(unmatched) > 5) " (+ more)" else ""
    cli::cli_warn(sprintf(
      "F1 GIS Sol: %d RRP code(s) not in UTS table, dropped. Unknown: %s%s",
      length(unmatched),
      paste(preview, collapse = ", "),
      suffix
    ))
  }

  fertility <- numeric(nrow(units))
  for (i in seq_len(nrow(units))) {
    intersected <- suppressWarnings(
      sf::st_intersection(rrp, units[i, ])
    )
    if (nrow(intersected) == 0) {
      fertility[i] <- NA_real_
      next
    }

    area <- as.numeric(sf::st_area(intersected))
    codes <- as.character(intersected[[rpf_code_col]])
    scores <- uts_table$fertility_score[
      match(codes, uts_table$rpf_code)
    ]
    valid <- !is.na(scores) & area > 0

    fertility[i] <- if (any(valid)) {
      sum(scores[valid] * area[valid]) / sum(area[valid])
    } else {
      NA_real_
    }
  }

  fertility
}

#' Soil Fertility Index (F2)
#'
#' Calculates soil fertility potential by combining TWI (water/nutrient
#' accumulation) and slope (erosion risk). Follows the tuto 03 methodology:
#' F2 = (twi_norm + slope_norm) / 2
#'
#' TWI is computed via GRASS (fasterRaster) when available, terra D8 otherwise,
#' referenced to a 2 m grid (\code{TWI - ln(step / 2)}) and normalised on the
#' window [2.5, 9] shared with W3 and R3 (spec 056).
#' Higher values indicate more fertile soil conditions.
#'
#' When a Theia \code{theia_soil} texture raster set is supplied via
#' \code{texture} (chantier sources Theia phase 3b), a third
#' component — texture-based erosion resistance, see
#' \code{\link{texture_to_erosion_resistance}} — is averaged in:
#' F2 = (twi_norm + slope_norm + resistance_norm) / 3. Silt-rich soils
#' are more erodible and lower the score.
#'
#' @param units nemeton_units object
#' @param layers nemeton_layers object containing DEM raster
#' @param dem_layer Character. Name of DEM layer
#' @param texture Optional named list of \code{SpatRaster}s with
#'   elements \code{clay}, \code{silt}, \code{sand} (the Theia
#'   \code{theia_soil} products, loaded via
#'   \code{\link{load_raster_source}}). When supplied, adds the
#'   texture erosion-resistance component. Default \code{NULL}
#'   (pre-existing TWI + slope behaviour).
#' @param dem_target_res Numeric. Working resolution (metres) the DEM is
#'   aggregated to before TWI and slope are computed. The same value drives the
#'   TWI grid, so both coincide and the TWI is never resampled up to a finer
#'   grid. Keep it identical across W2/W3/F2/R3 to share a single cached TWI.
#'   Default: the package-wide topographic working resolution, 2 m — see
#'   \code{options("nemeton.topo_target_res")}; \code{NULL} keeps the native
#'   resolution.
#'
#' @return The input \code{units} (same class, rows and order) with an added numeric column \code{F2}: erosion-resistance scores (0-100, higher = more
#'   resistant, i.e. LOWER erosion risk). Despite the historical variable name
#'   inside the function, this is not a fertility score: the ingredients are
#'   topographic (TWI wetness, slope steepness) plus optional soil texture.
#'
#' @section Lifecycle:
#' Stable: covered by the 1.0 API contract (spec 057).
#'
#' @export
#' @examples
#' \dontrun{
#' layers <- nemeton_layers(rasters = list(dem = "dem.tif"))
#' results <- indicateur_f2_erosion(units, layers)
#' }
indicateur_f2_erosion <- function(units,
                                   layers,
                                   dem_layer = "dem",
                                   texture = NULL,
                                   dem_target_res = .topo_target_res()) {
  .indicateur_resultat(units, "F2", .f2_erosion_valeur(
    units = units,
    layers = layers,
    dem_layer = dem_layer,
    texture = texture,
    dem_target_res = dem_target_res
  ))
}

# Calcul de F2 : rend le vecteur des valeurs, une par unite ; l'enveloppe
# exportee ci-dessus le range dans la colonne `F2` (contrat 1.0, spec 057).
.f2_erosion_valeur <- function(units,
                                   layers,
                                   dem_layer = "dem",
                                   texture = NULL,
                                   dem_target_res = .topo_target_res()) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    cli::cli_abort("units must be an sf object")
  }

  if (!inherits(layers, "nemeton_layers")) {
    cli::cli_abort("layers must be a nemeton_layers object")
  }

  # Get best available DEM (prefer LiDAR HD MNT over BD ALTI)
  dem <- get_dem_raster(layers)
  if (is.null(dem)) {
    dem <- .normalize_crs(resolve_raster_layer(layers, dem_layer))
  }
  if (is.null(dem)) {
    cli::cli_abort("No DEM layer available (tried lidar_mnt, {dem_layer})")
  }
  dem <- .dem_working_res(dem, target_res = dem_target_res, context = "F2")

  units_sf <- as_pure_sf(units)

  # 1. Compute TWI (cached across W2, W3, F2, R3)
  cli::cli_alert_info("F2: Computing erosion resistance from TWI + slope")
  # `twi_target_res` suit la résolution de travail (grilles alignées, cache
  # partagé avec W2/W3/R3).
  twi_raster <- get_or_compute_twi(dem, cache_dir = layers$cache_dir,
                                   twi_target_res = dem_target_res,
                                   crs = .twi_metric_crs(units))

  twi_mean <- safe_extract(twi_raster, units_sf, fun = "mean", progress = FALSE)

  # 2. Compute slope (degrees)
  slope_raster <- terra::terrain(dem, v = "slope", unit = "degrees")
  slope_mean <- safe_extract(slope_raster, units_sf, fun = "mean", progress = FALSE)

  # 3. Normalize TWI on the common window [2.5, 9] -> [0, 100] (higher TWI =
  # more fertile). Fenêtre commune W3/F2/R3 sur un TWI ramené à 2 m (spec 056) ;
  # elle était [2,5 ; 10] pour F2 seul.
  twi_norm <- .twi_norm(twi_mean) * 100

  # 4. Normalize slope: [0°, 45°] -> [100, 0] (flatter = less erodible)
  slope_norm <- pmax(pmin(100 - (slope_mean / 45) * 100, 100), 0)

  # 5. F2 = average of TWI and slope components, plus an optional
  #    texture-based erosion-resistance component (Theia theia_soil)
  if (!is.null(texture)) {
    cli::cli_alert_info("F2: adding texture erosion-resistance (Theia theia_soil)")
    tm <- .extract_texture_means(units, texture)
    resistance <- texture_to_erosion_resistance(tm$clay, tm$silt, tm$sand)
    fertility <- round((twi_norm + slope_norm + resistance) / 3, 1)
  } else {
    fertility <- round((twi_norm + slope_norm) / 2, 1)
  }

  # Log calculation
  msg_info("indicateur_f2_erosion")

  fertility
}

# ==============================================================================
# FAMILY L: LANDSCAPE / ESTHÉTIQUE
# Qualité paysagère, composition, diversité des structures, harmonies
# ==============================================================================

#' Sylvosphere - Edge Effect (L1)
#'
#' Composite indicator (0-100) with 3 components:
#' - Geometry (30%): shape index measuring parcel irregularity
#' - Matrix contrast (40%): land use contrast in buffer zone (OSO classes)
#' - Exposure (30%): wind (60%) and sun (40%) exposure based on boundary orientation
#'
#' @param units nemeton_units object
#' @param layers nemeton_layers object containing land cover (optional)
#' @param landcover_layer Character. Name of land cover layer
#' @param forest_values Numeric vector. Land cover codes for forest; their
#'   matrix contrast is 0. Default \code{c(16, 17)}: OSO broadleaf and
#'   coniferous forest (23-class Theia/CESBIO nomenclature). Other codes are
#'   read with the OSO contrast table (built-up 90, roads 75, crops 50,
#'   orchards/vineyards 45, water 30, grassland 20, moorland 15; 50 for codes
#'   outside the nomenclature).
#' @param buffer Numeric. Buffer distance (meters) for contrast analysis. Default 50m.
#'
#' @return The input \code{units} (same class, rows and order) with an added numeric column \code{L1}: sylvosphere scores (0-100). **Higher = more edge effect
#' borne by the unit = less favourable**: all three components grow with it
#' (boundary irregularity, hostile surrounding matrix, wind and sun
#' exposure). The value is therefore INVERTED by normalize_indicator() so the
#' radar convention holds (0-100, higher = better), like R1-R5 and T3. See
#' spec 048 section 9.
#'
#' @section Renamed in 0.176.0:
#' This indicator used to be called `indicateur_l2_fragmentation()` — a name
#' that announced the L2 fragmentation metric while computing the L1 edge
#' effect. The old name, kept as a deprecated alias since then, was removed
#' in 1.0.0 (spec 057). Persisted columns are renamed by
#' [migrer_colonnes_l()]. See spec 045.
#'
#' @section Lifecycle:
#' Stable: covered by the 1.0 API contract (spec 057).
#'
#' @export
#' @examples
#' \dontrun{
#' layers <- nemeton_layers(rasters = list(landcover = "landcover.tif"))
#' results <- indicateur_l1_effet_lisiere(
#'   units, layers,
#'   forest_values = c(1, 2, 3), buffer = 50
#' )
#' }
indicateur_l1_effet_lisiere <- function(units,
                                              layers = NULL,
                                              landcover_layer = "landcover",
                                              forest_values = c(16, 17),
                                              buffer = 50) {
  .indicateur_resultat(units, "L1", .l1_effet_lisiere_valeur(
    units = units,
    layers = layers,
    landcover_layer = landcover_layer,
    forest_values = forest_values,
    buffer = buffer
  ))
}

# Calcul de L1 : rend le vecteur des valeurs, une par unite ; l'enveloppe
# exportee ci-dessus le range dans la colonne `L1` (contrat 1.0, spec 057).
.l1_effet_lisiere_valeur <- function(units,
                                              layers = NULL,
                                              landcover_layer = "landcover",
                                              forest_values = c(16, 17),
                                              buffer = 50) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    cli::cli_abort("units must be an sf object")
  }

  # --- Component 1: Geometry (30%) ---
  # Shape index: SI = perimeter / (2 * sqrt(pi * area))
  l1_geometrie <- numeric(nrow(units))
  perimeters <- numeric(nrow(units))
  areas <- numeric(nrow(units))

  for (i in seq_len(nrow(units))) {
    boundary <- sf::st_cast(units[i, ], "MULTILINESTRING")
    perimeters[i] <- as.numeric(sf::st_length(boundary))
    areas[i] <- as.numeric(sf::st_area(units[i, ]))
    si <- perimeters[i] / (2 * sqrt(pi * areas[i]))
    l1_geometrie[i] <- pmin(100, (si - 1) * 25)
  }

  # --- Component 2: Matrix contrast (40%) ---
  # Table de contraste derivee de la nomenclature OSO 23 classes partagee
  # (l'ancienne table etait decalee : 16-18 « foret » alors que 18 = pelouses,
  # 19-30 hors nomenclature). Les codes `forest_values` ont un contraste nul.
  oso_contrast <- stats::setNames(OSO_NOMENCLATURE$contraste_l1,
                                  as.character(OSO_NOMENCLATURE$code))
  oso_contrast[as.character(forest_values)] <- 0

  l1_contraste <- numeric(nrow(units))
  has_landcover <- FALSE

  if (!is.null(layers) && inherits(layers, "nemeton_layers")) {
    landcover <- resolve_raster_layer(layers, landcover_layer)
    if (is.null(landcover)) landcover <- resolve_raster_layer(layers, "forest_cover")
    if (!is.null(landcover)) has_landcover <- TRUE
  }

  if (has_landcover) {
    for (i in seq_len(nrow(units))) {
      # Buffer around parcel, subtract parcel = edge zone
      edge_zone <- tryCatch({
        geom_i <- sf::st_geometry(units[i, ])
        buf <- sf::st_buffer(geom_i, dist = buffer)
        sf::st_sf(geometry = sf::st_difference(buf, geom_i))
      }, error = function(e) NULL)

      if (is.null(edge_zone) || as.numeric(sf::st_area(edge_zone)) < 1) {
        l1_contraste[i] <- 50  # neutral fallback
        next
      }

      # Extract landcover values in edge zone
      lc_values <- tryCatch({
        safe_extract(landcover, as_pure_sf(edge_zone), progress = FALSE)[[1]]$value
      }, error = function(e) NULL)

      if (is.null(lc_values) || length(lc_values) == 0) {
        l1_contraste[i] <- 50
        next
      }

      lc_values <- lc_values[!is.na(lc_values)]
      if (length(lc_values) == 0) {
        l1_contraste[i] <- 50
        next
      }

      # Weighted contrast by pixel count
      lc_tab <- table(as.character(lc_values))
      total_pixels <- sum(lc_tab)
      weighted_contrast <- 0
      for (cls in names(lc_tab)) {
        weight <- if (cls %in% names(oso_contrast)) oso_contrast[cls] else 50
        weighted_contrast <- weighted_contrast + (as.numeric(weight) * lc_tab[cls])
      }
      l1_contraste[i] <- weighted_contrast / total_pixels
    }
  } else {
    # No landcover: neutral contrast
    l1_contraste <- rep(50, nrow(units))
  }

  # --- Component 3: Exposure (30%) ---
  # Wind (60%) + Sun (40%)
  # Get dominant wind direction (cached, default 225° SW for France)
  wind_dir_deg <- get_nasapower_wind(units, default_dir = 225, cache_dir = if (!is.null(layers)) layers$cache_dir)

  l1_exposition <- numeric(nrow(units))

  for (i in seq_len(nrow(units))) {
    # Get boundary coordinates for segment analysis
    boundary <- sf::st_boundary(sf::st_geometry(units[i, ]))
    coords <- sf::st_coordinates(boundary)

    if (nrow(coords) < 3) {
      l1_exposition[i] <- 50
      next
    }

    # Geographic azimuth per segment: atan2(dx, dy) -> 0°=North, clockwise
    n_seg <- nrow(coords) - 1
    azimuths <- numeric(n_seg)
    seg_lengths <- numeric(n_seg)

    for (j in seq_len(n_seg)) {
      dx <- coords[j + 1, 1] - coords[j, 1]
      dy <- coords[j + 1, 2] - coords[j, 2]
      azimuths[j] <- (atan2(dx, dy) * 180 / pi + 360) %% 360
      seg_lengths[j] <- sqrt(dx^2 + dy^2)
    }

    # Wind exposure: max when edge normal is aligned with wind direction
    vent_exposure <- vapply(azimuths, function(az) {
      normale <- (az + 90) %% 360
      diff_angle <- abs(normale - wind_dir_deg)
      if (diff_angle > 180) diff_angle <- 360 - diff_angle
      cos(diff_angle * pi / 180)
    }, numeric(1))

    # Sun exposure: max when edge normal points South (180°)
    soleil_exposure <- vapply(azimuths, function(az) {
      normale <- (az + 90) %% 360
      diff_angle <- abs(normale - 180)
      if (diff_angle > 180) diff_angle <- 360 - diff_angle
      cos(diff_angle * pi / 180)
    }, numeric(1))

    total_len <- sum(seg_lengths)
    if (total_len > 0) {
      # Wind: absolute value (exposure regardless of face direction)
      wind_score <- sum(abs(vent_exposure) * seg_lengths) / total_len * 100
      # Sun: only positive (south-facing edges count)
      sun_score <- sum(pmax(0, soleil_exposure) * seg_lengths) / total_len * 100
    } else {
      wind_score <- 50
      sun_score <- 50
    }

    l1_exposition[i] <- 0.6 * wind_score + 0.4 * sun_score
  }

  # --- Synthesis ---
  l1 <- 0.30 * l1_geometrie + 0.40 * l1_contraste + 0.30 * l1_exposition
  l1 <- pmin(pmax(round(l1, 1), 0), 100)

  msg_info("indicateur_l1_effet_lisiere")
  l1
}

#' Landscape Fragmentation (L2)
#'
#' Calculates landscape fragmentation using landscapemetrics (COHESION + AI)
#' when available, or shape index fallback. Returns a score 0-100.
#'
#' @param units nemeton_units object
#' @param layers nemeton_layers object (optional, for raster-based metrics)
#' @param landcover_layer Character. Name of landcover layer in layers.
#' @param forest_values Numeric vector. Values representing forest in landcover.
#'   Default \code{c(16, 17)}: OSO broadleaf and coniferous forest (23-class
#'   Theia/CESBIO nomenclature, the \code{forest_cover} layer). Pass the codes
#'   of your own raster when it uses another nomenclature.
#' @param buffer Numeric. Buffer distance in meters around union of parcels.
#'
#' @return The input \code{units} (same class, rows and order) with an added numeric column \code{L2}: fragmentation scores (0-100). **Higher = less fragmented
#' = favourable** (COHESION + AI, or the inverse shape index in the
#' fallback): already oriented the right way, so normalize_indicator() passes
#' it through and does NOT invert it -- unlike L1.
#'
#' @section Renamed in 0.176.0:
#' This indicator used to be called `indicateur_l1_sylvosphere()` — a name that
#' announced the L1 sylvosphere while computing the L2 fragmentation metric.
#' The old name, kept as a deprecated alias since then, was removed in 1.0.0
#' (spec 057). Persisted columns are renamed by [migrer_colonnes_l()]. See
#' spec 045.
#'
#' @section Lifecycle:
#' Stable: covered by the 1.0 API contract (spec 057).
#'
#' @export
#' @examples
#' \dontrun{
#' results <- indicateur_l2_morcellement(units, layers, buffer = 1000)
#' }
indicateur_l2_morcellement <- function(units, layers = NULL,
                                     landcover_layer = "landcover",
                                     forest_values = c(16, 17),
                                     buffer = 1000) {
  .indicateur_resultat(units, "L2", .l2_morcellement_valeur(
    units = units,
    layers = layers,
    landcover_layer = landcover_layer,
    forest_values = forest_values,
    buffer = buffer
  ))
}

# Calcul de L2 : rend le vecteur des valeurs, une par unite ; l'enveloppe
# exportee ci-dessus le range dans la colonne `L2` (contrat 1.0, spec 057).
.l2_morcellement_valeur <- function(units, layers = NULL,
                                     landcover_layer = "landcover",
                                     forest_values = c(16, 17),
                                     buffer = 1000) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    cli::cli_abort("units must be an sf object")
  }

  if (nrow(units) == 0) {
    cli::cli_abort("units is empty (no features)")
  }

  # Try landscapemetrics approach if layers available
  if (!is.null(layers) && inherits(layers, "nemeton_layers") &&
      requireNamespace("landscapemetrics", quietly = TRUE)) {

    landcover <- resolve_raster_layer(layers, landcover_layer)
    if (is.null(landcover)) landcover <- resolve_raster_layer(layers, "forest_cover")

    if (!is.null(landcover)) {
      tryCatch({
        # Buffer 1km around union of parcels
        union_geom <- sf::st_union(units)
        buffer_zone <- sf::st_buffer(union_geom, dist = buffer)

        # Crop landcover to buffer zone
        lc_cropped <- terra::crop(landcover, terra::vect(buffer_zone), snap = "out")
        lc_masked <- terra::mask(lc_cropped, terra::vect(buffer_zone))

        # Create forest mask (1 = forest, 0 = non-forest)
        is_forest <- function(x) {
          ifelse(x %in% forest_values, 1, 0)
        }
        forest_raster <- terra::app(lc_masked, is_forest)

        # Calculate landscape metrics
        metrics <- suppressWarnings(landscapemetrics::calculate_lsm(
          terra::as.int(forest_raster),
          what = c("lsm_l_cohesion", "lsm_l_ai")
        ))

        cohesion <- metrics$value[metrics$metric == "cohesion"]
        ai <- metrics$value[metrics$metric == "ai"]

        if (length(cohesion) > 0 && length(ai) > 0 &&
            !is.na(cohesion[1]) && !is.na(ai[1])) {
          # L2 = (COHESION + AI) / 2 — same value for all parcels
          l2_score <- (cohesion[1] + ai[1]) / 2
          l2_score <- pmin(pmax(round(l2_score, 1), 0), 100)

          msg_info("indicateur_l2_morcellement")
          return(rep(l2_score, nrow(units)))
        }
      }, error = function(e) {
        cli::cli_alert_warning("L2: landscapemetrics failed ({e$message}), using shape index fallback")
      })
    }
  }

  # Fallback: shape index per parcel
  scores <- numeric(nrow(units))
  for (i in seq_len(nrow(units))) {
    boundary <- sf::st_cast(units[i, ], "MULTILINESTRING")
    perimeter <- as.numeric(sf::st_length(boundary))
    area <- as.numeric(sf::st_area(units[i, ]))

    shape_index <- perimeter / (2 * sqrt(pi * area))
    scores[i] <- pmin(round(100 / shape_index, 1), 100)
  }

  msg_info("indicateur_l2_morcellement")
  scores
}

# indicateur_s3_population est defini dans indicators-social.R

