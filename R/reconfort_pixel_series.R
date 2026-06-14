#' RECONFORT pixel CRswir/CRre diagnostic (L5, spec 021)
#'
#' @description
#' Reader side of the RECONFORT feature bundle persisted by
#' [run_reconfort_dieback()] (L5, [reconfort_outputs]). Given a clicked
#' pixel it returns the observed CRswir and CRre series — the data behind
#' the click-to-diagnose plotly of the RECONFORT map. Unlike the FORDEAD
#' diagnostic there is no harmonic model to reconstruct: the indices are
#' observed values, so no Python / reticulate is involved.
#'
#' @name reconfort_pixel_series
NULL


#' Locate a RECONFORT feature bundle directory
#'
#' Bundles live under `<cache_dir>/zone_<zone_id>/run_<run_id>/`
#' (mirror of [.locate_fordead_model_bundle()], `run_` prefix). When
#' `run_id` is `NULL` the most recent bundle (lexicographic, hence
#' chronological on the `YYYYMMDDTHHMMSS` suffix) wins.
#'
#' @param cache_dir Character(1). Root of the RECONFORT cache.
#' @param zone_id Integer. `monitoring_zone.id`.
#' @param run_id Optional character/integer. Explicit run selector.
#' @return Character(1) bundle directory, or `NULL` when none exists.
#' @keywords internal
.locate_reconfort_features_bundle <- function(cache_dir, zone_id,
                                              run_id = NULL) {
  if (is.null(cache_dir) || !nzchar(cache_dir) || !dir.exists(cache_dir)) {
    return(NULL)
  }
  zone_dir <- file.path(cache_dir, sprintf("zone_%d", as.integer(zone_id)))
  if (!dir.exists(zone_dir)) return(NULL)
  if (!is.null(run_id)) {
    d <- file.path(zone_dir, sprintf("run_%s", as.character(run_id)))
    return(if (dir.exists(d)) d else NULL)
  }
  dirs <- list.dirs(zone_dir, recursive = FALSE, full.names = TRUE)
  dirs <- dirs[grepl("^run_", basename(dirs))]
  if (!length(dirs)) return(NULL)
  sort(dirs)[length(dirs)]
}


#' Read the RECONFORT CRswir/CRre pixel diagnostic series
#'
#' For a clicked pixel of a monitoring zone, returns the observed CRswir
#' and CRre time series persisted by [run_reconfort_dieback()] (L5).
#'
#' @section `con` parameter:
#' Reserved for a future `reconfort_run` tracking table — **not**
#' consulted in this release (discovery is filesystem-based). Kept in the
#' signature for forward compatibility, like [read_fordead_pixel_series()].
#' `NULL` is accepted.
#'
#' @param con A `DBI` connection or `NULL`. Reserved (see above).
#' @param zone_id Integer. `monitoring_zone.id`.
#' @param xy Numeric(2). Coordinates of the clicked pixel, in `crs`.
#' @param crs EPSG code of `xy`. Default `4326` (leaflet convention).
#' @param run_id Optional character/integer. When supplied, the bundle
#'   `run_<run_id>/` is read directly; when `NULL` (default) the most
#'   recent bundle of the zone is used.
#' @param cache_dir Character(1). Root of the RECONFORT cache,
#'   typically `<project>/cache/layers/reconfort`. Required.
#'
#' @return A `data.frame` ordered by `obs_date`, with columns:
#'   \describe{
#'     \item{obs_date}{`Date` — observation date.}
#'     \item{crswir_obs}{`numeric` — observed CRswir (`NA` on a masked date).}
#'     \item{crre_obs}{`numeric` — observed CRre (`NA` on a masked date).}
#'   }
#'   Attributes: `species`, `v_model`, `n_classes`, `date_from`,
#'   `date_to`, `dans_zone_validite` (`logical`/`NA`, advisory G3 via
#'   [check_reconfort_validity()]).
#'
#'   Returns `NULL` (without error) when no bundle is found or the pixel
#'   is outside the extent.
#'
#' @seealso [run_reconfort_dieback()], [read_fordead_pixel_series()].
#' @export
read_reconfort_pixel_series <- function(con, zone_id, xy, crs = 4326,
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
  if (!requireNamespace("terra", quietly = TRUE) ||
      !requireNamespace("sf", quietly = TRUE)) {
    stop("Packages `terra` and `sf` are required.", call. = FALSE)
  }

  bundle <- .locate_reconfort_features_bundle(cache_dir, zid, run_id)
  if (is.null(bundle)) return(NULL)
  crswir_fp <- file.path(bundle, "crswir_stack.tif")
  crre_fp   <- file.path(bundle, "crre_stack.tif")
  meta_fp   <- file.path(bundle, "run_meta.json")
  if (!file.exists(crswir_fp) || !file.exists(crre_fp)) return(NULL)

  meta <- if (file.exists(meta_fp)) {
    tryCatch(jsonlite::read_json(meta_fp, simplifyVector = TRUE),
             error = function(e) list())
  } else list()

  crswir_r <- terra::rast(crswir_fp)
  crre_r   <- terra::rast(crre_fp)

  pt        <- sf::st_sfc(sf::st_point(as.numeric(xy)), crs = crs)
  pt_native <- sf::st_transform(pt, terra::crs(crswir_r))
  pv        <- terra::vect(pt_native)

  crswir_vals <- as.numeric(terra::extract(crswir_r, pv)[1L, -1L])
  crre_vals   <- as.numeric(terra::extract(crre_r, pv)[1L, -1L])
  # Pixel outside the modelled extent → both all-NA → NULL, no error.
  if ((!length(crswir_vals) || all(is.na(crswir_vals))) &&
      (!length(crre_vals)   || all(is.na(crre_vals)))) {
    return(NULL)
  }

  obs_date <- .crswir_stack_dates(crswir_r)
  df <- data.frame(
    obs_date   = obs_date,
    crswir_obs = crswir_vals,
    crre_obs   = crre_vals,
    stringsAsFactors = FALSE
  )
  df <- df[order(df$obs_date), , drop = FALSE]
  rownames(df) <- NULL

  dans_zone_validite <- tryCatch({
    half <- min(terra::res(crswir_r)) / 2
    aoi  <- sf::st_buffer(pt_native, half)
    isTRUE(check_reconfort_validity(aoi)$geo_valid)
  }, error = function(e) NA)

  or_default <- function(x, default) if (is.null(x)) default else x
  attr(df, "species")            <- or_default(meta$species,   NA_character_)
  attr(df, "v_model")            <- or_default(meta$v_model,   NA_character_)
  attr(df, "n_classes")          <- or_default(meta$n_classes, NA_integer_)
  attr(df, "date_from")          <- or_default(meta$date_from, NA_character_)
  attr(df, "date_to")            <- or_default(meta$date_to,   NA_character_)
  attr(df, "dans_zone_validite") <- dans_zone_validite
  df
}


#' Read the RECONFORT broadleaf-classification raster for a zone
#'
#' Returns the **categorical** class raster produced by
#' [run_reconfort_dieback()] for the given monitoring zone. Values:
#' `1 = sain`, `2 = dépérissant`, `3 = très dépérissant`, `0`/`NA`
#' outside the broadleaf mask. The RECONFORT mirror of
#' [read_fordead_dieback_mask()] — it feeds
#' [create_validation_sampling_plan()] (`source = "RECONFORT"`,
#' `classes = c(2, 3)`, `control_classes = c(1)`) so the broadleaf
#' validation plan reuses the same raster sampling machinery as FORDEAD.
#'
#' Looks up `<cache_dir>/zone_<zone_id>/reconfort_mask_<run_id>.tif`
#' (written by the `persist` phase of [run_reconfort_dieback()]); when
#' `run_id` is `NULL` the most recent file (lexicographic, hence
#' chronological on the `YYYYMMDDTHHMMSS` suffix) is returned.
#'
#' @param con A `DBI` connection or `NULL`. Used (when not `NULL`) to
#'   re-mask the raster to the zone AOI, like
#'   [read_fordead_dieback_mask()].
#' @param zone_id Integer. `monitoring_zone.id`.
#' @param run_id Optional character/integer. Explicit run selector.
#' @param cache_dir Character(1). Root of the RECONFORT cache,
#'   typically `<project>/cache/layers/reconfort`. Required.
#' @param apply_zone_mask Logical. Re-mask to the UGF zone AOI. Default
#'   `TRUE`.
#' @param mask_polygon Optional `sf`/`sfc` polygon overriding the AOI.
#'
#' @return A single-band `terra::SpatRaster`, or `NULL` when no mask is
#'   available.
#'
#' @seealso [read_fordead_dieback_mask()], [run_reconfort_dieback()].
#' @export
read_reconfort_alert_mask <- function(con,
                                      zone_id,
                                      run_id          = NULL,
                                      cache_dir       = NULL,
                                      apply_zone_mask = TRUE,
                                      mask_polygon    = NULL) {
  if (length(zone_id) != 1L || is.na(zone_id) ||
      !is.finite(suppressWarnings(as.numeric(zone_id)))) {
    stop("`zone_id` must be a single non-NA integer.", call. = FALSE)
  }
  zid <- as.integer(zone_id)
  if (is.null(cache_dir) || !nzchar(cache_dir) || !dir.exists(cache_dir)) {
    return(NULL)
  }
  if (!requireNamespace("terra", quietly = TRUE)) {
    stop("Package `terra` required.", call. = FALSE)
  }
  zone_dir <- file.path(cache_dir, sprintf("zone_%d", zid))
  if (!dir.exists(zone_dir)) return(NULL)

  out <- if (!is.null(run_id)) {
    fp <- file.path(zone_dir, sprintf("reconfort_mask_%s.tif", as.character(run_id)))
    if (!file.exists(fp)) return(NULL)
    terra::rast(fp)
  } else {
    files <- list.files(zone_dir,
                        pattern = "^reconfort_mask_[A-Za-z0-9._-]+\\.tif$",
                        full.names = TRUE)
    if (!length(files)) return(NULL)
    terra::rast(sort(files)[length(files)])
  }

  if (isTRUE(apply_zone_mask)) {
    poly <- mask_polygon %||%
      (if (!is.null(con)) tryCatch(.get_zone_aoi(con, zid),
                                   error = function(e) NULL) else NULL)
    out <- .apply_zone_mask(out, poly)
  }
  out
}
