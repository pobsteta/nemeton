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
