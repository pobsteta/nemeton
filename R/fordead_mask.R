#' Read the FORDEAD dieback classified raster for a zone
#'
#' Returns the **categorical** 0-4 raster produced by
#' [run_fordead_dieback()] for the given monitoring zone. Values:
#' `0 = sain`, `1 = faible`, `2 = moyenne`, `3 = forte`, `4 = sol nu`,
#' `NA` outside the forest mask.
#'
#' Looks up files under `<cache_dir>/zone_<zone_id>/` matching the
#' pattern `dieback_mask_<run_id>.tif`. When `run_id` is `NULL`, the
#' most recent file (lexicographic order on the YYYYMMDDTHHMMSS suffix
#' — which is also chronological) is returned.
#'
#' @section Path convention :
#' Mask files are written by the persist phase of
#' [run_fordead_dieback()] to the conventional layout :
#' \preformatted{<cache_dir>/
#'   zone_<zone_id>/
#'     dieback_mask_<YYYYMMDDTHHMMSS>.tif}
#'
#' With `replace = TRUE` (default) a run prunes the masks of earlier
#' runs of the zone, so the directory usually holds a single file.
#'
#' @section `con` parameter :
#' Discovery of the mask is filesystem-based: `con` is **not** used to
#' find it. It is only read to fetch the zone polygon when
#' `apply_zone_mask = TRUE` and no `mask_polygon` is given; with
#' `con = NULL` the zone mask is then skipped.
#'
#' @param con A `DBI` connection, or `NULL`. Only used to read the zone
#'   polygon for `apply_zone_mask` (see above).
#' @param zone_id Integer. `monitoring_zone.id`.
#' @param run_id Optional character or integer. When supplied, the
#'   file `dieback_mask_<run_id>.tif` is read directly ; when `NULL`
#'   (default), the latest mask file by filename order is returned.
#' @param cache_dir Character(1). Root of the FORDEAD mask cache,
#'   typically `<project>/cache/layers/fordead`. Required — the
#'   spec'd signature `(con, zone_id, run_id)` cannot derive this from
#'   the connection in this release, so the argument is exposed
#'   directly. Pass the same path the app uses for its UI.
#'
#' @param apply_zone_mask Logical. When `TRUE` (default), pixels outside the
#'   monitoring zone polygon (the managed UGF perimeter) are set to `NA`.
#' @param mask_polygon Optional `sf`/`sfc` polygon used as the zone mask
#'   instead of the polygon stored for the zone in the database.
#' @return A `terra::SpatRaster` with a single integer band, or
#'   `NULL` when no mask is available (no `cache_dir` provided, the
#'   directory doesn't exist, or no file matches).
#'
#' @section Lifecycle:
#' Experimental: may change in any release, without deprecation (spec 057).
#'
#' @seealso [run_fordead_dieback()] for the pipeline that produces
#'   the underlying anomaly / dieback rasters.
#'
#' @examples
#' \dontrun{
#'   r <- read_fordead_dieback_mask(
#'     con       = con,
#'     zone_id   = 1L,
#'     cache_dir = file.path(project_dir, "cache/layers/fordead")
#'   )
#'   if (!is.null(r)) terra::plot(r)
#' }
#'
#' @export
read_fordead_dieback_mask <- function(con,
                                      zone_id,
                                      run_id    = NULL,
                                      cache_dir = NULL,
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
    rid <- as.character(run_id)
    fp  <- file.path(zone_dir, sprintf("dieback_mask_%s.tif", rid))
    if (!file.exists(fp)) return(NULL)
    terra::rast(fp)
  } else {
    files <- list.files(zone_dir,
                        pattern = "^dieback_mask_[A-Za-z0-9._-]+\\.tif$",
                        full.names = TRUE)
    if (!length(files)) return(NULL)
    # Filename order on YYYYMMDDTHHMMSS is chronological. Fall back to
    # mtime if the suffix doesn't sort cleanly (e.g. mixed conventions).
    files <- sort(files)
    terra::rast(files[length(files)])
  }

  # spec 016 (v0.49.0) — apply UGF zone mask by default. FORDEAD's
  # output is filtered through the national BD Forêt v2 mask (Python
  # side), which is a *superset* of the user-managed UGFs. This re-mask
  # restricts the dieback_mask to the user's actual perimeter.
  if (isTRUE(apply_zone_mask)) {
    poly <- mask_polygon %||%
      (if (!is.null(con)) tryCatch(.get_zone_aoi(con, zid),
                                   error = function(e) NULL) else NULL)
    out <- .apply_zone_mask(out, poly)
  }
  out
}
