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
#' @param threshold_ndvi,threshold_nbr Numeric in `(0, 1)`. Passed
#'   through to [read_fast_alert_raster()].
#' @param date_from,date_to Date (or character `"YYYY-MM-DD"`) bounding
#'   the analysis window.
#' @param mode One of `"count"` or `"rolling"`. Default `"count"`.
#' @param window_days Integer. Trailing window length, used in
#'   `"rolling"` mode. Default `30L`.
#' @param cache_dir Path to the S2 COG cache.
#' @param mask_cache_dir Path to the FAST mask cache root. The mask is
#'   written under `<mask_cache_dir>/zone_<id>/fast_alert_<ts>.tif`.
#'   Defaults to a `fast/` sibling of `cache_dir` (i.e.
#'   `<project>/cache/layers/fast/`).
#' @param breaks Numeric vector of break points to discretise the
#'   continuous alert raster into the 0-4 scale. **5 cut points** are
#'   expected (defines bins `(-Inf, b1], (b1, b2], ..., (b4, Inf]`).
#'   Default depends on `mode`:
#'   * `"count"`   : `c(0, 2, 5, 10, Inf)` (cumulative day counts).
#'   * `"rolling"` : `c(0, 0.05, 0.10, 0.20, Inf)` (deficit magnitude).
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
                                    threshold_ndvi = 0.40,
                                    threshold_nbr  = 0.30,
                                    date_from, date_to,
                                    mode           = c("count", "rolling"),
                                    window_days    = 30L,
                                    cache_dir,
                                    mask_cache_dir  = NULL,
                                    breaks          = NULL,
                                    apply_zone_mask = TRUE,
                                    mask_polygon    = NULL) {
  mode <- match.arg(mode)
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

  # Default breaks per mode.
  if (is.null(breaks)) {
    breaks <- switch(mode,
      count   = c(0, 2, 5, 10, Inf),
      rolling = c(0, 0.05, 0.10, 0.20, Inf)
    )
  }
  if (!is.numeric(breaks) || length(breaks) != 5L) {
    cli::cli_abort("{.arg breaks} must be a numeric vector of length 5 (5 cut points).")
  }

  # spec 016 — propagate the UGF mask to the underlying continuous
  # raster *before* discretisation. The persisted 0-4 mask thus
  # already has NA outside the UGFs (compact on disk via DEFLATE,
  # and the reader doesn't need to re-mask).
  cont <- read_fast_alert_raster(
    con             = con,
    zone_id         = zid,
    threshold_ndvi  = threshold_ndvi,
    threshold_nbr   = threshold_nbr,
    date_from       = date_from,
    date_to         = date_to,
    mode            = mode,
    window_days     = window_days,
    cache_dir       = cache_dir,
    apply_zone_mask = apply_zone_mask,
    mask_polygon    = mask_polygon
  )
  if (is.null(cont)) {
    cli::cli_alert_info("No FAST alert raster to persist for zone {.val {zid}}.")
    return(invisible(NULL))
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
  invisible(out_path)
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
