#' Growth and recruitment correction of a FINN calibration
#'
#' Measures how much FINN's diameter growth of surviving trees and its
#' number of recruits must be scaled to match the observed ones, as smooth
#' functions of the initial basal area of the plot, for broadleaves and
#' conifers. The factors travel with the calibration and
#' [simuler_itineraire()], [predire_finn()] and [conformer_finn()] apply them
#' after every FINN step (spec 068, decision D-G option 1).
#'
#' @param calibration A `"finn_calibration"` object from [calibrer_finn()].
#' @param arbres data.frame of trees measured twice, with the columns of
#'   [calibrer_finn()] (`placette`, `essence`, `d1`, `d2`, `poids`,
#'   `statut`). Plots with a cut between the visits (`statut == "coupe"`)
#'   are left out.
#' @param environnement data.frame, one row per plot: `placette` and the
#'   variables of the calibration.
#' @param placettes_calibration Logical. Accept plots used in the
#'   calibration. Default `FALSE`. On BFC, FINN's bias on its calibration
#'   plots was the same as on held-out plots (spec 068), so the many
#'   calibration plots give steadier factors than the few held-out ones;
#'   keep held-out plots for [conformer_finn()] and for the test.
#' @param grille Numeric. Basal areas (m2/ha) where the factors are
#'   estimated; in between they are interpolated linearly, beyond they hold
#'   the value of the nearest end. Default 0 to 80 by 2.5.
#' @param largeur Numeric. Bandwidth (m2/ha) of the Gaussian kernel: the
#'   factor at `g` is the ratio of the observed to the simulated sums over
#'   all plots, weighted by `exp(-((G0 - g) / largeur)^2 / 2)`. Default 5.
#' @param n_tirages Integer. Draws averaged per plot. Default 3.
#' @param iterations Integer. Rounds of measure and adjustment. Default 2:
#'   the basal area grows with the square of the diameter, so a factor on
#'   the diameter increment is not exactly the ratio of the basal area
#'   increments; a second round absorbs the difference.
#' @param min_placettes Integer. A group (broadleaves, conifers) with fewer
#'   plots keeps factors of 1; a point of `grille` with a smaller kernel
#'   effective number of plots takes the factor of the nearest point that
#'   has enough (the ends of the range of basal areas). Default 30.
#'
#' @return The calibration, with an element `correction`: `grille`,
#'   `croissance` and `recrutement` (matrices, `grille` x `feuillus` /
#'   `resineux`), `n_effectif` (kernel effective number of plots, same
#'   shape), `resineux` (logical, one per species of the calibration),
#'   `largeur`, `n_placettes` and `placettes`. A conformal element
#'   `conforme` is dropped: measure it again with [conformer_finn()] on
#'   held-out plots, after the correction.
#'
#' @details
#' After a FINN step, a surviving cohort of diameter `dbh0` at the start and
#' `dbh1` at the end takes `dbh0 + f * (dbh1 - dbh0)`; the diameter never
#' decreases. A recruited cohort of `n` stems keeps `r * n` stems, rounded at
#' random to an integer. `f` and `r` are read at the basal area of the plot
#' at the start of the step, for the group of the species. The factors
#' correct a mean, not FINN's density-growth relation itself, and compound
#' over the steps of a long trajectory.
#'
#' @seealso [calibrer_finn()], [conformer_finn()], [simuler_itineraire()]
#' @export
corriger_finn <- function(calibration, arbres, environnement,
                          placettes_calibration = FALSE,
                          grille = seq(0, 80, by = 2.5), largeur = 5, n_tirages = 3L,
                          iterations = 2L, min_placettes = 30L) {
  if (!inherits(calibration, "finn_calibration")) {
    cli::cli_abort("{.arg calibration} must come from {.fn calibrer_finn}.")
  }
  if (!is.numeric(grille) || length(grille) < 2L || any(!is.finite(grille)) ||
      is.unsorted(grille, strictly = TRUE)) {
    cli::cli_abort("{.arg grille} must be at least two finite, strictly increasing basal areas.")
  }
  if (!is.numeric(largeur) || length(largeur) != 1L || !is.finite(largeur) || largeur <= 0) {
    cli::cli_abort("{.arg largeur} must be a single positive number (m2/ha).")
  }
  iterations <- as.integer(iterations)
  if (length(iterations) != 1L || is.na(iterations) || iterations < 1L) {
    cli::cli_abort("{.arg iterations} must be a positive integer.")
  }
  arbres <- as.data.frame(arbres)
  if (!"statut" %in% names(arbres)) arbres$statut <- "vivant"
  if (!isTRUE(placettes_calibration)) {
    communes <- intersect(unique(as.character(arbres$placette)), calibration$placettes)
    if (length(communes)) {
      cli::cli_abort(c(
        "{length(communes)} plot{?s} of {.arg arbres} {?was/were} used in the calibration.",
        "i" = "Set {.code placettes_calibration = TRUE} to accept them."
      ))
    }
  }
  coupees <- unique(as.character(arbres$placette[arbres$statut == "coupe"]))
  arbres <- arbres[!as.character(arbres$placette) %in% coupees, , drop = FALSE]
  .finn_verifier_installation()

  ess <- calibration$essences
  resineux <- is_conifer(ess)
  groupes <- c("feuillus", "resineux")

  # --- observe : par placette x groupe, accroissement en G des survivants et
  # G des recrues -------------------------------------------------------------
  esp <- as.character(arbres$essence)
  esp[!esp %in% ess] <- "other"
  grp_a <- factor(ifelse(resineux[match(esp, ess)], "resineux", "feuillus"), levels = groupes)
  pla <- factor(as.character(arbres$placette))
  somme <- function(x) {
    s <- tapply(x, list(pla, grp_a), sum)
    s[is.na(s)] <- 0
    s
  }
  v <- arbres$statut == "vivant" & is.finite(arbres$d1) & is.finite(arbres$d2)
  r <- arbres$statut == "recrute" & is.finite(arbres$d2)
  init <- arbres$statut %in% c("vivant", "mort") & is.finite(arbres$d1)
  surv_obs <- somme(ifelse(v, arbres$poids * (.g_arbre(arbres$d2) - .g_arbre(arbres$d1)), 0))
  recr_obs <- somme(ifelse(r, arbres$poids * .g_arbre(arbres$d2), 0))
  g_init <- somme(ifelse(init, arbres$poids * .g_arbre(arbres$d1), 0))

  # --- simule --------------------------------------------------------------------
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
  k_obs <- match(prep$sites$placette, rownames(surv_obs))
  ok <- !is.na(k_obs)

  simuler <- function(correction) {
    surv <- recr <- matrix(0, n_s, 2L)
    par_site <- function(x, i) {
      s <- tapply(x[i], factor(i_site[i], levels = seq_len(n_s)), sum)
      as.numeric(ifelse(is.na(s), 0, s)) / sp
    }
    for (t in seq_len(n_tirages)) {
      out <- .itin_pas_corrige(m, coh0, env1, sp, length(ess), correction)
      d0 <- attr(out, "dbh_entree")
      i_site <- out$siteID
      gs <- 1L + as.integer(resineux[out$species])
      sv <- is.finite(d0)
      dg <- ifelse(sv, out$trees * (.g_arbre(out$dbh) - .g_arbre(d0)), 0)
      gr <- ifelse(sv, 0, out$trees * .g_arbre(out$dbh))
      for (j in 1:2) {
        surv[, j] <- surv[, j] + par_site(dg, which(gs == j))
        recr[, j] <- recr[, j] + par_site(gr, which(gs == j))
      }
    }
    list(surv = surv / n_tirages, recr = recr / n_tirages)
  }

  # rapport a noyau : somme ponderee des observes / des simules, en chaque g
  poids_noyau <- outer(grille, g0[ok], function(g, x) exp(-((x - g) / largeur)^2 / 2))
  rapport <- function(o, s, sel) {
    w <- poids_noyau[, sel, drop = FALSE]
    out <- as.numeric(w %*% o[sel]) / as.numeric(w %*% s[sel])
    out[!is.finite(out)] <- 1
    out
  }
  present <- g_init[k_obs[ok], , drop = FALSE] > 0
  n_eff <- matrix(0, length(grille), 2L, dimnames = list(grille, groupes))
  for (j in 1:2) {
    w <- poids_noyau[, present[, j], drop = FALSE]
    n_eff[, j] <- rowSums(w)^2 / pmax(rowSums(w^2), .Machine$double.eps)
  }

  # aux bouts de la grille, peu de placettes : le facteur y prend la valeur
  # du point fiable (n effectif >= min_placettes) le plus proche
  tenir <- function(x, j) {
    fiable <- n_eff[, j] >= min_placettes
    if (!any(fiable)) return(rep(1, length(x)))
    i <- which(fiable)
    x[!fiable] <- x[i][vapply(which(!fiable), function(k) which.min(abs(i - k)), integer(1))]
    x
  }
  un <- matrix(1, length(grille), 2L, dimnames = list(grille, groupes))
  correction <- list(grille = grille, croissance = un, recrutement = un,
                     resineux = resineux)
  for (it in seq_len(iterations)) {
    sim <- simuler(if (it == 1L) NULL else correction)
    for (j in 1:2) {
      sel <- present[, j]
      if (sum(sel) < min_placettes) next
      so <- surv_obs[k_obs[ok], j]; ss <- sim$surv[ok, j]
      ro <- recr_obs[k_obs[ok], j]; rs <- sim$recr[ok, j]
      correction$croissance[, j] <- tenir(pmin(4, pmax(0.25,
        correction$croissance[, j] * rapport(so, ss, sel))), j)
      correction$recrutement[, j] <- tenir(pmin(4, pmax(0.25,
        correction$recrutement[, j] * rapport(ro, rs, sel))), j)
    }
  }
  correction$n_effectif <- n_eff
  correction$largeur <- largeur
  correction$n_placettes <- sum(ok)
  correction$placettes <- prep$sites$placette[ok]
  if (!is.null(calibration$conforme)) {
    cli::cli_inform(c("i" = "Conformal residuals dropped: measure them again with {.fn conformer_finn} after the correction."))
    calibration$conforme <- NULL
  }
  calibration$correction <- correction
  calibration
}

# Facteur d'une correction (grille x groupe) au G de chaque site, par groupe.
.finn_facteur <- function(table, grille, g, groupe) {
  out <- numeric(length(g))
  for (j in unique(groupe)) {
    i <- which(groupe == j)
    out[i] <- stats::approx(grille, table[, j], xout = g[i], rule = 2)$y
  }
  out
}
