#' Resolve the AOI sf POLYGON of a monitoring zone (EPSG:2154)
#'
#' Queries `monitoring_zone` for the zone's WKT + CRS, parses it via
#' `sf::st_as_sfc()`, and reprojects to Lambert-93 if needed.
#' Errors out with a typed message when the zone is unknown so the
#' caller surfaces an actionable message rather than an empty sf.
#'
#' Used as the single source of truth for the AOI of both the FORDEAD
#' pipeline ([run_fordead_dieback()]) and the FAST surveillance
#' pipeline ([ingest_sentinel2_timeseries()], [ingest_s2_raw_bands_to_cache()])
#' since spec 012. Sharing this resolver guarantees that both pipelines
#' read the *same* COG crop, so the on-disk S2 cache is reused across
#' them (a FORDEAD pre-fetch warms the FAST cache and vice versa).
#'
#' @param con A `DBIConnection`.
#' @param zone_id Integer scalar identifying the row in `monitoring_zone`.
#'
#' @return An `sf` POLYGON in EPSG:2154 (Lambert-93).
#'
#' @keywords internal
.get_zone_aoi <- function(con, zone_id) {
  if (!inherits(con, "DBIConnection")) {
    cli::cli_abort("{.arg con} must be a {.cls DBIConnection}.")
  }
  if (length(zone_id) != 1L || is.na(zone_id)) {
    cli::cli_abort("{.arg zone_id} must be a scalar non-NA identifier.")
  }

  row <- .db_get_query(con,
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


#' Apply the UGF zone mask to a SpatRaster
#'
#' Internal helper introduced in spec 016 (v0.49.0). Sets to `NA`
#' every pixel of `raster` that falls outside the polygon
#' `zone_polygon` (typically the UGF envelope returned by
#' [`.get_zone_aoi`()]). Returns the raster unchanged when
#' `zone_polygon` is `NULL`.
#'
#' Transparently reprojects `zone_polygon` to the raster's CRS if
#' they differ. Wraps `terra::mask()` with a small `tryCatch` so
#' that a failure (mismatched CRS, malformed polygon, …) does not
#' abort the entire pipeline — only `cli_warn` and return the raster
#' unmasked, which is the strictly less-restrictive behaviour
#' (back-compat semantics).
#'
#' @param raster A `terra::SpatRaster`.
#' @param zone_polygon An `sf` POLYGON (or `sfc`), typically
#'   `.get_zone_aoi(con, zone_id)`. `NULL` is a no-op.
#'
#' @return A `terra::SpatRaster` (masked or unchanged).
#' @keywords internal
.apply_zone_mask <- function(raster, zone_polygon) {
  if (is.null(zone_polygon)) return(raster)
  if (!requireNamespace("terra", quietly = TRUE)) return(raster)
  if (!requireNamespace("sf", quietly = TRUE))    return(raster)
  if (!inherits(raster, "SpatRaster")) return(raster)
  if (!inherits(zone_polygon, c("sf", "sfc"))) return(raster)

  tryCatch({
    poly_in_raster_crs <- sf::st_transform(zone_polygon,
                                           terra::crs(raster))
    terra::mask(raster, terra::vect(poly_in_raster_crs))
  }, error = function(e) {
    cli::cli_warn(c(
      "Failed to apply UGF zone mask to raster, returning unmasked.",
      i = "{conditionMessage(e)}"
    ))
    raster
  })
}


#' Keep only the alert features inside the UGF zone polygon
#'
#' Vector analogue of [`.apply_zone_mask`()] (spec 021 L7 revision):
#' drops the rows of an `sf` POINT alert layer whose geometry falls
#' outside `zone_polygon` (the UGF envelope). Returns the layer
#' unchanged when `zone_polygon` is `NULL`, when the input is not a
#' non-empty `sf`, or on any spatial error (best-effort, back-compat:
#' the unfiltered layer is the strictly less-restrictive result).
#'
#' Transparently reprojects `zone_polygon` to the alerts' CRS.
#'
#' @param alerts_sf An `sf` (POINT centroids, e.g. `result$alerts_sf`).
#' @param zone_polygon An `sf`/`sfc` polygon, typically
#'   `.get_zone_aoi(con, zone_id)`. `NULL` is a no-op.
#' @return An `sf` (filtered or unchanged).
#' @keywords internal
.filter_alerts_to_zone <- function(alerts_sf, zone_polygon) {
  if (is.null(zone_polygon)) return(alerts_sf)
  if (!requireNamespace("sf", quietly = TRUE)) return(alerts_sf)
  if (!inherits(alerts_sf, "sf")) return(alerts_sf)
  if (!nrow(alerts_sf)) return(alerts_sf)
  if (!inherits(zone_polygon, c("sf", "sfc"))) return(alerts_sf)

  tryCatch({
    poly <- sf::st_transform(sf::st_geometry(zone_polygon),
                             sf::st_crs(alerts_sf))
    hits <- lengths(sf::st_intersects(alerts_sf, poly)) > 0L
    alerts_sf[hits, , drop = FALSE]
  }, error = function(e) {
    cli::cli_warn(c(
      "Failed to filter alerts to UGF zone, returning unfiltered.",
      i = "{conditionMessage(e)}"
    ))
    alerts_sf
  })
}


#' Restrict an alert layer to the UGF zone, at read time (spec 021 L7)
#'
#' @description
#' Vector counterpart of the read-time raster masking
#' ([read_reconfort_layer()], [read_fast_alert_raster()],
#' [read_fordead_dieback_mask()], spec 016). Keeps only the alert
#' centroids that fall **inside the UGF zone polygon**, so a viewer no
#' longer shows alerts outside the user's managed perimeter.
#'
#' Shared by the three health pipelines (RECONFORT, FORDEAD, FAST): the
#' filtering operation is identical for any `sf` POINT alert layer, so a
#' single core helper provides true parity and keeps the spatial
#' predicate out of the presentation layer (ADR-009, CLAUDE.md strict
#' rules §1-3). The persisted `alert` table is **not** modified — the
#' filter is applied at read/display time only (spec 016 principle
#' "mask at read, not write"); the per-zone `zone_id` provenance is kept.
#'
#' @param alerts An `sf` POINT layer (e.g. `result$alerts_sf` from
#'   [run_reconfort_dieback()] / [run_fordead_dieback()], or rows read
#'   from the `alert` table). Returned unchanged if not a non-empty `sf`.
#' @param con A `DBIConnection`, used only to resolve the zone polygon
#'   via [`.get_zone_aoi`()] when `mask_polygon` is `NULL`.
#' @param zone_id Integer scalar identifying the row in `monitoring_zone`.
#' @param apply_zone_mask If `TRUE` (default), keep only in-zone alerts.
#'   `FALSE` returns the layer unchanged.
#' @param mask_polygon An explicit `sf`/`sfc` polygon overriding the DB
#'   lookup (e.g. a single stratum). When `NULL`, the polygon is resolved
#'   from `con` + `zone_id`.
#'
#' @return An `sf` (filtered to the UGF zone unless `apply_zone_mask =
#'   FALSE` or no polygon could be resolved).
#'
#' @seealso [read_reconfort_layer()], [read_fast_alert_raster()],
#'   [read_fordead_dieback_mask()]
#' @export
filter_alerts_to_zone <- function(alerts, con = NULL, zone_id = NULL,
                                  apply_zone_mask = TRUE,
                                  mask_polygon = NULL) {
  if (!isTRUE(apply_zone_mask)) return(alerts)
  poly <- mask_polygon %||%
    (if (!is.null(con) && !is.null(zone_id))
       tryCatch(.get_zone_aoi(con, as.integer(zone_id)),
                error = function(e) NULL)
     else NULL)
  if (is.null(poly)) {
    cli::cli_warn(c(
      "{.arg apply_zone_mask} is TRUE but no UGF polygon could be resolved.",
      i = "Provide {.arg mask_polygon}, or both {.arg con} and {.arg zone_id}.",
      i = "Returning the unfiltered alerts."
    ))
    return(alerts)
  }
  .filter_alerts_to_zone(alerts, poly)
}
