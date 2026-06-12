# ============================================================
# reconfort_mask.R — RECONFORT deciduous (OSO) binary mask fetch
# ------------------------------------------------------------
# The RECONFORT map-production step masks its final classification
# and probability rasters with a binary "deciduous vs not" mask so
# the oak/chestnut models only score broadleaf pixels (spec 021
# §10 Q6). By default this is the OSO 2021 deciduous mask shipped in
# the upstream repository (Apache-2.0). At ~54 MB it is too large to
# bundle in `inst/extdata/`, so — like the RF models (L2a) — it is
# fetched on demand, checksum-verified and cached. Users who already
# hold a copy (or a custom mask) pass a path instead.
# ============================================================


#' RECONFORT deciduous (OSO 2021) binary mask registry entry
#'
#' Metadata for the default broadleaf mask used by the RECONFORT
#' map-production step: file size and MD5 used by
#' [ensure_reconfort_oso_mask()] to verify a fetch. The mask is the
#' OSO 2021 deciduous-tree layer redistributed in the upstream
#' repository (`fl.mouret/reconfort`, Apache-2.0).
#'
#' @export
RECONFORT_OSO_MASK <- list(
  file       = "mask_oso_deciduous_compress.tif",
  size_bytes = 56497396,
  md5        = "ea87e929ad67b2e2f9d91f7375d508eb"
)


# Upstream URL for the OSO mask. Overridable via
# `options(nemeton.reconfort_mask_base_url = ...)` for a mirror.
.reconfort_mask_url <- function() {
  base <- getOption(
    "nemeton.reconfort_mask_base_url",
    "https://framagit.org/fl.mouret/reconfort/-/raw/main/masks"
  )
  sprintf("%s/%s", base, RECONFORT_OSO_MASK$file)
}


# Verify a fetched mask against its registry entry (size + MD5).
.reconfort_verify_mask <- function(path, abort = TRUE) {
  size_ok <- file.exists(path) && file.size(path) == RECONFORT_OSO_MASK$size_bytes
  md5_ok  <- size_ok && identical(unname(tools::md5sum(path)), RECONFORT_OSO_MASK$md5)
  ok <- isTRUE(size_ok) && isTRUE(md5_ok)
  if (!ok && abort) {
    cli::cli_abort(c(
      "RECONFORT OSO mask failed verification.",
      x = "Expected size {RECONFORT_OSO_MASK$size_bytes} B, MD5 {RECONFORT_OSO_MASK$md5}.",
      i = "Delete the cached file and retry, or pass a correct {.arg local_path}."
    ))
  }
  ok
}


#' Fetch (and cache) the RECONFORT deciduous (OSO) binary mask
#'
#' Ensures a local copy of the default OSO 2021 deciduous mask used to
#' restrict RECONFORT scoring to broadleaf pixels, and returns its
#' path. Resolution order mirrors [ensure_reconfort_model()]:
#' \enumerate{
#'   \item if `local_path` is given, that file is used directly
#'     (verified unless `verify = FALSE`);
#'   \item else, a verified cached copy is returned without download;
#'   \item else the mask is downloaded, verified and cached.
#' }
#'
#' The mask is ~54 MB; the first fetch is slow. The cache lives under
#' `cache_dir` (default `file.path(get_global_cache_dir(),
#' "reconfort_masks")`).
#'
#' @param cache_dir Cache directory. Default a per-user nemeton cache.
#' @param local_path Optional path to a mask already on disk (e.g. a
#'   custom broadleaf mask, or `<reconfort_clone>/masks/...`). When set,
#'   no download happens and (for a custom mask) verification is skipped
#'   if `verify = FALSE`.
#' @param url Optional explicit download URL overriding the registry
#'   default (from `options(nemeton.reconfort_mask_base_url)`).
#' @param force Re-download even if a valid cached copy exists.
#' @param verify Verify size + MD5 against [RECONFORT_OSO_MASK].
#'   Default `TRUE`. Pass `FALSE` when supplying a custom `local_path`.
#' @param quiet Suppress progress messages. Default `FALSE`.
#'
#' @return The path to the local mask file.
#' @export
ensure_reconfort_oso_mask <- function(cache_dir  = NULL,
                                      local_path = NULL,
                                      url        = NULL,
                                      force      = FALSE,
                                      verify     = TRUE,
                                      quiet      = FALSE) {
  say <- function(...) if (!quiet) cli::cli_alert_info(...)

  # 1) user-provided copy -------------------------------------------
  if (!is.null(local_path)) {
    if (!file.exists(local_path)) {
      cli::cli_abort("{.arg local_path} does not exist: {.path {local_path}}.")
    }
    if (verify) .reconfort_verify_mask(local_path)
    return(normalizePath(local_path))
  }

  # 2) cache resolution ---------------------------------------------
  if (is.null(cache_dir)) {
    cache_dir <- file.path(get_global_cache_dir(), "reconfort_masks")
  }
  dest <- file.path(cache_dir, RECONFORT_OSO_MASK$file)

  if (!force && file.exists(dest)) {
    ok <- if (verify) .reconfort_verify_mask(dest, abort = FALSE) else TRUE
    if (isTRUE(ok)) {
      say("RECONFORT OSO mask already cached.")
      return(dest)
    }
    if (!quiet) {
      cli::cli_alert_warning("Cached RECONFORT OSO mask failed verification; re-downloading.")
    }
  }

  # 3) download -----------------------------------------------------
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  src <- if (is.null(url)) .reconfort_mask_url() else url
  say("Downloading RECONFORT OSO mask (~{round(RECONFORT_OSO_MASK$size_bytes / 1e6)} MB) from {.url {src}} ...")

  tmp <- tempfile(fileext = ".tif")
  ok_dl <- tryCatch({
    suppressWarnings(download.file(src, tmp, mode = "wb", quiet = quiet))
    file.exists(tmp) && file.size(tmp) > 0
  }, error = function(e) {
    if (file.exists(tmp)) unlink(tmp)
    cli::cli_abort(c(
      "Failed to download the RECONFORT OSO mask.",
      x = conditionMessage(e),
      i = "Source: {.url {src}}",
      i = "Or pass {.arg local_path} to use a mask already on disk."
    ))
  })
  if (!isTRUE(ok_dl)) {
    if (file.exists(tmp)) unlink(tmp)
    cli::cli_abort(c(
      "Failed to download the RECONFORT OSO mask (empty or missing file).",
      i = "Source: {.url {src}}"
    ))
  }

  if (verify && !.reconfort_verify_mask(tmp, abort = FALSE)) {
    unlink(tmp)
    cli::cli_abort(c(
      "Checksum mismatch for the downloaded RECONFORT OSO mask.",
      i = "Expected MD5 {RECONFORT_OSO_MASK$md5}.",
      i = "The download may be corrupted or the upstream file has changed."
    ))
  }

  if (!file.rename(tmp, dest)) {
    file.copy(tmp, dest, overwrite = TRUE)
    unlink(tmp)
  }
  say("Cached RECONFORT OSO mask at {.path {dest}}.")
  dest
}
