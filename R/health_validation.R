# ============================================================
# health_validation.R — QGIS terrain validation workflow for FORDEAD
# ------------------------------------------------------------
# Implements guard-rail G4 of spec 008 (suivi sanitaire) :
# the methodology requires a terrain validation step (37%
# false-positive rate on class 1-faible per Bernard & Doridant
# ONF/DSF 2024). This module ships a QGIS form schema, a helper
# to draw a stratified sample of alerts to be checked in the
# field, and the ingestion path that maps DSF-aligned field
# observations back to `alert.validation_status`.
#
# Workflow: a QGIS project (.qgz) packaged by `create_qgis_project()`
# (see R/qgis_export.R) renders the form on QGIS Desktop, and the
# QFieldSync plugin pushes the same project to QField on a tablet
# for offline collection. Either side writes back into the same
# GPKG; this module re-ingests it.
# ============================================================


#' DSF-aligned dieback stages used by the terrain validation form
#'
#' Vocabulary aligned with the ONF/DSF 2024 reference report
#' (Bernard & Doridant, Annexe 1). Each stage is a code an
#' observer selects in the QGIS form (whether on QGIS Desktop or
#' on QField). The code is then translated to the
#' `alert.validation_status` column by [ingest_health_validation()].
#'
#' @export
HEALTH_VALIDATION_STADES <- c(
  "sain",
  "sain_scolyte_vert_indif",
  "scolyte_vert",
  "scolyte_rouge",
  "scolyte_gris",
  "scolyte_rouge_gris_indif",
  "coupe_rase"
)


#' Free-form causes proposed in the QGIS form
#'
#' These are *suggestions* presented to the field observer. The
#' chosen value lands in `alert.validation_cause` verbatim — the
#' `alert` table does not enforce a CHECK constraint on this
#' column (see migration `0002_fordead.sql`).
#'
#' @export
HEALTH_VALIDATION_CAUSES <- c(
  "scolyte",
  "secheresse",
  "casse_cime",
  "coupe",
  "chablis",
  "phenologie",
  "autre"
)


# Internal: maps a DSF stage code + the FORDEAD initial confidence
# class to (validation_status, validation_cause). The Coupe_rase
# rule is class-dependent because the rapport ONF/DSF 2024
# explicitly notes that 1-faible and 2-moyenne tend to false-flag
# clearcuts as dieback.
.health_stade_to_status <- function(stade, confidence_class = NA_character_) {
  stade  <- tolower(as.character(stade))
  cls    <- as.character(confidence_class)
  status <- NA_character_
  cause  <- NA_character_

  if (is.na(stade) || !nzchar(stade)) {
    return(list(status = NA_character_, cause = NA_character_))
  }

  if (stade == "sain") {
    status <- "false_positive"
    cause  <- "sain_terrain"
  } else if (stade == "coupe_rase") {
    cause <- "coupe_terrain"
    if (!is.na(cls) && cls %in% c("1-faible", "2-moyenne")) {
      status <- "false_positive"
    } else {
      status <- "confirmed"
    }
  } else if (startsWith(stade, "scolyte") || stade == "sain_scolyte_vert_indif") {
    status <- "confirmed"
    cause  <- "scolyte_terrain"
  } else {
    status <- "confirmed"
    cause  <- stade
  }

  list(status = status, cause = cause)
}


#' QGIS form schema for the health-validation `placette` layer
#'
#' Adds the dieback-specific columns on top of a sampling-style
#' header (`plot_id`, observer/date) so the GPKG can be opened in
#' QGIS Desktop (or pushed to QField on a tablet via QFieldSync),
#' edited offline by the field crew, then re-ingested by
#' [ingest_health_validation()]. The schema reuses the same
#' `.field()` descriptor convention as [get_placette_schema()] so
#' the existing `create_qgis_project()` machinery (in
#' `R/qgis_export.R`) renders the `.qgz` form without changes.
#'
#' @param region Character. Species region, used to populate the
#'   `essence_dominante` value-map. Default `"BFC"`.
#' @param lang Character. Language for species labels. Default
#'   `"fr"`.
#'
#' @return A list of field descriptors (see `R/field_schema.R`).
#'
#' @export
get_health_validation_schema <- function(region = "BFC", lang = "fr") {
  species_df <- tryCatch(
    list_species_classes(region = region, lang = lang),
    error = function(e) {
      cli::cli_warn(c(
        "Species config for {.val {region}} unavailable: {.val {e$message}}.",
        i = "Falling back to free-text {.field essence_dominante}."
      ))
      NULL
    }
  )
  species_domain <- if (!is.null(species_df)) species_df$code else NULL

  list(
    .field("plot_id",            "character", "text",
           label = "Plot ID", required = TRUE),
    .field("alert_id",           "integer",   "text",
           label = "Alert ID (DB)"),
    .field("confidence_class",   "character", "text",
           label = "FORDEAD class (initial)"),
    .field("stade_deperissement", "character", "value_map",
           label = "Stade de deperissement",
           domain = HEALTH_VALIDATION_STADES,
           required = TRUE),
    .field("cause",              "character", "value_map",
           label = "Cause observee",
           domain = HEALTH_VALIDATION_CAUSES),
    .field("taux_couvert",       "double",    "range",
           label = "Taux de couvert (%)",
           min = 0, max = 100),
    .field("essence_dominante",  "character",
           if (is.null(species_domain)) "text" else "value_map",
           label = "Essence dominante",
           domain = species_domain),
    .field("commentaires",       "character", "text",
           label = "Commentaires"),
    .field("photo_houppier",     "character", "photo",
           label = "Photo houppier"),
    .field("obs_date",           "datetime",  "datetime",
           label = "Date d observation"),
    .field("obs_by",             "character", "text",
           label = "Observateur")
  )
}


# Allocate a sample of size n_total across strata so that every
# present class gets at least 1 plot, then distribute the remainder
# proportionally (largest-remainder method). Returns an integer
# vector named after the strata, summing to min(n_total, sum(counts)).
.allocate_health_strata <- function(counts, n_total) {
  n_total <- as.integer(n_total)
  total_avail <- sum(counts)
  if (total_avail == 0L) return(setNames(integer(0), character(0)))
  n_total <- min(n_total, total_avail)
  k <- length(counts)
  if (n_total <= k) {
    # Not enough budget for the floor: keep the k_top largest classes.
    keep <- order(counts, decreasing = TRUE)[seq_len(n_total)]
    out  <- setNames(rep(0L, k), names(counts))
    out[keep] <- 1L
    return(out)
  }
  base <- setNames(pmin(rep(1L, k), counts), names(counts))
  remaining <- n_total - sum(base)
  if (remaining > 0L) {
    cap <- counts - base
    if (sum(cap) == 0L) return(base)
    raw <- remaining * cap / sum(cap)
    add <- floor(raw)
    leftover <- remaining - sum(add)
    if (leftover > 0L) {
      frac <- raw - add
      ord <- order(frac, decreasing = TRUE)
      add[ord[seq_len(leftover)]] <- add[ord[seq_len(leftover)]] + 1L
    }
    base <- base + as.integer(add)
  }
  base
}


#' Draw a stratified sample of alerts to be validated in the field
#'
#' Stratifies on `confidence_class` so every observed class lands
#' in the validation set (with at least one plot per class), then
#' uses GRTS via [spsurvey::grts()] when available for spatial
#' balance, and falls back to a per-stratum random draw when
#' `spsurvey` is not installed.
#'
#' The returned `sf` is shaped to feed `create_qgis_project()`
#' through [get_health_validation_schema()].
#'
#' @param alerts_sf An `sf` POINT layer of alert centroids. Must
#'   carry at least the `id`, `confidence_class`, `stress_index`
#'   and `trigger_date` columns produced by
#'   [list_alerts()] / [.insert_fordead_alerts()].
#' @param n Integer. Total number of validation plots to draw.
#' @param method Character. `"grts"` (default) or `"random"`.
#'   GRTS silently degrades to random when `spsurvey` is missing.
#' @param crs CRS the result is reprojected into. Default 2154
#'   (Lambert-93) — the CRS the downstream QGIS / QField project
#'   uses to render the placettes layer.
#'
#' @return An `sf` POINT layer with columns `plot_id`, `alert_id`,
#'   `confidence_class`, `stress_index`, `trigger_date`,
#'   `sampling_method`, plus the schema's editable columns
#'   pre-allocated as typed NAs.
#'
#' @export
generate_health_validation_plots <- function(alerts_sf,
                                              n      = 30L,
                                              method = c("grts", "random"),
                                              crs    = 2154) {
  if (!inherits(alerts_sf, "sf")) {
    cli::cli_abort("{.arg alerts_sf} must be an sf object.")
  }
  if (nrow(alerts_sf) == 0L) {
    cli::cli_warn("Empty {.arg alerts_sf} — returning an empty layer.")
    return(alerts_sf[0L, ])
  }
  required <- c("confidence_class")
  miss <- setdiff(required, names(alerts_sf))
  if (length(miss)) {
    cli::cli_abort("{.arg alerts_sf} is missing required column{?s}: {.val {miss}}.")
  }
  method <- match.arg(method)
  n <- as.integer(n)
  if (is.na(n) || n < 1L) {
    cli::cli_abort("{.arg n} must be a positive integer.")
  }

  ids <- if ("id" %in% names(alerts_sf)) alerts_sf$id else seq_len(nrow(alerts_sf))
  alerts_sf$alert_id  <- as.integer(ids)
  alerts_sf$.row_idx  <- seq_len(nrow(alerts_sf))

  cls <- as.character(alerts_sf$confidence_class)
  cls[is.na(cls) | !nzchar(cls)] <- "unknown"
  counts <- table(cls)
  alloc  <- .allocate_health_strata(counts, n)
  alloc  <- alloc[alloc > 0L]

  use_grts <- identical(method, "grts") &&
    requireNamespace("spsurvey", quietly = TRUE)

  picked <- integer(0)
  for (stratum in names(alloc)) {
    pool <- alerts_sf$.row_idx[cls == stratum]
    take <- min(alloc[[stratum]], length(pool))
    if (take == 0L) next
    if (use_grts && length(pool) > take) {
      sub_sf <- alerts_sf[pool, , drop = FALSE]
      drawn <- tryCatch({
        suppressMessages(utils::capture.output(
          res <- spsurvey::grts(sframe = sub_sf, n_base = take),
          file = nullfile()
        ))
        idx_in_pool <- match(res$sites_base$.row_idx, pool)
        pool[idx_in_pool[!is.na(idx_in_pool)]]
      }, error = function(e) {
        cli::cli_warn("spsurvey::grts failed in stratum {.val {stratum}}: {e$message}. Falling back to random.")
        sample(pool, take)
      })
      picked <- c(picked, drawn)
    } else {
      picked <- c(picked,
                  if (length(pool) <= take) pool else sample(pool, take))
    }
  }

  sampling_method <- if (use_grts) "grts" else "random"
  out <- alerts_sf[picked, , drop = FALSE]
  out$.row_idx <- NULL
  out$plot_id <- sprintf("HV-%04d", seq_len(nrow(out)))
  out$sampling_method <- sampling_method

  # Pre-allocate the editable schema columns as typed NAs so the
  # downstream GPKG export does not need to coerce logical NAs.
  schema_cols <- list(
    stade_deperissement = NA_character_,
    cause               = NA_character_,
    taux_couvert        = NA_real_,
    essence_dominante   = NA_character_,
    commentaires        = NA_character_,
    photo_houppier      = NA_character_,
    obs_date            = as.POSIXct(NA, tz = "UTC"),
    obs_by              = NA_character_
  )
  for (nm in names(schema_cols)) {
    if (!nm %in% names(out)) out[[nm]] <- schema_cols[[nm]]
  }

  if (sf::st_crs(out)$epsg != crs) out <- sf::st_transform(out, crs)

  keep <- c("plot_id", "alert_id", "confidence_class",
            intersect(c("stress_index", "trigger_date", "alert_type"),
                      names(out)),
            names(schema_cols), "sampling_method",
            attr(out, "sf_column"))
  out[, intersect(keep, names(out))]
}


#' Ingest a health-validation GPKG and update `alert` rows
#'
#' Reads the `placettes` layer of `gpkg_path` (typically a GPKG
#' edited in QGIS Desktop or in QField on a tablet), snaps each
#' plot to the nearest alert of the given `zone_id` (within
#' `snap_distance_m`), maps the observer-selected
#' `stade_deperissement` to `validation_status` /
#' `validation_cause`, and issues an `UPDATE alert` per match.
#' Plots without a `stade_deperissement` are skipped (never edited
#' in the field).
#'
#' @param con A `DBIConnection` to a TimescaleDB instance.
#' @param gpkg_path Character. Path to the GPKG returned by the
#'   field crew.
#' @param zone_id Integer. The monitoring zone whose alerts the
#'   validation targets.
#' @param snap_distance_m Numeric. Maximum distance (metres) for
#'   matching a plot to an alert. Default 50.
#' @param validated_by Character or `NULL`. Identity persisted on
#'   the alert (typically the OAuth subject of the ingesting user
#'   — defaults to the value present in `obs_by`, then to
#'   `Sys.info()[["user"]]`).
#' @param layer Character. GPKG layer name. Default `"placettes"`.
#'
#' @return A list:
#'   * `n_updated` (int), `n_confirmed` (int),
#'     `n_false_positive` (int);
#'   * `n_unmatched` (int) — plots without an alert within
#'     `snap_distance_m`;
#'   * `n_skipped` (int) — plots with no `stade_deperissement`;
#'   * `details` — a data.frame with one row per processed plot.
#'
#' @export
ingest_health_validation <- function(con,
                                     gpkg_path,
                                     zone_id,
                                     snap_distance_m = 50,
                                     validated_by    = NULL,
                                     layer           = "placettes") {
  .assert_db_pkgs()
  if (!file.exists(gpkg_path)) {
    cli::cli_abort("GPKG not found: {.path {gpkg_path}}.")
  }

  plots <- sf::st_read(gpkg_path, layer = layer, quiet = TRUE)
  if (!"stade_deperissement" %in% names(plots)) {
    cli::cli_abort("Layer {.val {layer}} of {.path {gpkg_path}} is missing the {.field stade_deperissement} column.")
  }

  # Pull every alert of this zone (id + geometry only). Snap is in
  # metres so we project everything to Lambert-93.
  alerts_q <- DBI::dbGetQuery(con,
    "SELECT a.id, a.confidence_class, p.geom_wkt
       FROM alert a
       JOIN plot p ON p.id = a.plot_id
      WHERE p.zone_id = $1",
    params = list(as.integer(zone_id)))

  if (!nrow(alerts_q)) {
    cli::cli_warn("Zone {zone_id} has no alerts — nothing to validate.")
    return(list(
      n_updated = 0L, n_confirmed = 0L, n_false_positive = 0L,
      n_unmatched = nrow(plots), n_skipped = 0L,
      details = .empty_health_details()
    ))
  }

  alerts_sf <- sf::st_as_sf(alerts_q, wkt = "geom_wkt", crs = 4326)
  alerts_sf <- sf::st_transform(alerts_sf, 2154)
  plots_m   <- sf::st_transform(plots, 2154)

  details <- .empty_health_details()
  n_confirmed <- 0L
  n_false_positive <- 0L
  n_unmatched <- 0L
  n_skipped <- 0L

  for (i in seq_len(nrow(plots_m))) {
    stade <- plots_m$stade_deperissement[i]
    if (is.na(stade) || !nzchar(stade)) {
      n_skipped <- n_skipped + 1L
      details <- rbind(details, .health_detail_row(
        plot_id = .plot_label(plots_m, i),
        alert_id = NA_integer_, distance_m = NA_real_,
        stade = NA_character_, status = NA_character_,
        cause = NA_character_, reason = "missing_stade"))
      next
    }
    d <- as.numeric(sf::st_distance(plots_m[i, ], alerts_sf))
    j <- which.min(d)
    dmin <- d[j]
    if (dmin > snap_distance_m) {
      n_unmatched <- n_unmatched + 1L
      details <- rbind(details, .health_detail_row(
        plot_id = .plot_label(plots_m, i),
        alert_id = NA_integer_, distance_m = dmin,
        stade = stade, status = NA_character_,
        cause = NA_character_, reason = "no_alert_within_snap"))
      next
    }

    alert_id <- as.integer(alerts_sf$id[j])
    cls      <- alerts_sf$confidence_class[j]
    map      <- .health_stade_to_status(stade, cls)
    status   <- map$status

    obs_by <- validated_by
    if (is.null(obs_by) && "obs_by" %in% names(plots) &&
        !is.na(plots$obs_by[i]) && nzchar(plots$obs_by[i])) {
      obs_by <- as.character(plots$obs_by[i])
    }
    if (is.null(obs_by)) obs_by <- Sys.info()[["user"]]

    field_cause <- if ("cause" %in% names(plots) &&
                      !is.na(plots$cause[i]) &&
                      nzchar(plots$cause[i])) {
      as.character(plots$cause[i])
    } else {
      map$cause
    }

    DBI::dbExecute(con,
      "UPDATE alert
          SET validation_status = $2,
              validation_cause  = $3,
              validated_by      = $4,
              validated_at      = now()
        WHERE id = $1",
      params = list(alert_id, status, field_cause, obs_by))

    if (status == "confirmed") n_confirmed <- n_confirmed + 1L
    if (status == "false_positive") n_false_positive <- n_false_positive + 1L

    details <- rbind(details, .health_detail_row(
      plot_id = .plot_label(plots_m, i),
      alert_id = alert_id, distance_m = dmin,
      stade = stade, status = status,
      cause = field_cause, reason = "ok"))
  }

  n_updated <- n_confirmed + n_false_positive
  cli::cli_alert_success(
    "Health validation: {n_updated} alert{?s} updated ({n_confirmed} confirmed, {n_false_positive} false-positive), {n_unmatched} unmatched, {n_skipped} skipped."
  )

  list(
    n_updated        = n_updated,
    n_confirmed      = n_confirmed,
    n_false_positive = n_false_positive,
    n_unmatched      = n_unmatched,
    n_skipped        = n_skipped,
    details          = details
  )
}


# ---- internal -------------------------------------------------------

.empty_health_details <- function() {
  data.frame(
    plot_id    = character(0),
    alert_id   = integer(0),
    distance_m = numeric(0),
    stade      = character(0),
    status     = character(0),
    cause      = character(0),
    reason     = character(0),
    stringsAsFactors = FALSE
  )
}


.health_detail_row <- function(plot_id, alert_id, distance_m,
                               stade, status, cause, reason) {
  data.frame(
    plot_id    = as.character(plot_id),
    alert_id   = as.integer(alert_id),
    distance_m = as.numeric(distance_m),
    stade      = as.character(stade),
    status     = as.character(status),
    cause      = as.character(cause),
    reason     = as.character(reason),
    stringsAsFactors = FALSE
  )
}


.plot_label <- function(plots_m, i) {
  if ("plot_id" %in% names(plots_m) && !is.na(plots_m$plot_id[i])) {
    as.character(plots_m$plot_id[i])
  } else {
    sprintf("row%04d", i)
  }
}
