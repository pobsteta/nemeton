# ============================================================
# reconfort_model.R — RECONFORT Random-Forest model fetch/cache
# ------------------------------------------------------------
# Implements lot L2a of spec 021. The RECONFORT oak-dieback models
# are Shark/OTB Random-Forest files (`model_1_seed_0.txt`) shipped
# in the upstream repository (Apache-2.0, Mouret et al. 2023). They
# are redistributable but far too large (5.7–197 MB) to bundle in
# `inst/extdata/`, so they are fetched on demand, checksum-verified,
# and cached. A user who already holds a copy (e.g. from cloning the
# upstream repo) can short-circuit the download via `local_path`.
#
# No IOTA² / Python here — this lot is pure download + cache + verify.
# ============================================================


#' RECONFORT Random-Forest model registry
#'
#' Metadata for the four RECONFORT models versioned in the upstream
#' repository (`fl.mouret/reconfort`, Apache-2.0). Each entry carries
#' the calibrated species, number of classes, the file size, the
#' MD5 checksum used by [ensure_reconfort_model()] to verify a fetch,
#' and `edate` — the `"MM-DD"` end of the model-bound analysis window
#' within `s2_year` (`10-29` for the 2-year models, `05-31` for the
#' 1.5-year `v3_early_may`). `edate` is what
#' [reconfort_latest_complete_year()] uses to tell whether a given
#' `s2_year` season is already complete.
#'
#' \describe{
#'   \item{v3}{Oak (\emph{Quercus}), 2-year series, 3 classes.}
#'   \item{v3_early_may}{Oak, 1.5-year series (Jan→May), 3 classes.}
#'   \item{v3_chestnut}{Sweet chestnut (\emph{Castanea}), 3 classes.}
#'   \item{v3_pine}{Scots pine (\emph{Pinus sylvestris}), 2 classes.}
#' }
#'
#' @export
RECONFORT_MODELS <- list(
  v3 = list(
    label      = "Oak (2-year series)",
    species    = "CHE",
    n_classes  = 3L,
    size_bytes = 205876256,
    md5        = "9b58a13d7659e757e32298a4da4dd70c",
    edate      = "10-29"
  ),
  v3_early_may = list(
    label      = "Oak (1.5-year series, Jan-May)",
    species    = "CHE",
    n_classes  = 3L,
    size_bytes = 206198055,
    md5        = "a4359992a3556704fde9434089112122",
    edate      = "05-31"
  ),
  v3_chestnut = list(
    label      = "Sweet chestnut",
    species    = "CHT",
    n_classes  = 3L,
    size_bytes = 14216359,
    md5        = "c65dcc83e9614212633a10f433b5d0b8",
    edate      = "10-29"
  ),
  v3_pine = list(
    label      = "Scots pine",
    species    = "PS",
    n_classes  = 2L,
    size_bytes = 5933217,
    md5        = "a3b14ba0ad3644db192138d256d2a0af",
    edate      = "10-29"
  )
)


# Base URL for the upstream model files. Overridable via
# `options(nemeton.reconfort_model_base_url = ...)` so a deployment can
# point at a mirror without code changes. The per-version file is
# always `<base>/<version>/model_1_seed_0.txt`.
.reconfort_model_url <- function(version) {
  base <- getOption(
    "nemeton.reconfort_model_base_url",
    "https://framagit.org/fl.mouret/reconfort/-/raw/main/models"
  )
  sprintf("%s/%s/model_1_seed_0.txt", base, version)
}


# Verify a model file against its registry entry (size + MD5). Returns
# TRUE/FALSE when `abort = FALSE`, otherwise raises a typed error.
.reconfort_verify_model <- function(path, info, version, abort = TRUE) {
  size_ok <- file.exists(path) && file.size(path) == info$size_bytes
  md5_ok  <- size_ok && identical(unname(tools::md5sum(path)), info$md5)
  ok <- isTRUE(size_ok) && isTRUE(md5_ok)
  if (!ok && abort) {
    cli::cli_abort(c(
      "RECONFORT model {.val {version}} failed verification.",
      x = "Expected size {info$size_bytes} B, MD5 {info$md5}.",
      i = "Delete the cached file and retry, or pass a correct {.arg local_path}."
    ))
  }
  ok
}


#' Look up a RECONFORT model registry entry
#'
#' @param version Model version, one of the names of [RECONFORT_MODELS]
#'   (`"v3"`, `"v3_early_may"`, `"v3_chestnut"`, `"v3_pine"`).
#'
#' @return The registry list entry (`label`, `species`, `n_classes`,
#'   `size_bytes`, `md5`).
#' @export
reconfort_model_info <- function(version = "v3") {
  if (!is.character(version) || length(version) != 1L || is.na(version)) {
    cli::cli_abort("{.arg version} must be a single non-NA string.")
  }
  if (!version %in% names(RECONFORT_MODELS)) {
    cli::cli_abort(c(
      "Unknown RECONFORT model version {.val {version}}.",
      i = "Available: {.val {names(RECONFORT_MODELS)}}."
    ))
  }
  RECONFORT_MODELS[[version]]
}


#' Fetch (and cache) a RECONFORT Random-Forest model
#'
#' Ensures a local copy of the requested RECONFORT model is available
#' and returns its path. Resolution order:
#' \enumerate{
#'   \item if `local_path` is given, that file is used directly (and
#'     verified unless `verify = FALSE`) — handy when the user already
#'     cloned the upstream repository;
#'   \item else, if a verified copy already sits in the cache, it is
#'     returned without downloading;
#'   \item else the model is downloaded from the upstream URL (or
#'     `url`), verified, and stored in the cache.
#' }
#'
#' Models are large (5.7–197 MB); the first fetch is slow. The cache
#' lives under `cache_dir` (default
#' `file.path(get_global_cache_dir(), "reconfort_models")`).
#'
#' @param version Model version (see [RECONFORT_MODELS]). Default `"v3"`.
#' @param cache_dir Cache directory. Default a per-user nemeton cache.
#' @param local_path Optional path to a model file already on disk
#'   (e.g. `<reconfort_clone>/models/v3/model_1_seed_0.txt`). When set,
#'   no download happens.
#' @param url Optional explicit download URL, overriding the registry
#'   default (built from `options(nemeton.reconfort_model_base_url)`).
#' @param force Re-download even if a valid cached copy exists.
#' @param verify Verify size + MD5 against the registry. Default `TRUE`.
#' @param quiet Suppress progress messages. Default `FALSE`.
#'
#' @return The path to the local model file (invisibly usable by the
#'   L2b pipeline).
#' @export
ensure_reconfort_model <- function(version    = "v3",
                                   cache_dir  = NULL,
                                   local_path = NULL,
                                   url        = NULL,
                                   force      = FALSE,
                                   verify     = TRUE,
                                   quiet      = FALSE) {
  info <- reconfort_model_info(version)
  say  <- function(...) if (!quiet) cli::cli_alert_info(...)

  # 1) user-provided copy -------------------------------------------
  if (!is.null(local_path)) {
    if (!file.exists(local_path)) {
      cli::cli_abort("{.arg local_path} does not exist: {.path {local_path}}.")
    }
    if (verify) .reconfort_verify_model(local_path, info, version)
    return(normalizePath(local_path))
  }

  # 2) cache resolution ---------------------------------------------
  if (is.null(cache_dir)) {
    cache_dir <- file.path(get_global_cache_dir(), "reconfort_models")
  }
  dest_dir <- file.path(cache_dir, version)
  dest     <- file.path(dest_dir, "model_1_seed_0.txt")

  if (!force && file.exists(dest)) {
    ok <- if (verify) {
      .reconfort_verify_model(dest, info, version, abort = FALSE)
    } else {
      TRUE
    }
    if (isTRUE(ok)) {
      say("RECONFORT model {.val {version}} already cached.")
      return(dest)
    }
    if (!quiet) {
      cli::cli_alert_warning(
        "Cached RECONFORT model {.val {version}} failed verification; re-downloading."
      )
    }
  }

  # 3) download -----------------------------------------------------
  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  src <- if (is.null(url)) .reconfort_model_url(version) else url
  say("Downloading RECONFORT model {.val {version}} (~{round(info$size_bytes / 1e6)} MB) from {.url {src}} ...")

  tmp <- tempfile(fileext = ".txt")
  ok_dl <- tryCatch({
    suppressWarnings(
      download.file(src, tmp, mode = "wb", quiet = quiet)
    )
    file.exists(tmp) && file.size(tmp) > 0
  }, error = function(e) {
    if (file.exists(tmp)) unlink(tmp)
    cli::cli_abort(c(
      "Failed to download RECONFORT model {.val {version}}.",
      x = conditionMessage(e),
      i = "Source: {.url {src}}",
      i = "Or pass {.arg local_path} to use a model already on disk."
    ))
  })
  if (!isTRUE(ok_dl)) {
    if (file.exists(tmp)) unlink(tmp)
    cli::cli_abort(c(
      "Failed to download RECONFORT model {.val {version}} (empty or missing file).",
      i = "Source: {.url {src}}"
    ))
  }

  if (verify && !.reconfort_verify_model(tmp, info, version, abort = FALSE)) {
    unlink(tmp)
    cli::cli_abort(c(
      "Checksum mismatch for the downloaded RECONFORT model {.val {version}}.",
      i = "Expected MD5 {info$md5}.",
      i = "The download may be corrupted or the upstream file has changed."
    ))
  }

  # Atomic-ish move into the cache.
  if (!file.rename(tmp, dest)) {
    file.copy(tmp, dest, overwrite = TRUE)
    unlink(tmp)
  }
  say("Cached RECONFORT model {.val {version}} at {.path {dest}}.")
  dest
}


# First Sentinel-2 year with usable dense France coverage (S2A+S2B).
# The RECONFORT `s2_year` picker starts here.
.RECONFORT_MIN_YEAR <- 2016L


#' Most recent RECONFORT `s2_year` whose season is already complete
#'
#' RECONFORT classifies a pixel's model-bound ~2-year index trajectory;
#' the analysis window ends at `s2_year<edate>` (`10-29` for the 2-year
#' models, `05-31` for `v3_early_may` — see [RECONFORT_MODELS]). Running
#' a run for a `s2_year` whose window has not fully elapsed yields a
#' truncated final season and a degraded classification. This helper
#' returns the latest `s2_year` for which the window end date has already
#' passed, so callers (notably the app's year picker) can default to —
#' and cap at — a year that produces a complete run.
#'
#' @param v_model Model version (see [RECONFORT_MODELS]). Default `"v3"`.
#' @param today Reference date. Default [Sys.Date()]; injectable for
#'   tests.
#' @param lag_days Extra buffer (days) added to the window end date to
#'   account for the Theia/Sentinel-2 processing latency before the last
#'   acquisitions of the window are ingestible. Default `0L` (the window
#'   end date itself). Pass a positive value to be conservative.
#'
#' @return A single integer year: the current year when its window end
#'   date (plus `lag_days`) is on or before `today`, otherwise the
#'   previous year.
#' @seealso [reconfort_year_bounds()], [run_reconfort_dieback()]
#' @examples
#' # Oak 2-year model: complete only once 29 Oct of the year has passed.
#' reconfort_latest_complete_year("v3", today = as.Date("2026-07-01")) # 2025
#' reconfort_latest_complete_year("v3", today = as.Date("2026-11-15")) # 2026
#' # early-May model: complete from June onwards.
#' reconfort_latest_complete_year("v3_early_may", today = as.Date("2026-07-01")) # 2026
#' @export
reconfort_latest_complete_year <- function(v_model  = "v3",
                                           today    = Sys.Date(),
                                           lag_days = 0L) {
  info <- reconfort_model_info(v_model)            # validates v_model
  today <- as.Date(today)
  if (length(today) != 1L || is.na(today)) {
    cli::cli_abort("{.arg today} must be a single non-NA date.")
  }
  lag_days <- as.integer(lag_days)
  if (is.na(lag_days) || lag_days < 0L) {
    cli::cli_abort("{.arg lag_days} must be a non-negative integer.")
  }
  y   <- as.integer(format(today, "%Y"))
  end <- as.Date(sprintf("%d-%s", y, info$edate)) + lag_days
  if (today >= end) y else y - 1L
}


#' Bounds for a RECONFORT `s2_year` picker
#'
#' Convenience wrapper returning the `min`, `max` and `default` a UI
#' year picker should use for `s2_year`. `min` is the first Sentinel-2
#' dense-coverage year (2016); `max` and `default` are both
#' [reconfort_latest_complete_year()] so the current, still-incomplete
#' year is neither the default nor selectable through the bounds.
#'
#' @inheritParams reconfort_latest_complete_year
#'
#' @return A named list of three integers: `min`, `max`, `default`.
#' @seealso [reconfort_latest_complete_year()]
#' @examples
#' reconfort_year_bounds("v3", today = as.Date("2026-07-01"))
#' # $min 2016  $max 2025  $default 2025
#' @export
reconfort_year_bounds <- function(v_model  = "v3",
                                   today    = Sys.Date(),
                                   lag_days = 0L) {
  latest <- reconfort_latest_complete_year(v_model, today = today,
                                           lag_days = lag_days)
  list(min = .RECONFORT_MIN_YEAR, max = latest, default = latest)
}
