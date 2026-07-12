# load_biljou.R — acquisition du forçage météo et du sol pour le bilan hydrique
# BILJOU (regen_bilan_hydrique, spec 027 L2 / §10.2). Patron load_theia_source :
# l'acquisition métier vit au cœur, l'app orchestre/cache.
# ------------------------------------------------------------------
# regen_bilan_hydrique(units, meteo=, sol=, lai_max=) exige :
#   - `meteo` : forçage journalier au format biljouR (date, doy, pet, rain),
#     partagé (data.frame) OU par unité (liste nommée par id) — biljou_run_grid
#     accepte les deux.
#   - `sol`   : un objet biljouR::biljou_soil() (réserve utile `ewm`, racines…).
# Ces deux loaders les produisent sans mettre de logique données dans l'app.

# Points d'extraction = centroïdes des unités, id séquentiel 1..n, lon/lat WGS84.
# MÊME construction que regen_bilan_hydrique() -> les clés de la liste `meteo`
# s'alignent sur les `points$id` du run.
.biljou_points <- function(units) {
  cent <- sf::st_centroid(sf::st_geometry(units))
  ll <- sf::st_coordinates(sf::st_transform(cent, 4326))
  data.frame(id = seq_len(nrow(units)), lon = ll[, 1], lat = ll[, 2])
}

# Service OGC API-EDR SAFRAN-ISBA (GéoSAS/INRAE, données Météo-France SIM
# quotidiennes, 1958->présent, sans authentification). Requête par point.
.BILJOU_SAFRAN_EDR <- "https://api.geosas.fr/edr/collections/safran-isba/position"

# Variables SAFRAN mappées par safran_to_meteo() (cols par défaut) : PET, pluie
# liquide/neige, + T/rayonnement/vent/humidité (utiles si compute_pet).
.BILJOU_SAFRAN_PARAMS <- c("ETP_Q", "PRELIQ_Q", "PRENEI_Q", "T_Q", "SSI_Q",
                           "FF_Q", "HU_Q")

# Variables SAFRAN pour le moteur meteoland (chantier microclimat P4). Ajoute les
# températures min/max journalières indispensables au gel tardif (R7) et au stress
# thermique. Noms EXACTS de la collection `safran-isba` (lus dans l'EDR, PAS
# présumés : `TINF_H_Q`/`TSUP_H_Q` = min/max des 24 T° horaires, pas `TINF_Q`).
.SAFRAN_METEOLAND_PARAMS <- c("T_Q", "TINF_H_Q", "TSUP_H_Q", "PRELIQ_Q",
                              "PRENEI_Q", "HU_Q", "FF_Q", "SSI_Q")

# URL de requête EDR position (chemin PUR, testable) : coords Lambert-93
# (EPSG:2154, CRS robuste de l'API — CRS84/4326 buggé en bêta), plage d'années,
# variables, sortie CSV.
.biljou_safran_edr_url <- function(x, y, years, params = .BILJOU_SAFRAN_PARAMS,
                                   base = .BILJOU_SAFRAN_EDR) {
  sprintf(paste0("%s?coords=POINT(%.1f%%20%.1f)&crs=EPSG:2154",
                 "&datetime=%d-01-01T00:00:00Z/%d-12-31T00:00:00Z",
                 "&parameter-name=%s&f=CSV"),
          base, x, y, min(years), max(years), paste(params, collapse = ","))
}

# Forçage SAFRAN par unité via l'EDR GéoSAS. Reprojette les centroïdes en L93,
# une requête CSV par point -> data.frame brut (colonne DATE ajoutée pour
# safran_to_meteo). Best-effort : liste nommée par id, éléments NULL si vide.
.biljou_forcing_safran <- function(points, years, emit = NULL,
                                   params = .BILJOU_SAFRAN_PARAMS) {
  if (is.null(emit)) emit <- function(payload) NULL
  xy <- sf::st_coordinates(sf::st_transform(
    sf::st_as_sf(points, coords = c("lon", "lat"), crs = 4326), 2154))
  n <- nrow(points)
  res <- lapply(seq_len(n), function(i) {
    emit(list(current = "biljou:safran_unit", i = i, n = n, id = points$id[i]))
    url <- .biljou_safran_edr_url(xy[i, 1], xy[i, 2], years, params = params)
    df <- tryCatch(utils::read.csv(url, check.names = FALSE),
                   error = function(e) NULL)
    if (is.null(df) || !nrow(df) || !"time" %in% names(df)) return(NULL)
    df$DATE <- as.Date(substr(df$time, 1, 10))
    df
  })
  stats::setNames(res, as.character(points$id))
}

# Restreint un meteo (ou une liste de meteo) aux années demandées.
.biljou_filter_years <- function(meteo, years) {
  if (is.null(years)) return(meteo)
  keep <- function(m) m[as.integer(format(as.Date(m$date), "%Y")) %in% years, , drop = FALSE]
  if (is.data.frame(meteo)) keep(meteo) else lapply(meteo, keep)
}

# Agrège un forçage ERA5 horaire (.rsen_forcage_era5) en journalier BILJOU +
# PET Penman. Best-effort ; unités : rad_glbl W/m² moyen -> MJ/m²/j (× 0.0864).
.biljou_era5_meteo <- function(hourly, lat, altitude) {
  day <- as.Date(hourly$obs_time)
  agg <- function(v, f) as.numeric(tapply(v, day, f))
  d <- data.frame(
    date  = as.Date(sort(unique(day))),
    tmean = agg(hourly$temp, mean),
    rg    = agg(hourly$swdown, mean) * 0.0864,
    wind  = agg(hourly$windspeed, mean),
    rh    = agg(hourly$relhum, mean),
    rain  = agg(hourly$precip, sum))
  d$doy <- as.integer(format(d$date, "%j"))
  pet <- biljouR::penman_pet(tmean = d$tmean, rg = d$rg, wind = d$wind,
                             rh = d$rh, doy = d$doy, latitude = lat,
                             altitude = altitude)
  data.frame(date = d$date, doy = d$doy, pet = pmax(as.numeric(pet), 0),
             rain = d$rain)
}

# Forçage ERA5-Land par unité (fallback). Réutilise .rsen_forcage_era5 (mcera5).
# Best-effort : NULL si mcera5/clé/réseau absent. Validé sur données réelles.
.biljou_forcing_era5 <- function(points, years, cache_dir, altitude = 0,
                                 emit = NULL) {
  if (is.null(emit)) emit <- function(payload) NULL
  if (!requireNamespace("mcera5", quietly = TRUE) || is.null(years)) return(NULL)
  n <- nrow(points)
  out <- lapply(seq_len(n), function(i) {
    p <- points[i, ]
    hourly <- do.call(rbind, lapply(years, function(y) {
      emit(list(current = "biljou:era5_download", i = i, n = n,
                id = p$id, year = y))
      .rsen_forcage_era5(p$lon, p$lat, y, cache_dir)
    }))
    .biljou_era5_meteo(hourly, lat = p$lat, altitude = altitude)
  })
  stats::setNames(out, as.character(points$id))
}

#' Acquire the BILJOU daily meteorological forcing for an AOI
#'
#' @description
#' Produce the `meteo` input of [regen_bilan_hydrique()] — a daily forcing at the
#' biljouR format (`date`, `doy`, `pet`, `rain`) — over `years` for `aoi`, from
#' SAFRAN (French primary) or ERA5-Land (fallback). SAFRAN is fetched from the
#' GéoSAS OGC API-EDR (`safran-isba`, Météo-France SIM daily, **no
#' authentication**) per unit centroid; ERA5-Land uses `mcera5` (needs a CDS key).
#' Acquisition lives in the core (rule #1); the app only orchestrates and caches
#' (pattern: [load_theia_source()], spec 027 §10.2).
#'
#' Returns a **named list of per-unit `meteo` data frames** (keyed by the same
#' sequential ids as `regen_bilan_hydrique()`'s grid points), directly consumable
#' by `biljou_run_grid()`; or a single `data.frame` when a shared `raw` series is
#' passed. Degrades to `NULL` when the source is unavailable (no `biljouR`, no CDS
#' key, network failure, AOI outside coverage) so the caller can fall back.
#'
#' @param aoi An `sf`/`sfc` of the management units (their centroids are sampled).
#' @param years Integer year(s) to fetch.
#' @param source `"safran"` (default, France, GéoSAS OGC API-EDR, no key) or
#'   `"era5"` (fallback, `mcera5`, needs a CDS key).
#' @param cache_dir Directory for the ERA5 downloads (default a tempdir).
#' @param raw Optional raw SAFRAN `data.frame` to convert instead of downloading
#'   (via [biljouR::safran_to_meteo()]) — the tested injection path.
#' @param points Optional pre-built `data.frame(id, lon, lat)` (defaults to the
#'   `aoi` centroids).
#' @param latitude,altitude Site latitude/altitude for PET when `raw`/ERA5 need a
#'   Penman estimate (`latitude` defaults to the AOI centroid).
#' @param compute_pet Passed to [biljouR::safran_to_meteo()] (SAFRAN provides
#'   `ETP_Q`, so the default `FALSE` is used unless a Penman estimate is wanted).
#' @param progress_callback Optional function called at each step with a
#'   `list(current = <key>, …)` payload (monitoring pattern). Keys:
#'   `"biljou:safran_unit"` (`i`/`n`/`id`), `"biljou:era5_download"`
#'   (`i`/`n`/`id`/`year`), `"biljou:complete"`, `"biljou:unavailable"`. The app
#'   maps these to bottom-right notifications during the forcing download.
#' @param ... Ignored (forward-compat).
#'
#' @return A per-unit named list of `meteo` data frames (or a single
#'   `data.frame`), or `NULL` on graceful degradation.
#' @export
load_biljou_forcing <- function(aoi, years, source = c("safran", "era5"),
                                cache_dir = NULL, raw = NULL, points = NULL,
                                latitude = NULL, altitude = 0,
                                compute_pet = FALSE, progress_callback = NULL,
                                ...) {
  # Progression par étapes (patron monitoring) : chaque unité/année publie un
  # payload list(current=…) que l'app affiche en notification. No-op si NULL.
  emit <- function(payload) {
    if (!is.null(progress_callback)) progress_callback(payload)
  }
  source <- match.arg(source)
  if (!requireNamespace("biljouR", quietly = TRUE) ||
      !requireNamespace("sf", quietly = TRUE)) {
    emit(list(current = "biljou:unavailable", reason = "deps"))
    return(NULL)
  }
  if (is.null(cache_dir)) cache_dir <- file.path(tempdir(), "biljou_forcing")
  if (is.null(points) && !is.null(aoi)) points <- .biljou_points(aoi)
  if (is.null(latitude) && !is.null(points)) latitude <- stats::median(points$lat)

  # Injection `raw` : conversion directe (chemin testé, série partagée).
  if (!is.null(raw)) {
    meteo <- tryCatch(
      biljouR::safran_to_meteo(raw, compute_pet = compute_pet,
                               latitude = latitude, altitude = altitude),
      error = function(e) NULL)
    emit(list(current = if (is.null(meteo)) "biljou:unavailable" else "biljou:complete",
              source = "raw"))
    return(.biljou_filter_years(meteo, years))
  }

  meteo <- tryCatch({
    if (source == "safran") {
      # Acquisition SAFRAN via l'OGC API-EDR GéoSAS (sans auth) -> data.frame
      # brut par unité -> safran_to_meteo() (ETP_Q fourni : pas de Penman).
      raws <- .biljou_forcing_safran(points, years, emit = emit)
      m <- lapply(raws, function(df) if (is.null(df)) NULL else
        biljouR::safran_to_meteo(df, compute_pet = compute_pet,
                                 latitude = latitude, altitude = altitude))
      m <- m[!vapply(m, is.null, logical(1))]
      if (!length(m)) NULL else m
    } else {
      .biljou_forcing_era5(points, years, cache_dir, altitude = altitude,
                           emit = emit)
    }
  }, error = function(e) NULL)
  if (is.null(meteo)) {
    emit(list(current = "biljou:unavailable", source = source))
    return(NULL)
  }
  emit(list(current = "biljou:complete", source = source,
            n_units = length(meteo)))
  .biljou_filter_years(meteo, years)
}

#' Build the BILJOU soil object(s) for management units
#'
#' @description
#' Produce the `sol` input of [regen_bilan_hydrique()] — one or several
#' [biljouR::biljou_soil()] objects (extractable water `ewm`, root fractions,
#' macro/micro porosity, initial fill).
#'
#' **Two modes.**
#' * `source = "uniform"` (default): a **single** shared soil, as in v0.146.x.
#'   `ewm` is then the reserve *per soil layer* (1 to 3 layers, per BILJOU) —
#'   **not** per unit.
#' * `source = "soilgrids"`: one **single-layer soil per unit**, its `ewm`
#'   derived from SoilGrids 250 m through the Saxton & Rawls pedotransfer
#'   function ([ewm_depuis_soilgrids()]). Returns a list named by unit id,
#'   which `biljou_run_grid()` indexes per point — this is what spatialises the
#'   water balance (spec 035).
#'
#' Falls back to the uniform soil, with a warning, when SoilGrids cannot be
#' reached. Units whose `ewm` is `NA` or non-positive get the `ewm` default,
#' since [biljouR::biljou_soil()] rejects non-positive reserves.
#'
#' @param units An `sf`/`sfc` of the management units. Required when
#'   `source = "soilgrids"`.
#' @param ewm Maximum extractable water (mm). Default `150`. Under
#'   `source = "uniform"` it is the reserve per soil layer (length 1-3); under
#'   `source = "soilgrids"` it is only the per-unit fallback value.
#' @param source `"uniform"` (default, shared soil) or `"soilgrids"` (per-unit
#'   soil from SoilGrids + pedotransfer).
#' @param rooting_depth_cm Rooting depth in cm passed to [ewm_depuis_soilgrids()]
#'   (default 100). Ignored under `source = "uniform"`.
#' @param country ISO country code for the datasource lookup. Default `"FR"`.
#' @param roots,macro,micro,init Passed to [biljouR::biljou_soil()] (root
#'   fractions, macro/micro porosity, initial fill fraction).
#' @param progress_callback Optional monitoring callback, forwarded to
#'   [ewm_depuis_soilgrids()].
#' @param ... Ignored (forward-compat).
#'
#' @return A `biljou_soil` object (uniform mode), a **named list** of
#'   `biljou_soil` objects keyed by unit id (SoilGrids mode), or `NULL` when
#'   `biljouR` is unavailable.
#' @seealso [ewm_depuis_soilgrids()], [regen_bilan_hydrique()]
#' @export
build_biljou_soil <- function(units = NULL, ewm = 150,
                              source = c("uniform", "soilgrids"),
                              rooting_depth_cm = 100, country = "FR",
                              roots = NULL, macro = NULL, micro = NULL,
                              init = 1, progress_callback = NULL, ...) {
  source <- match.arg(source)
  if (!requireNamespace("biljouR", quietly = TRUE)) return(NULL)
  # ewm NULL/NA (ex. champ UI vidé -> na_null) : retomber sur le défaut plutôt
  # que de propager NULL à biljou_soil (qui échoue « between 1 and 3 layers »).
  if (is.null(ewm) || (length(ewm) == 1 && is.na(ewm))) ewm <- 150

  make_soil <- function(e) {
    args <- list(ewm = e, init = init)
    if (!is.null(roots)) args$roots <- roots
    if (!is.null(macro)) args$macro <- macro
    if (!is.null(micro)) args$micro <- micro
    do.call(biljouR::biljou_soil, args)
  }

  if (identical(source, "uniform")) return(make_soil(ewm))

  # --- Mode SoilGrids : un sol mono-couche par UGF (spec 035 D2/D6). ---
  if (is.null(units)) {
    cli::cli_abort("{.arg units} is required when {.code source = \"soilgrids\"}.")
  }
  per_unit <- ewm_depuis_soilgrids(units, rooting_depth_cm = rooting_depth_cm,
                                   country = country,
                                   progress_callback = progress_callback)
  if (is.null(per_unit)) {
    cli::cli_warn(c(
      "SoilGrids is unreachable; falling back to a uniform soil ({.val {ewm[1]}} mm).",
      i = "Check network access to {.url https://files.isric.org}."))
    return(make_soil(ewm))
  }

  # biljou_soil() refuse ewm <= 0 : NA / roche affleurante -> valeur de repli.
  bad <- !is.finite(per_unit) | per_unit <= 0
  if (any(bad)) {
    cli::cli_warn("{sum(bad)} unit{?s} without usable soil data; using {.val {ewm[1]}} mm.")
    per_unit[bad] <- ewm[1]
  }
  ids <- as.character(seq_len(nrow(units)))
  stats::setNames(lapply(per_unit, make_soil), ids)
}
