#' Alert Detection on Sentinel-2 Time Series (E6 monitoring)
#'
#' @description
#' Compares each `obs_pixel` value against the rolling mean of the
#' previous `window_days` and flags drops larger than the per-band
#' threshold. New alerts are inserted into the `alert` table; the
#' function is idempotent thanks to the unique constraint on
#' `(plot_id, alert_type, trigger_date)`.
#'
#' Two alert types are produced:
#' \itemize{
#'   \item \code{ndvi_drop} — defoliation, clear-cut, drought
#'   \item \code{nbr_drop} — fire scar, severe canopy loss
#' }
#'
#' @name alerts
NULL


#' Detect drops in NDVI / NBR time series
#'
#' @description
#' \strong{Deprecated since v0.58.0; scheduled for removal in v0.60.0.}
#' This is the legacy per-placette rolling-window alert detector. Since
#' spec 017 the FAST diagnostic is a pure per-pixel raster from the COG
#' cache ([read_fast_alert_raster()] / [compute_fast_alert_mask()]),
#' independent of the validation sampling plan. The `obs_pixel` table it
#' reads was dropped in v0.58.0, so this function will fail at the SQL
#' stage.
#'
#' @param con A `DBIConnection` returned by [db_connect()].
#' @param zone_id Integer. Restrict detection to plots of this zone.
#' @param threshold_ndvi_drop Numeric. Minimum drop in NDVI (rolling
#'   mean − current value) to flag as `ndvi_drop`. Default 0.15.
#' @param threshold_nbr_drop Numeric. Minimum drop in NBR. Default 0.25.
#' @param window_days Integer. Length of the rolling baseline window
#'   in days. Default 30.
#'
#' @return An sf POINT object (CRS WGS84) with one row per alert,
#'   columns `plot_id`, `alert_type`, `trigger_date`, `value_before`,
#'   `value_after`, `delta`. Empty sf when no alert is found.
#'
#' @keywords internal
#' @export
detect_alerts <- function(con, zone_id,
                          threshold_ndvi_drop = 0.15,
                          threshold_nbr_drop  = 0.25,
                          window_days         = 30) {
  cli::cli_warn(paste(
    "{.fn detect_alerts} is deprecated and will be removed in v0.60.0 ;",
    "use the per-pixel {.fn read_fast_alert_raster} /",
    "{.fn compute_fast_alert_mask} instead."
  ))
  .assert_db_pkgs()

  # Detection: window function over (plot, band) computing the rolling
  # mean of the [window_days] preceding observations, then comparing
  # the current value to that baseline. Drops larger than the
  # band-specific threshold are persisted (idempotent INSERT).
  sql_detect <- sprintf("
    WITH rolling AS (
      SELECT op.plot_id, op.band, op.obs_date, op.value,
             AVG(op.value) OVER (
               PARTITION BY op.plot_id, op.band
               ORDER BY op.obs_date
               RANGE BETWEEN INTERVAL '%d days' PRECEDING
                         AND INTERVAL '1 day'  PRECEDING
             ) AS avg_prev
        FROM obs_pixel op
        JOIN plot p ON p.id = op.plot_id
       WHERE p.zone_id = $1
         AND op.value IS NOT NULL
    ),
    flagged AS (
      SELECT plot_id, band, obs_date, value, avg_prev,
             (avg_prev - value) AS drop_val
        FROM rolling
       WHERE avg_prev IS NOT NULL
         AND ((band = 'NDVI' AND (avg_prev - value) > $2)
           OR (band = 'NBR'  AND (avg_prev - value) > $3))
    )
    INSERT INTO alert (plot_id, alert_type, trigger_date,
                       value_before, value_after, delta)
    SELECT plot_id,
           CASE WHEN band = 'NDVI' THEN 'ndvi_drop' ELSE 'nbr_drop' END,
           obs_date, avg_prev, value, drop_val
      FROM flagged
     WHERE 1=1
    ON CONFLICT (plot_id, alert_type, trigger_date) DO NOTHING
  ", as.integer(window_days))

  .db_execute(con, sql_detect,
                 params = list(as.integer(zone_id),
                               as.numeric(threshold_ndvi_drop),
                               as.numeric(threshold_nbr_drop)))

  # Return all alerts for the zone (not just newly inserted ones; the
  # caller usually wants the full current state).
  rs <- .db_get_query(con,
    "SELECT a.plot_id, p.plot_id AS plot_label, a.alert_type,
            a.trigger_date, a.value_before, a.value_after, a.delta,
            p.geom_wkt
       FROM alert a
       JOIN plot p ON p.id = a.plot_id
      WHERE p.zone_id = $1
      ORDER BY a.trigger_date DESC, a.plot_id",
    params = list(as.integer(zone_id)))

  if (!nrow(rs)) {
    return(sf::st_sf(data.frame(plot_id = integer(0),
                                plot_label = character(0),
                                alert_type = character(0),
                                trigger_date = as.Date(character(0)),
                                value_before = numeric(0),
                                value_after = numeric(0),
                                delta = numeric(0)),
                     geometry = sf::st_sfc(crs = 4326)))
  }
  geoms <- lapply(rs$geom_wkt, sf::st_as_sfc, crs = 4326)
  geom_sfc <- do.call(c, geoms)
  rs$geom_wkt <- NULL
  sf::st_sf(rs, geometry = geom_sfc, crs = 4326)
}
