#' Read pixel observations for a monitoring zone
#'
#' @description
#' \strong{Deprecated since v0.58.0; scheduled for removal in v0.60.0.}
#' The `obs_pixel` table was dropped in v0.58.0 (the FAST diagnostic is
#' now a pure per-pixel computation over the COG band cache), so this
#' reader has no backing table and will fail at the SQL stage. Use the
#' per-pixel COG cache via [build_index_stack()] or
#' [extract_pixel_timeseries()] instead.
#'
#' Returns the per-plot, per-band, per-date Sentinel-2 reflectance / index
#' values stored in the `obs_pixel` hypertable, with the plot identifier
#' surfaced as the human-readable `plot.plot_id` (TEXT) — not the internal
#' `plot.id` (INTEGER FK) — so that downstream consumers (Shiny, Quarto,
#' GeoPackage exports) can refer to plots by the code the user knows.
#'
#' Filters are all optional and AND-combined. Passing `NULL` for a filter
#' means \emph{no filter on that dimension}. The result is sorted
#' deterministically by `(plot_id, obs_date, band)` so callers that hash
#' or diff the table get stable output.
#'
#' This function was the read-side counterpart of the per-plot write
#' path that [ingest_sentinel2_timeseries()] used before v0.58.0.
#' Exposing it as part of the `nemeton` API kept the SQL out of caller
#' code (cf. `nemetonshiny` rule §1: no business logic in the app).
#'
#' @param con A `DBI` connection to the `nemeton` schema (PostgreSQL +
#'   TimescaleDB or SQLite). The connection must already have the
#'   `monitoring_zone` / `plot` / `obs_pixel` tables (cf. migration
#'   `0001_init.sql`).
#' @param zone_id Integer. The `monitoring_zone.id` to read from.
#'   Returned by [register_monitoring_zone()].
#' @param plot_ids Optional character vector of human plot identifiers
#'   (`plot.plot_id`, e.g. `c("P001", "P002")`). `NULL` returns every
#'   plot of the zone. Plots that don't exist are silently ignored.
#' @param bands Optional character vector restricting the band filter
#'   (e.g. `c("NDVI", "NBR")` or `c("B04", "B08")`). `NULL` returns
#'   every band present.
#' @param date_from,date_to Optional `Date` (or coercible via [as.Date()])
#'   bounds, both inclusive. `NULL` means no lower / upper bound.
#'
#' @return A `data.frame` with columns `plot_id` (character),
#'   `obs_date` (`Date`), `band` (character), `value` (numeric),
#'   `cloud_pct` (numeric), `source` (character), `scene_id` (character).
#'   Empty (`nrow = 0`) when the zone has no matching observations, but
#'   with the right column schema so callers can `rbind()` /
#'   `dplyr::bind_rows()` safely.
#'
#' @section SQL injection:
#' All filter values are quoted via [DBI::dbQuoteLiteral()] before being
#' interpolated into the query. No user input reaches the SQL string
#' unescaped.
#'
#' @examples
#' \dontrun{
#'   con <- db_connect(Sys.getenv("NEMETON_DB_URL"))
#'   on.exit(db_disconnect(con), add = TRUE)
#'
#'   # Every observation for zone 1
#'   df <- read_obs_pixel(con, zone_id = 1L)
#'
#'   # Just NDVI / NBR for two plots over a 6-month window
#'   df <- read_obs_pixel(
#'     con, zone_id = 1L,
#'     plot_ids = c("P001", "P002"),
#'     bands     = c("NDVI", "NBR"),
#'     date_from = "2025-01-01",
#'     date_to   = "2025-06-30"
#'   )
#' }
#'
#' @section UGF zone filter (spec 016):
#' The function already filters by `plot.zone_id = zone_id`, which
#' is **the de-facto UGF membership filter** since plots are
#' registered inside the UGF polygon by
#' [register_monitoring_zone()]. No spatial `ST_Within` post-filter
#' is added — it would be redundant (and would require PostGIS
#' geometry casts that wouldn't survive on the SQLite backend). If a
#' plot has somehow drifted out of its zone polygon (data integrity
#' issue), that is reported by [register_monitoring_zone()]'s
#' validation, not at read time.
#'
#' @seealso [ingest_sentinel2_timeseries()] for the write path,
#'   [register_monitoring_zone()] to obtain `zone_id`,
#'   [extract_pixel_timeseries()] for the per-pixel (not per-plot)
#'   time series counterpart.
#' @keywords internal
#' @export
read_obs_pixel <- function(con,
                           zone_id,
                           plot_ids  = NULL,
                           bands     = NULL,
                           date_from = NULL,
                           date_to   = NULL) {
  cli::cli_warn(paste(
    "{.fn read_obs_pixel} is deprecated and will be removed in v0.60.0 ;",
    "use the per-pixel COG cache via {.fn build_index_stack} or",
    "{.fn extract_pixel_timeseries} instead."
  ))
  if (!inherits(con, "DBIConnection")) {
    stop("`con` must be a DBI connection.", call. = FALSE)
  }
  if (length(zone_id) != 1L || is.na(zone_id) ||
      !is.numeric(zone_id) && !is.integer(zone_id)) {
    # Accept numerics that round-trip to integer (e.g. 1, 2.0)
    if (length(zone_id) != 1L || is.na(zone_id) ||
        !is.finite(suppressWarnings(as.numeric(zone_id)))) {
      stop("`zone_id` must be a single non-NA integer.", call. = FALSE)
    }
  }
  zid <- as.integer(zone_id)

  if (!is.null(plot_ids)) {
    if (!is.character(plot_ids) && !is.numeric(plot_ids)) {
      stop("`plot_ids` must be a character vector or NULL.",
           call. = FALSE)
    }
    plot_ids <- as.character(plot_ids)
    plot_ids <- plot_ids[!is.na(plot_ids) & nzchar(plot_ids)]
  }
  if (!is.null(bands)) {
    if (!is.character(bands)) {
      stop("`bands` must be a character vector or NULL.", call. = FALSE)
    }
    bands <- bands[!is.na(bands) & nzchar(bands)]
  }
  date_from <- .coerce_obs_date(date_from, "date_from")
  date_to   <- .coerce_obs_date(date_to,   "date_to")
  if (!is.null(date_from) && !is.null(date_to) && date_from > date_to) {
    stop("`date_from` must be <= `date_to`.", call. = FALSE)
  }

  # Short-circuit: empty filter vectors ↔ "no rows can match" (caller
  # asked explicitly for an empty set, e.g. plot_ids = character(0)).
  if (!is.null(plot_ids) && length(plot_ids) == 0L) {
    return(.empty_obs_pixel())
  }
  if (!is.null(bands) && length(bands) == 0L) {
    return(.empty_obs_pixel())
  }

  where <- c(sprintf("p.zone_id = %d", zid))
  if (!is.null(plot_ids)) {
    where <- c(where, sprintf(
      "p.plot_id IN (%s)",
      paste(DBI::dbQuoteLiteral(con, plot_ids), collapse = ", ")
    ))
  }
  if (!is.null(bands)) {
    where <- c(where, sprintf(
      "op.band IN (%s)",
      paste(DBI::dbQuoteLiteral(con, bands), collapse = ", ")
    ))
  }
  if (!is.null(date_from)) {
    where <- c(where, sprintf(
      "op.obs_date >= %s",
      DBI::dbQuoteLiteral(con, date_from)
    ))
  }
  if (!is.null(date_to)) {
    where <- c(where, sprintf(
      "op.obs_date <= %s",
      DBI::dbQuoteLiteral(con, date_to)
    ))
  }

  sql <- sprintf(
    "SELECT p.plot_id   AS plot_id,
            op.obs_date AS obs_date,
            op.band     AS band,
            op.value    AS value,
            op.cloud_pct AS cloud_pct,
            op.source   AS source,
            op.scene_id AS scene_id
       FROM obs_pixel op
       JOIN plot p ON p.id = op.plot_id
      WHERE %s
      ORDER BY p.plot_id, op.obs_date, op.band",
    paste(where, collapse = " AND ")
  )

  out <- tryCatch(
    DBI::dbGetQuery(con, sql),
    error = function(e) {
      stop(sprintf("read_obs_pixel() failed: %s", conditionMessage(e)),
           call. = FALSE)
    }
  )
  if (!nrow(out)) return(.empty_obs_pixel())

  # Force consistent column types so downstream code (Shiny reactive,
  # plotly, GeoPackage export) doesn't have to second-guess what the
  # backend returned.
  out$plot_id   <- as.character(out$plot_id)
  out$obs_date  <- as.Date(out$obs_date)
  out$band      <- as.character(out$band)
  out$value     <- as.numeric(out$value)
  out$cloud_pct <- as.numeric(out$cloud_pct)
  out$source    <- as.character(out$source)
  out$scene_id  <- as.character(out$scene_id)
  out
}

.empty_obs_pixel <- function() {
  data.frame(
    plot_id   = character(0),
    obs_date  = as.Date(character(0)),
    band      = character(0),
    value     = numeric(0),
    cloud_pct = numeric(0),
    source    = character(0),
    scene_id  = character(0),
    stringsAsFactors = FALSE
  )
}

.coerce_obs_date <- function(x, name) {
  if (is.null(x)) return(NULL)
  if (length(x) != 1L) {
    stop(sprintf("`%s` must be a single Date or NULL.", name),
         call. = FALSE)
  }
  if (inherits(x, "Date")) return(x)
  out <- tryCatch(as.Date(x), error = function(e) NA)
  if (is.na(out)) {
    stop(sprintf("`%s` is not coercible to Date.", name), call. = FALSE)
  }
  out
}
