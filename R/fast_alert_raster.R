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
#' * **`"trend"`** — multi-year monotonic decline (spec 023). A
#'   *relative* paradigm: each pixel is its own baseline, no absolute
#'   `threshold`. Builds a seasonal yearly composite (median of the
#'   `months` window per year, dropping years with fewer than
#'   `min_obs_per_year` clear observations), requires at least
#'   `min_years` valid years, then fits a Theil-Sen slope and a
#'   Mann-Kendall significance test per pixel. Returns `abs(slope)`
#'   where the slope is negative **and** the Mann-Kendall p-value is
#'   below `alpha`, otherwise `0`; pixels with too few valid years are
#'   `NA`. The output is the same kind of continuous raster as the
#'   other modes (`0` = no alert, `> 0` = magnitude), so
#'   [compute_fast_alert_mask()] discretises it unchanged — Mann-Kendall
#'   plays the gate that the absolute threshold plays for count /
#'   rolling. Built for chronic dieback (slow multi-year decline, e.g.
#'   broadleaf oak / beech) that the short-horizon modes cannot see.
#'
#' **Tile-overlap caveat (trend).** When an AOI straddles MGRS tiles, the
#' slope is fitted independently per tile (each from that tile's own scene
#' set) and the per-tile rasters are combined with `mosaic(fun = "max")`,
#' as for `count` / `rolling`. In the ~10 km overlap strip the two tiles
#' can yield slightly different slopes (different acquisition dates), and
#' `max` keeps the **larger decline magnitude** — a mild high bias on those
#' seams. It is bounded (a single tile's estimate, never a sum) and
#' conservative for *detection*; treat the magnitude on tile boundaries as
#' an upper bound. A single-tile AOI is unaffected.
#'
#' The raster is computed in the native Sentinel-2 CRS (typically
#' EPSG:32631 for tiles T31xxx) for numerical accuracy, then
#' **projected to EPSG:2154 (Lambert-93)** before being returned, to stay
#' consistent with the rest of the project. Use [terra::project()]
#' downstream if a different output CRS is needed.
#'
#' Source data: this function reads from the on-disk COG cache populated
#' by [ingest_sentinel2_timeseries()] (or [ingest_s2_raw_bands_to_cache()]
#' on the FORDEAD path). The list of scenes to process is enumerated
#' directly from the cache directory and filtered by
#' `(date_from, date_to)` (spec 017), so the diagnostic is fully
#' independent of any per-placette table.
#'
#' @param con A `DBIConnection`. Used only to resolve the UGF zone
#'   polygon for the optional mask (spec 016) — **not** for scene
#'   enumeration (spec 017: scenes come from the COG cache, so the
#'   diagnostic is independent of `obs_pixel` / placettes).
#' @param zone_id Integer scalar. Existing zone in `monitoring_zone`.
#' @param index Character scalar. The single spectral index the alert
#'   map is built from: `"NDVI"`, `"NBR"`, `"NDMI"` (moisture, spec 019)
#'   or `"NDRE"` (red-edge, spec 022). The default is **mode-dependent**
#'   when `index` is not supplied: `"NDVI"` for `count` / `rolling`
#'   (back-compat), `"NDMI"` for `trend` (moisture decouples first under
#'   chronic stress). Spec 017 (v0.55.0) dropped the previous "NDVI OR
#'   NBR" combination — the map is mono-index.
#' @param threshold Numeric scalar in `(0, 1)`, or `NULL`. Alert if the
#'   chosen `index` is strictly below this value. When `NULL` (default)
#'   it resolves to `0.40` for `"NDVI"` and `0.30` otherwise (`"NBR"`,
#'   `"NDMI"`, `"NDRE"`). **Ignored when `mode = "trend"`** (the trend
#'   paradigm is relative, not threshold-based).
#' @param date_from,date_to Date (or character `"YYYY-MM-DD"`) bounding
#'   the analysis window.
#' @param mode Character scalar. One of `"count"`, `"rolling"` or
#'   `"trend"` (spec 023). Default `"count"`.
#' @param window_days Integer scalar. Length of the trailing window in
#'   calendar days for `mode = "rolling"`. Ignored in `"count"` /
#'   `"trend"` mode. Default 30.
#' @param months Integer vector in `1:12`. Trend mode only: the seasonal
#'   window kept for the yearly composite. Default `6:9` (summer, when
#'   water stress is most legible).
#' @param min_years Integer scalar. Trend mode only: minimum number of
#'   valid composite years a pixel needs, else it is `NA`. Default `4`.
#' @param min_obs_per_year Integer scalar. Trend mode only: minimum
#'   number of clear observations a pixel needs within a year for that
#'   year's median to count (else that year is `NA` for the pixel).
#'   Default `2`.
#' @param alpha Numeric scalar in `(0, 1)`. Trend mode only: the
#'   Mann-Kendall significance level. A pixel is flagged only when its
#'   Mann-Kendall **two-sided** p-value is below `alpha` **and** its
#'   Theil-Sen slope is negative. Because that negative-slope gate keeps
#'   a single tail, the **effective false-positive rate for a declared
#'   decline is `alpha / 2`** — the default `0.05` is a 2.5% one-sided
#'   risk. Pixels above the threshold are treated as noise (output `0`).
#'   Default `0.05`.
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
#'   fast_<INDEX>_<MODE>_thr<threshold>_<from>_<to>_w<window>_<hash8>.tif`
#'   (verbose, deterministic — same parameters yield the same name, so the
#'   cache hit is preserved). At most
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
#'   [compute_fast_alert_mask()] (the 0-4 quartile discretiser).
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
                                   apply_zone_mask  = TRUE,
                                   mask_polygon     = NULL,
                                   cache_result     = TRUE,
                                   result_cache_dir = NULL,
                                   parallel         = FALSE) {
  mode  <- match.arg(mode)
  # Mode-dependent default index: NDVI for count/rolling (back-compat),
  # NDMI for trend (moisture decouples first under chronic stress). An
  # explicit `index` always wins.
  if (missing(index)) {
    index <- if (mode == "trend") "NDMI" else "NDVI"
  } else {
    index <- match.arg(index, c("NDVI", "NBR", "NDMI", "NDRE"))
  }
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
  # the historical per-index default (NDVI 0.40, NBR 0.30). NDMI (spec
  # 019) reuses the generic non-NDVI default (0.30); the 0-4 mask stays
  # adaptive (quartiles) so no NDMI-specific calibration is needed.
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

  # spec 023 — trend mode validates its own parameters; `threshold` and
  # `window_days` are ignored here (the paradigm is relative).
  if (mode == "trend") {
    if (!is.numeric(alpha) || length(alpha) != 1L || is.na(alpha) ||
        alpha <= 0 || alpha >= 1) {
      cli::cli_abort("{.arg alpha} must be a single numeric in (0, 1) when {.code mode = \"trend\"}.")
    }
    if (!is.numeric(months) || !length(months) || anyNA(months) ||
        any(months < 1 | months > 12)) {
      cli::cli_abort("{.arg months} must be integers in 1:12 when {.code mode = \"trend\"}.")
    }
    if (!is.numeric(min_years) || length(min_years) != 1L ||
        is.na(min_years) || min_years < 2) {
      cli::cli_abort("{.arg min_years} must be a single integer >= 2 when {.code mode = \"trend\"}.")
    }
    if (!is.numeric(min_obs_per_year) || length(min_obs_per_year) != 1L ||
        is.na(min_obs_per_year) || min_obs_per_year < 1) {
      cli::cli_abort("{.arg min_obs_per_year} must be a single integer >= 1 when {.code mode = \"trend\"}.")
    }
  }
  months           <- sort(unique(as.integer(months)))
  min_years        <- as.integer(min_years)
  min_obs_per_year <- as.integer(min_obs_per_year)

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
                             wd, df, dt, mask_wkt,
                             alpha = alpha, months = months,
                             min_years = min_years,
                             min_obs_per_year = min_obs_per_year)
  cpath <- .fast_raster_cache_path(result_cache_dir, zid, index, mode,
                                   threshold, df, dt, wd, rhash,
                                   alpha = alpha, months = months,
                                   min_years = min_years)

  if (isTRUE(cache_result) && file.exists(cpath)) {
    cached <- tryCatch(terra::rast(cpath), error = function(e) NULL)
    if (!is.null(cached)) {
      names(cached)         <- .fast_layer_name(mode)
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
    } else if (mode == "rolling") {
      .compute_alert_rolling(stk, threshold, window_days = wd, date_to = dt)
    } else {
      # spec 023 — multi-year monotonic decline (Theil-Sen + Mann-Kendall).
      .fast_raster_trend(stk, months = months, min_years = min_years,
                         min_obs_per_year = min_obs_per_year, alpha = alpha)
    }
    if (is.null(rn)) return(NULL)
    terra::project(rn, "EPSG:2154", method = method)
  })
  per_tile <- Filter(Negate(is.null), per_tile)
  if (!length(per_tile)) {
    cli::cli_alert_info("No usable per-tile {.field {index}} stack for zone {.val {zid}}.")
    return(NULL)
  }
  # `fun = "max"` over tile overlaps: for count/rolling it avoids
  # double-counting the shared overlap dates; for trend it keeps the
  # larger of two independently-fitted slope magnitudes on the seam (a
  # mild, bounded high bias — see the "Tile-overlap caveat" in the
  # roxygen). A `mean` would smooth the seam but blur genuine within-strip
  # differences; `max` is kept for cross-mode consistency. `.mosaic_per_tile`
  # snaps the independently-projected tiles to ONE common EPSG:2154 grid
  # first: projecting each tile on its own lets terra pick a per-tile output
  # resolution, and two 20 m tiles (NDRE / B8A over T31TFM + T31TGM) then
  # land on marginally different resolutions and `terra::mosaic()` aborts
  # with "resolution does not match" (10 m NDMI happened to match by luck).
  out <- if (length(per_tile) == 1L) per_tile[[1L]] else
    .mosaic_per_tile(per_tile, method = method)

  names(out)         <- .fast_layer_name(mode)
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


# spec 023 — which `(index, mode)` pairs are a meaningful FAST alert map.
# `count` / `rolling` are the per-date / trailing-window paradigms, defined
# for the broadband indices (`NDVI`, `NBR`, `NDMI`) but NOT the red-edge
# `NDRE` (opt-in, only ingested for the chronic-decline use case). `trend`
# is the multi-year seasonal paradigm (ADR-014), meaningful only on the
# moisture / red-edge indices that decouple first under chronic stress
# (`NDMI`, `NDRE`). The wrapper and the prewarm both enumerate through this
# single predicate so they can never drift apart.
.fast_alert_combo_ok <- function(index, mode) {
  if (identical(mode, "trend")) index %in% c("NDMI", "NDRE")
  else index %in% c("NDVI", "NBR", "NDMI")
}

# Cartesian product of `indices` x `modes` restricted to the valid
# combinations above, returned as a data.frame in a deterministic canonical
# order (`NDVI`, `NBR`, `NDMI`, `NDRE`) x (`count`, `rolling`, `trend`) so
# the default call yields NDVI/NBR/NDMI count+rolling, then NDMI_trend, then
# NDRE_trend.
.fast_alert_combos <- function(indices, modes) {
  g <- expand.grid(index = indices, mode = modes,
                   stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE)
  ok <- mapply(.fast_alert_combo_ok, g$index, g$mode)
  g  <- g[ok, , drop = FALSE]
  g[order(match(g$index, c("NDVI", "NBR", "NDMI", "NDRE")),
          match(g$mode,  c("count", "rolling", "trend"))), , drop = FALSE]
}


#' Build the full FAST alert raster set (indices x modes)
#'
#' Convenience wrapper over [read_fast_alert_raster()] that builds the
#' complete FAST diagnostic in a single call. By default it produces the
#' six per-date / trailing-window maps (`NDVI`, `NBR`, `NDMI` each in
#' `count` and `rolling`) plus the two multi-year trend maps (`NDMI_trend`
#' and `NDRE_trend`, ADR-014). Only the meaningful `(index, mode)`
#' combinations are built: `trend` is restricted to the moisture / red-edge
#' indices (`NDMI`, `NDRE`), and `count` / `rolling` to the broadband
#' indices (`NDVI`, `NBR`, `NDMI`) — a request for an unsupported pair such
#' as `NDVI_trend` or `NDRE_count` is silently skipped. Every element is
#' produced exactly as a direct [read_fast_alert_raster()] call would be,
#' sharing the same COG cache, content-addressed result cache and zone
#' mask, so a revisit of any one map stays instant (spec 017 D6).
#'
#' The bands each index needs are cached by [ingest_sentinel2_timeseries()]
#' (B11 for NDMI is cached best-effort, spec 019 D3; B05 / B8A for NDRE only
#' when `bands = "NDRE"` is requested, spec 022). A map whose index has no
#' cached scene carrying its bands in the window is returned as `NULL`
#' rather than dropping the slot, so the result always has a stable shape.
#'
#' @inheritParams read_fast_alert_raster
#' @param indices Character vector, subset of
#'   `c("NDVI", "NBR", "NDMI", "NDRE")`. Default: all four.
#' @param modes Character vector, subset of
#'   `c("count", "rolling", "trend")`. Default: all three.
#' @param threshold Numeric scalar in `(0, 1)` applied to every requested
#'   index (ignored in `trend` mode), or `NULL` (default) to let each index
#'   resolve its own default (`0.40` for NDVI, `0.30` for NBR / NDMI). Pass
#'   `NULL` unless you deliberately want one shared cut-off across indices.
#'
#' @return A named `list` keyed `"<index>_<mode>"` (e.g. `"NDMI_trend"`),
#'   one element per valid combination (eight by default). Each element is a
#'   `terra::SpatRaster` (EPSG:2154) or `NULL` when no cached scene matched
#'   for that index in the window.
#'
#' @seealso [read_fast_alert_raster()] (the per-map builder),
#'   [compute_fast_alert_mask()] (0-4 quartile discretiser).
#'
#' @examples
#' \dontrun{
#'   con <- db_connect(Sys.getenv("NEMETON_DB_URL"))
#'   on.exit(db_disconnect(con), add = TRUE)
#'   maps <- read_fast_alert_rasters(
#'     con, zone_id = 1L,
#'     date_from = "2025-05-23", date_to = "2026-05-23",
#'     cache_dir = "/proj/cache/layers/sentinel2")
#'   names(maps)             # "NDVI_count" ... "NDMI_trend" "NDRE_trend"
#'   terra::plot(maps$NDMI_trend)
#' }
#'
#' @export
read_fast_alert_rasters <- function(con, zone_id,
                                    date_from, date_to,
                                    indices     = c("NDVI", "NBR", "NDMI", "NDRE"),
                                    modes       = c("count", "rolling", "trend"),
                                    threshold   = NULL,
                                    window_days = 30L,
                                    months           = 6:9,
                                    min_years        = 4L,
                                    min_obs_per_year = 2L,
                                    alpha            = 0.05,
                                    cache_dir,
                                    apply_zone_mask  = TRUE,
                                    mask_polygon     = NULL,
                                    cache_result     = TRUE,
                                    result_cache_dir = NULL,
                                    parallel         = FALSE) {
  indices <- match.arg(indices, c("NDVI", "NBR", "NDMI", "NDRE"),
                       several.ok = TRUE)
  modes   <- match.arg(modes, c("count", "rolling", "trend"),
                       several.ok = TRUE)

  combos <- .fast_alert_combos(indices, modes)
  out <- list()
  for (i in seq_len(nrow(combos))) {
    idx <- combos$index[i]
    md  <- combos$mode[i]
    key <- paste(idx, md, sep = "_")
    out[[key]] <- read_fast_alert_raster(
      con, zone_id,
      index            = idx,
      threshold        = threshold,
      date_from        = date_from,
      date_to          = date_to,
      mode             = md,
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
      parallel         = parallel)
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
                              window_days, date_from, date_to, mask_wkt,
                              alpha = NA_real_, months = NA_integer_,
                              min_years = NA_integer_,
                              min_obs_per_year = NA_integer_) {
  base <- list(
    scenes      = sort(as.character(scene_ids)),
    index       = index,
    # spec 023 — threshold is meaningless in trend mode; drop it from the
    # hash there so a threshold change never aliases two trend rasters.
    threshold   = if (identical(mode, "trend")) NA_real_
                  else round(as.numeric(threshold), 6L),
    mode        = mode,
    window_days = if (identical(mode, "rolling"))
                    as.integer(window_days) else NA_integer_,
    date_from   = as.character(date_from),
    date_to     = as.character(date_to),
    mask        = if (is.null(mask_wkt)) NA_character_ else mask_wkt
  )
  # Trend-only parameters are appended ONLY for trend, so the hash of a
  # count / rolling raster is byte-identical to pre-spec-023 — existing
  # cached COGs stay valid. Changing alpha / months / min_years /
  # min_obs_per_year invalidates a trend raster (the content IS the key).
  if (identical(mode, "trend")) {
    base <- c(base, list(
      alpha            = round(as.numeric(alpha), 6L),
      months           = paste(sort(as.integer(months)), collapse = "-"),
      min_years        = as.integer(min_years),
      min_obs_per_year = as.integer(min_obs_per_year)
    ))
  }
  rlang::hash(base)
}

# Verbose, deterministic cache filename for a FAST alert raster:
#   fast_<INDEX>_<MODE>_thr<seuil>_<from>_<to>_w<window>_<hash8>.tif
# The key parameters (threshold, date window, rolling window) are legible
# straight from the name, so two same-prefix files in one zone dir are
# distinguishable at a glance. An 8-char slice of the D6 hash still
# discriminates the inputs that don't fit a filename — the scene-id list
# (changes after a re-ingest) and the mask WKT (changes with the zone).
# Same parameters -> identical name, so the D6 cache hit is preserved.
.fast_raster_filename <- function(index, mode, threshold,
                                  date_from, date_to, window_days, hash,
                                  alpha = NA_real_, months = NA_integer_,
                                  min_years = NA_integer_) {
  h8  <- substr(as.character(hash), 1L, 8L)
  dff <- format(as.Date(date_from), "%Y-%m-%d")
  dtt <- format(as.Date(date_to),   "%Y-%m-%d")
  if (identical(mode, "trend")) {
    # spec 023 — trend ignores threshold / window_days; encode its own
    # legible parameters (alpha, season months, min years) instead. The
    # leading `fast_<INDEX>_` keeps the `^fast_[A-Z]` GC match (continuous
    # COGs), distinct from the lowercase `fast_alert_` 0-4 masks.
    sprintf(
      "fast_%s_trend_a%.3f_m%s_y%d_%s_%s_%s.tif",
      toupper(index),
      as.numeric(alpha),
      paste(sort(as.integer(months)), collapse = ""),
      as.integer(min_years),
      dff, dtt, h8)
  } else {
    sprintf(
      "fast_%s_%s_thr%.2f_%s_%s_w%d_%s.tif",
      toupper(index), tolower(mode),
      as.numeric(threshold), dff, dtt,
      as.integer(window_days), h8)
  }
}

# Absolute path of the cached COG: <result_cache_dir>/zone_<id>/
# fast_<INDEX>_<MODE>_thr<seuil>_<from>_<to>_w<window>_<hash8>.tif. The
# `fast_<INDEX>_` prefix keeps it distinct from the 0-4 mask cache
# (`fast/zone_<id>/fast_alert_<ts>.tif`, read by `read_fast_alert_mask`),
# so the two never collide.
.fast_raster_cache_path <- function(result_cache_dir, zid, index, mode,
                                    threshold, date_from, date_to,
                                    window_days, hash,
                                    alpha = NA_real_, months = NA_integer_,
                                    min_years = NA_integer_) {
  file.path(result_cache_dir, sprintf("zone_%d", zid),
            .fast_raster_filename(index, mode, threshold,
                                  date_from, date_to, window_days, hash,
                                  alpha = alpha, months = months,
                                  min_years = min_years))
}

# Keep at most `keep` cached continuous COGs per zone directory (LRU by
# mtime). The `^fast_[A-Z]` pattern matches the continuous files
# (`fast_NDVI_*`, `fast_NBR_*`, `fast_NDMI_*`) but NOT the 0-4 masks
# (`fast_alert_*`, lowercase), so when `result_cache_dir == mask_cache_dir`
# (validation sampling on `fast_sampling/`) the two caches are GC'd
# independently and never delete each other's files.
.fast_raster_gc <- function(zone_dir, keep = getOption("nemeton.fast_raster_keep", 20L)) {
  files <- list.files(zone_dir, pattern = "^fast_[A-Z].*\\.tif$", full.names = TRUE)
  if (length(files) <= keep) return(invisible(NULL))
  mt  <- file.info(files)$mtime
  old <- files[order(mt, decreasing = TRUE)][-seq_len(keep)]
  unlink(old)
  invisible(NULL)
}

# spec 017 — enumerate the cached scenes usable for `index` in the date
# window, straight from disk (no DB, no obs_pixel). A scene qualifies
# when its cache directory holds every band the index needs:
#   NDVI -> B04 + B08,  NBR -> B08 + B12,  NDMI -> B08 + B11 (spec 019).
# The directory name is the (sanitised) scene_id, which carries both the
# sensing date (3rd `_`-field, YYYYMMDD...) and the MGRS tile (5th field).
.enumerate_cache_scenes <- function(cache_dir, index, date_from, date_to) {
  bands <- switch(index,
                  NDVI = c("B04", "B08"),
                  NBR  = c("B08", "B12"),
                  NDMI = c("B08", "B11"),
                  NDRE = c("B05", "B8A"),   # spec 022 red-edge
                  cli::cli_abort("Unknown index {.val {index}}."))
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


# Mosaic per-tile alert rasters that were each projected to EPSG:2154
# independently. `terra::project(x, "EPSG:2154")` (no template) lets terra
# derive the output resolution from each tile's own extent, so two tiles —
# especially native 20 m ones (NDRE = B8A/B05) over neighbouring MGRS tiles
# (T31TFM + T31TGM) — can come out at marginally different resolutions and
# `terra::mosaic()` aborts with "[mosaic] resolution does not match". (Native
# 10 m indices like NDMI happen to round to the same resolution, which is why
# they don't reproduce the bug.) We snap every tile onto ONE shared grid —
# the first tile's resolution, over the union extent, same origin — with a
# `terra::resample()` (mode-appropriate method) before mosaicking, so the
# mosaic is well-defined regardless of per-tile projection drift.
.mosaic_per_tile <- function(rasters, method) {
  tgt_res <- terra::res(rasters[[1L]])
  rx <- tgt_res[1L]; ry <- tgt_res[2L]
  xmn <- min(vapply(rasters, terra::xmin, numeric(1)))
  xmx <- max(vapply(rasters, terra::xmax, numeric(1)))
  ymn <- min(vapply(rasters, terra::ymin, numeric(1)))
  ymx <- max(vapply(rasters, terra::ymax, numeric(1)))
  # Snap the union extent OUTWARD to whole multiples of the target resolution
  # (aligned to the projected origin) so the template keeps EXACTLY `tgt_res`.
  # `terra::rast(ext, resolution=)` otherwise tweaks the resolution to divide
  # an arbitrary extent evenly, which would reintroduce a per-call resolution
  # drift — the very thing we are fixing.
  full <- terra::ext(floor(xmn / rx) * rx, ceiling(xmx / rx) * rx,
                     floor(ymn / ry) * ry, ceiling(ymx / ry) * ry)
  tmpl <- terra::rast(full, resolution = tgt_res, crs = "EPSG:2154")
  aligned <- lapply(rasters, function(r) terra::resample(r, tmpl,
                                                         method = method))
  do.call(terra::mosaic, c(aligned, list(fun = "max")))
}


# Layer name for the continuous FAST raster, by mode.
.fast_layer_name <- function(mode) {
  switch(mode,
         count   = "alert_count",
         rolling = "alert_deficit",
         trend   = "alert_trend",
         "alert_deficit")
}


# `"trend"` mode (spec 023) — multi-year monotonic decline magnitude.
# Builds a seasonal yearly composite from the index stack, then fits a
# Theil-Sen slope + Mann-Kendall significance test per pixel. Returns a
# single-layer SpatRaster aligned with the input:
#   * `NA`  where the pixel has fewer than `min_years` valid composite
#     years (not enough signal to judge a trend),
#   * `0`   where the decline is not monotonic / not significant
#     (slope >= 0 or Mann-Kendall p >= alpha),
#   * `abs(slope)` (index units per year) where the pixel declines
#     significantly.
# This is the same 0 / >0 contract as count & rolling, so
# `compute_fast_alert_mask()` discretises it unchanged. Returns NULL when
# no in-season scene exists at all.
.fast_raster_trend <- function(stack, months, min_years,
                               min_obs_per_year, alpha) {
  dates <- terra::time(stack)
  if (length(dates) == 0L) return(NULL)
  dates <- as.Date(dates)
  mo <- as.integer(format(dates, "%m"))
  yr <- as.integer(format(dates, "%Y"))

  in_season <- mo %in% months
  if (!any(in_season)) return(NULL)
  stack <- stack[[which(in_season)]]
  yr    <- yr[in_season]
  uy    <- sort(unique(yr))

  # One median composite layer per year, NA where the pixel has fewer than
  # `min_obs_per_year` clear (non-NA) observations that year.
  yearly <- lapply(uy, function(y) {
    sub  <- stack[[which(yr == y)]]
    # `terra::app(sub, fun)` errors when `sub` has a single layer (a year
    # with one in-season scene), so use cell-wise terra primitives that are
    # robust to any layer count: non-NA count via nlyr - countNA, and the
    # per-cell median via terra::median (all-NA cells -> NaN, masked next).
    nok  <- terra::nlyr(sub) - terra::countNA(sub)
    med  <- terra::median(sub, na.rm = TRUE)
    terra::ifel(nok < min_obs_per_year, NA_real_, med)
  })
  yearly <- terra::rast(yearly)

  # Even the most-covered pixel can't reach `min_years`: short-circuit to
  # an all-NA raster (downstream mask will be empty, never an error).
  if (terra::nlyr(yearly) < min_years) {
    out <- terra::setValues(yearly[[1L]], NA_real_)
    names(out) <- "alert_trend"
    return(out)
  }

  # spec 023 (perf) — fit Theil-Sen + Mann-Kendall on the yearly value
  # matrix instead of a per-pixel `terra::app` callback. The former called
  # `combn` / `table` ONCE PER PIXEL, costing ~270 us/pixel (~4.5 min for a
  # 1 Mpx tile). Two levers replace it: (1) a vectorised pre-filter drops
  # every pixel with fewer than `min_years` valid composite years before
  # any fit, and (2) the slope and Mann-Kendall S are computed across all
  # surviving pixels at once via matrix column arithmetic (~9x). Only the
  # rare pixels whose values are not all distinct fall back to the exact
  # tie-corrected `.mann_kendall()`. NB: `terra::app(cores=)` cannot
  # serialise this closure and a furrr/PSOCK split was measured *slower*
  # than serial here (per-pixel maths too cheap to amortise serialisation)
  # — the win is vectorisation, not parallelism.
  vals    <- terra::values(yearly)            # ncell x nyears matrix
  present <- !is.na(vals)
  res     <- rep(NA_real_, nrow(vals))
  cand    <- which(rowSums(present) >= min_years)
  if (length(cand)) {
    n_cand <- length(cand)
    n_yr   <- terra::nlyr(yearly)
    cli::cli_alert_info(
      "FAST trend: Theil-Sen / Mann-Kendall on {n_cand} candidate pixel{?s} ({n_yr} composite years).")
    res[cand] <- .trend_fit_cells(vals[cand, , drop = FALSE],
                                  present[cand, , drop = FALSE],
                                  uy, alpha)
  }
  out <- terra::setValues(yearly[[1L]], res)
  names(out) <- "alert_trend"
  out
}


# spec 023 (perf) — vectorised Theil-Sen slope + Mann-Kendall significance
# across many pixels at once. `M` is a (pixel x year) matrix restricted to
# the candidate pixels (already known to hold >= min_years valid years),
# `present` its non-NA mask, `yrs` the composite years (aligned to the
# columns of `M`), `alpha` the significance level. Returns one value per
# row: `abs(slope)` for a significant monotonic decline, else `0`. Verified
# byte-identical to the per-pixel `.theil_sen` / `.mann_kendall` path,
# including heterogeneous NA coverage, flat series and partial ties.
.trend_fit_cells <- function(M, present, yrs, alpha) {
  p   <- ncol(M)
  prs <- utils::combn(p, 2L)
  dx  <- yrs[prs[2L, ]] - yrs[prs[1L, ]]
  # Pairwise year-to-year differences. A pair touching an absent year is
  # NA, so `na.rm` below restricts every pixel to its own present-year
  # pairs (years need not be contiguous — both Theil-Sen and Mann-Kendall
  # only require the values in chronological order, which columns are).
  D <- M[, prs[2L, ], drop = FALSE] - M[, prs[1L, ], drop = FALSE]
  ts_slope <- apply(sweep(D, 2L, dx, "/"), 1L, stats::median, na.rm = TRUE)
  S        <- rowSums(sign(D), na.rm = TRUE)
  n_i      <- rowSums(present)                       # valid years per pixel
  var_S    <- n_i * (n_i - 1) * (2 * n_i + 5) / 18   # no-tie MK variance
  # Continuity-corrected standard normal deviate, then two-sided p.
  Z <- ifelse(S > 0, (S - 1) / sqrt(var_S),
       ifelse(S < 0, (S + 1) / sqrt(var_S), 0))
  pv <- 2 * stats::pnorm(-abs(Z))
  # Exact tie correction (and the flat-series `p = NA`) for the few pixels
  # whose present values are not all distinct: defer to the scalar
  # Mann-Kendall so the result stays identical to the per-pixel path.
  # Continuous reflectance almost never ties, so this is a rare branch.
  tied <- apply(M, 1L, function(v) anyDuplicated(v[!is.na(v)]) > 0L)
  if (any(tied)) {
    wt <- which(tied)
    pv[wt] <- vapply(wt, function(i) {
      v <- M[i, ]; .mann_kendall(v[!is.na(v)])$p
    }, numeric(1))
  }
  # Significant monotonic DECLINE -> magnitude; everything else -> 0.
  ifelse(!is.na(ts_slope) & !is.na(pv) & ts_slope < 0 & pv < alpha,
         abs(ts_slope), 0)
}


# Theil-Sen slope estimator: the median of the pairwise slopes
# (y_j - y_i) / (x_j - x_i) over all i < j with x_j != x_i. Robust to
# outliers, no distributional assumption. Returns NA for < 2 points or
# when every x pair is tied.
.theil_sen <- function(x, y) {
  n <- length(x)
  if (n < 2L) return(NA_real_)
  idx <- utils::combn(n, 2L)
  dx  <- x[idx[2L, ]] - x[idx[1L, ]]
  dy  <- y[idx[2L, ]] - y[idx[1L, ]]
  keep <- dx != 0
  if (!any(keep)) return(NA_real_)
  stats::median(dy[keep] / dx[keep])
}


# Mann-Kendall trend test (normal approximation, two-sided p-value).
# Returns the S statistic, Kendall's tau, and the tie-corrected,
# continuity-corrected p-value. For n < 3 the test is undefined -> NA.
.mann_kendall <- function(y) {
  n <- length(y)
  if (n < 3L) return(list(S = NA_real_, tau = NA_real_, p = NA_real_))

  S <- 0
  for (k in seq_len(n - 1L)) {
    S <- S + sum(sign(y[(k + 1L):n] - y[k]))
  }

  # Variance with correction for tied groups.
  ties     <- as.numeric(table(y))
  tie_term <- sum(ties * (ties - 1) * (2 * ties + 5))
  var_S    <- (n * (n - 1) * (2 * n + 5) - tie_term) / 18
  if (var_S <= 0) return(list(S = S, tau = NA_real_, p = NA_real_))

  # Continuity-corrected standard normal deviate.
  Z <- if (S > 0) (S - 1) / sqrt(var_S)
       else if (S < 0) (S + 1) / sqrt(var_S)
       else 0
  p <- 2 * stats::pnorm(-abs(Z))

  n0        <- n * (n - 1) / 2
  tie_pairs <- sum(ties * (ties - 1) / 2)
  denom     <- sqrt((n0 - tie_pairs) * n0)
  tau       <- if (denom > 0) S / denom else NA_real_

  list(S = S, tau = tau, p = min(p, 1))
}


# Extract the MGRS tile code (5th underscore-separated field) from an
# S2 product id. Handles both the 6-field Planetary Computer form and
# the 7-field ESA `.SAFE` form (cf. v0.41.2 `.s2_split_product_id`).
.s2_mgrs_tile <- function(scene_id) {
  parts <- strsplit(scene_id, "_", fixed = TRUE)[[1L]]
  if (length(parts) >= 5L) parts[[5L]] else NA_character_
}
