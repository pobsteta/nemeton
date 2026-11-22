# load_eobs.R — acquisition E-OBS (T°max / précip estivales par année) pour la
# détection des années de référence et le contexte régional reGénération.
# ------------------------------------------------------------------
# E-OBS = jeu européen quadrillé quotidien (ECA&D / Copernicus). Les deux
# consommateurs cœur — microclimate_detect_years() et eobs_summer_series()
# — attendent un SpatRaster ESTIVAL PAR ANNÉE (une couche/an, nommée par
# l'année). Ce loader produit ce format depuis un netCDF quotidien fourni
# (voie B / injection `nc`, testable) ou téléchargé au CDS (voie A, best-effort,
# validé sur données réelles). Spec 034. Patron : load_foret_ancienne_source().

# Dataset E-OBS sur le Copernicus CDS (même clé ecmwfr que ERA5/mcera5).
.EOBS_CDS_DATASET <- "insitu-gridded-observations-europe"

# var nemeton -> (variable CDS, réducteur estival par défaut).
.eobs_var_spec <- function(var) {
  switch(
    var,
    tx = list(cds = "maximum_temperature",  reducer = "mean"),
    tg = list(cds = "mean_temperature",     reducer = "mean"),
    tn = list(cds = "minimum_temperature",  reducer = "mean"),
    rr = list(cds = "precipitation_amount", reducer = "sum"),
    cli::cli_abort("Unknown E-OBS {.arg var} {.val {var}}; use \"tx\", \"tg\", \"tn\" or \"rr\".")
  )
}

# Nombre de jours calendaires des mois `months` de l'année `y`.
.eobs_jours_attendus <- function(y, months) {
  sum(vapply(months, function(m) {
    d1 <- as.Date(sprintf("%d-%02d-01", y, m))
    d2 <- seq(d1, by = "month", length.out = 2L)[2L]
    as.integer(d2 - d1)
  }, integer(1)))
}

# Réduction estivale par année (chemin PUR, testable) : un raster quotidien daté
# -> une couche par année = réduction sur les mois d'été, restreinte à l'AOI.
# Audit 1.0 : une année dont moins de `min_frac` des jours des mois demandés
# sont présents (été en cours, bloc tronqué) est ÉCARTÉE avec un avertissement —
# sinon la moyenne d'un juin seul passait pour une moyenne estivale, et un cumul
# de pluie sur 30 jours pour un cumul de 92 jours.
.eobs_summer_by_year <- function(daily, aoi = NULL, years = NULL, months = 6:8,
                                 reducer = "mean", min_frac = 0.9) {
  if (!inherits(daily, "SpatRaster")) {
    cli::cli_abort("{.arg daily} must be a {.cls SpatRaster} of daily E-OBS values.")
  }
  fun <- switch(reducer, mean = "mean", sum = "sum", max = "max", min = "min",
                median = "median",
                cli::cli_abort("Unknown {.arg reducer} {.val {reducer}}."))
  if (!is.null(aoi) && !inherits(aoi, c("sf", "sfc"))) {
    cli::cli_abort("{.arg aoi} must be an {.cls sf}/{.cls sfc}.")
  }
  tt <- terra::time(daily)
  if (length(tt) == 0L || all(is.na(tt))) {
    cli::cli_abort(c(
      "E-OBS raster carries no {.fun terra::time}; cannot select summer months.",
      i = "Read the daily E-OBS netCDF so layers keep their dates."))
  }
  dates <- as.Date(tt)
  yr <- as.integer(format(dates, "%Y"))
  mo <- as.integer(format(dates, "%m"))
  keep_m <- mo %in% months
  ys <- if (is.null(years)) sort(unique(yr[keep_m])) else sort(unique(as.integer(years)))
  # Dates d'abord, emprise ensuite : le CDS livre la série complète (~27 000
  # couches depuis 1950). Découper toute la pile avant d'en garder les étés
  # demandés lirait des Go pour rien.
  sel <- which(keep_m & yr %in% ys)
  if (length(sel) && length(sel) < terra::nlyr(daily)) {
    daily <- daily[[sel]]
    dates <- dates[sel]; yr <- yr[sel]; mo <- mo[sel]; keep_m <- keep_m[sel]
  }
  if (!is.null(aoi)) {
    av <- terra::vect(sf::st_transform(
      sf::st_union(sf::st_geometry(aoi)), terra::crs(daily)))
    daily <- terra::mask(terra::crop(daily, av, snap = "out"), av)
  }
  incompletes <- character(0)
  layers <- lapply(ys, function(y) {
    idx <- which(keep_m & yr == y)
    if (!length(idx)) return(NULL)
    # Jours DISTINCTS présents (un doublon de date ne doit pas compléter l'été).
    n_ok <- length(unique(dates[idx]))
    n_att <- .eobs_jours_attendus(y, months)
    if (n_ok < min_frac * n_att) {
      incompletes <<- c(incompletes, sprintf("%d (%d/%d days)", y, n_ok, n_att))
      return(NULL)
    }
    terra::app(daily[[idx]], fun = fun)
  })
  if (length(incompletes)) {
    cli::cli_warn(c(
      "E-OBS: incomplete summer{?s} dropped: {incompletes}.",
      i = "A year needs at least {round(100 * min_frac)}% of the days of months {.val {months}}."))
  }
  ok <- !vapply(layers, is.null, logical(1))
  if (!any(ok)) {
    cli::cli_abort("No E-OBS summer layers for the requested {.arg years}/{.arg months}.")
  }
  out <- terra::rast(layers[ok])
  ys_ok <- ys[ok]
  names(out) <- as.character(ys_ok)
  terra::time(out) <- as.Date(sprintf("%d-07-15", ys_ok))
  out
}

# Téléchargement CDS (voie A). Non jouable en CI ; validé sur données réelles.
# Renvoie le chemin du netCDF ou ÉCHOUE avec un message explicite (audit 1.0 :
# chaque échec devenait un NULL muet, cf. l'incident « E-OBS indisponible » de
# juillet 2026). C'est load_eobs_source() qui transforme l'erreur en
# avertissement + payload `eobs:unavailable`.
#
# Depuis novembre 2026, le CDS ne découpe plus E-OBS en blocs d'années : le
# champ `period` a disparu du formulaire (toute requête qui le porte est
# « invalid request »), chaque requête livre la série complète depuis 1950
# (4,34 Go à 0,1° pour une variable, 0,83 Go à 0,25°, mesuré le 2026-11-22), et
# un champ `licence_type` est exigé. Un seul fichier par variable × version ×
# résolution, téléchargé une fois dans le cache global. `years` et `period` ne
# servent plus à la requête (gardés pour la signature).
.eobs_cds_fetch <- function(cds_var, years, cache_dir, version, resolution,
                            period = NULL, emit = NULL) {
  if (is.null(emit)) emit <- function(payload) NULL
  if (!requireNamespace("ecmwfr", quietly = TRUE)) {
    cli::cli_abort("The CDS download needs the {.pkg ecmwfr} package.")
  }
  # Cache PERSISTANT par défaut (plusieurs Go par variable — on ne
  # re-télécharge pas à chaque analyse). L'app peut passer un cache_dir projet.
  if (is.null(cache_dir)) cache_dir <- file.path(get_global_cache_dir(), "eobs")
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }
  .eobs_cds_fetch_block(cds_var, .EOBS_CDS_SERIE, cache_dir, version, resolution, emit)
}

# Étiquette de cache de la série complète (il n'y a plus de bloc d'années).
.EOBS_CDS_SERIE <- "1950-present"

# Licence à déclarer : le CDS n'accepte `open_data_licence` qu'à partir de la
# version 34.0e ; les versions 28.0e à 33.0e exigent la licence de recherche
# (`restricted_research_licence`), à accepter sur le compte CDS.
.eobs_licence <- function(version) {
  num <- suppressWarnings(as.numeric(sub("^v?([0-9]+).*$", "\\1", version)))
  if (!is.na(num) && num >= 34) "open_data_licence" else "restricted_research_licence"
}

# La série CDS (variable × version × résolution) -> chemin netCDF.
.eobs_cds_fetch_block <- function(cds_var, period, cache_dir, version,
                                  resolution, emit) {
  # Cache-hit : la série a déjà été téléchargée -> on réutilise sans réseau.
  nc_cache <- .eobs_cache_file(cds_var, period, version, resolution, cache_dir)
  if (file.exists(nc_cache)) {
    emit(list(current = "eobs:cache_hit", file = basename(nc_cache)))
    return(nc_cache)
  }
  # Le CDS attend les valeurs d'enum avec des underscores (`34_0e`, `0_1deg`),
  # pas des points — on tolère la forme humaine `34.0e` / `0.1deg` en entrée.
  req <- list(
    dataset_short_name = .EOBS_CDS_DATASET,
    product_type    = "ensemble_mean",
    variable        = cds_var,
    grid_resolution = gsub("\\.", "_", resolution),
    version         = gsub("\\.", "_", version),
    licence_type    = .eobs_licence(version),
    format          = "zip",
    target          = paste0(tools::file_path_sans_ext(basename(nc_cache)), ".zip"))
  emit(list(current = "eobs:cds_request", variable = cds_var,
            version = version, resolution = resolution))
  zip <- tryCatch(
    ecmwfr::wf_request(request = req, path = cache_dir, transfer = TRUE),
    error = function(e) cli::cli_abort(
      "CDS request failed for E-OBS {.val {cds_var}} v{version}: {conditionMessage(e)}",
      parent = e))
  if (is.null(zip) || !file.exists(zip)) {
    cli::cli_abort("CDS request for E-OBS {.val {cds_var}} v{version} returned no file.")
  }
  emit(list(current = "eobs:cds_download_done", file = basename(zip)))
  emit(list(current = "eobs:unzip"))
  nc <- tryCatch({
    # Extraction contrôlée : entrées relatives seulement, netCDF seulement.
    files <- .unzip_safe(zip, exdir = cache_dir, pattern = "\\.nc$")
    files[grepl("\\.nc$", files)][1]
  }, error = function(e) cli::cli_abort(
    "Cannot unzip the E-OBS archive {.path {basename(zip)}}: {conditionMessage(e)}",
    parent = e))
  if (is.null(nc) || is.na(nc) || !file.exists(nc)) {
    cli::cli_abort("The E-OBS archive {.path {basename(zip)}} holds no netCDF file.")
  }
  # Range le netCDF sous le nom de cache stable (prochain appel = cache-hit) et
  # supprime le zip volumineux devenu inutile.
  if (!identical(normalizePath(nc), normalizePath(nc_cache, mustWork = FALSE))) {
    if (isTRUE(tryCatch(file.rename(nc, nc_cache), error = function(e) FALSE))) {
      nc <- nc_cache
    }
  }
  tryCatch(unlink(zip), error = function(e) NULL)
  nc
}

# Nom de cache déterministe (variable × série × version × résolution) : permet
# le cache-hit et évite les collisions entre requêtes.
.eobs_cache_file <- function(cds_var, period, version, resolution, cache_dir) {
  tag <- gsub("[^A-Za-z0-9]+", "-",
              sprintf("%s_%s_v%s_%s", cds_var, period, version, resolution))
  file.path(cache_dir, paste0("eobs_", tag, ".nc"))
}

#' Path of the cached E-OBS daily series
#'
#' Where [load_eobs_source()] (`source = "cds"`) keeps the downloaded E-OBS
#' series of one variable, and whether it is there. Since November 2026 the CDS
#' delivers the whole series (1950 onwards) in a single netCDF per variable
#' (about 4.3 GB at 0.1°), so callers should share one cache — the default,
#' under [get_global_cache_dir()] — instead of downloading it once per project.
#'
#' @param var E-OBS variable: `"tx"`, `"tg"`, `"tn"` or `"rr"`.
#' @param version,resolution As in [load_eobs_source()].
#' @param cache_dir As in [load_eobs_source()]; `NULL` (default) is the global
#'   E-OBS cache.
#'
#' @return The netCDF path when the series is cached, otherwise `NULL`.
#'
#' @section Lifecycle:
#' Experimental.
#'
#' @seealso [load_eobs_source()]
#' @export
eobs_cached_file <- function(var = "tx", version = "34.0e", resolution = "0.1deg",
                             cache_dir = NULL) {
  spec <- .eobs_var_spec(var)
  if (is.null(cache_dir)) cache_dir <- file.path(get_global_cache_dir(), "eobs")
  f <- .eobs_cache_file(spec$cds, .EOBS_CDS_SERIE, version, resolution, cache_dir)
  if (file.exists(f)) f else NULL
}

#' Acquire E-OBS per-year summer fields (Tmax / precipitation) for an AOI
#'
#' @description
#' Build the per-year summer `SpatRaster` (one layer per year, named by year)
#' that [microclimate_detect_years()] and [eobs_summer_series()] consume,
#' from the European E-OBS gridded dataset (ECA&D / Copernicus). Two paths
#' (spec 034):
#'
#' - **Injection (`nc`)** — pass a daily E-OBS netCDF path (downloaded from the
#'   CDS web interface or ECA&D) or a dated `SpatRaster`; the core reduces it to
#'   summer-per-year. This is the tested contract.
#' - **CDS (`source = "cds"`)** — best-effort automatic download via `ecmwfr`
#'   (dataset `insitu-gridded-observations-europe`, the same CDS key as ERA5).
#'   Not runnable in CI; validated on real data. Degrades to `NULL`.
#'
#' @param aoi An `sf`/`sfc` of the management units (their union crops E-OBS).
#' @param var E-OBS variable: `"tx"` (max temperature, default), `"tg"` (mean
#'   temperature), `"tn"` (min temperature, since 2026.11.32) or `"rr"`
#'   (precipitation).
#' @param years Optional integer years to keep (default: all years present).
#' @param months Summer months to reduce over (default `6:8`, JJA). A year
#'   with less than 90% of the days of these months is dropped with a warning.
#' @param source `"cds"` for the automatic Copernicus download, anything else
#'   requires `nc`.
#' @param reducer Temporal reducer over the summer days: default `"mean"` for
#'   `tx`/`tg`/`tn`, `"sum"` for `rr`. Also `"max"`, `"min"`, `"median"`.
#' @param nc A daily E-OBS netCDF path (or a dated `SpatRaster`) to use instead
#'   of the CDS download.
#' @param cache_dir Persistent directory for the CDS download / unzip. Defaults
#'   to `file.path(get_global_cache_dir(), "eobs")` so a given series (variable
#'   × version × resolution) is downloaded **once** and reused on later calls
#'   (cache-hit, no network). Pass a project-scoped path to isolate it.
#' @param version,resolution E-OBS product version (default `"34.0e"`; dots are
#'   normalised to the CDS underscore form, e.g. `34_0e`) and grid resolution
#'   (default `"0.1deg"`) for the CDS request. Since November 2026 the CDS
#'   delivers the **whole series** (1950 onwards) in one file per variable —
#'   about 4.3 GB at 0.1°, 0.8 GB at 0.25° — and requires a licence type:
#'   `open_data_licence` from version 34.0e, `restricted_research_licence`
#'   (to accept once on the CDS) for versions 28.0e to 33.0e.
#' @param period Ignored since 2026.11.39: the CDS no longer splits E-OBS into
#'   period blocks. A non-`NULL` value warns once per session.
#' @param progress_callback Optional function called at each step with a
#'   `list(current = <key>, …)` payload (monitoring pattern). Keys:
#'   `"eobs:cache_hit"`, `"eobs:cds_request"`, `"eobs:cds_download_done"`,
#'   `"eobs:unzip"`, `"eobs:read"`, `"eobs:reduce"`, `"eobs:complete"`,
#'   `"eobs:unavailable"` (`reason`, and `message` = the underlying error).
#'   The app maps these to bottom-right notifications.
#' @param ... Ignored (forward-compat).
#'
#' @return A per-year summer `SpatRaster` (layers named by year), or `NULL` on
#'   graceful degradation (with a warning carrying the underlying error message).
#' @section Lifecycle:
#' Stable: covered by the 1.0 API contract (spec 057).
#'
#' @export
load_eobs_source <- function(aoi, var = "tx", years = NULL, months = 6:8,
                             source = "cds", reducer = NULL, nc = NULL,
                             cache_dir = NULL, version = "34.0e",
                             resolution = "0.1deg", period = NULL,
                             progress_callback = NULL, ...) {
  # Émetteur de progression : chaque étape publie un payload `list(current=…)`
  # que l'app traduit en notification (patron monitoring). No-op si NULL.
  emit <- function(payload) {
    if (!is.null(progress_callback)) progress_callback(payload)
  }
  if (!requireNamespace("terra", quietly = TRUE) ||
      !requireNamespace("sf", quietly = TRUE)) {
    emit(list(current = "eobs:unavailable", reason = "deps"))
    return(NULL)
  }
  spec <- .eobs_var_spec(var)
  if (is.null(reducer)) reducer <- spec$reducer
  if (!is.null(period)) {
    rlang::warn(
      "`period` is ignored: the CDS now delivers the whole E-OBS series in one file.",
      .frequency = "once", .frequency_id = "nemeton_eobs_period")
  }
  # Audit 1.0 : un échec n'est plus un NULL muet — le message d'origine part
  # dans un avertissement ET dans le payload `eobs:unavailable` (`message`).
  echec <- function(reason, e) {
    msg <- conditionMessage(e)
    cli::cli_warn(c("E-OBS {.val {var}} unavailable ({reason}).", x = "{msg}"))
    emit(list(current = "eobs:unavailable", reason = reason, message = msg))
    NULL
  }
  if (!is.null(nc)) {
    emit(list(current = "eobs:read", source = "nc", var = var))
    daily <- tryCatch(if (inherits(nc, "SpatRaster")) nc else terra::rast(nc),
                      error = function(e) e)
    if (inherits(daily, "error")) return(echec("read_error", daily))
  } else if (identical(source, "cds")) {
    f <- tryCatch(.eobs_cds_fetch(spec$cds, years, cache_dir, version,
                                  resolution, emit = emit),
                  error = function(e) e)
    if (inherits(f, "error")) return(echec("cds", f))
    emit(list(current = "eobs:read", source = "cds", var = var))
    daily <- tryCatch(terra::rast(f), error = function(e) e)
    if (inherits(daily, "error")) return(echec("read_error", daily))
  } else {
    emit(list(current = "eobs:unavailable", reason = "no_source"))
    return(NULL)
  }
  emit(list(current = "eobs:reduce", var = var, reducer = reducer))
  out <- tryCatch(
    .eobs_summer_by_year(daily, aoi = aoi, years = years, months = months,
                         reducer = reducer),
    error = function(e) e)
  if (inherits(out, "error")) return(echec("reduce_error", out))
  emit(list(current = "eobs:complete", var = var, n_years = terra::nlyr(out)))
  out
}
