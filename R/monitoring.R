#' Sentinel-2 Time Series Ingestion (E6 monitoring)
#'
#' @description
#' Fetch Sentinel-2 L2A scenes covering a set of plots over a date
#' range, derive NDVI and NBR per scene, extract the per-plot mean
#' value over a circular buffer, and persist into the `obs_pixel`
#' hypertable of the monitoring database.
#'
#' Triggered on demand: no cron worker is started by this function.
#' One call = one ingestion window.
#'
#' @name monitoring_ingest
NULL


#' Register a monitoring zone and its plots in the database
#'
#' Helper that inserts a `monitoring_zone` row and the associated
#' `plot` rows. Idempotent on `(zone_id, plot_id)` — within an
#' existing zone, re-registering the same `plot_id` is a no-op
#' (UNIQUE constraint + `ON CONFLICT DO NOTHING`). The
#' `monitoring_zone` table has no uniqueness on `name`, so calling
#' this function twice with the same `zone_name` creates two
#' independent zones.
#'
#' @param con A `DBIConnection` returned by [db_connect()].
#' @param zone_name Character. Display name for the zone.
#' @param zone_polygon An sf POLYGON (any CRS — re-projected to WGS84
#'   internally for storage).
#' @param placettes An sf POINT object with at least the columns
#'   `plot_id` (character) and optionally `type`.
#' @param radius_m Numeric. Sampling radius around each placette in
#'   metres. Default 15.
#'
#' @return The `zone_id` (integer) of the registered zone.
#'
#' @export
register_monitoring_zone <- function(con, zone_name, zone_polygon,
                                     placettes, radius_m = 15) {
  .assert_db_pkgs()
  if (!inherits(zone_polygon, c("sf", "sfc"))) {
    cli::cli_abort("{.arg zone_polygon} must be an sf/sfc object.")
  }
  if (!inherits(placettes, "sf") || !"plot_id" %in% names(placettes)) {
    cli::cli_abort("{.arg placettes} must be an sf object with a {.val plot_id} column.")
  }

  zone_4326 <- sf::st_transform(zone_polygon, 4326)
  zone_wkt  <- sf::st_as_text(sf::st_geometry(zone_4326)[[1]])

  zone_id <- DBI::dbWithTransaction(con, {
    DBI::dbExecute(con,
      "INSERT INTO monitoring_zone (name, zone_wkt, crs_epsg) VALUES ($1, $2, 4326)",
      params = list(zone_name, zone_wkt))
    rs <- DBI::dbGetQuery(con,
      "SELECT id FROM monitoring_zone WHERE name = $1 ORDER BY id DESC LIMIT 1",
      params = list(zone_name))
    rs$id[1]
  })

  pts <- sf::st_transform(placettes, 4326)
  geoms <- sf::st_geometry(pts)
  type <- if ("type" %in% names(pts)) as.character(pts$type) else rep(NA_character_, nrow(pts))
  for (i in seq_len(nrow(pts))) {
    DBI::dbExecute(con,
      paste0("INSERT INTO plot (zone_id, plot_id, plot_type, geom_wkt, radius_m) ",
             "VALUES ($1, $2, $3, $4, $5) ",
             "ON CONFLICT (zone_id, plot_id) DO NOTHING"),
      params = list(zone_id,
                    as.character(pts$plot_id[i]),
                    type[i],
                    sf::st_as_text(geoms[[i]]),
                    radius_m))
  }
  invisible(as.integer(zone_id))
}


#' Ingest a Sentinel-2 time series for the plots of a monitoring zone
#'
#' Searches Sentinel-2 L2A scenes (CDSE then PC fallback), computes
#' NDVI and/or NBR per scene, extracts the mean per plot over a
#' circular buffer (`exactextractr::exact_extract`), and inserts the
#' results into `obs_pixel` (idempotent on
#' `(plot_id, obs_date, band)`).
#'
#' @param con A `DBIConnection`.
#' @param zone_id Integer. Existing zone in `monitoring_zone`.
#' @param start,end Date or character `"YYYY-MM-DD"`.
#' @param bands Character vector. Subset of `c("NDVI", "NBR")`.
#' @param max_cloud Numeric. Maximum scene cloud cover (%). Default 20.
#' @param skip_cached Logical. When `TRUE` (default since v0.21.3),
#'   query `obs_pixel` before the STAC loop and skip every scene
#'   whose `obs_date` already has a row for **every** plot of the
#'   zone × **every** requested band. Lets re-runs against an
#'   existing database avoid all the per-scene HTTP traffic. Set
#'   `FALSE` to force re-extraction (e.g. after invalidating
#'   `obs_pixel` manually).
#' @param cache_dir Optional path to a directory under which cropped
#'   band rasters are persisted as tiled GeoTIFF (COG-compatible
#'   layout) at `<cache_dir>/{scene_id}/{band}.tif`. On a cache hit
#'   the band is read locally (no HTTP); on a miss it is fetched via
#'   VSI, cropped, and written to the cache atomically. Cache write
#'   failures only warn — the pipeline continues with the in-memory
#'   raster. Cache reuse is *extent-aware*: a cached file whose
#'   bounding box no longer covers the requested plots is silently
#'   overwritten. Default `NULL` (no on-disk cache, v0.21.3
#'   behaviour). Combine with `skip_cached = FALSE` to force
#'   re-extraction from cached COGs without touching the network.
#'
#'   Recommended layout for callers (e.g. `nemetonshiny`):
#'   `<project>/cache/layers/sentinel2/`, matching the
#'   `<project>/cache/layers/{lidar_mnh,lidar_mnt,lidar_nuage,...}`
#'   convention already used by `detect_ndp_from_cache()`. The
#'   `cache/` subtree is for derived, regeneratable artefacts and
#'   should be in `.gitignore`; do not use `<project>/data/` which
#'   is reserved for user-owned project data.
#'
#'   \strong{Priming the cache on an existing zone.} The two cache
#'   layers (`skip_cached` and `cache_dir`) are independent: when
#'   `skip_cached = TRUE` (default) finds an `obs_date` already
#'   covered in `obs_pixel`, the scene is skipped \emph{before}
#'   `.extract_scene_obs()` runs, so no COG is written. If you
#'   enable `cache_dir` on a zone whose `obs_pixel` is already
#'   populated, run the ingestion \emph{once} with
#'   `skip_cached = FALSE` to force re-extraction: scenes go through
#'   the full path and the COGs land on disk; SQL INSERTs are
#'   `ON CONFLICT DO NOTHING` so the DB stays bit-identical
#'   (no duplicate rows, no overwritten values). Subsequent runs
#'   can revert to `skip_cached = TRUE` — the COG cache will then
#'   kick in only when a genuine re-extraction is needed
#'   (a new band, a new metric, a manual `obs_pixel` wipe).
#' @param progress_callback Optional function called at each step of
#'   the ingestion to allow callers (e.g. `nemetonshiny`) to report
#'   download progress to the user. Receives a single named list
#'   argument with at least `current` (a short phase key, see below)
#'   and, when meaningful, `completed` and `total` (numeric units).
#'   Phases emitted, in order:
#'   \describe{
#'     \item{`s2:search`}{Before the STAC query — payload includes
#'       `start`, `end`, `n_plots`, `bands`.}
#'     \item{`s2:search_done`}{After STAC — payload includes `total`
#'       (number of scenes found) and `bands`.}
#'     \item{`s2:cache_lookup`}{After the `obs_pixel` cache query
#'       (only when `skip_cached = TRUE`) — payload includes
#'       `n_cached` (scenes whose obs_date is already fully ingested
#'       and will be skipped) and `n_to_process` (scenes that will
#'       hit the network).}
#'     \item{`s2:scene_cached`}{For each scene skipped thanks to the
#'       cache — payload includes `completed = i - 1L`, `total`,
#'       `scene_id`, `obs_date`, `cloud_pct`, `source`.}
#'     \item{`s2:scene`}{Before processing each non-cached scene —
#'       payload includes `completed = i - 1L`, `total`, plus
#'       `scene_id`, `obs_date`, `cloud_pct`, `source`.}
#'     \item{`s2:scene_skipped`}{When a scene fails extraction —
#'       payload adds `error_message` to the `s2:scene` shape.}
#'     \item{`s2:band_cached`}{Per-band hit on the local COG cache
#'       (only when `cache_dir` is set) — payload: `scene_id`,
#'       `band`, `path`.}
#'     \item{`s2:band_fetched`}{Per-band miss → VSI fetch + write
#'       to the cache (only when `cache_dir` is set) — payload:
#'       `scene_id`, `band`, `path`.}
#'     \item{`s2:pc_token_refreshed`}{The Planetary Computer SAS
#'       token expired between STAC search and band read; the band
#'       open was retried with a fresh token — payload:
#'       `scene_id`, `band`, `collection`.}
#'     \item{`s2:band_fetch_failed`}{`terra::rast(href)` raised an
#'       unrecoverable error (after the PC token refresh path if
#'       applicable) — payload: `scene_id`, `band`, `href`,
#'       `error_message`. The scene is then skipped at scene level
#'       (`s2:scene_skipped`).}
#'     \item{`s2:complete`}{After the loop — payload includes
#'       `completed = total`, `total`, `n_obs_inserted`,
#'       `n_scenes_cached`.}
#'   }
#'   The callback is invoked synchronously inside the calling thread.
#'   Default `NULL` (silent — no callback emitted).
#'
#' @return A tibble summarising the ingestion: number of scenes
#'   considered, number of scenes skipped thanks to the cache,
#'   number of observations inserted, bands ingested.
#'
#' @examples
#' \dontrun{
#' # Typical wiring from nemetonshiny's monitoring worker.
#' cache <- file.path(project_path, "cache", "layers", "sentinel2")
#'
#' # First run on an already-populated zone, to prime the COG cache.
#' # SQL INSERTs are ON CONFLICT DO NOTHING -> DB stays bit-identical.
#' ingest_sentinel2_timeseries(
#'   con, zone_id, "2020-01-01", "2025-12-31",
#'   bands       = c("NDVI", "NBR"),
#'   skip_cached = FALSE,                 # force re-extraction
#'   cache_dir   = cache
#' )
#'
#' # Subsequent runs: skip_cached short-circuits at the DB level,
#' # cache_dir only kicks in when a genuine re-extraction is needed.
#' ingest_sentinel2_timeseries(
#'   con, zone_id, "2026-01-01", "2026-06-30",
#'   bands     = c("NDVI", "NBR"),
#'   cache_dir = cache                    # skip_cached defaults to TRUE
#' )
#' }
#'
#' @export
ingest_sentinel2_timeseries <- function(con, zone_id,
                                        start, end,
                                        bands = c("NDVI", "NBR"),
                                        max_cloud = 20,
                                        skip_cached = TRUE,
                                        cache_dir = NULL,
                                        progress_callback = NULL) {
  .assert_db_pkgs()
  if (!requireNamespace("terra", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg terra} required.")
  }
  if (!requireNamespace("exactextractr", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg exactextractr} required.")
  }
  bands <- match.arg(bands, c("NDVI", "NBR"), several.ok = TRUE)

  if (!is.null(cache_dir) && nzchar(cache_dir) && !dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Local emitter — no-op when no callback is set, keeps the body free
  # of `if (!is.null(progress_callback))` boilerplate.
  emit <- function(payload) {
    if (!is.null(progress_callback)) progress_callback(payload)
  }

  plots <- .fetch_plots_sf(con, zone_id)
  if (!nrow(plots)) {
    cli::cli_warn("No plots registered for zone_id {.val {zone_id}}. Use {.fn register_monitoring_zone} first.")
    return(.empty_ingest_summary())
  }

  emit(list(current = "s2:search",
            start   = as.character(start),
            end     = as.character(end),
            n_plots = nrow(plots),
            bands   = bands))

  bbox <- sf::st_as_sfc(sf::st_bbox(plots))
  scenes <- stac_search_s2(bbox, start, end, max_cloud = max_cloud)
  if (!nrow(scenes)) {
    cli::cli_alert_info("No Sentinel-2 scene found for zone_id {zone_id} between {start} and {end} (max_cloud = {max_cloud}%).")
    emit(list(current = "s2:search_done",
              total   = 0L,
              bands   = bands))
    return(.empty_ingest_summary())
  }

  total_scenes <- nrow(scenes)
  emit(list(current = "s2:search_done",
            total   = total_scenes,
            bands   = bands))

  # Cache lookup: which obs_dates are already fully covered for
  # *every* plot × *every* requested band? Those scenes never need
  # to hit the network. Cheap one-shot query against the local DB.
  cached_dates <- character(0)
  if (isTRUE(skip_cached)) {
    cached_dates <- as.character(
      .find_cached_obs_dates(con, plots$id, bands, start, end)
    )
    n_cached_scenes <- sum(as.character(scenes$obs_date) %in% cached_dates)
    emit(list(current      = "s2:cache_lookup",
              n_cached     = as.integer(n_cached_scenes),
              n_to_process = as.integer(total_scenes - n_cached_scenes)))
  }

  total_inserted <- 0L
  total_cached   <- 0L
  for (i in seq_len(total_scenes)) {
    sc <- scenes[i, , drop = FALSE]
    if (as.character(sc$obs_date) %in% cached_dates) {
      total_cached <- total_cached + 1L
      emit(list(current   = "s2:scene_cached",
                completed = as.integer(i - 1L),
                total     = as.integer(total_scenes),
                scene_id  = sc$scene_id,
                obs_date  = sc$obs_date,
                cloud_pct = sc$cloud_pct,
                source    = sc$source))
      next
    }
    emit(list(current   = "s2:scene",
              completed = as.integer(i - 1L),
              total     = as.integer(total_scenes),
              scene_id  = sc$scene_id,
              obs_date  = sc$obs_date,
              cloud_pct = sc$cloud_pct,
              source    = sc$source))
    obs <- tryCatch(
      .extract_scene_obs(sc, plots, bands,
                         cache_dir = cache_dir, emit = emit),
      error = function(e) {
        cli::cli_warn("Scene {.val {sc$scene_id}} skipped: {conditionMessage(e)}")
        emit(list(current       = "s2:scene_skipped",
                  completed     = as.integer(i - 1L),
                  total         = as.integer(total_scenes),
                  scene_id      = sc$scene_id,
                  obs_date      = sc$obs_date,
                  cloud_pct     = sc$cloud_pct,
                  source        = sc$source,
                  error_message = conditionMessage(e)))
        NULL
      }
    )
    if (is.null(obs) || !nrow(obs)) next
    inserted <- .insert_obs_pixel(con, obs)
    total_inserted <- total_inserted + inserted
  }

  emit(list(current         = "s2:complete",
            completed       = as.integer(total_scenes),
            total           = as.integer(total_scenes),
            n_obs_inserted  = as.integer(total_inserted),
            n_scenes_cached = as.integer(total_cached)))

  data.frame(
    n_scenes        = total_scenes,
    n_scenes_cached = total_cached,
    n_obs_inserted  = total_inserted,
    n_plots         = nrow(plots),
    bands           = paste(bands, collapse = "+"),
    stringsAsFactors = FALSE
  )
}


# ---- Internal helpers ------------------------------------------------

.empty_ingest_summary <- function() {
  data.frame(
    n_scenes = 0L, n_scenes_cached = 0L, n_obs_inserted = 0L,
    n_plots = 0L, bands = "",
    stringsAsFactors = FALSE
  )
}

# Return the Date vector of obs_dates whose `obs_pixel` rows already
# cover *every* plot in `plot_ids` × *every* band in `bands`. Used by
# `ingest_sentinel2_timeseries()` to short-circuit scenes that would
# only re-download data we already have.
#
# Inlines `plot_ids` and `bands` into the SQL: both come from
# trusted sources (our own `plot.id` integers + a whitelist of
# bands enforced by `match.arg`), so injection is impossible.
.find_cached_obs_dates <- function(con, plot_ids, bands, start, end) {
  if (!length(plot_ids) || !length(bands)) {
    return(as.Date(character(0)))
  }
  expected <- length(plot_ids) * length(bands)
  plot_list <- paste(as.integer(plot_ids), collapse = ", ")
  band_list <- paste(sprintf("'%s'", bands),    collapse = ", ")
  sql <- sprintf(
    "SELECT obs_date FROM obs_pixel
      WHERE plot_id IN (%s)
        AND band IN (%s)
        AND obs_date BETWEEN $1 AND $2
      GROUP BY obs_date
     HAVING COUNT(*) = %d",
    plot_list, band_list, expected
  )
  rs <- tryCatch(
    DBI::dbGetQuery(con, sql,
                    params = list(as.character(start), as.character(end))),
    error = function(e) {
      cli::cli_warn("Cache lookup against {.code obs_pixel} failed: {conditionMessage(e)}. Re-extracting all scenes.")
      NULL
    }
  )
  if (is.null(rs) || !nrow(rs)) return(as.Date(character(0)))
  as.Date(rs$obs_date)
}

.fetch_plots_sf <- function(con, zone_id) {
  rs <- DBI::dbGetQuery(con,
    "SELECT id, plot_id, plot_type, geom_wkt, radius_m
       FROM plot
      WHERE zone_id = $1
      ORDER BY id",
    params = list(zone_id))
  if (!nrow(rs)) return(sf::st_sf(data.frame(),
                                   geometry = sf::st_sfc(crs = 4326)))
  geoms <- lapply(rs$geom_wkt, sf::st_as_sfc, crs = 4326)
  geom_sfc <- do.call(c, geoms)
  rs$geom_wkt <- NULL
  sf::st_sf(rs, geometry = geom_sfc, crs = 4326)
}

.extract_scene_obs <- function(scene, plots, bands,
                               cache_dir = NULL, emit = NULL) {
  # Buffer plots in their native projected CRS (Lambert-93 by default
  # for FR; in 4326 we'd buffer in degrees, which is wrong).
  plots_proj <- sf::st_transform(plots, 2154)
  buf <- sf::st_buffer(plots_proj, dist = plots_proj$radius_m)

  rB04 <- .get_s2_band_raster(scene, "B04", buf, cache_dir, emit)
  rB08 <- .get_s2_band_raster(scene, "B08", buf, cache_dir, emit)
  buf_in_raster_crs_08 <- sf::st_transform(buf, terra::crs(rB08))
  # B04 and B08 share resolution (10 m), no resample needed.

  out <- list()

  if ("NDVI" %in% bands) {
    ndvi <- (rB08 - rB04) / (rB08 + rB04)
    vals <- exactextractr::exact_extract(ndvi, buf_in_raster_crs_08, "mean",
                                         progress = FALSE)
    out$NDVI <- data.frame(
      plot_id   = plots$id,
      obs_date  = scene$obs_date,
      band      = "NDVI",
      value     = as.numeric(vals),
      cloud_pct = scene$cloud_pct,
      source    = scene$source,
      scene_id  = scene$scene_id,
      stringsAsFactors = FALSE
    )
  }

  if ("NBR" %in% bands) {
    rB12 <- .get_s2_band_raster(scene, "B12", buf, cache_dir, emit)
    # B12 is 20 m — resample to B08 grid for the formula.
    rB12r <- terra::resample(rB12, rB08, method = "bilinear")
    nbr <- (rB08 - rB12r) / (rB08 + rB12r)
    vals <- exactextractr::exact_extract(nbr, buf_in_raster_crs_08, "mean",
                                         progress = FALSE)
    out$NBR <- data.frame(
      plot_id   = plots$id,
      obs_date  = scene$obs_date,
      band      = "NBR",
      value     = as.numeric(vals),
      cloud_pct = scene$cloud_pct,
      source    = scene$source,
      scene_id  = scene$scene_id,
      stringsAsFactors = FALSE
    )
  }

  do.call(rbind, out)
}


# ---- S2 band cache (option C, v0.21.4) -------------------------------
#
# Persist the cropped Sentinel-2 band rasters as tiled GeoTIFF (DEFLATE +
# PREDICTOR=2 — COG-compatible layout) under
# `<cache_dir>/{scene_id}/{band}.tif`. On cache hit, the local file is
# opened by terra without any HTTP traffic; on miss the band is fetched
# via VSI, cropped to the plots' bbox, and atomically written to disk.
#
# Stale-cache rule: a cached file is reused only if its extent fully
# contains the needed extent. If a re-run adds a new placette outside
# the previously cached window, the file is silently overwritten.

# Filesystem-safe COG path for one band. Does NOT create any
# directory — creation is deferred to the writeRaster moment in
# `.get_s2_band_raster()` so a failed VSI fetch no longer leaves
# behind an empty scene directory.
.s2_band_cache_path <- function(cache_dir, scene_id, band) {
  if (is.null(cache_dir) || !nzchar(cache_dir)) return(NULL)
  safe_id <- gsub("[^A-Za-z0-9._-]", "_", as.character(scene_id))
  file.path(cache_dir, safe_id, paste0(band, ".tif"))
}

# Geometric predicate: does `outer` (xmin, xmax, ymin, ymax) contain
# `inner`? Accepts terra::ext() results or 4-numeric vectors.
.ext_contains <- function(outer, inner) {
  o <- as.numeric(c(outer[1], outer[2], outer[3], outer[4]))
  i <- as.numeric(c(inner[1], inner[2], inner[3], inner[4]))
  o[1] <= i[1] && o[2] >= i[2] && o[3] <= i[3] && o[4] >= i[4]
}

# Open a Sentinel-2 band href with `terra::rast()`, retrying once
# with a fresh SAS token when the first attempt fails with a 403/401
# on a Planetary Computer blob URL. Token-expired-mid-ingestion is the
# top failure mode on long (>30 min) runs: STAC search signs every
# href with a snapshot of the cached token, then each band open hits
# Azure with a possibly-stale signature.
#
# Emits `s2:band_fetch_failed` when the band cannot be opened (after
# retry, if applicable) and `s2:pc_token_refreshed` when the retry
# path succeeds. Both events carry `scene_id` + `band` + `href`.
.terra_rast_with_pc_retry <- function(href,
                                      collection = "sentinel-2-l2a",
                                      emit_fn    = NULL,
                                      scene_id   = NA_character_,
                                      band       = NA_character_) {
  emit_failure <- function(msg) {
    if (!is.null(emit_fn)) {
      emit_fn(list(current       = "s2:band_fetch_failed",
                   scene_id      = scene_id,
                   band          = band,
                   href          = href,
                   error_message = msg))
    }
  }

  r1 <- tryCatch(terra::rast(href), error = function(e) e)
  if (!inherits(r1, "error")) return(r1)

  err_msg1 <- conditionMessage(r1)
  # PC blob URL? + auth-shaped error? Otherwise no point refreshing
  # — propagate the original error (and let the scene-level handler
  # decide what to do with it).
  is_pc_blob <- grepl("blob\\.core\\.windows\\.net", href) &&
                grepl("sig=", href, fixed = TRUE)
  is_auth <- grepl("\\b(40[13]|forbidden|unauthorized|authentication)\\b",
                   err_msg1, ignore.case = TRUE, perl = TRUE)

  if (!is_pc_blob || !is_auth) {
    emit_failure(err_msg1)
    stop(r1)
  }

  # Refresh the SAS token, re-sign, retry once.
  .pc_invalidate_token(collection)
  fresh_href <- .pc_resign_href(href, collection)
  if (is.null(fresh_href)) {
    emit_failure(paste0(err_msg1, " (token refresh failed)"))
    stop(r1)
  }
  if (!is.null(emit_fn)) {
    emit_fn(list(current    = "s2:pc_token_refreshed",
                 scene_id   = scene_id,
                 band       = band,
                 collection = collection))
  }
  r2 <- tryCatch(terra::rast(fresh_href), error = function(e) e)
  if (inherits(r2, "error")) {
    msg2 <- conditionMessage(r2)
    emit_failure(sprintf("before refresh: %s | after refresh: %s",
                         err_msg1, msg2))
    cli::cli_warn(c(
      "PC SAS token refresh did not unstick {.val {scene_id}}/{band}.",
      i = "Before refresh: {err_msg1}",
      i = "After refresh:  {msg2}"
    ))
    stop(r2)
  }
  r2
}

# Return the (cropped) terra SpatRaster for one S2 band. Reads from
# `cache_dir` if a usable cached file exists; otherwise fetches via
# VSI, crops, and writes to cache (best-effort, write failures only
# warn).
.get_s2_band_raster <- function(scene, band, buf_plots,
                                cache_dir = NULL, emit = NULL) {
  scene_id <- as.character(scene$scene_id)
  cached_path <- .s2_band_cache_path(cache_dir, scene_id, band)

  href_col <- paste0("href_", band)
  if (!href_col %in% names(scene)) {
    cli::cli_abort("Scene {.val {scene_id}} has no {.field {href_col}} column.")
  }
  href <- scene[[href_col]][[1]]

  emit_fn <- function(payload) {
    if (!is.null(emit)) emit(payload)
  }

  # Try cache first.
  if (!is.null(cached_path) && file.exists(cached_path)) {
    r_cached <- tryCatch(terra::rast(cached_path), error = function(e) NULL)
    if (!is.null(r_cached)) {
      buf_native <- sf::st_transform(buf_plots, terra::crs(r_cached))
      needed_ext <- terra::ext(terra::vect(buf_native))
      if (.ext_contains(terra::ext(r_cached), needed_ext)) {
        # Re-crop to today's AOI so callers that arithmetic two
        # cached bands together (NDVI = (B08 - B04) / (B08 + B04))
        # see identical extents on both. snap = "out" rounds to the
        # cache's pixel grid, which is itself aligned to the source
        # tile's grid — so all bands stay co-registered.
        r_cached <- terra::crop(r_cached, needed_ext, snap = "out")
        emit_fn(list(current  = "s2:band_cached",
                     scene_id = scene_id,
                     band     = band,
                     path     = cached_path))
        return(r_cached)
      }
      # Stale (extent doesn't cover plots) — drop and refetch below.
    }
  }

  # Cache miss → fetch via VSI (with PC token auto-refresh on 403/401),
  # crop to AOI.
  r <- .terra_rast_with_pc_retry(href,
                                 emit_fn  = emit_fn,
                                 scene_id = scene_id,
                                 band     = band)
  buf_native <- sf::st_transform(buf_plots, terra::crs(r))
  r <- terra::crop(r, terra::ext(terra::vect(buf_native)), snap = "out")

  if (!is.null(cached_path)) {
    # Lazy directory creation: only at the moment we're about to
    # write. A failed `.terra_rast_with_pc_retry()` above raises
    # before we get here, so a broken scene no longer leaves an
    # empty scene directory behind.
    dir.create(dirname(cached_path), recursive = TRUE,
               showWarnings = FALSE)
    tmp <- paste0(cached_path, ".tmp")
    tryCatch({
      terra::writeRaster(
        r, tmp, overwrite = TRUE,
        gdal = c("TILED=YES", "COMPRESS=DEFLATE",
                 "BLOCKXSIZE=256", "BLOCKYSIZE=256", "PREDICTOR=2")
      )
      file.rename(tmp, cached_path)
      emit_fn(list(current  = "s2:band_fetched",
                   scene_id = scene_id,
                   band     = band,
                   path     = cached_path))
    }, error = function(e) {
      if (file.exists(tmp)) unlink(tmp)
      cli::cli_warn("S2 band cache write failed for {.val {scene_id}}/{band}: {conditionMessage(e)}")
    })
  }
  r
}

.insert_obs_pixel <- function(con, obs) {
  if (!nrow(obs)) return(0L)
  # Bulk insert via a temp staging table to avoid per-row round-trips.
  # The CREATE must live INSIDE the same transaction as the
  # dbAppendTable / INSERT: under PG, `ON COMMIT DROP` fires at the end
  # of the enclosing transaction, so a CREATE outside dbWithTransaction
  # would drop the table immediately. DuckDB has no `ON COMMIT DROP`
  # clause — its TEMP tables are session-scoped — so we branch on the
  # driver and drop the table manually after the INSERT.
  staging <- "tmp_obs_pixel_staging"
  is_duckdb <- inherits(con, "duckdb_connection")
  DBI::dbWithTransaction(con, {
    if (is_duckdb) {
      DBI::dbExecute(con, paste0("DROP TABLE IF EXISTS ", staging))
      DBI::dbExecute(con,
        paste0("CREATE TEMP TABLE ", staging, " (",
               "plot_id   INTEGER, ",
               "obs_date  DATE, ",
               "band      TEXT, ",
               "value     DOUBLE, ",
               "cloud_pct NUMERIC, ",
               "source    TEXT, ",
               "scene_id  TEXT)"))
    } else {
      DBI::dbExecute(con,
        paste0("CREATE TEMP TABLE IF NOT EXISTS ", staging, " (",
               "plot_id   INTEGER, ",
               "obs_date  DATE, ",
               "band      TEXT, ",
               "value     DOUBLE PRECISION, ",
               "cloud_pct NUMERIC, ",
               "source    TEXT, ",
               "scene_id  TEXT) ON COMMIT DROP"))
    }
    DBI::dbAppendTable(con, staging, obs)
    rs <- DBI::dbExecute(con, sprintf(
      "INSERT INTO obs_pixel (plot_id, obs_date, band, value, cloud_pct, source, scene_id)
         SELECT plot_id, obs_date, band, value, cloud_pct, source, scene_id
         FROM %s
       ON CONFLICT (plot_id, obs_date, band) DO NOTHING",
      staging))
    if (is_duckdb) {
      DBI::dbExecute(con, paste0("DROP TABLE ", staging))
    }
    rs
  })
}
