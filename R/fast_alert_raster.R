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
#' @param con A `DBIConnection`.
#' @param zone_id Integer scalar. Existing zone in `monitoring_zone`.
#' @param threshold_ndvi Numeric scalar in `(0, 1)`. Alert if NDVI is
#'   strictly below this value. Default 0.40.
#' @param threshold_nbr Numeric scalar in `(0, 1)`. Alert if NBR is
#'   strictly below this value. Default 0.30.
#' @param date_from,date_to Date (or character `"YYYY-MM-DD"`) bounding
#'   the analysis window.
#' @param mode Character scalar. One of `"count"` or `"rolling"`.
#'   Default `"count"`.
#' @param window_days Integer scalar. Length of the trailing window in
#'   calendar days for `mode = "rolling"`. Ignored in `"count"` mode.
#'   Default 30.
#' @param cache_dir Character scalar. Path to the COG cache root
#'   (typically `<project>/cache/layers/sentinel2`). Must exist.
#'
#' @return A `terra::SpatRaster` (single layer, EPSG:2154) when at least
#'   one usable scene is found, or `NULL` when no scene matches. The
#'   layer name is `alert_count` or `alert_deficit` depending on `mode`.
#'   Attribute `mode` carries the requested mode for downstream
#'   styling.
#'
#' @seealso [build_index_stack()] (the underlying NDVI / NBR stack
#'   builder, spec 010), [.get_zone_aoi()] (the shared AOI resolver,
#'   spec 012), [read_obs_pixel()] (the scene enumerator),
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
                                   threshold_ndvi = 0.40,
                                   threshold_nbr  = 0.30,
                                   date_from, date_to,
                                   mode           = c("count", "rolling"),
                                   window_days    = 30L,
                                   cache_dir,
                                   apply_zone_mask = TRUE,
                                   mask_polygon    = NULL) {
  mode <- match.arg(mode)
  .assert_db_pkgs()
  if (!requireNamespace("terra", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg terra} required.")
  }

  if (length(zone_id) != 1L || is.na(zone_id) ||
      !is.finite(suppressWarnings(as.numeric(zone_id)))) {
    cli::cli_abort("{.arg zone_id} must be a single non-NA integer.")
  }
  zid <- as.integer(zone_id)

  .validate_threshold <- function(x, name) {
    if (!is.numeric(x) || length(x) != 1L || is.na(x) || x <= 0 || x >= 1) {
      cli::cli_abort("{.arg {name}} must be a single numeric in (0, 1).")
    }
  }
  .validate_threshold(threshold_ndvi, "threshold_ndvi")
  .validate_threshold(threshold_nbr,  "threshold_nbr")

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

  # Resolve scenes via obs_pixel — same source of truth as the rest of
  # the FAST pipeline. A scene whose COGs are on disk but whose obs
  # weren't ingested into obs_pixel yet is ignored on purpose.
  obs <- read_obs_pixel(con, zid,
                        bands     = c("NDVI", "NBR"),
                        date_from = df,
                        date_to   = dt)
  if (!nrow(obs)) {
    cli::cli_alert_info("No FAST observation in [{.val {df}}, {.val {dt}}] for zone {.val {zid}}.")
    return(NULL)
  }
  scenes_df <- unique(obs[, c("scene_id", "obs_date"), drop = FALSE])
  scenes_df <- scenes_df[order(as.Date(scenes_df$obs_date)), , drop = FALSE]

  # Multi-tile AOI: an AOI that straddles MGRS tile boundaries (e.g.
  # villards on T31TFM + T31TGM) produces per-scene rasters with
  # incompatible extents that `build_index_stack` can't `terra::rast()`
  # together. Group scenes by their MGRS tile (5th `_`-field of the
  # scene_id), compute one alert raster per tile in its native CRS,
  # project each to EPSG:2154, then mosaic.
  scenes_df$mgrs <- vapply(as.character(scenes_df$scene_id),
                           .s2_mgrs_tile, character(1))
  tiles <- unique(scenes_df$mgrs[!is.na(scenes_df$mgrs)])

  method <- if (mode == "count") "near" else "bilinear"
  per_tile <- lapply(tiles, function(tile) {
    sub <- scenes_df[!is.na(scenes_df$mgrs) & scenes_df$mgrs == tile, ,
                     drop = FALSE]
    ndvi <- suppressWarnings(build_index_stack(cache_dir, sub, "NDVI"))
    nbr  <- suppressWarnings(build_index_stack(cache_dir, sub, "NBR"))
    if (is.null(ndvi) || is.null(nbr)) return(NULL)

    rn <- if (mode == "count") {
      .compute_alert_count(ndvi, nbr, threshold_ndvi, threshold_nbr)
    } else {
      .compute_alert_rolling(ndvi, nbr,
                             threshold_ndvi, threshold_nbr,
                             window_days = wd, date_to = dt)
    }
    if (is.null(rn)) return(NULL)
    terra::project(rn, "EPSG:2154", method = method)
  })
  per_tile <- Filter(Negate(is.null), per_tile)
  if (!length(per_tile)) {
    cli::cli_alert_info("No usable per-tile NDVI/NBR stack for zone {.val {zid}}.")
    return(NULL)
  }
  out <- if (length(per_tile) == 1L) per_tile[[1L]] else
    do.call(terra::mosaic, c(per_tile, list(fun = "max")))

  names(out)        <- if (mode == "count") "alert_count" else "alert_deficit"
  attr(out, "mode") <- mode

  # spec 016 (v0.49.0) — apply UGF zone mask by default. Pixels
  # outside the UGFs (= the polygon stored in monitoring_zone.zone_wkt)
  # become NA, so downstream counts / displays reflect only the
  # forest area actually managed by the user.
  if (isTRUE(apply_zone_mask)) {
    poly <- mask_polygon %||% tryCatch(.get_zone_aoi(con, zid),
                                       error = function(e) NULL)
    out <- .apply_zone_mask(out, poly)
  }
  out
}


# ---- internal helpers ------------------------------------------------

# `"count"` mode — sum of per-date boolean (NDVI < tN | NBR < tB).
# NA pixels (cloud mask, no-data) are counted as 0 by `sum(..., na.rm)`.
.compute_alert_count <- function(ndvi_stack, nbr_stack,
                                 threshold_ndvi, threshold_nbr) {
  in_ndvi <- ndvi_stack < threshold_ndvi  # SpatRaster boolean (0/1/NA)
  in_nbr  <- nbr_stack  < threshold_nbr
  # Layer-wise OR via max (boolean -> integer arithmetic).
  in_any  <- max(in_ndvi, in_nbr, na.rm = TRUE)
  # sum across layers, NA -> 0 contribution.
  sum(in_any, na.rm = TRUE)
}


# `"rolling"` mode — continuous deficit magnitude on the trailing window.
# Returns a single-layer SpatRaster aligned with the input stacks, or
# NULL if no scene falls in the trailing window.
.compute_alert_rolling <- function(ndvi_stack, nbr_stack,
                                   threshold_ndvi, threshold_nbr,
                                   window_days, date_to) {
  dates <- terra::time(ndvi_stack)
  if (length(dates) == 0L) return(NULL)
  win_start <- as.Date(date_to) - as.integer(window_days) + 1L
  in_win    <- dates >= win_start & dates <= as.Date(date_to)
  if (!any(in_win)) return(NULL)

  # Average NDVI / NBR over the trailing window via terra::app — `mean()`
  # on a SpatRaster returns a global scalar, not a cell-wise reduction.
  # `app` ignores NA per-pixel (so a pixel masked on some dates still
  # gets a value if at least one date is clear).
  mean_ndvi <- terra::app(ndvi_stack[[which(in_win)]],
                          fun = mean, na.rm = TRUE)
  mean_nbr  <- terra::app(nbr_stack[[which(in_win)]],
                          fun = mean, na.rm = TRUE)

  # Deficit = max(0, threshold - mean) per band, then max across bands.
  # `terra::clamp(..., lower = 0, values = TRUE)` is robust whether the
  # values are all non-negative (no clamp needed) or all non-positive
  # (the `[< 0] <- 0` subset-assignment idiom is fragile in that case
  # and can collapse the SpatRaster to a numeric).
  deficit_ndvi <- terra::clamp(threshold_ndvi - mean_ndvi,
                               lower = 0, values = TRUE)
  deficit_nbr  <- terra::clamp(threshold_nbr  - mean_nbr,
                               lower = 0, values = TRUE)
  max(deficit_ndvi, deficit_nbr, na.rm = FALSE)
}


# Extract the MGRS tile code (5th underscore-separated field) from an
# S2 product id. Handles both the 6-field Planetary Computer form and
# the 7-field ESA `.SAFE` form (cf. v0.41.2 `.s2_split_product_id`).
.s2_mgrs_tile <- function(scene_id) {
  parts <- strsplit(scene_id, "_", fixed = TRUE)[[1L]]
  if (length(parts) >= 5L) parts[[5L]] else NA_character_
}
