# test-reticulate-isolated.R — isolated reticulate subprocess primitive

test_that(".resolve_isolated_python honours an explicit existing path", {
  tf <- withr::local_tempfile(fileext = ".py"); file.create(tf)
  expect_identical(.resolve_isolated_python(python = tf), tf)
})

test_that(".resolve_isolated_python returns NA when nothing resolves", {
  expect_true(is.na(.resolve_isolated_python(python = "/no/such/python")))
  expect_true(is.na(.resolve_isolated_python()))
})

test_that("no resolvable Python falls back in-process with a warning", {
  expect_warning(
    out <- run_reticulate_isolated(function() 42L),
    "no Python"
  )
  expect_identical(out, 42L)
})

test_that("the subprocess sees the pinned RETICULATE_PYTHON + R_ENVIRON_USER", {
  skip_if_not_installed("callr")
  tf <- withr::local_tempfile(fileext = ".py"); file.create(tf)
  # the child returns the env vars it sees — proves the pin reached it
  got_py <- run_reticulate_isolated(
    function() Sys.getenv("RETICULATE_PYTHON"), python = tf, show = FALSE)
  expect_identical(got_py, tf)
  got_renv <- run_reticulate_isolated(
    function() Sys.getenv("R_ENVIRON_USER"), python = tf, show = FALSE)
  expect_identical(got_renv, "")
})

test_that("args are forwarded to the subprocess function", {
  skip_if_not_installed("callr")
  tf <- withr::local_tempfile(fileext = ".py"); file.create(tf)
  out <- run_reticulate_isolated(
    function(a, b) a + b, args = list(a = 2L, b = 5L), python = tf, show = FALSE)
  expect_identical(out, 7L)
})
