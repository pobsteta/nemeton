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
.biljou_forcing_era5 <- function(points, years, cache_dir, altitude = 0) {
  if (!requireNamespace("mcera5", quietly = TRUE) || is.null(years)) return(NULL)
  out <- lapply(seq_len(nrow(points)), function(i) {
    p <- points[i, ]
    hourly <- do.call(rbind, lapply(years, function(y)
      .rsen_forcage_era5(p$lon, p$lat, y, cache_dir)))
    .biljou_era5_meteo(hourly, lat = p$lat, altitude = altitude)
  })
  stats::setNames(out, as.character(points$id))
}

#' Acquire the BILJOU daily meteorological forcing for an AOI
#'
#' @description
#' Produce the `meteo` input of [regen_bilan_hydrique()] — a daily forcing at the
#' biljouR format (`date`, `doy`, `pet`, `rain`) — over `years` for `aoi`, from
#' SAFRAN (French primary) or ERA5-Land (fallback). Acquisition lives in the core
#' (rule #1); the app only orchestrates and caches (pattern:
#' [load_theia_source()], spec 027 §10.2).
#'
#' Returns a **named list of per-unit `meteo` data frames** (keyed by the same
#' sequential ids as `regen_bilan_hydrique()`'s grid points), directly consumable
#' by `biljou_run_grid()`; or a single `data.frame` when a shared `raw` series is
#' passed. Degrades to `NULL` when the source is unavailable (no `biljouR`, no CDS
#' key, network failure, AOI outside coverage) so the caller can fall back.
#'
#' @param aoi An `sf`/`sfc` of the management units (their centroids are sampled).
#' @param years Integer year(s) to fetch.
#' @param source `"safran"` (default, France) or `"era5"` (fallback, `mcera5`).
#' @param cache_dir Directory for the SAFRAN/ERA5 downloads (default a tempdir).
#' @param raw Optional raw SAFRAN `data.frame` to convert instead of downloading
#'   (via [biljouR::safran_to_meteo()]) — the tested injection path.
#' @param points Optional pre-built `data.frame(id, lon, lat)` (defaults to the
#'   `aoi` centroids).
#' @param latitude,altitude Site latitude/altitude for PET when `raw`/ERA5 need a
#'   Penman estimate (`latitude` defaults to the AOI centroid).
#' @param compute_pet Passed to [biljouR::safran_to_meteo()] for the `raw` path.
#' @param ... Passed to [biljouR::safran_download()].
#'
#' @return A per-unit named list of `meteo` data frames (or a single
#'   `data.frame`), or `NULL` on graceful degradation.
#' @export
load_biljou_forcing <- function(aoi, years, source = c("safran", "era5"),
                                cache_dir = NULL, raw = NULL, points = NULL,
                                latitude = NULL, altitude = 0,
                                compute_pet = FALSE, ...) {
  source <- match.arg(source)
  if (!requireNamespace("biljouR", quietly = TRUE) ||
      !requireNamespace("sf", quietly = TRUE)) {
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
    return(.biljou_filter_years(meteo, years))
  }

  meteo <- tryCatch({
    if (source == "safran") {
      dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
      files <- biljouR::safran_download(dest_dir = cache_dir, quiet = TRUE, ...)
      m <- biljouR::safran_nc_to_meteo(files, points = points, id_col = "id",
                                       lon_col = "lon", lat_col = "lat")
      # normaliser en liste nommée par id si un data.frame long est renvoyé
      if (is.data.frame(m) && "id" %in% names(m)) {
        m <- split(m[setdiff(names(m), "id")], m$id)
      }
      m
    } else {
      .biljou_forcing_era5(points, years, cache_dir, altitude = altitude)
    }
  }, error = function(e) NULL)
  if (is.null(meteo)) return(NULL)
  .biljou_filter_years(meteo, years)
}

#' Build the BILJOU soil object for management units
#'
#' @description
#' Produce the `sol` input of [regen_bilan_hydrique()] — a
#' [biljouR::biljou_soil()] object (extractable water `ewm`, root fractions,
#' macro/micro porosity, initial fill). A single soil is returned (shared across
#' the `biljou_run_grid()` points, as the engine expects). With no fine soil
#' reference (RRP / BDGSF / European Soil DB), a sensible uniform default is used
#' — the app already exposes an `ewm` default (150 mm) usable as a fallback.
#'
#' @param units An `sf`/`sfc` of the management units (currently used for count /
#'   future per-region soil lookup; the returned soil is uniform).
#' @param ewm Maximum extractable water (mm). Default `150`.
#' @param roots,macro,micro,init Passed to [biljouR::biljou_soil()] (root
#'   fractions, macro/micro porosity, initial fill fraction).
#' @param ... Ignored (forward-compat).
#'
#' @return A `biljou_soil` object, or `NULL` when `biljouR` is unavailable.
#' @export
build_biljou_soil <- function(units = NULL, ewm = 150, roots = NULL,
                              macro = NULL, micro = NULL, init = 1, ...) {
  if (!requireNamespace("biljouR", quietly = TRUE)) return(NULL)
  args <- list(ewm = ewm, init = init)
  if (!is.null(roots)) args$roots <- roots
  if (!is.null(macro)) args$macro <- macro
  if (!is.null(micro)) args$micro <- micro
  do.call(biljouR::biljou_soil, args)
}
