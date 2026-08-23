# ============================================================
# isolate.R — run a heavy pipeline in a memory-capped child R process
# ------------------------------------------------------------
# RECONFORT drives Python as a SUBPROCESS (`conda run python …`), so capping it
# is easy: `.reconfort_run_py()` wraps that subprocess in a transient cgroup.
#
# FORDEAD and the reGénération engines do not have that luxury. FORDEAD runs
# Python through reticulate's EMBEDDED interpreter (`fp$fit()`, `fp$predict()`);
# the engines are plain R. Their memory *is* the R process's memory, so it lives
# in the caller's systemd scope — the app's, typically. When it overshoots,
# systemd-oomd does not kill the job: it kills the whole scope. On 2026-07-14
# that took down RStudio and the terminals with it, mid-FORDEAD — exactly as it
# had on 2026-07-13, before RECONFORT was isolated.
#
# There is nothing to cap in-process. The work has to move into a CHILD R
# process, and the cap goes on that. This is what `run_memory_capped()` does.
#
# Note the sibling: `run_reticulate_isolated()` (reticulate_isolated.R) also
# spawns a child, but for a different reason — pinning a Python interpreter, so
# several environments can coexist in one session. It caps nothing. The two are
# complementary, not alternatives.
# ============================================================


# Mirror of the app's progress writer, so an isolated child leaves behind
# exactly the files the reader already polls: `<path>.json` holds the LAST event
# (atomic .tmp + rename), `<path>.ndjson` appends one line per event. Losing a
# progress tick must never abort the job, hence the blanket tryCatch.
.progress_file_writer <- function(progress_path) {
  if (is.null(progress_path) || !nzchar(progress_path)) return(NULL)
  if (!requireNamespace("jsonlite", quietly = TRUE)) return(NULL)
  ndjson_path <- .progress_ndjson_path(progress_path)
  function(event) {
    tryCatch(
      suppressWarnings({
        line <- jsonlite::toJSON(event, auto_unbox = TRUE, null = "null",
                                 na = "null", POSIXt = "ISO8601")
        tmp <- paste0(progress_path, ".tmp")
        writeLines(line, con = tmp, useBytes = TRUE)
        ok <- file.rename(tmp, progress_path)
        if (!isTRUE(ok)) {
          file.copy(tmp, progress_path, overwrite = TRUE)
          unlink(tmp)
        }
        cat(line, "\n", sep = "", file = ndjson_path, append = TRUE)
      }),
      error = function(e) invisible(NULL)
    )
  }
}

.progress_ndjson_path <- function(progress_path) {
  if (grepl("\\.json$", progress_path)) {
    sub("\\.json$", ".ndjson", progress_path)
  } else {
    paste0(progress_path, ".ndjson")
  }
}


# Replay the child's new NDJSON lines into the parent's callback. A callback
# cannot cross a process boundary, but its EFFECTS matter — the app's callback
# also fires the ntfy phase pushes. So the child writes events to disk and the
# parent tails the file: the caller keeps receiving events, unchanged.
# `from` is the number of lines already replayed; returns the new count.
.progress_replay <- function(path, from, callback) {
  if (is.null(callback) || !file.exists(path)) return(from)
  lines <- tryCatch(readLines(path, warn = FALSE), error = function(e) character())
  if (length(lines) <= from) return(from)
  for (line in lines[seq.int(from + 1L, length(lines))]) {
    if (!nzchar(line)) next
    ev <- tryCatch(jsonlite::fromJSON(line, simplifyVector = TRUE),
                   error = function(e) NULL)
    if (!is.null(ev)) tryCatch(callback(ev), error = function(e) invisible(NULL))
  }
  length(lines)
}


#' Run a heavy pipeline in a memory-capped child process
#'
#' @description
#' Runs a function of `package` (an export **or** an internal, resolved via
#' [asNamespace()]) in a **child R process** placed in a transient,
#' memory-capped cgroup. A run that overshoots then dies **alone**,
#' with an ordinary error the caller can report — instead of having
#' `systemd-oomd` kill the entire application scope (the R session, the Shiny
#' app, the terminals) for being the biggest thing under memory pressure.
#'
#' Use it for the pipelines whose memory lives *inside* the R process and so
#' cannot be capped in place: [run_fordead_dieback()] (Python through
#' reticulate's embedded interpreter) and the reGénération engines (plain R).
#' The latter live in `nemetonshiny` — hence `package` and `options` (to reach an
#' internal worker and to seed session options such as `nemeton.app_options`
#' across the boundary). [run_reconfort_dieback()] does **not** need it — it
#' already caps the Python subprocess it spawns.
#'
#' @details
#' Two arguments cannot be serialised across a process boundary, and are
#' therefore rebuilt in the child rather than passed:
#'
#' * **`con`** — a `DBIConnection` is not serialisable. Pass `db_url` and the
#'   child opens (and closes) its own via [db_connect()].
#' * **`progress_callback`** — a closure is not serialisable either. Pass
#'   `progress_path`: the child writes each event to `<path>.json` (last event,
#'   written atomically) and appends it to `<path>.ndjson`, and the parent tails
#'   that file and replays every event into the `progress_callback` you gave
#'   here. Callers therefore keep receiving events as before — including any
#'   side effects of their callback, such as push notifications.
#'
#' Without `systemd-run` (non-Linux, container with no user bus, CI) the work
#' still runs in a child process — whose memory at least returns to the OS on
#' exit — but **uncapped**, with a warning. Without a cgroup, an overshoot is
#' once again the whole scope's problem.
#'
#' @param fun Name of the function to run, in `package` (character). May be
#'   internal (not exported).
#' @param args Named list of arguments. Must be serialisable: no connections,
#'   no closures, no `SpatRaster` — pass file paths.
#' @param package Package the child loads and resolves `fun` from. Default
#'   `"nemeton"`. Use e.g. `"nemetonshiny"` to cap an app-side worker.
#' @param db_url Database URL. When given, the child opens a connection and
#'   passes it to `fun` as `con` (only if `fun` takes a `con` argument).
#' @param options Named list of session options set in the child (via
#'   [options()]) before calling `fun`. Use for options the worker reads but that
#'   do not cross the process boundary, e.g. `list(nemeton.app_options = ...)`.
#' @param progress_path Path of the progress `.json` file. When given, the child
#'   passes `fun` a callback writing there.
#' @param progress_callback Parent-side callback, fed by replaying the child's
#'   events (requires `progress_path`).
#' @param memory_max Ceiling as a systemd size string (e.g. `"12G"`), or
#'   `FALSE` to disable it. Default (`NULL`): **50% of `MemTotal`**, unless
#'   `options(nemeton.memory_max)` or the `NEMETON_MEMORY_MAX` environment
#'   variable says otherwise — one policy, shared with the RECONFORT subprocess
#'   cap. The fraction is not a guess: on the reference workstation
#'   `systemd-oomd` was observed killing the session at 17.1 GB of 31.2 GB,
#'   which the former 70% default (21 GB) sat *above* — a ceiling that can only
#'   trip after the OOM killer has acted is not a ceiling. See
#'   `R/memory-ceiling.R` for the full argument and the escape hatches.
#' @param poll_ms How often to poll the child for progress, in milliseconds.
#' @param quiet Suppress the child's console output.
#'
#' @return Whatever `fun` returned.
#'
#' @examples
#' \dontrun{
#' res <- run_memory_capped(
#'   "run_fordead_dieback",
#'   args       = list(zone_id = 9L, cache_dir = "~/cache"),
#'   db_url     = Sys.getenv("NEMETON_DB_URL"),
#'   memory_max = "12G"
#' )
#' }
#'
#' @seealso [run_fordead_dieback()], [run_reticulate_isolated()] (which pins a
#'   Python env rather than capping memory), [scratch_dir()]
#' @export
run_memory_capped <- function(fun, args = list(), package = "nemeton",
                              db_url = NULL, options = NULL,
                              progress_path = NULL, progress_callback = NULL,
                              memory_max = NULL, poll_ms = 500L,
                              quiet = FALSE) {
  if (!is.character(fun) || length(fun) != 1L || !nzchar(fun)) {
    cli::cli_abort("{.arg fun} must be the name of a function in {.arg package}.")
  }
  if (!is.character(package) || length(package) != 1L || !nzchar(package)) {
    cli::cli_abort("{.arg package} must be a single package name.")
  }
  if (!is.list(args) || (length(args) && is.null(names(args)))) {
    cli::cli_abort("{.arg args} must be a named list.")
  }
  if (!is.null(options) && (!is.list(options) || is.null(names(options)))) {
    cli::cli_abort("{.arg options} must be a named list or NULL.")
  }
  if (!requireNamespace("processx", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.pkg processx} is required to run {.val {fun}} in a capped child process.",
      i = "Install it, or call {.fun {fun}} directly (uncapped, at the scope's risk)."
    ))
  }

  dir <- scratch_dir(sprintf("capped_%s_%d", fun, as.integer(Sys.getpid())))
  on.exit(unlink(dir, recursive = TRUE, force = TRUE), add = TRUE)
  f_in     <- file.path(dir, "call.rds")
  f_out    <- file.path(dir, "result.rds")
  f_script <- file.path(dir, "run.R")

  saveRDS(list(fun = fun, args = args, package = package, db_url = db_url,
               options = options, progress_path = progress_path,
               libs = .libPaths()), f_in)

  writeLines(c(
    'a <- readRDS(commandArgs(trailingOnly = TRUE)[1L])',
    '.libPaths(a$libs)',
    'suppressMessages(loadNamespace(a$package))',
    '# `get(envir = asNamespace())` (not getExportedValue) so an INTERNAL',
    '# function of `package` is reachable too — the reGénération engine worker',
    '# is not exported from nemetonshiny (spec 035, brief-nemetonshiny-regen-capped).',
    'f <- get(a$fun, envir = asNamespace(a$package))',
    '# Options posées avant l\'appel : le worker peut lire des options de session',
    '# (p.ex. nemeton.app_options via get_app_options()), qui ne franchissent pas',
    '# la frontiere de process.',
    'if (length(a$options)) do.call(base::options, a$options)',
    '# Only inject what `f` actually takes: passing `con` or `progress_callback`',
    '# to a function without them is an "unused argument" error mid-run.',
    'takes <- function(arg) arg %in% names(formals(f))',
    'extra <- list()',
    'if (takes("con") && !is.null(a$db_url) && nzchar(a$db_url)) {',
    '  con <- nemeton::db_connect(a$db_url)',
    '  on.exit(try(nemeton::db_disconnect(con), silent = TRUE), add = TRUE)',
    '  extra$con <- con',
    '}',
    'if (takes("progress_callback")) {',
    '  cb <- nemeton:::.progress_file_writer(a$progress_path)',
    '  if (!is.null(cb)) extra$progress_callback <- cb',
    '}',
    'res <- do.call(f, c(extra, a$args))',
    'saveRDS(res, commandArgs(trailingOnly = TRUE)[2L])'
  ), f_script)

  mm <- if (is.null(memory_max)) {
    .memory_ceiling()
  } else if (isFALSE(memory_max)) {
    NULL
  } else {
    .memory_ceiling_parse(memory_max)
  }
  systemd <- .reconfort_systemd_run()
  if (is.null(systemd) || is.null(mm)) {
    cli::cli_warn(c(
      "Running {.val {fun}} in a child process, but WITHOUT a memory ceiling.",
      i = "With no cgroup, an overshoot is the whole session's problem again: the OOM killer takes the scope, not the job."
    ))
  }
  # Name the scope so systemd can be *asked* what became of it, instead of
  # guessing from an exit status that means several things at once (see
  # `.capped_failure_message()`).
  unit <- .capped_scope_unit(fun)
  cmd <- .reconfort_cap_memory(
    file.path(R.home("bin"), "Rscript"),
    c(f_script, f_in, f_out),
    memory_max = mm, systemd_run = systemd, unit = unit
  )
  # Naming the unit costs `--collect`, so we do its cleanup ourselves — on every
  # exit path, including the caller's interrupt.
  if (!is.null(cmd$unit)) on.exit(.capped_scope_reset(cmd$unit), add = TRUE)

  std <- if (quiet) NULL else ""
  px <- processx::process$new(cmd$command, cmd$args, stdout = std, stderr = std)
  on.exit(if (px$is_alive()) px$kill(), add = TRUE)

  ndjson <- if (is.null(progress_path)) NULL else .progress_ndjson_path(progress_path)
  seen <- 0L
  repeat {
    px$wait(timeout = as.integer(poll_ms))
    if (!is.null(ndjson)) seen <- .progress_replay(ndjson, seen, progress_callback)
    if (!px$is_alive()) break
  }
  st <- px$get_exit_status()
  if (!is.null(ndjson)) .progress_replay(ndjson, seen, progress_callback)

  if (!identical(as.integer(st), 0L) || !file.exists(f_out)) {
    # Do not read the tea leaves of the exit status: a ceiling overshoot reaches
    # us as -9 OR as -15 depending on which process of the scope the OOM killer
    # picked, and both also mean "someone stopped the scope". Ask systemd, which
    # kept a verdict, and fall back to a hedged wording only when it cannot
    # answer (no cgroup, no systemctl, unit already gone).
    ceiling <- if (is.null(mm)) "none" else mm
    result  <- .capped_scope_result(cmd$unit)
    cli::cli_abort(.capped_failure_message(fun, st, ceiling, result))
  }
  readRDS(f_out)
}
