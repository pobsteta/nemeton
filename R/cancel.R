# Cooperative file-based cancellation for long-running workers
# (`ingest_sentinel2_timeseries()`, `run_fordead_dieback()`).
#
# shiny::ExtendedTask has no cancellation API and the worker runs in a
# separate `future::multisession` process, so the only channel the app
# has to stop a running ingest/diagnostic is an out-of-band file. The
# app drops a flag file at a known path; the worker polls it between
# tiles / phases and, when it appears, exits cleanly — keeping whatever
# was already produced (for the S2 ingest, the COG bands cached for
# tiles 1..i-1 are durably on disk; for FORDEAD, the committed phases).
#
# Contract:
#  * `cancel_path = NULL` / `""` -> no polling at all, zero filesystem
#    calls. Identical behaviour and performance to the pre-cancel code.
#  * A flag already present AT ENTRY is treated as a stale leftover and
#    ignored for the whole run. The caller is responsible for deleting
#    the flag before each `invoke()`; this guard prevents a forgotten
#    flag from phantom-cancelling every subsequent run.
#  * Robustness: `file.exists()` never errors on a malformed path, so a
#    typo'd `cancel_path` simply reads as "no cancel", never a crash.

# Thin, mockable wrapper around `file.exists()` — lets tests assert the
# NULL-path fast path performs zero filesystem polls.
.cancel_flag_exists <- function(path) {
  isTRUE(file.exists(path))
}

# Build a stateful checker closure for one run. Call the returned
# function between work units; it returns TRUE exactly once the flag
# file appears (and only when cancellation is armed).
.make_cancel_checker <- function(cancel_path) {
  active <- !is.null(cancel_path) &&
            length(cancel_path) == 1L &&
            !is.na(cancel_path) &&
            nzchar(cancel_path)

  # Idempotence: a flag already on disk at entry is a leftover from a
  # previous run the caller forgot to clear. Disarm cancellation for
  # this whole run rather than aborting immediately.
  if (active && .cancel_flag_exists(cancel_path)) {
    cli::cli_warn(c(
      "Cancel flag already present at entry: {.path {cancel_path}}.",
      i = "Ignoring it for this run — delete the flag before {.fn invoke} \\
           to arm cooperative cancellation."
    ))
    active <- FALSE
  }

  function() active && .cancel_flag_exists(cancel_path)
}

# FORDEAD cancellation is coarser than FAST: the long reticulate phases
# (fit / predict) can't be interrupted mid-flight without an unreliable
# SIGINT into the Python subprocess, so we poll only at phase
# boundaries. When cancellation is observed we raise a classed
# condition that `run_fordead_dieback()` catches *before* its generic
# error handler, turning it into a `status = "cancelled"` result rather
# than a `status = "error"` one. `phase`/`n_scenes` ride on the
# condition so the handler can report what was reached.
.signal_cancel_fordead <- function(cancelled, phase, n_scenes = 0L) {
  if (cancelled()) {
    rlang::abort(
      sprintf("FORDEAD run cancelled at phase '%s'.", phase),
      class    = "nemeton_cancelled",
      phase    = phase,
      n_scenes = as.integer(n_scenes))
  }
  invisible(NULL)
}
