# ============================================================
# memory-ceiling.R — one policy for "how much RAM may a heavy job take?"
# ------------------------------------------------------------
# Every heavy pipeline that runs in a child process (`run_memory_capped()`,
# `.reconfort_run_py()`) needs a ceiling, and they must all use the SAME one:
# three jobs of the same session competing for the same RAM under three
# different ceilings is not a policy, it is an accident waiting for the biggest
# of the three.
#
# WHY 50 % AND NOT 70 % (decision 2026-08-22)
# -------------------------------------------
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
# The former default — 70 % of `MemTotal`, i.e. **21 GB** there — is ABOVE that
# figure. A ceiling that can only trip after the executioner has acted is not a
# ceiling; it never fired once, in either incident. 50 % gives **15 GB**: below
# the observed trip point, and still above the heaviest run ever measured here
# (RECONFORT/IOTA2 full chain, 11.3 GB on 2026-07-13). That is the whole
# argument — an observed kill point and an observed peak, with the ceiling
# placed between the two.
#
# It remains a HEURISTIC: pressure depends on the page cache, on swap and on
# what else the desktop is doing, so no fraction can be *proven* correct from
# inside R. Hence two escape hatches, honoured everywhere (see below), and the
# error message of `run_memory_capped()` names them.
#
# `MemTotal` and not `MemAvailable`, deliberately: sizing the ceiling on what
# happens to be free would make two runs of the same job on the same data have
# different odds of surviving, depending on which browser tabs were open.
# ============================================================

# 50 % of MemTotal. Below `.MEMORY_CEILING_MIN_GB` no ceiling is set at all:
# on such a machine the cap would fail every legitimate job, and refusing to
# pretend is more useful than a ceiling nothing can run under.
.MEMORY_CEILING_FRACTION <- 0.5
.MEMORY_CEILING_MIN_GB   <- 4


# Total physical memory, in kB, or NA off Linux / when /proc is unreadable.
.mem_total_kb <- function() {
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
#' @return A systemd size string (`"15G"`), or `NULL` for "no ceiling".
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
