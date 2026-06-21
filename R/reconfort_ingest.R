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
    if (is.character(v)) paste0("'", gsub("'", "\\\\'", v), "'") else as.character(v)
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


# Run a vendored RECONFORT python script in the conda env, from the
# glue dir so its `from utils.utils import ...` resolves. Returns the
# exit status (0 = success). Separated out so tests can mock it.
.reconfort_run_py <- function(conda_bin, env, script, cfg, workdir, quiet = FALSE) {
  withr::with_dir(workdir, {
    suppressWarnings(system2(
      conda_bin,
      args = c("run", "-n", env, "python", basename(script),
               "-config_file", shQuote(cfg)),
      stdout = if (quiet) FALSE else "", stderr = if (quiet) FALSE else ""
    ))
  })
}


#' Acquire Sentinel-2 scenes for an AOI into the IOTA² layout
#'
#' IOTA²-native ingestion: for each tile covering `aoi` (or each tile
#' in `tiles`), downloads the MUSCATE L2A archives from GEODES via the
#' vendored `pygeodes` driver, then unzips them into
#' `<s2_root>/extracted/<tile>/`. Requires the conda environment
#' (L2b.1) and a GEODES account; heavy and opt-in (not run in CI).
#'
#' @param aoi An `sf`/`sfc` AOI. Ignored when `tiles` is given.
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
#' @param quiet Suppress progress + subprocess output. Default `FALSE`.
#'
#' @return Invisibly, a list: `tiles`, `s2_root`, and `extracted` (the
#'   per-tile extraction directories), for the L2b.3 map-production step.
#' @export
reconfort_ingest_s2 <- function(aoi = NULL, tiles = NULL,
                                date_from, date_to,
                                s2_root,
                                geodes_config = NULL,
                                s2_collection = "THEIA_REFLECTANCE_SENTINEL2_L2A",
                                quiet = FALSE) {
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
      out_dir                    = out_dir
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
