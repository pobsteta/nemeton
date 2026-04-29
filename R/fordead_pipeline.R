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
#' Orchestrates the five FORDEAD steps via \pkg{reticulate}:
#'
#' \enumerate{
#'   \item Compute masked vegetation index (CRSWIR by default).
#'   \item Train the per-pixel harmonic model.
#'   \item Resolve / download the forest mask (BD Forêt v2 by
#'     default; helper is a stub until E6.c.3).
#'   \item Detect dieback anomalies.
#'   \item Export raster results to \code{output_dir}.
#' }
#'
#' Post-processing of the rasters into POINT clusters is performed
#' inline by [.postprocess_fordead_rasters()] (chantier E6.c.2). When
#' `con` and `zone_id` are both supplied, the centroids are persisted
#' into the `alert` table via [.insert_fordead_alerts()] (each
#' centroid is snapped to the nearest registered plot of the zone).
#'
#' Calibration is frozen on the ONF/DSF reference values
#' (Bernard & Doridant 2024) and not exposed to the end user — see
#' the package vignette and ADR-013 for the rationale.
#'
#' @param aoi An sf or sfc POLYGON in EPSG:2154.
#' @param dates_training Length-2 character/Date vector defining the
#'   training window (default `c("2016-01-01", "2017-12-31")`).
#' @param dates_monitoring Length-2 character/Date vector defining
#'   the monitoring window. Defaults to `c("2018-01-01", as.character(Sys.Date()))`.
#' @param vegetation_index One of `"CRSWIR"`, `"NDVI"`, `"NDWI"`.
#'   Default `"CRSWIR"`.
#' @param threshold_anomaly Numeric in `[0.05, 0.50]`. Default
#'   `0.16` (calibrated).
#' @param forest_mask `NULL`, an sf object, or a path to an existing
#'   raster. `NULL` triggers the BD Forêt v2 cached lookup.
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
                                verbose = TRUE) {
  t0 <- Sys.time()

  .validate_fordead_args(aoi, dates_training, dates_monitoring,
                         vegetation_index, threshold_anomaly,
                         forest_mask, output_dir)

  env_name <- if (is.null(python_env)) .fordead_default_env() else python_env

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  result <- tryCatch({
    fd <- .ensure_fordead_python(env_name = env_name, verbose = verbose)

    fordead_version <- tryCatch(
      reticulate::py_get_attr(fd, "__version__", silent = TRUE),
      error = function(e) NA_character_
    )
    fordead_version <- tryCatch(reticulate::py_to_r(fordead_version),
                                error = function(e) NA_character_)
    if (is.null(fordead_version) || !is.character(fordead_version)) {
      fordead_version <- NA_character_
    }

    if (verbose) {
      cli::cli_alert_info("FORDEAD pipeline starting (env={.val {env_name}}, fordead={.val {fordead_version}}).")
    }

    log_buf <- character(0)
    .capture <- function(label, expr) {
      if (verbose) cli::cli_alert_info("Step: {label}")
      out <- reticulate::py_capture_output(expr)
      if (nzchar(out)) {
        log_buf <<- c(log_buf, paste0("[", label, "] ", out))
      }
    }

    # 1. Masked vegetation index
    .capture("compute_masked_vegetationindex", {
      fd$steps$step1_compute_masked_vegetationindex$compute_masked_vegetationindex(
        input_directory  = output_dir,
        vegetation_index = vegetation_index
      )
    })

    # 2. Train model
    .capture("train_model", {
      fd$steps$step2_train_model$train_model(
        input_directory = output_dir,
        nb_min_date     = 10L
      )
    })

    # 3. Forest mask
    fmask <- forest_mask
    if (is.null(fmask)) {
      fmask <- .download_or_use_cached_bd_foret(aoi)
    }

    # 4. Dieback detection
    .capture("dieback_detection", {
      fd$steps$step3_dieback_detection$dieback_detection(
        input_directory   = output_dir,
        threshold_anomaly = threshold_anomaly
      )
    })

    # 5. Export results
    .capture("export_results", {
      fd$steps$step5_export_results$export_results(
        input_directory = output_dir
      )
    })

    rasters <- list(
      state              = file.path(output_dir, "DataAnomalies", "state.tif"),
      first_dieback_date = file.path(output_dir, "DataAnomalies", "first_dieback_date.tif"),
      stress_index       = file.path(output_dir, "DataAnomalies", "stress_index.tif")
    )

    # 6. Post-processing: rasters → POINT clusters → optional INSERT.
    alerts_sf <- tryCatch(
      .postprocess_fordead_rasters(rasters,
                                   min_pixels   = as.integer(min_pixels),
                                   connectivity = as.integer(connectivity)),
      error = function(e) {
        cli::cli_alert_warning("Post-processing failed: {conditionMessage(e)}")
        NULL
      }
    )
    if (!is.null(alerts_sf) && !nrow(alerts_sf)) alerts_sf <- NULL

    n_inserted <- 0L
    if (!is.null(con) && !is.null(zone_id) && !is.null(alerts_sf)) {
      n_inserted <- .insert_fordead_alerts(con, alerts_sf,
                                           zone_id = zone_id)
    }

    list(
      status            = "success",
      message           = NA_character_,
      output_dir        = output_dir,
      rasters           = rasters,
      alerts_sf         = alerts_sf,
      n_alerts_inserted = n_inserted,
      duration_sec      = as.numeric(difftime(Sys.time(), t0, units = "secs")),
      python_env        = env_name,
      fordead_version   = fordead_version
    )
  }, error = function(e) {
    if (verbose) cli::cli_alert_danger("FORDEAD pipeline failed: {conditionMessage(e)}")
    .empty_fordead_result(output_dir = output_dir,
                          python_env = env_name,
                          status     = "error",
                          duration_sec = as.numeric(difftime(Sys.time(), t0, units = "secs")),
                          message    = conditionMessage(e))
  })

  result
}
