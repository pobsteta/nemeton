#' Sentinel-2 bands required by FORDEAD 2.x
#'
#' Six raw bands consumed by FORDEAD's `FordeadProcess` class:
#'
#' - **B11, B8A, B12** — needed for the calibrated CRSWIR index
#'   `B11 / (B8A + (B12 - B8A) / (2185.7 - 864) * (1610.4 - 864))`.
#' - **B02, B04, B05** — used by the built-in cloud / shadow / soil
#'   masks (cf. fordead 2.x's `FordeadConfig` defaults).
#'
#' Differs from the FAST pipeline ([ingest_sentinel2_timeseries()]),
#' which only needs `c("B04", "B08", "B12")` for NDVI / NBR.
#'
#' Used as the canonical `bands` argument to
#' [ingest_s2_raw_bands_to_cache()] inside [run_fordead_dieback()]'s
#' phase-0 ingest. Exported so downstream callers (tests, custom
#' pipelines) reference one source of truth rather than hardcoding the
#' list.
#'
#' @format Character vector of length 6.
#' @export
#' @examples
#' FORDEAD_BANDS
FORDEAD_BANDS <- c("B02", "B04", "B05", "B8A", "B11", "B12")


#' Resolve the AOI sf POLYGON of a monitoring zone (EPSG:2154)
#'
#' Queries `monitoring_zone` for the zone's WKT + CRS, parses it via
#' `sf::st_as_sfc()`, and reprojects to Lambert-93 if needed.
#' Errors out with a typed message when the zone is unknown so the
#' caller (typically [run_fordead_dieback()]) surfaces an actionable
#' message rather than an empty sf.
#'
#' @keywords internal
.get_zone_aoi <- function(con, zone_id) {
  if (!inherits(con, "DBIConnection")) {
    cli::cli_abort("{.arg con} must be a {.cls DBIConnection}.")
  }
  if (length(zone_id) != 1L || is.na(zone_id)) {
    cli::cli_abort("{.arg zone_id} must be a scalar non-NA identifier.")
  }

  row <- DBI::dbGetQuery(con,
    "SELECT id, zone_wkt, crs_epsg FROM monitoring_zone WHERE id = $1",
    params = list(zone_id))

  if (!nrow(row)) {
    cli::cli_abort(c(
      "Unknown monitoring zone.",
      x = "zone_id = {.val {zone_id}}",
      i = "Check with {.fn register_monitoring_zone}."
    ))
  }

  srid <- as.integer(row$crs_epsg[[1L]])
  geom <- sf::st_as_sfc(row$zone_wkt[[1L]], crs = srid)
  aoi  <- sf::st_sf(geometry = geom, crs = srid)
  if (!identical(sf::st_crs(aoi)$epsg, 2154L)) {
    aoi <- sf::st_transform(aoi, 2154L)
  }
  aoi
}


#' FORDEAD Dieback Detection Pipeline (E6.c.1, spec 008)
#'
#' @description
#' R-side orchestrator that drives the five FORDEAD steps via
#' \pkg{reticulate}. The post-processing of output rasters into
#' POINT clusters and the persistence into the \code{alert} table
#' live in [`R/fordead_postprocess.R`] (chantier E6.c.2). When
#' invoked here without `con`, this function only produces the
#' rasters and returns their paths.
#'
#' Calibration is **frozen** on the values published by the
#' ONF/DSF FORDEAD validation report (Bernard & Doridant 2024,
#' cf. ADR-013 §G5):
#'
#' \itemize{
#'   \item `vegetation_index = "CRSWIR"`
#'   \item `threshold_anomaly = 0.16`
#'   \item Two years of training, three consecutive anomalies for
#'     a confirmed detection.
#' }
#'
#' These defaults are not exposed in the UI; advanced callers may
#' still override them programmatically.
#'
#' @name fordead_pipeline
NULL


# Recognised vegetation indices for the v0.21.0 release. CRSWIR is
# the calibrated default; NDVI and NDWI are tolerated for research
# but not part of the validated workflow.
.fordead_supported_vi <- c("CRSWIR", "NDVI", "NDWI")


#' Validate `run_fordead_dieback()` arguments
#'
#' Runs cheap, deterministic checks only — heavy validation (CRS
#' consistency, raster paths, etc.) is left to the FORDEAD steps
#' themselves so that we surface real Python errors instead of
#' double-checking.
#'
#' @keywords internal
.validate_fordead_args <- function(dates_training,
                                   dates_monitoring,
                                   vegetation_index,
                                   threshold_anomaly,
                                   output_dir) {
  .check_dates <- function(x, name) {
    if (length(x) != 2L) {
      cli::cli_abort("{.arg {name}} must be a length-2 vector.")
    }
    d <- tryCatch(as.Date(x), error = function(e) NA)
    if (any(is.na(d))) {
      cli::cli_abort("{.arg {name}} contains values that cannot be parsed as dates.")
    }
    if (d[2] < d[1]) {
      cli::cli_abort("{.arg {name}}[2] must be on or after {.arg {name}}[1].")
    }
    d
  }
  d_train <- .check_dates(dates_training,   "dates_training")
  d_mon   <- .check_dates(dates_monitoring, "dates_monitoring")
  if (d_mon[1] < d_train[1]) {
    cli::cli_abort("{.arg dates_monitoring}[1] must be on or after {.arg dates_training}[1].")
  }

  supported_vi <- .fordead_supported_vi
  if (!is.character(vegetation_index) || length(vegetation_index) != 1L ||
      !vegetation_index %in% supported_vi) {
    cli::cli_abort(c(
      "{.arg vegetation_index} must be one of {.val {supported_vi}}.",
      i = "Default {.val CRSWIR} is the calibrated value (Bernard & Doridant 2024)."
    ))
  }

  if (!is.numeric(threshold_anomaly) || length(threshold_anomaly) != 1L ||
      is.na(threshold_anomaly) ||
      threshold_anomaly < 0.05 || threshold_anomaly > 0.50) {
    cli::cli_abort("{.arg threshold_anomaly} must be a numeric scalar in [0.05, 0.50].")
  }

  if (!is.character(output_dir) || length(output_dir) != 1L ||
      !nzchar(output_dir)) {
    cli::cli_abort("{.arg output_dir} must be a non-empty string.")
  }
  invisible(list(
    dates_training_d   = d_train,
    dates_monitoring_d = d_mon
  ))
}


#' Build the structured return value for [run_fordead_dieback()]
#' @keywords internal
.empty_fordead_result <- function(output_dir, python_env, status = "success",
                                  duration_sec = NA_real_,
                                  fordead_version = NA_character_,
                                  message = NA_character_,
                                  zone_id = NA,
                                  n_scenes = 0L) {
  list(
    status            = status,
    message           = message,
    output_dir        = output_dir,
    zone_id           = zone_id,
    n_scenes          = as.integer(n_scenes),
    rasters           = list(state = NA_character_,
                             first_dieback_date = NA_character_,
                             stress_index = NA_character_),
    alerts_sf         = NULL,
    n_alerts_inserted = 0L,
    duration_sec      = duration_sec,
    python_env        = python_env,
    fordead_version   = fordead_version
  )
}


#' Run the FORDEAD dieback detection pipeline on a monitoring zone
#'
#' Orchestrates fordead 2.x via \pkg{reticulate}. The pipeline derives
#' its AOI from `monitoring_zone.zone_wkt`, ensures the Sentinel-2 COG
#' cache contains every required band ([FORDEAD_BANDS]), assembles a
#' STAC `ItemCollection` over local hrefs, and runs FORDEAD `fit()` +
#' `predict()` on top. Six phases :
#'
#' \enumerate{
#'   \item **ingest** ([ingest_s2_raw_bands_to_cache()]) — partial-
#'     coverage-aware download of missing raw bands into `cache_dir`.
#'     Re-uses bands already cached by [ingest_sentinel2_timeseries()]
#'     (FAST pipeline) so a zone with FAST already run skips the
#'     three shared bands (B04, B12) and only fetches the four FORDEAD-
#'     specific ones (B02, B05, B8A, B11). Propagates `s2:*` events
#'     verbatim to the user's `progress_callback`.
#'   \item **STAC assembly** ([.build_stac_collection_for_aoi()]) —
#'     walk `cache_dir`, build a `pystac.Item` per scene with band
#'     assets pointing at local COGs. Hrefs are local paths, so PC
#'     SAS expiry during long runs is a non-issue.
#'   \item **fit** — `FordeadProcess.fit()` trains the per-pixel
#'     harmonic model on the training window.
#'   \item **predict** — `FordeadProcess.predict()` produces
#'     `ANOMALY_CONFIRMED` / `ANOMALY_INDEX` / `CONSECUTIVE_DETECTIONS`
#'     /`STOP_CONFIRMED` rasters under `<output_dir>/<LAYER>/`.
#'   \item **postprocess** ([.postprocess_fordead_rasters()] reused) —
#'     derive a 0-4 confidence-class raster from the 2.x layers, run
#'     `terra::patches()` 8-neighbour, build cluster centroids with
#'     `confidence_class`, `stress_index`, `trigger_date`, `n_pixels`.
#'   \item **persist** — snap centroids to the nearest registered plot
#'     of the zone and insert them via [.insert_fordead_alerts()]
#'     (idempotent `ON CONFLICT DO NOTHING`).
#' }
#'
#' Calibration is frozen on the ONF/DSF reference values
#' (Bernard & Doridant 2024) and not exposed to the end user — see
#' ADR-013 for the rationale. The fordead 2.x defaults match these
#' values out of the box (cf. spec 008 §12.6).
#'
#' @section Breaking changes since v0.23.0:
#' The signature is now `(con, zone_id, cache_dir, ...)`. Arguments
#' `aoi`, `scenes_df` and `forest_mask` were removed (see
#' spec 008 §13.2). Migrate callers by switching from supplying an
#' explicit AOI + scenes_df to passing the `DBIConnection` + zone id
#' that the pipeline uses to derive both internally.
#'
#' @param con A `DBIConnection`. Used to resolve the AOI (from
#'   `monitoring_zone.zone_wkt`) and, in the `persist` phase, to
#'   insert FORDEAD centroids into the `alert` table.
#' @param zone_id Integer or character. Identifier of an existing row
#'   in `monitoring_zone`.
#' @param cache_dir Character(1). Root of the COG cache, typically
#'   `<project>/cache/layers/sentinel2`. Created if absent. Shared with
#'   [ingest_sentinel2_timeseries()] (FAST pipeline) so already-cached
#'   bands are reused on repeat runs.
#' @param dates_training Length-2 character vector defining the
#'   training window (default `c("2016-01-01", "2017-12-31")`).
#' @param dates_monitoring Length-2 character vector defining the
#'   monitoring window. The end may be `NA_character_` to mean
#'   "open / latest". Default `c("2018-01-01", as.character(Sys.Date()))`.
#' @param vegetation_index One of `"CRSWIR"`, `"NDVI"`, `"NDWI"`.
#'   Default `"CRSWIR"`.
#' @param threshold_anomaly Numeric in `[0.05, 0.50]`. Default
#'   `0.16` (calibrated).
#' @param max_cloud Numeric. Maximum scene cloud cover (%) passed to
#'   the phase-0 STAC search. Default 20.
#' @param output_dir Character. Where FORDEAD writes its rasters.
#'   Defaults to a fresh `tempfile("fordead_")`.
#' @param python_env Character. Virtualenv name. Defaults to
#'   `Sys.getenv("NEMETON_FORDEAD_ENV", "nemeton-fordead")`.
#' @param min_pixels Integer. Minimum FORDEAD patch size (in
#'   pixels) to be considered an alert. Default 5.
#' @param connectivity Integer 4 or 8. Default 8.
#' @param verbose Logical. Print progress via `cli`. Default `TRUE`.
#' @param progress_callback Optional function called at each phase of
#'   the pipeline. Receives a single named list with `current` (event
#'   key) and, when meaningful, `completed`, `total`, `phase_name`.
#'   Phases emitted, in order: `"ingest"`, `"stac_assembly"`, `"fit"`,
#'   `"predict"`, `"postprocess"`, `"persist"`. During `"ingest"` the
#'   `s2:*` events from [ingest_s2_raw_bands_to_cache()] also pass
#'   through verbatim (search / scene / band_cached / band_fetched /
#'   complete). Exceptions raised inside the callback are swallowed
#'   so a buggy UI never aborts the pipeline. Default `NULL` (silent).
#'
#' @return A list with the following fields:
#'   \describe{
#'     \item{status}{`"success"` or `"error"`.}
#'     \item{message}{Optional human-readable message.}
#'     \item{output_dir}{Path where FORDEAD wrote its rasters.}
#'     \item{zone_id}{The zone id that was processed.}
#'     \item{n_scenes}{Number of scenes considered.}
#'     \item{rasters}{Named list of GeoTIFF paths (`state`,
#'       `first_dieback_date`, `stress_index`).}
#'     \item{alerts_sf}{An sf POINT layer of FORDEAD cluster
#'       centroids (in EPSG:2154), or `NULL` when no anomaly was
#'       detected.}
#'     \item{n_alerts_inserted}{Integer.}
#'     \item{duration_sec}{Wall-clock duration in seconds.}
#'     \item{python_env}{The virtualenv that was used.}
#'     \item{fordead_version}{The Python `fordead` package version.}
#'   }
#'
#' @examples
#' \dontrun{
#' res <- run_fordead_dieback(
#'   con              = con,
#'   zone_id          = 1L,
#'   cache_dir        = file.path(project_dir, "cache/layers/sentinel2"),
#'   dates_training   = c("2016-01-01", "2017-12-31"),
#'   dates_monitoring = c("2018-01-01", as.character(Sys.Date()))
#' )
#' res$status
#' res$rasters
#' }
#'
#' @export
run_fordead_dieback <- function(con,
                                zone_id,
                                cache_dir,
                                dates_training   = c("2016-01-01", "2017-12-31"),
                                dates_monitoring = c("2018-01-01", as.character(Sys.Date())),
                                vegetation_index = "CRSWIR",
                                threshold_anomaly = 0.16,
                                max_cloud = 20,
                                output_dir = tempfile("fordead_"),
                                python_env = NULL,
                                min_pixels = 5L,
                                connectivity = 8L,
                                verbose = TRUE,
                                progress_callback = NULL) {
  t0 <- Sys.time()

  .validate_fordead_args(dates_training, dates_monitoring,
                         vegetation_index, threshold_anomaly,
                         output_dir)

  if (!inherits(con, "DBIConnection")) {
    cli::cli_abort("{.arg con} must be a {.cls DBIConnection}.")
  }
  if (length(zone_id) != 1L || is.na(zone_id)) {
    cli::cli_abort("{.arg zone_id} must be a scalar non-NA identifier.")
  }
  if (missing(cache_dir) || !is.character(cache_dir) ||
      length(cache_dir) != 1L || !nzchar(cache_dir)) {
    cli::cli_abort(c(
      "{.arg cache_dir} is required.",
      i = "Typically {.path <project>/cache/layers/sentinel2}."
    ))
  }
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }

  env_name <- if (is.null(python_env)) .fordead_default_env() else python_env

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Phase plan — 6 phases (ingest, stac_assembly, fit, predict,
  # postprocess, persist). v0.24.0: ingest added as phase 0, persist
  # always runs (con/zone_id are now required).
  phase_plan <- c("ingest", "stac_assembly", "fit", "predict",
                  "postprocess", "persist")
  will_persist <- TRUE
  total_phases <- length(phase_plan)
  current_phase_idx <- 0L
  current_phase_name <- NA_character_

  emit <- function(payload) {
    if (is.null(progress_callback)) return(invisible(NULL))
    tryCatch(progress_callback(payload),
             error = function(e) invisible(NULL))
  }
  begin_phase <- function(name) {
    current_phase_idx <<- current_phase_idx + 1L
    current_phase_name <<- name
    emit(list(current    = "fordead:phase",
              phase_name = name,
              completed  = as.integer(current_phase_idx - 1L),
              total      = as.integer(total_phases)))
  }
  end_phase <- function(name) {
    emit(list(current    = "fordead:phase_done",
              phase_name = name,
              completed  = as.integer(current_phase_idx),
              total      = as.integer(total_phases)))
  }

  result <- tryCatch({
    fd <- .ensure_fordead_python(env_name = env_name, verbose = verbose)

    fordead_version <- tryCatch({
      v <- reticulate::py_get_attr(fd, "version", silent = TRUE)
      if (is.null(v)) {
        v <- reticulate::py_get_attr(fd, "__version__", silent = TRUE)
      }
      reticulate::py_to_r(v)
    }, error = function(e) NA_character_)
    if (is.null(fordead_version) || !is.character(fordead_version)) {
      fordead_version <- NA_character_
    }

    if (verbose) {
      cli::cli_alert_info(
        "FORDEAD pipeline starting (env={.val {env_name}}, fordead={.val {fordead_version}})."
      )
    }

    emit(list(current         = "fordead:start",
              total           = as.integer(total_phases),
              python_env      = env_name,
              fordead_version = fordead_version))

    log_buf <- character(0)
    .capture <- function(label, expr) {
      if (verbose) cli::cli_alert_info("Step: {label}")
      out <- reticulate::py_capture_output(expr)
      if (nzchar(out)) {
        log_buf <<- c(log_buf, paste0("[", label, "] ", out))
      }
    }

    # 0. Ingest (NEW v0.24.0)
    # Resolve AOI from the zone and ensure the cache contains every
    # FORDEAD band for every scene in the [training, monitoring] window.
    # The downloader propagates s2:* events through the same callback
    # the user gave us — the app already renders those (FAST pipeline).
    aoi <- .get_zone_aoi(con, zone_id)

    begin_phase("ingest")
    .train_start  <- as.Date(dates_training[1L])
    .mon_end      <- if (is.na(dates_monitoring[2L]))
                       Sys.Date() else as.Date(dates_monitoring[2L])
    ingest_res <- ingest_s2_raw_bands_to_cache(
      con               = con,
      zone_id           = zone_id,
      bands             = FORDEAD_BANDS,
      start             = .train_start,
      end               = .mon_end,
      cache_dir         = cache_dir,
      max_cloud         = max_cloud,
      progress_callback = progress_callback
    )
    scenes_df <- ingest_res$scenes_df
    if (!nrow(scenes_df)) {
      window_str <- paste(as.character(.train_start),
                          "->", as.character(.mon_end))
      cli::cli_abort(c(
        "No Sentinel-2 scene available for zone {.val {zone_id}}.",
        i = "Window: {.val {window_str}}.",
        i = "Check the STAC backends and {.arg max_cloud}."
      ))
    }
    end_phase("ingest")

    # 1. STAC assembly
    begin_phase("stac_assembly")
    collection <- .build_stac_collection_for_aoi(
      aoi            = aoi,
      scenes_df      = scenes_df,
      cache_dir      = cache_dir,
      bands_required = FORDEAD_BANDS
    )
    geom_py <- .aoi_geometry_reticulate(aoi)  # GeoSeries(crs=4326) since v0.25.3
    cfg     <- .build_fordead_config(
      dates_training    = dates_training,
      dates_monitoring  = dates_monitoring,
      vegetation_index  = vegetation_index,
      threshold_anomaly = threshold_anomaly
    )
    end_phase("stac_assembly")

    # 2. fit
    begin_phase("fit")
    # v0.25.3 — pass `bbox = NULL` (Python None) so the FordeadProcess
    # geometry setter doesn't pre-clip via a wrong-CRS bbox when it
    # internally evaluates `self.crs = self.to_xarray().rio.crs`. The
    # setter detects to_crs/total_bounds on the GeoSeries we pass and
    # reprojects to the collection CRS (Sentinel-2 UTM EPSG:32631),
    # then overrides self.bbox from `geometry.total_bounds` in the
    # right CRS. Pre-v0.25.3 we passed bbox in degrees on a meter-CRS
    # collection → rioxarray.NoDataInBounds during fit().
    # fp lives only inside this tryCatch scope; reticulate handles
    # cleanup when R unbinds the reference.
    fp <- fd$workflow$FordeadProcess(
      collection = collection,
      output_dir = output_dir,
      bbox       = NULL,
      geometry   = geom_py,
      config     = cfg
    )
    .capture("fit", { fp$fit() })
    end_phase("fit")

    # 3. predict
    begin_phase("predict")
    .capture("predict", { fp$predict() })
    end_phase("predict")

    # Locate the most recent fordead-written layers and build the
    # `rasters` list the 1.x postprocess expects. The 0..4 class
    # raster is derived from ANOMALY_CONFIRMED + CONSECUTIVE_DETECTIONS
    # + STOP_CONFIRMED (see .fordead_2x_status_to_classes for the
    # mapping table — to be empirically recalibrated in AC.12.3).
    state_raster <- .fordead_2x_status_to_classes(output_dir)
    fdd_raster   <- tryCatch(
      .compute_first_dieback_date(output_dir, fd$utils),
      error = function(e) {
        cli::cli_alert_warning(
          "first_dieback_date derivation failed: {conditionMessage(e)}"
        )
        NULL
      }
    )
    rasters <- list(
      state              = .latest_layer_file(output_dir, "ANOMALY_CONFIRMED"),
      first_dieback_date = NA_character_,  # in-memory, not persisted
      stress_index       = .latest_layer_file(output_dir, "ANOMALY_INDEX")
    )

    # 4. postprocess (1.x helper reused — input shape unchanged)
    begin_phase("postprocess")
    alerts_sf <- tryCatch(
      .postprocess_fordead_rasters(
        rasters = list(
          state              = state_raster,
          first_dieback_date = fdd_raster,
          stress_index       = if (!is.na(rasters$stress_index))
                                 terra::rast(rasters$stress_index) else NULL
        ),
        min_pixels   = as.integer(min_pixels),
        connectivity = as.integer(connectivity)
      ),
      error = function(e) {
        cli::cli_alert_warning("Post-processing failed: {conditionMessage(e)}")
        NULL
      }
    )
    if (!is.null(alerts_sf) && !nrow(alerts_sf)) alerts_sf <- NULL
    end_phase("postprocess")

    n_inserted <- 0L
    begin_phase("persist")
    if (!is.null(alerts_sf)) {
      n_inserted <- .insert_fordead_alerts(con, alerts_sf,
                                           zone_id = zone_id)
    }
    end_phase("persist")

    duration_sec <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    emit(list(current           = "fordead:complete",
              completed         = as.integer(total_phases),
              total             = as.integer(total_phases),
              n_alerts_inserted = as.integer(n_inserted),
              duration_sec      = duration_sec))

    list(
      status            = "success",
      message           = NA_character_,
      output_dir        = output_dir,
      zone_id           = zone_id,
      n_scenes          = nrow(scenes_df),
      rasters           = rasters,
      alerts_sf         = alerts_sf,
      n_alerts_inserted = n_inserted,
      duration_sec      = duration_sec,
      python_env        = env_name,
      fordead_version   = fordead_version
    )
  }, error = function(e) {
    if (verbose) cli::cli_alert_danger("FORDEAD pipeline failed: {conditionMessage(e)}")
    duration_sec <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    emit(list(current       = "fordead:error",
              phase_name    = current_phase_name,
              error_message = conditionMessage(e),
              duration_sec  = duration_sec))
    .empty_fordead_result(output_dir = output_dir,
                          python_env = env_name,
                          status     = "error",
                          duration_sec = duration_sec,
                          message    = conditionMessage(e),
                          zone_id    = zone_id)
  })

  result
}
