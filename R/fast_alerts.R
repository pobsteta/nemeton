#' List FAST surveillance alerts for a monitoring zone
#'
#' @description
#' \strong{Deprecated since v0.58.0; scheduled for removal in v0.60.0.}
#' This is the legacy per-placette rolling-window FAST path. Since spec
#' 017 the FAST diagnostic is a pure per-pixel raster computed from the
#' COG cache by [read_fast_alert_raster()] / [compute_fast_alert_mask()],
#' independent of the validation sampling plan. The `obs_pixel` table it
#' aggregates was dropped in v0.58.0, so this function will fail at the
#' SQL stage.
#'
#' Aggregates the `obs_pixel` hypertable over the last `window_days`
#' of observations within `[date_from, date_to]` and returns the plots
#' whose NDVI / NBR rolling-window mean fell into the alert zone of
#' either threshold. Severity is bucketed by the margin under (or just
#' above) the threshold.
#'
#' @section Severity rules:
#' Let `r_ndvi = ndvi_value / threshold_ndvi` (and analogously for NBR).
#' A plot is classified by the **lower** of the two ratios :
#' \describe{
#'   \item{`critical`}{`r < 0.5` on either band — value below half the
#'     threshold.}
#'   \item{`warning`}{`0.5 <= r < 1.0` on either band — under the
#'     threshold but in the upper half.}
#'   \item{`info`}{`1.0 <= r < 1.1` on either band — still above the
#'     threshold but in the 10 % warning corridor.}
#' }
#' Plots with both ratios `>= 1.1` (safe) are not returned. Plots with
#' no NDVI nor NBR observation in the window are not returned either.
#'
#' @section SQL:
#' Both `plot.geom_wkt` (POINT in EPSG:4326) and the `obs_pixel`
#' aggregation happen server-side. Filter values are inlined via
#' [DBI::dbQuoteLiteral()] — same hardening pattern as
#' [read_obs_pixel()].
#'
#' @param con A `DBI` connection to the `nemeton` monitoring schema
#'   (PostgreSQL + TimescaleDB or SQLite).
#' @param zone_id Integer. `monitoring_zone.id`.
#' @param threshold_ndvi Numeric. Default `0.40`.
#' @param threshold_nbr Numeric. Default `0.30`.
#' @param window_days Integer rolling window length, in days. Default
#'   `30L`. Observations within `[date_to - window_days, date_to]` are
#'   averaged per band per plot.
#' @param date_from,date_to `Date` or character `"YYYY-MM-DD"`. Both
#'   required. `date_to` is the right edge of the rolling window ;
#'   `date_from` is the left edge of the search range (any plot with
#'   no observation in `[date_from, date_to]` is excluded).
#'
#' @return An `sf` POINT layer in **EPSG:4326** with columns:
#'   \describe{
#'     \item{plot_id}{character — human-readable `plot.plot_id`.}
#'     \item{last_obs_date}{`Date` — most recent observation date used
#'       in the rolling window for this plot.}
#'     \item{ndvi_value}{numeric — rolling-window mean NDVI, or `NA`.}
#'     \item{nbr_value}{numeric — rolling-window mean NBR, or `NA`.}
#'     \item{ndvi_drop}{numeric — `threshold_ndvi - ndvi_value` when
#'       positive (deeper drop = larger value), else `NA`.}
#'     \item{nbr_drop}{numeric — same for NBR, else `NA`.}
#'     \item{severity}{ordered factor with levels `c("info","warning",
#'       "critical")` — most severe of the two bands.}
#'   }
#'   Empty `sf` with the right column schema when no plot is in the
#'   alert zone.
#'
#' @seealso [read_obs_pixel()] for the raw per-observation table,
#'   [register_monitoring_zone()] to obtain `zone_id`.
#'
#' @examples
#' \dontrun{
#'   con <- db_connect(Sys.getenv("NEMETON_DB_URL"))
#'   on.exit(db_disconnect(con), add = TRUE)
#'   alerts <- list_fast_alerts_for_zone(
#'     con, zone_id = 1L,
#'     date_from = "2025-01-01",
#'     date_to   = Sys.Date()
#'   )
#'   table(alerts$severity)
#' }
#'
#' @keywords internal
#' @export
list_fast_alerts_for_zone <- function(con, zone_id,
                                      threshold_ndvi = 0.40,
                                      threshold_nbr  = 0.30,
                                      window_days    = 30L,
                                      date_from, date_to) {
  cli::cli_warn(paste(
    "{.fn list_fast_alerts_for_zone} is deprecated and will be removed in",
    "v0.60.0 ; use the per-pixel {.fn read_fast_alert_raster} /",
    "{.fn compute_fast_alert_mask} instead."
  ))
  if (!inherits(con, "DBIConnection")) {
    stop("`con` must be a DBI connection.", call. = FALSE)
  }
  if (length(zone_id) != 1L || is.na(zone_id) ||
      !is.finite(suppressWarnings(as.numeric(zone_id)))) {
    stop("`zone_id` must be a single non-NA integer.", call. = FALSE)
  }
  zid <- as.integer(zone_id)

  if (!is.numeric(threshold_ndvi) || length(threshold_ndvi) != 1L ||
      is.na(threshold_ndvi) || threshold_ndvi <= 0) {
    stop("`threshold_ndvi` must be a positive numeric scalar.", call. = FALSE)
  }
  if (!is.numeric(threshold_nbr) || length(threshold_nbr) != 1L ||
      is.na(threshold_nbr) || threshold_nbr <= 0) {
    stop("`threshold_nbr` must be a positive numeric scalar.", call. = FALSE)
  }
  if (!is.numeric(window_days) || length(window_days) != 1L ||
      is.na(window_days) || window_days < 1) {
    stop("`window_days` must be a positive integer.", call. = FALSE)
  }
  win <- as.integer(window_days)

  if (missing(date_from) || missing(date_to)) {
    stop("`date_from` and `date_to` are required.", call. = FALSE)
  }
  df <- .coerce_alert_date(date_from, "date_from")
  dt <- .coerce_alert_date(date_to,   "date_to")
  if (df > dt) {
    stop("`date_from` must be <= `date_to`.", call. = FALSE)
  }

  win_start <- dt - win + 1L

  # The aggregation uses two pivoted aggregates (one per band) and
  # left-joins them on plot.id. plot.geom_wkt comes from registration
  # (EPSG:4326 per register_monitoring_zone()).
  sql <- sprintf(
    "SELECT p.plot_id  AS plot_id,
            p.geom_wkt AS geom_wkt,
            MAX(op.obs_date) AS last_obs_date,
            AVG(CASE WHEN op.band = 'NDVI'
                      AND op.obs_date >= %s
                     THEN op.value END) AS ndvi_value,
            AVG(CASE WHEN op.band = 'NBR'
                      AND op.obs_date >= %s
                     THEN op.value END) AS nbr_value
       FROM plot p
       LEFT JOIN obs_pixel op
         ON op.plot_id = p.id
        AND op.obs_date BETWEEN %s AND %s
      WHERE p.zone_id = %d
      GROUP BY p.id, p.plot_id, p.geom_wkt
      ORDER BY p.plot_id",
    DBI::dbQuoteLiteral(con, win_start),
    DBI::dbQuoteLiteral(con, win_start),
    DBI::dbQuoteLiteral(con, df),
    DBI::dbQuoteLiteral(con, dt),
    zid
  )

  raw <- tryCatch(
    DBI::dbGetQuery(con, sql),
    error = function(e) {
      stop(sprintf("list_fast_alerts_for_zone() failed: %s",
                   conditionMessage(e)), call. = FALSE)
    }
  )

  if (!nrow(raw)) return(.empty_fast_alerts())

  raw$ndvi_value <- suppressWarnings(as.numeric(raw$ndvi_value))
  raw$nbr_value  <- suppressWarnings(as.numeric(raw$nbr_value))

  # Per-plot ratio against thresholds. NA values map to ratio = Inf so
  # they don't dominate the min() below — only observed bands drive
  # severity.
  r_ndvi <- ifelse(is.na(raw$ndvi_value),
                   Inf, raw$ndvi_value / threshold_ndvi)
  r_nbr  <- ifelse(is.na(raw$nbr_value),
                   Inf, raw$nbr_value  / threshold_nbr)
  r_min  <- pmin(r_ndvi, r_nbr)

  sev <- rep(NA_character_, nrow(raw))
  sev[r_min <  0.5] <- "critical"
  sev[r_min >= 0.5 & r_min < 1.0] <- "warning"
  sev[r_min >= 1.0 & r_min < 1.1] <- "info"

  keep <- !is.na(sev)
  if (!any(keep)) return(.empty_fast_alerts())

  raw <- raw[keep, , drop = FALSE]
  sev <- sev[keep]

  ndvi_drop <- ifelse(!is.na(raw$ndvi_value) &
                        raw$ndvi_value < threshold_ndvi,
                      threshold_ndvi - raw$ndvi_value, NA_real_)
  nbr_drop  <- ifelse(!is.na(raw$nbr_value) &
                        raw$nbr_value  < threshold_nbr,
                      threshold_nbr  - raw$nbr_value, NA_real_)

  geoms <- lapply(raw$geom_wkt, function(wkt) {
    if (is.na(wkt) || !nzchar(wkt)) return(sf::st_point())
    sf::st_as_sfc(wkt, crs = 4326)[[1L]]
  })

  out <- sf::st_sf(
    data.frame(
      plot_id       = as.character(raw$plot_id),
      last_obs_date = as.Date(raw$last_obs_date),
      ndvi_value    = raw$ndvi_value,
      nbr_value     = raw$nbr_value,
      ndvi_drop     = ndvi_drop,
      nbr_drop      = nbr_drop,
      severity      = factor(sev,
                             levels  = c("info", "warning", "critical"),
                             ordered = TRUE),
      stringsAsFactors = FALSE
    ),
    geometry = sf::st_sfc(geoms, crs = 4326),
    crs      = 4326
  )
  out
}


.empty_fast_alerts <- function() {
  sf::st_sf(
    data.frame(
      plot_id       = character(0),
      last_obs_date = as.Date(character(0)),
      ndvi_value    = numeric(0),
      nbr_value     = numeric(0),
      ndvi_drop     = numeric(0),
      nbr_drop      = numeric(0),
      severity      = factor(character(0),
                             levels  = c("info", "warning", "critical"),
                             ordered = TRUE),
      stringsAsFactors = FALSE
    ),
    geometry = sf::st_sfc(crs = 4326),
    crs      = 4326
  )
}


.coerce_alert_date <- function(x, name) {
  if (length(x) != 1L) {
    stop(sprintf("`%s` must be a single Date or YYYY-MM-DD string.", name),
         call. = FALSE)
  }
  if (inherits(x, "Date")) return(x)
  out <- tryCatch(as.Date(x), error = function(e) NA, warning = function(w) NA)
  if (is.na(out)) {
    stop(sprintf("`%s` is not coercible to Date.", name), call. = FALSE)
  }
  out
}
