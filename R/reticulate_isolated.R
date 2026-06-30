# reticulate_isolated.R — run a reticulate/Python task in an isolated R
# subprocess with a pinned Python interpreter.
# ------------------------------------------------------------------
# reticulate can bind only ONE Python per R session. When several Python
# workloads need *different* environments in the same app session (e.g.
# Open-Canopy's conda env for the CHM, FORDEAD's virtualenv for the
# dieback model, Theia), they cannot all use in-process reticulate — the
# first to bind wins, the rest fail. Running each task in a fresh callr
# subprocess gives it an unbound reticulate that binds to its own env,
# regardless of what the parent session already bound (incl. reticulate's
# uv ephemeral default). This is the deterministic alternative to a global
# RETICULATE_PYTHON (which can only point to a single env).


# Resolve a Python interpreter path from a direct path, a virtualenv name
# or a conda env name. Returns NA_character_ when none resolves. Resolution
# does NOT initialise Python (path lookup only), so it is safe to call in
# the parent without binding reticulate.
.resolve_isolated_python <- function(python = NULL, virtualenv = NULL,
                                     condaenv = NULL) {
  if (!is.null(python) && length(python) == 1L && nzchar(python) &&
      file.exists(python)) {
    return(python)
  }
  if (!is.null(virtualenv)) {
    p <- tryCatch(reticulate::virtualenv_python(virtualenv),
                  error = function(e) NA_character_)
    if (length(p) == 1L && !is.na(p) && file.exists(p)) return(p)
  }
  if (!is.null(condaenv)) {
    p <- tryCatch(reticulate::conda_python(condaenv),
                  error = function(e) NA_character_)
    if (length(p) == 1L && !is.na(p) && file.exists(p)) return(p)
    for (root in c("miniforge3", "mambaforge", "miniconda3", "anaconda3")) {
      fp <- file.path(path.expand("~"), root, "envs", condaenv, "bin", "python")
      if (file.exists(fp)) return(fp)
    }
  }
  NA_character_
}


#' Run a Python/reticulate task in an isolated subprocess (pinned env)
#'
#' @description
#' Runs `fun` in a fresh \pkg{callr} R subprocess whose reticulate is
#' pinned to a specific Python interpreter (`python` / `virtualenv` /
#' `condaenv`). The subprocess starts with an **unbound** reticulate, so
#' it always binds to the requested environment — even if the parent
#' session already bound reticulate to a different Python (another env,
#' Theia, or reticulate's uv ephemeral default). This lets several
#' Python workloads that need *different* environments coexist in one app
#' session without the single-binding conflict, and **without** a global
#' `RETICULATE_PYTHON` (which can only serve one env).
#'
#' `R_ENVIRON_USER = ""` is set for the subprocess so a `RETICULATE_PYTHON`
#' in the user's `~/.Renviron` cannot override the pin.
#'
#' `fun` must be self-contained (callr serialises it): qualify packages
#' explicitly (`pkg::fn`) and pass everything via `args`. Return values and
#' `args` must be serialisable — exchange rasters as **file paths**, not
#' in-memory `SpatRaster` objects.
#'
#' Falls back to running `fun` **in-process** when \pkg{callr} is missing or
#' no Python could be resolved (a `cli_warn` is emitted in the latter case).
#'
#' @param fun A function to run in the subprocess.
#' @param args A named list of arguments passed to `fun`.
#' @param python Direct path to a Python interpreter (highest priority).
#' @param virtualenv A virtualenv name (resolved via
#'   [reticulate::virtualenv_python()]).
#' @param condaenv A conda env name (resolved via
#'   [reticulate::conda_python()], with a fallback over the usual
#'   conda/mamba install roots).
#' @param show Stream the subprocess output to the console (default `TRUE`)
#'   — the way to surface progress, since R callbacks cannot cross the
#'   process boundary.
#'
#' @return Whatever `fun` returns.
#' @export
run_reticulate_isolated <- function(fun, args = list(), python = NULL,
                                    virtualenv = NULL, condaenv = NULL,
                                    show = TRUE) {
  py <- .resolve_isolated_python(python, virtualenv, condaenv)
  if (is.na(py) || !requireNamespace("callr", quietly = TRUE)) {
    if (is.na(py)) {
      cli::cli_warn(c(
        "run_reticulate_isolated(): no Python interpreter resolved; running in-process.",
        i = "Pass {.arg python} / {.arg virtualenv} / {.arg condaenv}."
      ))
    }
    return(do.call(fun, args))
  }
  callr::r(
    func = fun, args = args,
    env  = c(callr::rcmd_safe_env(),
             RETICULATE_PYTHON = py,
             R_ENVIRON_USER    = ""),
    show = show, spinner = FALSE
  )
}
