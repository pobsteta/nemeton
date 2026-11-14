#' Excess mortality against a FINN baseline
#'
#' Compares the basal area of the trees that died between two inventories
#' with the mortality a calibrated FINN model expects from the state at the
#' first one: the difference is the excess mortality (spec 069). Calibrated
#' before a crisis, FINN gives the ordinary mortality of competition and
#' ageing; an excess above the conformal threshold is abnormal (drought, bark
#' beetles, dieback, storm). It says "more than expected", not why.
#'
#' @param calibration A `"finn_calibration"` object from [calibrer_finn()].
#'   For the threshold, with the mortality residuals of [conformer_finn()].
#' @param arbres data.frame of trees measured twice, with the columns of
#'   [calibrer_finn()] (`placette`, `essence`, `d1`, `d2`, `poids`,
#'   `statut`). Dead trees (`statut == "mort"`) count at their first
#'   diameter `d1`. Plots with a cut between the visits
#'   (`statut == "coupe"`) are left out: a cut tree would have counted in the
#'   expected mortality.
#' @param environnement data.frame, one row per plot: `placette` and the
#'   variables of the calibration.
#' @param unites data.frame or `NULL`. `placette`, `unite`: the plots of each
#'   unit (management unit, or essence x region x period for a regional
#'   diagnosis). The default, `NULL`, reports every plot, with a warning: the
#'   death of a tree is a rare event and a single plot over a few years is
#'   noisy (spec 069, S-2).
#' @param niveau Numeric in `(0, 1)`. Level of the one-sided conformal
#'   threshold. Default 0.95 (spec 069, S-4).
#' @param n_tirages Integer. Draws of the FINN step averaged per plot.
#'   Default 20.
#' @param correction Logical. Apply the growth correction of the calibration
#'   ([corriger_finn()]) if it has one. Default `TRUE`.
#'
#' @return A data.frame, one row per plot (or per unit, with `unite` and
#'   `n_placettes` instead of `placette`): `g_initiale` (m2/ha, living and
#'   dead trees at the first visit), `mort_observee` and `mort_attendue`
#'   (m2/ha of basal area at the first visit of the trees that died during
#'   one FINN step, `calibration$pas_annees` years), `surmortalite`
#'   (observed minus expected), `surmortalite_pct` (in % of `g_initiale`),
#'   `seuil` (m2/ha) and `anormale` (`surmortalite > seuil`). For a unit the
#'   values are the means of its plots. `seuil` and `anormale` are `NA`
#'   without mortality residuals, or for a unit too large for them.
#'
#' @details
#' **Expected.** One FINN step from the trees of the first visit; the stems
#' that die in the step count at their diameter at the start of the step,
#' mean of `n_tirages` draws. The interval between the visits should be the
#' step of the calibration (5 years for the IFN).
#'
#' **Threshold.** For one plot, the conformal quantile at level
#' `niveau * (1 + 1 / n)` of the observed minus expected mortality on the
#' held-out plots of [conformer_finn()]: on plots exchangeable with those,
#' an ordinary mortality exceeds it with probability at most `1 - niveau`.
#' For a unit of `k` plots, the same quantile of the mean residual of groups
#' of `k` held-out plots, neighbours when [conformer_finn()] had the
#' coordinates, as for the interval of [simuler_itineraire()]; it needs at
#' least 30 groups.
#'
#' **Baseline.** The model must have learnt ordinary mortality. On BFC, a
#' FINN calibrated on the 1724 plots revisited in 2015-2017 put 3.7 to 6.6 % of
#' the held-out plots of those years above the 95 % threshold (2.45 m2/ha
#' in 5 years), and the excess rose after 2018: spruce 4.9 times the
#' expected mortality in 2021-2025 (+1.36 m2/ha), ash 3.0 times (+1.19),
#' beech 1.06 (spec 069, `data-raw/surmortalite_ifn_bfc.R`). The observed
#' mortality counts every tree dead between the visits, windthrow included.
#'
#' @seealso [conformer_finn()], [calibrer_finn()], [simuler_itineraire()]
#' @export
surmortalite_finn <- function(calibration, arbres, environnement, unites = NULL,
                              niveau = 0.95, n_tirages = 20L, correction = TRUE) {
  if (!inherits(calibration, "finn_calibration")) {
    cli::cli_abort("{.arg calibration} must come from {.fn calibrer_finn}.")
  }
  if (!is.numeric(niveau) || length(niveau) != 1L || !is.finite(niveau) ||
      niveau <= 0 || niveau >= 1) {
    cli::cli_abort("{.arg niveau} must be a number in (0, 1).")
  }
  n_tirages <- as.integer(n_tirages)
  if (length(n_tirages) != 1L || is.na(n_tirages) || n_tirages < 1L) {
    cli::cli_abort("{.arg n_tirages} must be a positive integer.")
  }
  arbres <- as.data.frame(arbres)
  manq <- setdiff(c("placette", "essence", "d1", "poids", "statut"), names(arbres))
  if (length(manq)) cli::cli_abort("{.arg arbres} lacks {.field {manq}}.")
  if (!is.null(unites)) {
    unites <- as.data.frame(unites)
    manq <- setdiff(c("placette", "unite"), names(unites))
    if (length(manq)) cli::cli_abort("{.arg unites} lacks {.field {manq}}.")
    if (anyDuplicated(unites$placette)) cli::cli_abort("A plot belongs to one unit only in {.arg unites}.")
  }
  pla <- as.character(arbres$placette)
  coupees <- unique(pla[arbres$statut == "coupe"])
  if (length(coupees)) {
    cli::cli_inform(c("i" = "{length(coupees)} plot{?s} cut between the visits left out."))
    arbres <- arbres[!pla %in% coupees, , drop = FALSE]
  }
  if (!nrow(arbres)) cli::cli_abort("No plot left without a cut.")
  vues <- intersect(unique(as.character(arbres$placette)), calibration$placettes)
  if (length(vues)) {
    cli::cli_warn(c(
      "{length(vues)} plot{?s} of {.arg arbres} {?was/were} used in the calibration.",
      "i" = "The model has learnt their mortality: their excess is biased towards 0."
    ))
  }

  m <- .finn_mortalite(calibration, arbres, environnement, n_tirages, correction)
  m$surmortalite <- m$mort_observee - m$mort_attendue
  conf <- calibration$conforme
  if (is.null(conf$mortalite)) {
    cli::cli_inform(c("i" = "No mortality residuals: run {.fn conformer_finn} for the threshold."))
  }

  if (is.null(unites)) {
    cli::cli_warn(c(
      "Excess mortality of single plots is noisy.",
      "i" = "Group plots with {.arg unites} (spec 069, S-2)."
    ))
    out <- m[, c("placette", "g_initiale", "mort_observee", "mort_attendue", "surmortalite")]
    out$seuil <- .finn_seuil_mortalite(conf, 1L, niveau)
  } else {
    u <- as.character(unites$unite)[match(m$placette, as.character(unites$placette))]
    if (anyNA(u)) {
      cli::cli_abort("{sum(is.na(u))} plot{?s} without a unit in {.arg unites}.")
    }
    moy <- function(v) as.numeric(tapply(m[[v]], u, mean))
    noms <- sort(unique(u))
    out <- data.frame(unite = noms, n_placettes = as.integer(table(u)[noms]),
                      g_initiale = moy("g_initiale"), mort_observee = moy("mort_observee"),
                      mort_attendue = moy("mort_attendue"), surmortalite = moy("surmortalite"),
                      stringsAsFactors = FALSE)
    tailles <- sort(unique(out$n_placettes))
    seuils <- vapply(tailles, function(k) .finn_seuil_mortalite(conf, k, niveau), numeric(1))
    out$seuil <- seuils[match(out$n_placettes, tailles)]
  }
  out$surmortalite_pct <- ifelse(out$g_initiale > 0, 100 * out$surmortalite / out$g_initiale,
                                 NA_real_)
  out$anormale <- out$surmortalite > out$seuil
  out <- out[, c(setdiff(names(out), c("seuil", "anormale", "surmortalite_pct")),
                 "surmortalite_pct", "seuil", "anormale")]
  attr(out, "niveau") <- niveau
  out
}

# Mortalite observee et attendue par placette (m2/ha de G a la premiere
# visite des tiges mortes pendant un pas FINN), moyenne de n_tirages.
.finn_mortalite <- function(calibration, arbres, environnement, n_tirages = 20L,
                            correction = TRUE) {
  .finn_verifier_installation()
  arbres <- as.data.frame(arbres)
  if (!"statut" %in% names(arbres)) arbres$statut <- "vivant"
  a0 <- arbres; a0$d2 <- NA_real_
  sp <- calibration$surface_placette
  prep <- .finn_preparer(a0, environnement, sp, essences = calibration$essences,
                         variables_env = calibration$variables_env, observations = FALSE)
  n_s <- nrow(prep$sites)
  m <- calibration$modele
  m$eval()
  corr <- if (isTRUE(correction)) calibration$correction else NULL
  env1 <- prep$env[prep$env$year == 0L, , drop = FALSE]
  coh0 <- prep$init[, c("siteID", "species", "dbh", "trees")]
  coh0$trees <- round(coh0$trees)
  att <- numeric(n_s)
  for (t in seq_len(n_tirages)) {
    coh <- .itin_pas_corrige(m, coh0, env1, sp, length(calibration$essences), corr)
    mo <- attr(coh, "morts")
    if (!is.null(mo) && nrow(mo)) {
      s <- tapply(mo$trees * .g_arbre(mo$dbh), factor(mo$siteID, levels = seq_len(n_s)), sum)
      att <- att + as.numeric(ifelse(is.na(s), 0, s)) / sp
    }
  }
  morte <- arbres$statut == "mort" & is.finite(arbres$d1)
  obs <- tapply(ifelse(morte, arbres$poids * .g_arbre(arbres$d1), 0),
                as.character(arbres$placette), sum)
  data.frame(placette = prep$sites$placette, g_initiale = prep$sites$g0,
             mort_observee = as.numeric(obs[prep$sites$placette]),
             mort_attendue = att / n_tirages, stringsAsFactors = FALSE)
}

# Seuil conforme unilateral de la surmortalite d'une unite de k placettes :
# quantile du residu (observe - attendu) moyen de groupes de k placettes
# tenues a l'ecart. NA sans residus ou si moins de 30 groupes.
.finn_seuil_mortalite <- function(conf, k, niveau) {
  r <- conf$mortalite$residus
  if (is.null(r)) return(NA_real_)
  ok <- is.finite(r)
  x <- if (!is.null(conf$x)) conf$x[ok]
  y <- if (!is.null(conf$y)) conf$y[ok]
  r <- r[ok]
  if (k <= 1L) {
    v <- r
  } else {
    n_g <- length(r) %/% k
    if (n_g < 30L) {
      cli::cli_warn(c(
        "No threshold for units of {k} plots: {n_g} group{?s} of held-out plots, 30 needed.",
        "i" = "{length(r)} plots with mortality residuals in {.fn conformer_finn}."
      ))
      return(NA_real_)
    }
    g <- .finn_groupes(length(r), k, x, y)$g
    v <- as.numeric(tapply(r[g > 0], g[g > 0], mean))
  }
  stats::quantile(v, min(1, niveau * (1 + 1 / length(v))), names = FALSE)
}
