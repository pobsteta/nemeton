#' FORDEAD pixel CRSWIR diagnostic (spec 008 section 14.4, L2)
#'
#' @description
#' Reader side of the FORDEAD diagnostic bundle persisted by
#' [run_fordead_dieback()] (L1, spec 008 section 14.3). Given a clicked
#' pixel it returns the observed CRSWIR series, the harmonic-model
#' prediction, the anomaly threshold band and the per-date anomaly
#' flag - the data behind the click-to-diagnose plot of the FORDEAD
#' map.
#'
#' @name fordead_pixel_series
NULL


#' Locate a FORDEAD diagnostic bundle directory
#'
#' Mirrors the path convention of [read_fordead_dieback_mask()]: model
#' bundles live under `<cache_dir>/zone_<zone_id>/model_<run_id>/`.
#' When `run_id` is `NULL` the most recent bundle (lexicographic order
#' on the `YYYYMMDDTHHMMSS` suffix, which is also chronological) wins.
#'
#' @param cache_dir Character(1). Root of the FORDEAD cache.
#' @param zone_id Integer. `monitoring_zone.id`.
#' @param run_id Optional character/integer. Explicit run selector.
#' @return Character(1) bundle directory, or `NULL` when none exists.
#' @keywords internal
.locate_fordead_model_bundle <- function(cache_dir, zone_id,
                                         run_id = NULL) {
  if (is.null(cache_dir) || !nzchar(cache_dir) || !dir.exists(cache_dir)) {
    return(NULL)
  }
  zone_dir <- file.path(cache_dir, sprintf("zone_%d", as.integer(zone_id)))
  if (!dir.exists(zone_dir)) return(NULL)

  if (!is.null(run_id)) {
    d <- file.path(zone_dir, sprintf("model_%s", as.character(run_id)))
    return(if (dir.exists(d)) d else NULL)
  }
  dirs <- list.dirs(zone_dir, recursive = FALSE, full.names = TRUE)
  dirs <- dirs[grepl("^model_", basename(dirs))]
  if (!length(dirs)) return(NULL)
  sort(dirs)[length(dirs)]
}


#' Observation dates of a persisted CRSWIR stack
#'
#' Reads the per-band dates of a `crswir_stack.tif` written by
#' [.write_fordead_model_bundle()]. `terra::time()` is the primary
#' source; the `YYYY-MM-DD` layer names are the fallback (both are
#' set at write time, but `time()` does not always survive a GeoTIFF
#' round-trip).
#'
#' @param r A `terra::SpatRaster` (the loaded CRSWIR stack).
#' @return A `Date` vector of length `terra::nlyr(r)`.
#' @keywords internal
.crswir_stack_dates <- function(r) {
  t <- terra::time(r)
  if (length(t) && !all(is.na(t))) return(as.Date(t))
  as.Date(names(r))
}


#' Reconstruct the FORDEAD harmonic prediction for a pixel
#'
#' Computes `crswir_pred` for every observation date from the five
#' per-pixel harmonic coefficients. Per ADR-013 amendment A3 decision
#' D3, the harmonic basis itself is **not** re-implemented in R: the
#' 5-term basis comes from `fordead.modeling.compute_HarmonicTerms`
#' via \pkg{reticulate}, guaranteeing parity with the run. Only
#' `dates_to_days` (a plain subtraction from `REF_DAY = 2015-01-01`)
#' is done R-side.
#'
#' Returns `NULL` (with a warning) when the FORDEAD virtualenv or the
#' `fordead` Python package is unavailable - the caller then degrades
#' gracefully (the residual risk accepted in ADR-013 A3).
#'
#' @param coeff Numeric(5). Per-pixel harmonic coefficients.
#' @param obs_date A `Date` vector. Observation dates to predict.
#' @param env_name Character. FORDEAD virtualenv name.
#' @return Numeric vector of predictions (length `length(obs_date)`),
#'   or `NULL` when the Python side is unavailable.
#' @keywords internal
.fordead_harmonic_predict <- function(coeff, obs_date,
                                      env_name = .fordead_default_env()) {
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    cli::cli_warn("Package {.pkg reticulate} is required for FORDEAD pixel diagnostics.")
    return(NULL)
  }
  modeling <- tryCatch({
    .use_fordead_env(env_name)
    reticulate::import("fordead.modeling", convert = TRUE)
  }, error = function(e) {
    cli::cli_warn(c(
      "Cannot load the FORDEAD virtualenv {.val {env_name}}: {conditionMessage(e)}",
      i = "The FORDEAD pixel diagnostic needs the {.pkg fordead} Python package."
    ))
    NULL
  })
  if (is.null(modeling)) return(NULL)

  # dates_to_days: integer days since REF_DAY (2015-01-01). This is a
  # plain date subtraction - re-doing it in R is exact and avoids
  # marshalling datetime64 arrays. The harmonic *basis* below is the
  # part that must come from fordead (decision D3).
  days <- as.integer(as.Date(obs_date) - as.Date("2015-01-01"))

  # 5-term harmonic basis from fordead, one call per date. terms is a
  # 5 x N matrix; prediction = coeff . terms per column.
  terms <- vapply(days, function(d) {
    as.numeric(modeling$compute_HarmonicTerms(as.numeric(d)))
  }, numeric(5L))
  as.numeric(crossprod(terms, as.numeric(coeff)))
}


#' Read the FORDEAD CRSWIR pixel diagnostic series
#'
#' For a clicked pixel of a monitoring zone, returns the time series
#' behind the FORDEAD detection: the observed (masked) CRSWIR, the
#' harmonic-model prediction, the anomaly-threshold band and the
#' per-date anomaly flag. Consumes the diagnostic bundle persisted by
#' [run_fordead_dieback()] (spec 008 section 14.3).
#'
#' Modelled on [extract_pixel_timeseries()] (the FAST pixel map) and
#' on [read_fordead_dieback_mask()] for the path / `run_id`
#' conventions.
#'
#' @section `con` parameter:
#' Reserved for a future `fordead_run` tracking table - **not**
#' consulted in this release (discovery is filesystem-based). Kept in
#' the signature for forward compatibility, exactly as
#' [read_fordead_dieback_mask()]. `NULL` is accepted.
#'
#' @param con A `DBI` connection or `NULL`. Reserved (see above).
#' @param zone_id Integer. `monitoring_zone.id`.
#' @param xy Numeric(2). Coordinates of the clicked pixel, in `crs`.
#' @param crs EPSG code of `xy`. Default `4326` (leaflet convention).
#' @param run_id Optional character/integer. When supplied, the bundle
#'   `model_<run_id>/` is read directly; when `NULL` (default) the
#'   most recent bundle of the zone is used.
#' @param cache_dir Character(1). Root of the FORDEAD cache,
#'   typically `<project>/cache/layers/fordead`. Required.
#'
#' @return A `data.frame` ordered by `obs_date`, with columns:
#'   \describe{
#'     \item{obs_date}{`Date` - observation date.}
#'     \item{crswir_obs}{`numeric` - observed masked CRSWIR (`NA` on a
#'       masked date - kept, not dropped).}
#'     \item{crswir_pred}{`numeric` - harmonic-model prediction.}
#'     \item{seuil_haut}{`numeric` - `crswir_pred + threshold_anomaly`.}
#'     \item{anomalie}{`logical` - `crswir_obs > seuil_haut`.}
#'   }
#'   Attributes carried on the data frame: `threshold_anomaly`,
#'   `premiere_detection` (`Date` or `NA`), `dans_zone_validite`
#'   (`logical` or `NA`, via [check_fordead_validity()]),
#'   `vegetation_index`.
#'
#'   Returns `NULL` (without error) when no bundle is found, the
#'   pixel is outside the modelled extent, or the FORDEAD Python
#'   environment is unavailable.
#'
#' @seealso [run_fordead_dieback()], [read_fordead_dieback_mask()].
#'
#' @examples
#' \dontrun{
#'   s <- read_fordead_pixel_series(
#'     con       = NULL,
#'     zone_id   = 1L,
#'     xy        = c(6.42, 46.71),
#'     cache_dir = file.path(project_dir, "cache/layers/fordead")
#'   )
#'   if (!is.null(s)) {
#'     plot(s$obs_date, s$crswir_obs)
#'     lines(s$obs_date, s$crswir_pred)
#'   }
#' }
#'
#' @export
read_fordead_pixel_series <- function(con, zone_id, xy, crs = 4326,
                                      run_id = NULL, cache_dir) {
  if (length(zone_id) != 1L || is.na(zone_id) ||
      !is.finite(suppressWarnings(as.numeric(zone_id)))) {
    stop("`zone_id` must be a single non-NA integer.", call. = FALSE)
  }
  zid <- as.integer(zone_id)
  if (!is.numeric(xy) || length(xy) != 2L || anyNA(xy)) {
    stop("`xy` must be a length-2 numeric, no NA.", call. = FALSE)
  }
  if (missing(cache_dir) || is.null(cache_dir) || !nzchar(cache_dir)) {
    return(NULL)
  }
  if (!requireNamespace("terra", quietly = TRUE)) {
    stop("Package `terra` is required.", call. = FALSE)
  }
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("Package `sf` is required.", call. = FALSE)
  }

  model_dir <- .locate_fordead_model_bundle(cache_dir, zid, run_id)
  if (is.null(model_dir)) return(NULL)

  coeff_fp  <- file.path(model_dir, "coeff_model.tif")
  crswir_fp <- file.path(model_dir, "crswir_stack.tif")
  meta_fp   <- file.path(model_dir, "run_meta.json")
  fa_fp     <- file.path(model_dir, "first_anomaly.tif")
  if (!file.exists(coeff_fp) || !file.exists(crswir_fp)) return(NULL)

  # run_meta.json - calibration + provenance. Best-effort.
  meta <- if (file.exists(meta_fp)) {
    tryCatch(jsonlite::read_json(meta_fp, simplifyVector = TRUE),
             error = function(e) list())
  } else {
    list()
  }
  threshold_anomaly <- if (!is.null(meta$threshold_anomaly)) {
    as.numeric(meta$threshold_anomaly)
  } else {
    NA_real_
  }
  vegetation_index <- if (!is.null(meta$vegetation_index)) {
    as.character(meta$vegetation_index)
  } else {
    NA_character_
  }

  coeff_r  <- terra::rast(coeff_fp)
  crswir_r <- terra::rast(crswir_fp)
  fa_r     <- if (file.exists(fa_fp)) terra::rast(fa_fp) else NULL

  # Reproject the clicked point to the bundle CRS and extract.
  pt        <- sf::st_sfc(sf::st_point(as.numeric(xy)), crs = crs)
  pt_native <- sf::st_transform(pt, terra::crs(crswir_r))
  pv        <- terra::vect(pt_native)

  coeff_vals  <- as.numeric(terra::extract(coeff_r, pv)[1L, -1L])
  crswir_vals <- as.numeric(terra::extract(crswir_r, pv)[1L, -1L])
  # All-NA coefficients == pixel outside the modelled extent (or never
  # modelled) - AC.14.3: return NULL cleanly, no error.
  if (!length(coeff_vals) || all(is.na(coeff_vals))) return(NULL)

  obs_date    <- .crswir_stack_dates(crswir_r)
  crswir_pred <- .fordead_harmonic_predict(coeff_vals, obs_date)
  if (is.null(crswir_pred)) return(NULL)

  seuil_haut <- crswir_pred + threshold_anomaly
  anomalie   <- crswir_vals > seuil_haut

  df <- data.frame(
    obs_date    = obs_date,
    crswir_obs  = crswir_vals,
    crswir_pred = crswir_pred,
    seuil_haut  = seuil_haut,
    anomalie    = anomalie,
    stringsAsFactors = FALSE
  )
  df <- df[order(df$obs_date), , drop = FALSE]
  rownames(df) <- NULL

  # premiere_detection - first confirmed-anomaly date of this pixel.
  premiere_detection <- NA
  if (!is.null(fa_r)) {
    fv <- as.numeric(terra::extract(fa_r, pv)[1L, 2L])
    if (length(fv) == 1L && !is.na(fv)) {
      premiere_detection <- as.Date(fv, origin = "1970-01-01")
    }
  }

  # dans_zone_validite - guard-rail G3 evaluated on the pixel cell.
  # Best-effort: any failure degrades to NA.
  dans_zone_validite <- tryCatch({
    half <- min(terra::res(crswir_r)) / 2
    aoi  <- sf::st_buffer(pt_native, half)
    isTRUE(check_fordead_validity(aoi)$geo_valid)
  }, error = function(e) NA)

  attr(df, "threshold_anomaly")  <- threshold_anomaly
  attr(df, "premiere_detection") <- premiere_detection
  attr(df, "dans_zone_validite") <- dans_zone_validite
  attr(df, "vegetation_index")   <- vegetation_index
  df
}
