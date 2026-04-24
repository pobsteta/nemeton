#' Sample Size from Target Relative Error and CV
#'
#' @description
#' Classic Cochran formula for the number of plots needed to estimate
#' a mean with a target relative error \eqn{E}:
#' \deqn{n \ge \left(\frac{t_{1-\alpha/2, n-1} \cdot CV}{E}\right)^2}
#'
#' The Student quantile depends on \eqn{n-1} degrees of freedom, so
#' the formula is solved iteratively: start from the normal
#' approximation (\eqn{z_{1-\alpha/2}}), plug back \eqn{t} with the
#' updated \eqn{df}, until \eqn{n} converges (usually 2-4 iterations).
#'
#' An optional finite-population correction (FPC) is applied when the
#' population size \eqn{N} is provided:
#' \deqn{n_{corr} = \frac{n}{1 + n / N}}
#'
#' The target variable is the basal area \eqn{G}/ha by convention
#' (IFN / PPtools, Bruciamacchie 2014, GPL-2). Formulas are standard
#' sampling theory and are not copyrightable; we re-implement them
#' from scratch without reusing any PPtools source.
#'
#' @name sample_size
#' @keywords internal
NULL


#' Sample size for a target relative error and a given CV
#'
#' @param cv Numeric. Coefficient of variation as a fraction (e.g.,
#'   0.35 for 35 \%). Non-negative.
#' @param target_error Numeric. Target relative error on the mean, as
#'   a fraction (e.g., 0.10 for \eqn{\pm}10 \%). Strictly positive.
#' @param alpha Numeric. Significance level. Default 0.05
#'   (95 \% confidence).
#' @param N Optional. Population size (number of plots the AOI can
#'   host at the target plot density). When provided, a finite-
#'   population correction is applied.
#' @param max_iter Integer. Maximum number of Student-iteration steps.
#'   Default 20 (convergence is typically reached in 2-4).
#' @param tol Numeric. Convergence tolerance on \eqn{n} between two
#'   iterations. Default 0.5 (half a plot).
#'
#' @return A list with:
#'   \itemize{
#'     \item \code{n}: the minimum sample size (rounded up).
#'     \item \code{t_used}: the Student quantile at convergence.
#'     \item \code{df}: degrees of freedom at convergence
#'       (\eqn{n - 1}).
#'     \item \code{converged}: logical.
#'     \item \code{iterations}: number of iterations.
#'     \item \code{fpc_applied}: logical, TRUE when \code{N} was used.
#'     \item \code{inputs}: echo of \code{cv}, \code{target_error},
#'       \code{alpha}, \code{N}.
#'   }
#'
#' @examples
#' # Conifer plantation, ±10 % on G/ha, 95 % confidence:
#' compute_sample_size(cv = 0.30, target_error = 0.10)
#'
#' # Same, with an AOI that hosts at most 200 plots:
#' compute_sample_size(cv = 0.30, target_error = 0.10, N = 200)
#'
#' @export
compute_sample_size <- function(cv,
                                target_error,
                                alpha = 0.05,
                                N = NULL,
                                max_iter = 20L,
                                tol = 0.5) {
  if (!is.numeric(cv) || length(cv) != 1L || is.na(cv) || cv < 0) {
    cli::cli_abort("{.arg cv} must be a non-negative scalar.")
  }
  if (!is.numeric(target_error) || length(target_error) != 1L ||
      is.na(target_error) || target_error <= 0) {
    cli::cli_abort("{.arg target_error} must be a positive scalar.")
  }
  if (!is.numeric(alpha) || length(alpha) != 1L ||
      alpha <= 0 || alpha >= 1) {
    cli::cli_abort("{.arg alpha} must be in (0, 1).")
  }
  if (!is.null(N)) {
    if (!is.numeric(N) || length(N) != 1L || is.na(N) || N < 1) {
      cli::cli_abort("{.arg N} must be a positive scalar when provided.")
    }
  }

  # --- First guess with the normal approximation ----------------------
  z <- stats::qnorm(1 - alpha / 2)
  n <- (z * cv / target_error)^2
  n <- max(n, 2)  # need df >= 1

  converged <- FALSE
  t_used <- z
  iters  <- 0L

  for (i in seq_len(max_iter)) {
    iters <- i
    n_prev <- n
    df <- max(n_prev - 1, 1)
    t_used <- stats::qt(1 - alpha / 2, df = df)
    n <- (t_used * cv / target_error)^2
    if (abs(n - n_prev) < tol) {
      converged <- TRUE
      break
    }
  }

  # --- Finite-population correction -----------------------------------
  fpc_applied <- FALSE
  if (!is.null(N)) {
    n <- n / (1 + n / N)
    fpc_applied <- TRUE
  }

  n_final <- as.integer(ceiling(n))
  if (n_final < 2L) n_final <- 2L

  list(
    n          = n_final,
    t_used     = t_used,
    df         = max(n_final - 1L, 1L),
    converged  = converged,
    iterations = iters,
    fpc_applied = fpc_applied,
    inputs     = list(cv = cv, target_error = target_error,
                      alpha = alpha, N = N)
  )
}
