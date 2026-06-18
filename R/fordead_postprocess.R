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
#' Since v0.23.0 (fordead 2.x migration — spec 008 §12), the
#' `state` element is no longer the legacy `DataAnomalies/state.tif`
#' integer raster but a `SpatRaster` built in-memory by
#' [.fordead_2x_status_to_classes()] from the 2.x layers
#' (`ANOMALY_CONFIRMED`, `CONSECUTIVE_DETECTIONS`, `STOP_CONFIRMED`).
#' The accepted input shape (named list with 0-4 integer codes in
#' `state`) is unchanged so this helper itself didn't need a rewrite.
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


#' Persist health-diagnostic alert centroids in the `alert` table
#'
#' Shared implementation behind [.insert_fordead_alerts()] and
#' [.insert_reconfort_alerts()] since spec 008 §15 Phase B. The alert is a
#' **pixel/cluster entity** : it carries its own centroid geometry
#' (`geom_wkt`, EPSG:4326 — D-B2) and is attached to the monitoring zone
#' (`zone_id`), never to a plot. `plot_id` is left `NULL`.
#'
#' Idempotence across runs uses the **replace-by-window** strategy (D-B1) :
#' the run's monitoring window is deleted for this `(zone_id, alert_type)`
#' before inserting — `cluster_id` is per-run and not stable, so the UNIQUE
#' `(zone_id, alert_type, trigger_date, cluster_id)` constraint is only an
#' intra-run guard. `cluster_id` is renumbered to a per-insert sequence so
#' it cannot collide within a run (the per-class ids from
#' [.cluster_to_centroids()] are not unique across classes).
#'
#' @param con A `DBIConnection`.
#' @param alerts_sf An sf POINT (centroids) with columns `trigger_date`,
#'   `confidence_class`, `stress_index` and, when available, `n_pixels`,
#'   `area_m2`. CRS assumed EPSG:2154 when absent.
#' @param zone_id Integer. Target monitoring zone.
#' @param alert_type Character. `"fordead_dieback"` or
#'   `"reconfort_dieback"`.
#' @param monitoring_window Optional length-2 Date / character — the run's
#'   monitoring window for the replace-by-window delete. When `NULL`, the
#'   range of the staged `trigger_date`s is used.
#'
#' @return Number of rows inserted (integer).
#' @keywords internal
.insert_health_alerts <- function(con, alerts_sf, zone_id, alert_type,
                                  monitoring_window = NULL) {
  .assert_db_pkgs()
  if (!inherits(alerts_sf, "sf") || !nrow(alerts_sf)) return(0L)
  zid <- as.integer(zone_id)

  # Centroïde en EPSG:4326 (D-B2), cohérent avec plot.geom_wkt /
  # monitoring_zone.zone_wkt. Les centroïdes arrivent dans le CRS du
  # masque (2154) ; on reprojette systématiquement.
  if (is.na(sf::st_crs(alerts_sf))) {
    cli::cli_warn("{.arg alerts_sf} has no CRS; assuming EPSG:2154.")
    sf::st_crs(alerts_sf) <- 2154
  }
  alerts_sf <- sf::st_transform(alerts_sf, 4326)
  geom_wkt  <- sf::st_as_text(sf::st_geometry(alerts_sf))

  col <- function(nm) if (nm %in% names(alerts_sf)) alerts_sf[[nm]] else NA
  staging <- data.frame(
    zone_id          = zid,
    plot_id          = NA_integer_,
    alert_type       = alert_type,
    # trigger_date en TEXTE 'YYYY-MM-DD' : portable PG (cast date) /
    # SQLite (comparaisons texte fiables pour le BETWEEN ci-dessous).
    trigger_date     = format(as.Date(alerts_sf$trigger_date)),
    geom_wkt         = geom_wkt,
    n_pixels         = suppressWarnings(as.integer(col("n_pixels"))),
    area_m2          = suppressWarnings(as.numeric(col("area_m2"))),
    cluster_id       = NA_integer_,
    confidence_class = as.character(col("confidence_class")),
    stress_index     = suppressWarnings(as.numeric(col("stress_index"))),
    value_before     = NA_real_,
    value_after      = NA_real_,
    delta            = NA_real_,
    stringsAsFactors = FALSE
  )

  # trigger_date NA → ligne non insérable (colonne de la clé UNIQUE et
  # NOT NULL). On la retire avec un avertissement explicite : un run qui
  # détecte du dépérissement mais rapporte « 0 alerte » a déjà masqué un
  # vrai bug (date de première anomalie non dérivée).
  keep_dt   <- !is.na(staging$trigger_date) & nzchar(staging$trigger_date) &
               staging$trigger_date != "NA"
  n_dropped <- sum(!keep_dt)
  staging   <- staging[keep_dt, , drop = FALSE]
  if (n_dropped > 0L) {
    cli::cli_warn(c(
      "Dropped {n_dropped} {alert_type} alert{?s} with a missing {.field trigger_date}.",
      i = "Usual cause: the first-anomaly date raster could not be derived."))
  }
  if (!nrow(staging)) return(0L)

  # cluster_id = séquence intra-insert → unicité garantie de la clé
  # (zone_id, alert_type, trigger_date, cluster_id) au sein du run.
  staging$cluster_id <- seq_len(nrow(staging))

  # Fenêtre de remplacement (D-B1) : par défaut l'amplitude des
  # trigger_date du run.
  win <- if (!is.null(monitoring_window) && length(monitoring_window) == 2L &&
             all(!is.na(monitoring_window))) {
    as.Date(monitoring_window)
  } else {
    range(as.Date(staging$trigger_date))
  }

  inserted <- DBI::dbWithTransaction(con, {
    # Replace-by-window : purge la fenêtre du run avant ré-insertion.
    # Garantit l'idempotence inter-runs (cluster_id non stable).
    .db_execute(con,
      "DELETE FROM alert WHERE zone_id = $1 AND alert_type = $2
         AND trigger_date BETWEEN $3 AND $4",
      params = list(zid, alert_type, format(win[1]), format(win[2])))
    # Insertion directe : après le DELETE et avec cluster_id séquentiel,
    # aucun conflit possible → pas besoin de table de staging temporaire
    # ni de `ON CONFLICT` (et on évite les écueils de grammaire SQLite).
    DBI::dbAppendTable(con, "alert", staging)
    nrow(staging)
  })
  as.integer(inserted)
}


#' Persist FORDEAD alert centroids in the `alert` table
#'
#' Thin wrapper over [.insert_health_alerts()] with
#' `alert_type = "fordead_dieback"`. Pixel/cluster entity, no plot
#' snapping (spec 008 §15 Phase B).
#'
#' @inheritParams .insert_health_alerts
#' @return Number of rows inserted (integer).
#' @keywords internal
.insert_fordead_alerts <- function(con, alerts_sf, zone_id,
                                   monitoring_window = NULL) {
  .insert_health_alerts(con, alerts_sf, zone_id,
                        alert_type        = "fordead_dieback",
                        monitoring_window = monitoring_window)
}


#' Tag each alert with the disturbance type it most likely reflects (G2)
#'
#' Garde-fou G2, extended to **three methods** since spec 021 (L3):
#' FAST (rolling-window `ndvi_drop` / `nbr_drop`) plus the two
#' diagnostic methods `fordead_dieback` (resineux) and
#' `reconfort_dieback` (feuillus). Cross-references alerts on the same
#' plot within `± window_days` and adds a `disturbance_type` column
#' (+ a `method_overlap` flag):
#'
#' \itemize{
#'   \item `"mechanical"` — a diagnostic alert (FORDEAD **or**
#'     RECONFORT) with a FAST (`ndvi_drop` / `nbr_drop`) companion.
#'     Likely a clear-cut, chablis or fire scar.
#'   \item `"progressive"` — a lone diagnostic alert (FORDEAD or
#'     RECONFORT) without a FAST companion. Likely scolyte /
#'     drought-driven dieback.
#'   \item `"recent_event"` — a lone FAST drop without any diagnostic
#'     echo. Recent perturbation, no confirmed dieback.
#'   \item `NA_character_` — a FAST drop already paired with a
#'     diagnostic alert (the diagnostic row carries the verdict).
#' }
#'
#' `method_overlap` is `TRUE` on a diagnostic alert when **both**
#' FORDEAD and RECONFORT fired on the same plot/window (mixed
#' broadleaf/conifer fringe): the type stays `"progressive"` but the
#' flag says "signal seen by two methods — do not double-count".
#'
#' Computed in pure R: cost is O(n²) on a few thousand alerts max,
#' so we deliberately don't push it to SQL.
#'
#' Co-location is **spatial** since spec 008 §15 Phase B (the plot is
#' decoupled): two alerts pair when their centroids are within
#' `radius_m`, replacing the former `plot_id` equality. A legacy
#' `plot_id`-equality fallback is kept for pre-Phase-B alert frames that
#' carry no geometry.
#'
#' @param alerts_df The sf POINT returned by [list_alerts()] (columns
#'   `alert_type`, `trigger_date` + centroid geometry). A plain data
#'   frame with a non-NULL `plot_id` is tolerated (legacy fallback).
#' @param window_days Integer. Half-width of the join window in
#'   days. Default 30.
#' @param radius_m Numeric. Max centroid-to-centroid distance (m) for two
#'   alerts to be considered co-located. Default 100.
#'
#' @return The input enriched with a `disturbance_type` column and a
#'   logical `method_overlap` column.
#'
#' @export
classify_disturbance <- function(alerts_df, window_days = 30L,
                                 radius_m = 100) {
  if (is.null(alerts_df) || !nrow(alerts_df)) {
    alerts_df$disturbance_type <- character(0)
    alerts_df$method_overlap   <- logical(0)
    return(alerts_df)
  }
  required <- c("alert_type", "trigger_date")
  missing  <- setdiff(required, names(alerts_df))
  if (length(missing)) {
    cli::cli_abort("{.arg alerts_df} is missing column{?s}: {.val {missing}}.")
  }
  win <- as.integer(window_days)
  if (is.na(win) || win < 0L) {
    cli::cli_abort("{.arg window_days} must be a non-negative integer.")
  }
  rad <- as.numeric(radius_m)
  if (is.na(rad) || rad < 0) {
    cli::cli_abort("{.arg radius_m} must be a non-negative number.")
  }

  td  <- as.Date(alerts_df$trigger_date)
  at  <- alerts_df$alert_type
  n   <- nrow(alerts_df)

  # Matrice de co-localisation (G2 Phase B). Spatial par défaut : deux
  # centroïdes à <= radius_m. Repli legacy sur l'égalité plot_id quand
  # aucune géométrie n'est disponible (alertes pré-Phase-B).
  near <- if (inherits(alerts_df, "sf") && !is.na(sf::st_crs(alerts_df))) {
    g  <- sf::st_transform(sf::st_geometry(alerts_df), 2154)
    dm <- matrix(as.numeric(sf::st_distance(g)), n, n)
    m  <- dm <= rad
    m[is.na(m)] <- FALSE   # POINT EMPTY → distance NA → non co-localisé
    m
  } else if ("plot_id" %in% names(alerts_df) &&
             !all(is.na(alerts_df$plot_id))) {
    pid <- alerts_df$plot_id
    outer(pid, pid, function(a, b) !is.na(a) & !is.na(b) & a == b)
  } else {
    cli::cli_abort(c(
      "{.arg alerts_df} needs centroid geometry (an sf with a CRS) for the spatial G2 fusion.",
      i = "Pass the {.fn list_alerts} output (Phase B)."))
  }

  fast_types       <- c("ndvi_drop", "nbr_drop")
  diagnostic_types <- c("fordead_dieback", "reconfort_dieback")

  res <- lapply(seq_len(n), function(i) {
    in_window  <- abs(as.numeric(td - td[i])) <= win
    candidates <- near[i, ] & in_window
    candidates[i] <- FALSE  # don't pair with self

    if (at[i] %in% diagnostic_types) {
      has_fast  <- any(candidates & at %in% fast_types)
      other_dx  <- setdiff(diagnostic_types, at[i])
      has_other <- any(candidates & at %in% other_dx)
      list(type = if (has_fast) "mechanical" else "progressive",
           overlap = has_other)
    } else if (at[i] %in% fast_types) {
      has_dx <- any(candidates & at %in% diagnostic_types)
      list(type = if (has_dx) NA_character_ else "recent_event",
           overlap = FALSE)
    } else {
      list(type = NA_character_, overlap = FALSE)
    }
  })

  alerts_df$disturbance_type <- vapply(res, `[[`, character(1), "type")
  alerts_df$method_overlap   <- vapply(res, `[[`, logical(1), "overlap")
  alerts_df
}


#' List alerts of a zone with G1 default filtering
#'
#' Since spec 008 §15 Phase B the alert is a pixel/cluster entity: the
#' geometry returned is the alert's own centroid (`alert.geom_wkt`,
#' EPSG:4326), not a plot. `plot` is `LEFT JOIN`ed only to expose the
#' optional `plot_label`. The result also carries `n_pixels` / `area_m2`.
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

  where <- c("a.zone_id = $1")
  pars  <- list(as.integer(zone_id))
  i <- 1L
  add_param <- function(values) {
    i <<- i + 1L
    pars[[length(pars) + 1L]] <<- values
    sprintf("$%d", i)
  }
  # Generate a portable `IN ($n, $n+1, ...)` clause and append one
  # parameter per value. Replaces the previous PG-only
  # `ANY($n::text[])` form which relied on a server-side cast — the
  # SQLite backend has no `text[]` type and would parameter-bind the
  # array literal as a scalar string, producing an empty result set.
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
    "SELECT a.id, a.zone_id, a.plot_id, p.plot_id AS plot_label,
            a.alert_type, a.trigger_date,
            a.n_pixels, a.area_m2, a.cluster_id,
            a.value_before, a.value_after, a.delta,
            a.confidence_class, a.stress_index,
            a.validation_status, a.validation_cause,
            a.validated_by, a.validated_at,
            COALESCE(a.geom_wkt, p.geom_wkt) AS geom_wkt
       FROM alert a
       LEFT JOIN plot p ON p.id = a.plot_id
      WHERE %s
      ORDER BY a.trigger_date DESC, a.id",
    paste(where, collapse = " AND ")
  )
  rs <- .db_get_query(con, sql, params = pars)

  if (!nrow(rs)) {
    return(sf::st_sf(
      data.frame(
        id                = integer(0),
        zone_id           = integer(0),
        plot_id           = integer(0),
        plot_label        = character(0),
        alert_type        = character(0),
        trigger_date      = as.Date(character(0)),
        n_pixels          = integer(0),
        area_m2           = numeric(0),
        cluster_id        = integer(0),
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
  # Rows whose geometry is missing on both sides (should not happen for
  # Phase B alerts, which always carry a centroid) get an empty POINT.
  wkt <- rs$geom_wkt
  wkt[is.na(wkt) | !nzchar(wkt)] <- "POINT EMPTY"
  geoms <- lapply(wkt, sf::st_as_sfc, crs = 4326)
  geom_sfc <- do.call(c, geoms)
  rs$geom_wkt <- NULL
  sf::st_sf(rs, geometry = geom_sfc, crs = 4326)
}
