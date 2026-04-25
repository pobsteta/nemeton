#' Sentinel-2 Time Series Ingestion (E6 monitoring)
#'
#' @description
#' Fetch Sentinel-2 L2A scenes covering a set of plots over a date
#' range, derive NDVI and NBR per scene, extract the per-plot mean
#' value over a circular buffer, and persist into the `obs_pixel`
#' hypertable of the monitoring database.
#'
#' Triggered on demand: no cron worker is started by this function.
#' One call = one ingestion window.
#'
#' @name monitoring_ingest
NULL


#' Register a monitoring zone and its plots in the database
#'
#' Helper that upserts a `monitoring_zone` row and the associated
#' `plot` rows. Idempotent on `(zone_name, plot_id)`.
#'
#' @param con A `DBIConnection` returned by [db_connect()].
#' @param zone_name Character. Display name for the zone.
#' @param zone_polygon An sf POLYGON (any CRS — re-projected to WGS84
#'   internally for storage).
#' @param placettes An sf POINT object with at least the columns
#'   `plot_id` (character) and optionally `type`.
#' @param radius_m Numeric. Sampling radius around each placette in
#'   metres. Default 15.
#'
#' @return The `zone_id` (integer) of the registered zone.
#'
#' @export
register_monitoring_zone <- function(con, zone_name, zone_polygon,
                                     placettes, radius_m = 15) {
  .assert_db_pkgs()
  if (!inherits(zone_polygon, c("sf", "sfc"))) {
    cli::cli_abort("{.arg zone_polygon} must be an sf/sfc object.")
  }
  if (!inherits(placettes, "sf") || !"plot_id" %in% names(placettes)) {
    cli::cli_abort("{.arg placettes} must be an sf object with a {.val plot_id} column.")
  }

  zone_4326 <- sf::st_transform(zone_polygon, 4326)
  zone_wkt  <- sf::st_as_text(sf::st_geometry(zone_4326)[[1]])

  zone_id <- DBI::dbWithTransaction(con, {
    DBI::dbExecute(con,
      "INSERT INTO monitoring_zone (name, zone_wkt, crs_epsg) VALUES ($1, $2, 4326)",
      params = list(zone_name, zone_wkt))
    rs <- DBI::dbGetQuery(con,
      "SELECT id FROM monitoring_zone WHERE name = $1 ORDER BY id DESC LIMIT 1",
      params = list(zone_name))
    rs$id[1]
  })

  pts <- sf::st_transform(placettes, 4326)
  geoms <- sf::st_geometry(pts)
  type <- if ("type" %in% names(pts)) as.character(pts$type) else rep(NA_character_, nrow(pts))
  for (i in seq_len(nrow(pts))) {
    DBI::dbExecute(con,
      paste0("INSERT INTO plot (zone_id, plot_id, plot_type, geom_wkt, radius_m) ",
             "VALUES ($1, $2, $3, $4, $5) ",
             "ON CONFLICT (zone_id, plot_id) DO NOTHING"),
      params = list(zone_id,
                    as.character(pts$plot_id[i]),
                    type[i],
                    sf::st_as_text(geoms[[i]]),
                    radius_m))
  }
  invisible(as.integer(zone_id))
}


#' Ingest a Sentinel-2 time series for the plots of a monitoring zone
#'
#' Searches Sentinel-2 L2A scenes (CDSE then PC fallback), computes
#' NDVI and/or NBR per scene, extracts the mean per plot over a
#' circular buffer (`exactextractr::exact_extract`), and inserts the
#' results into `obs_pixel` (idempotent on
#' `(plot_id, obs_date, band)`).
#'
#' @param con A `DBIConnection`.
#' @param zone_id Integer. Existing zone in `monitoring_zone`.
#' @param start,end Date or character `"YYYY-MM-DD"`.
#' @param bands Character vector. Subset of `c("NDVI", "NBR")`.
#' @param max_cloud Numeric. Maximum scene cloud cover (%). Default 20.
#'
#' @return A tibble summarising the ingestion: number of scenes
#'   considered, number of observations inserted, bands ingested.
#'
#' @export
ingest_sentinel2_timeseries <- function(con, zone_id,
                                        start, end,
                                        bands = c("NDVI", "NBR"),
                                        max_cloud = 20) {
  .assert_db_pkgs()
  if (!requireNamespace("terra", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg terra} required.")
  }
  if (!requireNamespace("exactextractr", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg exactextractr} required.")
  }
  bands <- match.arg(bands, c("NDVI", "NBR"), several.ok = TRUE)

  plots <- .fetch_plots_sf(con, zone_id)
  if (!nrow(plots)) {
    cli::cli_warn("No plots registered for zone_id {.val {zone_id}}. Use {.fn register_monitoring_zone} first.")
    return(.empty_ingest_summary())
  }

  bbox <- sf::st_as_sfc(sf::st_bbox(plots))
  scenes <- stac_search_s2(bbox, start, end, max_cloud = max_cloud)
  if (!nrow(scenes)) {
    cli::cli_alert_info("No Sentinel-2 scene found for zone_id {zone_id} between {start} and {end} (max_cloud = {max_cloud}%).")
    return(.empty_ingest_summary())
  }

  total_inserted <- 0L
  for (i in seq_len(nrow(scenes))) {
    sc <- scenes[i, , drop = FALSE]
    obs <- tryCatch(
      .extract_scene_obs(sc, plots, bands),
      error = function(e) {
        cli::cli_warn("Scene {.val {sc$scene_id}} skipped: {conditionMessage(e)}")
        NULL
      }
    )
    if (is.null(obs) || !nrow(obs)) next
    inserted <- .insert_obs_pixel(con, obs)
    total_inserted <- total_inserted + inserted
  }

  data.frame(
    n_scenes        = nrow(scenes),
    n_obs_inserted  = total_inserted,
    n_plots         = nrow(plots),
    bands           = paste(bands, collapse = "+"),
    stringsAsFactors = FALSE
  )
}


# ---- Internal helpers ------------------------------------------------

.empty_ingest_summary <- function() {
  data.frame(
    n_scenes = 0L, n_obs_inserted = 0L,
    n_plots = 0L, bands = "",
    stringsAsFactors = FALSE
  )
}

.fetch_plots_sf <- function(con, zone_id) {
  rs <- DBI::dbGetQuery(con,
    "SELECT id, plot_id, plot_type, geom_wkt, radius_m
       FROM plot
      WHERE zone_id = $1
      ORDER BY id",
    params = list(zone_id))
  if (!nrow(rs)) return(sf::st_sf(data.frame(),
                                   geometry = sf::st_sfc(crs = 4326)))
  geoms <- lapply(rs$geom_wkt, sf::st_as_sfc, crs = 4326)
  geom_sfc <- do.call(c, geoms)
  rs$geom_wkt <- NULL
  sf::st_sf(rs, geometry = geom_sfc, crs = 4326)
}

.extract_scene_obs <- function(scene, plots, bands) {
  # Buffer plots in their native projected CRS (Lambert-93 by default
  # for FR; in 4326 we'd buffer in degrees, which is wrong).
  plots_proj <- sf::st_transform(plots, 2154)
  buf <- sf::st_buffer(plots_proj, dist = plots_proj$radius_m)

  # Read just the windows we need. terra reads COGs over HTTP via VSI.
  rB04 <- terra::rast(scene$href_B04)
  rB08 <- terra::rast(scene$href_B08)
  buf_in_raster_crs_04 <- sf::st_transform(buf, terra::crs(rB04))
  buf_in_raster_crs_08 <- sf::st_transform(buf, terra::crs(rB08))
  rB04 <- terra::crop(rB04, terra::ext(terra::vect(buf_in_raster_crs_04)),
                      snap = "out")
  rB08 <- terra::crop(rB08, terra::ext(terra::vect(buf_in_raster_crs_08)),
                      snap = "out")
  # B04 and B08 share resolution (10 m), no resample needed.

  out <- list()

  if ("NDVI" %in% bands) {
    ndvi <- (rB08 - rB04) / (rB08 + rB04)
    vals <- exactextractr::exact_extract(ndvi, buf_in_raster_crs_08, "mean",
                                         progress = FALSE)
    out$NDVI <- data.frame(
      plot_id   = plots$id,
      obs_date  = scene$obs_date,
      band      = "NDVI",
      value     = as.numeric(vals),
      cloud_pct = scene$cloud_pct,
      source    = scene$source,
      scene_id  = scene$scene_id,
      stringsAsFactors = FALSE
    )
  }

  if ("NBR" %in% bands) {
    rB12 <- terra::rast(scene$href_B12)
    buf_in_raster_crs_12 <- sf::st_transform(buf, terra::crs(rB12))
    rB12 <- terra::crop(rB12, terra::ext(terra::vect(buf_in_raster_crs_12)),
                        snap = "out")
    # B12 is 20 m — resample to B08 grid for the formula.
    rB12r <- terra::resample(rB12, rB08, method = "bilinear")
    nbr <- (rB08 - rB12r) / (rB08 + rB12r)
    vals <- exactextractr::exact_extract(nbr, buf_in_raster_crs_08, "mean",
                                         progress = FALSE)
    out$NBR <- data.frame(
      plot_id   = plots$id,
      obs_date  = scene$obs_date,
      band      = "NBR",
      value     = as.numeric(vals),
      cloud_pct = scene$cloud_pct,
      source    = scene$source,
      scene_id  = scene$scene_id,
      stringsAsFactors = FALSE
    )
  }

  do.call(rbind, out)
}

.insert_obs_pixel <- function(con, obs) {
  if (!nrow(obs)) return(0L)
  # Bulk insert via a temp staging table to avoid per-row round-trips.
  staging <- "tmp_obs_pixel_staging"
  DBI::dbExecute(con,
    paste0("CREATE TEMP TABLE IF NOT EXISTS ", staging, " (",
           "plot_id   INTEGER, ",
           "obs_date  DATE, ",
           "band      TEXT, ",
           "value     DOUBLE PRECISION, ",
           "cloud_pct NUMERIC, ",
           "source    TEXT, ",
           "scene_id  TEXT) ON COMMIT DROP"))
  DBI::dbWithTransaction(con, {
    DBI::dbAppendTable(con, staging, obs)
    rs <- DBI::dbExecute(con, sprintf(
      "INSERT INTO obs_pixel (plot_id, obs_date, band, value, cloud_pct, source, scene_id)
         SELECT plot_id, obs_date, band, value, cloud_pct, source, scene_id
         FROM %s
       ON CONFLICT (plot_id, obs_date, band) DO NOTHING",
      staging))
    rs
  })
}
