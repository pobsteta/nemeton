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
.validate_fordead_args <- function(aoi,
                                   dates_training,
                                   dates_monitoring,
                                   vegetation_index,
                                   threshold_anomaly,
                                   forest_mask,
                                   output_dir) {
  if (!inherits(aoi, c("sf", "sfc"))) {
    cli::cli_abort("{.arg aoi} must be an sf or sfc object.")
  }
  if (!"POLYGON" %in% as.character(sf::st_geometry_type(aoi)) &&
      !"MULTIPOLYGON" %in% as.character(sf::st_geometry_type(aoi))) {
    cli::cli_abort("{.arg aoi} must contain (MULTI)POLYGON geometries.")
  }
  crs_aoi <- sf::st_crs(aoi)
  if (is.na(crs_aoi) || !identical(crs_aoi$epsg, 2154L)) {
    cli::cli_abort(c(
      "{.arg aoi} must be in EPSG:2154 (Lambert-93).",
      i = "Reproject with {.code sf::st_transform(aoi, 2154)}."
    ))
  }

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

  if (!is.null(forest_mask) &&
      !inherits(forest_mask, c("sf", "sfc")) &&
      !(is.character(forest_mask) && length(forest_mask) == 1L &&
        file.exists(forest_mask))) {
    cli::cli_abort(c(
      "{.arg forest_mask} must be {.cls NULL}, an sf object, or a path to an existing raster.",
      i = "When {.cls NULL}, the IGN BD Forêt v2 mask is used (cached locally)."
    ))
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


#' Resolve or download the BD Forêt v2 forest mask (cached)
#'
#' Stub for E6.c.1. Real implementation lands in E6.c.3 alongside
#' the validity-zone helpers. For now, returns `NULL` and emits a
#' CLI warning: the FORDEAD pipeline downstream will run with the
#' permissive default mask shipped by `fordead`.
#'
#' @param aoi An sf POLYGON in EPSG:2154.
#' @return A path to a GeoTIFF mask, or `NULL` when no cached mask
#'   is available.
#' @keywords internal
.download_or_use_cached_bd_foret <- function(aoi) {
  cli::cli_alert_warning(c(
    "BD Forêt v2 mask helper is a stub (lands in E6.c.3). ",
    "Falling back to FORDEAD's permissive forest mask."
  ))
  NULL
}


#' Build the structured return value for [run_fordead_dieback()]
#' @keywords internal
.empty_fordead_result <- function(output_dir, python_env, status = "success",
                                  duration_sec = NA_real_,
                                  fordead_version = NA_character_,
                                  message = NA_character_) {
  list(
    status            = status,
    message           = message,
    output_dir        = output_dir,
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


#' Run the FORDEAD dieback detection pipeline on an AOI
#'
#' Orchestrates fordead 2.x via \pkg{reticulate} on a STAC
#' `ItemCollection` built locally from the nemeton Sentinel-2 COG
#' cache. The pipeline runs in four phases :
#'
#' \enumerate{
#'   \item **STAC assembly** ([.build_stac_collection_for_aoi()]) —
#'     walk `cache_dir`, build a `pystac.Item` per scene with band
#'     assets pointing at local COGs. Hrefs are local paths, so PC
#'     SAS expiry during long runs (cf. v0.22.1) is a non-issue.
#'   \item **fit** — `FordeadProcess.fit()` trains the per-pixel
#'     harmonic model on the training window.
#'   \item **predict** — `FordeadProcess.predict()` produces
#'     `ANOMALY_CONFIRMED` / `ANOMALY_INDEX` / `CONSECUTIVE_DETECTIONS`
#'     /`STOP_CONFIRMED` rasters under `<output_dir>/<LAYER>/`.
#'   \item **postprocess** ([.postprocess_fordead_rasters()] reused) —
#'     derive a 0-4 confidence-class raster from the 2.x layers, run
#'     `terra::patches()` 8-neighbour, build cluster centroids with
#'     `confidence_class`, `stress_index`, `trigger_date`, `n_pixels`.
#' }
#'
#' When `con` and `zone_id` are both supplied, an additional **persist**
#' phase snaps centroids to the nearest registered plot of the zone
#' and inserts them via [.insert_fordead_alerts()] (idempotent
#' ON CONFLICT DO NOTHING).
#'
#' Calibration is frozen on the ONF/DSF reference values
#' (Bernard & Doridant 2024) and not exposed to the end user — see
#' the package vignette and ADR-013 for the rationale. The fordead 2.x
#' defaults match these values out of the box (cf. spec 008 §12.6).
#'
#' @param aoi An sf or sfc POLYGON in EPSG:2154.
#' @param scenes_df A `data.frame` (or tibble) with at minimum the
#'   columns `scene_id` (character) and `obs_date` (Date or
#'   coercible). Typically produced upstream by
#'   [ingest_sentinel2_timeseries()] (`scenes_df` output) or queried
#'   from the `obs_pixel` table. Duplicate `scene_id`s are silently
#'   dropped. Scenes whose `obs_date` falls outside
#'   `c(dates_training[1], dates_monitoring[2])` are ignored.
#' @param cache_dir Character(1). Root of the COG cache as written by
#'   [ingest_sentinel2_timeseries()] — typically
#'   `<project>/cache/layers/sentinel2`. Bands required by FORDEAD
#'   (B02, B04, B05, B8A, B11, B12) must already be present under
#'   `<cache_dir>/<safe_scene_id>/<band>.tif`. Scenes with missing
#'   bands are skipped with an aggregated warning.
#' @param dates_training Length-2 character vector defining the
#'   training window (default `c("2016-01-01", "2017-12-31")`).
#' @param dates_monitoring Length-2 character vector defining the
#'   monitoring window. The end may be `NA_character_` to mean
#'   "open / latest". Default `c("2018-01-01", as.character(Sys.Date()))`.
#' @param vegetation_index One of `"CRSWIR"`, `"NDVI"`, `"NDWI"`.
#'   Default `"CRSWIR"`.
#' @param threshold_anomaly Numeric in `[0.05, 0.50]`. Default
#'   `0.16` (calibrated).
#' @param forest_mask Deprecated since v0.23.0 — kept for argument
#'   compatibility but ignored. fordead 2.x's `FordeadProcess`
#'   handles cloud/shadow/soil masking via its own `FordeadConfig`
#'   defaults. The IGN BD Forêt v2 stub (which never fully landed in
#'   1.x) is no longer wired.
#' @param output_dir Character. Where FORDEAD writes its rasters.
#'   Defaults to a fresh `tempfile("fordead_")`.
#' @param python_env Character. Virtualenv name. Defaults to
#'   `Sys.getenv("NEMETON_FORDEAD_ENV", "nemeton-fordead")`.
#' @param con Optional `DBIConnection`. When supplied together with
#'   `zone_id`, FORDEAD centroids are persisted into the `alert`
#'   table (idempotent ON CONFLICT DO NOTHING).
#' @param zone_id Integer or `NULL`. Required to persist alerts.
#'   Centroids are snapped to the nearest registered plot of the
#'   zone (max 200 m).
#' @param min_pixels Integer. Minimum FORDEAD patch size (in
#'   pixels) to be considered an alert. Default 5.
#' @param connectivity Integer 4 or 8. Default 8.
#' @param verbose Logical. Print progress via `cli`. Default `TRUE`.
#' @param progress_callback Optional function called at each phase of
#'   the pipeline to allow callers (e.g. `nemetonshiny`) to report
#'   progress to the user. Receives a single named list argument with
#'   at least `current` (a short phase key) and, when meaningful,
#'   `completed` / `total` (number of phases done / scheduled) and
#'   `phase_name`. Phases emitted, in order:
#'   \describe{
#'     \item{`fordead:start`}{Once at the beginning — payload includes
#'       `total` (4 without `con`/`zone_id`, 5 when persistence is
#'       requested), `python_env`, `fordead_version`.}
#'     \item{`fordead:phase`}{Before each phase — payload includes
#'       `phase_name`, `completed = i - 1L`, `total`.}
#'     \item{`fordead:phase_done`}{After each successful phase —
#'       payload includes `phase_name`, `completed = i`, `total`.}
#'     \item{`fordead:complete`}{After the last phase — payload
#'       includes `completed = total`, `total`, `n_alerts_inserted`,
#'       `duration_sec`.}
#'     \item{`fordead:error`}{When the pipeline aborts in a phase —
#'       payload includes `phase_name`, `error_message`,
#'       `duration_sec`.}
#'   }
#'   The `phase_name` values are, in order: `"stac_assembly"`,
#'   `"fit"`, `"predict"`, `"postprocess"`, and (when applicable)
#'   `"persist"`. The callback is invoked synchronously inside the
#'   calling thread; exceptions raised inside it are swallowed so a
#'   buggy UI never aborts the pipeline. Default `NULL` (silent).
#'
#' @return A list with the following fields:
#'   \describe{
#'     \item{status}{`"success"` or `"error"`.}
#'     \item{message}{Optional human-readable message.}
#'     \item{output_dir}{Path where FORDEAD wrote its rasters.}
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
#' library(sf)
#' aoi <- st_read(system.file("extdata", "aoi_demo.gpkg",
#'                            package = "nemeton"))
#' res <- run_fordead_dieback(
#'   aoi              = aoi,
#'   dates_training   = c("2016-01-01", "2017-12-31"),
#'   dates_monitoring = c("2018-01-01", as.character(Sys.Date()))
#' )
#' res$status
#' res$rasters
#' }
#'
#' @export
run_fordead_dieback <- function(aoi,
                                scenes_df,
                                cache_dir,
                                dates_training   = c("2016-01-01", "2017-12-31"),
                                dates_monitoring = c("2018-01-01", as.character(Sys.Date())),
                                vegetation_index = "CRSWIR",
                                threshold_anomaly = 0.16,
                                forest_mask = NULL,
                                output_dir = tempfile("fordead_"),
                                python_env = NULL,
                                con = NULL,
                                zone_id = NULL,
                                min_pixels = 5L,
                                connectivity = 8L,
                                verbose = TRUE,
                                progress_callback = NULL) {
  t0 <- Sys.time()

  .validate_fordead_args(aoi, dates_training, dates_monitoring,
                         vegetation_index, threshold_anomaly,
                         forest_mask, output_dir)

  # New required v0.23.0 arguments — validate here rather than in
  # .validate_fordead_args() to keep that helper's signature stable
  # for downstream tests.
  if (missing(scenes_df) || !is.data.frame(scenes_df)) {
    cli::cli_abort(c(
      "{.arg scenes_df} is required and must be a data.frame.",
      i = "Provide the scenes_df returned by {.fun ingest_sentinel2_timeseries}."
    ))
  }
  if (missing(cache_dir) || !is.character(cache_dir) ||
      length(cache_dir) != 1L || !dir.exists(cache_dir)) {
    cli::cli_abort(c(
      "{.arg cache_dir} is required and must point to an existing directory.",
      i = "Typically {.path <project>/cache/layers/sentinel2}."
    ))
  }
  if (!is.null(forest_mask) && isTRUE(verbose)) {
    cli::cli_alert_warning(
      "{.arg forest_mask} is ignored since v0.23.0 (fordead 2.x handles masks)."
    )
  }

  env_name <- if (is.null(python_env)) .fordead_default_env() else python_env

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Phase plan — 4 phases (stac_assembly, fit, predict, postprocess)
  # plus an optional `persist` when caller passes both `con` and
  # `zone_id`. See spec 008 §12.5.
  will_persist <- !is.null(con) && !is.null(zone_id)
  phase_plan <- c("stac_assembly", "fit", "predict", "postprocess",
                  if (will_persist) "persist")
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

    # Filter scenes to the [training_start, monitoring_end] window
    # (the open-end case keeps everything after monitoring_start).
    .scene_dates  <- as.Date(scenes_df$obs_date)
    .train_start  <- as.Date(dates_training[1L])
    .mon_end      <- if (is.na(dates_monitoring[2L]))
                       max(.scene_dates, na.rm = TRUE) else
                       as.Date(dates_monitoring[2L])
    scenes_df <- scenes_df[!is.na(.scene_dates) &
                             .scene_dates >= .train_start &
                             .scene_dates <= .mon_end, , drop = FALSE]

    # 1. STAC assembly
    begin_phase("stac_assembly")
    collection <- .build_stac_collection_for_aoi(
      aoi            = aoi,
      scenes_df      = scenes_df,
      cache_dir      = cache_dir,
      bands_required = c("B02", "B04", "B05", "B8A", "B11", "B12")
    )
    bbox_4326 <- .aoi_bbox_4326(aoi)
    geom_py   <- .aoi_geometry_reticulate(aoi)
    cfg       <- .build_fordead_config(
      dates_training    = dates_training,
      dates_monitoring  = dates_monitoring,
      vegetation_index  = vegetation_index,
      threshold_anomaly = threshold_anomaly
    )
    end_phase("stac_assembly")

    # 2. fit
    begin_phase("fit")
    # fp lives only inside this tryCatch scope; reticulate handles
    # cleanup when R unbinds the reference.
    fp <- fd$workflow$FordeadProcess(
      collection = collection,
      output_dir = output_dir,
      bbox       = reticulate::r_to_py(as.list(bbox_4326)),
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
    if (will_persist) {
      begin_phase("persist")
      if (!is.null(alerts_sf)) {
        n_inserted <- .insert_fordead_alerts(con, alerts_sf,
                                             zone_id = zone_id)
      }
      end_phase("persist")
    }

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
                          message    = conditionMessage(e))
  })

  result
}
