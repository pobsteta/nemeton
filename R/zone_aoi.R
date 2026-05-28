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
