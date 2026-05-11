#' FORDEAD Post-Processing: Rasters to Alert Clusters (E6.c.2, spec 008)
#'
#' @description
#' Turns the GeoTIFF outputs of [run_fordead_dieback()] into a sf
#' POINT layer of cluster centroids and persists them into the
#' `alert` table. The flow is:
#'
#' \enumerate{
#'   \item `state.tif` (per-pixel anomaly class, 0–4) is reclassified
#'     into the canonical [`FORDEAD_CLASSES`] vocabulary.
#'   \item Connected pixel patches are extracted (`terra::patches`,
#'     8-neighbour by default) per class. Patches smaller than
#'     `min_pixels` are dropped.
#'   \item Each cluster yields a centroid enriched with
#'     `confidence_class`, `stress_index`, `trigger_date`,
#'     `n_pixels`, `area_m2`.
#' }
#'
#' Confidence weights are calibrated on the ONF/DSF FORDEAD
#' validation report (Bernard & Doridant 2024) — see
#' [`FORDEAD_CONFIDENCE_WEIGHTS`] and ADR-013 §G5.
#'
#' @name fordead_postprocess
NULL


#' Canonical ordered FORDEAD anomaly classes
#'
#' Vector of length 5 ordered from healthy to bare soil. Index `i`
#' (1-based) is the class corresponding to the integer code `i - 1`
#' in `state.tif`.
#'
#' @export
FORDEAD_CLASSES <- c(
  "0-hors-anomalie",
  "1-faible",
  "2-moyenne",
  "3-forte",
  "4-sol-nu"
)


#' Confidence weights from the ONF/DSF FORDEAD validation report
#'
#' Per-class trustworthiness coefficients used to weight the R5
#' dépérissement indicator (spec 008 §4.4 / G5). Sourced from:
#'
#' Bernard C, Doridant JB (2024) — *Méthode FORDEAD : analyse de la
#' validité des détections d'anomalies de végétation par contrôle
#' terrain*. ONF/DSF, mai 2024.
#'
#' Field validation taught us that classes 1 and 2 carry too many
#' false positives (50 % and 1/3 respectively) to be trusted alone;
#' classes 3 and 4 are usable.
#'
#' @export
FORDEAD_CONFIDENCE_WEIGHTS <- c(
  "1-faible"  = 0.10,
  "2-moyenne" = 0.30,
  "3-forte"   = 0.82,
  "4-sol-nu"  = 0.70
)


#' Reclassify a raw FORDEAD `state.tif` into the canonical class layer
#'
#' Maps integer codes 0–4 onto factor levels in [`FORDEAD_CLASSES`].
#' Unknown values become NA. Non-anomaly pixels (code `0`) are kept
#' as the first level so that downstream callers can choose to mask
#' them out explicitly.
#'
#' @param state_raster A `terra::SpatRaster` whose values are
#'   integer codes in `0..4`.
#'
#' @return A `terra::SpatRaster` of integer codes in `0..4` (with
#'   the value attribute table set to [`FORDEAD_CLASSES`]). NA for
#'   any pixel outside `0..4`.
#'
#' @keywords internal
.classify_pixels_to_classes <- function(state_raster) {
  if (!inherits(state_raster, "SpatRaster")) {
    cli::cli_abort("{.arg state_raster} must be a {.cls SpatRaster}.")
  }
  vals <- terra::values(state_raster)
  vals[!is.na(vals) & (vals < 0 | vals > 4)] <- NA
  out <- terra::setValues(state_raster, vals)
  names(out) <- "fordead_class"
  out
}


#' Cluster anomalous pixels into connected patches per class
#'
#' Splits the reclassified raster into one binary raster per
#' anomaly class (1..4) and runs `terra::patches()` 8-neighbour by
#' default. Patches smaller than `min_pixels` are dropped (G1 — we
#' don't trust isolated pixels).
#'
#' @param class_raster A `terra::SpatRaster` returned by
#'   [.classify_pixels_to_classes()].
#' @param min_pixels Integer. Minimum patch size (in pixels) to be
#'   kept. Default 5.
#' @param connectivity Integer 4 or 8. Default 8.
#'
#' @return A list of `SpatRaster`s, one per anomaly class
#'   (`"1-faible"`, `"2-moyenne"`, `"3-forte"`, `"4-sol-nu"`). Each
#'   raster has integer patch IDs (1..N_class) and NA elsewhere.
#'
#' @keywords internal
.cluster_anomaly_pixels <- function(class_raster,
                                    min_pixels   = 5L,
                                    connectivity = 8L) {
  if (!inherits(class_raster, "SpatRaster")) {
    cli::cli_abort("{.arg class_raster} must be a {.cls SpatRaster}.")
  }
  if (!connectivity %in% c(4L, 8L)) {
    cli::cli_abort("{.arg connectivity} must be 4 or 8.")
  }

  out <- list()
  for (code in 1:4) {
    cls <- FORDEAD_CLASSES[code + 1L]
    mask <- terra::ifel(class_raster == code, 1L, NA)
    if (all(is.na(terra::values(mask)))) {
      out[[cls]] <- mask
      next
    }
    patches <- terra::patches(mask, directions = connectivity,
                              zeroAsNA = TRUE)
    # Drop patches smaller than min_pixels (operate on the value
    # vector — `%in%` is not defined on SpatRaster).
    freq <- terra::freq(patches)
    freq <- freq[!is.na(freq$value), , drop = FALSE]
    if (nrow(freq) > 0L) {
      tiny <- freq$value[freq$count < min_pixels]
      if (length(tiny)) {
        v <- terra::values(patches)
        v[!is.na(v) & v %in% tiny] <- NA
        patches <- terra::setValues(patches, v)
      }
    }
    out[[cls]] <- patches
  }
  out
}


#' Convert per-class patch rasters into an enriched centroid `sf`
#'
#' Replaces each patch by its centroid (in the raster's CRS),
#' attaching the per-cluster mean stress index and the per-cluster
#' minimum first-dieback date (i.e. earliest detected anomaly).
#'
#' @param clusters A list returned by [.cluster_anomaly_pixels()].
#' @param stress_index_raster `SpatRaster` of FORDEAD stress index.
#'   May be `NULL` (then the column comes back as NA).
#' @param first_dieback_date_raster `SpatRaster` of first-dieback
#'   date, expressed as days since `1970-01-01` (FORDEAD default).
#'   May be `NULL`.
#'
#' @return An sf POINT with columns `confidence_class`,
#'   `stress_index`, `trigger_date`, `n_pixels`, `area_m2`,
#'   `cluster_id`. CRS inherited from `clusters`. Empty sf when no
#'   cluster passes the size threshold.
#'
#' @keywords internal
.cluster_to_centroids <- function(clusters,
                                  stress_index_raster       = NULL,
                                  first_dieback_date_raster = NULL) {
  empty <- sf::st_sf(
    confidence_class = character(0),
    stress_index     = numeric(0),
    trigger_date     = as.Date(character(0)),
    n_pixels         = integer(0),
    area_m2          = numeric(0),
    cluster_id       = integer(0),
    geometry         = sf::st_sfc(crs = sf::st_crs(NA))
  )
  if (!length(clusters)) return(empty)

  rows <- list()
  for (cls in names(clusters)) {
    r <- clusters[[cls]]
    if (is.null(r) || all(is.na(terra::values(r)))) next

    poly <- sf::st_as_sf(terra::as.polygons(r, dissolve = TRUE))
    if (!nrow(poly)) next
    names(poly)[1] <- "cluster_id"
    poly$cluster_id <- as.integer(poly$cluster_id)

    pix_area <- prod(terra::res(r))
    counts   <- terra::freq(r)
    counts   <- counts[!is.na(counts$value), , drop = FALSE]
    n_by_id  <- stats::setNames(as.integer(counts$count),
                                as.character(counts$value))
    poly$n_pixels <- n_by_id[as.character(poly$cluster_id)]
    poly$area_m2  <- poly$n_pixels * pix_area

    # Per-cluster summaries from the stress / date rasters. We zonal
    # over the cluster raster `r` (whose values are cluster IDs).
    stress_by_id <- if (!is.null(stress_index_raster)) {
      z <- terra::zonal(stress_index_raster, r, fun = "mean", na.rm = TRUE)
      stats::setNames(as.numeric(z[[2]]), as.character(z[[1]]))
    } else {
      stats::setNames(rep(NA_real_, length(n_by_id)), names(n_by_id))
    }
    date_by_id <- if (!is.null(first_dieback_date_raster)) {
      z <- terra::zonal(first_dieback_date_raster, r, fun = "min", na.rm = TRUE)
      stats::setNames(as.numeric(z[[2]]), as.character(z[[1]]))
    } else {
      stats::setNames(rep(NA_real_, length(n_by_id)), names(n_by_id))
    }
    poly$stress_index <- stress_by_id[as.character(poly$cluster_id)]
    poly$trigger_date <- as.Date(date_by_id[as.character(poly$cluster_id)],
                                 origin = "1970-01-01")
    poly$confidence_class <- cls

    centroids <- sf::st_centroid(sf::st_geometry(poly))
    poly_pt <- sf::st_sf(
      confidence_class = poly$confidence_class,
      stress_index     = poly$stress_index,
      trigger_date     = poly$trigger_date,
      n_pixels         = poly$n_pixels,
      area_m2          = poly$area_m2,
      cluster_id       = poly$cluster_id,
      geometry         = centroids
    )
    rows[[cls]] <- poly_pt
  }
  if (!length(rows)) return(empty)
  do.call(rbind, rows)
}


#' Top-level helper: turn FORDEAD raster outputs into an `alerts_sf`
#'
#' Combines [.classify_pixels_to_classes()],
#' [.cluster_anomaly_pixels()] and [.cluster_to_centroids()] into a
#' single call. Used by [run_fordead_dieback()] and by tests.
#'
#' @param rasters Named list with character paths or `SpatRaster`
#'   objects under `state`, `stress_index`, `first_dieback_date`.
#' @param min_pixels Integer. Minimum patch size. Default 5.
#' @param connectivity Integer 4 or 8. Default 8.
#'
#' @return An sf POINT (possibly empty).
#' @keywords internal
.postprocess_fordead_rasters <- function(rasters,
                                         min_pixels   = 5L,
                                         connectivity = 8L) {
  if (!is.list(rasters) || is.null(rasters$state)) {
    cli::cli_abort("{.arg rasters$state} is required.")
  }
  load_one <- function(x) {
    if (is.null(x) || (is.character(x) && (length(x) != 1L || !file.exists(x)))) {
      return(NULL)
    }
    if (inherits(x, "SpatRaster")) x else terra::rast(x)
  }
  st <- load_one(rasters$state)
  if (is.null(st)) cli::cli_abort("Cannot load {.arg rasters$state}.")
  si <- load_one(rasters$stress_index)
  fd <- load_one(rasters$first_dieback_date)

  cl <- .classify_pixels_to_classes(st)
  patches <- .cluster_anomaly_pixels(cl, min_pixels = min_pixels,
                                     connectivity = connectivity)
  .cluster_to_centroids(patches,
                        stress_index_raster       = si,
                        first_dieback_date_raster = fd)
}


#' Persist FORDEAD alert centroids in the `alert` table
#'
#' Bulk-inserts the rows of `alerts_sf` as
#' `alert_type = 'fordead_dieback'` records, with
#' `confidence_class` and `stress_index` populated. Idempotent
#' thanks to the existing UNIQUE `(plot_id, alert_type,
#' trigger_date)` constraint and `ON CONFLICT DO NOTHING`.
#'
#' Each centroid is snapped to the nearest plot of the zone (we do
#' not invent a new `plot` row per cluster — the plot model is the
#' grain of all existing alerts). Centroids with no plot within
#' `radius_m` are skipped with a warning.
#'
#' @param con A `DBIConnection`.
#' @param alerts_sf An sf POINT returned by
#'   [.postprocess_fordead_rasters()].
#' @param zone_id Integer. Target monitoring zone.
#' @param radius_m Numeric. Maximum allowed centroid → plot
#'   distance, in metres. Default 200.
#'
#' @return Number of rows inserted (integer).
#' @keywords internal
.insert_fordead_alerts <- function(con, alerts_sf, zone_id,
                                   radius_m = 200) {
  .assert_db_pkgs()
  if (!inherits(alerts_sf, "sf") || !nrow(alerts_sf)) return(0L)

  plots <- DBI::dbGetQuery(con,
    "SELECT id, plot_id, geom_wkt FROM plot WHERE zone_id = $1",
    params = list(as.integer(zone_id)))
  if (!nrow(plots)) {
    cli::cli_warn("Zone {zone_id} has no registered plots; skipping FORDEAD alert insertion.")
    return(0L)
  }
  geoms_plot <- lapply(plots$geom_wkt, sf::st_as_sfc, crs = 4326)
  plots_sf <- sf::st_sf(
    plot_db_id = plots$id,
    geometry   = do.call(c, geoms_plot)
  )
  plots_sf <- sf::st_transform(plots_sf, 2154)

  if (sf::st_crs(alerts_sf) != sf::st_crs(2154)) {
    alerts_sf <- sf::st_transform(alerts_sf, 2154)
  }

  nearest <- sf::st_nearest_feature(alerts_sf, plots_sf)
  dist_m  <- sf::st_distance(alerts_sf, plots_sf[nearest, , drop = FALSE],
                             by_element = TRUE)
  dist_m  <- as.numeric(dist_m)
  keep    <- dist_m <= radius_m
  if (!any(keep)) {
    cli::cli_warn("All FORDEAD centroids are farther than {radius_m} m from any plot of zone {zone_id}.")
    return(0L)
  }
  if (any(!keep)) {
    cli::cli_alert_warning(
      "Skipping {sum(!keep)} FORDEAD centroid{?s} farther than {radius_m} m from any plot.")
  }

  staging <- data.frame(
    plot_id          = plots_sf$plot_db_id[nearest][keep],
    alert_type       = "fordead_dieback",
    trigger_date     = alerts_sf$trigger_date[keep],
    value_before     = NA_real_,
    value_after      = NA_real_,
    delta            = NA_real_,
    confidence_class = alerts_sf$confidence_class[keep],
    stress_index     = alerts_sf$stress_index[keep],
    stringsAsFactors = FALSE
  )
  staging <- staging[!is.na(staging$trigger_date), , drop = FALSE]
  if (!nrow(staging)) return(0L)

  is_duckdb <- inherits(con, "duckdb_connection")
  inserted <- DBI::dbWithTransaction(con, {
    if (is_duckdb) {
      # DuckDB has no `ON COMMIT DROP`; drop any leftover from a
      # previous failed run, create, use, and drop manually.
      DBI::dbExecute(con, "DROP TABLE IF EXISTS tmp_fordead_alert_staging")
      DBI::dbExecute(con,
        "CREATE TEMP TABLE tmp_fordead_alert_staging (
           plot_id          INTEGER,
           alert_type       TEXT,
           trigger_date     DATE,
           value_before     DOUBLE,
           value_after      DOUBLE,
           delta            DOUBLE,
           confidence_class TEXT,
           stress_index     DOUBLE
         )")
    } else {
      DBI::dbExecute(con,
        "CREATE TEMP TABLE tmp_fordead_alert_staging (
           plot_id          INTEGER,
           alert_type       TEXT,
           trigger_date     DATE,
           value_before     DOUBLE PRECISION,
           value_after      DOUBLE PRECISION,
           delta            DOUBLE PRECISION,
           confidence_class TEXT,
           stress_index     DOUBLE PRECISION
         ) ON COMMIT DROP")
    }
    DBI::dbAppendTable(con, "tmp_fordead_alert_staging", staging)
    n <- DBI::dbExecute(con,
      "INSERT INTO alert (plot_id, alert_type, trigger_date,
                          value_before, value_after, delta,
                          confidence_class, stress_index)
       SELECT plot_id, alert_type, trigger_date,
              value_before, value_after, delta,
              confidence_class, stress_index
         FROM tmp_fordead_alert_staging
       ON CONFLICT (plot_id, alert_type, trigger_date) DO NOTHING")
    if (is_duckdb) {
      DBI::dbExecute(con, "DROP TABLE tmp_fordead_alert_staging")
    }
    as.integer(n)
  })
  inserted
}


#' Tag each alert with the disturbance type it most likely reflects (G2)
#'
#' Cross-references FORDEAD alerts with the rolling-window NDVI/NBR
#' alerts on the same plot. Adds a `disturbance_type` column:
#'
#' \itemize{
#'   \item `"mechanical"` — FORDEAD alert with a `ndvi_drop` /
#'     `nbr_drop` companion within `± window_days`. Likely a
#'     clear-cut, chablis or fire scar.
#'   \item `"progressive"` — Lone FORDEAD alert. Likely
#'     scolyte / drought-driven dieback.
#'   \item `"recent_event"` — Lone NDVI/NBR drop without any
#'     FORDEAD echo. Recent perturbation, no confirmed dieback.
#'   \item `NA_character_` — NDVI/NBR drop already paired with a
#'     FORDEAD alert (the FORDEAD row carries the verdict).
#' }
#'
#' Computed in pure R: cost is O(n²) on a few thousand alerts max,
#' so we deliberately don't push it to SQL.
#'
#' @param alerts_df A data frame with columns `plot_id`,
#'   `alert_type`, `trigger_date`. The `alerts_sf` returned by
#'   [list_alerts()] works as-is.
#' @param window_days Integer. Half-width of the join window in
#'   days. Default 30.
#'
#' @return The input enriched with a `disturbance_type` column.
#'
#' @export
classify_disturbance <- function(alerts_df, window_days = 30L) {
  if (is.null(alerts_df) || !nrow(alerts_df)) {
    alerts_df$disturbance_type <- character(0)
    return(alerts_df)
  }
  required <- c("plot_id", "alert_type", "trigger_date")
  missing  <- setdiff(required, names(alerts_df))
  if (length(missing)) {
    cli::cli_abort("{.arg alerts_df} is missing column{?s}: {.val {missing}}.")
  }
  win <- as.integer(window_days)
  if (is.na(win) || win < 0L) {
    cli::cli_abort("{.arg window_days} must be a non-negative integer.")
  }

  td <- as.Date(alerts_df$trigger_date)
  pid <- alerts_df$plot_id
  at  <- alerts_df$alert_type

  out <- vapply(seq_len(nrow(alerts_df)), function(i) {
    same_plot <- pid == pid[i]
    in_window <- abs(as.numeric(td - td[i])) <= win
    candidates <- same_plot & in_window
    candidates[i] <- FALSE  # don't pair with self

    if (identical(at[i], "fordead_dieback")) {
      if (any(candidates & at %in% c("ndvi_drop", "nbr_drop"))) "mechanical"
      else "progressive"
    } else if (at[i] %in% c("ndvi_drop", "nbr_drop")) {
      if (any(candidates & at == "fordead_dieback")) NA_character_
      else "recent_event"
    } else NA_character_
  }, character(1))

  alerts_df$disturbance_type <- out
  alerts_df
}


#' List alerts of a zone with G1 default filtering
#'
#' Default behaviour applies garde-fou G1: returns only the
#' trustworthy classes 3-forte and 4-sol-nu (rolling-window alerts
#' have no `confidence_class`, so they pass through).
#'
#' Pass `classes = NULL` to disable the class filter (useful for
#' the UI when the user explicitly opts in to lower-confidence
#' alerts, with a banner — the UI is in charge of warning the
#' user).
#'
#' @param con A `DBIConnection`.
#' @param zone_id Integer. Monitoring zone.
#' @param classes Character vector of `confidence_class` values to
#'   include. Default `c("3-forte", "4-sol-nu")`. Use `NULL` to
#'   include everything (including alerts without a class, i.e. the
#'   rolling-window ones).
#' @param validation_status Character vector or `NULL`. Filter on
#'   `alert.validation_status`. `NULL` (default) returns every
#'   status.
#' @param period A length-2 Date / character vector or `NULL`.
#'   Filter on `trigger_date`. `NULL` (default) returns every date.
#'
#' @return An sf POINT layer (CRS WGS84) ready to be drawn on a
#'   leaflet map. Empty sf when no alert matches.
#'
#' @export
list_alerts <- function(con, zone_id,
                        classes           = c("3-forte", "4-sol-nu"),
                        validation_status = NULL,
                        period            = NULL) {
  .assert_db_pkgs()

  where <- c("p.zone_id = $1")
  pars  <- list(as.integer(zone_id))
  i <- 1L
  add_param <- function(values) {
    i <<- i + 1L
    pars[[length(pars) + 1L]] <<- values
    sprintf("$%d", i)
  }
  # Generate a portable `IN ($n, $n+1, ...)` clause and append one
  # parameter per value. Replaces the previous PG-only
  # `ANY($n::text[])` form which relied on a server-side cast — DuckDB
  # has no `text[]` type and parameter-binds the array literal as a
  # scalar string, producing an empty result set instead of erroring.
  add_in_clause <- function(values) {
    vals <- as.character(values)
    placeholders <- vapply(vals, add_param, character(1))
    sprintf("(%s)", paste(placeholders, collapse = ", "))
  }
  if (!is.null(classes)) {
    where <- c(where,
               sprintf("(a.confidence_class IS NULL OR a.confidence_class IN %s)",
                       add_in_clause(classes)))
  }
  if (!is.null(validation_status)) {
    where <- c(where,
               sprintf("a.validation_status IN %s",
                       add_in_clause(validation_status)))
  }
  if (!is.null(period)) {
    if (length(period) != 2L) {
      cli::cli_abort("{.arg period} must be a length-2 vector.")
    }
    p <- as.Date(period)
    where <- c(where,
               sprintf("a.trigger_date BETWEEN %s AND %s",
                       add_param(format(p[1])),
                       add_param(format(p[2]))))
  }

  sql <- sprintf(
    "SELECT a.id, a.plot_id, p.plot_id AS plot_label,
            a.alert_type, a.trigger_date,
            a.value_before, a.value_after, a.delta,
            a.confidence_class, a.stress_index,
            a.validation_status, a.validation_cause,
            a.validated_by, a.validated_at,
            p.geom_wkt
       FROM alert a
       JOIN plot p ON p.id = a.plot_id
      WHERE %s
      ORDER BY a.trigger_date DESC, a.plot_id",
    paste(where, collapse = " AND ")
  )
  rs <- DBI::dbGetQuery(con, sql, params = pars)

  if (!nrow(rs)) {
    return(sf::st_sf(
      data.frame(
        id                = integer(0),
        plot_id           = integer(0),
        plot_label        = character(0),
        alert_type        = character(0),
        trigger_date      = as.Date(character(0)),
        value_before      = numeric(0),
        value_after       = numeric(0),
        delta             = numeric(0),
        confidence_class  = character(0),
        stress_index      = numeric(0),
        validation_status = character(0),
        validation_cause  = character(0),
        validated_by      = character(0),
        validated_at      = as.POSIXct(character(0), tz = "UTC")
      ),
      geometry = sf::st_sfc(crs = 4326)
    ))
  }
  geoms <- lapply(rs$geom_wkt, sf::st_as_sfc, crs = 4326)
  geom_sfc <- do.call(c, geoms)
  rs$geom_wkt <- NULL
  sf::st_sf(rs, geometry = geom_sfc, crs = 4326)
}
