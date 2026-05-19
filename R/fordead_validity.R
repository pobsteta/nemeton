# ============================================================
# fordead_validity.R — FORDEAD calibration validity check
# ------------------------------------------------------------
# Implements guard-rail G3 of spec 008 (suivi sanitaire) :
# the FORDEAD method is calibrated only on the five French
# departments studied by Bernard & Doridant (ONF/DSF) 2024
# and on coniferous stands dominated by Norway spruce (EPC,
# Picea abies) and silver fir (SAP, Abies alba). Outside
# these conditions, alerts must be flagged with a UI banner
# (and the R5 dieback indicator falls back to NA — see spec
# 008 §7).
# ============================================================


#' Department codes covered by the FORDEAD calibration validity zone
#'
#' INSEE codes of the five French departments studied by Bernard &
#' Doridant (ONF/DSF) 2024: Vosges (88), Jura (39), Ain (01),
#' Savoie (73), Haute-Savoie (74).
#'
#' @export
FORDEAD_VALIDITY_DEPARTMENTS <- c("88", "39", "01", "73", "74")


#' Conifer species considered valid by the FORDEAD calibration
#'
#' Two-letter ONF/DSF codes for Norway spruce and silver fir.
#'
#' @export
FORDEAD_VALIDITY_SPECIES <- c("EPC", "SAP")


# In-package cache for the (small) GeoJSON layer so we don't pay
# the sf::st_read() cost on every check_fordead_validity() call.
.fordead_validity_cache <- new.env(parent = emptyenv())


#' Load the FORDEAD validity zones layer
#'
#' Reads `inst/extdata/fordead_validity_zones.geojson` (five
#' department polygons in EPSG:4326) and caches the result for
#' the lifetime of the R session.
#'
#' @return An `sf` object with columns `code_dept`, `nom_dept`,
#'   `source`, `reference` and `geometry` (MULTIPOLYGON, EPSG:4326).
#' @export
load_fordead_validity_zones <- function() {
  if (is.null(.fordead_validity_cache$zones)) {
    p <- system.file("extdata", "fordead_validity_zones.geojson",
                     package = "nemeton")
    if (!nzchar(p)) {
      cli::cli_abort(c(
        "Cannot find {.file fordead_validity_zones.geojson}.",
        i = "Run {.code Rscript data-raw/build_fordead_validity_zones.R} to (re)build it."
      ))
    }
    .fordead_validity_cache$zones <- sf::st_read(p, quiet = TRUE)
  }
  .fordead_validity_cache$zones
}


# Match Norway spruce. ONF/DSF code "EPC" or any French / Latin
# label containing "epicea" / "épicéa" / "picea".
.is_epicea <- function(x) {
  x <- as.character(x)
  out <- rep(FALSE, length(x))
  out[is.na(x)] <- FALSE
  m <- !is.na(x)
  s <- x[m]
  s_low <- tolower(s)
  hit <- grepl("\\bepc\\b", s, ignore.case = TRUE) |
    grepl("epic", s_low, fixed = FALSE) |
    grepl("épic", s_low, fixed = FALSE) |
    grepl("picea", s_low, fixed = FALSE)
  out[m] <- hit
  out
}


# Match silver fir (Abies alba). Excludes Douglas fir
# (Pseudotsuga menziesii) — the French language often lumps it
# under "sapin de Douglas", but it is botanically distinct and
# not part of the FORDEAD calibration. Also excludes "Picea
# abies" (Norway spruce, Latin name collision: "abies" is both
# the genus of fir and the species epithet of spruce).
.is_sapin_pectine <- function(x) {
  x <- as.character(x)
  out <- rep(FALSE, length(x))
  m <- !is.na(x)
  s <- x[m]
  s_low <- tolower(s)
  is_douglas <- grepl("douglas", s_low, fixed = TRUE) |
    grepl("pseudotsuga", s_low, fixed = TRUE)
  is_picea <- grepl("picea", s_low, fixed = TRUE) |
    grepl("épic", s_low, fixed = FALSE) |
    grepl("epicea", s_low, fixed = TRUE)
  hit <- (
    grepl("\\bsap\\b", s, ignore.case = TRUE) |
      grepl("sapin", s_low, fixed = TRUE) |
      grepl("abies", s_low, fixed = TRUE)
  ) & !is_douglas & !is_picea
  out[m] <- hit
  out
}


# Pick the column carrying the dominant species label. Priority
# order matches spec 008 §3.7 (R/fordead_validity.R contract).
.pick_species_column <- function(units) {
  candidates <- c("essence_dominante", "essence", "species_label",
                  "species", "essence_principale")
  hit <- candidates[candidates %in% names(units)]
  if (length(hit) == 0L) return(NA_character_)
  hit[1L]
}


#' Check whether an AOI lies within the FORDEAD calibration domain
#'
#' Implements guard-rail G3 (spec 008): an AOI is "valid" for FORDEAD
#' if (i) it intersects the five validated departments by more than
#' `threshold_geo` of its area and (ii) the user-provided forest
#' units are dominated by spruce + fir at more than
#' `threshold_species` of their cumulated area.
#'
#' @param aoi An `sf` polygon (any CRS); the project area of interest.
#' @param units Optional `sf` of forest management units. Must carry
#'   a species label column (one of `essence_dominante`, `essence`,
#'   `species_label`, `species`, `essence_principale`). When `NULL`,
#'   the species check is skipped (`species_valid = NA`). When `units`
#'   has no species column, the function falls back to deriving it
#'   from BD Forêt V2 if either `bdforet` or `layers` is provided
#'   (see below).
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
#'   Convenient when the caller already holds a project-wide
#'   layer registry.
#' @param threshold_geo Minimum fraction of `aoi` area that must
#'   fall inside the validity zones. Default `0.5`.
#' @param threshold_species Minimum fraction of `units` area that
#'   must be Norway spruce + silver fir. Default `0.7` (consistent
#'   with the ONF/DSF 2024 calibration sample).
#' @param min_resineux Minimum per-unit conifer share to use the
#'   FORDEAD output for that unit when computing R5
#'   (`R/indicators-deperissement.R`). Reserved here for API
#'   parity — `check_fordead_validity()` itself does not filter
#'   by it and only echoes it back in the result.
#'
#' @return A list with elements:
#'   * `geo_valid` (logical), `geo_intersection_pct` (numeric,
#'     fraction of AOI area inside the validity zones),
#'     `geo_dept_codes` (character vector of department codes
#'     intersected, possibly empty);
#'   * `species_valid` (logical or `NA`), `species_resineux_pct`,
#'     `species_epc_pct`, `species_sap_pct` (numeric or `NA`);
#'   * `overall_valid` (logical) — `geo_valid && (species_valid %||% TRUE)`.
#'
#' @export
check_fordead_validity <- function(aoi,
                                   units             = NULL,
                                   bdforet           = NULL,
                                   layers            = NULL,
                                   threshold_geo     = 0.5,
                                   threshold_species = 0.7,
                                   min_resineux      = 0.3) {
  if (!inherits(aoi, "sf") && !inherits(aoi, "sfc")) {
    cli::cli_abort("{.arg aoi} must be an sf or sfc object.")
  }
  if (!is.null(units) && !inherits(units, "sf")) {
    cli::cli_abort("{.arg units} must be an sf object or NULL.")
  }

  zones <- load_fordead_validity_zones()

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
  epc_pct <- sap_pct <- res_pct <- NA_real_

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
            "Species column derived from BD Forêt V2 (no column on {.arg units})."
          )
        }
      }
    }

    if (is.na(col)) {
      cli::cli_warn(c(
        "No species column found on {.arg units}.",
        i = "Expected one of: essence_dominante, essence, species_label, species, essence_principale.",
        i = "Pass {.arg bdforet} (sf of BD Forêt V2 polygons) or {.arg layers} to enable the BD Forêt fallback.",
        i = "Skipping species check."
      ))
    } else {
      lbl <- units[[col]]
      area <- as.numeric(sf::st_area(sf::st_transform(units, 2154)))
      total <- sum(area)
      if (total > 0) {
        epc_pct <- sum(area[.is_epicea(lbl)])         / total
        sap_pct <- sum(area[.is_sapin_pectine(lbl)])  / total
        res_pct <- epc_pct + sap_pct
        species_valid <- res_pct >= threshold_species
      }
    }
  }

  overall <- geo_valid && (is.na(species_valid) || isTRUE(species_valid))

  list(
    geo_valid            = geo_valid,
    geo_intersection_pct = geo_pct,
    geo_dept_codes       = dept_codes,
    species_valid        = species_valid,
    species_resineux_pct = res_pct,
    species_epc_pct      = epc_pct,
    species_sap_pct      = sap_pct,
    overall_valid        = overall,
    thresholds           = list(
      geo          = threshold_geo,
      species      = threshold_species,
      min_resineux = min_resineux
    )
  )
}
