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
#' @param project_uuid Optional character scalar (or `NULL`, default).
#'   Opaque project identifier used by callers (`nemetonshiny`) to
#'   stably bind a project to its monitoring zone. When non-`NULL`,
#'   stored on `monitoring_zone.project_uuid` and queryable via
#'   [find_zone_by_project()]. UNIQUE on non-`NULL` values — registering
#'   a second zone with the same `project_uuid` raises a DB error.
#'   Available since spec 011 (migration `0003_project_uuid`).
#'
#' @return The `zone_id` (integer) of the registered zone.
#'
#' @export
register_monitoring_zone <- function(con, zone_name, zone_polygon,
                                     placettes, radius_m = 15,
                                     project_uuid = NULL) {
  .assert_db_pkgs()
  if (!inherits(zone_polygon, c("sf", "sfc"))) {
    cli::cli_abort("{.arg zone_polygon} must be an sf/sfc object.")
  }
  if (!inherits(placettes, "sf") || !"plot_id" %in% names(placettes)) {
    cli::cli_abort("{.arg placettes} must be an sf object with a {.val plot_id} column.")
  }
  if (!is.null(project_uuid)) {
    if (!is.character(project_uuid) || length(project_uuid) != 1L ||
        is.na(project_uuid) || !nzchar(project_uuid)) {
      cli::cli_abort("{.arg project_uuid} must be a non-empty character scalar or {.code NULL}.")
    }
  }

  zone_4326 <- sf::st_transform(zone_polygon, 4326)
  zone_wkt  <- sf::st_as_text(sf::st_geometry(zone_4326)[[1]])

  zone_id <- DBI::dbWithTransaction(con, {
    if (is.null(project_uuid)) {
      .db_execute(con,
        "INSERT INTO monitoring_zone (name, zone_wkt, crs_epsg) VALUES ($1, $2, 4326)",
        params = list(zone_name, zone_wkt))
      rs <- .db_get_query(con,
        "SELECT id FROM monitoring_zone WHERE name = $1 ORDER BY id DESC LIMIT 1",
        params = list(zone_name))
    } else {
      .db_execute(con,
        paste0("INSERT INTO monitoring_zone (name, zone_wkt, crs_epsg, project_uuid) ",
               "VALUES ($1, $2, 4326, $3)"),
        params = list(zone_name, zone_wkt, project_uuid))
      rs <- .db_get_query(con,
        "SELECT id FROM monitoring_zone WHERE project_uuid = $1",
        params = list(project_uuid))
    }
    rs$id[1]
  })

  pts <- sf::st_transform(placettes, 4326)
  geoms <- sf::st_geometry(pts)
  type <- if ("type" %in% names(pts)) as.character(pts$type) else rep(NA_character_, nrow(pts))
  for (i in seq_len(nrow(pts))) {
    .db_execute(con,
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
#' @param max_cloud Numeric. Maximum scene cloud cover (percent). Default 20.
#' @param skip_cached Logical. When `TRUE` (default since v0.21.3),
#'   query `obs_pixel` before the STAC loop and skip every scene
#'   whose `obs_date` already has a row for **every** plot of the
#'   zone × **every** requested band. Lets re-runs against an
#'   existing database avoid all the per-scene HTTP traffic. Set
#'   `FALSE` to force re-extraction (e.g. after invalidating
#'   `obs_pixel` manually).
#' @param cache_dir Optional path to a directory under which cropped
#'   band rasters are persisted as tiled GeoTIFF (COG-compatible
#'   layout) at `<cache_dir>/<scene_id>/<band>.tif`. On a cache hit
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
#'   `<project>/cache/layers/<layer>` convention (with `<layer>` one of
#'   `lidar_mnh`, `lidar_mnt`, `lidar_nuage`, etc.) already used by
#'   `detect_ndp_from_cache()`. The
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
#'     \item{`s2:band_fetch_retry`}{Transient network error (DNS,
#'       timeout, connection refused, 5xx) on a band fetch; sleeping
#'       and retrying — payload: `scene_id`, `band`, `attempt`,
#'       `max_tries`, `retry_in_sec`, `error_message`. Override the
#'       max-attempts budget with the `NEMETON_S2_MAX_TRIES` env var
#'       (default 3).}
#'     \item{`s2:band_fetch_failed`}{`terra::rast(href)` raised an
#'       unrecoverable error (after the PC token refresh path and
#'       transient-network retries if applicable) — payload:
#'       `scene_id`, `band`, `href`, `error_message`. The scene is
#'       then skipped at scene level (`s2:scene_skipped`).}
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

  # Always-on cache status banner. Catches the most common wiring bug
  # ("I forgot to pass cache_dir") at the very first line of output, so
  # a missing argument can't go unnoticed for 30 minutes of ingestion.
  if (is.null(cache_dir) || !nzchar(cache_dir)) {
    cli::cli_alert_info("S2 band cache: {.strong DISABLED} ({.code cache_dir} is NULL or empty).")
  } else {
    cli::cli_alert_info("S2 band cache: enabled at {.path {cache_dir}}")
    if (!dir.exists(cache_dir)) {
      dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
      cli::cli_alert_info("S2 cache directory created.")
    }
  }
  if (.s2_cache_debug_enabled()) {
    cli::cli_alert_info("S2 cache verbose tracing: ON ({.envvar NEMETON_S2_CACHE_DEBUG}=TRUE).")
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

  # spec 012 — the STAC search bbox AND the COG crop are driven by
  # `monitoring_zone.zone_wkt` (the UGF envelope registered by the
  # app), not by the per-plot bbox. This is what makes the on-disk S2
  # cache shareable between FAST and FORDEAD: both pipelines now ask
  # the COG for the same crop. Fallback to the plot bbox (v0.43.x
  # behaviour) when the zone has no WKT — typically a zone created by
  # a script that bypassed `register_monitoring_zone()`.
  aoi_zone <- tryCatch(.get_zone_aoi(con, zone_id), error = function(e) NULL)
  if (is.null(aoi_zone)) {
    cli::cli_warn(c(
      "Zone {.val {zone_id}} has no usable {.field zone_wkt}; falling back to per-plot bbox (legacy behaviour).",
      i = "Re-register the zone via {.fn register_monitoring_zone} so FAST and FORDEAD share the same cache."
    ))
    aoi_zone <- sf::st_sf(geometry = sf::st_as_sfc(sf::st_bbox(plots)),
                          crs = sf::st_crs(plots))
  }
  bbox <- sf::st_as_sfc(sf::st_bbox(sf::st_transform(aoi_zone, 4326)))
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
      .extract_scene_obs(sc, plots, bands, crop_aoi = aoi_zone,
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
    .db_get_query(con, sql,
                    params = list(as.character(start), as.character(end))),
    error = function(e) {
      cli::cli_warn("Cache lookup against {.code obs_pixel} failed: {conditionMessage(e)}. Re-extracting all scenes.")
      NULL
    }
  )
  if (is.null(rs) || !nrow(rs)) return(as.Date(character(0)))
  as.Date(rs$obs_date)
}

#' Diagnose an S2 band cache directory
#'
#' Walks `<cache_dir>/<scene_id>/` and reports how many scene
#' directories are populated (contain at least one `.tif`) versus
#' empty (no `.tif`). Empty dirs are typically leftovers from the
#' v0.21.4 eager-creation bug (fixed in v0.21.6) — they can be
#' safely wiped. Use this as a one-shot sanity check after running
#' `ingest_sentinel2_timeseries(..., cache_dir = ...)`.
#'
#' @param cache_dir Character. Path to the S2 cache root, e.g.
#'   `<project>/cache/layers/sentinel2`.
#' @param verbose Logical. When `TRUE` (default), print a `cli`
#'   summary; when `FALSE` only return the result list invisibly.
#'
#' @return Invisibly, a list with `cache_dir`, `n_scenes`,
#'   `n_populated`, `n_empty`, `total_bytes`, `bands_per_scene`
#'   (mean), and `empty_dirs` (character vector of paths).
#'
#' @examples
#' \dontrun{
#' diagnose_s2_cache(file.path(project_path, "cache", "layers", "sentinel2"))
#' # i S2 cache at <project>/cache/layers/sentinel2
#' #   * Scene directories: 159
#' #   * Populated: 12 (3.4 MB)
#' #   * Empty: 147   <- leftover from v0.21.4 or active fetch failures
#' }
#'
#' @export
diagnose_s2_cache <- function(cache_dir, verbose = TRUE) {
  if (is.null(cache_dir) || !nzchar(cache_dir) || !dir.exists(cache_dir)) {
    if (verbose) {
      cli::cli_alert_danger("S2 cache directory not found: {.path {cache_dir %||% '<NULL>'}}")
    }
    return(invisible(list(
      cache_dir       = cache_dir,
      n_scenes        = 0L, n_populated = 0L, n_empty = 0L,
      total_bytes     = 0,  bands_per_scene = 0,
      empty_dirs      = character(0)
    )))
  }
  scene_dirs <- list.dirs(cache_dir, recursive = FALSE)
  n_scenes <- length(scene_dirs)
  if (!n_scenes) {
    if (verbose) {
      cli::cli_alert_info("S2 cache at {.path {cache_dir}} is empty (no scene directories).")
    }
    return(invisible(list(
      cache_dir = cache_dir, n_scenes = 0L, n_populated = 0L,
      n_empty = 0L, total_bytes = 0, bands_per_scene = 0,
      empty_dirs = character(0)
    )))
  }

  per_scene <- lapply(scene_dirs, function(d) {
    tifs <- list.files(d, pattern = "\\.tif$", full.names = TRUE)
    if (!length(tifs)) {
      list(populated = FALSE, n_bands = 0L, bytes = 0)
    } else {
      list(populated = TRUE,
           n_bands   = length(tifs),
           bytes     = sum(file.info(tifs)$size, na.rm = TRUE))
    }
  })
  pop_idx     <- vapply(per_scene, function(x) x$populated, logical(1))
  n_pop       <- sum(pop_idx)
  n_empty     <- n_scenes - n_pop
  total_bytes <- sum(vapply(per_scene, function(x) x$bytes, numeric(1)))
  mean_bands  <- if (n_pop) {
    mean(vapply(per_scene[pop_idx], function(x) x$n_bands, integer(1)))
  } else 0
  empty_dirs  <- scene_dirs[!pop_idx]

  if (verbose) {
    fmt_mb <- function(b) formatC(b / 1e6, digits = 1, format = "f")
    cli::cli_alert_info("S2 cache at {.path {cache_dir}}")
    cli::cli_bullets(c(
      "*" = "Scene directories: {n_scenes}",
      "*" = "Populated: {n_pop} ({fmt_mb(total_bytes)} MB, mean {round(mean_bands, 1)} bands/scene)",
      "*" = "Empty: {n_empty}"
    ))
    if (n_empty > 0) {
      cli::cli_alert_warning(c(
        "Empty scene dirs detected. Most likely causes:"
      ))
      cli::cli_li(c(
        "Leftover from v0.21.4 (eager dir-creation bug, fixed in v0.21.6).",
        "Active fetch failure: scan warnings for {.code S2 band cache write failed} or {.code Scene .* skipped}.",
        "Wiring: confirm {.code cache_dir} is passed to {.fn ingest_sentinel2_timeseries}."
      ))
      cli::cli_alert_info("Wipe leftovers safely: {.code unlink(diagnose_s2_cache(...)$empty_dirs, recursive = TRUE)}.")
    }
  }
  invisible(list(
    cache_dir       = cache_dir,
    n_scenes        = as.integer(n_scenes),
    n_populated     = as.integer(n_pop),
    n_empty         = as.integer(n_empty),
    total_bytes     = total_bytes,
    bands_per_scene = mean_bands,
    empty_dirs      = empty_dirs
  ))
}

.fetch_plots_sf <- function(con, zone_id) {
  rs <- .db_get_query(con,
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

.extract_scene_obs <- function(scene, plots, bands, crop_aoi = NULL,
                               cache_dir = NULL, emit = NULL) {
  # Buffer plots in their native projected CRS (Lambert-93 by default
  # for FR; in 4326 we'd buffer in degrees, which is wrong).
  plots_proj <- sf::st_transform(plots, 2154)
  buf <- sf::st_buffer(plots_proj, dist = plots_proj$radius_m)

  # spec 012 — crop the COG to the zone envelope (`crop_aoi`) so the
  # cache key matches between FAST and FORDEAD; the per-plot buffer
  # `buf` is only used downstream for `exact_extract`. When `crop_aoi`
  # is NULL (legacy caller), fall back to the buffer bbox.
  crop_geom <- if (is.null(crop_aoi)) buf else crop_aoi

  rB04 <- .get_s2_band_raster(scene, "B04", crop_geom, cache_dir, emit)
  rB08 <- .get_s2_band_raster(scene, "B08", crop_geom, cache_dir, emit)
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
    rB12 <- .get_s2_band_raster(scene, "B12", crop_geom, cache_dir, emit)
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

# Verbose tracer for diagnosing why no .tif lands on disk. Off by
# default; enable with `Sys.setenv(NEMETON_S2_CACHE_DEBUG = "TRUE")`
# (or the env var at process launch). Writes via `message()` so the
# output is captured by Shiny / RStudio / `future_promise` worker
# logs even when the calling thread doesn't render `cli` output.
.s2_cache_debug_enabled <- function() {
  v <- Sys.getenv("NEMETON_S2_CACHE_DEBUG", "FALSE")
  isTRUE(as.logical(v)) || identical(v, "1")
}
.s2_cache_log <- function(...) {
  if (.s2_cache_debug_enabled()) {
    message(sprintf("[s2_cache %s] %s",
                    format(Sys.time(), "%H:%M:%S"),
                    paste0(c(...), collapse = "")))
  }
}

# Filesystem-safe variant of a scene_id for use as a directory name.
# Shared between the write path (`.s2_band_cache_path`) and the read
# path (spec 010 — `read_s2_band_raster` and friends in
# `R/pixel-map.R`). Keeping one definition guarantees writes and
# reads agree on the on-disk layout — if a future scene_id contains
# a new exotic character, we change the rule here and only here.
.s2_safe_scene_id <- function(scene_id) {
  gsub("[^A-Za-z0-9._-]", "_", as.character(scene_id))
}

# Filesystem-safe COG path for one band. Does NOT create any
# directory — creation is deferred to the writeRaster moment in
# `.get_s2_band_raster()` so a failed VSI fetch no longer leaves
# behind an empty scene directory.
.s2_band_cache_path <- function(cache_dir, scene_id, band) {
  if (is.null(cache_dir) || !nzchar(cache_dir)) return(NULL)
  safe_id <- .s2_safe_scene_id(scene_id)
  file.path(cache_dir, safe_id, paste0(band, ".tif"))
}

# Coerce an extent-like to a length-4 numeric in (xmin, xmax, ymin, ymax)
# order. `terra::SpatExtent` is an S4 object — `outer[1]` returns a
# nested S4 element (NOT a plain double), so the old
# `as.numeric(c(outer[1], …))` blew up with
# "cannot coerce type 'S4' to vector of type 'double'" on every cache
# hit. We now route SpatExtent through `terra::xmin()/xmax()/ymin()/ymax()`
# which are bulletproof across terra versions.
.ext_as_numeric <- function(e) {
  if (inherits(e, "SpatExtent")) {
    c(terra::xmin(e), terra::xmax(e), terra::ymin(e), terra::ymax(e))
  } else {
    as.numeric(e)
  }
}

# Geometric predicate: does `outer` (xmin, xmax, ymin, ymax) contain
# `inner`? Accepts terra::ext() results or 4-numeric vectors. Robust
# to terra S4 indexing quirks since v0.21.8.
#
# `tolerance` (CRS units, typically metres for EPSG:32631) relaxes
# each bound by that amount, so a sub-pixel mismatch — typical of the
# `sf::st_transform(buf, raster_crs)` + `terra::crop(snap = "out")`
# pipeline run-to-run — does not trigger a spurious CACHE-STALE.
# Caller passes `max(terra::res(r_cached))` so that the slack is
# exactly one pixel of the cached raster. Default 0 = strict
# (back-compat for older callers). Spec « solution A » (v0.47.3).
.ext_contains <- function(outer, inner, tolerance = 0) {
  o <- .ext_as_numeric(outer)
  i <- .ext_as_numeric(inner)
  (o[1] - tolerance) <= i[1] && (o[2] + tolerance) >= i[2] &&
    (o[3] - tolerance) <= i[3] && (o[4] + tolerance) >= i[4]
}


# Snap a 4-vector or terra::SpatExtent (xmin, xmax, ymin, ymax) to a
# pixel grid of resolution `res` (CRS units). xmin/ymin floor down,
# xmax/ymax ceil up — same convention as `terra::crop(snap = "out")`.
# Returns a 4-numeric (xmin, xmax, ymin, ymax) on the grid.
#
# v0.48.1 fix : strict `.ext_contains(outer, inner, tolerance)` compared
# raw floats which were sensitive to the sub-pixel jitter introduced
# by `sf::st_transform(zone_polygon, raster_crs)` — even with 4-pixel
# absolute tolerance the predicate could return FALSE on extents that
# referenced the SAME pixel cell. Snap-to-grid eliminates the jitter
# at the source : both cached and needed extents are projected onto
# the COG's own pixel grid before comparison.
.snap_ext_to_grid <- function(ext, res) {
  e <- .ext_as_numeric(ext)
  c(floor(  e[1] / res) * res,
    ceiling(e[2] / res) * res,
    floor(  e[3] / res) * res,
    ceiling(e[4] / res) * res)
}


# Pixel-grid-aware containment : does `outer_ext` (a cached raster's
# extent) contain `inner_ext` (today's needed extent) after both are
# snapped to the COG's pixel grid `res` ? `tol_pixels` further relaxes
# each side by N pixels (default 1) to absorb the half-cell rounding
# that `snap = "out"` and `terra::ext(terra::vect(...))` may introduce
# on top of the snap. Returns a list :
#   - `ok`         : logical, TRUE if outer contains inner (snapped)
#   - `outer_snap` : 4-numeric, snapped outer
#   - `inner_snap` : 4-numeric, snapped inner
#   - `delta_m`    : 4-numeric, signed margin per side (xmin, xmax,
#                    ymin, ymax) in metres ; negative = inner overshoots
# Caller uses the list to log a diagnostic when ok is FALSE.
.ext_contains_at_grid <- function(outer_ext, inner_ext, res,
                                  tol_pixels = 1L) {
  o <- .snap_ext_to_grid(outer_ext, res)
  i <- .snap_ext_to_grid(inner_ext, res)
  tol <- tol_pixels * res
  delta <- c(
    i[1] - (o[1] - tol),  # xmin : positive = inside, negative = outside
    (o[2] + tol) - i[2],  # xmax
    i[3] - (o[3] - tol),  # ymin
    (o[4] + tol) - i[4]   # ymax
  )
  list(ok         = all(delta >= 0),
       outer_snap = o,
       inner_snap = i,
       delta_m    = delta)
}


# ENV bypass for the cache-hit validation. When set, every
# (cache-existing) file is trusted blindly and read straight from
# disk. Intended for emergency throughput when the user knows the
# cache is good but the predicate is being noisy. Active values :
# "TRUE" (case-insensitive) or "1".
.cache_skip_validation <- function() {
  v <- Sys.getenv("NEMETON_S2_CACHE_SKIP_VALIDATION", "")
  identical(toupper(v), "TRUE") || identical(v, "1")
}


# v0.48.3 — per-MGRS-tile native extent memoization. The tile-aware
# second-chance in `.get_s2_band_raster()` reads the COG header via
# `terra::rast(href)` to obtain the tile's footprint ; that GET range
# call costs ~10-25 s per band. An MGRS tile's footprint is identical
# for all bands of all dates of that tile (B04/B08/B12 cover the same
# 100 km × 100 km area, only the resolution differs). Cache it once
# per tile key (e.g. "T31TFM") per R session.
.s2_tile_ext_cache <- new.env(parent = emptyenv())

.s2_tile_ext_memoize <- function(tile_code, href) {
  if (!nzchar(tile_code) || is.na(tile_code)) return(NULL)
  if (exists(tile_code, envir = .s2_tile_ext_cache, inherits = FALSE)) {
    return(get(tile_code, envir = .s2_tile_ext_cache))
  }
  ext_native <- tryCatch({
    r_full <- terra::rast(.pc_ensure_fresh_href(href))
    terra::ext(r_full)
  }, error = function(e) {
    .s2_cache_log("Tile-ext memoize: terra::rast(href) failed for ",
                  tile_code, ": ", conditionMessage(e))
    NULL
  })
  if (!is.null(ext_native)) {
    assign(tile_code, ext_native, envir = .s2_tile_ext_cache)
  }
  ext_native
}

# Test helper — clears the in-session memo. Mostly useful for
# integration tests that want to assert the tile_ext_native is
# actually fetched, not served from a stale memo.
.s2_tile_ext_cache_clear <- function() {
  rm(list = ls(envir = .s2_tile_ext_cache),
     envir = .s2_tile_ext_cache)
  invisible(TRUE)
}

# Open a Sentinel-2 band href with `terra::rast()`, retrying on the
# following transient failures (up to `max_tries` attempts, default
# 3; override with the env var `NEMETON_S2_MAX_TRIES`):
#
# - PC SAS auth (40[13] / forbidden / unauthorized) on a PC blob URL
#   → invalidate cached token, re-sign href, retry immediately.
#   Top failure mode on long (>30 min) ingestions: STAC search signs
#   every href with a snapshot of the cached token, then each band
#   open hits Azure with a possibly-stale signature.
#
# - Network-transient (DNS / connection timed out / refused /
#   network unreachable / GDAL HTTP 5xx) → sleep with exponential
#   backoff (2 s, 4 s, 8 s, capped at 30 s) and retry the same href.
#   These typically clear in seconds on a flaky ISP / VPN
#   reconnect, so a hard skip used to lose entire scenes for a
#   30-second DNS hiccup.
#
# Any other error (404, malformed COG, etc.) propagates immediately.
#
# Emits `s2:pc_token_refreshed`, `s2:band_fetch_retry` (per retry on
# transient errors), and `s2:band_fetch_failed` (on giving up).
.terra_rast_with_pc_retry <- function(href,
                                      collection  = "sentinel-2-l2a",
                                      emit_fn     = NULL,
                                      scene_id    = NA_character_,
                                      band        = NA_character_,
                                      max_tries   = NULL,
                                      materialize = NULL) {
  if (is.null(max_tries)) {
    mt <- suppressWarnings(
      as.integer(Sys.getenv("NEMETON_S2_MAX_TRIES", "3"))
    )
    max_tries <- if (is.na(mt) || mt < 1L) 3L else mt
  }

  emit_failure <- function(msg) {
    if (!is.null(emit_fn)) {
      emit_fn(list(current       = "s2:band_fetch_failed",
                   scene_id      = scene_id,
                   band          = band,
                   href          = href,
                   error_message = msg))
    }
  }

  current_href <- href
  last_err     <- NULL
  for (attempt in seq_len(max_tries)) {
    r <- tryCatch({
      r0 <- terra::rast(current_href)
      # When a `materialize` closure is provided, run it INSIDE the
      # tryCatch so that the actual pixel reads (which terra defers
      # to whichever call first needs values — typically the caller's
      # writeRaster) happen under the same retry/refresh budget as
      # the metadata open. Without this, a SAS token that expires
      # between the rast() head request and the eventual byte-range
      # read on the COG silently surfaces as a writeRaster() failure
      # past the retry budget, leaving an empty
      # `<cache_dir>/{scene_id}/` behind (v0.21.10 fix).
      if (is.null(materialize)) r0 else materialize(r0)
    }, error = function(e) e)
    if (!inherits(r, "error")) return(r)

    last_err <- r
    err_msg <- conditionMessage(r)

    if (attempt == max_tries) break

    is_pc_blob <- grepl("blob\\.core\\.windows\\.net", current_href) &&
                  grepl("sig=", current_href, fixed = TRUE)
    is_auth <- grepl("\\b(40[13]|forbidden|unauthorized|authentication)\\b",
                     err_msg, ignore.case = TRUE, perl = TRUE)
    is_transient <- grepl(
      paste0("could not resolve host|could not connect|",
             "connection (timed out|reset|refused)|",
             "network (is )?unreachable|temporary failure|",
             "http error.*\\b5\\d{2}\\b|gdal error.*timeout"),
      err_msg, ignore.case = TRUE, perl = TRUE
    )

    if (is_pc_blob && is_auth) {
      # PC SAS token refresh path — no sleep, retry on a fresh URL.
      .pc_invalidate_token(collection)
      fresh_href <- .pc_resign_href(href, collection)
      if (is.null(fresh_href)) {
        emit_failure(paste0(err_msg, " (token refresh failed)"))
        stop(last_err)
      }
      if (!is.null(emit_fn)) {
        emit_fn(list(current    = "s2:pc_token_refreshed",
                     scene_id   = scene_id,
                     band       = band,
                     collection = collection))
      }
      current_href <- fresh_href
      next
    }

    if (is_transient) {
      sleep_s <- min(30, 2L^attempt)
      if (!is.null(emit_fn)) {
        emit_fn(list(current        = "s2:band_fetch_retry",
                     scene_id       = scene_id,
                     band           = band,
                     attempt        = as.integer(attempt),
                     max_tries      = as.integer(max_tries),
                     retry_in_sec   = as.integer(sleep_s),
                     error_message  = err_msg))
      }
      cli::cli_alert_info(c(
        "Transient S2 fetch error ({.val {scene_id}}/{band}, attempt {attempt}/{max_tries}): {err_msg}",
        i = "Retrying in {sleep_s}s."
      ))
      Sys.sleep(sleep_s)
      next
    }

    # Non-recoverable (404, malformed COG, etc.) — propagate.
    emit_failure(err_msg)
    stop(last_err)
  }

  # All attempts exhausted.
  emit_failure(conditionMessage(last_err))
  cli::cli_warn(c(
    "S2 band fetch gave up on {.val {scene_id}}/{band} after {max_tries} attempts.",
    i = "Last error: {conditionMessage(last_err)}"
  ))
  stop(last_err)
}

# Return the (cropped) terra SpatRaster for one S2 band. Reads from
# `cache_dir` if a usable cached file exists; otherwise fetches via
# VSI, crops, and writes to cache (best-effort, write failures only
# warn).
#
# Since spec 012 the third argument is the zone AOI (an sf polygon)
# rather than the per-plot buffer — same shape, but now the cache key
# is stable across FAST and FORDEAD runs against the same zone. The
# parameter name `buf_plots` is preserved for back-compat with mocks
# that name it explicitly (`local_mocked_bindings(.get_s2_band_raster
# = function(scene, band, buf_plots, ...))`).
.get_s2_band_raster <- function(scene, band, buf_plots,
                                cache_dir = NULL, emit = NULL) {
  scene_id <- as.character(scene$scene_id)
  cached_path <- .s2_band_cache_path(cache_dir, scene_id, band)

  .s2_cache_log("ENTER scene=", scene_id, " band=", band,
                " cache_dir=",
                if (is.null(cache_dir)) "<NULL>" else cache_dir,
                " cached_path=",
                if (is.null(cached_path)) "<NULL>" else cached_path)

  href_col <- paste0("href_", band)
  if (!href_col %in% names(scene)) {
    cli::cli_abort(c(
      "Scene {.val {scene_id}} has no {.field {href_col}} column.",
      i = "STAC search did not expose this band. Add it to {.field .S2_STAC_BANDS}."
    ))
  }
  href <- scene[[href_col]][[1]]
  if (!nzchar(href) || is.na(href)) {
    cli::cli_abort(c(
      "Scene {.val {scene_id}} has no asset for band {.val {band}}.",
      i = "The STAC item exposed the column but the href is empty.",
      i = "Skip this scene for pipelines that need band {.val {band}}."
    ))
  }

  emit_fn <- function(payload) {
    if (!is.null(emit)) emit(payload)
  }

  # Try cache first.
  if (!is.null(cached_path) && file.exists(cached_path)) {
    .s2_cache_log("CACHE-HIT? checking ", cached_path,
                  " (", file.info(cached_path)$size, " bytes)")
    r_cached <- tryCatch(terra::rast(cached_path), error = function(e) {
      .s2_cache_log("CACHE-HIT abort: terra::rast(local) failed: ",
                    conditionMessage(e))
      NULL
    })
    if (!is.null(r_cached)) {
      # ENV bypass (v0.48.1) : skip validation entirely when the user
      # opts in. Useful when a stable cache exists but the predicate
      # is being noisy on legacy extents. The post-crop step below
      # still happens, so the returned raster is properly aligned to
      # today's AOI.
      if (.cache_skip_validation()) {
        buf_native <- sf::st_transform(buf_plots, terra::crs(r_cached))
        needed_ext <- terra::ext(terra::vect(buf_native))
        r_cached   <- terra::crop(r_cached, needed_ext, snap = "out")
        .s2_cache_log("CACHE-HIT (validation skipped via NEMETON_S2_CACHE_SKIP_VALIDATION)")
        emit_fn(list(current  = "s2:band_cached",
                     scene_id = scene_id,
                     band     = band,
                     path     = cached_path))
        return(r_cached)
      }

      buf_native <- sf::st_transform(buf_plots, terra::crs(r_cached))
      needed_ext <- terra::ext(terra::vect(buf_native))
      # v0.48.1 — snap both cached and needed extents to the COG's
      # pixel grid before comparing, with 1-pixel tolerance on each
      # side. Replaces the v0.47.4 absolute-metres tolerance which
      # was insensitive to the dimension of the sub-pixel jitter
      # being absorbed. Snap-to-grid eliminates the jitter at the
      # source : two extents that reference the same pixel cell are
      # snapped to the identical numeric value.
      res <- max(terra::res(r_cached))
      cont <- .ext_contains_at_grid(terra::ext(r_cached), needed_ext,
                                    res = res, tol_pixels = 1L)
      if (cont$ok) {
        # Re-crop to today's AOI so callers that arithmetic two
        # cached bands together (NDVI = (B08 - B04) / (B08 + B04))
        # see identical extents on both. snap = "out" rounds to the
        # cache's pixel grid, which is itself aligned to the source
        # tile's grid — so all bands stay co-registered.
        r_cached <- terra::crop(r_cached, needed_ext, snap = "out")
        .s2_cache_log("CACHE-HIT served from disk")
        emit_fn(list(current  = "s2:band_cached",
                     scene_id = scene_id,
                     band     = band,
                     path     = cached_path))
        return(r_cached)
      }

      # v0.48.2 tile-aware second chance — when the simple predicate
      # says STALE, the most common cause on multi-tile AOIs is that
      # the cached file was naturally clipped to the COG's MGRS tile
      # extent (e.g. villards spans T31TFM + T31TGM ; the T31TFM
      # cached file ends at xmax = 709800 = the FM/GM frontier).
      # Today's `needed_ext` covers the whole AOI (xmax = 710700),
      # which legitimately overshoots T31TFM by 90 px — but the
      # cached file holds ALL of T31TFM's contribution. Refetching
      # ramène RIEN de plus. Solution : lazy-read the COG headers
      # (cheap GET range, no pixel decode), clip `needed_ext` to the
      # tile's native extent, retry the predicate.
      #
      # v0.48.3 — memoize the tile's native extent per MGRS code
      # (key = "T31TFM", "T31TGM", ...). An MGRS tile's footprint is
      # identical for B04, B08, B12 (same SW corner, same 100 km
      # span ; only the cell resolution differs). The first scene of
      # a tile pays the ~25 s GET range cost ; all subsequent scenes
      # of the same tile (and any band) lookup is instant. Villards
      # paid ~1 h on the full re-validation pass ; with memoization,
      # ~25 s × 2 tiles = ~50 s total tile-header cost.
      tile_cont <- NULL
      tile_code <- .s2_mgrs_tile(scene_id)
      tile_ext_native <- if (!is.null(tile_code) && !is.na(tile_code)) {
        .s2_tile_ext_memoize(tile_code, href)
      } else NULL
      if (!is.null(tile_ext_native)) {
        needed_in_tile <- tryCatch(
          terra::intersect(needed_ext, tile_ext_native),
          error = function(e) NULL)
        if (!is.null(needed_in_tile) &&
            !is.na(terra::xmin(needed_in_tile))) {
          tile_cont <- .ext_contains_at_grid(
            terra::ext(r_cached), needed_in_tile,
            res = res, tol_pixels = 1L)
        }
      }
      if (!is.null(tile_cont) && tile_cont$ok) {
        r_cached <- terra::crop(r_cached, needed_in_tile, snap = "out")
        .s2_cache_log("CACHE-HIT served from disk (needed clipped to tile native extent)")
        emit_fn(list(current  = "s2:band_cached",
                     scene_id = scene_id,
                     band     = band,
                     path     = cached_path))
        return(r_cached)
      }

      # v0.48.1 diagnostic — log the snapped extents AND the per-side
      # margin so the user can see *which* boundary is failing and by
      # how many pixels. Negative delta = inner overshoots outer.
      .s2_cache_log(sprintf(paste(
        "CACHE-STALE extent does not cover AOI (snap-grid res=%.0fm",
        "tol=1px) :",
        " cached_snap=(%.0f,%.0f,%.0f,%.0f)",
        " needed_snap=(%.0f,%.0f,%.0f,%.0f)",
        " delta_m=(%.0f,%.0f,%.0f,%.0f),",
        "refetching"),
        res,
        cont$outer_snap[1], cont$outer_snap[2],
        cont$outer_snap[3], cont$outer_snap[4],
        cont$inner_snap[1], cont$inner_snap[2],
        cont$inner_snap[3], cont$inner_snap[4],
        cont$delta_m[1],    cont$delta_m[2],
        cont$delta_m[3],    cont$delta_m[4]))
    }
  } else if (!is.null(cached_path)) {
    .s2_cache_log("CACHE-MISS file does not exist yet")
  } else {
    .s2_cache_log("CACHE-DISABLED (cached_path is NULL)")
  }

  # Cache miss → fetch via VSI (with PC token auto-refresh on 403/401,
  # backoff on transient network errors), crop to AOI, and force pixel
  # materialization. The crop + read happen INSIDE the retry budget
  # via the `materialize` closure — otherwise pixel reads would only
  # fire later in terra::writeRaster(), past the retry window, and a
  # SAS token expiring mid-scene would silently produce an empty
  # `<cache_dir>/{scene_id}/` (the bug v0.21.10 fixes).
  #
  # v0.22.1: proactive PC SAS token refresh. The href in `scene` was
  # baked at STAC search time (potentially > 30 min ago on a long
  # run) so parse its `se=` and refresh if within 60 s of expiry —
  # this avoids a 403 round-trip per remaining scene that the
  # reactive retry in .terra_rast_with_pc_retry would otherwise catch.
  href <- .pc_ensure_fresh_href(href)
  .s2_cache_log("FETCH href=", href)
  r <- .terra_rast_with_pc_retry(
    href,
    emit_fn    = emit_fn,
    scene_id   = scene_id,
    band       = band,
    materialize = function(r0) {
      buf_native <- sf::st_transform(buf_plots, terra::crs(r0))
      needed_ext <- terra::ext(terra::vect(buf_native))
      r_cropped  <- terra::crop(r0, needed_ext, snap = "out")
      # Arithmetic with a scalar yields a new SpatRaster whose values
      # are read into RAM (canonical terra idiom for "make in-memory").
      # If any VSI range-request fails here — auth expiry, transient
      # 5xx, DNS hiccup mid-stream — the error surfaces inside the
      # retry loop and triggers re-sign / backoff. The downstream
      # writeRaster() then writes from RAM, no more VSI traffic.
      r_cropped + 0
    }
  )
  .s2_cache_log("FETCH+MATERIALIZE ok dim=",
                paste(dim(r)[1:2], collapse = "x"),
                " ext=",
                paste(round(.ext_as_numeric(terra::ext(r)), 1),
                      collapse = ","))

  if (!is.null(cached_path)) {
    # Lazy directory creation: only at the moment we're about to
    # write. A failed `.terra_rast_with_pc_retry()` above raises
    # before we get here, so a broken scene no longer leaves an
    # empty scene directory behind.
    scene_dir <- dirname(cached_path)
    .s2_cache_log("WRITE preparing dir.create(", scene_dir, ")")
    dir.create(scene_dir, recursive = TRUE, showWarnings = FALSE)
    if (!dir.exists(scene_dir)) {
      .s2_cache_log("WRITE ABORT dir.create did NOT yield a directory at ",
                    scene_dir, " (permissions?)")
      cli::cli_warn("S2 band cache: cannot create {.path {scene_dir}}. Check write permissions.")
      return(r)
    }
    tmp <- paste0(cached_path, ".tmp")
    .s2_cache_log("WRITE writeRaster -> ", tmp)
    tryCatch({
      # `filetype = "GTiff"` is REQUIRED — without it, terra infers the
      # GDAL driver from the file extension, and our temp file ends in
      # `.tmp` (e.g. `B04.tif.tmp`). Recent terra versions reject that
      # with "cannot guess file type from filename", so every write
      # failed silently and the cache stayed empty since v0.21.4
      # (v0.21.12 fix).
      terra::writeRaster(
        r, tmp, overwrite = TRUE,
        filetype = "GTiff",
        gdal = c("TILED=YES", "COMPRESS=DEFLATE",
                 "BLOCKXSIZE=256", "BLOCKYSIZE=256", "PREDICTOR=2")
      )
      sz <- if (file.exists(tmp)) file.info(tmp)$size else NA_integer_
      .s2_cache_log("WRITE ok size=", sz, " bytes")
      file.rename(tmp, cached_path)
      .s2_cache_log("RENAME ok -> ", cached_path)
      emit_fn(list(current  = "s2:band_fetched",
                   scene_id = scene_id,
                   band     = band,
                   path     = cached_path))
    }, error = function(e) {
      .s2_cache_log("WRITE ERROR: ", conditionMessage(e))
      if (file.exists(tmp)) unlink(tmp)
      cli::cli_warn("S2 band cache write failed for {.val {scene_id}}/{band}: {conditionMessage(e)}")
      # Clean up an orphan scene_dir we just created. Only remove if
      # empty — earlier bands of the same scene may have already
      # populated it, in which case we keep the partial cache.
      remaining <- list.files(scene_dir, all.files = FALSE,
                              no.. = TRUE)
      if (length(remaining) == 0L) {
        # `recursive = TRUE` is required: unlink() never removes a
        # directory with recursive = FALSE, even an empty one. The
        # emptiness guard above makes this safe.
        unlink(scene_dir, recursive = TRUE, force = FALSE)
        .s2_cache_log("WRITE cleanup removed empty ", scene_dir)
      }
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
  # would drop the table immediately. SQLite has no
  # `ON COMMIT DROP` clause — its TEMP tables are connection-scoped —
  # so for those backends we drop the table manually after the INSERT.
  staging <- "tmp_obs_pixel_staging"
  is_pg <- inherits(con, "PqConnection")
  DBI::dbWithTransaction(con, {
    if (is_pg) {
      .db_execute(con,
        paste0("CREATE TEMP TABLE IF NOT EXISTS ", staging, " (",
               "plot_id   INTEGER, ",
               "obs_date  DATE, ",
               "band      TEXT, ",
               "value     DOUBLE PRECISION, ",
               "cloud_pct NUMERIC, ",
               "source    TEXT, ",
               "scene_id  TEXT) ON COMMIT DROP"))
    } else {
      .db_execute(con, paste0("DROP TABLE IF EXISTS ", staging))
      .db_execute(con,
        paste0("CREATE TEMP TABLE ", staging, " (",
               "plot_id   INTEGER, ",
               "obs_date  DATE, ",
               "band      TEXT, ",
               "value     DOUBLE, ",
               "cloud_pct NUMERIC, ",
               "source    TEXT, ",
               "scene_id  TEXT)"))
    }
    DBI::dbAppendTable(con, staging, obs)
    rs <- .db_execute(con, sprintf(
      "INSERT INTO obs_pixel (plot_id, obs_date, band, value, cloud_pct, source, scene_id)
         SELECT plot_id, obs_date, band, value, cloud_pct, source, scene_id
         FROM %s
       ON CONFLICT (plot_id, obs_date, band) DO NOTHING",
      staging))
    if (!is_pg) {
      .db_execute(con, paste0("DROP TABLE ", staging))
    }
    rs
  })
}
