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


#' Parse a Python interpreter's version string via `python --version`
#'
#' Runs `<py_path> --version` and extracts the major.minor numeric
#' version. Robust to "Python 3.12.3" on stdout (Python ≥ 3.4) or
#' stderr (older builds). Returns `NA_numeric_version_` if the
#' interpreter is unreachable or the output is unparseable.
#'
#' @param py_path Character path to a Python interpreter.
#' @return A [numeric_version] of length 1 (possibly NA).
#' @keywords internal
.probe_python_version <- function(py_path) {
  out <- tryCatch(
    suppressWarnings(system2(py_path, "--version",
                             stdout = TRUE, stderr = TRUE)),
    error = function(e) character()
  )
  if (length(out) == 0L) return(numeric_version(NA_character_, strict = FALSE))
  m <- regmatches(out[1], regexpr("[0-9]+\\.[0-9]+", out[1]))
  if (length(m) == 0L || !nzchar(m)) {
    return(numeric_version(NA_character_, strict = FALSE))
  }
  numeric_version(m, strict = FALSE)
}


#' Probe PATH for a Python ≥ 3.10 interpreter
#'
#' Walks a list of conventional Python binary names from newest to
#' oldest (3.14 → 3.10 → generic `python3` → `python`) and returns
#' the first one that exists on `PATH` AND reports a version ≥ 3.10.
#'
#' Used as a fallback when [reticulate::py_discover_config()] returns
#' nothing useful — for instance because the user just removed
#' `RETICULATE_PYTHON` from their `.Renviron` and reticulate's
#' internal discovery hasn't kicked in.
#'
#' @return Character path (string) to a Python ≥ 3.10 interpreter,
#'   or `""` if nothing matches.
#' @keywords internal
.find_python_on_path <- function() {
  candidates <- c("python3.14", "python3.13", "python3.12",
                  "python3.11", "python3.10", "python3", "python")
  for (cand in candidates) {
    p <- unname(Sys.which(cand))
    if (!nzchar(p) || !file.exists(p)) next
    v <- .probe_python_version(p)
    if (!is.na(v) && v >= numeric_version("3.10")) return(p)
  }
  ""
}


#' Assert reticulate is available and Python >= 3.10 is installed
#'
#' Raises a `cli::cli_abort` with installation hints when reticulate
#' is missing, when Python cannot be found, or when the discovered
#' interpreter is older than 3.10.
#'
#' Discovery is two-pronged: first ask reticulate via
#' [reticulate::py_discover_config()] (which honours `RETICULATE_PYTHON`
#' and reticulate's pinned config). If that returns nothing useful —
#' a real failure mode when the user has just unset `RETICULATE_PYTHON`
#' or when reticulate's config cache is stale — fall back to
#' [.find_python_on_path()] which probes `Sys.which()` directly.
#'
#' We don't need reticulate to be initialised against the discovered
#' interpreter at this point; we only need to know that a 3.10+ Python
#' is reachable so the FORDEAD venv can be built from it.
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
  py_path <- if (is.null(cfg) || is.null(cfg$python)) "" else cfg$python
  ver_str <- if (is.null(cfg) || is.null(cfg$version)) NA_character_ else cfg$version

  # Fallback: reticulate gave us nothing — probe PATH directly.
  if (!nzchar(py_path)) {
    py_path <- .find_python_on_path()
    if (nzchar(py_path)) {
      v <- .probe_python_version(py_path)
      ver_str <- if (is.na(v)) NA_character_ else as.character(v)
    }
  }

  if (!nzchar(py_path)) {
    cli::cli_abort(c(
      "No Python interpreter found.",
      i = "FORDEAD requires Python {.val >= 3.10}.",
      i = "Install Python 3.10+ then rerun, or set {.envvar RETICULATE_PYTHON} to its path."
    ))
  }

  ver <- numeric_version(ver_str, strict = FALSE)
  if (is.na(ver) || ver < numeric_version("3.10")) {
    cli::cli_abort(c(
      "Python {ver_str} found at {.path {py_path}} but {.val >= 3.10} is required.",
      i = "FORDEAD 2.x dropped support for Python < 3.10."
    ))
  }
  invisible(py_path)
}


#' Run `python -c "import <module>"` in an external interpreter
#'
#' Thin wrapper over [base::system2()] used to probe whether a
#' Python module is importable from a specific interpreter, without
#' loading it into the current reticulate session. Exists so tests
#' can mock the system call without dealing with `system2` directly.
#'
#' @param py_path Character path to a Python interpreter.
#' @param module  Module name to import (default `"fordead"`).
#' @return `TRUE` if the import succeeded (exit code 0), `FALSE`
#'   otherwise (non-zero exit, signal, or any error).
#' @keywords internal
.fordead_python_import_ok <- function(py_path, module = "fordead") {
  # `system2()` does not quote `args`: without shQuote() the shell
  # word-splits `import fordead` into the bare statement `import`,
  # which is a SyntaxError — the probe then always reports FALSE and
  # forces a needless `pip install` on every pipeline run.
  rc <- tryCatch(
    suppressWarnings(system2(
      py_path,
      c("-c", shQuote(paste0("import ", module))),
      stdout = FALSE, stderr = FALSE
    )),
    error = function(e) -1L
  )
  identical(as.integer(rc), 0L)
}


#' Read the fordead version pinned in a requirements file
#'
#' Parses lines like
#' `fordead @ git+https://.../fordead_package@v1.11.4` or
#' `fordead==1.11.4` and returns the X.Y.Z string. The leading
#' `@v` or `==` is stripped. Returns `NA_character_` when no
#' fordead line is found or the version can't be parsed.
#'
#' @param requirements_path Character path to the requirements file.
#' @return Character(1) — the pinned version or `NA`.
#' @keywords internal
.fordead_version_pinned <- function(requirements_path) {
  if (!file.exists(requirements_path)) return(NA_character_)
  lines <- readLines(requirements_path, warn = FALSE)
  # Strip comments + whitespace, keep only the fordead line
  lines <- sub("\\s*#.*$", "", lines)
  fordead <- lines[grepl("^\\s*fordead\\b", lines, ignore.case = TRUE)]
  if (!length(fordead)) return(NA_character_)
  # Try git URL pin first (`@vX.Y.Z`), then PyPI-style (`==X.Y.Z`)
  m <- regmatches(fordead[1], regexpr("@v[0-9]+\\.[0-9]+\\.[0-9]+", fordead[1]))
  if (!length(m) || !nzchar(m)) {
    m <- regmatches(fordead[1], regexpr("==[0-9]+\\.[0-9]+\\.[0-9]+", fordead[1]))
  }
  if (!length(m) || !nzchar(m)) return(NA_character_)
  sub("^(@v|==)", "", m)
}


#' Run `python -c <code>` and capture stdout
#'
#' Thin wrapper over [base::system2()] with `stdout = TRUE`. Exists so
#' tests can mock the captured output without dealing with `system2`
#' directly (mirrors [.fordead_python_import_ok()]).
#'
#' `system2()` pastes `args` into a single shell command line without
#' quoting, so `code` MUST be [shQuote()]d here — otherwise spaces,
#' `;` and `()` in the Python snippet are word-split / interpreted by
#' the shell and the snippet never reaches the interpreter intact.
#'
#' @param py_path Character path to a Python interpreter.
#' @param code    Character. Python statement(s) to execute.
#' @return Character vector of stdout lines (possibly empty on error).
#' @keywords internal
.python_capture_stdout <- function(py_path, code) {
  tryCatch(
    suppressWarnings(system2(
      py_path, c("-c", shQuote(code)),
      stdout = TRUE, stderr = FALSE
    )),
    error = function(e) character()
  )
}


#' Probe the installed fordead version in a virtualenv
#'
#' Reads the *distribution* version via
#' `importlib.metadata.version("fordead")` — the canonical source.
#' Note: the `fordead.version` attribute is a *function*, not a
#' version string, so `print(fordead.version)` yields a
#' `<function …>` repr. Probing that made the installed version
#' never match the pin, triggering a spurious `pip install` on every
#' pipeline run. Returns `NA_character_` when fordead isn't installed
#' or the call fails.
#'
#' @param env_name Character. Virtualenv name.
#' @return Character(1) — installed version, or `NA`.
#' @keywords internal
.fordead_python_version <- function(env_name) {
  py <- tryCatch(reticulate::virtualenv_python(env_name),
                 error = function(e) NA_character_)
  if (is.na(py) || !nzchar(py) || !file.exists(py)) return(NA_character_)
  out <- .python_capture_stdout(
    py, "import importlib.metadata as m; print(m.version('fordead'))"
  )
  if (length(out) == 0L) return(NA_character_)
  ver <- trimws(out[1])
  if (!nzchar(ver)) return(NA_character_)
  ver
}


#' Check whether `fordead` is actually importable in the given venv
#'
#' Returns `TRUE` when the venv exists, its Python can `import fordead`,
#' AND — when a `requirements_path` is provided — the installed
#' fordead version matches the pin. This last check is the recovery
#' mechanism for cases where a previous nemeton release pinned a
#' different fordead version (e.g. v0.22.2..v0.22.4 pinned v2.1.1,
#' v0.22.5 downgrades to v1.11.4): without it, `.ensure_fordead_python`
#' would see fordead as "installed" and skip the upgrade, leaving the
#' user with a wrong-API fordead in their venv.
#'
#' @param env_name Character. Virtualenv name.
#' @param requirements_path Optional character path to the pinned
#'   requirements file. When supplied, the version is compared against
#'   the pin and a mismatch returns `FALSE` (with a `cli::cli_alert_warning`
#'   so the user knows why a reinstall is about to happen).
#' @return Logical(1).
#' @keywords internal
.fordead_is_installed <- function(env_name, requirements_path = NULL) {
  py <- tryCatch(reticulate::virtualenv_python(env_name),
                 error = function(e) NA_character_)
  if (is.na(py) || !nzchar(py) || !file.exists(py)) return(FALSE)
  if (!.fordead_python_import_ok(py)) return(FALSE)
  if (!is.null(requirements_path) && file.exists(requirements_path)) {
    pinned    <- .fordead_version_pinned(requirements_path)
    installed <- .fordead_python_version(env_name)
    if (!is.na(pinned) && !is.na(installed) && !identical(pinned, installed)) {
      cli::cli_alert_warning(c(
        "{.pkg fordead} {.val {installed}} installed in {.val {env_name}}, ",
        "but {.path {basename(requirements_path)}} pins {.val {pinned}}."
      ))
      return(FALSE)
    }
  }
  TRUE
}


#' Compare two filesystem paths for equality
#'
#' Robust to symlinks, trailing slashes, and `~` expansion via
#' [normalizePath()] with `mustWork = FALSE` (so a non-existent
#' path doesn't error — useful when comparing a configured value
#' to a venv that may not be created yet).
#'
#' @param a,b Character paths.
#' @return Logical(1).
#' @keywords internal
.same_path <- function(a, b) {
  if (!nzchar(a) || !nzchar(b)) return(FALSE)
  identical(
    normalizePath(a, winslash = "/", mustWork = FALSE),
    normalizePath(b, winslash = "/", mustWork = FALSE)
  )
}


#' Switch reticulate to the FORDEAD virtualenv
#'
#' Calls [reticulate::use_virtualenv()] with `required = TRUE`. The
#' virtualenv must already exist — see [.ensure_fordead_python()]
#' which creates it on first use.
#'
#' Handles a notorious reticulate quirk: when the `RETICULATE_PYTHON`
#' environment variable is set (e.g. by a user's `.Renviron` pointing
#' at a conda env for another project), it silently overrides
#' `use_python()` / `use_virtualenv()` even with `required = TRUE`.
#' We work around this in two phases:
#'
#' * If Python is **not yet initialised** in the session, we mask
#'   `RETICULATE_PYTHON` for the duration of the `use_virtualenv()`
#'   call (the var is restored on exit so other reticulate consumers
#'   — e.g. OpenCanopy CHM operations from spec 005 — are unaffected
#'   for the rest of their work, though Python's binding is now
#'   fixed for the session).
#' * If Python is **already initialised** to a *different* binary,
#'   the in-process switch is impossible (reticulate caches the
#'   binding once Python is initialised). We surface a clear,
#'   actionable error pointing the user at the env var.
#'
#' @param env_name Character. Name of the virtualenv. Defaults to
#'   `Sys.getenv("NEMETON_FORDEAD_ENV", "nemeton-fordead")`.
#' @return Invisibly `env_name`.
#' @keywords internal
.use_fordead_env <- function(env_name = .fordead_default_env()) {
  .assert_fordead_system()

  fordead_py <- reticulate::virtualenv_python(env_name)
  rp <- Sys.getenv("RETICULATE_PYTHON", unset = "")
  conflict <- nzchar(rp) && !.same_path(rp, fordead_py)

  if (conflict) {
    if (isTRUE(reticulate::py_available(initialize = FALSE))) {
      current <- tryCatch(reticulate::py_config()$python,
                          error = function(e) NA_character_)
      if (!is.na(current) && !.same_path(current, fordead_py)) {
        cli::cli_abort(c(
          "Reticulate is already bound to {.path {current}}.",
          i = "{.envvar RETICULATE_PYTHON} is set to {.val {rp}}.",
          x = "Cannot switch to the FORDEAD venv {.path {fordead_py}} within this R session.",
          i = "Action: {.code Sys.unsetenv(\"RETICULATE_PYTHON\")} (or remove the line from your {.path .Renviron}), then restart R."
        ))
      }
    }
    # Python not yet initialised — temporarily mask RETICULATE_PYTHON so
    # use_virtualenv() takes effect. Restore the var on exit; reticulate's
    # cached binding stays on the FORDEAD env for the rest of the session.
    Sys.unsetenv("RETICULATE_PYTHON")
    on.exit(Sys.setenv(RETICULATE_PYTHON = rp), add = TRUE)
  }

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

  if (!file.exists(requirements)) {
    cli::cli_abort("Requirements file not found at {.path {requirements}}.")
  }

  needs_install <- FALSE
  if (!reticulate::virtualenv_exists(env_name)) {
    if (verbose) {
      cli::cli_alert_info(
        "Creating Python virtualenv {.val {env_name}} (first FORDEAD use)."
      )
    }
    reticulate::virtualenv_create(env_name)
    needs_install <- TRUE
  } else if (!.fordead_is_installed(env_name, requirements_path = requirements)) {
    # Venv exists but fordead is either missing OR installed at a
    # different version than the current pin. Both situations need
    # the same recovery: re-run pip install. The helper itself emits
    # a warning when the cause is a version mismatch (so we don't
    # duplicate the message here for that case).
    if (verbose) {
      cli::cli_alert_warning(c(
        "Reinstalling FORDEAD dependencies into {.val {env_name}} ",
        "from {.path {basename(requirements)}}."
      ))
    }
    needs_install <- TRUE
  }

  if (needs_install) {
    if (verbose) {
      cli::cli_alert_info(
        "Installing FORDEAD dependencies from {.path {basename(requirements)}}."
      )
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
