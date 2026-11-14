#' Growth correction of a FINN calibration
#'
#' Measures, on plots that took no part in the calibration, how much the
#' diameter growth of FINN's surviving trees must be scaled to match the
#' observed growth, by class of initial basal area and by group (broadleaves,
#' conifers). The factors travel with the calibration and
#' [simuler_itineraire()], [predire_finn()] and [conformer_finn()] apply them
#' after every FINN step (spec 068, decision D-G option 1).
#'
#' @param calibration A `"finn_calibration"` object from [calibrer_finn()].
#' @param arbres data.frame of trees measured twice on plots **not** used in
#'   the calibration, with the columns of [calibrer_finn()] (`placette`,
#'   `essence`, `d1`, `d2`, `poids`, `statut`). Plots with a cut between the
#'   visits (`statut == "coupe"`) are left out.
#' @param environnement data.frame, one row per plot: `placette` and the
#'   variables of the calibration.
#' @param bornes Numeric. Bounds of the classes of initial basal area
#'   (m2/ha), increasing, from 0 to `Inf`. Default 0, 10, 20, 30, 40, 50,
#'   `Inf`.
#' @param n_tirages Integer. Draws averaged per plot. Default 3.
#' @param iterations Integer. Rounds of measure and adjustment. Default 2:
#'   the basal area grows with the square of the diameter, so a factor on
#'   the diameter increment is not exactly the ratio of the basal area
#'   increments; a second round absorbs the difference.
#' @param min_placettes Integer. Plots needed in a cell (class x group);
#'   below, the cell takes the factor of its group over all classes, and a
#'   group below this number keeps a factor of 1. Default 30.
#'
#' @return The calibration, with an element `correction`: `bornes`,
#'   `facteurs` (matrix, classes x `feuillus` / `resineux`), `n_placettes`
#'   (same shape), `resineux` (logical, one per species of the calibration),
#'   `suivi` (data.frame of the ratio observed / simulated growth per cell
#'   and iteration, before the adjustment of that iteration) and
#'   `placettes`. A conformal element `conforme` is dropped: measure it again
#'   with [conformer_finn()] on other plots, after the correction.
#'
#' @details
#' After a FINN step, a surviving cohort of diameter `dbh0` at the start and
#' `dbh1` at the end takes `dbh0 + f * (dbh1 - dbh0)`, `f` being the factor
#' of the class of basal area of its plot at the start of the step and of
#' the group of its species; the diameter never decreases. Recruits are not
#' corrected. The factor corrects a mean per cell, not FINN's
#' density-growth relation itself, and compounds over the steps of a long
#' trajectory.
#'
#' On BFC (model calibrated on 5 632 plots, loss weight of the basal area
#' x 3), FINN's growth plus recruitment was 11 to 17 % too high between 10
#' and 30 m2/ha of initial basal area on 780 held-out plots (spec 068).
#'
#' @seealso [calibrer_finn()], [conformer_finn()], [simuler_itineraire()]
#' @export
corriger_finn <- function(calibration, arbres, environnement,
                          bornes = c(0, 10, 20, 30, 40, 50, Inf), n_tirages = 3L,
                          iterations = 2L, min_placettes = 30L) {
  if (!inherits(calibration, "finn_calibration")) {
    cli::cli_abort("{.arg calibration} must come from {.fn calibrer_finn}.")
  }
  if (!is.numeric(bornes) || length(bornes) < 2L || bornes[1] != 0 ||
      !is.infinite(bornes[length(bornes)]) || is.unsorted(bornes, strictly = TRUE)) {
    cli::cli_abort("{.arg bornes} must increase strictly from 0 to {.code Inf}.")
  }
  iterations <- as.integer(iterations)
  if (length(iterations) != 1L || is.na(iterations) || iterations < 1L) {
    cli::cli_abort("{.arg iterations} must be a positive integer.")
  }
  arbres <- as.data.frame(arbres)
  if (!"statut" %in% names(arbres)) arbres$statut <- "vivant"
  communes <- intersect(unique(as.character(arbres$placette)), calibration$placettes)
  if (length(communes)) {
    cli::cli_abort(c(
      "{length(communes)} plot{?s} of {.arg arbres} {?was/were} used in the calibration.",
      "i" = "The correction needs plots the model has not seen."
    ))
  }
  coupees <- unique(as.character(arbres$placette[arbres$statut == "coupe"]))
  arbres <- arbres[!as.character(arbres$placette) %in% coupees, , drop = FALSE]
  .finn_verifier_installation()

  ess <- calibration$essences
  resineux <- is_conifer(ess)
  n_cl <- length(bornes) - 1L
  noms_cl <- paste0("[", bornes[-length(bornes)], ",", bornes[-1], ")")
  groupes <- c("feuillus", "resineux")

  # --- observe : accroissement en G des survivants, par placette x groupe ---
  esp <- as.character(arbres$essence)
  esp[!esp %in% ess] <- "other"
  grp_a <- ifelse(resineux[match(esp, ess)], "resineux", "feuillus")
  v <- arbres$statut == "vivant" & is.finite(arbres$d1) & is.finite(arbres$d2)
  pla <- as.character(arbres$placette)
  obs <- tapply(ifelse(v, arbres$poids * (.g_arbre(arbres$d2) - .g_arbre(arbres$d1)), 0),
                list(factor(pla), factor(grp_a, levels = groupes)), sum)
  obs[is.na(obs)] <- 0
  init <- arbres$statut %in% c("vivant", "mort") & is.finite(arbres$d1)
  g_init <- tapply(ifelse(init, arbres$poids * .g_arbre(arbres$d1), 0),
                   list(factor(pla), factor(grp_a, levels = groupes)), sum)
  g_init[is.na(g_init)] <- 0

  # --- simule ------------------------------------------------------------------
  a0 <- arbres; a0$d2 <- NA_real_
  prep <- .finn_preparer(a0, environnement, calibration$surface_placette,
                         essences = ess, variables_env = calibration$variables_env,
                         observations = FALSE)
  sp <- calibration$surface_placette
  n_s <- nrow(prep$sites)
  m <- calibration$modele
  m$eval()
  env1 <- prep$env[prep$env$year == 0L, , drop = FALSE]
  coh0 <- prep$init[, c("siteID", "species", "dbh", "trees")]
  coh0$trees <- round(coh0$trees)
  g0 <- .itin_etat(coh0, n_s, sp)$g
  cl <- pmin(findInterval(g0, bornes, rightmost.closed = TRUE), n_cl)
  sites <- prep$sites$placette
  k_obs <- match(sites, rownames(obs))
  obs_s <- obs[k_obs, , drop = FALSE]
  present <- g_init[k_obs, , drop = FALSE] > 0
  ok <- !is.na(k_obs) & cl >= 1L
  n_pla <- matrix(0L, n_cl, 2L, dimnames = list(noms_cl, groupes))
  for (j in 1:2) n_pla[, j] <- tabulate(cl[ok & present[, j]], n_cl)

  croissance_sim <- function(correction) {
    tot <- matrix(0, n_s, 2L)
    for (i in seq_len(n_tirages)) {
      out <- .itin_pas_corrige(m, coh0, env1, sp, length(ess), correction)
      d0 <- attr(out, "dbh_entree")
      s <- which(is.finite(d0))
      dg <- out$trees[s] * (.g_arbre(out$dbh[s]) - .g_arbre(d0[s])) / sp
      gs <- 1L + as.integer(resineux[out$species[s]])
      for (j in 1:2) {
        v <- tapply(dg[gs == j], factor(out$siteID[s][gs == j], levels = seq_len(n_s)), sum)
        v[is.na(v)] <- 0
        tot[, j] <- tot[, j] + as.numeric(v)
      }
    }
    tot / n_tirages
  }

  facteurs <- matrix(1, n_cl, 2L, dimnames = list(noms_cl, groupes))
  correction <- list(bornes = bornes, facteurs = facteurs, resineux = resineux)
  suivi <- list()
  for (it in seq_len(iterations)) {
    sim <- croissance_sim(if (it == 1L) NULL else correction)
    rap <- matrix(NA_real_, n_cl, 2L, dimnames = list(noms_cl, groupes))
    for (j in 1:2) {
      sel <- ok & present[, j]
      so <- tapply(obs_s[sel, j], factor(cl[sel], levels = seq_len(n_cl)), sum)
      ss <- tapply(sim[sel, j], factor(cl[sel], levels = seq_len(n_cl)), sum)
      r_cell <- as.numeric(so / ss)
      r_grp <- if (sum(sel) >= min_placettes) sum(obs_s[sel, j]) / sum(sim[sel, j]) else 1
      if (!is.finite(r_grp)) r_grp <- 1
      petit <- n_pla[, j] < min_placettes | !is.finite(r_cell)
      r_cell[petit] <- r_grp
      rap[, j] <- r_cell
    }
    suivi[[it]] <- data.frame(iteration = it, classe = rep(noms_cl, 2L),
                              groupe = rep(groupes, each = n_cl),
                              n_placettes = as.vector(n_pla),
                              rapport = as.vector(rap), stringsAsFactors = FALSE)
    correction$facteurs[] <- pmin(4, pmax(0.25, correction$facteurs * rap))
  }
  correction$n_placettes <- n_pla
  correction$suivi <- do.call(rbind, suivi)
  correction$placettes <- sites[ok]
  if (!is.null(calibration$conforme)) {
    cli::cli_inform(c("i" = "Conformal residuals dropped: measure them again with {.fn conformer_finn} after the correction."))
    calibration$conforme <- NULL
  }
  calibration$correction <- correction
  calibration
}
