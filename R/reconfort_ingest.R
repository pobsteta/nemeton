# ============================================================
# reconfort_ingest.R — RECONFORT Sentinel-2 acquisition (L2b.2)
# ------------------------------------------------------------
# IOTA²-native ingestion (cadrage L2b D1): RECONFORT does not reuse
# the FAST COG cache — IOTA² wants raw MUSCATE L2A scenes in its own
# per-tile layout. This module:
#   1. resolves which Sentinel-2 MGRS tile(s) an AOI falls on, from a
#      bundled France tiling grid (no network);
#   2. drives the vendored upstream download (pygeodes/GEODES) and
#      unzip scripts via a subprocess in the conda env, populating the
#      `<s2_root>/extracted/<tile>/` layout the map-production step
#      (L2b.3) consumes.
#
# The actual download needs the conda env (L2b.1) + a GEODES account
# (`pygeodes-config.json`) + tens of GB of S2 — opt-in / out of CI.
# ============================================================


# Session cache for the (small) bundled tiling grid.
.reconfort_tiles_cache <- new.env(parent = emptyenv())


#' Load the bundled Sentinel-2 MGRS tiling grid (metropolitan France)
#'
#' Reads `inst/extdata/s2_mgrs_tiles_fr.geojson` (188 tiles, EPSG:4326)
#' and caches it for the session.
#' @keywords internal
.reconfort_load_s2_tiles <- function() {
  if (is.null(.reconfort_tiles_cache$grid)) {
    p <- system.file("extdata", "s2_mgrs_tiles_fr.geojson", package = "nemeton")
    if (!nzchar(p) || !file.exists(p)) {
      p <- file.path("inst", "extdata", "s2_mgrs_tiles_fr.geojson")  # dev mode
    }
    if (!file.exists(p)) {
      cli::cli_abort(c(
        "Cannot find {.file s2_mgrs_tiles_fr.geojson}.",
        i = "Run {.code Rscript data-raw/build_s2_mgrs_tiles_fr.R} to (re)build it."
      ))
    }
    .reconfort_tiles_cache$grid <- sf::st_read(p, quiet = TRUE)
  }
  .reconfort_tiles_cache$grid
}


#' Sentinel-2 MGRS tile(s) covering an AOI
#'
#' Intersects an area of interest with the bundled France Sentinel-2
#' tiling grid and returns the MGRS tile code(s) the RECONFORT/IOTA²
#' chain must fetch. Entirely local (no network).
#'
#' @param aoi An `sf`/`sfc` polygon (any CRS).
#' @param prefix Prefix codes with `"T"` (e.g. `"T31UDP"`), as IOTA²
#'   and `list_tiles` expect. Default `TRUE`. `FALSE` returns the bare
#'   MGRS code (`"31UDP"`).
#'
#' @return Character vector of tile codes (sorted, deduplicated). Empty
#'   (with a warning) when the AOI falls outside the bundled grid —
#'   RECONFORT is calibrated on Centre-Val de Loire, and the grid
#'   covers metropolitan France.
#' @export
reconfort_aoi_tiles <- function(aoi, prefix = TRUE) {
  if (!inherits(aoi, "sf") && !inherits(aoi, "sfc")) {
    cli::cli_abort("{.arg aoi} must be an sf or sfc object.")
  }
  grid <- .reconfort_load_s2_tiles()
  aoi_g <- sf::st_union(sf::st_transform(sf::st_geometry(aoi), sf::st_crs(grid)))
  hit <- suppressWarnings(
    sf::st_intersects(grid, aoi_g, sparse = FALSE)[, 1]
  )
  tiles <- sort(unique(as.character(grid$tile[hit])))
  if (length(tiles) == 0L) {
    cli::cli_warn(c(
      "The AOI intersects no Sentinel-2 tile in the bundled France grid.",
      i = "RECONFORT covers metropolitan France (Centre-Val de Loire calibration)."
    ))
    return(character(0))
  }
  if (prefix) paste0("T", tiles) else tiles
}


# Serialise an R value to a Python literal for a RECONFORT `.cfg` file
# (`load_config_variable` eval()s each value). Length>1 -> Python list.
.reconfort_py_literal <- function(x) {
  scal <- function(v) {
    if (is.character(v)) paste0("'", gsub("'", "\\\\'", v), "'")
    # R `TRUE`/`FALSE` -> Python `True`/`False` (eval()ed upstream).
    else if (is.logical(v)) if (isTRUE(v)) "True" else "False"
    else as.character(v)
  }
  if (length(x) != 1L) paste0("[", paste(vapply(x, scal, ""), collapse = ", "), "]")
  else scal(x)
}


#' Write a RECONFORT `.cfg` file (`key=<python-literal>` per line)
#' @keywords internal
.reconfort_write_cfg <- function(path, kv) {
  lines <- vapply(names(kv),
                  function(k) paste0(k, "=", .reconfort_py_literal(kv[[k]])),
                  character(1))
  writeLines(lines, path)
  invisible(path)
}


#' Resolve the GEODES account config path
#'
#' Default `options(nemeton.geodes_config)`, else
#' `<user_data_dir>/nemeton/pygeodes-config.json`. Aborts if missing.
#' @keywords internal
.reconfort_geodes_config <- function(path = NULL) {
  if (is.null(path)) {
    path <- getOption("nemeton.geodes_config")
  }
  if (is.null(path)) {
    base <- if (requireNamespace("rappdirs", quietly = TRUE)) {
      rappdirs::user_data_dir("nemeton", "nemeton")
    } else {
      file.path(Sys.getenv("HOME"), ".local", "share", "nemeton")
    }
    path <- file.path(base, "pygeodes-config.json")
  }
  if (!file.exists(path)) {
    cli::cli_abort(c(
      "GEODES account config not found: {.path {path}}.",
      i = "Create a GEODES account ({.url https://geodes-portal.cnes.fr/}), an API key, and a {.file pygeodes-config.json}.",
      i = "Then set {.code options(nemeton.geodes_config = \"<path>\")} or pass {.arg geodes_config}."
    ))
  }
  normalizePath(path)
}


# Materialise a per-run pygeodes account config whose `download_dir`
# points at `download_dir` (the per-tile zip dir, inside the project
# cache `s2_root` — same caller-supplied convention as FORDEAD's
# `cache_dir`). The upstream `run_geodes_download.py` calls
# `geodes.download_item_archive(item)`, which downloads to the pygeodes
# Config's `download_dir` — NOT to the cfg's `zip_path` that
# `run_process_downloaded_images.py` later globs. Without this override
# the two steps disagree on the path and the unzip finds nothing.
#
# The config carries the GEODES api_key, so — unlike the downloaded data
# — it must NOT live in the project cache. We copy the user's JSON
# (api_key et al. intact), swap only `download_dir`, and write it to a
# private tempfile (mode 600). Never logged. The caller unlinks it once
# the tile is done. Returns the tempfile path.
.reconfort_account_with_download_dir <- function(account, download_dir) {
  conf <- jsonlite::read_json(account, simplifyVector = TRUE)
  conf$download_dir <- paste0(normalizePath(download_dir, mustWork = FALSE), "/")
  # `jsonlite::read_json()` turns JSON `null` into a zero-length list, which
  # `write_json()` then re-serialises as `{}` — and pygeodes' S3 archive
  # download feeds `aws_access_key_id` et al. straight to botocore, which
  # raises `TypeError: expected str instance, dict found` when they are `{}`
  # instead of `null`. (Item *search* ignores these fields, so only the
  # download breaks — silently, via the upstream bare `except`.) Restore the
  # null-valued keys to JSON `null` so botocore sees `None`.
  empty <- lengths(conf) == 0L
  if (any(empty)) conf[empty] <- NA
  out <- tempfile("pygeodes-config-", fileext = ".json")
  jsonlite::write_json(conf, out, auto_unbox = TRUE, na = "null", pretty = TRUE)
  Sys.chmod(out, mode = "0600")
  out
}


# Free bytes available on the filesystem holding `path` (POSIX `df -Pk`,
# Available column). Returns `NA_real_` when it cannot be determined (no
# `df`, parse failure) so callers treat the disk guard as best-effort.
.reconfort_free_bytes <- function(path) {
  # Walk up to the nearest existing ancestor (the leaf may not exist yet).
  while (nzchar(path) && !file.exists(path)) {
    parent <- dirname(path)
    if (identical(parent, path)) break
    path <- parent
  }
  out <- tryCatch(
    system2("df", c("-Pk", shQuote(path)), stdout = TRUE, stderr = FALSE),
    error = function(e) character(0), warning = function(w) character(0))
  if (length(out) < 2L) return(NA_real_)
  fields <- strsplit(trimws(out[length(out)]), "\\s+")[[1]]
  avail_k <- suppressWarnings(as.numeric(fields[4]))  # df -P: col 4 = Available (1K)
  if (is.na(avail_k)) return(NA_real_)
  avail_k * 1024
}


# `PYTHONWARNINGS` filter silencing two floods of benign warnings from the
# downloader's deps that would otherwise drown real messages:
#   - pygeodes' per-item "file with same content already exists, skipping
#     download" `UserWarning` (one per cached scene — up to 140/tile);
#   - urllib3's `InsecureRequestWarning` (pygeodes calls the CNES GEODES
#     portal with TLS verification disabled — upstream's choice).
# The urllib3 warning is matched by *message* ("Unverified HTTPS request"),
# not by category: a `category::module` filter referencing `urllib3.exceptions`
# is rejected at interpreter startup ("Invalid -W option ignored: invalid
# module name") because the third-party module is not importable that early.
# A message filter needs no import. Python errors, tracebacks and the scripts'
# own stdout are untouched, so genuine failures still surface.
.RECONFORT_PYWARN <- "ignore::UserWarning,ignore:Unverified HTTPS request"


# Run a vendored RECONFORT python script in the conda env, from the
# glue dir so its `from utils.utils import ...` resolves. Returns the
# exit status (0 = success). Separated out so tests can mock it.
.reconfort_run_py <- function(conda_bin, env, script, cfg, workdir, quiet = FALSE) {
  withr::with_envvar(
    c(PYTHONWARNINGS = .RECONFORT_PYWARN),
    withr::with_dir(workdir, {
      suppressWarnings(system2(
        conda_bin,
        args = c("run", "-n", env, "python", basename(script),
                 "-config_file", shQuote(cfg)),
        stdout = if (quiet) FALSE else "", stderr = if (quiet) FALSE else ""
      ))
    })
  )
}


# List the GEODES S2 items for a tile + date range (one search) via the
# nemeton-authored `list_s2_items.py`, returning the parsed manifest as a
# data.frame (idx, item_id, datetime, filesize, json). The script writes one
# STAC JSON per item under `manifest_dir` so the archives can be fetched one
# at a time (no re-search). Separated out so tests can mock it.
.reconfort_list_s2_items <- function(conda_bin, env, glue, cfg, manifest_dir,
                                     quiet = FALSE) {
  st <- .reconfort_run_py(conda_bin, env,
                          file.path(glue, "list_s2_items.py"),
                          cfg, glue, quiet = quiet)
  if (!identical(as.integer(st), 0L)) {
    cli::cli_abort("S2 item listing failed (exit {st}).")
  }
  mf <- file.path(manifest_dir, "manifest.json")
  if (!file.exists(mf)) cli::cli_abort("S2 item manifest not produced ({.path {mf}}).")
  jsonlite::read_json(mf, simplifyVector = TRUE)
}


# Download ONE S2 archive (reconstructed from its STAC JSON) to `outfile`,
# via the nemeton-authored `download_s2_item.py`. Same `PYTHONWARNINGS`
# filter as the bulk runner. Returns the exit status. Mockable in tests.
.reconfort_download_s2_item <- function(conda_bin, env, glue, account, item_json,
                                        outfile, quiet = FALSE) {
  withr::with_envvar(
    c(PYTHONWARNINGS = .RECONFORT_PYWARN),
    withr::with_dir(glue, {
      suppressWarnings(system2(
        conda_bin,
        args = c("run", "-n", env, "python", "download_s2_item.py",
                 "-account", shQuote(account),
                 "-item_json", shQuote(item_json),
                 "-outfile", shQuote(outfile)),
        stdout = if (quiet) FALSE else "", stderr = if (quiet) FALSE else ""
      ))
    })
  )
}


#' Acquire Sentinel-2 scenes for an AOI into the IOTA² layout
#'
# Stream one tile's S2 ingestion: one GEODES search -> per item
# download -> R unzip -> AOI crop -> delete (archive + full scene). Peak
# disk ~ a single archive. Idempotent: a per-item marker under
# <s2_root>/ingested/<tile>/ lets a re-run skip already-cropped scenes.
# Returns out_dir, the per-tile AOI-cropped extraction dir.
.reconfort_ingest_tile_streaming <- function(tile, bare, aoi, date_from, date_to,
                                             s2_root, zip_dir, out_dir, account,
                                             s2_collection, target_crs, buffer_m,
                                             conda_bin, env, glue, quiet = FALSE,
                                             progress_callback = NULL) {
  emit <- function(payload) {
    if (is.null(progress_callback)) return(invisible(NULL))
    tryCatch(progress_callback(payload), error = function(e) invisible(NULL))
  }
  win          <- .reconfort_aoi_window(aoi, target_crs, buffer_m)
  manifest_dir <- file.path(s2_root, "manifest", tile)
  marker_dir   <- file.path(s2_root, "ingested", tile)
  scratch_root <- file.path(s2_root, "scratch", tile)
  dir.create(manifest_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(marker_dir, recursive = TRUE, showWarnings = FALSE)

  # Sanitised per-run account (api_key tempfile, botocore null-fix). The
  # download_dir is irrelevant here — each download passes an explicit
  # `-outfile` — but the sanitiser still applies the null-fix.
  account_run <- .reconfort_account_with_download_dir(account, zip_dir)
  on.exit(unlink(account_run, force = TRUE), add = TRUE)

  cfg <- tempfile(fileext = ".cfg")
  .reconfort_write_cfg(cfg, list(
    tile                       = c(bare, tile),
    path_to_cfg_geodes_account = account_run,
    s2_collection              = s2_collection,
    start                      = date_from,
    end                        = date_to,
    manifest_dir               = manifest_dir
  ))

  if (!quiet) cli::cli_alert_info(
    "RECONFORT: listing S2 items for tile {.val {tile}} ...")
  manifest <- .reconfort_list_s2_items(conda_bin, env, glue, cfg, manifest_dir, quiet)
  n_items  <- if (is.data.frame(manifest)) nrow(manifest) else length(manifest)
  if (n_items == 0L) {
    cli::cli_abort(c(
      "No Sentinel-2 item found for tile {.val {tile}} ({date_from}..{date_to}).",
      i = "Check the GEODES collection id and the date range."
    ))
  }
  if (!quiet) cli::cli_alert_info(
    "RECONFORT: tile {.val {tile}} — {n_items} S2 scene{?s} to ingest.")
  emit(list(current = "reconfort:ingest_listed", tile = tile,
            total = as.integer(n_items)))

  item_dates <- if (!is.null(manifest$datetime)) {
    substr(as.character(manifest$datetime), 1L, 10L)
  } else rep(NA_character_, n_items)

  n_done <- 0L; n_skip <- 0L; n_fail <- 0L
  for (i in seq_len(n_items)) {
    item_id   <- as.character(manifest$item_id[i])
    item_json <- as.character(manifest$json[i])
    item_date <- item_dates[i]
    safe      <- gsub("[^A-Za-z0-9._-]", "_", item_id)
    marker    <- file.path(marker_dir, paste0(safe, ".done"))
    if (file.exists(marker)) {                                   # idempotence
      n_skip <- n_skip + 1L
      emit(list(current = "reconfort:ingest_item", tile = tile, step = "cached",
                completed = as.integer(i), total = as.integer(n_items),
                item_date = item_date))
      next
    }

    tmp_zip <- file.path(zip_dir, paste0(safe, ".zip"))
    scratch <- file.path(scratch_root, safe)
    unlink(tmp_zip, force = TRUE)
    unlink(scratch, recursive = TRUE, force = TRUE)
    dir.create(scratch, recursive = TRUE, showWarnings = FALSE)

    if (!quiet) cli::cli_alert_info(
      "RECONFORT: {tile} {i}/{n_items} downloading{if (!is.na(item_date)) paste0(' ', item_date) else ''} ...")
    emit(list(current = "reconfort:ingest_item", tile = tile, step = "download",
              completed = as.integer(i), total = as.integer(n_items),
              item_date = item_date))

    dl <- .reconfort_download_s2_item(conda_bin, env, glue, account_run,
                                      item_json, tmp_zip, quiet)
    # A dropped connection / bad item must not kill the tile: log + skip.
    if (!identical(as.integer(dl), 0L) || !file.exists(tmp_zip) ||
        file.size(tmp_zip) == 0) {
      if (!quiet) cli::cli_alert_warning(
        "RECONFORT: download failed for item {.val {item_id}}; skipping.")
      n_fail <- n_fail + 1L
      emit(list(current = "reconfort:ingest_item", tile = tile, step = "failed",
                completed = as.integer(i), total = as.integer(n_items),
                item_date = item_date))
      unlink(tmp_zip, force = TRUE); unlink(scratch, recursive = TRUE, force = TRUE)
      next
    }

    if (!quiet) cli::cli_alert_info(
      "RECONFORT: {tile} {i}/{n_items} extracting + cropping to AOI ...")
    emit(list(current = "reconfort:ingest_item", tile = tile, step = "crop",
              completed = as.integer(i), total = as.integer(n_items),
              item_date = item_date))
    suppressWarnings(utils::unzip(tmp_zip, exdir = scratch))
    sub_scenes <- list.dirs(scratch, recursive = FALSE)
    if (length(sub_scenes) == 0L) {
      if (!quiet) cli::cli_alert_warning(
        "RECONFORT: empty/corrupt archive for item {.val {item_id}}; skipping.")
      n_fail <- n_fail + 1L
      emit(list(current = "reconfort:ingest_item", tile = tile, step = "failed",
                completed = as.integer(i), total = as.integer(n_items),
                item_date = item_date))
      unlink(tmp_zip, force = TRUE); unlink(scratch, recursive = TRUE, force = TRUE)
      next
    }
    for (sc in sub_scenes) {
      .reconfort_crop_scene_to_aoi(sc, file.path(out_dir, basename(sc)),
                                   win, target_crs)
    }
    unlink(tmp_zip, force = TRUE); unlink(scratch, recursive = TRUE, force = TRUE)
    file.create(marker)
    n_done <- n_done + 1L
    if (!quiet) cli::cli_alert_info("RECONFORT: {tile} {i}/{n_items} cropped to AOI.")
    emit(list(current = "reconfort:ingest_item", tile = tile, step = "done",
              completed = as.integer(i), total = as.integer(n_items),
              item_date = item_date))
  }
  unlink(scratch_root, recursive = TRUE, force = TRUE)

  scenes <- list.dirs(out_dir, recursive = FALSE)
  if (length(scenes) == 0L) {
    cli::cli_abort(c(
      "RECONFORT: no scene cropped for tile {.val {tile}}.",
      i = "{n_fail} item{?s} failed to download/extract; check connectivity to {.url https://geodes-portal.cnes.fr/} and re-run."
    ))
  }
  if (!quiet) cli::cli_alert_success(
    "RECONFORT: tile {.val {tile}} — {length(scenes)} scene{?s} cropped to AOI ({n_skip} cached, {n_fail} failed).")
  out_dir
}


#' Acquire Sentinel-2 scenes for an AOI into the IOTA² layout
#'
#' IOTA²-native ingestion. Two modes:
#'
#' * **AOI streaming** (when `aoi` is supplied — the production path):
#'   one GEODES search per tile, then each archive is downloaded,
#'   extracted, **clipped + reprojected to the AOI window** and deleted
#'   one at a time. Peak disk stays near a single archive (~a few GB)
#'   instead of *whole-tile archives + whole-tile extracted* (~460 GB for
#'   one tile over two years). The output `<s2_root>/extracted/<tile>/` is
#'   already AOI-cropped in `target_crs`, so the separate post-extraction
#'   crop is no longer needed.
#' * **Full tile** (when `aoi` is `NULL`): downloads the MUSCATE L2A
#'   archives for each `tiles` entry and unzips the whole tile into
#'   `<s2_root>/extracted/<tile>/` (the v0.94.x behaviour).
#'
#' Requires the conda environment (L2b.1) and a GEODES account; heavy and
#' opt-in (not run in CI).
#'
#' @param aoi An `sf`/`sfc` AOI. When supplied, scenes are streamed and
#'   clipped to the AOI window (production path); also used to resolve
#'   `tiles` when those are `NULL`. When `NULL`, the full tile is ingested.
#' @param tiles Explicit MGRS tile code(s) (e.g. `"T31UDP"`); resolved
#'   from `aoi` when `NULL`.
#' @param date_from,date_to Date range (`"YYYY-MM-DD"`). RECONFORT needs
#'   two full years.
#' @param s2_root Root directory for the S2 data (zip + extracted).
#' @param geodes_config Path to `pygeodes-config.json` (see
#'   [.reconfort_geodes_config]). Default resolves the option / user dir.
#' @param s2_collection GEODES collection id. Default
#'   `"THEIA_REFLECTANCE_SENTINEL2_L2A"` — the THEIA/MUSCATE Sentinel-2
#'   surface-reflectance L2A products. (The bare `MUSCATE_*` name from the
#'   upstream RECONFORT example is not a valid GEODES id and 400s.)
#' @param target_crs Integer EPSG of the AOI-streaming output projection
#'   (default 2154). Ignored in full-tile mode.
#' @param buffer_m Numeric buffer (m) around the AOI bbox for the clip
#'   window (default 3000). Ignored in full-tile mode.
#' @param keep_zips Full-tile mode only: keep the downloaded `.zip`
#'   archives after extraction. Default `FALSE` (each archive is deleted as
#'   soon as it is extracted, capping peak disk). In AOI-streaming mode the
#'   archives are always streamed and removed.
#' @param quiet Suppress progress + subprocess output. Default `FALSE`.
#' @param progress_callback Optional function called with a named list at
#'   each step of the AOI-streaming ingest, so a caller (e.g. the Shiny
#'   app) can surface per-scene progress. Events: `reconfort:ingest_listed`
#'   (`tile`, `total`) once the manifest is known, then
#'   `reconfort:ingest_item` per scene (`tile`, `completed`, `total`,
#'   `step` one of `"download"`/`"crop"`/`"done"`/`"cached"`/`"failed"`,
#'   `item_date`). Ignored in full-tile mode.
#'
#' @return Invisibly, a list: `tiles`, `s2_root`, and `extracted` (the
#'   per-tile extraction directories), for the L2b.3 map-production step.
#' @export
reconfort_ingest_s2 <- function(aoi = NULL, tiles = NULL,
                                date_from, date_to,
                                s2_root,
                                geodes_config = NULL,
                                s2_collection = "THEIA_REFLECTANCE_SENTINEL2_L2A",
                                target_crs = 2154,
                                buffer_m = .RECONFORT_AOI_BUFFER_M,
                                keep_zips = FALSE,
                                quiet = FALSE,
                                progress_callback = NULL) {
  if (is.null(tiles)) {
    if (is.null(aoi)) cli::cli_abort("Provide either {.arg aoi} or {.arg tiles}.")
    tiles <- reconfort_aoi_tiles(aoi, prefix = TRUE)
    if (length(tiles) == 0L) cli::cli_abort("No Sentinel-2 tile resolved for the AOI.")
  }

  env       <- .ensure_reconfort_python(require_pygeodes = TRUE, quiet = quiet)
  conda_bin <- .reconfort_conda_binary()
  account   <- .reconfort_geodes_config(geodes_config)
  glue      <- .reconfort_glue_dir()

  extracted <- character(0)
  for (tile in tiles) {
    bare    <- sub("^T", "", tile)
    zip_dir <- file.path(s2_root, "zip", tile)
    out_dir <- file.path(s2_root, "extracted", tile)
    dir.create(zip_dir, recursive = TRUE, showWarnings = FALSE)
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

    if (!is.null(aoi)) {
      # AOI streaming: list once, then download+extract+crop+delete each
      # archive in turn so peak disk stays near a single archive.
      extracted <- c(extracted, .reconfort_ingest_tile_streaming(
        tile = tile, bare = bare, aoi = aoi, date_from = date_from,
        date_to = date_to, s2_root = s2_root, zip_dir = zip_dir,
        out_dir = out_dir, account = account, s2_collection = s2_collection,
        target_crs = target_crs, buffer_m = buffer_m,
        conda_bin = conda_bin, env = env, glue = glue, quiet = quiet,
        progress_callback = progress_callback))
      next
    }

    # Force pygeodes to download into zip_dir so the unzip step finds
    # the archives there (see .reconfort_account_with_download_dir).
    # Holds the api_key -> private tempfile, wiped at end of iteration.
    account_run <- .reconfort_account_with_download_dir(account, zip_dir)
    on.exit(unlink(account_run, force = TRUE), add = TRUE)

    cfg <- tempfile(fileext = ".cfg")
    .reconfort_write_cfg(cfg, list(
      tile                       = c(bare, tile),  # query both forms
      path_to_cfg_geodes_account = account_run,
      s2_collection              = s2_collection,
      start                      = date_from,
      end                        = date_to,
      zip_path                   = zip_dir,
      out_dir                    = out_dir,
      # Drives extract-then-delete in run_process_downloaded_images.py.
      delete_zip_after_extract   = !keep_zips
    ))

    if (!quiet) cli::cli_alert_info("RECONFORT: downloading S2 for tile {.val {tile}} ...")
    st1 <- .reconfort_run_py(conda_bin, env,
                             file.path(glue, "run_geodes_download.py"),
                             cfg, glue, quiet = quiet)
    if (!identical(as.integer(st1), 0L)) {
      cli::cli_abort("S2 download failed for tile {.val {tile}} (exit {st1}).")
    }
    # The upstream downloader wraps each item in a bare `except` that
    # prints "Error downloading image" and still exits 0 — a dropped
    # connection on a multi-GB archive (ChunkedEncodingError) thus looks
    # like success. Verify an archive actually landed before trusting it.
    zips <- list.files(zip_dir, pattern = "(?i)SENTINEL.*\\.zip$", full.names = TRUE)
    if (length(zips) == 0L) {
      cli::cli_abort(c(
        "S2 download produced no archive for tile {.val {tile}}.",
        i = "The upstream downloader swallows network errors; a single THEIA L2A archive is ~2 GB and the GEODES connection may have dropped.",
        i = "Check connectivity to {.url https://geodes-portal.cnes.fr/} and re-run; partial files in {.path {zip_dir}} can be deleted first."
      ))
    }

    # Pre-flight disk guard. Extraction is the big consumer (a full tile
    # over two years is ~250 GB) and `zipfile.extractall` dies with an
    # opaque exit 1 (OSError [Errno 28]) when the disk fills mid-way.
    # Estimate the extracted footprint from the archives (~1.3x, SRE files
    # are dropped) and require the headroom *before* extracting. With
    # extract-then-delete on (default), each archive is freed as it is
    # extracted, so the net additional space is only the excess of
    # extracted over zips plus a couple of in-flight archives.
    zip_bytes <- sum(file.size(zips))
    max_zip   <- max(file.size(zips))
    extracted_est <- 1.3 * zip_bytes
    need <- if (keep_zips) extracted_est else max(extracted_est - zip_bytes, 3 * max_zip)
    free <- .reconfort_free_bytes(out_dir)
    if (!is.na(free) && free < need) {
      gb <- function(b) sprintf("%.1f GB", b / 1e9)
      cli::cli_abort(c(
        "Not enough free disk space to extract S2 archives for tile {.val {tile}}.",
        i = "Need ~{gb(need)} free in {.path {out_dir}}, but only {gb(free)} available ({length(zips)} archive{?s}, {gb(zip_bytes)} of zips).",
        i = if (keep_zips) "Re-run with {.code keep_zips = FALSE} (the default) to free each archive as it is extracted, or free disk space."
            else "Free disk space (older project caches, the system temp dir) and re-run; already-extracted scenes are kept."
      ))
    }

    st2 <- .reconfort_run_py(conda_bin, env,
                             file.path(glue, "run_process_downloaded_images.py"),
                             cfg, glue, quiet = quiet)
    if (!identical(as.integer(st2), 0L)) {
      cli::cli_abort("S2 unzip failed for tile {.val {tile}} (exit {st2}).")
    }
    scenes <- list.dirs(out_dir, recursive = FALSE)
    if (length(scenes) == 0L) {
      cli::cli_abort(c(
        "S2 unzip produced no scene folder for tile {.val {tile}} in {.path {out_dir}}.",
        i = "The {length(zips)} archive{?s} in {.path {zip_dir}} may be truncated (incomplete download)."
      ))
    }
    if (!quiet) cli::cli_alert_success(
      "RECONFORT: tile {.val {tile}} — {length(zips)} archive{?s}, {length(scenes)} scene{?s}.")
    extracted <- c(extracted, out_dir)
  }

  if (!quiet) cli::cli_alert_success("RECONFORT: S2 ready for {length(tiles)} tile{?s}.")
  invisible(list(tiles = tiles, s2_root = s2_root, extracted = extracted))
}
