#' Compute and persist a FAST alert mask on the 0-4 categorical scale
#'
#' Builds a discretised **0-4 categorical** SpatRaster of FAST alerts
#' from the continuous output of [read_fast_alert_raster()] (spec 013)
#' and **persists it to disk** so that downstream consumers
#' (validation sampling, app reactives) can read it back via
#' [read_fast_alert_mask()] without recomputing.
#'
#' The 0-4 scale is **aligned with the FORDEAD `dieback_mask`** so that
#' [fordead_alert_mask()] and [create_validation_sampling_plan()]
#' consume FAST and FORDEAD rasters uniformly.
#'
#' Default discretisation (in `mode = "count"`):
#'
#' | Pixel value (alert days) | Class |
#' |---|---|
#' | 0           | 0 — pas d'alerte |
#' | 1-2         | 1 — trace |
#' | 3-5         | 2 — moyenne |
#' | 6-10        | 3 — forte |
#' | > 10        | 4 — très forte |
#'
#' Pass a custom `breaks` to override (e.g. percentile-based for
#' `mode = "rolling"` where the value is a continuous deficit
#' magnitude with no natural bin sizes).
#'
#' @param con A `DBIConnection`. Passed to [read_fast_alert_raster()].
#' @param zone_id Integer scalar.
#' @param index Character scalar `"NDVI"`, `"NBR"`, `"NDMI"` or `"NDRE"`
#'   — the single index the alert map is built from (spec 017 / 019 /
#'   022). Default is mode-dependent when omitted: `"NDVI"` for count /
#'   rolling, `"NDMI"` for trend (mirror of [read_fast_alert_raster()]).
#' @param threshold Numeric in `(0, 1)` or `NULL`. Passed through to
#'   [read_fast_alert_raster()]; `NULL` resolves per `index`
#'   (NDVI 0.40, NBR/NDMI/NDRE 0.30). Ignored when `mode = "trend"`.
#' @param date_from,date_to Date (or character `"YYYY-MM-DD"`) bounding
#'   the analysis window.
#' @param mode One of `"count"`, `"rolling"` or `"trend"` (spec 023).
#'   Default `"count"`.
#' @param window_days Integer. Trailing window length, used in
#'   `"rolling"` mode. Default `30L`.
#' @param months,min_years,min_obs_per_year,alpha Trend-mode parameters
#'   (spec 023), passed through to [read_fast_alert_raster()]. Seasonal
#'   month window (default `6:9`), minimum valid composite years
#'   (`4L`), minimum clear observations per year (`2L`), and Mann-Kendall
#'   significance level (`0.05`). Ignored in count / rolling mode.
#' @param cache_dir Path to the S2 COG cache.
#' @param mask_cache_dir Path to the FAST mask cache root. The mask is
#'   written under `<mask_cache_dir>/zone_<id>/fast_alert_<ts>.tif`.
#'   Defaults to a `fast/` sibling of `cache_dir` (i.e.
#'   `<project>/cache/layers/fast/`). Masks are timestamped (one file per
#'   call); at most `getOption("nemeton.fast_mask_keep", 20)` are kept per
#'   zone (LRU by mtime), so the directory does not grow unbounded.
#' @param breaks Numeric vector of break points to discretise the
#'   continuous alert raster into the 0-4 scale. **5 cut points** are
#'   expected (defines bins `(-Inf, b1], (b1, b2], ..., (b4, Inf]`).
#'   When `NULL` (default, spec 017) the breaks are computed as
#'   **quartiles of the strictly-positive pixels**: class 0 = no alert
#'   (value 0), classes 1-4 = the quartile bins
#'   `c(0, q25, q50, q75, Inf)` of pixels with at least one alert. This
#'   adaptive scheme applies to **all** modes (`"count"`, `"rolling"`,
#'   `"trend"`) — for trend the strictly-positive pixels are the
#'   significant-decline magnitudes.
#'   Degenerate distributions (tied quantiles) collapse to fewer
#'   occupied classes rather than erroring; an all-zero raster maps
#'   entirely to class 0.
#' @param cache_result,result_cache_dir Passed through to
#'   [read_fast_alert_raster()] (spec 017 D6): whether to persist the
#'   underlying continuous raster as a content-addressed COG, and where.
#' @param parallel Passed through to [read_fast_alert_raster()] (spec 017
#'   D4): optional multi-core per-scene raster compute via \pkg{furrr}.
#'
#' @return Invisibly, the absolute path to the persisted TIF, or
#'   `NULL` if [read_fast_alert_raster()] returned `NULL` (no scene
#'   in the window or empty cache).
#'
#' @seealso [read_fast_alert_mask()] (the strict reader, mirror of
#'   [read_fordead_dieback_mask()]), [read_fast_alert_raster()] (the
#'   continuous live compute), [fordead_alert_mask()] (the cell
#'   selector that consumes the persisted 0-4 mask).
#'
#' @export
compute_fast_alert_mask <- function(con, zone_id,
                                    index          = c("NDVI", "NBR", "NDMI", "NDRE"),
                                    threshold      = NULL,
                                    date_from, date_to,
                                    mode           = c("count", "rolling", "trend"),
                                    window_days    = 30L,
                                    months           = 6:9,
                                    min_years        = 4L,
                                    min_obs_per_year = 2L,
                                    alpha            = 0.05,
                                    cache_dir,
                                    mask_cache_dir  = NULL,
                                    breaks          = NULL,
                                    apply_zone_mask = TRUE,
                                    mask_polygon    = NULL,
                                    cache_result     = TRUE,
                                    result_cache_dir = NULL,
                                    parallel         = FALSE) {
  mode  <- match.arg(mode)
  # Mode-dependent default index (mirror of read_fast_alert_raster):
  # NDVI for count/rolling, NDMI for trend. Explicit `index` wins.
  if (missing(index)) {
    index <- if (mode == "trend") "NDMI" else "NDVI"
  } else {
    index <- match.arg(index, c("NDVI", "NBR", "NDMI", "NDRE"))
  }
  if (!requireNamespace("terra", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg terra} required.")
  }
  if (length(zone_id) != 1L || is.na(zone_id) ||
      !is.finite(suppressWarnings(as.numeric(zone_id)))) {
    cli::cli_abort("{.arg zone_id} must be a single non-NA integer.")
  }
  zid <- as.integer(zone_id)

  # Derive mask_cache_dir from cache_dir when not provided. Mirrors the
  # convention used by `run_fordead_dieback()` for `<...>/fordead/`.
  if (is.null(mask_cache_dir)) {
    mask_cache_dir <- file.path(dirname(cache_dir), "fast")
  }
  if (!dir.exists(mask_cache_dir)) {
    dir.create(mask_cache_dir, recursive = TRUE, showWarnings = FALSE)
  }
  zone_dir <- file.path(mask_cache_dir, sprintf("zone_%d", zid))
  if (!dir.exists(zone_dir)) {
    dir.create(zone_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # An explicitly-supplied `breaks` is validated up front; the default
  # (quartiles) is computed below, once the continuous raster exists.
  if (!is.null(breaks) && (!is.numeric(breaks) || length(breaks) != 5L)) {
    cli::cli_abort("{.arg breaks} must be a numeric vector of length 5 (5 cut points).")
  }

  # spec 016 — propagate the UGF mask to the underlying continuous
  # raster *before* discretisation. The persisted 0-4 mask thus
  # already has NA outside the UGFs (compact on disk via DEFLATE,
  # and the reader doesn't need to re-mask).
  cont <- read_fast_alert_raster(
    con             = con,
    zone_id         = zid,
    index           = index,
    threshold       = threshold,
    date_from       = date_from,
    date_to         = date_to,
    mode            = mode,
    window_days      = window_days,
    months           = months,
    min_years        = min_years,
    min_obs_per_year = min_obs_per_year,
    alpha            = alpha,
    cache_dir        = cache_dir,
    apply_zone_mask  = apply_zone_mask,
    mask_polygon     = mask_polygon,
    cache_result     = cache_result,
    result_cache_dir = result_cache_dir,
    parallel         = parallel
  )
  if (is.null(cont)) {
    cli::cli_alert_info("No FAST alert raster to persist for zone {.val {zid}}.")
    return(invisible(NULL))
  }

  # spec 017 (D2) — adaptive quartile breaks on the strictly-positive
  # pixels. Class 0 = no alert (value 0); classes 1-4 = the quartile
  # bins of pixels that have at least one alert. Same scheme for count
  # and rolling.
  if (is.null(breaks)) {
    breaks <- .fast_alert_quartile_breaks(cont)
  }

  # Discretise: 0 for value <= breaks[1] (= 0 by default), then 1..4
  # for the upper bins. `terra::classify` matrix: from, to, becomes.
  rcl <- matrix(c(
    -Inf,      breaks[1L], 0,
    breaks[1L], breaks[2L], 1,
    breaks[2L], breaks[3L], 2,
    breaks[3L], breaks[4L], 3,
    breaks[4L], breaks[5L], 4
  ), ncol = 3, byrow = TRUE)
  mask <- terra::classify(cont, rcl, include.lowest = TRUE, right = TRUE)
  mask <- terra::as.int(mask)
  names(mask) <- "fast_alert_class"

  ts <- format(Sys.time(), "%Y%m%dT%H%M%S")
  out_path <- file.path(zone_dir, sprintf("fast_alert_%s.tif", ts))
  tryCatch(
    terra::writeRaster(mask, out_path,
                       filetype  = "GTiff",
                       overwrite = TRUE,
                       datatype  = "INT1U",
                       gdal      = c("COMPRESS=DEFLATE", "PREDICTOR=2",
                                     "TILED=YES")),
    error = function(e) {
      cli::cli_warn("Failed to persist FAST alert mask at {.path {out_path}}: {conditionMessage(e)}")
      out_path <<- NA_character_
    }
  )
  # Unlike the content-addressed continuous cache, masks are timestamped
  # (`fast_alert_<ts>.tif`) so every call writes a new file and the dir
  # grows unbounded. Trim to the most recent `keep` masks (LRU by mtime),
  # mirroring `.fast_raster_gc()` for the continuous COGs.
  if (!is.na(out_path)) .fast_alert_mask_gc(zone_dir)
  invisible(out_path)
}

# Keep at most `keep` discretised 0-4 masks per zone directory (LRU by
# mtime). Targets ONLY `fast_alert_<ts>.tif` files, so it never touches the
# continuous COGs (`fast_<INDEX>_*`) that share the directory when
# `mask_cache_dir == result_cache_dir` (the validation-sampling case).
.fast_alert_mask_gc <- function(zone_dir,
                                keep = getOption("nemeton.fast_mask_keep", 20L)) {
  files <- list.files(zone_dir, pattern = "^fast_alert_.*\\.tif$",
                      full.names = TRUE)
  if (length(files) <= keep) return(invisible(NULL))
  mt  <- file.info(files)$mtime
  old <- files[order(mt, decreasing = TRUE)][-seq_len(keep)]
  unlink(old)
  invisible(NULL)
}


# spec 017 (D2) — 0-4 discretisation breaks from quartiles of the
# strictly-positive pixels of `cont`. Returns 5 cut points
# `c(0, q25, q50, q75, Inf)`: the bin `(-Inf, 0]` is class 0 (no alert),
# then the four quartile bins are classes 1-4. An all-zero / all-NA
# raster yields `c(0, 1, 2, 3, Inf)` (every pixel falls in class 0).
# Tied quantiles are kept as-is — they make the corresponding upper
# bins empty (fewer occupied classes), never an error.
.fast_alert_quartile_breaks <- function(cont) {
  vals <- terra::values(cont, mat = FALSE)
  pos  <- vals[!is.na(vals) & vals > 0]
  if (!length(pos)) return(c(0, 1, 2, 3, Inf))
  qs <- as.numeric(stats::quantile(pos, probs = c(.25, .5, .75),
                                   names = FALSE, type = 7))
  c(0, qs, Inf)
}


#' Read the most recent FAST alert mask for a monitoring zone
#'
#' Strict mirror of [read_fordead_dieback_mask()]: looks under
#' `<cache_dir>/zone_<zone_id>/` for files matching
#' `^fast_alert_[A-Za-z0-9._-]+\\.tif$` and returns the latest one
#' (chronological by filename, fallback mtime). Pass `run_id` to read
#' a specific persisted mask by its timestamp suffix.
#'
#' Returns `NULL` when the directory or any matching file is absent —
#' the same dégradation pattern as [read_fordead_dieback_mask()] so
#' the app can `is.null(mask)` and show an empty state.
#'
#' @param con A `DBIConnection`. Currently unused (the function reads
#'   from disk only) but kept in the signature for symmetry with
#'   [read_fordead_dieback_mask()] and future SQL-side filtering.
#' @param zone_id Integer scalar.
#' @param run_id Optional character. Timestamp suffix used at write
#'   time (`format(Sys.time(), "%Y%m%dT%H%M%S")`). When `NULL`, the
#'   most recent persisted mask is returned.
#' @param cache_dir Path to the FAST mask cache root (typically
#'   `<project>/cache/layers/fast`).
#'
#' @return A `terra::SpatRaster` (single layer, categorical 0-4) or
#'   `NULL`.
#'
#' @seealso [compute_fast_alert_mask()] (the writer),
#'   [read_fordead_dieback_mask()] (the FORDEAD mirror),
#'   [fordead_alert_mask()] (the consumer that selects alert cells).
#'
#' @export
read_fast_alert_mask <- function(con,
                                 zone_id,
                                 run_id    = NULL,
                                 cache_dir = NULL,
                                 apply_zone_mask = TRUE,
                                 mask_polygon    = NULL) {
  if (length(zone_id) != 1L || is.na(zone_id) ||
      !is.finite(suppressWarnings(as.numeric(zone_id)))) {
    cli::cli_abort("{.arg zone_id} must be a single non-NA integer.")
  }
  zid <- as.integer(zone_id)

  if (is.null(cache_dir) || !nzchar(cache_dir) || !dir.exists(cache_dir)) {
    return(NULL)
  }
  if (!requireNamespace("terra", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg terra} required.")
  }

  zone_dir <- file.path(cache_dir, sprintf("zone_%d", zid))
  if (!dir.exists(zone_dir)) return(NULL)

  out <- if (!is.null(run_id)) {
    rid <- as.character(run_id)
    fp  <- file.path(zone_dir, sprintf("fast_alert_%s.tif", rid))
    if (!file.exists(fp)) return(NULL)
    terra::rast(fp)
  } else {
    files <- list.files(zone_dir,
                        pattern    = "^fast_alert_[A-Za-z0-9._-]+\\.tif$",
                        full.names = TRUE)
    if (!length(files)) return(NULL)
    files <- sort(files)
    terra::rast(files[length(files)])
  }

  # spec 016 (v0.49.0) — re-mask at read time for back-compat with
  # TIFs written by compute_fast_alert_mask() before v0.49.0 (which
  # were not masked at write). A re-mask on an already-masked raster
  # is a no-op (NAs stay NAs).
  if (isTRUE(apply_zone_mask)) {
    poly <- mask_polygon %||%
      (if (!is.null(con)) tryCatch(.get_zone_aoi(con, zid),
                                   error = function(e) NULL) else NULL)
    out <- .apply_zone_mask(out, poly)
  }
  out
}
