#' Effects of management estimated from the project's own units
#'
#' Estimates, for each unit and each family index (or indicator), the effect
#' of the declared management type compared with a reference type, from the
#' units of the project themselves: a T- or X-learner (Kunzel et al. 2019)
#' fitted on covariates that describe the site (P2, altitude, slope, SER).
#' The overlap between treated and reference units is checked on a
#' propensity score; units outside the common support are left out, and the
#' function refuses to conclude when too few units are comparable
#' (spec 068, chantier D, step 1). It needs no simulation model: it says what
#' management has produced on this massif, so that a simulation can later be
#' confronted with it.
#'
#' @param units sf or data.frame of units.
#' @param traitement Character. Column holding the declared management type
#'   (e.g. `"type_sylviculture"`, or the `itineraire_actuel` of spec 065).
#'   Default `"type_sylviculture"`.
#' @param resultats Character. Outcome columns. `NULL` (default): the
#'   family indices present (`famille_*`).
#' @param covariables Character. Site covariates. Only those present in
#'   `units` are used; at least one is required. Default
#'   `c("P2", "altitude", "pente", "ser")`.
#' @param reference Character. Reference level of `traitement`. `NULL`: the
#'   most frequent level.
#' @param methode `"x_learner"` (default) or `"t_learner"`.
#' @param support_min Numeric in `[0, 1]`. Minimum share of the units of a
#'   contrast that must lie in the common support; below it the contrast is
#'   refused (`recouvrement_insuffisant`). Default 0.7 (spec 068, D-4).
#' @param min_par_traitement Integer. Minimum number of units per level in a
#'   contrast; below it, `trop_peu_unites`. Default 10 (D-4).
#' @param n_boot Integer. Bootstrap replicates for the intervals. Default 50.
#' @param graine Integer. Random seed. Default 1.
#'
#' @return A list of class `"effet_gestion"`:
#'   \describe{
#'     \item{resume}{one row per contrast (`traitement` against `reference`)
#'       and outcome: `traitement`, `reference`, `resultat`, `n_traite`,
#'       `n_reference`, `part_support`, `effet_moyen` (doubly robust, AIPW,
#'       mean effect over the units in the support), `ic_bas`, `ic_haut`
#'       (90 % interval from its influence function), `statut` (`calcule`,
#'       `recouvrement_insuffisant`, `trop_peu_unites`).}
#'     \item{unites}{one row per unit of a computed contrast and outcome:
#'       `unite` (row number), `traitement`, `resultat`, `effet` (individual
#'       effect from the T- or X-learner), `ic_bas`, `ic_haut` (bootstrap
#'       5-95 % quantiles, indicative), `support`; `NA` outside the support.}
#'     \item{reference, methode, apprenant, covariables}{what was used;
#'       `apprenant` is `"ranger"` when installed, else `"lm"`.}
#'   }
#'
#' @details
#' **Learners.** T-learner: one outcome model per group, the effect is the
#' difference of their predictions. X-learner: the effects imputed in each
#' group are modelled in turn and mixed by the propensity score, which suits
#' unbalanced groups (Kunzel et al. 2019). Outcome models are random forests
#' (\pkg{ranger}) when installed, else linear models.
#'
#' **Mean effect.** The summary uses an augmented inverse-probability
#' weighting estimator (AIPW, doubly robust) on the units in the support,
#' with out-of-bag predictions of the outcome models; `methode` only changes
#' the individual effects. On simulated data (150 units, effect 8, strong
#' confounding by P2, 30 draws), the naive difference of means gave 18.5,
#' the AIPW estimate 7.1 on average, and its 90 % interval covered the true
#' value 93 % of the time: a small downward bias remains with forests.
#'
#' **Support.** Propensity score by logistic regression on the covariates; a
#' unit is in the common support when its score lies within the range shared
#' by both groups and within `[0.05, 0.95]`.
#'
#' **What it is not** (fiche): an association adjusted for the covariates,
#' not a causal effect unless every confounder is among them; a declared
#' management type is not necessarily the one applied; with few units per
#' type the intervals are wide. Results enter the AI perspectives as results
#' of the project, cited as such.
#'
#' @section Lifecycle:
#' Experimental (spec 068): may change in any release.
#'
#' @references
#' Kunzel, S. R., Sekhon, J. S., Bickel, P. J. & Yu, B. (2019). Metalearners
#' for estimating heterogeneous treatment effects using machine learning.
#' *PNAS* 116(10), 4156-4165.
#'
#' @seealso [comparer_itineraires()]
#' @export
#' @examples
#' set.seed(1)
#' n <- 120
#' d <- data.frame(P2 = runif(n, 2, 10), altitude = runif(n, 200, 900))
#' d$type_sylviculture <- ifelse(runif(n) < plogis((d$P2 - 6) / 2), "irregulier", "regulier")
#' d$famille_biodiversite <- 40 + 3 * d$P2 + 8 * (d$type_sylviculture == "irregulier") + rnorm(n, 0, 3)
#' e <- effet_gestion(d, reference = "regulier", n_boot = 20)
#' e$resume
effet_gestion <- function(units,
                          traitement = "type_sylviculture",
                          resultats = NULL,
                          covariables = c("P2", "altitude", "pente", "ser"),
                          reference = NULL,
                          methode = c("x_learner", "t_learner"),
                          support_min = 0.7,
                          min_par_traitement = 10L,
                          n_boot = 50L,
                          graine = 1L) {
  methode <- match.arg(methode)
  d <- if (inherits(units, "sf")) sf::st_drop_geometry(units) else as.data.frame(units)
  if (!traitement %in% names(d)) {
    cli::cli_abort("Treatment column {.field {traitement}} not found.")
  }
  if (is.null(resultats)) resultats <- grep("^famille_", names(d), value = TRUE)
  absents <- setdiff(resultats, names(d))
  if (!length(resultats) || length(absents)) {
    cli::cli_abort("Outcome columns missing: {.field {if (length(absents)) absents else 'famille_*'}}.")
  }
  cov <- intersect(covariables, names(d))
  if (!length(cov)) {
    cli::cli_abort("None of the covariates {.field {covariables}} is in {.arg units}.")
  }
  if (!is.numeric(support_min) || support_min < 0 || support_min > 1) {
    cli::cli_abort("{.arg support_min} must be in [0, 1].")
  }
  n_boot <- as.integer(n_boot)
  if (n_boot < 2L) cli::cli_abort("{.arg n_boot} must be at least 2.")

  tr <- as.character(d[[traitement]])
  niveaux <- sort(unique(tr[!is.na(tr)]))
  if (length(niveaux) < 2L) cli::cli_abort("{.field {traitement}} needs at least two levels.")
  if (is.null(reference)) reference <- names(sort(table(tr), decreasing = TRUE))[1]
  if (!reference %in% niveaux) cli::cli_abort("Reference {.val {reference}} is not a level of {.field {traitement}}.")
  apprenant <- if (.eg_ranger_ok()) "ranger" else "lm"

  X <- d[, cov, drop = FALSE]
  for (v in cov) if (is.character(X[[v]])) X[[v]] <- factor(X[[v]])
  complet <- stats::complete.cases(X) & !is.na(tr)

  ancienne <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv())
  on.exit(if (!is.null(ancienne)) assign(".Random.seed", ancienne, envir = globalenv()), add = TRUE)
  set.seed(graine)

  resume <- list()
  unites <- list()
  for (niv in setdiff(niveaux, reference)) {
    idx <- which(complet & tr %in% c(niv, reference))
    w <- as.integer(tr[idx] == niv)
    Xc <- droplevels(X[idx, , drop = FALSE])
    n1 <- sum(w == 1L); n0 <- sum(w == 0L)
    ligne <- function(res, statut, part = NA_real_, m = NA_real_, lo = NA_real_, hi = NA_real_) {
      data.frame(traitement = niv, reference = reference, resultat = res,
                 n_traite = n1, n_reference = n0, part_support = part,
                 effet_moyen = m, ic_bas = lo, ic_haut = hi, statut = statut)
    }
    if (n1 < min_par_traitement || n0 < min_par_traitement) {
      resume <- c(resume, lapply(resultats, ligne, statut = "trop_peu_unites"))
      next
    }
    ps <- .eg_propension(Xc, w)
    commun <- c(max(min(ps[w == 1L]), min(ps[w == 0L])), min(max(ps[w == 1L]), max(ps[w == 0L])))
    support <- ps >= max(commun[1], 0.05) & ps <= min(commun[2], 0.95)
    part <- mean(support)
    if (part < support_min || sum(support & w == 1L) < 2L || sum(support & w == 0L) < 2L) {
      resume <- c(resume, lapply(resultats, ligne, statut = "recouvrement_insuffisant", part = part))
      next
    }
    for (res in resultats) {
      y <- suppressWarnings(as.numeric(d[[res]][idx]))
      ok <- support & !is.na(y)
      tau <- rep(NA_real_, length(idx))
      tau[ok] <- .eg_effet(Xc[ok, , drop = FALSE], y[ok], w[ok], ps[ok], methode, apprenant)
      # bootstrap stratifie par groupe, sur les unites du support
      boot <- matrix(NA_real_, sum(ok), n_boot)
      i1 <- which(ok & w == 1L); i0 <- which(ok & w == 0L)
      for (b in seq_len(n_boot)) {
        tire <- c(i1[sample.int(length(i1), replace = TRUE)], i0[sample.int(length(i0), replace = TRUE)])
        boot[, b] <- .eg_effet(Xc[tire, , drop = FALSE], y[tire], w[tire], ps[tire], methode, apprenant,
                               nouveau = Xc[ok, , drop = FALSE], ps_nouveau = ps[ok])
      }
      q <- t(apply(boot, 1L, stats::quantile, probs = c(0.05, 0.95), na.rm = TRUE))
      # effet moyen doublement robuste (AIPW), predictions hors echantillon
      aipw <- .eg_aipw(Xc[ok, , drop = FALSE], y[ok], w[ok], ps[ok], apprenant)
      resume[[length(resume) + 1L]] <- ligne(
        res, "calcule", part = part, m = aipw[["estimation"]],
        lo = aipw[["ic_bas"]], hi = aipw[["ic_haut"]])
      e <- rep(NA_real_, length(idx)); lo <- e; hi <- e
      e[ok] <- tau[ok]; lo[ok] <- q[, 1]; hi[ok] <- q[, 2]
      unites[[length(unites) + 1L]] <- data.frame(
        unite = idx, traitement = tr[idx], resultat = res,
        effet = e, ic_bas = lo, ic_haut = hi, support = support)
    }
  }

  vide <- data.frame(unite = integer(0), traitement = character(0), resultat = character(0),
                     effet = numeric(0), ic_bas = numeric(0), ic_haut = numeric(0),
                     support = logical(0))
  structure(list(
    resume = do.call(rbind, resume),
    unites = if (length(unites)) do.call(rbind, unites) else vide,
    reference = reference,
    methode = methode,
    apprenant = apprenant,
    covariables = cov
  ), class = "effet_gestion")
}

#' @export
print.effet_gestion <- function(x, ...) {
  cat(sprintf("Management effects (%s, %s), reference: %s; covariates: %s\n",
              x$methode, x$apprenant, x$reference, paste(x$covariables, collapse = ", ")))
  print(x$resume, row.names = FALSE)
  cat("Association adjusted for the covariates, not a proven causal effect.\n")
  invisible(x)
}

# ranger est-il installe ? (fonction a part pour la simuler en test)
.eg_ranger_ok <- function() requireNamespace("ranger", quietly = TRUE)

# Score de propension : regression logistique sur les covariables.
.eg_propension <- function(X, w) {
  dd <- cbind(X, .w = w)
  m <- suppressWarnings(stats::glm(.w ~ ., data = dd, family = stats::binomial()))
  p <- suppressWarnings(stats::predict(m, newdata = X, type = "response"))
  pmin(pmax(as.numeric(p), 1e-6), 1 - 1e-6)
}

# Modele de resultat (ranger, sinon lm) : rend une fonction de prediction,
# avec l'attribut "hors_sac" (predictions hors echantillon sur les donnees
# d'apprentissage : out-of-bag pour ranger, ajustees pour lm).
.eg_modele <- function(X, y, apprenant) {
  dd <- cbind(X, .y = y)
  if (apprenant == "ranger" && nrow(dd) >= 5L) {
    m <- ranger::ranger(.y ~ ., data = dd, num.trees = 200L, min.node.size = 3L,
                        seed = sample.int(.Machine$integer.max, 1L))
    f <- function(nouveau) stats::predict(m, data = nouveau)$predictions
    attr(f, "hors_sac") <- m$predictions
    f
  } else {
    # facteurs reduits a un niveau : retires pour lm
    garde <- vapply(X, function(v) !is.factor(v) || nlevels(droplevels(v)) > 1L, logical(1))
    dd <- cbind(X[, garde, drop = FALSE], .y = y)
    m <- stats::lm(.y ~ ., data = dd)
    f <- function(nouveau) suppressWarnings(as.numeric(stats::predict(m, newdata = nouveau[, garde, drop = FALSE])))
    attr(f, "hors_sac") <- as.numeric(stats::fitted(m))
    f
  }
}

# Effet moyen doublement robuste (AIPW) sur les unites fournies, intervalle a
# 90 % par la variance de la fonction d'influence. Les predictions des
# modeles de resultat sur leur propre groupe sont hors echantillon (OOB).
.eg_aipw <- function(X, y, w, ps, apprenant) {
  m1 <- .eg_modele(X[w == 1L, , drop = FALSE], y[w == 1L], apprenant)
  m0 <- .eg_modele(X[w == 0L, , drop = FALSE], y[w == 0L], apprenant)
  mu1 <- m1(X); mu0 <- m0(X)
  mu1[w == 1L] <- attr(m1, "hors_sac")
  mu0[w == 0L] <- attr(m0, "hors_sac")
  ps <- pmin(pmax(ps, 0.05), 0.95)
  psi <- mu1 - mu0 + w * (y - mu1) / ps - (1 - w) * (y - mu0) / (1 - ps)
  est <- mean(psi)
  se <- stats::sd(psi) / sqrt(length(psi))
  z <- stats::qnorm(0.95)
  c(estimation = est, ic_bas = est - z * se, ic_haut = est + z * se)
}

# Effet individuel par T- ou X-learner, predit sur `nouveau`.
.eg_effet <- function(X, y, w, ps, methode, apprenant, nouveau = X, ps_nouveau = ps) {
  m1 <- .eg_modele(X[w == 1L, , drop = FALSE], y[w == 1L], apprenant)
  m0 <- .eg_modele(X[w == 0L, , drop = FALSE], y[w == 0L], apprenant)
  if (methode == "t_learner") return(m1(nouveau) - m0(nouveau))
  d1 <- y[w == 1L] - m0(X[w == 1L, , drop = FALSE])
  d0 <- m1(X[w == 0L, , drop = FALSE]) - y[w == 0L]
  t1 <- .eg_modele(X[w == 1L, , drop = FALSE], d1, apprenant)
  t0 <- .eg_modele(X[w == 0L, , drop = FALSE], d0, apprenant)
  ps_nouveau * t0(nouveau) + (1 - ps_nouveau) * t1(nouveau)
}
