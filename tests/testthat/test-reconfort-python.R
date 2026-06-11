# RECONFORT conda/IOTA2 env helpers (spec 021 L2b.1). No real conda:
# reticulate (env discovery) and the in-env import probe
# (.reconfort_py_imports_ok) are mocked. terra-free, so use testthat's
# own skip_if_not_installed (not the package's terra-probing override).

reset_reconfort_state <- function() {
  st <- nemeton:::.reconfort_state
  st$ready <- FALSE
  st$env <- NULL
  st$pygeodes <- NULL
}

# Mock reticulate's env-discovery surface (conda binary + env list +
# binding). The env list is parameterised by `names`.
mock_reticulate <- function(names = c("base", "test-reconfort"), env = parent.frame()) {
  testthat::local_mocked_bindings(
    conda_binary = function(...) "/opt/conda/bin/conda",
    conda_list = function(...) data.frame(
      name = names, python = paste0("/p/", names), stringsAsFactors = FALSE),
    use_condaenv = function(...) invisible(NULL),
    .package = "reticulate",
    .env = env
  )
}

# Mock the in-env import probe: `ok` is a predicate(module) -> logical.
mock_imports <- function(ok, env = parent.frame()) {
  testthat::local_mocked_bindings(
    .reconfort_py_imports_ok = function(conda_bin, env, modules) ok(modules),
    .env = env
  )
}


test_that("RECONFORT_BANDS lists the six index bands (ni B02 ni B07)", {
  expect_equal(RECONFORT_BANDS, c("B04", "B05", "B06", "B8A", "B11", "B12"))
  expect_false("B02" %in% RECONFORT_BANDS)
  expect_false("B07" %in% RECONFORT_BANDS)
})

test_that(".reconfort_default_env defaults and respects the option/env var", {
  expect_equal(nemeton:::.reconfort_default_env(), "nemeton-reconfort")
  withr::local_options(nemeton.reconfort_conda_env = "my-env")
  expect_equal(nemeton:::.reconfort_default_env(), "my-env")
})

test_that(".reconfort_glue_dir resolves and ships custom_index.py", {
  d <- nemeton:::.reconfort_glue_dir()
  expect_true(dir.exists(d))
  expect_true(file.exists(file.path(d, "custom_index.py")))
})

test_that(".reconfort_conda_binary prefers `conda` over a `mamba` sibling", {
  testthat::skip_if_not_installed("reticulate")
  tmp <- withr::local_tempdir()
  file.create(file.path(tmp, "mamba"), file.path(tmp, "conda"))
  testthat::local_mocked_bindings(
    conda_binary = function(...) file.path(tmp, "mamba"),
    .package = "reticulate"
  )
  expect_equal(nemeton:::.reconfort_conda_binary(), file.path(tmp, "conda"))
})

test_that(".ensure_reconfort_python aborts (with install steps) when env is missing", {
  testthat::skip_if_not_installed("reticulate")
  reset_reconfort_state()
  mock_reticulate(names = c("base", "open_canopy"))
  expect_error(nemeton:::.ensure_reconfort_python(quiet = TRUE), "not found")
})

test_that(".ensure_reconfort_python validates a complete env (iota2 + pygeodes)", {
  testthat::skip_if_not_installed("reticulate")
  reset_reconfort_state()
  withr::local_options(nemeton.reconfort_conda_env = "test-reconfort")
  mock_reticulate(names = c("base", "test-reconfort"))
  mock_imports(function(m) TRUE)
  expect_equal(nemeton:::.ensure_reconfort_python(quiet = TRUE), "test-reconfort")
})

test_that(".ensure_reconfort_python aborts when iota2 is not importable", {
  testthat::skip_if_not_installed("reticulate")
  reset_reconfort_state()
  withr::local_options(nemeton.reconfort_conda_env = "test-reconfort")
  mock_reticulate(names = "test-reconfort")
  mock_imports(function(m) FALSE)
  expect_error(nemeton:::.ensure_reconfort_python(quiet = TRUE), "iota2")
})

test_that(".ensure_reconfort_python: pygeodes required vs optional", {
  testthat::skip_if_not_installed("reticulate")
  withr::local_options(nemeton.reconfort_conda_env = "test-reconfort")
  iota2_only <- function(m) identical(m, "iota2")

  # require_pygeodes = TRUE -> abort.
  reset_reconfort_state()
  mock_reticulate(names = "test-reconfort")
  mock_imports(iota2_only)
  expect_error(
    nemeton:::.ensure_reconfort_python(require_pygeodes = TRUE, quiet = TRUE),
    "pygeodes"
  )
})

test_that(".ensure_reconfort_python: classification-only path (pygeodes optional)", {
  testthat::skip_if_not_installed("reticulate")
  reset_reconfort_state()
  withr::local_options(nemeton.reconfort_conda_env = "test-reconfort")
  mock_reticulate(names = "test-reconfort")
  mock_imports(function(m) identical(m, "iota2"))
  expect_equal(
    nemeton:::.ensure_reconfort_python(require_pygeodes = FALSE, quiet = TRUE),
    "test-reconfort"
  )
})
