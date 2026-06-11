# RECONFORT conda/IOTA2 env helpers (spec 021 L2b.1). No real conda /
# reticulate: reticulate is mocked. terra-free, so call testthat's own
# skip_if_not_installed (not the package's terra-probing override).

# Reset the session cache so each test re-validates from scratch.
reset_reconfort_state <- function() {
  st <- nemeton:::.reconfort_state
  st$ready <- FALSE
  st$env <- NULL
  st$pygeodes <- NULL
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

test_that(".ensure_reconfort_python aborts (with install steps) when env is missing", {
  testthat::skip_if_not_installed("reticulate")
  reset_reconfort_state()
  testthat::local_mocked_bindings(
    conda_list = function(...) data.frame(
      name = c("base", "open_canopy"),
      python = c("/x", "/y"), stringsAsFactors = FALSE),
    .package = "reticulate"
  )
  expect_error(
    nemeton:::.ensure_reconfort_python(quiet = TRUE),
    "not found"
  )
})

test_that(".ensure_reconfort_python validates a complete env (iota2 + pygeodes)", {
  testthat::skip_if_not_installed("reticulate")
  reset_reconfort_state()
  withr::local_options(nemeton.reconfort_conda_env = "test-reconfort")
  testthat::local_mocked_bindings(
    conda_list = function(...) data.frame(
      name = c("base", "test-reconfort"),
      python = c("/a", "/b"), stringsAsFactors = FALSE),
    use_condaenv = function(...) invisible(NULL),
    py_config = function(...) list(version = numeric_version("3.9"), python = "/b"),
    py_module_available = function(module) module %in% c("iota2", "pygeodes"),
    .package = "reticulate"
  )
  expect_equal(nemeton:::.ensure_reconfort_python(quiet = TRUE), "test-reconfort")
})

test_that(".ensure_reconfort_python aborts when iota2 is not importable", {
  testthat::skip_if_not_installed("reticulate")
  reset_reconfort_state()
  withr::local_options(nemeton.reconfort_conda_env = "test-reconfort")
  testthat::local_mocked_bindings(
    conda_list = function(...) data.frame(
      name = "test-reconfort", python = "/b", stringsAsFactors = FALSE),
    use_condaenv = function(...) invisible(NULL),
    py_config = function(...) list(version = numeric_version("3.9")),
    py_module_available = function(module) FALSE,
    .package = "reticulate"
  )
  expect_error(
    nemeton:::.ensure_reconfort_python(quiet = TRUE),
    "iota2"
  )
})

test_that(".ensure_reconfort_python: pygeodes required vs optional", {
  testthat::skip_if_not_installed("reticulate")
  withr::local_options(nemeton.reconfort_conda_env = "test-reconfort")
  iota2_only <- function(module) identical(module, "iota2")
  mock <- function() testthat::local_mocked_bindings(
    conda_list = function(...) data.frame(
      name = "test-reconfort", python = "/b", stringsAsFactors = FALSE),
    use_condaenv = function(...) invisible(NULL),
    py_config = function(...) list(version = numeric_version("3.10")),
    py_module_available = iota2_only,
    .package = "reticulate",
    .env = parent.frame()
  )

  # require_pygeodes = TRUE -> abort.
  reset_reconfort_state(); mock()
  expect_error(
    nemeton:::.ensure_reconfort_python(require_pygeodes = TRUE, quiet = TRUE),
    "pygeodes"
  )

  # require_pygeodes = FALSE -> success (classification-only path).
  reset_reconfort_state(); mock()
  expect_equal(
    nemeton:::.ensure_reconfort_python(require_pygeodes = FALSE, quiet = TRUE),
    "test-reconfort"
  )
})
