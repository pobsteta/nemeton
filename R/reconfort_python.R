# ============================================================
# reconfort_python.R — RECONFORT conda/IOTA² environment helpers
# ------------------------------------------------------------
# Lot L2b.1 of spec 021. Unlike FORDEAD (a pip virtualenv created
# lazily — see R/fordead_python.R), RECONFORT runs on the IOTA²
# chain, which is distributed as a **conda** package (OTB/Shark/GDAL
# bundle) and is far too heavy to bootstrap from R. Per the L2b
# cadrage (decision D2) the environment is therefore **located and
# validated**, never created: the user installs it once following the
# upstream procedure, and nemeton checks it is usable.
#
# This lot ships the environment helpers + the RECONFORT band list +
# the vendored computational glue (CRswir/CRre indices, continuous
# score). The download/orchestration glue and the pipeline itself
# come in L2b.2 / L2b.3.
# ============================================================


#' Sentinel-2 bands used by the RECONFORT indices
#'
#' The six Sentinel-2 L2A bands feeding the RECONFORT continuum-removal
#' indices (spec 021 §10 Q2): CRswir uses B8A/B11/B12, CRre uses
#' B04/B05/B06. Documentary — IOTA² ingests the full L2A product; this
#' constant records the bands the model actually depends on (centre
#' wavelengths, nm: B04=665, B05=704, B06=741, B8A=865, B11=1610,
#' B12=2190). Parallel to [FORDEAD_BANDS].
#'
#' @export
RECONFORT_BANDS <- c("B04", "B05", "B06", "B8A", "B11", "B12")


# Module-level cache so the env is inspected at most once per session
# (keyed on the resolved env name so an option change re-validates).
.reconfort_state <- new.env(parent = emptyenv())


#' Resolve the RECONFORT conda environment name
#'
#' Default `"nemeton-reconfort"`, overridable via
#' `options(nemeton.reconfort_conda_env = ...)` or the
#' `NEMETON_RECONFORT_ENV` environment variable.
#' @keywords internal
.reconfort_default_env <- function() {
  getOption(
    "nemeton.reconfort_conda_env",
    Sys.getenv("NEMETON_RECONFORT_ENV", unset = "nemeton-reconfort")
  )
}


#' Resolve a usable conda binary for env discovery
#'
#' [reticulate::conda_binary()] may return `mamba` on a miniforge
#' install, whose `env list` output reticulate mis-parses (yielding a
#' single bogus entry). When that happens, prefer the sibling `conda`
#' binary in the same directory.
#' @keywords internal
.reconfort_conda_binary <- function() {
  cb <- tryCatch(reticulate::conda_binary(), error = function(e) NULL)
  if (is.null(cb)) return(NULL)
  if (!identical(basename(cb), "conda")) {
    sib <- file.path(dirname(cb), "conda")
    if (file.exists(sib)) cb <- sib
  }
  cb
}


#' TRUE if `python -c "import <modules>"` succeeds inside the conda env
#'
#' Validates via a subprocess (`conda run -n <env> python -c ...`) rather
#' than reticulate's embedded interpreter: IOTA² is itself driven through
#' the `Iota2.py` subprocess, so this is both representative and immune to
#' reticulate's one-Python-per-session initialisation quirk (and to import
#' side-effects such as the OTB banner).
#' @keywords internal
.reconfort_py_imports_ok <- function(conda_bin, env, modules) {
  expr <- paste0("import ", paste(modules, collapse = ", "))
  status <- tryCatch(
    suppressWarnings(system2(
      conda_bin,
      args = c("run", "-n", env, "python", "-c", shQuote(expr)),
      stdout = FALSE, stderr = FALSE
    )),
    error = function(e) 1L
  )
  identical(as.integer(status), 0L)
}


#' Path to the vendored RECONFORT Python glue (`inst/python/reconfort/`)
#' @keywords internal
.reconfort_glue_dir <- function() {
  p <- system.file("python", "reconfort", package = "nemeton")
  if (!nzchar(p) || !dir.exists(p)) {
    # Dev mode (devtools::load_all) — fall back to the source tree.
    p <- file.path("inst", "python", "reconfort")
  }
  p
}


#' Locate and validate the RECONFORT conda/IOTA² environment
#'
#' Checks that the conda environment (default `"nemeton-reconfort"`)
#' exists and exposes the runtime RECONFORT needs: `iota2` and (unless
#' `require_pygeodes = FALSE`) `pygeodes`. Binds reticulate to it.
#' **Does not create or modify** the environment (cadrage D2) — on a
#' miss it aborts with the upstream install instructions.
#'
#' @param require_pygeodes Validate that `pygeodes` (S2 download) is
#'   importable. Default `TRUE`. Set `FALSE` when only the classification
#'   step is needed.
#' @param quiet Suppress the success message. Default `FALSE`.
#'
#' @return Invisibly, the resolved environment name.
#' @keywords internal
.ensure_reconfort_python <- function(require_pygeodes = TRUE, quiet = FALSE) {
  env <- .reconfort_default_env()

  if (isTRUE(.reconfort_state$ready) &&
      identical(.reconfort_state$env, env) &&
      (!require_pygeodes || isTRUE(.reconfort_state$pygeodes))) {
    return(invisible(env))
  }

  if (!requireNamespace("reticulate", quietly = TRUE)) {
    cli::cli_abort(c(
      "Package {.pkg reticulate} is required for the RECONFORT pipeline.",
      i = 'Install it with {.code install.packages("reticulate")}.'
    ))
  }

  conda_bin <- .reconfort_conda_binary()
  if (is.null(conda_bin)) {
    cli::cli_abort(c(
      "No conda installation found for the RECONFORT environment.",
      i = "Install Miniconda/Miniforge first, then create the {.val {env}} env."
    ))
  }

  envs <- tryCatch(reticulate::conda_list(conda = conda_bin),
                   error = function(e) NULL)
  if (is.null(envs) || !is.data.frame(envs) || !(env %in% envs$name)) {
    cli::cli_abort(c(
      "RECONFORT conda environment {.val {env}} not found.",
      i = "RECONFORT needs the IOTA2 chain (conda, not a pip venv). Install once:",
      "*" = "{.code conda create -n {env} -y}",
      "*" = "{.code mamba install -n {env} -y python=3.9 iota2 -c iota2 -c iota2-deps}",
      "*" = "{.code conda run -n {env} pip install pygeodes}",
      i = "Or point nemeton at an existing env: {.code options(nemeton.reconfort_conda_env = \"<name>\")}.",
      i = "Upstream guide: {.url https://docs.iota2.net/master/HowToGetIOTA2.html}"
    ))
  }

  # Validate the runtime via a subprocess (see .reconfort_py_imports_ok).
  if (!.reconfort_py_imports_ok(conda_bin, env, "iota2")) {
    cli::cli_abort(c(
      "Python module {.pkg iota2} is not importable in conda env {.val {env}}.",
      i = "Re-install it: {.code mamba install -n {env} -y iota2 -c iota2 -c iota2-deps -c conda-forge}."
    ))
  }
  has_pygeodes <- .reconfort_py_imports_ok(conda_bin, env, "pygeodes")
  if (require_pygeodes && !has_pygeodes) {
    cli::cli_abort(c(
      "Python module {.pkg pygeodes} (S2 download) is not importable in conda env {.val {env}}.",
      i = "Install it: {.code conda run -n {env} pip install pygeodes}."
    ))
  }

  # Best-effort: also bind reticulate to the env, for any embedded glue.
  tryCatch(
    reticulate::use_condaenv(env, conda = conda_bin, required = FALSE),
    error = function(e) NULL
  )

  .reconfort_state$ready    <- TRUE
  .reconfort_state$env      <- env
  .reconfort_state$pygeodes <- has_pygeodes
  if (!quiet) {
    cli::cli_alert_success(
      "RECONFORT conda env {.val {env}} ready (iota2{if (has_pygeodes) ' + pygeodes' else ''})."
    )
  }
  invisible(env)
}
