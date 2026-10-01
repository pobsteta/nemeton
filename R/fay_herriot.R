# fay_herriot.R — estimateur Fay-Herriot au niveau du domaine (spec 054, ADR-016)
# -----------------------------------------------------------------------------
# Implémentation maison en R de base (spec 054 D4) : `sae` et `JoSAE` sont sous
# GPL-2 stricte, et le modèle tient en quelques lignes. `sae` reste en Suggests,
# uniquement pour un test d'égalité numérique (tests/testthat/test-fay-herriot.R).
#
# Modèle (Fay & Herriot 1979 ; Rao & Molina 2015, ch. 6) :
#   direct_i = x_i' beta + v_i + e_i,   v_i ~ N(0, A),   e_i ~ N(0, psi_i)
# A estimé par REML (score de Fisher, comme sae::eblupFH), beta par MCG,
# EBLUP = gamma * direct + (1 - gamma) * x' beta, gamma = A / (A + psi).
# MSE de Prasad-Rao / Datta-Lahiri pour REML : g1 + g2 + 2 g3.

#' Fay-Herriot area-level estimator (EBLUP and its MSE)
#'
#' @description
#' Combines, domain by domain, a design-based direct estimate (unbiased but
#' noisy where plots are few) with a synthetic regression prediction on
#' domain-level covariates. The weight given to the direct estimate,
#' `gamma = A / (A + psi)`, grows with the domain's sampling precision, so a
#' well-sampled domain keeps its own figure and a poorly sampled one borrows
#' strength from the others. Every estimate comes with its mean squared error.
#'
#' Domains whose direct estimate or sampling variance is missing (no plot, or a
#' single plot so that `psi` cannot be computed) do not enter the fit; they
#' receive the synthetic prediction alone and are flagged
#' `nature = "synthetique"`, never presented as a measurement.
#'
#' @param direct Numeric vector of direct (design-based) domain estimates.
#'   `NA` for domains without one.
#' @param psi Numeric vector of sampling variances of `direct` (variance of
#'   the mean), treated as known. `NA` or non-positive values send the domain
#'   to the synthetic path.
#' @param X Covariates: a numeric matrix or data.frame with one row per
#'   domain, without intercept (one is added). No `NA` allowed.
#' @param methode Variance estimation method. Only `"REML"` for now.
#' @param max_iter,tol Fisher-scoring controls for the REML fit.
#'
#' @return A data.frame with one row per domain, in input order: `direct`,
#'   `psi`, `synthetique` (x' beta), `gamma`, `estimation`, `mse`, `rse`
#'   (relative standard error, percent), `nature` (`"fay_herriot"` or
#'   `"synthetique"`). Attributes: `beta` (named coefficients), `sigma2_v`
#'   (estimated random-effect variance `A`), `vcov_beta` (covariance matrix
#'   of `beta`, for the MSE of a synthetic prediction `x' beta` outside the
#'   fit: `x' vcov_beta x`), `iterations`, `converge`.
#'
#' @details
#' When the REML estimate of `A` is not positive, it is truncated to 0 with a
#' warning: every estimate is then the synthetic prediction, and the caller
#' must know it.
#'
#' @references
#' Fay R.E., Herriot R.A. (1979). Estimates of income for small places: an
#' application of James-Stein procedures to census data. JASA 74:269-277.
#'
#' Rao J.N.K., Molina I. (2015). Small Area Estimation, 2nd ed. Wiley.
#'
#' Onwunji I.C. et al. (2026). Leveraging GEDI and NFI to inform on forest
#' productivity at the level of the management units. Annals of Forest
#' Science 83:46. doi:10.1186/s13595-026-01358-2
#'
#' @export
#' @examples
#' set.seed(1)
#' x <- runif(30, 10, 30)
#' psi <- runif(30, 0.5, 4)
#' direct <- 2 + 0.3 * x + rnorm(30, 0, 1) + rnorm(30, 0, sqrt(psi))
#' fh <- estimer_fay_herriot(direct, psi, data.frame(h = x))
#' head(fh)
#' attr(fh, "sigma2_v")
estimer_fay_herriot <- function(direct, psi, X, methode = "REML",
                                max_iter = 100L, tol = 1e-6) {
  methode <- match.arg(methode, "REML")
  if (!is.numeric(direct) || !is.numeric(psi) || length(direct) != length(psi)) {
    cli::cli_abort("{.arg direct} and {.arg psi} must be numeric vectors of the same length.")
  }
  X <- as.matrix(X)
  if (!is.numeric(X) || nrow(X) != length(direct)) {
    cli::cli_abort("{.arg X} must be numeric with one row per domain.")
  }
  if (anyNA(X)) cli::cli_abort("{.arg X} must not contain {.val NA}.")
  if (any(!is.na(direct) & !is.finite(direct)) || any(!is.na(psi) & !is.finite(psi))) {
    cli::cli_abort("{.arg direct} and {.arg psi} must be finite (or NA).")
  }
  if (is.null(colnames(X))) colnames(X) <- paste0("x", seq_len(ncol(X)))
  Xc <- cbind("(Intercept)" = 1, X)

  # Domaines entrant dans l'ajustement : direct ET psi utilisables.
  ok <- !is.na(direct) & !is.na(psi) & psi > 0
  m <- sum(ok)
  p <- ncol(Xc)
  if (m <= p) {
    cli::cli_abort("Only {m} domain{?s} with a usable direct estimate for {p} coefficients.")
  }
  y <- direct[ok]
  Xs <- Xc[ok, , drop = FALSE]
  ps <- psi[ok]

  # REML par score de Fisher (meme schema que sae::eblupFH), sans matrice
  # n x n : avec P = V^-1 - V^-1 X Q X' V^-1 (V diagonale),
  #   tr(P)   = sum(vi) - tr(Q X'V^-2 X)
  #   tr(P^2) = sum(vi^2) - 2 tr(Q X'V^-3 X) + tr((Q X'V^-2 X)^2)
  #   P y     = vi * (y - X beta)
  # 5 000 domaines tiennent en quelques Mo au lieu d'environ 1 Go par iteration.
  A <- stats::median(ps)
  it <- 0L
  converge <- FALSE
  for (it in seq_len(max_iter)) {
    vi <- 1 / (A + ps)
    Q <- solve(crossprod(Xs * vi, Xs))
    beta_k <- Q %*% crossprod(Xs, vi * y)
    Py <- vi * (y - drop(Xs %*% beta_k))
    M2 <- Q %*% crossprod(Xs * vi^2, Xs)
    M3 <- Q %*% crossprod(Xs * vi^3, Xs)
    trP <- sum(vi) - sum(diag(M2))
    trP2 <- sum(vi^2) - 2 * sum(diag(M3)) + sum(M2 * t(M2))
    s <- -0.5 * trP + 0.5 * sum(Py^2)
    fisher <- 0.5 * trP2
    A_new <- A + s / fisher
    if (!is.finite(A_new)) {
      cli::cli_abort(c(
        "REML diverged (non-finite variance at iteration {it}).",
        "i" = "Check {.arg direct}, {.arg psi} and {.arg X} for extreme or non-finite values."
      ))
    }
    if (abs(A_new - A) / max(abs(A), 1e-12) < tol) {
      A <- A_new
      converge <- TRUE
      break
    }
    A <- A_new
  }
  if (!converge) {
    cli::cli_warn("REML did not converge in {max_iter} iterations.")
  }
  if (A <= 0) {
    cli::cli_warn(c(
      "Estimated random-effect variance is not positive ({signif(A, 3)}); truncated to 0.",
      "i" = "Every estimate is then the synthetic regression prediction."
    ))
    A <- 0
  }

  vi <- 1 / (A + ps)
  Q <- solve(crossprod(Xs * vi, Xs))
  beta <- drop(Q %*% crossprod(Xs, vi * y))
  names(beta) <- colnames(Xc)

  synth <- drop(Xc %*% beta)
  n <- length(direct)
  gamma <- rep(0, n)
  gamma[ok] <- A / (A + ps)
  estimation <- synth
  estimation[ok] <- gamma[ok] * y + (1 - gamma[ok]) * synth[ok]

  # MSE (Prasad-Rao, correction REML de Datta-Lahiri : 2 g3).
  var_A <- 2 / sum(vi^2)
  g2_all <- rowSums((Xc %*% Q) * Xc)
  mse <- A + g2_all  # chemin synthetique : v_i inconnu
  mse[ok] <- gamma[ok] * ps +
    (1 - gamma[ok])^2 * g2_all[ok] +
    2 * ps^2 / (A + ps)^3 * var_A

  out <- data.frame(
    direct = direct,
    psi = psi,
    synthetique = synth,
    gamma = gamma,
    estimation = estimation,
    mse = mse,
    rse = 100 * sqrt(mse) / abs(estimation),
    nature = ifelse(ok, "fay_herriot", "synthetique"),
    stringsAsFactors = FALSE
  )
  attr(out, "beta") <- beta
  # Covariance de beta (Q = (X' V^-1 X)^-1) : sert a la MSE d'une prediction
  # synthetique pour un domaine hors ajustement (g2 = x' Q x).
  attr(out, "vcov_beta") <- structure(Q, dimnames = list(names(beta), names(beta)))
  attr(out, "sigma2_v") <- A
  attr(out, "iterations") <- it
  attr(out, "converge") <- converge
  out
}
