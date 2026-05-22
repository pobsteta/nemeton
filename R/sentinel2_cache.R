#' Populate the Sentinel-2 COG cache with raw bands (no DB writes)
#'
#' Companion of [ingest_sentinel2_timeseries()] for callers that need
#' raw Sentinel-2 bands (e.g. `c("B02", "B04", "B05", "B8A", "B11", "B12")`
#' for FORDEAD CRSWIR + masks) rather than the derived NDVI / NBR
#' indices. Searches STAC, then for each scene x band calls the same
#' cache-aware fetcher used by the FAST pipeline ([.get_s2_band_raster()]),
#' so:
#'
#' - **cache-hit**: zero HTTP traffic, band returned from disk;
#' - **cache-miss**: one GET via VSI to Planetary Computer / CDSE,
#'   then written atomically to `<cache_dir>/<safe_scene_id>/<band>.tif`.
#'
#' Does **not** write anything to the database (no `obs_pixel` rows
#' produced). The DB connection is only used to resolve the AOI of the
#' monitoring zone.
#'
#' Emits the same `s2:*` events as [ingest_sentinel2_timeseries()]
#' through `progress_callback`: `search`, `search_done`, `scene`,
#' `band_cached`, `band_fetched`, `scene_skipped`, `complete`.
#'
#' @param con A `DBIConnection`.
#' @param zone_id Integer. Existing zone in `monitoring_zone`.
#' @param bands Character vector of raw band codes -- the letter `B`
#'   followed by one or two digits and an optional trailing `A`
#'   (e.g. `c("B02", "B04", "B8A", "B12")`). At least one band required.
#' @param start,end Date or character `"YYYY-MM-DD"`.
#' @param cache_dir Character(1). Root of the COG cache, typically
#'   `<project>/cache/layers/sentinel2`. Created if absent. Required.
#' @param max_cloud Numeric. Maximum scene cloud cover (percent). Default 20.
#' @param progress_callback Optional. `function(payload)` receiving
#'   `s2:*` event lists.
#'
#' @return A list with:
#'   \describe{
#'     \item{scenes_df}{`data.frame` (`scene_id`, `obs_date`,
#'       `cloud_pct`, `source`) of all scenes processed (regardless of
#'       cache state).}
#'     \item{n_scenes}{Integer. Total scenes returned by STAC.}
#'     \item{n_bands_fetched}{Integer. Bands actually downloaded over
#'       the network.}
#'     \item{n_bands_cached}{Integer. Bands served from disk.}
#'     \item{n_scenes_skipped}{Integer. Scenes that failed entirely.}
#'   }
#'   When STAC returns nothing, `scenes_df` is a 0-row data.frame with
#'   the same columns.
#'
#' @seealso [ingest_sentinel2_timeseries()] for the FAST pipeline that
#'   builds NDVI / NBR indices and writes them to `obs_pixel`.
#' @seealso [FORDEAD_BANDS] for the canonical list of FORDEAD bands.
#'
#' @examples
#' \dontrun{
#' res <- ingest_s2_raw_bands_to_cache(
#'   con       = con,
#'   zone_id   = 1L,
#'   bands     = FORDEAD_BANDS,
#'   start     = "2016-01-01",
#'   end       = as.character(Sys.Date()),
#'   cache_dir = file.path(project_dir, "cache/layers/sentinel2")
#' )
#' nrow(res$scenes_df)   # number of scenes available
#' }
#'
#' @export
ingest_s2_raw_bands_to_cache <- function(con, zone_id, bands,
                                         start, end, cache_dir,
                                         max_cloud = 20,
                                         progress_callback = NULL) {
  .assert_db_pkgs()
  if (!requireNamespace("terra", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg terra} required.")
  }

  if (!is.character(bands) || !length(bands)) {
    cli::cli_abort("{.arg bands} must be a non-empty character vector.")
  }
  bad <- bands[!grepl("^B[0-9]{1,2}A?$", bands)]
  if (length(bad)) {
    cli::cli_abort(c(
      "{.arg bands} contains values that are not raw Sentinel-2 codes.",
      x = "Offending: {.val {bad}}",
      i = "Expected pattern {.code ^B[0-9]+A?$} (e.g. B02, B04, B8A, B12).",
      i = "For NDVI / NBR indices, use {.fn ingest_sentinel2_timeseries} instead."
    ))
  }
  if (missing(cache_dir) || !is.character(cache_dir) ||
      length(cache_dir) != 1L || !nzchar(cache_dir)) {
    cli::cli_abort("{.arg cache_dir} is required and must be a single non-empty path.")
  }
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
    cli::cli_alert_info("S2 cache directory created at {.path {cache_dir}}.")
  }

  emit <- function(payload) {
    if (!is.null(progress_callback)) {
      tryCatch(progress_callback(payload), error = function(e) invisible(NULL))
    }
  }

  plots <- .fetch_plots_sf(con, zone_id)
  if (!nrow(plots)) {
    cli::cli_warn("No plots registered for zone_id {.val {zone_id}}.")
    return(.empty_raw_ingest_summary())
  }

  emit(list(current = "s2:search",
            start   = as.character(start),
            end     = as.character(end),
            n_plots = nrow(plots),
            bands   = bands))

  bbox <- sf::st_as_sfc(sf::st_bbox(plots))
  scenes <- stac_search_s2(bbox, start, end, max_cloud = max_cloud)
  if (!nrow(scenes)) {
    cli::cli_alert_info("No Sentinel-2 scene found between {start} and {end}.")
    emit(list(current = "s2:search_done", total = 0L, bands = bands))
    return(.empty_raw_ingest_summary())
  }

  total_scenes <- nrow(scenes)
  emit(list(current = "s2:search_done",
            total   = total_scenes,
            bands   = bands))

  # v0.24.2 — parity with FAST: pre-loop cache lookup. For each scene,
  # check whether every requested band already has a COG on disk. The
  # app uses this counter to drive the "X/Y scenes ready, Z to fetch"
  # toast before the per-scene loop starts emitting.
  scene_fully_cached <- vapply(seq_len(total_scenes), function(i) {
    sc <- scenes[i, , drop = FALSE]
    all(vapply(bands, function(b) {
      p <- .s2_band_cache_path(cache_dir, sc$scene_id, b)
      !is.null(p) && file.exists(p)
    }, logical(1)))
  }, logical(1))
  n_cached_scenes <- sum(scene_fully_cached)
  emit(list(current      = "s2:cache_lookup",
            n_cached     = as.integer(n_cached_scenes),
            n_to_process = as.integer(total_scenes - n_cached_scenes)))

  plots_proj <- sf::st_transform(plots, 2154)
  buf <- sf::st_buffer(plots_proj, dist = plots_proj$radius_m)

  n_bands_fetched <- 0L
  n_bands_cached  <- 0L
  n_skipped       <- 0L
  total_cached    <- 0L

  for (i in seq_len(total_scenes)) {
    sc <- scenes[i, , drop = FALSE]

    # Fully-cached scene → emit scene_cached, skip the band loop. Same
    # event payload as FAST (`s2:scene_cached`) so the app's existing
    # toast dispatch handles it identically.
    if (scene_fully_cached[[i]]) {
      total_cached <- total_cached + 1L
      n_bands_cached <- n_bands_cached + length(bands)
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

    band_emit <- function(payload) {
      if (!is.null(payload$current)) {
        if (identical(payload$current, "s2:band_cached"))  n_bands_cached  <<- n_bands_cached  + 1L
        if (identical(payload$current, "s2:band_fetched")) n_bands_fetched <<- n_bands_fetched + 1L
      }
      emit(payload)
    }

    scene_failed <- FALSE
    for (b in bands) {
      ok <- tryCatch({
        .get_s2_band_raster(sc, b, buf, cache_dir, band_emit)
        TRUE
      }, error = function(e) {
        cli::cli_warn("Scene {.val {sc$scene_id}} band {.val {b}} skipped: {conditionMessage(e)}")
        emit(list(current       = "s2:scene_skipped",
                  completed     = as.integer(i - 1L),
                  total         = as.integer(total_scenes),
                  scene_id      = sc$scene_id,
                  obs_date      = sc$obs_date,
                  band          = b,
                  error_message = conditionMessage(e)))
        FALSE
      })
      if (!isTRUE(ok)) {
        scene_failed <- TRUE
        break
      }
    }
    if (scene_failed) n_skipped <- n_skipped + 1L
  }

  emit(list(current         = "s2:complete",
            completed       = as.integer(total_scenes),
            total           = as.integer(total_scenes),
            n_scenes_cached = as.integer(total_cached),
            n_bands_fetched = as.integer(n_bands_fetched),
            n_bands_cached  = as.integer(n_bands_cached)))

  list(
    scenes_df       = scenes[, intersect(c("scene_id", "obs_date",
                                           "cloud_pct", "source"),
                                         names(scenes)),
                             drop = FALSE],
    n_scenes        = as.integer(total_scenes),
    n_bands_fetched = as.integer(n_bands_fetched),
    n_bands_cached  = as.integer(n_bands_cached),
    n_scenes_skipped = as.integer(n_skipped)
  )
}


.empty_raw_ingest_summary <- function() {
  list(
    scenes_df       = data.frame(scene_id  = character(0),
                                 obs_date  = as.Date(character(0)),
                                 cloud_pct = numeric(0),
                                 source    = character(0),
                                 stringsAsFactors = FALSE),
    n_scenes        = 0L,
    n_bands_fetched = 0L,
    n_bands_cached  = 0L,
    n_scenes_skipped = 0L
  )
}
