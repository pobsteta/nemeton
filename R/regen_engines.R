# regen_engines.R — moteurs reGénération : L1/L2 (spec 027 v2.1)
# ------------------------------------------------------------------
# État du portage : les 3 moteurs sont RÉELS — pai_depuis_nuage (lasR),
# regen_sensibilite (microclimf) et regen_bilan_hydrique (biljouR).
# Ces moteurs orchestrent des dépendances LOURDES (GPL, hors CRAN pour
# certaines) : microclimf, mcera5, lidR, lasR (exposition microclimatique) et
# biljouR (bilan hydrique). Elles sont en `Suggests` (hygiène d'installation,
# pas licence : tout est GPL-3 — cf. spec 027 §2). Chaque fonction :
#   * valide ses entrées (testable) ;
#   * OFFRE un chemin `precomputed` PUR : quand les sorties du moteur sont déjà
#     calculées (prototypes /Documents/reGénération, ou cache projet), la
#     fonction les rattache aux unités en colonnes standard §7 — sans le moteur ;
#   * sinon, tente le moteur si présent, ou ÉCHOUE PROPREMENT (message
#     actionnable) — jamais d'erreur de chargement de package.
#
# biljouR est déclaré en `Suggests` + `Remotes` (pobsteta/biljouR) ; il reste
# chargé via requireNamespace() (dépendance optionnelle, dégradation propre).

# Colonnes de sortie §7 par moteur (contrat).
.REGEN_COLS_HYDRIQUE <- c("njstress", "istress", "rew_min", "deb_stress")
.REGEN_COLS_EXPO <- c("tmax_moyenne", "tmax_canicule", "vpd_moyenne",
                      "vpd_canicule", "d_tmax", "d_vpd", "sensibilite",
                      "rang_sensibilite", "robustesse", "signal_robuste",
                      "couverture_pct")

# Rattache des colonnes per-unité `precomputed` (data.frame / liste nommée) à
# `units`, restreintes à `allowed`. Longueur = nrow(units) ou 1 (recyclé).
.regen_attach_precomputed <- function(units, precomputed, allowed) {
  if (!is.data.frame(precomputed) && !is.list(precomputed)) {
    stop("`precomputed` must be a data.frame or a named list", call. = FALSE)
  }
  n <- nrow(units)
  nms <- intersect(names(precomputed), allowed)
  if (!length(nms)) {
    stop("`precomputed` has none of the expected columns: ",
         paste(allowed, collapse = ", "), call. = FALSE)
  }
  unknown <- setdiff(names(precomputed), allowed)
  if (length(unknown)) {
    cli::cli_warn("Ignoring unexpected `precomputed` column{?s}: {.val {unknown}}.")
  }
  for (nm in nms) {
    v <- precomputed[[nm]]
    if (length(v) != n && length(v) != 1L) {
      stop("`precomputed$", nm, "` has length ", length(v),
           "; expected ", n, " (or 1).", call. = FALSE)
    }
    units[[nm]] <- rep(as.numeric(v), length.out = n)
  }
  units
}


#' Soil water balance per unit — BILJOU engine (spec 027 L2)
#'
#' @description
#' Per-unit soil water-balance metrics (relative extractable water, days of
#' hydric stress, drought intensity / onset) from the **BILJOU** model
#' (`biljouR`, INRAE lineage), forced by SAFRAN (primary) or ERA5-Land
#' (fallback) — decision §10.2. Feeds [indicateur_r3_secheresse()] (via its
#' `biljou` argument) and [indice_priorite_regen()].
#'
#' **Two paths.** *Fast-path*: pass `precomputed` (the per-unit output of a
#' BILJOU run) and the metrics are attached to `units` as the §7 columns,
#' **without** the GPL engine. *Engine path*: builds unit-centroid points, runs
#' `biljouR::biljou_run_grid()` (per-point BILJOU forced by `meteo`), and
#' aggregates the per-year drought indices to the mean per unit — mapping
#' `NJstress`/`Istress`/`DEBstress`/`min_rew` to `njstress`/`istress`/
#' `deb_stress`/`rew_min`. It needs `meteo` (SAFRAN via `biljouR::safran_*`, or
#' ERA5-Land — §10.2), a soil (`sol`) and per-unit `lai_max`; with LiDAR/SAFRAN
#' inputs it is **not runnable in CI** — validated on real data.
#'
#' @param units An `sf` of management units (UGF).
#' @param meteo SAFRAN/ERA5 forcing for the engine path: a single `meteo`
#'   `data.frame` (applied to every unit) or a named list keyed by unit id.
#' @param sol A `biljouR::biljou_soil()` object (extractable water `ewm`, root
#'   fractions `roots`, …).
#' @param lai_max Per-unit maximum LAI (e.g. derived from `pai_depuis_nuage()`):
#'   a scalar, a length-`nrow(units)` vector, or a named list by id.
#' @param forest_type Phenology: `"feuillu"`/`"broadleaved"` or
#'   `"resineux"`/`"coniferous"` (mapped to BILJOU's `broadleaved`/`coniferous`).
#' @param years Optional integer years to keep from the BILJOU indices before
#'   averaging (default: all years in the run).
#' @param precomputed Optional per-unit BILJOU output (`data.frame`/list with
#'   any of `njstress`, `istress`, `rew_min`, `deb_stress`). Pure fast-path.
#' @param progress_callback Optional function called at each step with a
#'   `list(current = <key>, …)` payload (monitoring pattern). Keys:
#'   `"regen_biljou:start"` (`n` points) and `"regen_biljou:complete"`. No-op
#'   when `NULL`; never fatal. The per-point loop is internal to `biljouR`.
#' @param ... Passed to `biljouR::biljou_run()` (e.g. `budburst`, `leaf_fall`,
#'   `rew_c`, `k`).
#'
#' @return `units` with the water-balance columns `njstress`, `istress`,
#'   `rew_min`, `deb_stress` (per-unit mean over the retained years).
#' @seealso [indicateur_r3_secheresse()], [indice_priorite_regen()]
#' @export
regen_bilan_hydrique <- function(units, meteo = NULL, sol = NULL,
                                 lai_max = NULL, forest_type = "feuillu",
                                 years = NULL, precomputed = NULL,
                                 progress_callback = NULL, ...) {
  validate_sf(units)
  # Progression (patron monitoring) : no-op si NULL, jamais fatale.
  emit <- function(payload) {
    if (!is.null(progress_callback))
      tryCatch(progress_callback(payload), error = function(e) invisible(NULL))
  }
  if (!is.null(precomputed)) {
    return(.regen_attach_precomputed(units, precomputed, .REGEN_COLS_HYDRIQUE))
  }
  if (!requireNamespace("biljouR", quietly = TRUE)) {
    cli::cli_abort(c(
      "regen_bilan_hydrique() needs the {.pkg biljouR} package for the engine path.",
      i = "Install it with {.code remotes::install_github(\"pobsteta/biljouR\")}, or pass a precomputed BILJOU output via {.arg precomputed}."
    ))
  }
  if (is.null(meteo) || is.null(sol)) {
    cli::cli_abort(c(
      "regen_bilan_hydrique() engine path needs {.arg meteo} and {.arg sol}.",
      i = "Build {.arg meteo} via {.code biljouR::safran_to_meteo()}, {.arg sol} via {.code biljouR::biljou_soil()}; or pass a {.arg precomputed} result."))
  }

  # Type de peuplement -> valeurs BILJOU (broadleaved/coniferous).
  ft <- unname(c(feuillu = "broadleaved", broadleaved = "broadleaved",
                 resineux = "coniferous", coniferous = "coniferous")[tolower(forest_type)])
  if (is.na(ft)) {
    cli::cli_abort("{.arg forest_type} must be feuillu/broadleaved or resineux/coniferous.")
  }

  # lai_max NULL/NA : replier sur un défaut par type de peuplement (proxy NDP 0)
  # plutôt que d'échouer. Cas RECONFORT : LiDAR présent mais microclimf sauté
  # faute de clé CDS, et repli LAI satellite non déclenché (grid non nul) ->
  # sans ce garde-fou, BILJOU ne tournait pas et la carte restait vide. L'app
  # doit privilégier une valeur pilotée par la donnée (PAI LiDAR / LAI S2).
  if (is.null(lai_max) || (length(lai_max) == 1 && is.na(lai_max))) {
    lai_max <- if (identical(ft, "coniferous")) 4.5 else 5
    cli::cli_warn(c(
      "regen_bilan_hydrique(): no {.arg lai_max} supplied; using a stand-type default ({.val {lai_max}}).",
      i = "Provide a LiDAR-derived PAI ({.code pai_depuis_nuage()}) or Sentinel-2/PROSAIL LAI ({.code lai_sentinel2()}) for a data-driven value."))
  }

  # Points = centroïdes des unités (id séquentiel, lon/lat WGS84). Même
  # construction que load_biljou_forcing() -> les ids de la liste `meteo`
  # par unité s'y alignent.
  points <- .biljou_points(units)
  emit(list(current = "regen_biljou:start", n = nrow(points)))

  grid <- biljouR::biljou_run_grid(
    points = points, meteo = meteo, soil = sol, lai_max = lai_max,
    forest_type = ft, years = years,
    indicators = c("NJstress", "Istress", "DEBstress", "min_rew"),
    id_col = "id", lon_col = "lon", lat_col = "lat", ...)
  emit(list(current = "regen_biljou:complete"))

  # Moyenne inter-annuelle par unité, remise dans l'ordre des unités.
  map_col <- function(ind) {
    sel <- grid$indicator == ind
    if (!any(sel)) return(rep(NA_real_, nrow(units)))
    m <- tapply(grid$value[sel], grid$id[sel], mean, na.rm = TRUE)
    as.numeric(m[as.character(points$id)])
  }
  units$njstress   <- map_col("NJstress")
  units$istress    <- map_col("Istress")
  units$deb_stress <- map_col("DEBstress")
  units$rew_min    <- map_col("min_rew")
  units
}


# --- Helpers moteur exposition (microclimf) — portage fidèle du prototype
# /Documents/reGénération/microclimat_parcelles_robuste.R. Non testables en CI
# (LiDAR HD + microclimf + ERA5/CDS requis) ; validés par Pascal sur données
# réelles. Le chemin `precomputed` de regen_sensibilite() reste pur et testé.

# microclimf 2.x : runpointmodel() référence les datasets `soilparameters` /
# `soilparamsp` mais ne les charge pas lui-même (namespace verrouillé, pas de
# lazy-load interne) → `object 'soilparameters' not found`. La résolution de nom
# d'un appel microclimf remonte jusqu'au globalenv : on les y expose (idempotent)
# le temps du run. Retourne les noms RÉELLEMENT ajoutés, à retirer par l'appelant
# (on.exit) pour ne pas polluer durablement l'environnement global.
.rsen_ensure_soildata <- function() {
  genv <- globalenv()
  added <- character(0)
  for (ds in c("soilparameters", "soilparamsp")) {
    if (!exists(ds, envir = genv, inherits = FALSE)) {
      ok <- tryCatch({
        utils::data(list = ds, package = "microclimf", envir = genv); TRUE
      }, error = function(e) FALSE)
      if (ok) added <- c(added, ds)
    }
  }
  added
}

# VPD (kPa) depuis T°C et HR%.
.rsen_vpd <- function(Tc, RH) {
  es <- 0.6108 * exp(17.27 * Tc / (Tc + 237.3)); es * (1 - RH / 100)
}

# MNT/MNH : SpatRaster direct, ou dossier de dalles .tif (VRT + crop emprise).
.rsen_load_raster <- function(x, emprise, what) {
  if (inherits(x, "SpatRaster")) return(terra::crop(x, emprise))
  fich <- list.files(x, pattern = "\\.tif$", full.names = TRUE, ignore.case = TRUE)
  if (!length(fich)) cli::cli_abort("No .tif tiles for {what} in {.path {x}}.")
  terra::crop(terra::vrt(fich), emprise)
}

# Réduit une couche microclimf hétérogène à une grille constante = sa moyenne.
# Reconvertit une sortie microclimf (array nu nrow×ncol×ntime, ou déjà
# SpatRaster) en SpatRaster géo-référencé sur le gabarit `ref` (dtm). Réplique
# microclimf:::.rast (rast + ext + crs) tout en restant compatible avec les
# versions qui renvoient directement un SpatRaster.
.rsen_as_rast <- function(a, ref) {
  if (inherits(a, "SpatRaster")) return(a)
  r <- terra::rast(a)
  terra::ext(r) <- terra::ext(ref)
  terra::crs(r) <- terra::crs(ref)
  r
}

.rsen_vers_grille <- function(x, g) {
  # microclimf >= récent stocke vegp/soilc en PackedSpatRaster (sérialisable) :
  # dépaqueter avant de conformer à la grille, sinon dims != dtm (checkinputs KO).
  if (inherits(x, "PackedSpatRaster")) x <- terra::unwrap(x)
  if (inherits(x, "SpatRaster")) {
    # valeur représentative scalaire (moyenne toutes cellules/couches), conformée
    # à la grille : robuste aux composants multi-couches (mensuels).
    m <- mean(unlist(terra::global(x, "mean", na.rm = TRUE)), na.rm = TRUE)
    r <- g; terra::values(r) <- m; r
  } else x
}

# Retry + back-off autour d'une requête ERA5 : absorbe un throttle / une coupure
# réseau CDS transitoire (mcera5 ne relance pas toujours un `curl_fetch_memory`
# non-429). `do_request` est un thunk (testable sans mcera5). base_wait = 0 en
# test pour ne pas dormir.
.rsen_era5_with_retry <- function(do_request, max_tries = 3L, base_wait = 15) {
  last_err <- NULL
  for (attempt in seq_len(max_tries)) {
    ok <- tryCatch({ do_request(); TRUE },
                   error = function(e) { last_err <<- e; FALSE })
    if (isTRUE(ok)) return(invisible(TRUE))
    if (attempt < max_tries) Sys.sleep(min(90, base_wait * attempt))
  }
  stop(last_err)
}

# Fichier ERA5 combiné (mensuels fusionnés par mcera5) pour une année, ou NA.
# mcera5 nomme le combiné `<outfile>_<annee>.nc` et les mensuels
# `<outfile>_<annee>_<mois>.nc` : le combiné se termine donc par `_<annee>.nc`.
# On le repère par CE suffixe (robuste au préfixe `outfile`) : avec
# `outfile_name = "era5_<annee>"`, mcera5 écrit `era5_<annee>_<annee>.nc`
# (double année) — que l'ancien lookup `era5_<annee>.nc` ne trouvait jamais, d'où
# un re-téléchargement des 24 mois à chaque run malgré le cache.
.rsen_era5_combined <- function(cache_dir, annee) {
  hit <- list.files(cache_dir, pattern = sprintf("_%d\\.nc$", annee),
                    full.names = TRUE)
  if (length(hit)) hit[[1]] else NA_character_
}

# Fichier ERA5 à LIRE pour une année (entrée d'extract_clim) : le combiné s'il
# existe, sinon repli défensif = le nom le PLUS COURT parmi les `era5_<annee>*.nc`
# (le combiné `era5_<annee>_<annee>.nc` est plus court que les mensuels
# `era5_<annee>_<annee>_<mois>.nc`). `nchar()` est INDÉPENDANT de la locale,
# contrairement à `sort()`/`[1]` : selon la locale (FR notamment), le combiné ne
# trie PAS forcément avant les mensuels ('.' vs '_'), donc `[1]` pouvait piocher
# un mensuel (1 mois au lieu de 12). Renvoie NA si rien.
.rsen_era5_src <- function(cache_dir, annee) {
  comb <- .rsen_era5_combined(cache_dir, annee)
  if (!is.na(comb)) return(comb)
  cands <- list.files(cache_dir, pattern = sprintf("^era5_%d.*\\.nc$", annee),
                      full.names = TRUE)
  if (!length(cands)) return(NA_character_)
  cands[order(nchar(basename(cands)), basename(cands))][1]
}

# Forçage ERA5 pour une année (téléchargement mcera5 mis en cache).
.rsen_forcage_era5 <- function(lon, lat, annee, cache_dir) {
  if (!dir.exists(cache_dir)) dir.create(cache_dir, recursive = TRUE)
  combined <- .rsen_era5_combined(cache_dir, annee)   # NA si aucun combiné en cache
  st  <- as.POSIXct(sprintf("%d-01-01 00:00", annee), tz = "UTC")
  en  <- as.POSIXct(sprintf("%d-12-31 23:00", annee), tz = "UTC")
  if (is.na(combined)) {
    if (!requireNamespace("mcera5", quietly = TRUE)) {
      cli::cli_abort(c(
        "regen_sensibilite() engine needs {.pkg mcera5} to fetch ERA5 forcing.",
        i = "Install mcera5 (+ CDS key, and accept the ERA5 licence on the CDS site), or pre-populate {.path {cache_dir}}."))
    }
    # mcera5 >= 0.4 : build_era5_request() construit, request_era5() exécute.
    # by_month = TRUE : 12 requêtes MENSUELLES que mcera5 fusionne (combine=TRUE)
    # en un `era5_<annee>.nc`. Chaque mensuel (~9 000 champs) reste SOUS la limite
    # de coût par requête du nouveau CDS. Une requête ANNUELLE (by_month=FALSE,
    # ~105 000 champs) est rejetée `403 cost limits exceeded / request too large`
    # → aucun run microclimf n'aboutissait depuis la bascule v0.143.0. Le retry/
    # back-off (.rsen_era5_with_retry) absorbe le throttle des appels mensuels.
    req <- mcera5::build_era5_request(
      xmin = lon - 0.05, xmax = lon + 0.05, ymin = lat - 0.05, ymax = lat + 0.05,
      start_time = st, end_time = en, by_month = TRUE,
      outfile_name = sprintf("era5_%d", annee))
    .rsen_era5_with_retry(function() mcera5::request_era5(req, out_path = cache_dir))
  }
  # Combiné si trouvé, sinon repli défensif (nom le plus court = le combiné,
  # indépendant de la locale — cf. .rsen_era5_src).
  src <- .rsen_era5_src(cache_dir, annee)
  # format "microclimf" -> colonnes prêtes (obs_time/temp/relhum/pres/swdown/
  # difrad/lwdown/windspeed/winddir/precip), précip incluse, pression en kPa.
  mcera5::extract_clim(src, long = lon, lat = lat,
                       start_time = st, end_time = en, format = "microclimf")
}

# Une année -> rasters d'été (T°max sous couvert, VPD moyen), mis en cache tif.
.rsen_traiter_annee <- function(annee, lon, lat, dtm, veg, soil,
                                reqhgt, mois_ete, cache_dir) {
  ft <- file.path(cache_dir, sprintf("cache_%d_tmax.tif", annee))
  fv <- file.path(cache_dir, sprintf("cache_%d_vpd.tif", annee))
  if (file.exists(ft) && file.exists(fv))
    return(list(tmax = terra::rast(ft), vpd = terra::rast(fv)))
  meteo <- .rsen_forcage_era5(lon, lat, annee, cache_dir)
  microclimf::checkinputs(meteo, veg, soil, dtm)
  mp  <- microclimf::runpointmodel(meteo, reqhgt, dtm, veg, soil)
  mp  <- microclimf::subsetpointmodel(mp, tstep = "month", what = "tmax")
  # Horodatage des pas retenus. microclimf 2.x ne peuple plus `out$tme` (renvoyé
  # VIDE) et ne pose pas `terra::time()` sur la sortie → la seule source fiable
  # des mois est le modèle ponctuel sous-échantillonné : `mp$weather$obs_time`
  # (une journée/mois × 24 h = `nlyr` pas, alignés 1:1 aux couches de `out$Tz`).
  # NB : l'ancien garde `!is.null(terra::time(Tz))` était cassé — `time()` renvoie
  # des NA (pas NULL) → `format(NA, "%m")` prenait "%m" pour l'argument `trim`
  # → « invalid 'trim' argument ».
  tme <- tryCatch(as.POSIXct(mp$weather$obs_time), error = function(e) NULL)
  out <- microclimf::runmicro(mp, reqhgt, veg, soil, dtm)
  # microclimf >= récent renvoie Tz/relhum en array nu (nrow,ncol,ntime) : les
  # reconvertir en SpatRaster géo-référencé (même convention que microclimf:::.rast).
  Tz <- .rsen_as_rast(out$Tz, dtm)
  RH <- .rsen_as_rast(out$relhum, dtm)
  mois <- if (!is.null(tme) && length(tme) == terra::nlyr(Tz))
            as.integer(format(tme, "%m")) else seq_len(terra::nlyr(Tz))
  sel <- which(mois %in% mois_ete); if (!length(sel)) sel <- seq_len(terra::nlyr(Tz))
  # Réduction CELLULE-À-CELLULE sur les couches d'été via `terra::app` : `max()` /
  # `mean()` nus sur un SpatRaster peuvent renvoyer un scalaire global (selon la
  # version de terra) → `writeRaster` échouait sur un "numeric". `tmax` = pic
  # estival de T° sous couvert ; `vpd` = VPD moyen estival.
  tmax <- terra::app(Tz[[sel]], fun = "max", na.rm = TRUE)
  vpd  <- terra::app(.rsen_vpd(Tz[[sel]], RH[[sel]]), fun = "mean", na.rm = TRUE)
  terra::writeRaster(tmax, ft, overwrite = TRUE)
  terra::writeRaster(vpd,  fv, overwrite = TRUE)
  list(tmax = tmax, vpd = vpd)
}

# Moyenne (et écart-type interannuel) d'une catégorie d'années. `emit`/`category`
# publient un événement `regen_expo:era5` par année (progression fine ntfy).
.rsen_moyenne_categorie <- function(annees, ..., emit = NULL, category = NA) {
  dots <- list(...)
  n    <- length(annees)
  res  <- lapply(seq_len(n), function(k) {
    if (!is.null(emit)) emit(list(current = "regen_expo:era5",
      category = category, year = annees[[k]], i = k, n = n))
    do.call(.rsen_traiter_annee, c(list(annees[[k]]), dots))
  })
  st_t <- terra::rast(lapply(res, `[[`, "tmax"))
  st_v <- terra::rast(lapply(res, `[[`, "vpd"))
  list(tmax_moy = terra::mean(st_t, na.rm = TRUE),
       vpd_moy  = terra::mean(st_v, na.rm = TRUE),
       tmax_sd  = if (length(annees) > 1) terra::app(st_t, stats::sd, na.rm = TRUE) else NULL,
       vpd_sd   = if (length(annees) > 1) terra::app(st_v, stats::sd, na.rm = TRUE) else NULL,
       n = length(annees))
}


#' Microclimate exposure per unit — microclimf engine (spec 027 L1)
#'
#' @description
#' Per-unit summer under-canopy exposure (T°max, VPD, canopy buffering,
#' heatwave-vs-average sensitivity, robustness) from the mechanistic
#' **microclimf** model driven by LiDAR-HD structure and ERA5-Land forcing.
#' Produces the §7 exposure columns consumed by [indice_priorite_regen()].
#'
#' **Two paths.** *Fast-path*: pass `precomputed` (the per-unit output of a
#' microclimf run — e.g. the prototype `microclimat_parcelles_robuste.R`) and the
#' metrics are attached as §7 columns without the GPL engine; missing
#' `d_tmax`/`d_vpd` are derived from `tmax_canicule - tmax_moyenne` /
#' `vpd_canicule - vpd_moyenne`, and `rang_sensibilite` from `sensibilite`
#' (1 = most sensitive). *Engine path* (portage of the prototype): builds the
#' fixed LiDAR-HD grid (DTM, canopy height, PAI via [pai_depuis_nuage()]), runs
#' **microclimf** per year forced by ERA5-Land (`mcera5`) with disk caching,
#' averages the *average* vs *heatwave* summers (canopy held fixed), and
#' aggregates ΔT°max / ΔVPD, a z-score `sensibilite`, and a signal/noise
#' `robustesse` per unit. The engine path needs LiDAR HD + ERA5/CDS and is
#' **not runnable in CI** — validated on real data.
#'
#' @param units An `sf` of UGF.
#' @param mnt,mnh Optional LiDAR-HD DTM / canopy-height inputs for the engine
#'   path: a `terra::SpatRaster`, or a directory of `.tif` tiles (VRT-mosaicked).
#' @param las Optional directory of classified LiDAR `.las`/`.laz` tiles (PAI via
#'   [pai_depuis_nuage()]).
#' @param annees_moy,annees_canic Integer years for the average / heatwave
#'   summers (engine path). See [microclimate_detect_years()].
#' @param mois_ete Integer months of the summer window (default `6:8`).
#' @param res Target grid resolution in metres (default `2`).
#' @param tampon Buffer in metres around the units for the working extent
#'   (default `150`).
#' @param reqhgt Height (m) above ground for the microclimate (default `0.5`).
#' @param k Beer-Lambert extinction coefficient for PAI (default `0.5`).
#' @param pai Optional canopy `SpatRaster` to use instead of the LiDAR PAI. The
#'   NDP-0 fallback: a Sentinel-2/PROSAIL LAI from [lai_sentinel2()] (degraded
#'   proxy — LAI ≠ structural PAI). When supplied, `las` is not required.
#' @param pai_cache Optional path to a GeoTIFF caching the LiDAR-derived PAI. The
#'   PAI depends only on the point cloud and the working grid (invariant for a
#'   given project / AOI / `res`), yet [pai_depuis_nuage()] is the slowest step
#'   before ERA5. When the file exists **and** its geometry matches the working
#'   grid it is read back (no recompute); otherwise the PAI is computed and
#'   written there. A geometry mismatch (AOI / `res` changed) invalidates it
#'   (recompute + overwrite). Ignored when `pai` is supplied. `NULL` (default)
#'   disables caching — the v0.144.x behaviour.
#' @param pai_ncores Tile-level parallelism for the LiDAR PAI build, forwarded to
#'   [pai_depuis_nuage()] (`ncores`): `NULL` (default) uses `lasR::half_cores()`,
#'   an integer sets the number of tiles processed at once, `1`/`FALSE` forces
#'   sequential. Trades RAM for wall-time; the PAI is identical either way.
#' @param cache_dir Directory for the ERA5 `.nc` and per-year microclimate `.tif`
#'   caches. `NULL` (default) uses a session temp dir; pass a persistent path to
#'   reuse expensive runs.
#' @param progress_callback Optional function called at each step with a
#'   `list(current = <key>, …)` payload (monitoring pattern). Keys:
#'   `"regen_expo:pai"` (`source` = `"lidar"`/`"cache"`/`"raster"`, once, when the
#'   vegetation-structure PAI is built/read), `"regen_expo:microclimf"` (`category`),
#'   `"regen_expo:era5"` (`category`/`year`/`i`/`n`, once per reference year) and
#'   `"regen_expo:complete"`. No-op when `NULL`; never fatal. The monthly ERA5
#'   split is internal to `mcera5`.
#' @param precomputed Optional per-unit microclimf output (`data.frame`/list).
#' @param ... Reserved (engine parameters).
#'
#' @return `units` with the §7 exposure columns (`tmax_moyenne`,
#'   `tmax_canicule`, `vpd_moyenne`, `vpd_canicule`, `d_tmax`, `d_vpd`,
#'   `sensibilite`, `rang_sensibilite`, `robustesse`, `signal_robuste`,
#'   `couverture_pct`), plus `parcelle_sensible` / `priorite`.
#' @seealso [indice_priorite_regen()], [microclimate_detect_years()],
#'   [pai_depuis_nuage()]
#' @export
regen_sensibilite <- function(units, mnt = NULL, mnh = NULL, las = NULL,
                              annees_moy = NULL, annees_canic = NULL,
                              mois_ete = 6:8, res = 2, tampon = 150,
                              reqhgt = 0.5, k = 0.5, pai = NULL, pai_cache = NULL,
                              pai_ncores = NULL, cache_dir = NULL,
                              progress_callback = NULL, precomputed = NULL, ...) {
  validate_sf(units)
  # Progression (patron monitoring) : émission no-op si NULL, jamais fatale.
  emit <- function(payload) {
    if (!is.null(progress_callback))
      tryCatch(progress_callback(payload), error = function(e) invisible(NULL))
  }
  if (!is.null(precomputed)) {
    units <- .regen_attach_precomputed(units, precomputed, .REGEN_COLS_EXPO)
    if (all(c("tmax_moyenne", "tmax_canicule") %in% names(units)) &&
        !"d_tmax" %in% names(units)) {
      units$d_tmax <- units$tmax_canicule - units$tmax_moyenne
    }
    if (all(c("vpd_moyenne", "vpd_canicule") %in% names(units)) &&
        !"d_vpd" %in% names(units)) {
      units$d_vpd <- units$vpd_canicule - units$vpd_moyenne
    }
    if ("sensibilite" %in% names(units) && !"rang_sensibilite" %in% names(units)) {
      units$rang_sensibilite <- rank(-units$sensibilite, ties.method = "min")
    }
    return(units)
  }

  # --- Engine path : orchestration microclimf (portage prototype) ---
  if (!requireNamespace("terra", quietly = TRUE) ||
      !requireNamespace("microclimf", quietly = TRUE)) {
    cli::cli_abort(c(
      "regen_sensibilite() needs {.pkg microclimf} (and {.pkg terra}) for the engine path.",
      i = "Install them, or pass a precomputed microclimf output via {.arg precomputed}."))
  }
  if (is.null(mnt) || is.null(mnh) || (is.null(las) && is.null(pai)) ||
      is.null(annees_moy) || is.null(annees_canic)) {
    cli::cli_abort(c(
      "regen_sensibilite() engine path needs {.arg mnt}, {.arg mnh}, {.arg annees_moy}, {.arg annees_canic}, and either {.arg las} (LiDAR HD) or {.arg pai} (S2/PROSAIL LAI fallback, spec 033).",
      i = "Or pass a precomputed per-unit result via {.arg precomputed}."))
  }
  if (is.null(cache_dir)) cache_dir <- tempfile("regen_micro_")
  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)

  # 1. Unités en CRS de travail (LiDAR HD = EPSG:2154), emprise tamponnée.
  parc    <- terra::vect(sf::st_transform(units, 2154))
  emprise <- terra::ext(terra::buffer(parc, tampon))

  # Grille STATIQUE (une fois) : DTM, hauteur de canopée, PAI.
  mnt_r <- .rsen_load_raster(mnt, emprise, "MNT")
  mnh_r <- .rsen_load_raster(mnh, emprise, "MNH")
  f <- max(1, round(res / terra::res(mnt_r)[1]))
  if (f > 1) {
    mnt_r <- terra::aggregate(mnt_r, f, fun = "mean", na.rm = TRUE)
    mnh_r <- terra::aggregate(mnh_r, f, fun = "mean", na.rm = TRUE)
  }
  mnh_r <- terra::resample(mnh_r, mnt_r)
  dtm <- mnt_r; names(dtm) <- "dtm"
  hgt <- terra::clamp(mnh_r, 0, Inf); names(hgt) <- "hgt"

  # Structure de végétation (PAI), trois provenances par priorité :
  #  1. `pai` fourni explicitement (repli LAI Sentinel-2/PROSAIL, spec 033 —
  #     proxy dégradé, LAI ≠ PAI structural), rééchantillonné sur la grille ;
  #  2. `pai_cache` présent ET géométrie == grille -> relu du disque : le PAI ne
  #     dépend que du nuage + grille (invariants pour un projet/AOI/res), inutile
  #     de repayer le poste le plus long avant ERA5. Une géométrie différente
  #     (AOI/res changés) invalide le cache -> recalcul + réécriture ;
  #  3. sinon dérivé du nuage LiDAR (pai_depuis_nuage) puis écrit dans `pai_cache`.
  # La phase est annoncée (source lidar/cache/raster) pour l'affichage app.
  pai_hit <- !is.null(pai_cache) && file.exists(pai_cache) &&
    isTRUE(tryCatch(terra::compareGeom(terra::rast(pai_cache), dtm,
                                       stopOnError = FALSE),
                    error = function(e) FALSE))
  pai_source <- if (!is.null(pai)) "raster" else if (pai_hit) "cache" else "lidar"
  emit(list(current = "regen_expo:pai", source = pai_source))

  pai <- if (!is.null(pai)) {
    if (!inherits(pai, "SpatRaster")) cli::cli_abort("{.arg pai} must be a terra SpatRaster (LAI/PAI fallback).")
    terra::resample(pai[[1]], dtm)
  } else if (pai_hit) {
    terra::rast(pai_cache)                       # cache hit : PAI relu, grille alignée
  } else {
    p <- pai_depuis_nuage(las, dtm, res = res, k = k, ncores = pai_ncores)
    if (!is.null(pai_cache)) {
      dir.create(dirname(pai_cache), showWarnings = FALSE, recursive = TRUE)
      tryCatch(terra::writeRaster(p, pai_cache, overwrite = TRUE),
               error = function(e) cli::cli_warn(
                 "regen_sensibilite(): PAI cache not written to {.path {pai_cache}}."))
    }
    p
  }
  names(pai) <- "pai"

  # Végétation / sol microclimf, ramenés à la grille ; hgt/pai injectés.
  e <- new.env()
  utils::data("vegp", package = "microclimf", envir = e)
  utils::data("soilc", package = "microclimf", envir = e)
  veg <- e$vegp
  for (nm in names(veg)) if (!nm %in% c("hgt", "pai")) veg[[nm]] <- .rsen_vers_grille(veg[[nm]], dtm)
  veg$hgt <- hgt; veg$pai <- pai
  soil <- e$soilc
  for (nm in names(soil)) soil[[nm]] <- .rsen_vers_grille(soil[[nm]], dtm)

  # microclimf 2.x exige `soilparameters`/`soilparamsp` en portée (cf. helper) ;
  # exposés le temps du run puis retirés.
  .soildata_added <- .rsen_ensure_soildata()
  if (length(.soildata_added)) {
    on.exit(suppressWarnings(rm(list = .soildata_added, envir = globalenv())),
            add = TRUE)
  }

  ll  <- terra::geom(terra::centroids(terra::project(parc, "EPSG:4326")))
  lon <- mean(ll[, "x"]); lat <- mean(ll[, "y"])

  # 2. microclimat par catégorie (moyenne des étés moyens vs canicule).
  emit(list(current = "regen_expo:microclimf", category = "moyenne"))
  M <- .rsen_moyenne_categorie(annees_moy, lon = lon, lat = lat, dtm = dtm,
         veg = veg, soil = soil, reqhgt = reqhgt, mois_ete = mois_ete,
         cache_dir = cache_dir, emit = emit, category = "moyenne")
  emit(list(current = "regen_expo:microclimf", category = "canicule"))
  C <- .rsen_moyenne_categorie(annees_canic, lon = lon, lat = lat, dtm = dtm,
         veg = veg, soil = soil, reqhgt = reqhgt, mois_ete = mois_ete,
         cache_dir = cache_dir, emit = emit, category = "canicule")

  # 3. Écarts et robustesse signal/bruit (si >= 2 années par catégorie).
  d_tmax <- C$tmax_moy - M$tmax_moy
  d_vpd  <- C$vpd_moy  - M$vpd_moy
  robustesse <- NULL
  if (!is.null(M$tmax_sd) && !is.null(C$tmax_sd)) {
    sdp_t <- sqrt(M$tmax_sd^2 + C$tmax_sd^2)
    sdp_v <- sqrt(M$vpd_sd^2  + C$vpd_sd^2)
    robustesse <- (abs(d_tmax) / (sdp_t + 1e-6) + abs(d_vpd) / (sdp_v + 1e-6)) / 2
  }

  # 4. Agrégation par unité + indices. Moyennes pondérées par le RECOUVREMENT
  # cellule/polygone (exactextractr, cohérent avec .micro_extract des
  # indicateurs A3/A4/W4) ; `couverture_pct` = fraction exacte non-NA sur l'UGF.
  moyp <- function(r) .micro_extract(units, r)$mean
  # z-score inter-UGF ; robuste au cas dégénéré (1 seule UGF -> sd = NA ; delta
  # parfaitement uniforme -> sd = 0) : pas de signal relatif -> 0 plutôt que NaN.
  z    <- function(x) {
    s <- stats::sd(x, na.rm = TRUE)
    if (is.na(s) || s == 0) return(rep(0, length(x)))
    (x - mean(x, na.rm = TRUE)) / s
  }

  ex_ref <- .micro_extract(units, M$tmax_moy)
  units$tmax_moyenne  <- round(ex_ref$mean, 2)
  units$tmax_canicule <- round(moyp(C$tmax_moy), 2)
  units$vpd_moyenne   <- round(moyp(M$vpd_moy), 3)
  units$vpd_canicule  <- round(moyp(C$vpd_moy), 3)
  units$d_tmax <- round(moyp(d_tmax), 2)
  units$d_vpd  <- round(moyp(d_vpd), 3)
  units$couverture_pct <- round(100 * ex_ref$cover, 0)

  units$sensibilite      <- round(z(units$d_tmax) + z(units$d_vpd), 2)
  units$rang_sensibilite <- rank(-units$sensibilite, na.last = "keep", ties.method = "min")
  seuil <- stats::quantile(units$sensibilite, 2 / 3, na.rm = TRUE)
  units$parcelle_sensible <- units$sensibilite >= seuil

  if (!is.null(robustesse)) {
    units$robustesse     <- round(moyp(robustesse), 2)
    units$signal_robuste <- units$robustesse >= 1
    units$priorite       <- units$parcelle_sensible & units$signal_robuste
  } else {
    units$robustesse     <- NA_real_
    units$signal_robuste <- NA
    units$priorite       <- units$parcelle_sensible
  }
  emit(list(current = "regen_expo:complete"))
  units
}


# Filtre spatial LASlib `-keep_xy` calé sur l'emprise d'une zone (SpatExtent /
# SpatRaster / SpatVector / sf), tamponnée de `margin` m. Passé au reader lasR
# pour ne lire que les points de l'AOI : sur des dalles COPC (indexées), lasR
# saute aussi les dalles hors emprise -> évite de lire tout le nuage.
.pai_keep_xy_filter <- function(zone, margin = 0) {
  e <- if (inherits(zone, "SpatExtent")) zone
       else if (inherits(zone, c("SpatRaster", "SpatVector"))) terra::ext(zone)
       else terra::ext(terra::vect(zone))
  v <- as.vector(e)   # named: xmin xmax ymin ymax
  sprintf("-keep_xy %.3f %.3f %.3f %.3f",
          v[["xmin"]] - margin, v[["ymin"]] - margin,
          v[["xmax"]] + margin, v[["ymax"]] + margin)
}

# Nombre de dalles à traiter en parallèle (lasR concurrent_files). Retourne un
# entier >= 2 (parallèle) ou NA (séquentiel / stratégie inchangée) :
#   NULL  -> auto = lasR::half_cores() (défaut bénéfique, sortie identique) ;
#   FALSE / <= 1 -> NA (séquentiel) ; entier N -> N.
# RAM totale (Go) — Linux /proc/meminfo, sinon NA.
.pai_total_ram_gb <- function() {
  mi <- tryCatch(readLines("/proc/meminfo", n = 1L), error = function(e) NA_character_)
  if (length(mi) != 1L || is.na(mi[1])) return(NA_real_)
  kb <- suppressWarnings(as.numeric(sub("\\D*([0-9]+).*", "\\1", mi[1])))  # MemTotal kB
  if (is.na(kb)) NA_real_ else kb / 1024^2
}

# Concurrence PAI par défaut BORNÉE MÉMOIRE. Les dalles COPC décompressées sont
# lourdes (~4 Go/dalle en pic) et `systemd-oomd` tue le scope à ~50 % de pression
# mémoire soutenue : `half_cores()` aveugle (4 sur 8 cœurs) a fait OOM un run réel
# sur 31 Go (incident 2026-07-08). On budgète ~6 Go/dalle concurrente sur 40 % de
# la RAM totale, borné par `hard_max` (= half_cores). RAM inconnue -> prudent (2).
.pai_mem_safe_ncores <- function(hard_max) {
  ram <- .pai_total_ram_gb()
  if (is.na(ram)) return(min(2L, hard_max))
  max(1L, min(as.integer(hard_max), as.integer(floor(0.40 * ram / 6))))
}

# Concurrence lasR effective pour le PAI :
#  - ncores = FALSE           -> séquentiel (NA = pas de stratégie parallèle) ;
#  - ncores = entier          -> tel quel (choix explicite de l'appelant) ;
#  - ncores = NULL (défaut)   -> override `options(nemeton.pai_ncores=)` /
#    env `NEMETON_PAI_NCORES`, sinon défaut borné mémoire ∩ half_cores.
# Renvoie NA_integer_ pour n<=1 (lasR reste séquentiel — 1 dalle à la fois).
.pai_parallel_ncores <- function(ncores) {
  if (isFALSE(ncores)) return(NA_integer_)
  if (is.null(ncores)) {
    ov <- getOption("nemeton.pai_ncores",
                    Sys.getenv("NEMETON_PAI_NCORES", unset = NA))
    n <- if (!is.na(ov)) suppressWarnings(as.integer(ov))
         else .pai_mem_safe_ncores(lasR::half_cores())
  } else {
    n <- suppressWarnings(as.integer(ncores))
  }
  if (length(n) != 1L || is.na(n) || n <= 1L) NA_integer_ else n
}

#' Plant Area Index from a LiDAR-HD point cloud (spec 027 L1)
#'
#' @description
#' Wall-to-wall **PAI** raster from a classified LiDAR-HD point cloud
#' (`.las`/`.laz`), via per-pixel gap fraction + Beer-Lambert:
#' `P_gap = N_ground / (N_ground + N_veg)` then `PAI = -(1/k) * ln(P_gap)`. The
#' PAI feeds the `lai_max` of [regen_bilan_hydrique()] and the canopy of
#' [regen_sensibilite()] (⚠️ PAI ≈ LAI only for a leaves-on acquisition, spec
#' 027 §9.3).
#'
#' The point-cloud path uses the **`lasR`** pipeline (single read, two
#' class-filtered rasterizations) and is resampled onto `grille` (the working
#' DTM). Heavy dependency in `Suggests`, guarded by `requireNamespace`. When
#' `precomputed` is a `SpatRaster` (or raster file path) it is returned as-is,
#' so the pipeline can run on a pre-built PAI without `lasR`.
#'
#' @param dossier_las Directory of classified `.las`/`.laz` tiles covering the
#'   parcels plus a buffer.
#' @param grille Target grid (`SpatRaster`, typically the working DTM) — the PAI
#'   is resampled onto it, and (when `parcelle` is `NULL`) its extent bounds the
#'   LiDAR read window (`-keep_xy`), so only tiles/points over the AOI are read.
#' @param res Numeric working resolution in metres (default 2).
#' @param k Beer-Lambert extinction coefficient (default 0.5).
#' @param parcelle Optional `SpatVector`/`sf`: bounds the LiDAR read window
#'   (`-keep_xy`, buffered) **and** masks the final raster. `NULL` uses
#'   `grille`'s extent for the read window and applies no final mask.
#' @param fenetre Optional smoothing window in metres (`NA` = none).
#' @param cl_sol,cl_veg ASPRS classes counted as ground / vegetation
#'   (defaults `2` and `c(3, 4, 5)`).
#' @param epsg CRS forced on the tiles when absent (LiDAR HD = `2154`).
#' @param pai_max Upper clamp on PAI (default 8).
#' @param ncores Tile-level parallelism for the `lasR` read (`concurrent_files`):
#'   `NULL` (default) picks a **memory-bounded** number of tiles (COPC tiles are
#'   heavy once decompressed and `systemd-oomd` kills at ~50% memory pressure, so
#'   the default budgets ~6 GB per concurrent tile over 40% of RAM, capped by
#'   `lasR::half_cores()`); an integer `N` processes exactly `N`; `1`/`FALSE`
#'   forces sequential. When `ncores` is `NULL`, `options(nemeton.pai_ncores=)`
#'   or the `NEMETON_PAI_NCORES` env var override the default (useful when the
#'   caller — e.g. the Shiny app — does not expose the knob). The PAI is identical
#'   whatever the value (per-cell counting is associative); more tiles trade RAM
#'   for wall-time. The global `lasR` strategy is saved and restored around the run.
#' @param precomputed Optional pre-built PAI `SpatRaster` or raster path.
#' @param ... Reserved.
#'
#' @return A `terra::SpatRaster` of PAI (layer `pai`).
#' @seealso [regen_bilan_hydrique()], [regen_sensibilite()]
#' @export
pai_depuis_nuage <- function(dossier_las = NULL, grille = NULL, res = 2,
                             k = 0.5, parcelle = NULL, fenetre = NA,
                             cl_sol = 2L, cl_veg = c(3L, 4L, 5L), epsg = 2154,
                             pai_max = 8, ncores = NULL, precomputed = NULL, ...) {
  if (!is.null(precomputed)) {
    if (inherits(precomputed, "SpatRaster")) return(precomputed)
    if (is.character(precomputed) && length(precomputed) == 1L &&
        file.exists(precomputed)) {
      return(terra::rast(precomputed))
    }
    stop("`precomputed` must be a SpatRaster or an existing raster file path",
         call. = FALSE)
  }
  if (is.null(dossier_las) || is.null(grille)) {
    cli::cli_abort(c(
      "pai_depuis_nuage() needs a LiDAR tile directory and a target grid.",
      i = "Provide {.arg dossier_las} + {.arg grille}, or a pre-built PAI via {.arg precomputed}."
    ))
  }
  if (!inherits(grille, "SpatRaster")) {
    stop("`grille` must be a terra SpatRaster", call. = FALSE)
  }
  if (!requireNamespace("lasR", quietly = TRUE)) {
    cli::cli_abort(c(
      "pai_depuis_nuage() needs the {.pkg lasR} package for the point-cloud path.",
      i = "Install it with {.code install.packages(\"lasR\", repos = \"https://r-lidar.r-universe.dev\")}, or pass a pre-built PAI via {.arg precomputed}."
    ))
  }

  dalles <- list.files(dossier_las, pattern = "\\.(las|laz)$",
                       full.names = TRUE, ignore.case = TRUE)
  if (!length(dalles)) {
    cli::cli_abort("No .las/.laz tiles found in {.path {dossier_las}}.")
  }

  # rasterize tamponnée si fenêtre fournie.
  res_arg <- if (is.na(fenetre)) res else c(res, fenetre)
  f_sol <- tempfile(fileext = ".tif")
  f_veg <- tempfile(fileext = ".tif")

  # Clip spatial de la lecture à l'emprise de travail (parcelle si fournie, sinon
  # la grille — déjà tamponnée à l'AOI par l'appelant), marge = quelques cellules
  # pour le rééchantillonnage bilinéaire des bords. Sur nuage COPC, lasR n'ouvre
  # que les dalles concernées : gros massif -> on ne lit plus tout le nuage.
  zone <- if (!is.null(parcelle)) parcelle else grille
  xy_filter <- .pai_keep_xy_filter(zone, margin = 3 * res)

  # Un seul passage de lecture, deux rastérisations filtrées par classe.
  # default_value = 0 : pixel couvert mais sans point de la classe -> 0 (pas NA),
  # indispensable sous canopée dense où N_sol peut être nul.
  pipe <- lasR::reader_las(filter = xy_filter) + lasR::set_crs(epsg) +
    lasR::rasterize(res_arg, "count", filter = lasR::keep_class(cl_sol),
                    default_value = 0, ofile = f_sol) +
    lasR::rasterize(res_arg, "count", filter = lasR::keep_class(cl_veg),
                    default_value = 0, ofile = f_veg)

  # Parallélisme lasR : traiter plusieurs dalles de front (concurrent_files) —
  # sortie strictement identique (le comptage par cellule est associatif), gain
  # ~linéaire en cœurs sur un massif multi-dalles. On sauvegarde/restaure la
  # stratégie globale pour ne pas fuiter d'état hors de la fonction.
  n_par <- .pai_parallel_ncores(ncores)
  if (!is.na(n_par)) {
    old_strat <- lasR::get_parallel_strategy()
    lasR::set_parallel_strategy(lasR::concurrent_files(n_par))
    on.exit(if (is.null(old_strat)) lasR::unset_parallel_strategy()
            else lasR::set_parallel_strategy(old_strat), add = TRUE)
  }
  lasR::exec(pipe, on = dalles, progress = TRUE)

  n_sol <- terra::rast(f_sol)
  n_veg <- terra::rast(f_veg)

  # Fraction de trouée puis Beer-Lambert.
  ntot  <- n_sol + n_veg
  p_gap <- n_sol / ntot
  p_gap <- terra::clamp(p_gap, 1e-3, 1 - 1e-3)          # évite log(0)
  pai   <- -(cos(0) / k) * log(p_gap)
  pai   <- terra::clamp(pai, 0, pai_max)
  pai[ntot == 0] <- NA                                  # hors couverture LiDAR
  names(pai) <- "pai"

  # Aligne sur la grille de travail puis masque éventuellement.
  pai <- terra::resample(pai, grille, method = "bilinear")
  if (!is.null(parcelle)) {
    pv <- if (inherits(parcelle, "SpatVector")) parcelle else terra::vect(parcelle)
    pai <- terra::mask(terra::crop(pai, pv), pv)
  }
  pai
}
