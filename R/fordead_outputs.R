#' FORDEAD 2.x output locators & status derivation (spec 008 §12)
#'
#' @description
#' Helpers that bridge the fordead 2.x on-disk layout
#' (`<out_dir>/<LAYER>/fordead_<YYYYMMDD>_<LAYER>.tif`) with the
#' existing postprocess pipeline ([.postprocess_fordead_rasters()]),
#' which expects a `list(state, stress_index, first_dieback_date)` of
#' raster paths or `SpatRaster` objects.
#'
#' Three helpers :
#'
#' * [.list_layer_files()] / [.latest_layer_file()] — locate the
#'   per-date GeoTIFFs FORDEAD writes for a given layer name.
#' * [.compute_first_dieback_date()] — stack `ANOMALY_CONFIRMED` and
#'   call `fordead.utils.backward_start()` to derive the first
#'   confirmed-anomaly date per pixel. Returns a `SpatRaster` (in
#'   memory).
#' * [.fordead_2x_status_to_classes()] — combine `ANOMALY_CONFIRMED`,
#'   `CONSECUTIVE_DETECTIONS` and `STOP_CONFIRMED` into a single 0-4
#'   `SpatRaster` consumable by the existing
#'   [.classify_pixels_to_classes()] (which is reused intact). The
#'   thresholds come from spec 008 §12.4 mapping table.
#'
#' @name fordead_outputs
#' @keywords internal
NULL


#' All fordead-written `.tif` files for a layer, sorted by embedded date
#'
#' fordead 2.x writes per-date layers under
#' `<out_dir>/<LAYER>/fordead_<YYYYMMDD>_<LAYER>.tif`. This helper
#' lists them ordered by `YYYYMMDD` ascending.
#'
#' @param output_dir Character(1). Root output directory of a
#'   `FordeadProcess` run.
#' @param layer Character(1). Layer name (e.g. `"ANOMALY_CONFIRMED"`,
#'   `"ANOMALY_INDEX"`, `"CONSECUTIVE_DETECTIONS"`).
#' @return Character vector of absolute paths, possibly empty. Always
#'   sorted by ascending date.
#' @keywords internal
.list_layer_files <- function(output_dir, layer) {
  if (!is.character(output_dir) || length(output_dir) != 1L ||
      !nzchar(output_dir)) {
    cli::cli_abort("{.arg output_dir} must be a non-empty string.")
  }
  if (!is.character(layer) || length(layer) != 1L || !nzchar(layer)) {
    cli::cli_abort("{.arg layer} must be a non-empty string.")
  }
  d <- file.path(output_dir, layer)
  if (!dir.exists(d)) return(character(0))
  # fordead_YYYYMMDD_<LAYER>.tif — extract the date for sorting.
  pat <- sprintf("^fordead_[0-9]{8}_%s\\.tif$", layer)
  files <- list.files(d, pattern = pat, full.names = TRUE)
  if (!length(files)) return(character(0))
  dates <- regmatches(basename(files),
                      regexpr("[0-9]{8}", basename(files)))
  files[order(dates)]
}


#' Path to the most recent fordead-written file for a layer
#'
#' @inheritParams .list_layer_files
#' @return Character(1) absolute path, or `NA_character_` when the
#'   layer directory is missing or empty.
#' @keywords internal
.latest_layer_file <- function(output_dir, layer) {
  files <- .list_layer_files(output_dir, layer)
  if (!length(files)) return(NA_character_)
  files[length(files)]
}


#' Derive first-dieback-date raster from the ANOMALY_CONFIRMED stack
#'
#' Stacks every `<output_dir>/ANOMALY_CONFIRMED/fordead_<YYYYMMDD>_ANOMALY_CONFIRMED.tif`
#' chronologically and calls `fordead.utils.backward_start(arr)` to
#' compute, per pixel, the **first date** at which the anomaly status
#' became `1`. Returns the result as a `SpatRaster` whose values are
#' days since `1970-01-01` (FORDEAD convention, compatible with the
#' 1.x layout expected by [.cluster_to_centroids()]).
#'
#' @param output_dir Character(1). Root FordeadProcess output dir.
#' @param fd_utils Python `fordead.utils` module (as imported via
#'   `reticulate::import("fordead.utils", convert = FALSE)`). Passing
#'   it in (rather than re-importing) lets callers share one Python
#'   binding and keeps this helper testable.
#' @return A `terra::SpatRaster` in memory, or `NULL` when no
#'   `ANOMALY_CONFIRMED` layer is found on disk (degraded case —
#'   the pipeline reports it but doesn't abort).
#' @keywords internal
.compute_first_dieback_date <- function(output_dir, fd_utils) {
  if (!requireNamespace("terra", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg terra} is required.")
  }
  files <- .list_layer_files(output_dir, "ANOMALY_CONFIRMED")
  if (!length(files)) {
    cli::cli_warn(
      "No {.val ANOMALY_CONFIRMED} layer found in {.path {output_dir}} ",
      "for first-dieback-date computation."
    )
    return(NULL)
  }
  if (is.null(fd_utils)) {
    cli::cli_abort("{.arg fd_utils} must be the imported fordead.utils module.")
  }

  # Stack chronologically. terra::time() gets the date per-layer from
  # the filename pattern so `backward_start` can convert "first 1" into
  # a calendar date downstream.
  rast_stack <- terra::rast(files)
  dates <- as.Date(
    regmatches(basename(files), regexpr("[0-9]{8}", basename(files))),
    format = "%Y%m%d"
  )
  terra::time(rast_stack) <- dates

  # Hand the stack to fordead.utils.backward_start. The Python side
  # operates on an xarray DataArray, so we materialise as a numpy
  # array via reticulate::r_to_py + np_array conversion. terra's
  # values matrix is layers-as-rows; we reshape to (time, y, x).
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg reticulate} is required.")
  }
  np <- reticulate::import("numpy", convert = FALSE)
  xr <- reticulate::import("xarray", convert = FALSE)

  n_layers <- terra::nlyr(rast_stack)
  n_rows   <- terra::nrow(rast_stack)
  n_cols   <- terra::ncol(rast_stack)
  # terra's cell order is ROW-major (cell = (row-1)*ncol + col), but
  # R's array() fills COLUMN-major. Feeding a values matrix straight into
  # array(dim = c(n_rows, n_cols, n_layers)) therefore transposes the
  # y/x axes whenever n_rows != n_cols — the first-dieback dates would
  # land on the wrong pixels. Reshape each layer with byrow = TRUE so
  # the axes are an honest (time, y, x).
  #
  # The numpy buffer is filled layer by layer. Going through a full
  # `terra::values()` matrix and an intermediate R array kept THREE copies of
  # the same data alive at once (values + array + numpy heap) — ~1.4 GB of peak
  # for a 1 Mpx AOI over 60 dates, all of it counted in the RSS systemd-oomd
  # watches. Only one layer is now in R at any time.
  np_arr <- np$empty(
    reticulate::tuple(as.integer(n_layers), as.integer(n_rows), as.integer(n_cols)),
    dtype = "float64")
  for (l in seq_len(n_layers)) {
    layer <- matrix(terra::values(rast_stack[[l]])[, 1L],
                    nrow = n_rows, ncol = n_cols, byrow = TRUE)
    np_arr$`__setitem__`(as.integer(l - 1L), reticulate::r_to_py(layer))
    rm(layer)
  }

  da <- xr$DataArray(
    np_arr,
    dims   = c("time", "y", "x"),
    coords = reticulate::dict(
      time = reticulate::r_to_py(as.character(dates))
    )
  )
  fdd <- fd_utils$backward_start(da)
  # `backward_start` returns an xarray DataArray of shape (y, x).
  # When the `time` coordinate is passed as date strings (as we do
  # above), its values come back as an **object-dtype** numpy array:
  # an ISO date string on every confirmed pixel and a float `NaN`
  # everywhere else. `py_to_r()` turns that into an R *list-matrix*,
  # which `terra::rast()` cannot ingest. Coerce explicitly to a
  # numeric matrix of days since 1970-01-01 — the unit
  # [.cluster_to_centroids()] expects. A plain numeric array (other
  # fordead versions / datetime-typed coords) is passed through.
  fdd_np <- fdd$to_numpy()
  fdd_r  <- reticulate::py_to_r(fdd_np)
  dims   <- dim(fdd_r)
  if (is.null(dims) || length(dims) != 2L) {
    cli::cli_abort("Unexpected {.fn backward_start} output shape.")
  }
  if (is.numeric(fdd_r)) {
    fdd_mat <- matrix(as.numeric(fdd_r), nrow = dims[1L], ncol = dims[2L])
  } else {
    # object-dtype: ISO date strings on confirmed pixels, NaN elsewhere.
    chr <- vapply(as.vector(fdd_r),
                  function(x) if (is.character(x) && length(x) == 1L)
                                x else NA_character_,
                  character(1))
    fdd_mat <- matrix(as.numeric(as.Date(chr)),
                      nrow = dims[1L], ncol = dims[2L])
  }

  out <- terra::rast(fdd_mat,
                     extent = terra::ext(rast_stack),
                     crs    = terra::crs(rast_stack))
  names(out) <- "first_dieback_date"
  out
}


#' Derive the 0-4 confidence-class raster from fordead 2.x layers
#'
#' fordead 2.x emits `ANOMALY_CONFIRMED` (boolean, 0/1) plus a count
#' raster `CONSECUTIVE_DETECTIONS` (integer, length of the current
#' streak of flagged anomalies) and a `STOP_CONFIRMED` flag (boolean,
#' set when the stress index has crossed the soil-nu threshold).
#'
#' The 0-4 schema expected by [.classify_pixels_to_classes()] is then
#' assembled per pixel as :
#'
#' * `STOP_CONFIRMED == 1`  → `4` (sol-nu)
#' * `CONSECUTIVE_DETECTIONS >= 10`  → `3` (forte)
#' * `CONSECUTIVE_DETECTIONS >= 6`   → `2` (moyenne)
#' * `CONSECUTIVE_DETECTIONS >= 3`   → `1` (faible)
#' * else                            → `0` (sain)
#'
#' Pixels where `ANOMALY_CONFIRMED == 0` are forced to `0` regardless
#' of the count (defensive — the count can persist after a transient
#' recovery in `definitive_anomaly = False` mode).
#'
#' Thresholds match spec 008 §12.4. To be **calibrated empirically**
#' in v0.23.0 release prep (AC.12.3) against a real FORDEAD run; until
#' then we keep them as documented defaults.
#'
#' @param output_dir Character(1). Root FordeadProcess output dir.
#' @return A `terra::SpatRaster` of integer codes `0..4`, or `NULL`
#'   when the mandatory `ANOMALY_CONFIRMED` layer is missing.
#' @keywords internal
.fordead_2x_status_to_classes <- function(output_dir) {
  if (!requireNamespace("terra", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg terra} is required.")
  }
  ac_file <- .latest_layer_file(output_dir, "ANOMALY_CONFIRMED")
  if (is.na(ac_file)) {
    cli::cli_warn(
      "No {.val ANOMALY_CONFIRMED} layer in {.path {output_dir}} -- ",
      "cannot derive confidence classes."
    )
    return(NULL)
  }
  cd_file <- .latest_layer_file(output_dir, "CONSECUTIVE_DETECTIONS")
  sc_file <- .latest_layer_file(output_dir, "STOP_CONFIRMED")

  ac <- terra::rast(ac_file)

  # Optional layers: when absent, we treat the corresponding component
  # of the rule as zero (safest — caps the class at 1-faible).
  cd <- if (is.na(cd_file)) terra::setValues(ac, 0L) else terra::rast(cd_file)
  sc <- if (is.na(sc_file)) terra::setValues(ac, 0L) else terra::rast(sc_file)

  # Some fordead encodings use 255 as FillValue for uint8 layers.
  # Treat as NA before arithmetic.
  to_na_255 <- function(x) terra::ifel(x == 255L, NA, x)
  ac <- to_na_255(ac)
  cd <- to_na_255(cd)
  sc <- to_na_255(sc)

  # Pixel mask: keep only confirmed anomalies.
  confirmed <- !is.na(terra::values(ac)) & terra::values(ac) == 1L

  cd_vals <- terra::values(cd)
  sc_vals <- terra::values(sc)

  out_vals <- rep(0L, length(cd_vals))
  out_vals[confirmed & !is.na(cd_vals) & cd_vals >= 3L]  <- 1L
  out_vals[confirmed & !is.na(cd_vals) & cd_vals >= 6L]  <- 2L
  out_vals[confirmed & !is.na(cd_vals) & cd_vals >= 10L] <- 3L
  out_vals[confirmed & !is.na(sc_vals) & sc_vals == 1L]  <- 4L

  # Where ANOMALY_CONFIRMED itself was NA (no-data), propagate NA.
  out_vals[is.na(terra::values(ac))] <- NA_integer_

  out <- terra::setValues(ac, out_vals)
  names(out) <- "fordead_class"
  out
}


#' Assemble the masked observed-CRSWIR stack (spec 008 §14.3)
#'
#' Stacks every per-date `CRSWIR` raster fordead 2.x wrote into one
#' multiband `SpatRaster`, masks each band with the matching
#' `INVALID_PIXEL_MASK` (cloud / shadow / soil — values `> 0` become
#' `NA`), and tags `terra::time()` with the observation dates. This is
#' the CRSWIR series exactly as FORDEAD modelled it, ready to be
#' persisted as `crswir_stack.tif` in the diagnostic bundle.
#'
#' Dates with no `INVALID_PIXEL_MASK` counterpart are persisted
#' unmasked (best-effort — the raw CRSWIR is still informative) with a
#' warning.
#'
#' @param output_dir Character(1). Root FordeadProcess output dir.
#' @return A `terra::SpatRaster`, one band per observation date with
#'   `terra::time()` set, or `NULL` when no `CRSWIR` layer exists.
#' @keywords internal
.build_crswir_masked_stack <- function(output_dir) {
  if (!requireNamespace("terra", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg terra} is required.")
  }
  cr_files <- .list_layer_files(output_dir, "CRSWIR")
  if (!length(cr_files)) {
    cli::cli_warn("No {.val CRSWIR} layer in {.path {output_dir}}.")
    return(NULL)
  }
  layer_date <- function(f) {
    as.Date(regmatches(basename(f), regexpr("[0-9]{8}", basename(f))),
            format = "%Y%m%d")
  }
  cr_dates <- layer_date(cr_files)
  crswir   <- terra::rast(cr_files)

  # Pair each CRSWIR date with its INVALID_PIXEL_MASK counterpart and
  # blank out invalid pixels (cloud / shadow / soil).
  mk_files <- .list_layer_files(output_dir, "INVALID_PIXEL_MASK")
  if (length(mk_files)) {
    idx <- match(cr_dates, layer_date(mk_files))
    if (!anyNA(idx)) {
      crswir <- terra::ifel(terra::rast(mk_files[idx]) > 0, NA, crswir)
    } else {
      cli::cli_warn(
        "{sum(is.na(idx))} CRSWIR date{?s} have no INVALID_PIXEL_MASK; \\
         those bands are persisted unmasked."
      )
      ok <- which(!is.na(idx))
      if (length(ok)) {
        crswir[[ok]] <- terra::ifel(
          terra::rast(mk_files[idx[ok]]) > 0, NA, crswir[[ok]]
        )
      }
    }
  }
  terra::time(crswir) <- cr_dates
  names(crswir)       <- format(cr_dates, "%Y-%m-%d")
  crswir
}


#' Persist the FORDEAD diagnostic bundle (spec 008 §14.3, L1)
#'
#' Writes the curated model bundle a later `read_fordead_pixel_series()`
#' (L2, spec 008 §14.4) will consume: the 5-band harmonic coefficient
#' raster, the masked observed-CRSWIR stack, the first-anomaly date
#' raster and a `run_meta.json`. Best-effort by contract — the caller
#' wraps this in a `tryCatch` so a write failure warns but never
#' aborts the FORDEAD run.
#'
#' @param output_dir Character(1). Root FordeadProcess output dir — the
#'   working set, source of `fit/model.tif` and the `CRSWIR` layers.
#' @param model_dir Character(1). Destination bundle directory,
#'   conventionally `<mask_cache_dir>/zone_<id>/model_<run_id>/`.
#'   Created (with parents) if absent.
#' @param first_anomaly A `terra::SpatRaster` of first-anomaly dates
#'   (days since epoch), typically the raster returned by
#'   [.compute_first_dieback_date()]. May be `NULL` (then
#'   `first_anomaly.tif` is skipped).
#' @param run_meta A named list serialised verbatim to `run_meta.json`.
#' @param verbose Logical. Emit a `cli` line when the bundle is written.
#' @return `model_dir` (invisibly) on success; throws on failure.
#' @keywords internal
.write_fordead_model_bundle <- function(output_dir, model_dir,
                                        first_anomaly = NULL,
                                        run_meta = list(),
                                        verbose = TRUE) {
  if (!requireNamespace("terra", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg terra} is required.")
  }
  dir.create(model_dir, recursive = TRUE, showWarnings = FALSE)

  # 1. coeff_model.tif — the 5-band harmonic coefficient raster.
  #    Re-read + re-write rather than file.copy() so the band names
  #    and compression are normalised.
  model_src <- file.path(output_dir, "fit", "model.tif")
  if (!file.exists(model_src)) {
    cli::cli_abort("Missing {.path fit/model.tif} in {.path {output_dir}}.")
  }
  terra::writeRaster(terra::rast(model_src),
                     file.path(model_dir, "coeff_model.tif"),
                     overwrite = TRUE)

  # 2. crswir_stack.tif — masked observed CRSWIR, one band per date.
  crswir <- .build_crswir_masked_stack(output_dir)
  if (is.null(crswir)) {
    cli::cli_abort("Cannot assemble the CRSWIR stack.")
  }
  terra::writeRaster(crswir, file.path(model_dir, "crswir_stack.tif"),
                     overwrite = TRUE)

  # 3. first_anomaly.tif — first confirmed-anomaly date (days since
  #    epoch). Best-effort: skipped when the raster is unavailable.
  if (!is.null(first_anomaly) && inherits(first_anomaly, "SpatRaster")) {
    terra::writeRaster(first_anomaly,
                       file.path(model_dir, "first_anomaly.tif"),
                       overwrite = TRUE)
  }

  # 3b. anomaly_index.tif — latest ANOMALY_INDEX (continuous current
  #     severity). Best-effort. Feeds the "indice d'anomalie" map layer
  #     (read_fordead_layer).
  ai_src <- .latest_layer_file(output_dir, "ANOMALY_INDEX")
  if (!is.na(ai_src)) {
    tryCatch(
      terra::writeRaster(terra::rast(ai_src),
                         file.path(model_dir, "anomaly_index.tif"),
                         overwrite = TRUE),
      error = function(e)
        cli::cli_warn("anomaly_index persist failed: {conditionMessage(e)}"))
  }

  # 3c. modelled_pixels.tif — confidence mask (pixels the harmonic model
  #     could be fitted on). Best-effort. Feeds the "confiance" map layer.
  mp_src <- file.path(output_dir, "fit", "modelled_pixels.tif")
  if (file.exists(mp_src)) {
    tryCatch(
      terra::writeRaster(terra::rast(mp_src),
                         file.path(model_dir, "modelled_pixels.tif"),
                         overwrite = TRUE),
      error = function(e)
        cli::cli_warn("modelled_pixels persist failed: {conditionMessage(e)}"))
  }

  # 4. run_meta.json — calibration + provenance of this run.
  jsonlite::write_json(run_meta,
                       file.path(model_dir, "run_meta.json"),
                       auto_unbox = TRUE, pretty = TRUE, null = "null")

  if (verbose) {
    cli::cli_alert_info("FORDEAD model bundle written: {.path {model_dir}}")
  }
  invisible(model_dir)
}
