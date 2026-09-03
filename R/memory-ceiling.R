# ============================================================
# memory-ceiling.R — one policy for "how much RAM may a heavy job take?"
# ------------------------------------------------------------
# Every heavy pipeline that runs in a child process (`run_memory_capped()`,
# `.reconfort_run_py()`) needs a ceiling, and they must all use the SAME one:
# three jobs of the same session competing for the same RAM under three
# different ceilings is not a policy, it is an accident waiting for the biggest
# of the three.
#
# WHY 40 % (decision 2026-09-01, revisant celle du 2026-08-22)
# ------------------------------------------------------------
# The ceiling exists so that an overshooting job dies ALONE. For that it must
# trip BEFORE `systemd-oomd` acts on the user slice — and oomd does not act on
# an absolute figure but on memory PRESSURE (PSI). On the reference workstation
# (`MemTotal` 31.2 GB, 8 GB swap, `ManagedOOMMemoryPressureLimit` = 50 %) it
# fired at 17.1 GB of usage, page cache included:
#
#   Killed .../app-gnome-rstudio-*.scope due to memory pressure for
#   user@1000.service being 77.22% > 50.00% for > 20s
#   Current Memory Usage: 17.1G
#
# The 70 % default of the day — **21 GB** there — was ABOVE that figure. A
# ceiling that can only trip after the executioner has acted is not a ceiling;
# it never fired once, in either incident. 50 % gave **15 GB**: below the trip
# point observed at the time, and above the heaviest run ever measured here
# (RECONFORT/IOTA2 full chain, 11.3 GB on 2026-07-13).
#
# A THIRD MEASUREMENT MOVED THE TARGET (2026-09-01)
# -------------------------------------------------
# On that day oomd fired again on the same workstation, at **14.5 GB** — i.e.
# BELOW the 15 GB the 50 % rule computes:
#
#   Killed .../app-rstudio-1113027.scope due to memory pressure for
#   user@1000.service being 56.87% > 50.00% for > 20s with reclaim activity
#
# So the trip point is not a property of the machine, it is a property of the
# machine's mood: 17.1 GB one day, 14.5 GB another, depending on the page
# cache, on swap, and on what else the desktop happens to be running (that
# morning: two R test suites in parallel). 50 % had become inert again —
# exactly the defect the 70 % -> 50 % change had been made to fix.
#
# Hence **40 %**, i.e. **12 GB** on this 31.2 GB machine: still above the
# 11.3 GB peak, now below BOTH observed trip points. The argument is unchanged
# — a ceiling between the observed peak and the observed kill — only the
# measurements it rests on have grown from two to three.
#
# What this fraction CANNOT do, and it is worth stating rather than
# rediscovering: oomd kills on PRESSURE, not on an absolute figure, and
# pressure is produced by the whole user session, not by the capped job alone.
# No fraction of `MemTotal` can therefore be *proven* correct from inside R.
# The margin above the observed peak is now thin (11.3 -> 12 GB), which is the
# price of staying under a trip point that moves. Hence two escape hatches,
# honoured everywhere (see below), and the error message of
# `run_memory_capped()` names them.
#
# The structural fix is elsewhere and was made the same day, in the app: every
# heavy path must run in a capped child, so the kill takes the job and not the
# session. RECONFORT's R ingestion loop was running in the session's own scope,
# capped by nothing — no fraction, however low, would have saved that run.
#
# `MemTotal` and not `MemAvailable`, deliberately: sizing the ceiling on what
# happens to be free would make two runs of the same job on the same data have
# different odds of surviving, depending on which browser tabs were open.
# ============================================================

# 40 % of MemTotal. Below `.MEMORY_CEILING_MIN_GB` no ceiling is set at all:
# on such a machine the cap would fail every legitimate job, and refusing to
# pretend is more useful than a ceiling nothing can run under.
.MEMORY_CEILING_FRACTION <- 0.4
.MEMORY_CEILING_MIN_GB   <- 4


# Total physical memory, in kB, or NA off Linux / when /proc is unreadable.
#
# Le `file.exists()` n'est pas une precaution de style : `readLines()` sur un
# fichier absent AVERTIT avant d'echouer, et le `tryCatch(error=)` n'attrape
# pas l'avertissement. Sous Windows, l'utilisateur lisait donc en pleine
# console « impossible d'ouvrir le fichier '/proc/meminfo' » au milieu d'un
# calcul qui, lui, aboutissait (rapport du 2026-08-24). `/proc/meminfo` est une
# specificite Linux, pas un alea d'entree-sortie : le test dit ce qu'on veut
# vraiment dire.
.mem_total_kb <- function() {
  if (!file.exists("/proc/meminfo")) return(NA_real_)
  tryCatch({
    line <- grep("^MemTotal:", readLines("/proc/meminfo", warn = FALSE),
                 value = TRUE)[1]
    as.numeric(sub("^MemTotal:\\s*([0-9]+).*$", "\\1", line))
  }, error = function(e) NA_real_)
}


# Normalise a user-supplied ceiling into what `systemd-run` expects, or NULL
# for "no ceiling". Accepts the same disabling spellings as the app used, so
# `NEMETON_MEMORY_MAX=none` keeps working from either side.
.memory_ceiling_parse <- function(x) {
  if (isFALSE(x)) return(NULL)
  x <- trimws(as.character(x)[1L])
  if (is.na(x) || !nzchar(x)) return(NULL)
  if (tolower(x) %in% c("none", "off", "false", "no", "0")) return(NULL)
  x
}


# A ceiling as a number of bytes, so a caller can SIZE its work against it
# rather than merely hand it to systemd. Accepts what `.memory_ceiling()`
# returns — a systemd size string or NULL — and the suffixes systemd itself
# accepts (K/M/G/T, powers of 1024; bare digits are bytes). NA for "no ceiling"
# or anything unparseable: the caller must then fall back on its own bound, not
# on a number invented here.
.memory_ceiling_bytes <- function(x = .memory_ceiling()) {
  x <- .memory_ceiling_parse(x)
  if (is.null(x)) return(NA_real_)
  x <- toupper(trimws(x))
  m <- regmatches(x, regexec("^([0-9]+(?:\\.[0-9]+)?)\\s*([KMGT]?)I?B?$", x))[[1L]]
  if (length(m) != 3L) return(NA_real_)
  as.numeric(m[[2L]]) * switch(m[[3L]], K = 1024, M = 1024^2, G = 1024^3,
                               `T` = 1024^4, 1)
}


#' Memory ceiling for a capped child process
#'
#' Resolution order, from most to least specific:
#'
#' 1. `options(nemeton.memory_max)` — the session knob. `FALSE` or `""`
#'    disables the ceiling. `nemeton.reconfort_memory_max` is still honoured
#'    under its historical name.
#' 2. `NEMETON_MEMORY_MAX` — the operator knob (a deployment can lift or drop
#'    the ceiling without touching code). `"none"`, `"off"`, `"false"`, `"no"`
#'    or `"0"` disable it.
#' 3. `fraction` of `MemTotal`, rounded down to whole GB — see the file header
#'    for why the fraction is what it is.
#'
#' An explicit `memory_max =` argument at the call site outranks all three:
#' it never reaches this function.
#'
#' @param fraction Fraction of `MemTotal` for the computed default.
#' @return A systemd size string (`"12G"`), or `NULL` for "no ceiling".
#' @noRd
.memory_ceiling <- function(fraction = .MEMORY_CEILING_FRACTION) {
  opt <- getOption("nemeton.memory_max",
                   getOption("nemeton.reconfort_memory_max", NULL))
  if (!is.null(opt)) return(.memory_ceiling_parse(opt))

  env <- Sys.getenv("NEMETON_MEMORY_MAX", "")
  if (nzchar(trimws(env))) return(.memory_ceiling_parse(env))

  kb <- .mem_total_kb()
  if (is.na(kb) || kb <= 0) return(NULL)
  gb <- floor(kb / 1048576 * fraction)
  if (gb < .MEMORY_CEILING_MIN_GB) return(NULL)
  paste0(gb, "G")
}


# ============================================================
# What actually became of a capped scope
# ------------------------------------------------------------
# An exit status cannot tell an OOM from a `systemctl stop`, and — measured on
# 2026-08-23 — cannot even tell an OOM from an OOM: the same overshoot surfaces
# as `-9` (SIGKILL, reproduced locally: the scope's main process is the victim)
# or as `-15` (SIGTERM, observed in production on 2026-08-22: the OOM killer
# takes another process of the scope and systemd then tears the scope down,
# terminating the main process). Widening the list of "signals that mean OOM"
# would therefore trade one wrong answer for another, in both directions.
#
# systemd knows. A named transient scope keeps a `Result` — `oom-kill`,
# `exit-code`, `signal`, `timeout`, `success` — and that is a *constat*, not an
# inference. These two helpers ask it, and clean up after themselves since
# naming the unit costs us `--collect`.
# ============================================================

# A valid, unique transient scope name. systemd accepts [a-zA-Z0-9:_.\-] in unit
# names; anything else in `fun` is folded away rather than rejected.
.capped_scope_unit <- function(fun) {
  slug <- gsub("[^a-zA-Z0-9_.-]", "-", as.character(fun)[1L])
  slug <- substr(slug, 1L, 60L)
  sprintf("nemeton-%s-%d-%s.scope", slug, as.integer(Sys.getpid()),
          sub("^file", "", basename(tempfile("file"))))
}


# `Result` of a transient scope, once it has settled. Returns one of systemd's
# result strings, or NA when the question cannot be asked or answered.
#
# The poll exists because a scope is not necessarily done being torn down when
# the child's exit status reaches us; `Result` reads `success` for a unit that
# is still active, which is exactly the ambiguity to avoid. So wait for
# `ActiveState` to settle first, briefly, and give up rather than guess.
.capped_scope_result <- function(unit, timeout_ms = 2000L, poll_ms = 100L) {
  if (is.null(unit) || !nzchar(unit)) return(NA_character_)
  bin <- unname(Sys.which("systemctl"))
  if (!nzchar(bin)) return(NA_character_)

  ask <- function(prop) {
    out <- tryCatch(
      suppressWarnings(system2(bin, c("--user", "show", "--property", prop,
                                      "--value", unit),
                               stdout = TRUE, stderr = FALSE)),
      error = function(e) character()
    )
    out <- trimws(paste(out, collapse = ""))
    if (!nzchar(out)) NA_character_ else out
  }

  deadline <- Sys.time() + timeout_ms / 1000
  repeat {
    state <- ask("ActiveState")
    if (!is.na(state) && state %in% c("failed", "inactive")) break
    if (Sys.time() >= deadline) return(NA_character_)
    Sys.sleep(poll_ms / 1000)
  }
  ask("Result")
}


# Drop a failed transient unit, so naming it does not leak one entry per crash.
# A scope that ended well is garbage-collected by systemd on its own; only the
# failed ones linger, which is precisely what let us read `Result`.
.capped_scope_reset <- function(unit) {
  if (is.null(unit) || !nzchar(unit)) return(invisible(NULL))
  bin <- unname(Sys.which("systemctl"))
  if (!nzchar(bin)) return(invisible(NULL))
  tryCatch(
    suppressWarnings(system2(bin, c("--user", "reset-failed", unit),
                             stdout = FALSE, stderr = FALSE)),
    error = function(e) NULL
  )
  invisible(NULL)
}


# Bullets pointing at the child's captured output — the file, and its last
# meaningful lines. Nothing when no `log_path` was asked for (the default), when
# the file never appeared, or when it is empty: an `i` bullet saying "see this
# empty file" is worse than silence.
#
# `n` is deliberately small. The point is not to reproduce the log in an error
# message but to carry the ONE line that names the cause — a Python traceback's
# last line, an R `Error in ...`. The file holds the rest, and is cited.
#
# `esc` comes from the caller so the escaping rule stays in one place: log
# content is arbitrary text and may contain braces, which cli would otherwise
# evaluate as expressions.
.capped_log_bullets <- function(log_path, esc, n = 5L) {
  if (is.null(log_path) || !nzchar(log_path)) return(character())
  bullets <- c(i = esc(cli::format_inline(
    "The child's output was kept in {.path {log_path}}.")))
  if (!file.exists(log_path)) return(bullets)
  lines <- tryCatch(readLines(log_path, warn = FALSE), error = function(e) character())
  lines <- lines[nzchar(trimws(lines))]
  if (!length(lines)) return(bullets)
  tail_lines <- utils::tail(lines, n)
  # Truncated per line: a single line of a Python traceback can be very long,
  # and an error message that scrolls is an error message nobody reads.
  tail_lines <- vapply(tail_lines, function(l)
    if (nchar(l) > 200L) paste0(substr(l, 1L, 197L), "...") else l,
    character(1L), USE.NAMES = FALSE)
  c(bullets, stats::setNames(esc(tail_lines), rep(">", length(tail_lines))))
}


# The failure message of a capped child, decided from what we actually know.
# Pure: `result` is systemd's verdict (NA when unavailable), `status` the exit
# status seen by processx. Kept separate from `run_memory_capped()` so every
# branch is testable without spawning, killing or filling anything.
#
# Three cases, three levels of certainty — and the wording says which:
#   * systemd says `oom-kill`      -> assert the ceiling. No hedging.
#   * systemd says something else  -> do NOT claim memory; name what it said.
#   * systemd cannot be asked      -> a killing signal is *usually* the ceiling,
#                                     said as a likelihood, not as a fact.
#
# Values are interpolated HERE rather than left to `cli_abort()`: its `{}`
# expressions evaluate in the *calling* frame, which does not hold `status` or
# `signal`. Braces surviving in an interpolated value are escaped, so a function
# name containing one cannot turn into an expression downstream.
.capped_failure_message <- function(fun, status, ceiling, result = NA_character_,
                                    log_path = NULL) {
  status  <- as.integer(status)
  ceiling <- if (is.null(ceiling)) "none" else as.character(ceiling)
  killed  <- status %in% c(-9L, 137L, -15L, 143L)
  signal  <- if (status < 0L) -status else if (status > 128L) status - 128L else NA_integer_

  esc <- function(x) gsub("}", "}}", gsub("{", "{{", x, fixed = TRUE), fixed = TRUE)
  f   <- function(...) esc(cli::format_inline(...))

  # Where the child's own words are, when the caller asked for them to be kept.
  # Appended to every branch: even a verdict as clear as `oom-kill` leaves open
  # WHICH step was running when the ceiling bit.
  trace <- .capped_log_bullets(log_path, esc)

  hatches <- f("Raise it with {.arg memory_max}, {.envvar NEMETON_MEMORY_MAX} ",
               "(accepts {.val none}) or {.code options(nemeton.memory_max=)}, ",
               "or run on a smaller extent.")
  spared  <- "The rest of the session was spared \u2014 only the job died."

  if (identical(result, "oom-kill")) {
    return(c(
      f("{.val {fun}} ran out of memory and was killed (ceiling: {ceiling})."),
      i = hatches,
      i = spared,
      trace
    ))
  }

  if (!is.na(result) && !identical(result, "success")) {
    return(c(
      f("{.val {fun}} failed in its capped child process (systemd: {.val {result}})."),
      i = if (identical(result, "timeout")) {
            "The scope hit a time limit, not the memory ceiling."
          } else {
            f("This is not the memory ceiling: systemd would have said {.val oom-kill}.")
          },
      i = spared,
      trace
    ))
  }

  if (killed) {
    return(c(
      f("{.val {fun}} was killed (signal {signal}; systemd's verdict unavailable)."),
      i = f("The memory ceiling ({ceiling}) is the usual cause \u2014 but a stopped ",
            "scope or an outside {.code kill} looks the same from here."),
      i = hatches,
      i = spared,
      trace
    ))
  }

  c(f("{.val {fun}} failed in its capped child process (exit {status})."), trace)
}
