#' Climate-driven BAI drift (Charru et al. 2017)
#'
#' Per-species relative changes in stand basal area increment (BAI)
#' over 1980-2007, from Charru M., Seynave I., Herve J.-C.,
#' Bertrand R. and Bontemps J.-D. (2017), "Recent growth changes in
#' Western European forests are driven by climate warming and
#' structured across tree species climatic habitats", Annals of
#' Forest Science 74:33 (HAL hal-01573238).
#'
#' The 8 species studied span four climatic habitats (mountain,
#' generalist, temperate lowland, Mediterranean) and show BAI trends
#' ranging from about -28 percent (P. halepensis, Mediterranean) to
#' about +25 percent (P. abies, mountain) over the 25-year window.
#' Modern stands therefore grow at different rates than the historical
#' baselines encoded in classic yield tables. For nemeton this is
#' informational in Phase 2: it does NOT auto-correct P1 / P3 / E1
#' outputs. Callers that want a modern volume can multiply by
#' \code{bai_drift_factor(species)}; callers studying retrospective
#' productivity may prefer the raw synthetic inventory.
#'
#' The values are central estimates read from Fig. 4a of the paper
#' and are therefore approximate (about 0.05 in relative units). They
#' should not be over-interpreted beyond their first digit.
#'
#' @name charru_bai_drift
#' @keywords internal
NULL


# Per-species central estimates of BAI_chg (relative change in stand
# basal area increment), period 1980-2007, mean climatic context.
# Source: Charru et al. 2017, Fig. 4a (positive = increase, negative
# = decline vs the 1980 baseline). "habitat" column tags the climatic
# ensemble each species belongs to.
.charru_bai_drift <- data.frame(
  species = c("PIAB", "ABAL", "PISY", "FASY",
              "QURO", "QUPE", "QUPU", "PIHA"),
  habitat = c("mountain", "mountain", "generalist", "generalist",
              "lowland", "lowland", "mediterranean", "mediterranean"),
  # relative change: 1.25 = +25 %, 0.88 = -12 %
  bai_chg = c(1.25, 1.17, 0.96, 1.05,
              1.00, 0.97, 0.88, 0.72),
  stringsAsFactors = FALSE
)


#' Charru 2017 BAI drift lookup table
#'
#' Returns the per-species relative BAI change over 1980-2007 and
#' the climatic habitat of each species.
#'
#' @return A data.frame with columns \code{species}, \code{habitat}
#'   and \code{bai_chg}.
#'
#' @examples
#' charru_bai_drift_table()
#'
#' @export
charru_bai_drift_table <- function() {
  .charru_bai_drift
}


#' Species BAI drift factor (Charru 2017)
#'
#' Returns the relative change in BAI over 1980-2007 for a given
#' species, i.e. a multiplicative factor that converts a historical
#' baseline productivity to its 2007 value (e.g. 1.25 for
#' \code{"PIAB"} = +25 %). Species not covered by the Charru 2017
#' panel fall back to the per-habitat mean when the habitat is
#' supplied, or to 1.0 (no drift) otherwise.
#'
#' Only 8 species are tabulated: \code{PIAB, ABAL, PISY, FASY, QURO,
#' QUPE, QUPU, PIHA}. For broader or finer-grained coverage, see
#' \code{\link{charru_bai_drift_table}}.
#'
#' @param species Character vector of IFN species codes.
#' @param habitat Optional character vector of climatic habitats
#'   (\code{"mountain"}, \code{"generalist"}, \code{"lowland"},
#'   \code{"mediterranean"}) to control the fallback. Recycled
#'   against \code{species}.
#'
#' @return Numeric vector of the same length as \code{species} with
#'   the relative BAI change (1.0 = no change).
#'
#' @examples
#' bai_drift_factor(c("PIAB", "FASY", "QUPE", "PIHA"))
#' bai_drift_factor("ACPS", habitat = "lowland")  # fallback by habitat
#'
#' @export
bai_drift_factor <- function(species, habitat = NULL) {
  n <- length(species)
  if (n == 0) return(numeric(0))
  species <- toupper(as.character(species))
  if (!is.null(habitat)) {
    habitat <- rep_len(as.character(habitat), n)
  }
  tab <- .charru_bai_drift
  habitat_mean <- c(
    mountain       = mean(tab$bai_chg[tab$habitat == "mountain"]),
    generalist     = mean(tab$bai_chg[tab$habitat == "generalist"]),
    lowland        = mean(tab$bai_chg[tab$habitat == "lowland"]),
    mediterranean  = mean(tab$bai_chg[tab$habitat == "mediterranean"])
  )
  out <- rep(1.0, n)
  for (i in seq_len(n)) {
    s <- species[i]
    if (is.na(s)) {
      out[i] <- NA_real_
      next
    }
    idx <- match(s, tab$species)
    if (!is.na(idx)) {
      out[i] <- tab$bai_chg[idx]
    } else if (!is.null(habitat)) {
      h <- habitat[i]
      if (!is.na(h) && h %in% names(habitat_mean)) {
        out[i] <- habitat_mean[[h]]
      }
    }
  }
  out
}
