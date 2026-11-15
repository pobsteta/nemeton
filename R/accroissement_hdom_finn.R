# Accroissement de hauteur dominante attendu par FINN (spec 068, T4).
#
# FINN porte des diametres : la hauteur vient de l'allometrie hauteur-diametre
# ajustee sur les hauteurs mesurees de l'IFN (decision T4-2,
# inst/extdata/allometrie_hauteur_ifn.csv, data-raw/allometrie_hauteur_ifn.R).
# Hauteur dominante = hauteur moyenne des 100 plus gros arbres a l'hectare.

#' Dominant-height increment expected by FINN
#'
#' Simulates one FINN step (5 years) from the first-visit state of each plot
#' and returns the increment of its dominant height, the mean height of the
#' 100 largest trees per hectare. Heights come from the height-diameter
#' curves fitted on the total heights measured by the French national forest
#' inventory (IFN, Bourgogne-Franche-Comte), by species and, where enough
#' trees were measured, by sylvo-ecoregion (SER). This is the expected growth
#' that the dynamic vitality indicator T4 compares with the FORMS-T
#' canopy-height series (spec 068).
#'
#' @param calibration A `finn_calibration` from [calibrer_finn()].
#' @param arbres Data frame of trees, as in [calibrer_finn()]: `placette`,
#'   `essence`, `d1` (cm), `poids` (stems/ha); `d2` and `statut` are optional
#'   and ignored (every tree with a diameter is alive at the start).
#' @param environnement Data frame with `placette` and the environmental
#'   variables of the calibration, for the simulated period.
#' @param ser Optional named character vector giving the SER code of each
#'   plot (names = plot identifiers), or a data frame with columns `placette`
#'   and `ser`. Without it, the all-SER curve of each species is used.
#' @param n_tirages Integer, number of FINN draws per plot. Default 20.
#' @param correction Logical, apply the growth and recruitment correction of
#'   [corriger_finn()] when the calibration carries one. Default `TRUE`.
#'
#' @return A data frame with one row per plot and draw: `placette`, `ser`,
#'   `essence` (species with the largest basal area at the start), `g0`
#'   (m2/ha), `h_dom` (dominant height at the start, m), `tirage` and
#'   `accroissement` (dominant-height increment over the step, m).
#'
#' @details
#' The curves are static: one height per diameter and species. They mix
#' stands of different fertility, so the increment they give for the
#' dominant trees can be lower than the true one on good sites; T4 must be
#' checked for centring on a stand with no known disturbance before use
#' (spec 068, T4-3). Species pooled as `"other"` by the calibration use the
#' `"other"` curve.
#'
#' @seealso [indicateur_t4_vitalite()], [calibrer_finn()], [corriger_finn()]
#' @export
accroissement_hdom_finn <- function(calibration, arbres, environnement, ser = NULL,
                                    n_tirages = 20L, correction = TRUE) {
  if (!inherits(calibration, "finn_calibration")) {
    cli::cli_abort("{.arg calibration} must come from {.fn calibrer_finn}.")
  }
  if (!is.numeric(n_tirages) || length(n_tirages) != 1L || n_tirages < 1) {
    cli::cli_abort("{.arg n_tirages} must be a positive integer.")
  }
  n_tirages <- as.integer(n_tirages)
  .finn_verifier_installation()
  arbres <- as.data.frame(arbres)
  manq <- setdiff(c("placette", "essence", "d1", "poids"), names(arbres))
  if (length(manq)) cli::cli_abort("{.arg arbres} lacks column{?s} {.field {manq}}.")
  arbres <- arbres[is.finite(arbres$d1) & is.finite(arbres$poids), , drop = FALSE]
  arbres$statut <- "vivant"
  arbres$d2 <- NA_real_

  sp <- calibration$surface_placette
  prep <- .finn_preparer(arbres, environnement, sp, essences = calibration$essences,
                         variables_env = calibration$variables_env, observations = FALSE)
  pla <- prep$sites$placette
  n_s <- length(pla)
  ser_s <- .t4_ser_placettes(ser, pla)
  ess <- calibration$essences

  # essence dominante en G (code d'origine, pas le groupe FINN)
  a <- arbres[arbres$placette %in% pla, , drop = FALSE]
  g_ess <- stats::aggregate(list(g = a$poids * .g_arbre(a$d1)),
                            list(placette = a$placette, essence = as.character(a$essence)), sum)
  g_ess <- g_ess[order(g_ess$placette, -g_ess$g), , drop = FALSE]
  g_ess <- g_ess[!duplicated(g_ess$placette), , drop = FALSE]
  dom <- g_ess$essence[match(pla, g_ess$placette)]

  m <- calibration$modele
  m$eval()
  corr <- if (isTRUE(correction)) calibration$correction else NULL
  env1 <- prep$env[prep$env$year == 0L, , drop = FALSE]
  coh0 <- prep$init[, c("siteID", "species", "dbh", "trees")]
  coh0$trees <- round(coh0$trees)
  h0 <- .h_dominante_cohortes(coh0, n_s, sp, ess, ser_s)

  res <- vector("list", n_tirages)
  for (t in seq_len(n_tirages)) {
    coh <- .itin_pas_corrige(m, coh0, env1, sp, length(ess), corr)
    res[[t]] <- .h_dominante_cohortes(as.data.frame(coh), n_s, sp, ess, ser_s) - h0
  }
  data.frame(placette = rep(pla, n_tirages), ser = rep(ser_s, n_tirages),
             essence = rep(dom, n_tirages), g0 = rep(prep$sites$g0, n_tirages),
             h_dom = rep(h0, n_tirages), tirage = rep(seq_len(n_tirages), each = n_s),
             accroissement = unlist(res), stringsAsFactors = FALSE)
}

# SER de chaque placette (NA si inconnue).
.t4_ser_placettes <- function(ser, placettes) {
  if (is.null(ser)) return(rep(NA_character_, length(placettes)))
  if (is.data.frame(ser)) {
    if (!all(c("placette", "ser") %in% names(ser))) {
      cli::cli_abort("{.arg ser} must have columns {.field placette} and {.field ser}.")
    }
    ser <- stats::setNames(as.character(ser$ser), as.character(ser$placette))
  }
  if (is.null(names(ser))) cli::cli_abort("{.arg ser} must be named by plot.")
  unname(as.character(ser[placettes]))
}

# Hauteur dominante (m) de chaque site depuis des cohortes FINN (siteID,
# species, dbh en cm, trees par placette de surface sp ha) : hauteur moyenne
# des 100 plus gros arbres a l'hectare, la derniere cohorte comptant pour sa
# part. NA pour un site sans tige.
.h_dominante_cohortes <- function(coh, n_sites, sp, essences, ser_sites) {
  coh <- coh[is.finite(coh$trees) & coh$trees > 0, , drop = FALSE]
  out <- rep(NA_real_, n_sites)
  if (!nrow(coh)) return(out)
  h <- .hauteur_ifn(coh$dbh, essences[coh$species], ser_sites[coh$siteID])
  quota <- 100 * sp
  for (s in unique(coh$siteID)) {
    i <- which(coh$siteID == s)
    i <- i[order(coh$dbh[i], decreasing = TRUE)]
    n <- coh$trees[i]
    pris <- pmin(n, pmax(0, quota - c(0, cumsum(n)[-length(n)])))
    out[s] <- sum(pris * h[i]) / sum(pris)
  }
  out
}

# Hauteur totale (m) depuis le diametre (cm), allometrie IFN : courbe de
# l'essence dans la SER si elle existe, sinon de l'essence, sinon "other".
.hauteur_ifn <- function(d, essence, ser = NA_character_) {
  tab <- .allometrie_hauteur()
  ser <- rep_len(as.character(ser), length(d))
  essence <- as.character(essence)
  cle <- paste(essence, ser)
  k <- match(cle, paste(tab$essence, tab$ser))
  k0 <- match(paste(essence, ""), paste(tab$essence, tab$ser))
  k[is.na(k)] <- k0[is.na(k)]
  k[is.na(k)] <- match("other ", paste(tab$essence, tab$ser))
  1.3 + tab$a[k] * d / (tab$b[k] + d)
}

.allometrie_cache <- new.env(parent = emptyenv())

.allometrie_hauteur <- function() {
  if (is.null(.allometrie_cache$tab)) {
    f <- system.file("extdata", "allometrie_hauteur_ifn.csv", package = "nemeton")
    tab <- utils::read.csv(f, colClasses = c(essence = "character", ser = "character"))
    tab$ser[is.na(tab$ser)] <- ""
    .allometrie_cache$tab <- tab
  }
  .allometrie_cache$tab
}
