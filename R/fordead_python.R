#' FORDEAD Python Environment Helpers (E6.c.1, spec 008)
#'
#' @description
#' Manage the isolated Python virtual environment that hosts the
#' \code{fordead} pipeline used by [run_fordead_dieback()]. The env
#' lives in \code{~/.virtualenvs/nemeton-fordead} by default and is
#' created lazily on first use; subsequent calls are idempotent.
#'
#' Python \eqn{\geq} 3.10 is required (FORDEAD 2.x). Pinned dependency
#' list lives in \code{inst/python/requirements.txt}.
#'
#' @name fordead_python
NULL


# Module-level cache so the venv is only inspected once per R session.
.fordead_state <- new.env(parent = emptyenv())


#' Default virtualenv name used by the FORDEAD pipeline
#' @keywords internal
.fordead_default_env <- function() {
  Sys.getenv("NEMETON_FORDEAD_ENV", unset = "nemeton-fordead")
}


#' Path to the pinned requirements file shipped with the package
#' @keywords internal
.fordead_requirements_path <- function() {
  p <- system.file("python", "requirements.txt", package = "nemeton")
  if (!nzchar(p) || !file.exists(p)) {
    # Dev mode (devtools::load_all) — fall back to source tree.
    p <- file.path("inst", "python", "requirements.txt")
  }
  p
}


#' Assert reticulate is available and Python >= 3.10 is installed
#'
#' Raises a `cli::cli_abort` with installation hints when reticulate
#' is missing, when Python cannot be found, or when the discovered
#' interpreter is older than 3.10.
#'
#' @return Invisibly the resolved Python interpreter path (string).
#' @keywords internal
.assert_fordead_system <- function() {
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    cli::cli_abort(c(
      "Package {.pkg reticulate} is required for the FORDEAD pipeline.",
      i = "Install with {.code install.packages(\"reticulate\")}."
    ))
  }
  cfg <- tryCatch(reticulate::py_discover_config(),
                  error = function(e) NULL)
  py_path <- if (is.null(cfg)) "" else (if (is.null(cfg$python)) "" else cfg$python)
  if (!nzchar(py_path)) {
    cli::cli_abort(c(
      "No Python interpreter found.",
      i = "FORDEAD requires Python {.val >= 3.10}.",
      i = "Install Python 3.10+ then rerun."
    ))
  }
  ver <- numeric_version(cfg$version, strict = FALSE)
  if (is.na(ver) || ver < numeric_version("3.10")) {
    cli::cli_abort(c(
      "Python {cfg$version} found at {.path {cfg$python}} but {.val >= 3.10} is required.",
      i = "FORDEAD 2.x dropped support for Python < 3.10."
    ))
  }
  invisible(cfg$python)
}


#' Switch reticulate to the FORDEAD virtualenv
#'
#' Calls [reticulate::use_virtualenv()] with `required = TRUE`. The
#' virtualenv must already exist — see [.ensure_fordead_python()]
#' which creates it on first use.
#'
#' @param env_name Character. Name of the virtualenv. Defaults to
#'   `Sys.getenv("NEMETON_FORDEAD_ENV", "nemeton-fordead")`.
#' @return Invisibly `env_name`.
#' @keywords internal
.use_fordead_env <- function(env_name = .fordead_default_env()) {
  .assert_fordead_system()
  reticulate::use_virtualenv(env_name, required = TRUE)
  invisible(env_name)
}


#' Ensure the FORDEAD virtualenv exists and return the loaded module
#'
#' Idempotent. On first call, creates the virtualenv (via
#' [reticulate::virtualenv_create()]) and installs the pinned
#' dependencies from \code{inst/python/requirements.txt}. On
#' subsequent calls in the same R session, the result is cached.
#'
#' Set the env var \code{NEMETON_FORDEAD_ENV} to override the default
#' virtualenv name, e.g. for parallel test runs.
#'
#' @param env_name Character. Virtualenv name. Defaults to
#'   `nemeton-fordead`.
#' @param requirements Character path. Pinned requirements file.
#'   Defaults to the package-shipped one.
#' @param verbose Logical. Print progress via `cli`. Default `TRUE`.
#'
#' @return The imported `fordead` Python module (a
#'   `python.builtin.module` object usable with `$` syntax).
#'
#' @keywords internal
.ensure_fordead_python <- function(env_name = .fordead_default_env(),
                                   requirements = .fordead_requirements_path(),
                                   verbose = TRUE) {
  cache_key <- paste0("module:", env_name)
  if (!is.null(.fordead_state[[cache_key]])) {
    return(.fordead_state[[cache_key]])
  }

  .assert_fordead_system()

  exists_already <- reticulate::virtualenv_exists(env_name)
  if (!exists_already) {
    if (verbose) {
      cli::cli_alert_info("Creating Python virtualenv {.val {env_name}} (first FORDEAD use).")
    }
    reticulate::virtualenv_create(env_name)
    if (!file.exists(requirements)) {
      cli::cli_abort("Requirements file not found at {.path {requirements}}.")
    }
    if (verbose) {
      cli::cli_alert_info("Installing FORDEAD dependencies from {.path {basename(requirements)}}.")
    }
    reticulate::virtualenv_install(env_name,
                                   packages = NULL,
                                   requirements = requirements,
                                   ignore_installed = FALSE)
  }

  .use_fordead_env(env_name)
  fd <- reticulate::import("fordead", convert = FALSE)
  .fordead_state[[cache_key]] <- fd
  fd
}


#' Reset the cached FORDEAD module (test helper)
#' @keywords internal
.reset_fordead_state <- function() {
  rm(list = ls(.fordead_state, all.names = TRUE), envir = .fordead_state)
  invisible(NULL)
}
