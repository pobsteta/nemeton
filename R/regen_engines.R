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
#' @param ... Passed to `biljouR::biljou_run()` (e.g. `budburst`, `leaf_fall`,
#'   `rew_c`, `k`).
#'
#' @return `units` with the water-balance columns `njstress`, `istress`,
#'   `rew_min`, `deb_stress` (per-unit mean over the retained years).
#' @seealso [indicateur_r3_secheresse()], [indice_priorite_regen()]
#' @export
regen_bilan_hydrique <- function(units, meteo = NULL, sol = NULL,
                                 lai_max = NULL, forest_type = "feuillu",
                                 years = NULL, precomputed = NULL, ...) {
  validate_sf(units)
  if (!is.null(precomputed)) {
    return(.regen_attach_precomputed(units, precomputed, .REGEN_COLS_HYDRIQUE))
  }
  if (!requireNamespace("biljouR", quietly = TRUE)) {
    cli::cli_abort(c(
      "regen_bilan_hydrique() needs the {.pkg biljouR} package for the engine path.",
      i = "Install it with {.code remotes::install_github(\"pobsteta/biljouR\")}, or pass a precomputed BILJOU output via {.arg precomputed}."
    ))
  }
  if (is.null(meteo) || is.null(sol) || is.null(lai_max)) {
    cli::cli_abort(c(
      "regen_bilan_hydrique() engine path needs {.arg meteo}, {.arg sol} and {.arg lai_max}.",
      i = "Build {.arg meteo} via {.fn biljouR::safran_to_meteo}, {.arg sol} via {.fn biljouR::biljou_soil}, {.arg lai_max} from {.fn pai_depuis_nuage}; or pass a {.arg precomputed} result."))
  }

  # Type de peuplement -> valeurs BILJOU (broadleaved/coniferous).
  ft <- unname(c(feuillu = "broadleaved", broadleaved = "broadleaved",
                 resineux = "coniferous", coniferous = "coniferous")[tolower(forest_type)])
  if (is.na(ft)) {
    cli::cli_abort("{.arg forest_type} must be feuillu/broadleaved or resineux/coniferous.")
  }

  # Points = centroïdes des unités (id séquentiel, lon/lat WGS84).
  cent <- sf::st_centroid(sf::st_geometry(units))
  ll   <- sf::st_coordinates(sf::st_transform(cent, 4326))
  points <- data.frame(id = seq_len(nrow(units)), lon = ll[, 1], lat = ll[, 2])

  grid <- biljouR::biljou_run_grid(
    points = points, meteo = meteo, soil = sol, lai_max = lai_max,
    forest_type = ft, years = years,
    indicators = c("NJstress", "Istress", "DEBstress", "min_rew"),
    id_col = "id", lon_col = "lon", lat_col = "lat", ...)

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
.rsen_vers_grille <- function(x, g) {
  if (inherits(x, "SpatRaster")) {
    r <- g; terra::values(r) <- as.numeric(terra::global(x, "mean", na.rm = TRUE)); r
  } else x
}

# Forçage ERA5-Land pour une année (téléchargement mcera5 mis en cache).
.rsen_forcage_era5 <- function(lon, lat, annee, cache_dir) {
  nc <- file.path(cache_dir, sprintf("era5_%d.nc", annee))
  if (!file.exists(nc)) {
    if (!requireNamespace("mcera5", quietly = TRUE)) {
      cli::cli_abort(c(
        "regen_sensibilite() engine needs {.pkg mcera5} to fetch ERA5 forcing.",
        i = "Install mcera5 (+ CDS credentials), or pre-populate {.path {cache_dir}}."))
    }
    req <- mcera5::request_era5(
      bbox = c(ymx = lat + 0.05, ymn = lat - 0.05, xmx = lon + 0.05, xmn = lon - 0.05),
      start_time = sprintf("%d-01-01", annee), end_time = sprintf("%d-12-31", annee),
      outfile_name = tools::file_path_sans_ext(basename(nc)))
    mcera5::request_era5(req, out_path = cache_dir)
  }
  clim <- mcera5::extract_clim(nc, long = lon, lat = lat,
            start_time = sprintf("%d-01-01", annee), end_time = sprintf("%d-12-31", annee))
  prec <- mcera5::extract_precip(nc, long = lon, lat = lat,
            start_time = sprintf("%d-01-01", annee), end_time = sprintf("%d-12-31", annee))
  data.frame(obs_time = clim$obs_time, temp = clim$temperature, relhum = clim$humidity,
             pres = clim$pressure, swdown = clim$rad_glbl,
             difrad = pmax(clim$rad_glbl - clim$rad_dni, 0), lwdown = clim$downlong,
             windspeed = clim$windspeed, winddir = clim$winddir, precip = prec)
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
  out <- microclimf::runmicro(mp, reqhgt, veg, soil, dtm)
  Tz  <- out$Tz
  mois <- if (!is.null(terra::time(Tz))) as.integer(format(terra::time(Tz), "%m"))
          else seq_len(terra::nlyr(Tz))
  sel <- which(mois %in% mois_ete); if (!length(sel)) sel <- seq_len(terra::nlyr(Tz))
  tmax <- max(Tz[[sel]], na.rm = TRUE)
  vpd  <- mean(.rsen_vpd(Tz[[sel]], out$relhum[[sel]]), na.rm = TRUE)
  terra::writeRaster(tmax, ft, overwrite = TRUE)
  terra::writeRaster(vpd,  fv, overwrite = TRUE)
  list(tmax = tmax, vpd = vpd)
}

# Moyenne (et écart-type interannuel) d'une catégorie d'années.
.rsen_moyenne_categorie <- function(annees, ...) {
  res  <- lapply(annees, .rsen_traiter_annee, ...)
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
#' @param cache_dir Directory for the ERA5 `.nc` and per-year microclimate `.tif`
#'   caches. `NULL` (default) uses a session temp dir; pass a persistent path to
#'   reuse expensive runs.
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
                              reqhgt = 0.5, k = 0.5, cache_dir = NULL,
                              precomputed = NULL, ...) {
  validate_sf(units)
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
  if (is.null(mnt) || is.null(mnh) || is.null(las) ||
      is.null(annees_moy) || is.null(annees_canic)) {
    cli::cli_abort(c(
      "regen_sensibilite() engine path needs {.arg mnt}, {.arg mnh}, {.arg las}, {.arg annees_moy} and {.arg annees_canic}.",
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
  pai <- pai_depuis_nuage(las, dtm, res = res, k = k)
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

  ll  <- terra::geom(terra::centroids(terra::project(parc, "EPSG:4326")))
  lon <- mean(ll[, "x"]); lat <- mean(ll[, "y"])

  # 2. microclimat par catégorie (moyenne des étés moyens vs canicule).
  M <- .rsen_moyenne_categorie(annees_moy, lon = lon, lat = lat, dtm = dtm,
         veg = veg, soil = soil, reqhgt = reqhgt, mois_ete = mois_ete,
         cache_dir = cache_dir)
  C <- .rsen_moyenne_categorie(annees_canic, lon = lon, lat = lat, dtm = dtm,
         veg = veg, soil = soil, reqhgt = reqhgt, mois_ete = mois_ete,
         cache_dir = cache_dir)

  # 3. Écarts et robustesse signal/bruit (si >= 2 années par catégorie).
  d_tmax <- C$tmax_moy - M$tmax_moy
  d_vpd  <- C$vpd_moy  - M$vpd_moy
  robustesse <- NULL
  if (!is.null(M$tmax_sd) && !is.null(C$tmax_sd)) {
    sdp_t <- sqrt(M$tmax_sd^2 + C$tmax_sd^2)
    sdp_v <- sqrt(M$vpd_sd^2  + C$vpd_sd^2)
    robustesse <- (abs(d_tmax) / (sdp_t + 1e-6) + abs(d_vpd) / (sdp_v + 1e-6)) / 2
  }

  # 4. Agrégation par unité + indices.
  moyp <- function(r) terra::extract(r, parc, fun = mean, na.rm = TRUE, ID = FALSE)[, 1]
  z    <- function(x) (x - mean(x, na.rm = TRUE)) / stats::sd(x, na.rm = TRUE)

  units$tmax_moyenne  <- round(moyp(M$tmax_moy), 2)
  units$tmax_canicule <- round(moyp(C$tmax_moy), 2)
  units$vpd_moyenne   <- round(moyp(M$vpd_moy), 3)
  units$vpd_canicule  <- round(moyp(C$vpd_moy), 3)
  units$d_tmax <- round(moyp(d_tmax), 2)
  units$d_vpd  <- round(moyp(d_vpd), 3)
  units$couverture_pct <- round(100 * moyp(!is.na(M$tmax_moy)), 0)

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
  units
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
#'   is resampled onto it.
#' @param res Numeric working resolution in metres (default 2).
#' @param k Beer-Lambert extinction coefficient (default 0.5).
#' @param parcelle Optional `SpatVector`/`sf` mask applied at the end.
#' @param fenetre Optional smoothing window in metres (`NA` = none).
#' @param cl_sol,cl_veg ASPRS classes counted as ground / vegetation
#'   (defaults `2` and `c(3, 4, 5)`).
#' @param epsg CRS forced on the tiles when absent (LiDAR HD = `2154`).
#' @param pai_max Upper clamp on PAI (default 8).
#' @param precomputed Optional pre-built PAI `SpatRaster` or raster path.
#' @param ... Reserved.
#'
#' @return A `terra::SpatRaster` of PAI (layer `pai`).
#' @seealso [regen_bilan_hydrique()], [regen_sensibilite()]
#' @export
pai_depuis_nuage <- function(dossier_las = NULL, grille = NULL, res = 2,
                             k = 0.5, parcelle = NULL, fenetre = NA,
                             cl_sol = 2L, cl_veg = c(3L, 4L, 5L), epsg = 2154,
                             pai_max = 8, precomputed = NULL, ...) {
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

  # Un seul passage de lecture, deux rastérisations filtrées par classe.
  # default_value = 0 : pixel couvert mais sans point de la classe -> 0 (pas NA),
  # indispensable sous canopée dense où N_sol peut être nul.
  pipe <- lasR::reader_las() + lasR::set_crs(epsg) +
    lasR::rasterize(res_arg, "count", filter = lasR::keep_class(cl_sol),
                    default_value = 0, ofile = f_sol) +
    lasR::rasterize(res_arg, "count", filter = lasR::keep_class(cl_veg),
                    default_value = 0, ofile = f_veg)
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
