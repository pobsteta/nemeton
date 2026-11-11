#' Parameters of the wood chain for harvested carbon and substitution
#'
#' The sourced defaults used by [simuler_itineraire()] with
#' `produits = TRUE` to follow the carbon of the harvested wood outside the
#' forest and the emissions it avoids (spec 068, sources in
#' `specs/068-trajectoires-finn/sources-carbone-produits.md`). Change an
#' element of the returned list to test another hypothesis.
#'
#' @return A list:
#' \describe{
#'   \item{taux_bo}{data.frame `groupe`, `d_min` (cm), `taux_bo`, `n`:
#'     share of the stem volume (merchantable, to 7 cm) of sawlog quality,
#'     by species group and diameter class from `d_min` up. Measured on the
#'     IFN plots of Bourgogne-Franche-Comte, 2005-2013 (quality 1 + 2 of the
#'     fields `Q1`, `Q2` of `ARBRE.csv`, weighted by volume;
#'     `data-raw/taux_bois_oeuvre_ifn.R`). Groups: `chenes` (02, 03),
#'     `hetre` (09), `sapin` (61), `epicea` (62), `douglas` (64),
#'     `autres_resineux`, `autres_feuillus`. An upper bound: the quality
#'     is presumed on the standing tree (ADEME-IGN-FCBA 2016).}
#'   \item{part_bi}{Named numeric, `feuillus` 0.25 and `resineux` 0.60:
#'     share of the non-sawlog volume going to industry (panels, pulp), the
#'     rest burnt for energy. Orders of magnitude from the Agreste harvest
#'     surveys (BFC 2024, France 2022) plus the non-professional fuelwood
#'     of BFC; no source by species. An hypothesis.}
#'   \item{rendement}{Named numeric, `bo` 0.50 and `bi` 0.85: share of the
#'     sawlog and industry volume that ends in products (the rest are
#'     co-products, counted inside the material substitution factor).
#'     INRA-IGN 2017, annex 4 section II.4.}
#'   \item{demi_vie}{Named numeric, `bo` 20 and `bi` 5 years: half-lives of
#'     the two product pools, first-order decay. INRA-IGN 2017, table 13.1
#'     (IPCC 2019 Tier 1: 35 years sawn wood, 25 panels, 2 paper).}
#'   \item{substitution_materiau}{1.6 tCO2 avoided per m3 of product (range
#'     0.59-3.47), from Sathre and O'Connor (2010) as selected by INRA-IGN
#'     2017, table 4.2.}
#'   \item{substitution_energie}{0.916 tCO2 avoided per dry tonne of wood
#'     burnt: 80 % fuel oil (0.97) and 20 % natural gas (0.70), INRA-IGN
#'     2017, table 4.3 (after Oliver et al. 2014), i.e. their 0.50 tCO2/m3
#'     for a hardwood of basic density 0.55.}
#' }
#'
#' @details Only the stem is followed (FINN carries no crown): branches,
#' small wood and logging losses are not counted, neither as products nor
#' as energy. The substitution factors are means of the literature, with a
#' range of a factor of six; read them as an order of magnitude.
#'
#' @references Roux A., Dhote J.-F. (coord.) et al. (2017). Quel role pour
#'   les forets et la filiere foret-bois francaises dans l'attenuation du
#'   changement climatique ? Etude INRA-IGN, annexes.
#'
#'   Colin A., Thivolle-Cazat A. (2016). Disponibilites en bois d'origine
#'   forestiere a l'horizon 2035. ADEME-IGN-FCBA.
#'
#'   IPCC (2019). 2019 Refinement to the 2006 IPCC Guidelines, vol. 4,
#'   chap. 12, table 12.3.
#' @section Lifecycle:
#' Experimental (spec 068): may change in any release.
#' @seealso [simuler_itineraire()]
#' @export
#' @examples
#' p <- parametres_filiere_bois()
#' p$demi_vie
#' p$demi_vie[["bo"]] <- 35 # IPCC sawn wood
parametres_filiere_bois <- function() {
  taux <- utils::read.csv(system.file("extdata", "taux_bois_oeuvre_ifn.csv", package = "nemeton"),
                          colClasses = c("character", "numeric", "numeric", "integer"))
  list(taux_bo = taux,
       part_bi = c(feuillus = 0.25, resineux = 0.60),
       rendement = c(bo = 0.50, bi = 0.85),
       demi_vie = c(bo = 20, bi = 5),
       substitution_materiau = 1.6,
       substitution_energie = 0.8 * 0.97 + 0.2 * 0.70)
}

# Verifie une liste de parametres de filiere (forme de parametres_filiere_bois()).
.filiere_verifier <- function(f) {
  noms <- c("taux_bo", "part_bi", "rendement", "demi_vie", "substitution_materiau",
            "substitution_energie")
  manq <- setdiff(noms, names(f))
  if (length(manq)) cli::cli_abort("{.arg filiere} lacks {.field {manq}}.")
  t <- as.data.frame(f$taux_bo)
  if (!all(c("groupe", "d_min", "taux_bo") %in% names(t)) || !nrow(t) ||
      any(!is.finite(t$taux_bo) | t$taux_bo < 0 | t$taux_bo > 1)) {
    cli::cli_abort("{.field taux_bo} needs {.field groupe}, {.field d_min} and {.field taux_bo} in [0, 1].")
  }
  part <- function(x, n, borne = 1) {
    !is.null(names(x)) && all(n %in% names(x)) && all(is.finite(x[n])) &&
      all(x[n] >= 0 & x[n] <= borne)
  }
  if (!part(f$part_bi, c("feuillus", "resineux"))) {
    cli::cli_abort("{.field part_bi} needs {.field feuillus} and {.field resineux} in [0, 1].")
  }
  if (!part(f$rendement, c("bo", "bi"))) {
    cli::cli_abort("{.field rendement} needs {.field bo} and {.field bi} in [0, 1].")
  }
  if (!part(f$demi_vie, c("bo", "bi"), Inf) || any(f$demi_vie[c("bo", "bi")] <= 0)) {
    cli::cli_abort("{.field demi_vie} needs positive {.field bo} and {.field bi} (years).")
  }
  for (n in c("substitution_materiau", "substitution_energie")) {
    x <- f[[n]]
    if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < 0) {
      cli::cli_abort("{.field {n}} must be one non-negative number.")
    }
  }
  t$groupe <- as.character(t$groupe)
  t <- t[order(t$groupe, t$d_min), , drop = FALSE]
  f$taux_bo <- t
  f
}

# Groupe de la table taux_bo d'une essence IFN (ESPAR).
.filiere_groupe <- function(espar) {
  e <- as.character(espar)
  g <- ifelse(is_conifer(e), "autres_resineux", "autres_feuillus")
  g[e %in% c("02", "03")] <- "chenes"
  g[e == "09"] <- "hetre"
  g[e == "61"] <- "sapin"
  g[e == "62"] <- "epicea"
  g[e == "64"] <- "douglas"
  g
}

# Taux de bois d'oeuvre par cohorte : groupe et diametre (cm). Groupe absent
# de la table : celui des autres feuillus ou resineux, sinon 0.
.filiere_taux <- function(taux, groupe, dbh, resineux) {
  out <- numeric(length(dbh))
  repli <- ifelse(resineux, "autres_resineux", "autres_feuillus")
  groupe[!groupe %in% taux$groupe] <- repli[!groupe %in% taux$groupe]
  for (gr in unique(groupe)) {
    i <- which(groupe == gr)
    t <- taux[taux$groupe == gr, , drop = FALSE]
    if (!nrow(t)) next
    k <- findInterval(dbh[i], t$d_min)
    out[i] <- ifelse(k > 0, t$taux_bo[pmax(k, 1)], 0)
  }
  out
}
