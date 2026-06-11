# ============================================================
# reconfort_validity.R — RECONFORT calibration validity check
# ------------------------------------------------------------
# Implements guard-rail G3 of spec 021 (suivi sanitaire feuillus) :
# the RECONFORT oak-dieback model (Mouret et al. 2023,
# doi:10.1109/JSTARS.2023.3332420) is calibrated only on the six
# departments of the Centre-Val de Loire region (18 Cher, 28
# Eure-et-Loir, 36 Indre, 37 Indre-et-Loire, 41 Loir-et-Cher,
# 45 Loiret) and on stands of pedunculate/sessile oak (CHE),
# sweet chestnut (CHT) and Scots pine (PS).
#
# IMPORTANT — advisory, not blocking. Unlike FORDEAD (spec 008
# G3, which gates the run), RECONFORT imposes NO hard geographic
# lock: the upstream code itself runs outside CVL (its example
# targets the FD Saint-Gobain, Aisne). `check_reconfort_validity()`
# therefore only ADVISES — the app shows a warning banner, it does
# not prevent the diagnosis. `advisory = TRUE` is echoed in the
# result to make this explicit.
# ============================================================


#' Department codes covered by the RECONFORT calibration validity zone
#'
#' INSEE codes of the six departments of the Centre-Val de Loire
#' region where the RECONFORT model is calibrated: Cher (18),
#' Eure-et-Loir (28), Indre (36), Indre-et-Loire (37),
#' Loir-et-Cher (41), Loiret (45).
#'
#' @export
RECONFORT_VALIDITY_DEPARTMENTS <- c("18", "28", "36", "37", "41", "45")


#' Tree species considered valid by the RECONFORT calibration
#'
#' Short codes for the three RECONFORT-calibrated species: oak (CHE,
#' \emph{Quercus} spp.), sweet chestnut (CHT, \emph{Castanea sativa})
#' and Scots pine (PS, \emph{Pinus sylvestris}).
#'
#' @export
RECONFORT_VALIDITY_SPECIES <- c("CHE", "CHT", "PS")


# In-package cache for the (small) GeoJSON layer so we don't pay
# the sf::st_read() cost on every check_reconfort_validity() call.
.reconfort_validity_cache <- new.env(parent = emptyenv())


#' Load the RECONFORT validity zones layer
#'
#' Reads `inst/extdata/reconfort_validity_zones.geojson` (the six
#' Centre-Val de Loire department polygons in EPSG:4326) and caches
#' the result for the lifetime of the R session.
#'
#' @return An `sf` object with columns `code_dept`, `nom_dept`,
#'   `source`, `reference` and `geometry` (MULTIPOLYGON, EPSG:4326).
#' @export
load_reconfort_validity_zones <- function() {
  if (is.null(.reconfort_validity_cache$zones)) {
    p <- system.file("extdata", "reconfort_validity_zones.geojson",
                     package = "nemeton")
    if (!nzchar(p)) {
      cli::cli_abort(c(
        "Cannot find {.file reconfort_validity_zones.geojson}.",
        i = "Run {.code Rscript data-raw/build_reconfort_validity_zones.R} to (re)build it."
      ))
    }
    .reconfort_validity_cache$zones <- sf::st_read(p, quiet = TRUE)
  }
  .reconfort_validity_cache$zones
}


# Match oak (Quercus spp.). RECONFORT code "CHE" or any French /
# Latin label containing "chene" / "chêne" / "quercus".
.is_chene <- function(x) {
  x <- as.character(x)
  out <- rep(FALSE, length(x))
  m <- !is.na(x)
  s <- x[m]
  s_low <- tolower(s)
  hit <- grepl("\\bche\\b", s, ignore.case = TRUE) |
    grepl("chene", s_low, fixed = TRUE) |
    grepl("ch\u00eane", s_low, fixed = TRUE) |
    grepl("quercus", s_low, fixed = TRUE)
  out[m] <- hit
  out
}


# Match sweet chestnut (Castanea sativa). RECONFORT code "CHT" or
# any label containing "chataignier" / "châtaignier" / "castanea".
.is_chataignier <- function(x) {
  x <- as.character(x)
  out <- rep(FALSE, length(x))
  m <- !is.na(x)
  s <- x[m]
  s_low <- tolower(s)
  hit <- grepl("\\bcht\\b", s, ignore.case = TRUE) |
    grepl("chataignier", s_low, fixed = TRUE) |
    grepl("ch\u00e2taignier", s_low, fixed = TRUE) |
    grepl("castanea", s_low, fixed = TRUE)
  out[m] <- hit
  out
}


# Match Scots pine (Pinus sylvestris). RECONFORT code "PS" or an
# explicit "pin sylvestre" / "pinus sylvestris" label. Deliberately
# NOT matching "pin" alone, to exclude maritime/black/Laricio pines
# which RECONFORT does not cover.
.is_pin_sylvestre <- function(x) {
  x <- as.character(x)
  out <- rep(FALSE, length(x))
  m <- !is.na(x)
  s <- x[m]
  s_low <- tolower(s)
  hit <- grepl("\\bps\\b", s, ignore.case = TRUE) |
    grepl("pin sylvestre", s_low, fixed = TRUE) |
    grepl("pinus sylvestris", s_low, fixed = TRUE)
  out[m] <- hit
  out
}


#' Check whether an AOI lies within the RECONFORT calibration domain
#'
#' Implements guard-rail G3 (spec 021). An AOI is "valid" for
#' RECONFORT if (i) it intersects the six Centre-Val de Loire
#' departments by more than `threshold_geo` of its area and (ii) the
#' user-provided forest units are dominated by the three calibrated
#' species (oak + chestnut + Scots pine) at more than
#' `threshold_species` of their cumulated area.
#'
#' Unlike [check_fordead_validity()], the check is **advisory, not
#' blocking** (`advisory = TRUE` in the result): RECONFORT carries no
#' hard geographic lock upstream, so the app warns but never prevents
#' the diagnosis.
#'
#' @param aoi An `sf` polygon (any CRS); the project area of interest.
#' @param units Optional `sf` of forest management units. Must carry
#'   a species label column (one of `essence_dominante`, `essence`,
#'   `species_label`, `species`, `essence_principale`). When `NULL`,
#'   the species check is skipped (`species_valid = NA`). When `units`
#'   has no species column, the function falls back to deriving it
#'   from BD Forêt V2 if either `bdforet` or `layers` is provided.
#' @param bdforet Optional `sf` of BD Forêt V2 polygons (formation
#'   végétale layer, IGN). Used as a species fallback when `units`
#'   carries no recognisable species column. Each unit's dominant
#'   essence is derived by area-weighted intersection via
#'   [enrich_parcels_bdforet()]. Ignored when `units` already
#'   carries a species column.
#' @param layers Optional `nemeton_layers` object. When `bdforet`
#'   is `NULL`, the function attempts to resolve a `"bdforet"`
#'   vector layer from `layers` (`resolve_vector_layer(layers,
#'   "bdforet")`) and uses it as the fallback species source.
#' @param threshold_geo Minimum fraction of `aoi` area that must
#'   fall inside the validity zones. Default `0.5`.
#' @param threshold_species Minimum fraction of `units` area that
#'   must be oak + chestnut + Scots pine. Default `0.7`.
#' @param min_target Minimum per-unit RECONFORT-species share to use
#'   the RECONFORT output for that unit when routing R5
#'   (`R/indicators-deperissement.R`, lot L4). Reserved here for API
#'   parity — `check_reconfort_validity()` itself does not filter by
#'   it and only echoes it back in the result.
#'
#' @return A list with elements:
#'   * `geo_valid` (logical), `geo_intersection_pct` (numeric,
#'     fraction of AOI area inside the validity zones),
#'     `geo_dept_codes` (character vector of department codes
#'     intersected, possibly empty);
#'   * `species_valid` (logical or `NA`), `species_target_pct`
#'     (combined oak+chestnut+pine share), `species_chene_pct`,
#'     `species_chataignier_pct`, `species_pin_pct` (numeric or `NA`);
#'   * `overall_valid` (logical) — `geo_valid && (species_valid %||% TRUE)`;
#'   * `advisory` (always `TRUE`) — the check warns, it does not block;
#'   * `thresholds` (list).
#'
#' @export
check_reconfort_validity <- function(aoi,
                                     units             = NULL,
                                     bdforet           = NULL,
                                     layers            = NULL,
                                     threshold_geo     = 0.5,
                                     threshold_species = 0.7,
                                     min_target        = 0.3) {
  if (!inherits(aoi, "sf") && !inherits(aoi, "sfc")) {
    cli::cli_abort("{.arg aoi} must be an sf or sfc object.")
  }
  if (!is.null(units) && !inherits(units, "sf")) {
    cli::cli_abort("{.arg units} must be an sf object or NULL.")
  }

  zones <- load_reconfort_validity_zones()

  # Reproject to a metric CRS (Lambert-93) for area computation.
  zones_m <- sf::st_transform(zones, 2154)
  aoi_m   <- sf::st_transform(sf::st_geometry(aoi), 2154)

  inter <- suppressWarnings(sf::st_intersection(aoi_m, sf::st_union(zones_m)))
  inter_area <- if (length(inter) == 0L) 0
                else as.numeric(sum(sf::st_area(inter)))
  aoi_area   <- as.numeric(sum(sf::st_area(aoi_m)))
  geo_pct    <- if (aoi_area > 0) inter_area / aoi_area else 0
  geo_valid  <- geo_pct >= threshold_geo

  intersected <- suppressWarnings(
    sf::st_filter(zones_m, aoi_m, .predicate = sf::st_intersects)
  )
  dept_codes <- as.character(intersected$code_dept)

  species_valid <- NA
  chene_pct <- cht_pct <- pin_pct <- target_pct <- NA_real_

  if (!is.null(units) && nrow(units) > 0L) {
    col <- .pick_species_column(units)

    # Fallback : when units carries no species column, try to derive
    # it from BD Forêt V2 (direct sf or resolved from layers).
    if (is.na(col)) {
      bdforet_fb <- bdforet
      if (is.null(bdforet_fb) && !is.null(layers)) {
        bdforet_fb <- tryCatch(
          resolve_vector_layer(layers, "bdforet"),
          error = function(e) NULL
        )
      }
      if (!is.null(bdforet_fb) && inherits(bdforet_fb, "sf") &&
          nrow(bdforet_fb) > 0L) {
        enriched <- tryCatch(
          enrich_parcels_bdforet(units, bdforet_fb),
          error = function(e) NULL
        )
        if (!is.null(enriched) && "species" %in% names(enriched) &&
            any(!is.na(enriched$species))) {
          units$species <- enriched$species
          col <- "species"
          cli::cli_alert_info(
            "Species column derived from BD For\u00eat V2 (no column on {.arg units})."
          )
        }
      }
    }

    if (is.na(col)) {
      cli::cli_warn(c(
        "No species column found on {.arg units}.",
        i = "Expected one of: essence_dominante, essence, species_label, species, essence_principale.",
        i = "Pass {.arg bdforet} (sf of BD For\u00eat V2 polygons) or {.arg layers} to enable the BD For\u00eat fallback.",
        i = "Skipping species check."
      ))
    } else {
      lbl <- units[[col]]
      area <- as.numeric(sf::st_area(sf::st_transform(units, 2154)))
      total <- sum(area)
      if (total > 0) {
        chene_pct  <- sum(area[.is_chene(lbl)])         / total
        cht_pct    <- sum(area[.is_chataignier(lbl)])   / total
        pin_pct    <- sum(area[.is_pin_sylvestre(lbl)]) / total
        target_pct <- chene_pct + cht_pct + pin_pct
        species_valid <- target_pct >= threshold_species
      }
    }
  }

  overall <- geo_valid && (is.na(species_valid) || isTRUE(species_valid))

  list(
    geo_valid               = geo_valid,
    geo_intersection_pct    = geo_pct,
    geo_dept_codes          = dept_codes,
    species_valid           = species_valid,
    species_target_pct      = target_pct,
    species_chene_pct       = chene_pct,
    species_chataignier_pct = cht_pct,
    species_pin_pct         = pin_pct,
    overall_valid           = overall,
    advisory                = TRUE,
    thresholds              = list(
      geo        = threshold_geo,
      species    = threshold_species,
      min_target = min_target
    )
  )
}
