#' FAST alert raster at native S2 pixel resolution (spec 013)
#'
#' Computes a single-band raster of FAST alerts for a monitoring zone,
#' built from the cached Sentinel-2 NDVI / NBR layers produced by
#' [ingest_sentinel2_timeseries()]. Two semantics are supported, selected
#' via `mode`:
#'
#' * **`"count"`** — for each pixel, the integer number of dates within
#'   `[date_from, date_to]` where `NDVI < threshold_ndvi` **or**
#'   `NBR < threshold_nbr`. Sensitive to brief stress events;
#'   to unmasked cloud noise — mitigated by the `max_cloud` filter
#'   already applied at ingestion.
#' * **`"rolling"`** — continuous deficit magnitude over the most recent
#'   `window_days`. For each pixel, computes
#'   `mean(NDVI)` and `mean(NBR)` on the trailing window, then returns
#'   `max(deficit_ndvi, deficit_nbr)` where
#'   `deficit_x = max(0, threshold_x - mean_x)`. Value 0 = pixel not in
#'   alert, value > 0 = magnitude of the alert. Robust to brief noise,
#'   but insensitive to short shocks.
#'
#' The raster is computed in the native Sentinel-2 CRS (typically
#' EPSG:32631 for tiles T31xxx) for numerical accuracy, then
#' **projected to EPSG:2154 (Lambert-93)** before being returned, to stay
#' consistent with the rest of the project. Use [terra::project()]
#' downstream if a different output CRS is needed.
#'
#' Source data: this function reads from the on-disk COG cache populated
#' by [ingest_sentinel2_timeseries()] (or [ingest_s2_raw_bands_to_cache()]
#' on the FORDEAD path). The list of scenes to process is resolved via
#' [read_obs_pixel()] filtered by `(zone_id, [date_from, date_to])`,
#' so a scene that hasn't been ingested into `obs_pixel` yet is ignored
#' even if its COG happens to be on disk.
#'
#' @param con A `DBIConnection`. Used only to resolve the UGF zone
#'   polygon for the optional mask (spec 016) — **not** for scene
#'   enumeration (spec 017: scenes come from the COG cache, so the
#'   diagnostic is independent of `obs_pixel` / placettes).
#' @param zone_id Integer scalar. Existing zone in `monitoring_zone`.
#' @param index Character scalar. The single spectral index the alert
#'   map is built from: `"NDVI"` (default) or `"NBR"`. Spec 017 (v0.55.0)
#'   dropped the previous "NDVI OR NBR" combination — the map is now
#'   mono-index.
#' @param threshold Numeric scalar in `(0, 1)`, or `NULL`. Alert if the
#'   chosen `index` is strictly below this value. When `NULL` (default)
#'   it resolves to `0.40` for `"NDVI"` and `0.30` for `"NBR"`.
#' @param date_from,date_to Date (or character `"YYYY-MM-DD"`) bounding
#'   the analysis window.
#' @param mode Character scalar. One of `"count"` or `"rolling"`.
#'   Default `"count"`.
#' @param window_days Integer scalar. Length of the trailing window in
#'   calendar days for `mode = "rolling"`. Ignored in `"count"` mode.
#'   Default 30.
#' @param cache_dir Character scalar. Path to the COG cache root
#'   (typically `<project>/cache/layers/sentinel2`). Must exist.
#' @param cache_result Logical. When `TRUE` (default, spec 017 D6) the
#'   continuous result raster is persisted as a content-addressed COG
#'   and a subsequent call with the same inputs is served instantly from
#'   disk (zero recompute). A new scene in `cache_dir`, any parameter
#'   change, or a zone re-registration changes the content hash and
#'   triggers a fresh compute. `FALSE` disables the persistence entirely.
#' @param result_cache_dir Character scalar or `NULL`. Root of the result
#'   COG cache. When `NULL` (default) it is `file.path(dirname(cache_dir),
#'   "fast_raster")`; COGs land under `<result_cache_dir>/zone_<id>/
#'   fast_<index>_<mode>_<hash>.tif`. At most
#'   `getOption("nemeton.fast_raster_keep", 20)` COGs are kept per zone.
#' @param parallel Logical (spec 017 D4). Passed to [build_index_stack()]:
#'   when `TRUE` and \pkg{furrr} is installed, the per-scene raster
#'   compute fans across cores (set a `future::plan()` first). Default
#'   `FALSE`; results are identical to sequential.
#'
#' @return A `terra::SpatRaster` (single layer, EPSG:2154) when at least
#'   one usable scene is found, or `NULL` when no scene matches. The
#'   layer name is `alert_count` or `alert_deficit` depending on `mode`;
#'   attribute `mode` carries the mode, `index` the spectral index, and
#'   `cached = TRUE` is set when the raster was read from the result
#'   cache.
#'
#' @seealso [build_index_stack()] (the underlying index stack builder,
#'   spec 010), [.get_zone_aoi()] (the shared AOI resolver, spec 012),
#'   [compute_fast_alert_mask()] (the 0-4 quartile discretiser),
#'   [list_fast_alerts_for_zone()] (the legacy per-plot alert table).
#'
#' @examples
#' \dontrun{
#'   con <- db_connect(Sys.getenv("NEMETON_DB_URL"))
#'   on.exit(db_disconnect(con), add = TRUE)
#'   r <- read_fast_alert_raster(
#'     con, zone_id = 1L,
#'     date_from  = "2025-05-23",
#'     date_to    = "2026-05-23",
#'     mode       = "count",
#'     cache_dir  = "/proj/cache/layers/sentinel2")
#'   terra::plot(r)
#' }
#'
#' @export
read_fast_alert_raster <- function(con, zone_id,
                                   index          = c("NDVI", "NBR"),
                                   threshold      = NULL,
                                   date_from, date_to,
                                   mode           = c("count", "rolling"),
                                   window_days    = 30L,
                                   cache_dir,
                                   apply_zone_mask  = TRUE,
                                   mask_polygon     = NULL,
                                   cache_result     = TRUE,
                                   result_cache_dir = NULL,
                                   parallel         = FALSE) {
  mode  <- match.arg(mode)
  index <- match.arg(index)
  .assert_db_pkgs()
  if (!requireNamespace("terra", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg terra} required.")
  }

  if (length(zone_id) != 1L || is.na(zone_id) ||
      !is.finite(suppressWarnings(as.numeric(zone_id)))) {
    cli::cli_abort("{.arg zone_id} must be a single non-NA integer.")
  }
  zid <- as.integer(zone_id)

  # spec 017 — a single threshold for the chosen index. NULL resolves to
  # the historical per-index default (NDVI 0.40, NBR 0.30).
  if (is.null(threshold)) {
    threshold <- if (index == "NDVI") 0.40 else 0.30
  }
  if (!is.numeric(threshold) || length(threshold) != 1L ||
      is.na(threshold) || threshold <= 0 || threshold >= 1) {
    cli::cli_abort("{.arg threshold} must be a single numeric in (0, 1).")
  }

  if (missing(date_from) || missing(date_to)) {
    cli::cli_abort("{.arg date_from} and {.arg date_to} are required.")
  }
  df <- tryCatch(as.Date(date_from),
                 error = function(e) as.Date(NA),
                 warning = function(w) as.Date(NA))
  dt <- tryCatch(as.Date(date_to),
                 error = function(e) as.Date(NA),
                 warning = function(w) as.Date(NA))
  if (is.na(df) || is.na(dt)) {
    cli::cli_abort("{.arg date_from} / {.arg date_to} must parse as Date (ISO yyyy-mm-dd).")
  }
  if (df > dt) {
    cli::cli_abort("{.arg date_from} must be <= {.arg date_to}.")
  }

  if (missing(cache_dir) || !is.character(cache_dir) ||
      length(cache_dir) != 1L || !nzchar(cache_dir)) {
    cli::cli_abort("{.arg cache_dir} is required and must be a non-empty path.")
  }
  if (!dir.exists(cache_dir)) {
    cli::cli_abort("{.arg cache_dir} does not exist: {.path {cache_dir}}.")
  }

  if (mode == "rolling") {
    if (!is.numeric(window_days) || length(window_days) != 1L ||
        is.na(window_days) || window_days < 1) {
      cli::cli_abort("{.arg window_days} must be a positive integer when {.code mode = \"rolling\"}.")
    }
  }
  wd <- as.integer(window_days)

  # spec 017 (v0.55.0) — enumerate scenes from the COG cache, not from
  # `obs_pixel`. The diagnostic is a per-pixel raster computed before any
  # placette exists, so it must not depend on `obs_pixel` (which is a
  # per-plot, placette-keyed table). We list the cached scenes that carry
  # the bands the chosen `index` needs and fall in [date_from, date_to].
  scenes_df <- .enumerate_cache_scenes(cache_dir, index, df, dt)
  if (!nrow(scenes_df)) {
    cli::cli_alert_info("No cached {.field {index}} scene in [{.val {df}}, {.val {dt}}] under {.path {cache_dir}}.")
    return(NULL)
  }

  # spec 017 D6 — resolve the UGF mask polygon now (cheap DB read), both
  # to apply it at the end AND to fold it into the content hash so a zone
  # re-registration invalidates the cached raster.
  poly <- if (isTRUE(apply_zone_mask)) {
    mask_polygon %||% tryCatch(.get_zone_aoi(con, zid), error = function(e) NULL)
  } else NULL

  # Content-addressed result cache. The diagnostic is expensive and
  # re-viewed often; persisting the continuous raster keyed by its inputs
  # makes a revisit instant and self-invalidates when a new scene lands in
  # the cache or any parameter changes (the content IS the key).
  if (is.null(result_cache_dir)) {
    result_cache_dir <- file.path(dirname(cache_dir), "fast_raster")
  }
  mask_wkt <- if (!is.null(poly))
    tryCatch(sf::st_as_text(sf::st_geometry(poly)[[1L]]),
             error = function(e) NULL) else NULL
  rhash <- .fast_raster_hash(scenes_df$scene_id, index, threshold, mode,
                             wd, df, dt, mask_wkt)
  cpath <- .fast_raster_cache_path(result_cache_dir, zid, index, mode, rhash)

  if (isTRUE(cache_result) && file.exists(cpath)) {
    cached <- tryCatch(terra::rast(cpath), error = function(e) NULL)
    if (!is.null(cached)) {
      names(cached)         <- if (mode == "count") "alert_count" else "alert_deficit"
      attr(cached, "mode")  <- mode
      attr(cached, "index") <- index
      attr(cached, "cached") <- TRUE
      return(cached)
    }
  }

  # Multi-tile AOI: an AOI that straddles MGRS tile boundaries (e.g.
  # villards on T31TFM + T31TGM) is handled per-tile, NOT by handing all
  # scenes to a single `build_index_stack` call. Two reasons survive
  # build_index_stack's union+pad (v0.52.x):
  #   1. Double-counting. The ~10 km S2 tile overlap means the SAME
  #      acquisition date is present in both tiles' scenes. Unioning
  #      them into one stack and `count`-ing would tally each overlap
  #      date twice. Per-tile counting + `mosaic(fun = "max")` keeps the
  #      overlap strip bounded by a single tile's date count.
  #   2. Multi-CRS. Neighbouring tiles can sit in different UTM zones;
  #      computing each in its native CRS then projecting the *alert*
  #      raster (integers, `near`) is cleaner than bilinear-resampling
  #      raw NDVI across zones.
  # Group scenes by their MGRS tile (5th `_`-field of the scene_id),
  # compute one alert raster per tile in its native CRS, project each to
  # EPSG:2154, then mosaic. (Within a tile, build_index_stack now pads
  # to the union rather than cropping to the intersection, so intra-tile
  # extent drift no longer trims coverage either.)
  scenes_df$mgrs <- vapply(as.character(scenes_df$scene_id),
                           .s2_mgrs_tile, character(1))
  tiles <- unique(scenes_df$mgrs[!is.na(scenes_df$mgrs)])

  method <- if (mode == "count") "near" else "bilinear"
  per_tile <- lapply(tiles, function(tile) {
    sub <- scenes_df[!is.na(scenes_df$mgrs) & scenes_df$mgrs == tile, ,
                     drop = FALSE]
    # spec 017 — a single index stack (NDVI *or* NBR), not both.
    # `parallel` (D4) fans the per-scene compute across cores.
    stk <- suppressWarnings(
      build_index_stack(cache_dir, sub, index, parallel = parallel))
    if (is.null(stk)) return(NULL)

    rn <- if (mode == "count") {
      .compute_alert_count(stk, threshold)
    } else {
      .compute_alert_rolling(stk, threshold, window_days = wd, date_to = dt)
    }
    if (is.null(rn)) return(NULL)
    terra::project(rn, "EPSG:2154", method = method)
  })
  per_tile <- Filter(Negate(is.null), per_tile)
  if (!length(per_tile)) {
    cli::cli_alert_info("No usable per-tile {.field {index}} stack for zone {.val {zid}}.")
    return(NULL)
  }
  out <- if (length(per_tile) == 1L) per_tile[[1L]] else
    do.call(terra::mosaic, c(per_tile, list(fun = "max")))

  names(out)         <- if (mode == "count") "alert_count" else "alert_deficit"
  attr(out, "mode")  <- mode
  attr(out, "index") <- index

  # spec 016 (v0.49.0) — apply the UGF zone mask (resolved above). Pixels
  # outside the UGFs become NA, so downstream counts / displays reflect
  # only the forest area actually managed by the user.
  if (isTRUE(apply_zone_mask)) {
    out <- .apply_zone_mask(out, poly)
  }

  # spec 017 D6 — persist the continuous result as a content-addressed
  # COG. Best-effort: a write failure warns but still returns the raster.
  if (isTRUE(cache_result)) {
    zone_dir <- dirname(cpath)
    if (!dir.exists(zone_dir)) {
      dir.create(zone_dir, recursive = TRUE, showWarnings = FALSE)
    }
    tryCatch({
      terra::writeRaster(out, cpath, filetype = "GTiff", overwrite = TRUE,
                         gdal = c("COMPRESS=DEFLATE", "PREDICTOR=2",
                                  "TILED=YES"))
      .fast_raster_gc(zone_dir)
    }, error = function(e) {
      cli::cli_warn("Failed to cache FAST alert raster at {.path {cpath}}: {conditionMessage(e)}")
    })
  }
  out
}


# ---- internal helpers ------------------------------------------------

# spec 017 D6 — content hash of every input that determines the FAST
# alert raster. A new scene in the cache, a parameter change, or a zone
# re-registration (mask geometry) all change the hash, so the cached COG
# self-invalidates. Uses `rlang::hash` (already an Import) — no `digest`
# dependency. `window_days` only matters in rolling mode; the mask WKT is
# NA when no mask is applied.
.fast_raster_hash <- function(scene_ids, index, threshold, mode,
                              window_days, date_from, date_to, mask_wkt) {
  rlang::hash(list(
    scenes      = sort(as.character(scene_ids)),
    index       = index,
    threshold   = round(as.numeric(threshold), 6L),
    mode        = mode,
    window_days = if (identical(mode, "rolling"))
                    as.integer(window_days) else NA_integer_,
    date_from   = as.character(date_from),
    date_to     = as.character(date_to),
    mask        = if (is.null(mask_wkt)) NA_character_ else mask_wkt
  ))
}

# Absolute path of the cached COG: <result_cache_dir>/zone_<id>/
# fast_<index>_<mode>_<hash>.tif. The `fast_<index>_<mode>_` prefix keeps
# it distinct from the 0-4 mask cache (`fast/zone_<id>/fast_alert_<ts>.tif`,
# read by `read_fast_alert_mask`), so the two never collide.
.fast_raster_cache_path <- function(result_cache_dir, zid, index, mode, hash) {
  file.path(result_cache_dir, sprintf("zone_%d", zid),
            sprintf("fast_%s_%s_%s.tif", index, mode, hash))
}

# Keep at most `keep` cached COGs per zone directory (LRU by mtime).
.fast_raster_gc <- function(zone_dir, keep = getOption("nemeton.fast_raster_keep", 20L)) {
  files <- list.files(zone_dir, pattern = "^fast_.*\\.tif$", full.names = TRUE)
  if (length(files) <= keep) return(invisible(NULL))
  mt  <- file.info(files)$mtime
  old <- files[order(mt, decreasing = TRUE)][-seq_len(keep)]
  unlink(old)
  invisible(NULL)
}

# spec 017 — enumerate the cached scenes usable for `index` in the date
# window, straight from disk (no DB, no obs_pixel). A scene qualifies
# when its cache directory holds every band the index needs:
#   NDVI -> B04 + B08,  NBR -> B08 + B12.
# The directory name is the (sanitised) scene_id, which carries both the
# sensing date (3rd `_`-field, YYYYMMDD...) and the MGRS tile (5th field).
.enumerate_cache_scenes <- function(cache_dir, index, date_from, date_to) {
  bands <- switch(index, NDVI = c("B04", "B08"), NBR = c("B08", "B12"))
  scene_dirs <- list.dirs(cache_dir, recursive = FALSE)
  empty <- data.frame(scene_id = character(0), obs_date = as.Date(character(0)),
                      stringsAsFactors = FALSE)
  if (!length(scene_dirs)) return(empty)
  has_bands <- vapply(scene_dirs, function(d)
    all(file.exists(file.path(d, paste0(bands, ".tif")))), logical(1))
  scene_dirs <- scene_dirs[has_bands]
  if (!length(scene_dirs)) return(empty)
  sid <- basename(scene_dirs)
  od  <- .s2_scene_date(sid)
  keep <- !is.na(od) & od >= as.Date(date_from) & od <= as.Date(date_to)
  out <- data.frame(scene_id = sid[keep], obs_date = od[keep],
                    stringsAsFactors = FALSE)
  out[order(out$obs_date), , drop = FALSE]
}

# Parse the sensing date (3rd `_`-field, first 8 chars = YYYYMMDD) from
# one or more S2 scene ids. Returns Date (NA when the field is absent).
.s2_scene_date <- function(scene_id) {
  parts <- strsplit(as.character(scene_id), "_", fixed = TRUE)
  ymd <- vapply(parts, function(p)
    if (length(p) >= 3L) substr(p[[3L]], 1L, 8L) else NA_character_,
    character(1))
  as.Date(ymd, format = "%Y%m%d")
}

# `"count"` mode — count of per-date alerts (index < threshold).
# NA pixels (cloud mask, no-data) are counted as 0 by `sum(..., na.rm)`.
.compute_alert_count <- function(stack, threshold) {
  # spec 017 — mono-index. Per date a pixel is "in alert" when the index
  # is strictly below the threshold; the result is the count of alert
  # dates per pixel (NA dates contribute 0 via `na.rm`).
  in_alert <- stack < threshold          # SpatRaster boolean (0/1/NA)
  sum(in_alert, na.rm = TRUE)
}


# `"rolling"` mode — continuous deficit magnitude on the trailing window.
# Returns a single-layer SpatRaster aligned with the input stacks, or
# NULL if no scene falls in the trailing window.
.compute_alert_rolling <- function(stack, threshold, window_days, date_to) {
  dates <- terra::time(stack)
  if (length(dates) == 0L) return(NULL)
  win_start <- as.Date(date_to) - as.integer(window_days) + 1L
  in_win    <- dates >= win_start & dates <= as.Date(date_to)
  if (!any(in_win)) return(NULL)

  # Average the index over the trailing window via terra::app — `mean()`
  # on a SpatRaster returns a global scalar, not a cell-wise reduction.
  # `app` ignores NA per-pixel (so a pixel masked on some dates still
  # gets a value if at least one date is clear).
  mean_x <- terra::app(stack[[which(in_win)]], fun = mean, na.rm = TRUE)

  # Deficit = max(0, threshold - mean). `terra::clamp(..., lower = 0,
  # values = TRUE)` is robust whether the values are all non-negative
  # (no clamp needed) or all non-positive (the `[< 0] <- 0`
  # subset-assignment idiom is fragile in that case and can collapse the
  # SpatRaster to a numeric).
  terra::clamp(threshold - mean_x, lower = 0, values = TRUE)
}


# Extract the MGRS tile code (5th underscore-separated field) from an
# S2 product id. Handles both the 6-field Planetary Computer form and
# the 7-field ESA `.SAFE` form (cf. v0.41.2 `.s2_split_product_id`).
.s2_mgrs_tile <- function(scene_id) {
  parts <- strsplit(scene_id, "_", fixed = TRUE)[[1L]]
  if (length(parts) >= 5L) parts[[5L]] else NA_character_
}
