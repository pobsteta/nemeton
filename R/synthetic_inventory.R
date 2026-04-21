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
# H_dom -> D_g allometric coefficients
# ============================================================

# Rough H_dom -> D_g slopes for mature even-aged stands, in cm per m.
# Values are order-of-magnitude and consistent with IFN 2004 sample
# statistics (mean H_0 vs mean D_g per species); to be refined from
# yield tables when available. Keys are the IFN 4-letter codes.
.h_to_dq_slope <- c(
  QUPU = 1.20, QURO = 1.05, QUPE = 1.00, FASY = 0.95, CASA = 1.00,
  PIAB = 0.90, ABAL = 0.90, PSME = 0.85,
  PISY = 0.95, PIPI = 1.00, PIHA = 1.10, PILA = 0.90,
  POSP = 1.00
)

# Fallbacks by functional type
.h_to_dq_fallback <- c(broadleaf = 1.00, conifer = 0.90)


#' Estimate a quadratic mean diameter from dominant height
#'
#' Applies a species-specific linear allometry
#' \deqn{D_g \approx k_{species} \cdot H_{dom}}
#' and falls back to a genus-level coefficient when the species is
#' not tabulated. The relationship is valid only for pure even-aged
#' mature stands; very young or multi-layered stands will be poorly
#' approximated.
#'
#' @param H_dom Numeric vector. Dominant height in metres.
#' @param species Character vector of IFN species codes
#'   (recycled against \code{H_dom}).
#'
#' @return Numeric vector of estimated \eqn{D_g} in cm. \code{NA} when
#'   \code{H_dom} is \code{NA}, non-positive or below 6 m (stands too
#'   young for this allometry).
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

  out <- rep(NA_real_, n)
  for (i in seq_len(n)) {
    h <- H_dom[i]
    s <- species[i]
    if (is.na(h) || is.na(s) || h < 6) next
    k <- .h_to_dq_slope[toupper(s)]
    if (length(k) == 0 || is.na(k)) {
      k <- if (is_conifer(s)) .h_to_dq_fallback["conifer"]
           else .h_to_dq_fallback["broadleaf"]
    }
    out[i] <- as.numeric(k) * h
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
#'
#' @return A data.frame with one row per unit containing
#'   \code{H_dom} (m), \code{dbh} (cm, the quadratic mean
#'   diameter), \code{density} (stems / ha), and \code{source}
#'   (always "synthetic_ml") columns.
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
                                         stocking = 0.75) {
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
                                    h_dom_percentile = 0.9) {
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
      stocking         = stocking
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
