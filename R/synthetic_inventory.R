#' Synthetic inventory from a Canopy Height Model (NDP 1)
#'
#' Derive a coarse stand-level inventory (quadratic mean diameter
#' \eqn{D_g} and stems per hectare \eqn{N}) for each spatial unit
#' directly from a CHM, a species code and (optionally) a stand age.
#' This is the \emph{NDP 1 synthetic} path between NDP 0 (public
#' raster/vector data only) and NDP 2 (actual terrain measurements),
#' introduced alongside the Open-Canopy CHM integration (spec 005
#' phase 6+) so that indicators depending on \eqn{D_g} or \eqn{N}
#' (P1, P3, E1) do not have to silently fail at NDP 0.
#'
#' The method is intentionally simple: \eqn{H_{dom}} is extracted
#' from the CHM per unit, inverted to a plausible \eqn{D_g} through a
#' species-specific linear allometry, and the resulting \eqn{D_g} is
#' fed to the Charru 2012 self-thinning relationship to obtain the
#' maximum stand density at that diameter. A user-tunable stocking
#' fraction (default 0.75) is applied to reflect the typical ratio
#' of observed density to the self-thinning boundary in French
#' managed stands.
#'
#' @name synthetic_inventory
#' @keywords internal
NULL


# ============================================================
# H_dom -> D_g allometric coefficients (power law)
# ============================================================

# Power-law allometry D_g[cm] = a_species * H_dom[m]^b.
# b = 0.9 is a gently sub-linear shape: at low H young stands
# retain a D_g floor, and at high H diameter still grows but
# slower than strictly proportional to height — consistent with
# published yield-table behaviour and with Eichhorn's law at
# constant site.
# For each species, a is calibrated so that D_g(H_0_mean_IFN)
# equals the IFN mean D_g reported in:
#   * Charru et al. 2012 Table 1 (mean D_g per species across
#     the French NFI), and
#   * Charru et al. 2017 Table 1 (mean H_0 per species in the
#     same resource, when present).
# dq_min / dq_max are the observed Dg bounds from Charru 2012
# Table 1, used as clamps to prevent extrapolation mishaps.
#
# Species not in Charru 2017 (PSME, PIPI, PILA) have a derived
# from Charru 2012 D_g mean and a typical IFN 2004 H_0 mean —
# less anchored but better than a flat slope.
# CASA / POSP have no Charru coverage; fall back to broadleaf
# genus defaults.
.h_to_dq_params <- data.frame(
  species = c("QUPU", "QURO", "QUPE", "FASY",
              "PIAB", "ABAL", "PISY", "PIPI",
              "PIHA", "PILA", "PSME",
              "CASA", "POSP"),
  # a = D_g_IFN_mean / H_0_IFN_mean^0.9 (Charru 2012 x 2017).
  # Values chosen so that D_g(H_0_ref) = D_g_ref within <0.1 cm.
  a = c(1.928, 1.646, 1.351, 1.523,
        1.646, 1.615, 1.922, 2.050,
        2.431, 2.058, 1.551,
        1.45,  1.45),
  b = rep(0.9, 13L),
  dq_min = c(15, 15, 15, 16,
             15, 15, 14, 16,
             15, 18, 20,
             12, 12),
  dq_max = c(37, 37, 30, 40,
             45, 45, 33, 37,
             40, 50, 50,
             50, 50),
  stringsAsFactors = FALSE
)

# Fallbacks by functional type (power-law a, b = 0.9). Derived
# from per-genus averages of the tabulated species above:
# broadleaf mean a ≈ 1.57, conifer mean a ≈ 1.90.
.h_to_dq_fallback <- c(broadleaf = 1.57, conifer = 1.90)


#' H_dom -> D_g calibration table (IFN / Charru)
#'
#' Returns the species-keyed power-law parameters used by
#' \code{\link{estimate_dq_from_hdom}}. The \code{a} column is
#' calibrated so that \eqn{a \cdot H_0^{0.9} = D_g} for the mean
#' IFN \eqn{(H_0, D_g)} pair of each species (Charru et al. 2012
#' Table 1 x Charru et al. 2017 Table 1). The \code{dq_min} /
#' \code{dq_max} columns are the observed Dg range boundaries
#' from Charru 2012 Table 1.
#'
#' @return A data.frame with columns \code{species, a, b, dq_min,
#'   dq_max}.
#'
#' @examples
#' h_to_dq_params()
#'
#' @export
h_to_dq_params <- function() {
  .h_to_dq_params
}


#' Estimate a quadratic mean diameter from dominant height
#'
#' Applies a species-specific power-law allometry
#' \deqn{D_g \approx a_{species} \cdot H_{dom}^b}
#' with \eqn{b = 0.9} (gently sub-linear). The per-species
#' \eqn{a_{species}} is calibrated against the mean
#' \eqn{(H_0, D_g)} pair observed in the French National Forest
#' Inventory — i.e. Charru et al. 2012 Table 1 (mean \eqn{D_g})
#' crossed with Charru et al. 2017 Table 1 (mean \eqn{H_0}) for
#' the 8 species covered by both, with extensions using typical
#' IFN H_0 values for PSME, PIPI, PILA, and broadleaf-genus
#' defaults for CASA and POSP.
#'
#' The relationship is valid only for pure even-aged stands.
#' Multi-layered or strongly irregular stands will still be
#' approximated — the estimate then reflects a biased mean
#' diameter of the dominant social position. The output is
#' clamped to the observed \eqn{D_g} range of each species
#' (Charru 2012 Table 1) to avoid extrapolation artefacts at
#' very small or very large \eqn{H_{dom}}.
#'
#' @param H_dom Numeric vector. Dominant height in metres.
#' @param species Character vector of IFN species codes
#'   (recycled against \code{H_dom}).
#'
#' @return Numeric vector of estimated \eqn{D_g} in cm, clamped
#'   to each species' observed range. \code{NA} when
#'   \code{H_dom} is \code{NA}, non-positive or below 6 m
#'   (stands too young for this allometry).
#'
#' @examples
#' estimate_dq_from_hdom(H_dom = 25, species = "FASY")
#' estimate_dq_from_hdom(
#'   H_dom   = c(18, 25, 30),
#'   species = c("QUPE", "FASY", "PIAB")
#' )
#'
#' @export
estimate_dq_from_hdom <- function(H_dom, species) {
  n <- max(length(H_dom), length(species))
  if (n == 0) return(numeric(0))
  H_dom   <- rep_len(as.numeric(H_dom), n)
  species <- rep_len(as.character(species), n)

  tab <- .h_to_dq_params
  out <- rep(NA_real_, n)

  for (i in seq_len(n)) {
    h <- H_dom[i]
    s <- toupper(species[i])
    if (is.na(h) || is.na(s) || h < 6) next

    idx <- match(s, tab$species)
    if (is.na(idx)) {
      # Unknown species -> functional-type fallback, with broad
      # bounds borrowed from the most representative genus member.
      a <- if (is_conifer(s)) .h_to_dq_fallback[["conifer"]]
           else .h_to_dq_fallback[["broadleaf"]]
      b <- 0.9
      lo <- if (is_conifer(s)) 15 else 15
      hi <- if (is_conifer(s)) 50 else 50
    } else {
      a  <- tab$a[idx]
      b  <- tab$b[idx]
      lo <- tab$dq_min[idx]
      hi <- tab$dq_max[idx]
    }

    dq_raw <- a * h^b
    out[i] <- pmin(pmax(dq_raw, lo), hi)
  }
  out
}


# ============================================================
# Main orchestrator
# ============================================================

#' Estimate a synthetic stand inventory per unit
#'
#' Given an \code{sf} of spatial units, a \code{SpatRaster} CHM and
#' a species vector, returns \code{D_g} (cm) and stem density
#' (stems / ha) per unit by chaining:
#' \enumerate{
#'   \item \code{\link{extract_h_dom}} to get \eqn{H_{dom}} per unit;
#'   \item \code{\link{estimate_dq_from_hdom}} for \eqn{D_g};
#'   \item \code{\link{n_max_selfthinning}} (Charru 2012) times a
#'         \code{stocking} fraction for \eqn{N}.
#' }
#'
#' @param units sf polygon layer.
#' @param chm A \code{SpatRaster} canopy height model.
#' @param species Character vector of IFN species codes, length
#'   \code{nrow(units)}.
#' @param h_dom_percentile Numeric. Percentile of CHM pixels taken
#'   as dominant height per unit (default 0.9). Ignored when \code{H_dom}
#'   is already present in \code{units}.
#' @param stocking Numeric in \code{(0, 1]}. Fraction of
#'   self-thinning maximum density used as the expected actual
#'   density (default 0.75, i.e. 75% of N_max, a realistic value for
#'   French managed stands).
#' @param min_stand_height Numeric (m). Dominant height below which a
#'   unit is treated as carrying \strong{no standing stock} (clear-cut,
#'   cleared or non-forest): its \code{dbh} and \code{density} are set to
#'   \code{0} rather than \code{NA}, so volume/quality indicators return
#'   \code{0} for a felled stand instead of a cryptic \code{NA}. Default
#'   \code{1.3} (breast height). Only applies when \eqn{H_{dom}} is
#'   observed (non-\code{NA}); an \code{NA} \eqn{H_{dom}} (no CHM
#'   coverage) stays \code{NA}.
#'
#' @return A data.frame with one row per unit containing
#'   \code{H_dom} (m), \code{dbh} (cm, the quadratic mean
#'   diameter), \code{density} (stems / ha), and \code{source}
#'   (always "synthetic_ml") columns. Units below
#'   \code{min_stand_height} get \code{dbh = 0} and \code{density = 0}.
#'
#' @examples
#' \dontrun{
#' inv <- estimate_synthetic_inventory(
#'   units   = ugf,
#'   chm     = chm_clean,
#'   species = ugf$species,
#'   stocking = 0.75
#' )
#' ugf$dbh     <- inv$dbh
#' ugf$density <- inv$density
#' }
#'
#' @export
estimate_synthetic_inventory <- function(units, chm, species,
                                         h_dom_percentile = 0.9,
                                         stocking = 0.75,
                                         min_stand_height = 1.3) {
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }
  if (!inherits(chm, "SpatRaster")) {
    stop("chm must be a terra SpatRaster", call. = FALSE)
  }
  if (!is.numeric(stocking) || length(stocking) != 1L ||
      is.na(stocking) || stocking <= 0 || stocking > 1) {
    stop("stocking must be a scalar in (0, 1]", call. = FALSE)
  }
  if (!is.numeric(min_stand_height) || length(min_stand_height) != 1L ||
      is.na(min_stand_height) || min_stand_height < 0) {
    stop("min_stand_height must be a non-negative scalar", call. = FALSE)
  }

  n <- nrow(units)
  species <- rep_len(as.character(species), n)

  if ("H_dom" %in% names(units)) {
    h_dom <- as.numeric(units[["H_dom"]])
  } else {
    h_dom <- extract_h_dom(chm, units, percentile = h_dom_percentile)
  }

  dq <- estimate_dq_from_hdom(h_dom, species)
  n_max <- n_max_selfthinning(dq, species)
  density <- stocking * n_max

  # spec 005 amendment (v0.107.0) — "no canopy" vs "too young". A unit
  # whose H_dom is *observed* (non-NA) but below breast height
  # (`min_stand_height`, 1.3 m) carries NO standing stock: clear-cut,
  # cleared, or non-forest. There D_g and N are 0, not NA, so the
  # downstream volume/quality indicators (P1, P3, E1) return 0 —
  # the correct answer for a felled stand — instead of a cryptic NA.
  # Distinct from a young stand (min_stand_height <= H_dom < 6 m) where
  # the mature-stand allometry is not calibrated and estimate_dq_from_hdom
  # rightly yields NA, and from H_dom = NA (no CHM coverage) which stays
  # NA (genuinely unknown).
  no_stand <- !is.na(h_dom) & h_dom < min_stand_height
  dq[no_stand]      <- 0
  density[no_stand] <- 0

  data.frame(
    H_dom   = h_dom,
    dbh     = dq,
    density = density,
    source  = rep("synthetic_ml", n),
    stringsAsFactors = FALSE
  )
}


#' Fill in missing inventory fields from a CHM
#'
#' Convenience wrapper around
#' \code{\link{estimate_synthetic_inventory}} that mutates an
#' \code{sf} in place: fills the \code{dbh_field} / \code{density_field}
#' columns only when they are absent or fully \code{NA}, leaves any
#' partial user-provided values intact, and tags the result with the
#' attribute \code{inventory_source = "synthetic_ml"} when
#' substitution actually occurred. Designed to be called at the top
#' of any indicator function that depends on \eqn{D_g} and \eqn{N}.
#'
#' @param units sf object.
#' @param species_field Character. Column holding species codes
#'   (default "species").
#' @param dbh_field Character. Column expected to hold \eqn{D_g}
#'   (default "dbh").
#' @param density_field Character. Column expected to hold stems / ha
#'   (default "density").
#' @param chm Optional \code{SpatRaster} CHM. When \code{NULL}, the
#'   function is a no-op.
#' @param stocking Stocking fraction (see
#'   \code{\link{estimate_synthetic_inventory}}).
#' @param h_dom_percentile Percentile for \eqn{H_{dom}} extraction.
#' @param min_stand_height Numeric (m). Dominant height below which a
#'   unit is treated as carrying no standing stock (\code{dbh} /
#'   \code{density} filled with \code{0}, not \code{NA}); see
#'   \code{\link{estimate_synthetic_inventory}}. Default \code{1.3}.
#'
#' @return The input \code{sf} with \code{dbh_field} and
#'   \code{density_field} filled (when possible). The
#'   \code{inventory_source} attribute is set to "synthetic_ml" iff
#'   at least one field was filled from the CHM.
#'
#' @keywords internal
#' @export
ensure_inventory_fields <- function(units,
                                    species_field = "species",
                                    dbh_field     = "dbh",
                                    density_field = "density",
                                    chm = NULL,
                                    stocking = 0.75,
                                    h_dom_percentile = 0.9,
                                    min_stand_height = 1.3) {
  if (is.null(chm)) return(units)
  if (!species_field %in% names(units)) return(units)

  has_dbh <- dbh_field %in% names(units) &&
    !all(is.na(units[[dbh_field]]))
  has_dens <- density_field %in% names(units) &&
    !all(is.na(units[[density_field]]))
  if (has_dbh && has_dens) return(units)

  inv <- tryCatch(
    estimate_synthetic_inventory(
      units            = units,
      chm              = chm,
      species          = units[[species_field]],
      h_dom_percentile = h_dom_percentile,
      stocking         = stocking,
      min_stand_height = min_stand_height
    ),
    error = function(e) {
      cli::cli_warn("ensure_inventory_fields: {e$message}")
      NULL
    }
  )
  if (is.null(inv)) return(units)

  filled <- FALSE
  if (!has_dbh) {
    units[[dbh_field]] <- inv$dbh
    filled <- TRUE
  }
  if (!has_dens) {
    units[[density_field]] <- inv$density
    filled <- TRUE
  }
  if (filled) {
    attr(units, "inventory_source") <- "synthetic_ml"
    cli::cli_alert_info(
      "Synthetic inventory (CHM \u2192 D_g \u2192 N via Charru 2012) \\
       filled on {nrow(units)} UGF"
    )
  }
  units
}
