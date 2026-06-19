# ============================================================
# fordead_layer.R — read an auxiliary FORDEAD diagnostic raster
# ------------------------------------------------------------
# The persist phase of run_fordead_dieback() writes, besides the
# categorical 0-4 dieback mask, a per-run model bundle under
# zone_<id>/model_<run_id>/ (.write_fordead_model_bundle). This reader
# exposes the bundle's map-relevant single-band rasters so the app
# (Carte FORDEAD) can offer them as selectable display layers, on the
# same footing as read_fordead_dieback_mask().
# ============================================================


#' Read an auxiliary FORDEAD diagnostic raster (model bundle)
#'
#' Loads one of the map-relevant single-band rasters written to the
#' per-run model bundle (`zone_<id>/model_<run_id>/`) by the persist
#' phase of [run_fordead_dieback()], and applies the UGF zone mask the
#' same way [read_fordead_dieback_mask()] does.
#'
#' Recognised layers:
#' \describe{
#'   \item{`"first_anomaly"`}{First confirmed-anomaly date per pixel
#'     (days since 1970-01-01) — feeds the "date de première détection"
#'     display layer.}
#'   \item{`"anomaly_index"`}{Latest continuous anomaly index — feeds the
#'     "indice d'anomalie / sévérité continue" display layer.}
#'   \item{`"modelled_pixels"`}{Binary mask of pixels the harmonic model
#'     could be fitted on — feeds the "confiance / zone modélisée"
#'     display layer.}
#' }
#'
#' Returns `NULL` (never errors) when the cache, the zone, the bundle or
#' the layer file is missing — older runs predating a layer simply yield
#' `NULL`, so the caller degrades gracefully.
#'
#' @param con A `DBIConnection` or `NULL`. Used only to resolve the UGF
#'   AOI for the zone mask (skipped when `NULL`).
#' @param zone_id Integer. `monitoring_zone.id`.
#' @param layer Character. One of `"first_anomaly"`, `"anomaly_index"`,
#'   `"modelled_pixels"`.
#' @param run_id Character or `NULL`. Run timestamp; `NULL` picks the
#'   most recent bundle.
#' @param cache_dir Character. Project FORDEAD cache root
#'   (`<project>/cache/layers/fordead`), same as
#'   [read_fordead_dieback_mask()].
#' @param apply_zone_mask Logical. Restrict to the UGF perimeter
#'   (default `TRUE`).
#' @param mask_polygon Optional `sf`/`sfc` overriding the DB-resolved
#'   AOI.
#'
#' @return A `terra::SpatRaster` (single band) or `NULL`.
#' @export
read_fordead_layer <- function(con,
                               zone_id,
                               layer,
                               run_id    = NULL,
                               cache_dir = NULL,
                               apply_zone_mask = TRUE,
                               mask_polygon    = NULL) {
  layers <- c("first_anomaly", "anomaly_index", "modelled_pixels")
  if (length(layer) != 1L || !layer %in% layers) {
    stop(sprintf("`layer` must be one of %s.",
                 paste(sprintf('"%s"', layers), collapse = ", ")),
         call. = FALSE)
  }
  if (length(zone_id) != 1L || is.na(zone_id) ||
      !is.finite(suppressWarnings(as.numeric(zone_id)))) {
    stop("`zone_id` must be a single non-NA integer.", call. = FALSE)
  }
  if (is.null(cache_dir) || !nzchar(cache_dir) || !dir.exists(cache_dir)) {
    return(NULL)
  }
  if (!requireNamespace("terra", quietly = TRUE)) {
    stop("Package `terra` required.", call. = FALSE)
  }
  zid <- as.integer(zone_id)

  bundle <- .locate_fordead_model_bundle(cache_dir, zid, run_id = run_id)
  if (is.null(bundle)) return(NULL)
  fp <- file.path(bundle, sprintf("%s.tif", layer))
  if (!file.exists(fp)) return(NULL)

  out <- tryCatch(terra::rast(fp), error = function(e) NULL)
  if (is.null(out)) return(NULL)

  # Same UGF re-mask as read_fordead_dieback_mask(): FORDEAD's output is
  # filtered through the national BD Forêt v2 mask (superset of the
  # user's UGFs); restrict to the actual perimeter.
  if (isTRUE(apply_zone_mask)) {
    poly <- mask_polygon %||%
      (if (!is.null(con)) tryCatch(.get_zone_aoi(con, zid),
                                   error = function(e) NULL) else NULL)
    out <- .apply_zone_mask(out, poly)
  }
  out
}
