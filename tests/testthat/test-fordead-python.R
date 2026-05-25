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
  # Capture the original `requireNamespace` *before* mocking, so the
  # else-branch of the mock doesn't recurse into itself
  # (`base::requireNamespace` from inside the mock body resolves to
  # the mock again because `local_mocked_bindings(.package = "base")`
  # replaces the namespace binding).
  real_require <- base::requireNamespace
  testthat::local_mocked_bindings(
    requireNamespace = function(pkg, quietly = FALSE, ...) {
      if (identical(pkg, "reticulate")) return(FALSE)
      real_require(pkg, quietly = quietly)
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
  # Also block the PATH fallback so the assertion really has no Python.
  testthat::local_mocked_bindings(
    .find_python_on_path = function() "",
    .package = "nemeton"
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
  # Hermetic: hide any developer-set RETICULATE_PYTHON for the test.
  withr::local_envvar(c(RETICULATE_PYTHON = ""))

  fake_module <- structure(list(tag = "fake-fordead"),
                           class = "python.builtin.module")
  create_calls <- 0L
  install_calls <- 0L

  testthat::local_mocked_bindings(
    py_discover_config  = function() list(python = "/usr/bin/python3", version = "3.11"),
    virtualenv_exists   = function(env) FALSE,
    virtualenv_python   = function(env) sprintf("~/.virtualenvs/%s/bin/python", env),
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
  withr::local_envvar(c(RETICULATE_PYTHON = ""))

  fake_module <- structure(list(tag = "fake-fordead-2"),
                           class = "python.builtin.module")
  create_calls <- 0L
  install_calls <- 0L

  testthat::local_mocked_bindings(
    py_discover_config  = function() list(python = "/usr/bin/python3", version = "3.11"),
    virtualenv_exists   = function(env) TRUE,
    virtualenv_python   = function(env) sprintf("~/.virtualenvs/%s/bin/python", env),
    virtualenv_create   = function(env, ...) { create_calls <<- create_calls + 1L; invisible() },
    virtualenv_install  = function(env, ...) { install_calls <<- install_calls + 1L; invisible() },
    use_virtualenv      = function(env, required = TRUE) invisible(env),
    import              = function(module, convert = TRUE) fake_module,
    .package = "reticulate"
  )
  # Healthy venv: fordead is importable, so .ensure_fordead_python
  # must skip both create AND install.
  testthat::local_mocked_bindings(
    .fordead_is_installed = function(env_name, requirements_path = NULL) TRUE,
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
  withr::local_envvar(c(RETICULATE_PYTHON = ""))

  fake_module <- structure(list(tag = "fake-fordead-3"),
                           class = "python.builtin.module")
  create_calls <- 0L
  install_calls <- 0L

  testthat::local_mocked_bindings(
    py_discover_config  = function() list(python = "/usr/bin/python3", version = "3.11"),
    virtualenv_exists   = function(env) TRUE,
    virtualenv_python   = function(env) sprintf("~/.virtualenvs/%s/bin/python", env),
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
    .fordead_is_installed = function(env_name, requirements_path = NULL) FALSE,
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


# ----- PATH fallback when py_discover_config returns nothing -----------

test_that(".probe_python_version parses major.minor from --version output", {
  skip_if_no_reticulate()
  # The real interpreter probably reports its version on stdout (Python ≥ 3.4)
  # or stderr (older). We don't care which — only that we parse a number.
  py <- unname(Sys.which("python3"))
  if (!nzchar(py)) skip("no python3 on PATH")
  v <- nemeton:::.probe_python_version(py)
  expect_s3_class(v, "numeric_version")
  expect_true(is.na(v) || v >= numeric_version("3.0"))
})


test_that(".probe_python_version returns NA on unreachable binary", {
  fake <- tempfile("no-such-python-")
  v <- nemeton:::.probe_python_version(fake)
  expect_true(is.na(v))
})


test_that(".find_python_on_path returns a 3.10+ binary when available", {
  skip_if_no_reticulate()
  p <- nemeton:::.find_python_on_path()
  if (!nzchar(p)) skip("no Python ≥ 3.10 on PATH in the test runner")
  expect_true(file.exists(p))
  v <- nemeton:::.probe_python_version(p)
  expect_true(!is.na(v) && v >= numeric_version("3.10"))
})


test_that(".find_python_on_path returns \"\" when no candidate matches", {
  testthat::local_mocked_bindings(
    Sys.which = function(name) setNames("", name),
    .package = "base"
  )
  expect_identical(nemeton:::.find_python_on_path(), "")
})


test_that(".assert_fordead_system falls back to PATH when py_discover_config is NULL", {
  skip_if_no_reticulate()
  testthat::local_mocked_bindings(
    py_discover_config = function() NULL,
    .package = "reticulate"
  )
  # The fallback finds /usr/bin/python3.12 (or whatever exists). The mock
  # below decouples the test from the runner's actual interpreter.
  testthat::local_mocked_bindings(
    .find_python_on_path = function() "/fake/python3.12",
    .probe_python_version = function(py_path) numeric_version("3.12"),
    .package = "nemeton"
  )
  expect_identical(nemeton:::.assert_fordead_system(), "/fake/python3.12")
})


test_that(".assert_fordead_system errors when both reticulate AND PATH yield nothing", {
  skip_if_no_reticulate()
  testthat::local_mocked_bindings(
    py_discover_config = function() NULL,
    .package = "reticulate"
  )
  testthat::local_mocked_bindings(
    .find_python_on_path = function() "",
    .package = "nemeton"
  )
  expect_error(
    nemeton:::.assert_fordead_system(),
    "No Python interpreter found"
  )
})


# ----- RETICULATE_PYTHON conflict handling ------------------------------

test_that(".same_path normalises symlinks, trailing slashes, NA-ish inputs", {
  expect_true(nemeton:::.same_path("/tmp/a", "/tmp/a/"))
  expect_true(nemeton:::.same_path("/tmp/a", "/tmp/./a"))
  expect_false(nemeton:::.same_path("/tmp/a", "/tmp/b"))
  # Empty strings short-circuit to FALSE (avoids spurious match on "")
  expect_false(nemeton:::.same_path("", "/tmp/a"))
  expect_false(nemeton:::.same_path("/tmp/a", ""))
  expect_false(nemeton:::.same_path("", ""))
})


test_that(".use_fordead_env masks RETICULATE_PYTHON on conflict when Python is not yet bound", {
  skip_if_no_reticulate()

  conflicting <- "/path/to/some/other/env/bin/python"
  fordead_py  <- "/home/pascal/.virtualenvs/nemeton-fordead/bin/python"
  withr::local_envvar(c(RETICULATE_PYTHON = conflicting))

  seen_rp_during_use <- NA_character_

  testthat::local_mocked_bindings(
    py_discover_config = function() list(python = "/usr/bin/python3", version = "3.11"),
    virtualenv_python  = function(env) fordead_py,
    py_available       = function(initialize = FALSE) FALSE,
    use_virtualenv     = function(env, required = TRUE) {
      seen_rp_during_use <<- Sys.getenv("RETICULATE_PYTHON", unset = "")
      invisible(env)
    },
    .package = "reticulate"
  )

  nemeton:::.use_fordead_env(env_name = "nemeton-fordead")

  # During use_virtualenv(), the env var was masked (empty string).
  expect_identical(seen_rp_during_use, "")
  # After return, on.exit restored the original value.
  expect_identical(Sys.getenv("RETICULATE_PYTHON", unset = ""), conflicting)
})


test_that(".use_fordead_env errors when Python is already bound to a different env", {
  skip_if_no_reticulate()

  conflicting <- "/path/to/some/other/env/bin/python"
  fordead_py  <- "/home/pascal/.virtualenvs/nemeton-fordead/bin/python"
  withr::local_envvar(c(RETICULATE_PYTHON = conflicting))

  testthat::local_mocked_bindings(
    py_discover_config = function() list(python = "/usr/bin/python3", version = "3.11"),
    virtualenv_python  = function(env) fordead_py,
    py_available       = function(initialize = FALSE) TRUE,
    py_config          = function() list(python = conflicting),
    use_virtualenv     = function(env, required = TRUE) invisible(env),
    .package = "reticulate"
  )

  expect_error(
    nemeton:::.use_fordead_env(env_name = "nemeton-fordead"),
    "already bound|RETICULATE_PYTHON"
  )
})


test_that(".fordead_version_pinned parses git URL pin", {
  tmp <- tempfile("req-", fileext = ".txt")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(c(
    "# Some comment",
    "xarray>=2024.0",
    "fordead @ git+https://gitlab.com/fordead/fordead_package@v1.11.4",
    "numpy>=1.26"
  ), tmp)
  expect_identical(nemeton:::.fordead_version_pinned(tmp), "1.11.4")
})


test_that(".fordead_version_pinned parses PyPI-style pin", {
  tmp <- tempfile("req-", fileext = ".txt")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(c("fordead==2.1.1", "numpy>=1.26"), tmp)
  expect_identical(nemeton:::.fordead_version_pinned(tmp), "2.1.1")
})


test_that(".fordead_version_pinned returns NA when nothing matches", {
  tmp <- tempfile("req-", fileext = ".txt")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(c("numpy>=1.26", "pandas>=2.0"), tmp)
  expect_true(is.na(nemeton:::.fordead_version_pinned(tmp)))

  expect_true(is.na(nemeton:::.fordead_version_pinned("/no/such/file")))
})


test_that(".fordead_python_version reads the importlib.metadata version", {
  skip_if_no_reticulate()
  fake_py <- tempfile("fake-py-"); file.create(fake_py)
  on.exit(unlink(fake_py), add = TRUE)

  testthat::local_mocked_bindings(
    virtualenv_python = function(env) fake_py,
    .package = "reticulate"
  )

  captured_code <- NULL
  testthat::local_mocked_bindings(
    .python_capture_stdout = function(py_path, code) {
      captured_code <<- code
      "2.1.1"
    },
    .package = "nemeton"
  )

  expect_identical(nemeton:::.fordead_python_version("any-env"), "2.1.1")
  # Regression guard: the probe must query the distribution metadata,
  # never the `fordead.version` attribute (which is a function, so
  # printing it used to feed garbage into the version comparison and
  # force a `pip install` on every pipeline run).
  expect_match(captured_code, "importlib\\.metadata")
  expect_no_match(captured_code, "fordead\\.version")
})


test_that(".fordead_python_version returns NA when the probe yields nothing", {
  skip_if_no_reticulate()
  fake_py <- tempfile("fake-py-"); file.create(fake_py)
  on.exit(unlink(fake_py), add = TRUE)

  testthat::local_mocked_bindings(
    virtualenv_python = function(env) fake_py,
    .package = "reticulate"
  )
  testthat::local_mocked_bindings(
    .python_capture_stdout = function(py_path, code) character(),
    .package = "nemeton"
  )

  expect_true(is.na(nemeton:::.fordead_python_version("any-env")))
})


test_that(".fordead_python_version returns NA when the venv python is absent", {
  skip_if_no_reticulate()
  testthat::local_mocked_bindings(
    virtualenv_python = function(env) "/no/such/python",
    .package = "reticulate"
  )
  expect_true(is.na(nemeton:::.fordead_python_version("phantom-env")))
})


test_that(".fordead_is_installed flags a version mismatch as not-installed", {
  skip_if_no_reticulate()
  fake_py <- tempfile("fake-py-"); file.create(fake_py)
  on.exit(unlink(fake_py), add = TRUE)

  tmp_req <- tempfile("req-", fileext = ".txt")
  on.exit(unlink(tmp_req), add = TRUE)
  writeLines("fordead @ git+https://gitlab.com/fordead/fordead_package@v1.11.4",
             tmp_req)

  testthat::local_mocked_bindings(
    virtualenv_python = function(env) fake_py,
    .package = "reticulate"
  )
  # fordead IS importable but reports the wrong version.
  testthat::local_mocked_bindings(
    .fordead_python_import_ok = function(py_path, module = "fordead") TRUE,
    .fordead_python_version   = function(env_name) "2.1.1",
    .package = "nemeton"
  )

  expect_warning(
    result <- nemeton:::.fordead_is_installed("any-env", requirements_path = tmp_req),
    "fordead.*2\\.1\\.1.*1\\.11\\.4|fordead"
  )
  expect_false(result)
})


test_that(".fordead_is_installed accepts a matching version", {
  skip_if_no_reticulate()
  fake_py <- tempfile("fake-py-"); file.create(fake_py)
  on.exit(unlink(fake_py), add = TRUE)

  tmp_req <- tempfile("req-", fileext = ".txt")
  on.exit(unlink(tmp_req), add = TRUE)
  writeLines("fordead @ git+https://gitlab.com/fordead/fordead_package@v1.11.4",
             tmp_req)

  testthat::local_mocked_bindings(
    virtualenv_python = function(env) fake_py,
    .package = "reticulate"
  )
  testthat::local_mocked_bindings(
    .fordead_python_import_ok = function(py_path, module = "fordead") TRUE,
    .fordead_python_version   = function(env_name) "1.11.4",
    .package = "nemeton"
  )

  expect_true(nemeton:::.fordead_is_installed("any-env", requirements_path = tmp_req))
})


test_that(".use_fordead_env is a no-op when RETICULATE_PYTHON matches the fordead venv", {
  skip_if_no_reticulate()

  fordead_py <- "/home/pascal/.virtualenvs/nemeton-fordead/bin/python"
  withr::local_envvar(c(RETICULATE_PYTHON = fordead_py))

  seen_rp_during_use <- NA_character_

  testthat::local_mocked_bindings(
    py_discover_config = function() list(python = "/usr/bin/python3", version = "3.11"),
    virtualenv_python  = function(env) fordead_py,
    py_available       = function(initialize = FALSE) FALSE,
    use_virtualenv     = function(env, required = TRUE) {
      seen_rp_during_use <<- Sys.getenv("RETICULATE_PYTHON", unset = "")
      invisible(env)
    },
    .package = "reticulate"
  )

  nemeton:::.use_fordead_env(env_name = "nemeton-fordead")

  # No conflict → env var must NOT be masked.
  expect_identical(seen_rp_during_use, fordead_py)
  expect_identical(Sys.getenv("RETICULATE_PYTHON", unset = ""), fordead_py)
})
