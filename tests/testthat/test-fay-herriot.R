# Tests estimer_fay_herriot() — spec 054 §4, ADR-016.

simuler_fh <- function(n = 40, seed = 42) {
  set.seed(seed)
  x1 <- runif(n, 10, 30)
  x2 <- rnorm(n)
  psi <- runif(n, 0.5, 4)
  y <- 2 + 0.3 * x1 + 0.5 * x2 + rnorm(n, 0, 1.2) + rnorm(n, 0, sqrt(psi))
  list(y = y, psi = psi, X = data.frame(x1 = x1, x2 = x2))
}

test_that("the in-house EBLUP and MSE reproduce sae::mseFH (REML)", {
  skip_if_not_installed("sae")
  s <- simuler_fh()
  fh <- estimer_fay_herriot(s$y, s$psi, s$X, tol = 1e-12)
  d <- data.frame(y = s$y, s$X, psi = s$psi)
  ref <- sae::mseFH(y ~ x1 + x2, psi, method = "REML", data = d,
                    PRECISION = 1e-12, MAXITER = 500)
  expect_equal(attr(fh, "sigma2_v"), ref$est$fit$refvar, tolerance = 1e-8)
  expect_equal(unname(attr(fh, "beta")), unname(ref$est$fit$estcoef[, 1]),
               tolerance = 1e-8)
  expect_equal(fh$estimation, as.numeric(ref$est$eblup), tolerance = 1e-8)
  expect_equal(fh$mse, as.numeric(ref$mse), tolerance = 1e-8)
})

test_that("gamma weighs the direct estimate by its precision", {
  s <- simuler_fh()
  fh <- estimer_fay_herriot(s$y, s$psi, s$X)
  A <- attr(fh, "sigma2_v")
  expect_equal(fh$gamma, A / (A + s$psi))
  expect_equal(fh$estimation,
               fh$gamma * s$y + (1 - fh$gamma) * fh$synthetique)
  # Plus psi est grand, plus l'estimation s'eloigne du direct.
  expect_lt(cor(s$psi, fh$gamma), 0)
  expect_true(all(fh$nature == "fay_herriot"))
  expect_true(all(fh$mse < s$psi))
})

test_that("domains without a usable direct estimate go synthetic, never silent", {
  s <- simuler_fh()
  s$y[1] <- NA          # aucune placette
  s$psi[2] <- NA        # une seule placette : psi incalculable
  s$psi[3] <- 0         # psi nul : pas d'information de variance
  fh <- estimer_fay_herriot(s$y, s$psi, s$X)
  expect_equal(fh$nature[1:3], rep("synthetique", 3))
  expect_equal(fh$estimation[1:3], fh$synthetique[1:3])
  expect_equal(fh$gamma[1:3], rep(0, 3))
  # Chemin synthetique : MSE = A + g2, au-dessus de la seule variance du modele.
  expect_true(all(fh$mse[1:3] > attr(fh, "sigma2_v")))
  expect_true(all(fh$nature[-(1:3)] == "fay_herriot"))
})

test_that("a non-positive random-effect variance is truncated with a warning", {
  set.seed(3)
  n <- 30
  x <- runif(n, 0, 10)
  psi <- rep(4, n)
  # Aucun effet domaine : la dispersion est entierement d'echantillonnage.
  y <- 1 + 0.5 * x + rnorm(n, 0, 0.5)
  expect_warning(fh <- estimer_fay_herriot(y, psi, data.frame(x = x)),
                 "truncated to 0")
  expect_equal(attr(fh, "sigma2_v"), 0)
  expect_equal(fh$estimation, fh$synthetique)
})

test_that("inputs are validated", {
  s <- simuler_fh()
  expect_error(estimer_fay_herriot(s$y, s$psi[-1], s$X), "same length")
  X <- s$X
  X$x1[1] <- NA
  expect_error(estimer_fay_herriot(s$y, s$psi, X), "NA")
  expect_error(estimer_fay_herriot(s$y[1:3], s$psi[1:3], s$X[1:3, ]),
               "usable direct")
})
