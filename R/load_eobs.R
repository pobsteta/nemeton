# load_eobs.R — acquisition E-OBS (T°max / précip estivales par année) pour la
# détection des années de référence et le contexte régional reGénération.
# ------------------------------------------------------------------
# E-OBS = jeu européen quadrillé quotidien (ECA&D / Copernicus). Les deux
# consommateurs cœur — microclimate_detect_years() et tendances_estivales_eobs()
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
    rr = list(cds = "precipitation_amount", reducer = "sum"),
    cli::cli_abort("Unknown E-OBS {.arg var} {.val {var}}; use \"tx\", \"tg\" or \"rr\".")
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
  fun <- switch(reducer, mean = "mean", sum = "sum", max = "max", median = "median",
                cli::cli_abort("Unknown {.arg reducer} {.val {reducer}}."))
  if (!is.null(aoi)) {
    if (!inherits(aoi, c("sf", "sfc"))) {
      cli::cli_abort("{.arg aoi} must be an {.cls sf}/{.cls sfc}.")
    }
    av <- terra::vect(sf::st_transform(
      sf::st_union(sf::st_geometry(aoi)), terra::crs(daily)))
    daily <- terra::mask(terra::crop(daily, av, snap = "out"), av)
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
# Renvoie le(s) chemin(s) netCDF — un par bloc CDS couvert par `years` — ou
# ÉCHOUE avec un message explicite (audit 1.0 : chaque échec devenait un NULL
# muet, cf. l'incident « E-OBS indisponible » de juillet 2026). C'est
# load_eobs_source() qui transforme l'erreur en avertissement + payload
# `eobs:unavailable`.
.eobs_cds_fetch <- function(cds_var, years, cache_dir, version, resolution,
                            period = NULL, emit = NULL) {
  if (is.null(emit)) emit <- function(payload) NULL
  if (!requireNamespace("ecmwfr", quietly = TRUE)) {
    cli::cli_abort("The CDS download needs the {.pkg ecmwfr} package.")
  }
  # Cache PERSISTANT par défaut (les blocs E-OBS pèsent plusieurs Go — on ne
  # re-télécharge pas à chaque analyse). L'app peut passer un cache_dir projet.
  if (is.null(cache_dir)) cache_dir <- file.path(get_global_cache_dir(), "eobs")
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }
  if (is.null(period)) {
    if (is.null(years)) {
      cli::cli_abort(c(
        "Cannot infer the E-OBS CDS period block without {.arg years}.",
        i = "Pass {.arg years} or an explicit {.arg period}."))
    }
    # Années à cheval sur plusieurs blocs CDS : un bloc par tranche, fusionnés
    # à la lecture (terra::rast() sur plusieurs fichiers de même grille).
    period <- .eobs_cds_periods(as.integer(years))
    if (length(period) > 1L) {
      cli::cli_inform(c(
        "i" = "E-OBS: requested years span {length(period)} CDS blocks ({.val {period}}); downloading and merging them."))
    }
  }
  vapply(period, function(p)
    .eobs_cds_fetch_block(cds_var, p, cache_dir, version, resolution, emit),
    character(1), USE.NAMES = FALSE)
}

# Un bloc CDS (variable × période × version × résolution) -> chemin netCDF.
.eobs_cds_fetch_block <- function(cds_var, period, cache_dir, version,
                                  resolution, emit) {
  # Cache-hit : le bloc a déjà été téléchargé -> on réutilise sans réseau.
  nc_cache <- .eobs_cache_file(cds_var, period, version, resolution, cache_dir)
  if (file.exists(nc_cache)) {
    emit(list(current = "eobs:cache_hit", file = basename(nc_cache)))
    return(nc_cache)
  }
  # Le CDS attend les valeurs d'enum avec des underscores (`30_0e`, `0_1deg`),
  # pas des points — on tolère la forme humaine `30.0e` / `0.1deg` en entrée.
  req <- list(
    dataset_short_name = .EOBS_CDS_DATASET,
    product_type    = "ensemble_mean",
    variable        = cds_var,
    grid_resolution = gsub("\\.", "_", resolution),
    period          = period,
    version         = gsub("\\.", "_", version),
    format          = "zip",
    target          = paste0(tools::file_path_sans_ext(basename(nc_cache)), ".zip"))
  emit(list(current = "eobs:cds_request", variable = cds_var,
            period = period, version = version, resolution = resolution))
  zip <- tryCatch(
    ecmwfr::wf_request(request = req, path = cache_dir, transfer = TRUE),
    error = function(e) cli::cli_abort(
      "CDS request failed for E-OBS {.val {cds_var}} {.val {period}}: {conditionMessage(e)}",
      parent = e))
  if (is.null(zip) || !file.exists(zip)) {
    cli::cli_abort("CDS request for E-OBS {.val {cds_var}} {.val {period}} returned no file.")
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

# Blocs CDS E-OBS (tranches pluriannuelles livrées par le CDS).
.EOBS_CDS_BLOCKS <- list(c(1950, 1964), c(1965, 1979), c(1980, 1994),
                         c(1995, 2010), c(2011, 2100))

# Libellé CDS d'un bloc pour des années qu'il contient. Bloc ouvert
# (« courant ») : la borne haute suit l'année demandée la plus récente au lieu
# d'un plafond figé — la valeur d'enum `2011_<max>` doit correspondre à la
# couverture de la `version` E-OBS choisie (best-effort). Blocs clos : borne
# réelle.
.eobs_block_label <- function(b, years) {
  hi <- if (b[2] >= 2100) max(years) else b[2]
  sprintf("%d_%d", b[1], hi)
}

# Tous les blocs CDS couvrant `years`, dans l'ordre chronologique (audit 1.0 :
# des années à cheval sur deux blocs renvoyaient NULL sans message).
.eobs_cds_periods <- function(years) {
  years <- sort(unique(as.integer(years)))
  out <- character(0)
  couvert <- logical(length(years))
  for (b in .EOBS_CDS_BLOCKS) {
    dans <- years >= b[1] & years <= b[2]
    if (any(dans)) {
      out <- c(out, .eobs_block_label(b, years[dans]))
      couvert <- couvert | dans
    }
  }
  if (!all(couvert)) {
    cli::cli_abort("E-OBS covers 1950 onwards; years {.val {years[!couvert]}} are out of range.")
  }
  out
}

# Bloc pluriannuel E-OBS couvrant les années demandées (les fichiers CDS sont
# livrés par tranches). Renvoie NULL si les années débordent d'un seul bloc —
# voir .eobs_cds_periods() pour le cas à cheval, géré par .eobs_cds_fetch().
.eobs_cds_period <- function(years) {
  years <- as.integer(years)
  for (b in .EOBS_CDS_BLOCKS) {
    if (all(years >= b[1] & years <= b[2])) return(.eobs_block_label(b, years))
  }
  NULL
}

# Nom de cache déterministe pour un bloc E-OBS (variable × période × version ×
# résolution) : permet le cache-hit et évite les collisions entre requêtes.
.eobs_cache_file <- function(cds_var, period, version, resolution, cache_dir) {
  tag <- gsub("[^A-Za-z0-9]+", "-",
              sprintf("%s_%s_v%s_%s", cds_var, period, version, resolution))
  file.path(cache_dir, paste0("eobs_", tag, ".nc"))
}

#' Acquire E-OBS per-year summer fields (Tmax / precipitation) for an AOI
#'
#' @description
#' Build the per-year summer `SpatRaster` (one layer per year, named by year)
#' that [microclimate_detect_years()] and [tendances_estivales_eobs()] consume,
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
#'   temperature) or `"rr"` (precipitation).
#' @param years Optional integer years to keep (default: all years present).
#' @param months Summer months to reduce over (default `6:8`, JJA). A year
#'   with less than 90% of the days of these months is dropped with a warning.
#' @param source `"cds"` for the automatic Copernicus download, anything else
#'   requires `nc`.
#' @param reducer Temporal reducer over the summer days: default `"mean"` for
#'   `tx`/`tg`, `"sum"` for `rr`. Also `"max"`, `"median"`.
#' @param nc A daily E-OBS netCDF path (or a dated `SpatRaster`) to use instead
#'   of the CDS download.
#' @param cache_dir Persistent directory for the CDS download / unzip. Defaults
#'   to `file.path(get_global_cache_dir(), "eobs")` so a given block (variable ×
#'   period × version × resolution) is downloaded **once** and reused on later
#'   calls (cache-hit, no network). Pass a project-scoped path to isolate it.
#' @param version,resolution E-OBS product version (default `"30.0e"`; dots are
#'   normalised to the CDS underscore form, e.g. `30_0e`) and grid
#'   resolution (default `"0.1deg"`) for the CDS request. For years beyond the
#'   default block bound, pair a recent `version` with the matching `period`.
#' @param period Optional explicit CDS period block (e.g. `"2011_2024"`);
#'   inferred from `years` when `NULL`. For the current (open) block the inferred
#'   upper bound follows the most recent requested year (no fixed ceiling).
#'   Years spanning several CDS blocks are downloaded block by block and merged.
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
#' @export
load_eobs_source <- function(aoi, var = "tx", years = NULL, months = 6:8,
                             source = "cds", reducer = NULL, nc = NULL,
                             cache_dir = NULL, version = "30.0e",
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
  # Audit 1.0 : un échec n'est plus un NULL muet — le message d'origine part
  # dans un avertissement ET dans le payload `eobs:unavailable` (`message`).
  echec <- function(reason, e) {
    msg <- conditionMessage(e)
    cli::cli_warn(c("E-OBS {.val {var}} unavailable ({reason}).", x = msg))
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
                                  resolution, period, emit = emit),
                  error = function(e) e)
    if (inherits(f, "error")) return(echec("cds", f))
    emit(list(current = "eobs:read", source = "cds", var = var))
    # Plusieurs blocs CDS -> une seule pile quotidienne (même grille).
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
