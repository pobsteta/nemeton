# Tests for compute_sample_size().
# Cochran formula with Student iteration + finite-population correction.

test_that("compute_sample_size rejects bad inputs", {
  expect_error(compute_sample_size(cv = -1, target_error = 0.1), "non-negative")
  expect_error(compute_sample_size(cv = 0.3, target_error = 0),  "positive")
  expect_error(compute_sample_size(cv = 0.3, target_error = -0.1), "positive")
  expect_error(compute_sample_size(cv = 0.3, target_error = 0.1, alpha = 0),
               "in \\(0, 1\\)")
  expect_error(compute_sample_size(cv = 0.3, target_error = 0.1, alpha = 1),
               "in \\(0, 1\\)")
  expect_error(compute_sample_size(cv = 0.3, target_error = 0.1, N = -1),
               "positive")
})


test_that("converges quickly to the normal-approx answer for large n", {
  # CV = 0.30, E = 0.05 -> n ~ (1.96 * 0.30 / 0.05)^2 = 138.3 -> 139
  res <- compute_sample_size(cv = 0.30, target_error = 0.05)
  expect_true(res$converged)
  expect_true(res$iterations <= 5L)
  expect_gte(res$n, 138L)
  expect_lte(res$n, 142L)   # allow the 1-2 plot Student bump
  expect_equal(res$df, res$n - 1L)
  expect_false(res$fpc_applied)
})


test_that("small n gets a larger t than 1.96 and more plots than normal approx", {
  # CV = 0.8, E = 0.30 -> normal approx n ~ 27; t-correction should keep
  # n slightly above the normal approx.
  res <- compute_sample_size(cv = 0.8, target_error = 0.30)
  n_normal <- ceiling((stats::qnorm(0.975) * 0.8 / 0.30)^2)
  expect_gte(res$n, n_normal)
  expect_gt(res$t_used, 1.96)
  expect_lt(res$t_used, 2.10)  # for df ~ 27
})


test_that("finite-population correction reduces n", {
  base <- compute_sample_size(cv = 0.30, target_error = 0.05)
  with_fpc <- compute_sample_size(cv = 0.30, target_error = 0.05, N = 200)
  expect_true(with_fpc$fpc_applied)
  expect_false(base$fpc_applied)
  expect_lt(with_fpc$n, base$n)
  # 1/n_corr = 1/n + 1/N  -> n_corr = n * N / (n + N)
  expected <- base$n * 200 / (base$n + 200)
  expect_lte(abs(with_fpc$n - ceiling(expected)), 1)
})


test_that("minimum n is 2", {
  # CV = 0 collapses n to 0; we clamp to 2 for df >= 1.
  res <- compute_sample_size(cv = 0, target_error = 0.10)
  expect_equal(res$n, 2L)
})


test_that("n inversely scales with CV^2 and with 1/E^2", {
  r1 <- compute_sample_size(cv = 0.3, target_error = 0.10)
  r2 <- compute_sample_size(cv = 0.6, target_error = 0.10)
  # Doubling CV -> quadrupling n (roughly; Student bumps slightly).
  expect_gte(r2$n / r1$n, 3.5)
  expect_lte(r2$n / r1$n, 4.5)

  r3 <- compute_sample_size(cv = 0.3, target_error = 0.05)
  expect_gte(r3$n / r1$n, 3.5)
  expect_lte(r3$n / r1$n, 4.5)
})
