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
    grepl("\u00e9pic", s_low, fixed = FALSE) |
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
    grepl("\u00e9pic", s_low, fixed = FALSE) |
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
#' Can R5 dieback be computed here, and by which method?
#'
#' Answers, **before** any FORDEAD or RECONFORT run, whether the dieback
#' indicator applies to a set of forest units — and if not, which of the two
#' independent conditions fails. Mirrors the routing that
#' [indicateur_r5_deperissement()] performs at compute time, so a caller can
#' tell the user up front instead of showing an empty indicator after a long
#' run.
#'
#' Two conditions, deliberately reported apart:
#' \itemize{
#'   \item \strong{species} — Norway spruce / silver fir route to FORDEAD, oak /
#'     chestnut / Scots pine route to RECONFORT (same helpers the indicator
#'     uses). Without a species column, BD Foret V2 is used as a fallback.
#'   \item \strong{calibration} — the FORDEAD route was validated on five
#'     departments only (see [FORDEAD_VALIDITY_DEPARTMENTS], ONF/DSF 2024).
#'     Outside them the computation still runs, but its confidence classes are
#'     extrapolated.
#' }
#'
#' The distinction matters: a silver fir stand in the Ardennes is still a silver
#' fir stand. Reporting "out of calibration" is not the same as reporting "wrong
#' species", and conflating the two either hides a real limit or discards a
#' usable signal. RECONFORT has no published validity zone, so
#' \code{in_calibration} is \code{NA} on that route.
#'
#' @param units An sf object with the forest units.
#' @param bdforet An sf of BD Foret V2 polygons, used to derive the dominant
#'   species when \code{units} carries no species column. Optional.
#' @param layers A nemeton_layers object. Used to resolve \code{bdforet} when it
#'   is not passed directly. Optional.
#' @param resineux_col,feuillus_col Character. Columns holding a 0-1 conifer /
#'   broadleaf share, bypassing species derivation. Optional.
#' @param min_resineux,min_feuillus Numeric in \code{[0, 1]}. Minimum share for
#'   a unit to route to FORDEAD / RECONFORT. Defaults 0.3, as in
#'   [indicateur_r5_deperissement()].
#' @param threshold_geo Numeric in \code{[0, 1]}. Share of the units' extent
#'   that must fall inside the calibration zone. Default 0.5.
#'
#' @return A list with:
#'   \itemize{
#'     \item \code{status}: one of \code{"eligible_fordead"},
#'       \code{"eligible_fordead_out_of_calibration"},
#'       \code{"eligible_reconfort"}, \code{"no_species"},
#'       \code{"not_applicable"}. A \strong{stable key}, meant to be translated
#'       downstream.
#'     \item \code{method}: \code{"fordead"}, \code{"reconfort"} or \code{NA}.
#'     \item \code{in_calibration}: logical, \code{NA} on the RECONFORT route.
#'     \item \code{geo_pct}, \code{dept_codes}: extent share inside the
#'       calibration zone, and the departments met.
#'     \item \code{resineux_pct}, \code{feuillus_pct}: share of units routed to
#'       each method.
#'     \item \code{n_units}, \code{n_fordead}, \code{n_reconfort}.
#'     \item \code{per_unit}: data.frame (\code{share_resineux},
#'       \code{share_feuillus}, \code{method}) — the routing is per unit, a
#'       mixed massif is not an all-or-nothing verdict.
#'   }
#'
#' @seealso [check_fordead_validity()], [indicateur_r5_deperissement()]
#' @export
#'
#' @examples
#' \dontrun{
#' ap <- r5_applicabilite(units, bdforet = bdforet)
#' if (ap$status == "eligible_fordead_out_of_calibration") {
#'   message("Espece correcte, hors des 5 departements de calibration ONF/DSF")
#' }
#' }
r5_applicabilite <- function(units,
                             bdforet       = NULL,
                             layers        = NULL,
                             resineux_col  = NULL,
                             feuillus_col  = NULL,
                             min_resineux  = 0.3,
                             min_feuillus  = 0.3,
                             threshold_geo = 0.5) {
  if (!inherits(units, "sf")) {
    cli::cli_abort("{.arg units} must be an sf object.")
  }
  n <- nrow(units)

  out <- function(status, method = NA_character_, in_calibration = NA,
                  geo_pct = NA_real_, dept_codes = character(0),
                  res_pct = NA_real_, feu_pct = NA_real_,
                  per_unit = NULL) {
    list(status = status, method = method, in_calibration = in_calibration,
         geo_pct = geo_pct, dept_codes = dept_codes,
         resineux_pct = res_pct, feuillus_pct = feu_pct,
         n_units = n,
         n_fordead = if (is.null(per_unit)) 0L else sum(per_unit$method == "fordead", na.rm = TRUE),
         n_reconfort = if (is.null(per_unit)) 0L else sum(per_unit$method == "reconfort", na.rm = TRUE),
         per_unit = per_unit)
  }

  if (n == 0L) return(out("not_applicable"))

  # --- Espèce : même dérivation que check_fordead_validity(), pour que les deux
  # fonctions ne puissent pas diverger sur le même jeu de données.
  units_sp <- .r5_with_species(units, bdforet = bdforet, layers = layers)
  has_species <- !is.na(.pick_species_column(units_sp)) ||
    !is.null(resineux_col) || !is.null(feuillus_col)

  # --- Géographie : part de l'emprise dans la zone de calibration FORDEAD.
  geo <- .r5_calibration_share(units)

  if (!has_species) {
    return(out("no_species", geo_pct = geo$pct, dept_codes = geo$dept_codes,
               in_calibration = geo$pct >= threshold_geo))
  }

  share_res <- .resolve_resineux_share(units_sp, resineux_col)
  share_feu <- .resolve_reconfort_share(units_sp, feuillus_col)
  if (!is.null(resineux_col) && is.null(feuillus_col)) share_feu[] <- 0
  if (!is.null(feuillus_col) && is.null(resineux_col)) share_res[] <- 0

  # Routage par unité, identique à celui d'indicateur_r5_deperissement() : le
  # feuillus l'emporte à égalité, un massif mixte n'est pas un verdict global.
  method <- rep(NA_character_, n)
  is_rec <- !is.na(share_feu) & share_feu >= min_feuillus &
    (is.na(share_res) | share_feu >= share_res)
  is_for <- !is.na(share_res) & share_res >= min_resineux & !is_rec
  method[is_rec] <- "reconfort"
  method[is_for] <- "fordead"

  per_unit <- data.frame(share_resineux = share_res,
                         share_feuillus = share_feu,
                         method = method,
                         stringsAsFactors = FALSE)
  res_pct <- mean(is_for)
  feu_pct <- mean(is_rec)

  if (!any(is_for) && !any(is_rec)) {
    return(out("not_applicable", geo_pct = geo$pct, dept_codes = geo$dept_codes,
               in_calibration = geo$pct >= threshold_geo,
               res_pct = res_pct, feu_pct = feu_pct, per_unit = per_unit))
  }

  # La méthode dominante décide du statut rendu ; `per_unit` garde le détail.
  if (sum(is_for) >= sum(is_rec)) {
    in_calib <- geo$pct >= threshold_geo
    status <- if (in_calib) "eligible_fordead" else "eligible_fordead_out_of_calibration"
    return(out(status, method = "fordead", in_calibration = in_calib,
               geo_pct = geo$pct, dept_codes = geo$dept_codes,
               res_pct = res_pct, feu_pct = feu_pct, per_unit = per_unit))
  }
  # RECONFORT n'a pas de zone de validité publiée : `in_calibration` reste NA
  # plutôt que FALSE, qui laisserait croire à un hors-zone constaté.
  out("eligible_reconfort", method = "reconfort", in_calibration = NA,
      geo_pct = geo$pct, dept_codes = geo$dept_codes,
      res_pct = res_pct, feu_pct = feu_pct, per_unit = per_unit)
}


# Part de l'emprise des unités tombant dans la zone de calibration FORDEAD.
.r5_calibration_share <- function(units) {
  zones_m <- sf::st_transform(load_fordead_validity_zones(), 2154)
  u_m <- sf::st_transform(sf::st_geometry(units), 2154)
  inter <- suppressWarnings(sf::st_intersection(u_m, sf::st_union(zones_m)))
  inter_area <- if (length(inter) == 0L) 0 else as.numeric(sum(sf::st_area(inter)))
  total <- as.numeric(sum(sf::st_area(u_m)))
  hit <- suppressWarnings(sf::st_filter(zones_m, u_m, .predicate = sf::st_intersects))
  list(pct = if (total > 0) inter_area / total else 0,
       dept_codes = as.character(hit$code_dept))
}


# Colonne d'essence, dérivée de la BD Forêt V2 quand `units` n'en porte pas.
.r5_with_species <- function(units, bdforet = NULL, layers = NULL) {
  if (!is.na(.pick_species_column(units))) return(units)
  bd <- bdforet
  if (is.null(bd) && !is.null(layers)) {
    bd <- tryCatch(resolve_vector_layer(layers, "bdforet"), error = function(e) NULL)
  }
  if (is.null(bd) || !inherits(bd, "sf") || nrow(bd) == 0L) return(units)
  enriched <- tryCatch(enrich_parcels_bdforet(units, bd), error = function(e) NULL)
  if (!is.null(enriched) && "species" %in% names(enriched) &&
      any(!is.na(enriched$species))) {
    units$species <- enriched$species
    cli::cli_alert_info(
      "Species column derived from BD Forêt V2 (no column on {.arg units})."
    )
  }
  units
}


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
