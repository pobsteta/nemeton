#' Species self-thinning relationships (Charru et al. 2012)
#'
#' Lookup table of \eqn{\ln(N_{max}) = a + b \ln(D_g) + c \ln(D_g)^2}
#' coefficients estimated from French National Forest Inventory data
#' for 11 temperate and Mediterranean tree species, published in:
#'
#' Charru, M., Seynave, I., Morneau, F., Rivoire, M. & Bontemps, J.-D.
#' (2012). \emph{Significant differences and curvilinearity in the
#' self-thinning relationships of 11 temperate tree species assessed
#' from forest inventory data.} Annals of Forest Science 69(2),
#' 195-205. (HAL: hal-00930719).
#'
#' When the quadratic term was significant in the paper (7 species),
#' the curvilinear model (Table 5) is used. Otherwise the linear
#' self-thinning line (Table 2) is retained.
#'
#' @name density_selfthinning
#' @keywords internal
NULL


# ============================================================
# Coefficients table
# ============================================================

# Columns: species (IFN-style 4-letter code), model ("linear" | "quad"),
# a (intercept), b (slope on ln Dg), c (quadratic coeff), dg_min / dg_max
# (observed validity range in cm).
.charru_selfthinning <- data.frame(
  # IFN code, preferred model, a, b, c, dg_min, dg_max
  species = c("QUPU", "QURO", "QUPE", "FASY",
              "PISY", "PIHA", "PILA", "PIPI",
              "PIAB", "ABAL", "PSME"),
  model   = c("linear", "linear", "linear", "quad",
              "quad",   "quad",   "linear", "quad",
              "quad",   "quad",   "quad"),
  a = c(12.270, 12.138, 12.681,  9.790,
         2.279,  9.575, 12.104,  9.307,
        10.043,  4.700,  0.607),
  b = c(-1.809, -1.758, -1.911,  0.000,
         4.701,  0.000, -1.653,  0.000,
         0.000,  3.000,  5.192),
  c = c( 0.000,  0.000,  0.000, -0.296,
        -1.023, -0.299,  0.000, -0.272,
        -0.287, -0.718, -1.009),
  dg_min = c(15, 15, 15, 16, 16, 15, 18, 16, 15, 15, 20),
  dg_max = c(37, 37, 30, 40, 33, 40, 40, 37, 40, 45, 50),
  stringsAsFactors = FALSE
)


#' Charru 2012 self-thinning coefficients table
#'
#' Returns the species-keyed lookup table used by
#' \code{\link{n_max_selfthinning}}.
#'
#' @return A data.frame with columns \code{species, model, a, b, c,
#'   dg_min, dg_max}.
#'
#' @examples
#' charru_selfthinning_table()
#'
#' @export
charru_selfthinning_table <- function() {
  .charru_selfthinning
}


# ============================================================
# N_max(D_g, species)
# ============================================================

#' Maximum stand density under self-thinning (Charru 2012)
#'
#' Returns the upper boundary of the stems-per-hectare / quadratic-
#' mean-diameter relationship for a given species, i.e. the density
#' a fully stocked pure even-aged stand would sustain at the given
#' \eqn{D_g}. Equation:
#' \deqn{\ln(N_{max}) = a + b \ln(D_g) + c \ln(D_g)^2}
#' where \eqn{N_{max}} is in stems / ha and \eqn{D_g} in cm.
#'
#' Species not present in the Charru table fall back to a
#' genus-level proxy:
#' \itemize{
#'   \item conifers (in \code{is_conifer()}) \eqn{\to} \code{PSME}
#'         (Douglas-fir)
#'   \item broadleaves \eqn{\to} \code{FASY} (common beech)
#' }
#'
#' Values are clamped to the \code{[dg_min, dg_max]} range of the
#' species when \code{clamp = TRUE} (default) because the self-thinning
#' relationship was calibrated only over that range and extrapolates
#' poorly.
#'
#' @param dq Numeric vector. Quadratic mean diameter in cm.
#' @param species Character vector of IFN-style species codes
#'   (recycled against \code{dq}).
#' @param clamp Logical. If \code{TRUE}, clamp \code{dq} to the
#'   observed range of the species.
#'
#' @return Numeric vector of maximum stems/ha. \code{NA} when the
#'   species cannot be resolved or \code{dq} is \code{NA} / non-
#'   positive.
#'
#' @examples
#' # Common beech, D_g = 30 cm
#' n_max_selfthinning(dq = 30, species = "FASY")
#'
#' # Vector input
#' n_max_selfthinning(
#'   dq      = c(20, 30, 40),
#'   species = c("QUPE", "FASY", "PIAB")
#' )
#'
#' @export
n_max_selfthinning <- function(dq, species, clamp = TRUE) {
  n <- max(length(dq), length(species))
  if (n == 0) return(numeric(0))
  dq      <- rep_len(dq, n)
  species <- rep_len(as.character(species), n)

  tab <- .charru_selfthinning
  out <- rep(NA_real_, n)

  for (i in seq_len(n)) {
    d <- dq[i]
    s <- species[i]
    if (is.na(d) || is.na(s) || d <= 0) next

    sp_key <- .resolve_species_selfthinning(s, tab$species)
    if (is.na(sp_key)) next

    row <- tab[tab$species == sp_key, ]
    d_use <- if (clamp) pmin(pmax(d, row$dg_min), row$dg_max) else d
    ld <- log(d_use)
    out[i] <- exp(row$a + row$b * ld + row$c * ld^2)
  }
  out
}


# Map an arbitrary species code to one that has a self-thinning
# curve. Reuses the conifer list declared in R/site_index.R.
.resolve_species_selfthinning <- function(species, available) {
  if (is.na(species)) return(NA_character_)
  sp <- toupper(species)
  if (sp %in% available) return(sp)
  if (is_conifer(sp)) {
    if ("PSME" %in% available) return("PSME")
  } else {
    if ("FASY" %in% available) return("FASY")
  }
  NA_character_
}
