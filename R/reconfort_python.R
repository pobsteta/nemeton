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

  envs <- tryCatch(reticulate::conda_list(), error = function(e) NULL)
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

  reticulate::use_condaenv(env, required = TRUE)

  # Soft Python-version check (IOTA2 supports 3.9-3.11; warn, don't fail).
  ver <- tryCatch(reticulate::py_config()$version, error = function(e) NULL)
  if (!is.null(ver) && (ver < "3.9" || ver >= "3.12")) {
    cli::cli_warn(
      "RECONFORT conda env {.val {env}} runs Python {ver}; IOTA2 is validated on 3.9-3.11."
    )
  }

  if (!reticulate::py_module_available("iota2")) {
    cli::cli_abort(c(
      "Python module {.pkg iota2} is not importable in conda env {.val {env}}.",
      i = "Re-install it: {.code mamba install -n {env} -y iota2 -c iota2 -c iota2-deps}."
    ))
  }
  has_pygeodes <- reticulate::py_module_available("pygeodes")
  if (require_pygeodes && !has_pygeodes) {
    cli::cli_abort(c(
      "Python module {.pkg pygeodes} (S2 download) is not importable in conda env {.val {env}}.",
      i = "Install it: {.code conda run -n {env} pip install pygeodes}."
    ))
  }

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
