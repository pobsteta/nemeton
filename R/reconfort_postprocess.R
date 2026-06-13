#' RECONFORT Post-Processing: Rasters to Alert Clusters (L3, spec 021)
#'
#' @description
#' Turns the GeoTIFF outputs of [run_reconfort_dieback()] into a sf
#' POINT layer of cluster centroids and persists them into the
#' `alert` table, mirroring [fordead_postprocess]. The flow is:
#'
#' \enumerate{
#'   \item The masked classification raster (per-pixel RF class,
#'     `1` sain / `2` dépérissant / `3` très dépérissant for oak &
#'     chestnut, `1`/`2` for pine; `0` = no-data/masked) is
#'     reclassified into the canonical [`RECONFORT_CLASSES`] labels.
#'   \item Connected pixel patches are extracted (`terra::patches`,
#'     8-neighbour by default) per **dieback** class (codes `>= 2`;
#'     class `1` "sain" never raises an alert). Patches smaller than
#'     `min_pixels` are dropped (garde-fou G1).
#'   \item Each cluster yields a centroid enriched with
#'     `confidence_class`, `stress_index` (= mean of the **continuous
#'     score** raster `(1001 + (-P1 + P2 + 2*P3)) / 30`), `n_pixels`,
#'     `area_m2`. Unlike FORDEAD there is no per-pixel date raster, so
#'     `trigger_date` is the single run date.
#' }
#'
#' @name reconfort_postprocess
NULL


#' Canonical RECONFORT classes by target species
#'
#' Per-species ordered class labels of the Random-Forest output
#' (spec 021 §4.4). Index `i` (1-based) is the class for the integer
#' code `i` in the classification raster (code `0` is no-data/masked,
#' it has no label). Oak (`CHE`) and chestnut (`CHT`) have 3 classes;
#' Scots pine (`PS`) has 2.
#'
#' @export
RECONFORT_CLASSES <- list(
  CHE = c("1-sain", "2-deperissant", "3-tres-deperissant"),
  CHT = c("1-sain", "2-deperissant", "3-tres-deperissant"),
  PS  = c("1-sain", "2-deperissant")
)


#' Provisional RECONFORT confidence weights (garde-fou G1)
#'
#' Per-class trustworthiness coefficients used to weight the R5
#' dépérissement indicator (spec 021 §5/G1), the RECONFORT analogue of
#' [`FORDEAD_CONFIDENCE_WEIGHTS`]. The healthy class (`1-sain`) raises
#' no alert; the dieback classes are the ones that propagate.
#'
#' **PROVISIONAL — NOT YET CALIBRATED.** spec 021 §5/G1 prescribes that
#' these weights be documented from the RECONFORT confusion matrix
#' (Mouret et al. 2023, IEEE J-STARS). That matrix is not transcribed
#' here yet: the values below are conservative placeholders
#' (severe > moderate, healthy ~ 0) and **must** be replaced by the
#' upstream-validated figures before the R5 indicator (L4) relies on
#' them quantitatively. They are not used for the L3 alert geometry,
#' only for downstream weighting.
#'
#' @export
RECONFORT_CONFIDENCE_WEIGHTS <- list(
  CHE = c("1-sain" = 0.00, "2-deperissant" = 0.50, "3-tres-deperissant" = 0.80),
  CHT = c("1-sain" = 0.00, "2-deperissant" = 0.50, "3-tres-deperissant" = 0.80),
  PS  = c("1-sain" = 0.00, "2-deperissant" = 0.55)
)


#' Default trustworthy RECONFORT classes for garde-fou G1
#'
#' The dieback classes that [list_alerts()] keeps by default — the
#' RECONFORT mirror of FORDEAD's `c("3-forte", "4-sol-nu")`. The
#' healthy class `1-sain` is always excluded.
#'
#' @export
RECONFORT_ALERT_CLASSES <- c("2-deperissant", "3-tres-deperissant")


#' Resolve the class labels for a RECONFORT target species
#'
#' @param species One of `"CHE"`, `"CHT"`, `"PS"`.
#' @return A character vector of class labels (length 3 or 2).
#' @keywords internal
.reconfort_species_classes <- function(species) {
  species <- toupper(as.character(species))
  cl <- RECONFORT_CLASSES[[species]]
  if (is.null(cl)) {
    cli::cli_abort(c(
      "Unknown RECONFORT species {.val {species}}.",
      i = "Expected one of {.val {names(RECONFORT_CLASSES)}}."
    ))
  }
  cl
}


#' Continuous RECONFORT dieback score from class probabilities
#'
#' Implements the production formula of
#' `mask_and_compress_rasters.py::compute_continuous_score`
#' (spec 021 §4.4): `score = (1001 + (-P1 + P2 + 2*P3)) / 30`, where
#' `P1`/`P2`/`P3` are the per-pixel probabilities (0..1000 scale, as
#' produced by OTB/Shark) of the healthy / dieback / severe classes.
#' Pine (2 classes) has no `P3` (treated as 0). The score is bounded
#' roughly in `1..100` (1 = healthy, 100 = severe); `0` is no-data.
#'
#' Provided so the score can be reconstructed in R (tests, or a
#' fallback when only the probability raster survived). The real
#' pipeline reads the precomputed `Final_continuous_score_masked`
#' raster directly.
#'
#' @param p1,p2 Healthy / dieback probabilities (numeric, 0..1000).
#' @param p3 Severe probability (numeric, 0..1000). `0` for pine.
#' @return Numeric continuous score.
#' @keywords internal
.reconfort_continuous_score <- function(p1, p2, p3 = 0) {
  (1001 + (-p1 + p2 + 2 * p3)) / 30
}


#' Reclassify a RECONFORT classification raster into canonical classes
#'
#' Maps integer codes onto the species' [`RECONFORT_CLASSES`]. Code
#' `0` (no-data / masked out) and any value outside `1..n_classes`
#' become NA.
#'
#' @param classif_raster A `terra::SpatRaster` of integer codes
#'   (`0..n`).
#' @param species One of `"CHE"`, `"CHT"`, `"PS"`.
#' @return A `terra::SpatRaster` of integer codes in `1..n` (NA
#'   elsewhere), named `"reconfort_class"`.
#' @keywords internal
.classify_pixels_to_reconfort_classes <- function(classif_raster, species) {
  if (!inherits(classif_raster, "SpatRaster")) {
    cli::cli_abort("{.arg classif_raster} must be a {.cls SpatRaster}.")
  }
  n <- length(.reconfort_species_classes(species))
  vals <- terra::values(classif_raster)
  vals[!is.na(vals) & (vals < 1 | vals > n)] <- NA
  out <- terra::setValues(classif_raster, vals)
  names(out) <- "reconfort_class"
  out
}


#' Cluster RECONFORT dieback pixels into connected patches per class
#'
#' Mirror of [.cluster_anomaly_pixels()] for RECONFORT: one binary
#' raster per **dieback** class (codes `>= 2`; the healthy class `1`
#' raises no alert), `terra::patches()` 8-neighbour by default,
#' patches smaller than `min_pixels` dropped.
#'
#' @param class_raster A `terra::SpatRaster` returned by
#'   [.classify_pixels_to_reconfort_classes()].
#' @param species One of `"CHE"`, `"CHT"`, `"PS"`.
#' @param min_pixels Integer. Minimum patch size. Default 5.
#' @param connectivity Integer 4 or 8. Default 8.
#' @return A named list of `SpatRaster`s (one per dieback class) with
#'   integer patch IDs and NA elsewhere.
#' @keywords internal
.cluster_reconfort_pixels <- function(class_raster, species,
                                      min_pixels   = 5L,
                                      connectivity = 8L) {
  if (!inherits(class_raster, "SpatRaster")) {
    cli::cli_abort("{.arg class_raster} must be a {.cls SpatRaster}.")
  }
  if (!connectivity %in% c(4L, 8L)) {
    cli::cli_abort("{.arg connectivity} must be 4 or 8.")
  }
  classes <- .reconfort_species_classes(species)
  out <- list()
  for (code in 2:length(classes)) {            # skip code 1 ("sain")
    cls  <- classes[code]
    mask <- terra::ifel(class_raster == code, 1L, NA)
    if (all(is.na(terra::values(mask)))) {
      out[[cls]] <- mask
      next
    }
    patches <- terra::patches(mask, directions = connectivity,
                              zeroAsNA = TRUE)
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


#' Top-level helper: turn RECONFORT raster outputs into an `alerts_sf`
#'
#' Combines [.classify_pixels_to_reconfort_classes()],
#' [.cluster_reconfort_pixels()] and [.cluster_to_centroids()] (reused
#' from [fordead_postprocess], generic on the cluster names) into a
#' single call. The continuous-score raster feeds `stress_index`; the
#' single run `trigger_date` is stamped on every centroid (RECONFORT
#' has no per-pixel date raster).
#'
#' @param rasters Named list with character paths or `SpatRaster`
#'   objects under `classif` (masked classification) and
#'   `continuous_score`.
#' @param species One of `"CHE"`, `"CHT"`, `"PS"`.
#' @param trigger_date A length-1 `Date` (the run date). Stamped on
#'   every centroid.
#' @param min_pixels Integer. Minimum patch size. Default 5.
#' @param connectivity Integer 4 or 8. Default 8.
#' @return An sf POINT (possibly empty), columns as
#'   [.cluster_to_centroids()].
#' @keywords internal
.postprocess_reconfort_rasters <- function(rasters, species, trigger_date,
                                           min_pixels   = 5L,
                                           connectivity = 8L) {
  if (!is.list(rasters) || is.null(rasters$classif)) {
    cli::cli_abort("{.arg rasters$classif} is required.")
  }
  load_one <- function(x) {
    if (is.null(x) || (is.character(x) && (length(x) != 1L || !file.exists(x)))) {
      return(NULL)
    }
    if (inherits(x, "SpatRaster")) x else terra::rast(x)
  }
  cf <- load_one(rasters$classif)
  if (is.null(cf)) cli::cli_abort("Cannot load {.arg rasters$classif}.")
  sc <- load_one(rasters$continuous_score)

  cl      <- .classify_pixels_to_reconfort_classes(cf, species)
  patches <- .cluster_reconfort_pixels(cl, species, min_pixels = min_pixels,
                                       connectivity = connectivity)
  out <- .cluster_to_centroids(patches,
                               stress_index_raster       = sc,
                               first_dieback_date_raster = NULL)
  if (nrow(out)) {
    out$trigger_date <- as.Date(rep(trigger_date, nrow(out)))
  }
  out
}


#' Persist RECONFORT alert centroids in the `alert` table
#'
#' Mirror of [.insert_fordead_alerts()] with
#' `alert_type = 'reconfort_dieback'`. Idempotent via the existing
#' UNIQUE `(plot_id, alert_type, trigger_date)` constraint and
#' `ON CONFLICT DO NOTHING`. Each centroid is snapped to the nearest
#' plot of the zone within `radius_m`.
#'
#' @param con A `DBIConnection`.
#' @param alerts_sf An sf POINT from [.postprocess_reconfort_rasters()].
#' @param zone_id Integer. Target monitoring zone.
#' @param radius_m Numeric. Max centroid -> plot distance (m). Default 200.
#' @return Number of rows inserted (integer).
#' @keywords internal
.insert_reconfort_alerts <- function(con, alerts_sf, zone_id,
                                     radius_m = 200) {
  .assert_db_pkgs()
  if (!inherits(alerts_sf, "sf") || !nrow(alerts_sf)) return(0L)

  plots <- .db_get_query(con,
    "SELECT id, plot_id, geom_wkt FROM plot WHERE zone_id = $1",
    params = list(as.integer(zone_id)))
  if (!nrow(plots)) {
    cli::cli_warn("Zone {zone_id} has no registered plots; skipping RECONFORT alert insertion.")
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
  dist_m  <- as.numeric(sf::st_distance(
    alerts_sf, plots_sf[nearest, , drop = FALSE], by_element = TRUE))
  keep <- dist_m <= radius_m
  if (!any(keep)) {
    cli::cli_warn("All RECONFORT centroids are farther than {radius_m} m from any plot of zone {zone_id}.")
    return(0L)
  }
  if (any(!keep)) {
    cli::cli_alert_warning(
      "Skipping {sum(!keep)} RECONFORT centroid{?s} farther than {radius_m} m from any plot.")
  }

  staging <- data.frame(
    plot_id          = plots_sf$plot_db_id[nearest][keep],
    alert_type       = "reconfort_dieback",
    trigger_date     = alerts_sf$trigger_date[keep],
    value_before     = NA_real_,
    value_after      = NA_real_,
    delta            = NA_real_,
    confidence_class = alerts_sf$confidence_class[keep],
    stress_index     = alerts_sf$stress_index[keep],
    stringsAsFactors = FALSE
  )
  n_before <- nrow(staging)
  staging  <- staging[!is.na(staging$trigger_date), , drop = FALSE]
  if (n_before - nrow(staging) > 0L) {
    cli::cli_warn("Dropped {n_before - nrow(staging)} RECONFORT alert{?s} with a missing {.field trigger_date}.")
  }
  if (!nrow(staging)) return(0L)

  is_pg <- inherits(con, "PqConnection")
  inserted <- DBI::dbWithTransaction(con, {
    if (is_pg) {
      .db_execute(con,
        "CREATE TEMP TABLE tmp_reconfort_alert_staging (
           plot_id          INTEGER,
           alert_type       TEXT,
           trigger_date     DATE,
           value_before     DOUBLE PRECISION,
           value_after      DOUBLE PRECISION,
           delta            DOUBLE PRECISION,
           confidence_class TEXT,
           stress_index     DOUBLE PRECISION
         ) ON COMMIT DROP")
    } else {
      .db_execute(con, "DROP TABLE IF EXISTS tmp_reconfort_alert_staging")
      .db_execute(con,
        "CREATE TEMP TABLE tmp_reconfort_alert_staging (
           plot_id          INTEGER,
           alert_type       TEXT,
           trigger_date     DATE,
           value_before     DOUBLE,
           value_after      DOUBLE,
           delta            DOUBLE,
           confidence_class TEXT,
           stress_index     DOUBLE
         )")
    }
    DBI::dbAppendTable(con, "tmp_reconfort_alert_staging", staging)
    # `WHERE 1=1` mandatory on SQLite (UPSERT-after-SELECT parsing, cf.
    # .insert_fordead_alerts); no-op on PG.
    n <- .db_execute(con,
      "INSERT INTO alert (plot_id, alert_type, trigger_date,
                          value_before, value_after, delta,
                          confidence_class, stress_index)
       SELECT plot_id, alert_type, trigger_date,
              value_before, value_after, delta,
              confidence_class, stress_index
         FROM tmp_reconfort_alert_staging
         WHERE 1=1
       ON CONFLICT (plot_id, alert_type, trigger_date) DO NOTHING")
    if (!is_pg) {
      .db_execute(con, "DROP TABLE tmp_reconfort_alert_staging")
    }
    as.integer(n)
  })
  inserted
}
