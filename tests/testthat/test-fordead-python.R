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
  # fordead lives on gitlab.com (not PyPI) so the pin is a PEP 508 URL.
  expect_true(any(grepl("^fordead\\b", txt)))
  expect_true(any(grepl("git\\+https://gitlab\\.com/fordead", txt)))
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
  # Healthy venv: fordead is importable, so .ensure_fordead_python
  # must skip both create AND install.
  testthat::local_mocked_bindings(
    .fordead_is_installed = function(env_name) TRUE,
    .package = "nemeton"
  )

  m <- nemeton:::.ensure_fordead_python(env_name = "test-env-2", verbose = FALSE)
  expect_identical(m, fake_module)
  expect_equal(create_calls,  0L)
  expect_equal(install_calls, 0L)

  nemeton:::.reset_fordead_state()
})


test_that(".ensure_fordead_python reinstalls when fordead is missing from existing venv", {
  skip_if_no_reticulate()
  nemeton:::.reset_fordead_state()

  fake_module <- structure(list(tag = "fake-fordead-3"),
                           class = "python.builtin.module")
  create_calls <- 0L
  install_calls <- 0L

  testthat::local_mocked_bindings(
    py_discover_config  = function() list(python = "/usr/bin/python3", version = "3.11"),
    virtualenv_exists   = function(env) TRUE,
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
  # Corrupted venv: directory exists but `import fordead` would fail.
  # Expect: no create (venv is there), one install (recovery path).
  testthat::local_mocked_bindings(
    .fordead_is_installed = function(env_name) FALSE,
    .package = "nemeton"
  )

  m <- expect_message(
    nemeton:::.ensure_fordead_python(env_name = "test-env-3", verbose = TRUE),
    "missing"
  )
  expect_identical(m, fake_module)
  expect_equal(create_calls,  0L)
  expect_equal(install_calls, 1L)

  nemeton:::.reset_fordead_state()
})


test_that(".fordead_is_installed returns FALSE when the venv python is absent", {
  skip_if_no_reticulate()

  # Point virtualenv_python at a non-existent path: file.exists() returns
  # FALSE, the function short-circuits without invoking system2.
  testthat::local_mocked_bindings(
    virtualenv_python = function(env) tempfile("no-such-python-"),
    .package = "reticulate"
  )
  expect_false(nemeton:::.fordead_is_installed("phantom-env"))
})


test_that(".fordead_is_installed reflects the python import probe", {
  skip_if_no_reticulate()

  fake_py <- tempfile("fake-py-"); file.create(fake_py)
  on.exit(unlink(fake_py), add = TRUE)

  testthat::local_mocked_bindings(
    virtualenv_python = function(env) fake_py,
    .package = "reticulate"
  )

  # Probe says OK -> TRUE
  testthat::local_mocked_bindings(
    .fordead_python_import_ok = function(py_path, module = "fordead") TRUE,
    .package = "nemeton"
  )
  expect_true(nemeton:::.fordead_is_installed("any-env"))

  # Probe says KO -> FALSE
  testthat::local_mocked_bindings(
    .fordead_python_import_ok = function(py_path, module = "fordead") FALSE,
    .package = "nemeton"
  )
  expect_false(nemeton:::.fordead_is_installed("any-env"))
})
