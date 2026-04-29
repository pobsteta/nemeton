# test-fordead-python.R — reticulate venv helpers (E6.c.1)
#
# These tests never create a real virtualenv. We mock the reticulate
# entry points so the suite stays fast and offline. Tests are skipped
# entirely when reticulate is not installed.

skip_if_no_reticulate <- function() {
  testthat::skip_if_not_installed("reticulate")
}


test_that(".fordead_default_env honours NEMETON_FORDEAD_ENV", {
  withr::with_envvar(c(NEMETON_FORDEAD_ENV = "alt-env"), {
    expect_equal(nemeton:::.fordead_default_env(), "alt-env")
  })
  withr::with_envvar(c(NEMETON_FORDEAD_ENV = NA_character_), {
    expect_equal(nemeton:::.fordead_default_env(), "nemeton-fordead")
  })
})


test_that(".fordead_requirements_path resolves the shipped requirements", {
  p <- nemeton:::.fordead_requirements_path()
  expect_true(file.exists(p))
  txt <- readLines(p)
  expect_true(any(grepl("^fordead==", txt)))
})


test_that(".assert_fordead_system aborts when reticulate is missing", {
  skip_if_no_reticulate()
  testthat::local_mocked_bindings(
    requireNamespace = function(pkg, quietly = FALSE, ...) {
      if (identical(pkg, "reticulate")) FALSE else base::requireNamespace(pkg, quietly = quietly)
    },
    .package = "base"
  )
  expect_error(nemeton:::.assert_fordead_system(),
               "reticulate")
})


test_that(".assert_fordead_system aborts when no Python is found", {
  skip_if_no_reticulate()
  testthat::local_mocked_bindings(
    py_discover_config = function() list(python = "", version = "0.0"),
    .package = "reticulate"
  )
  expect_error(nemeton:::.assert_fordead_system(),
               "Python")
})


test_that(".assert_fordead_system aborts when Python < 3.10", {
  skip_if_no_reticulate()
  testthat::local_mocked_bindings(
    py_discover_config = function() list(python = "/usr/bin/python3", version = "3.9"),
    .package = "reticulate"
  )
  expect_error(nemeton:::.assert_fordead_system(),
               ">= 3.10|3.10")
})


test_that(".assert_fordead_system passes for Python >= 3.10", {
  skip_if_no_reticulate()
  testthat::local_mocked_bindings(
    py_discover_config = function() list(python = "/usr/bin/python3", version = "3.11"),
    .package = "reticulate"
  )
  expect_silent(nemeton:::.assert_fordead_system())
  expect_equal(nemeton:::.assert_fordead_system(), "/usr/bin/python3")
})


test_that(".ensure_fordead_python is idempotent within a session", {
  skip_if_no_reticulate()
  nemeton:::.reset_fordead_state()

  fake_module <- structure(list(tag = "fake-fordead"),
                           class = "python.builtin.module")
  create_calls <- 0L
  install_calls <- 0L

  testthat::local_mocked_bindings(
    py_discover_config  = function() list(python = "/usr/bin/python3", version = "3.11"),
    virtualenv_exists   = function(env) FALSE,
    virtualenv_create   = function(env, ...) { create_calls <<- create_calls + 1L; invisible() },
    virtualenv_install  = function(env, packages = NULL, requirements = NULL,
                                   ignore_installed = FALSE, ...) {
      install_calls <<- install_calls + 1L
      expect_true(file.exists(requirements))
      invisible()
    },
    use_virtualenv      = function(env, required = TRUE) invisible(env),
    import              = function(module, convert = TRUE) fake_module,
    .package = "reticulate"
  )

  m1 <- nemeton:::.ensure_fordead_python(env_name = "test-env-1", verbose = FALSE)
  m2 <- nemeton:::.ensure_fordead_python(env_name = "test-env-1", verbose = FALSE)
  expect_identical(m1, fake_module)
  expect_identical(m1, m2)
  # Cached after the first call: create + install only happen once.
  expect_equal(create_calls,  1L)
  expect_equal(install_calls, 1L)

  nemeton:::.reset_fordead_state()
})


test_that(".ensure_fordead_python skips create when the venv already exists", {
  skip_if_no_reticulate()
  nemeton:::.reset_fordead_state()

  fake_module <- structure(list(tag = "fake-fordead-2"),
                           class = "python.builtin.module")
  create_calls <- 0L
  install_calls <- 0L

  testthat::local_mocked_bindings(
    py_discover_config  = function() list(python = "/usr/bin/python3", version = "3.11"),
    virtualenv_exists   = function(env) TRUE,
    virtualenv_create   = function(env, ...) { create_calls <<- create_calls + 1L; invisible() },
    virtualenv_install  = function(env, ...) { install_calls <<- install_calls + 1L; invisible() },
    use_virtualenv      = function(env, required = TRUE) invisible(env),
    import              = function(module, convert = TRUE) fake_module,
    .package = "reticulate"
  )

  m <- nemeton:::.ensure_fordead_python(env_name = "test-env-2", verbose = FALSE)
  expect_identical(m, fake_module)
  expect_equal(create_calls,  0L)
  expect_equal(install_calls, 0L)

  nemeton:::.reset_fordead_state()
})
