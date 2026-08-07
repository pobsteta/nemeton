# ============================================================
# zzz.R — package load hooks
# ============================================================


# terra's default `memfrac` is 0.6 — it will materialise a raster in RAM up to
# 60% of the machine's TOTAL memory before spilling to disk. Total, not free:
# nothing accounts for what the rest of the run already holds. In a nemeton
# pipeline that is a bad bet, because the heavy neighbours are invisible to it —
# the IOTA2/FORDEAD Python subprocess (~11 GB on its own), a Shiny session, the
# other rasters of the project. On 2026-07-13 the sum of those got the whole R
# session killed by systemd-oomd.
#
# 0.25 leaves terra a workable working set while keeping the pipeline far from
# the OOM killer's pressure threshold; beyond it, terra streams through disk,
# which is slower but finishes. Users who know their machine can raise it back:
#
#   terra::terraOptions(memfrac = 0.6)                 # per session
#   options(nemeton.terra_memfrac = 0.5)               # before loading nemeton
#
.NEMETON_TERRA_MEMFRAC <- 0.25

# A fraction is not a ceiling. `memfrac` scales with the machine, so the same
# package behaves differently everywhere: 0.25 is 7.8 GB on a 31 GB workstation,
# 2 GB on an 8 GB laptop, 32 GB on a 128 GB server — and it says nothing about
# what the machine can actually spare right now. On 2026-08-07 that got the Dabo
# run killed: terra was entitled to ~15 GB in a session already sharing the user
# slice with RStudio and a browser, and systemd-oomd killed the whole scope at
# 50% pressure long before terra considered spilling.
#
# `memmax` is an absolute ceiling in GB, so it behaves identically on every
# machine, and it is adaptive: terra only streams through disk for the rasters
# that exceed it. Measured on the R3 chain in a 10 GB cgroup — at the normal
# operating point (5 m) it is free (0.67 GB peak, 0 MB written, same timing as
# today); at 0.5 m it turns an OOM kill into a finished run and protects better
# than `todisk = TRUE` (0.88 GB peak vs 2.51 GB) for the same time. `todisk` is
# the wrong lever: unconditional, it costs 3.4x the time and 142 MB of writes at
# 5 m to save 0.01 GB.
#
#   terra::terraOptions(memmax = 8)          # per session
#   options(nemeton.terra_memmax = 8)        # before loading nemeton
#   NEMETON_TERRA_MEMMAX=8                   # environment
#   options(nemeton.terra_memmax = -1)       # opt out (terra default)
#
# Caveat: spilling only protects if terra's tempdir is real storage. On a system
# where `/tmp` is a tmpfs, "spilling to disk" writes to RAM and buys nothing —
# set `terra::terraOptions(tempdir = ...)` to a real filesystem there.
.NEMETON_TERRA_MEMMAX <- 3

.onLoad <- function(libname, pkgname) {
  if (!requireNamespace("terra", quietly = TRUE)) return(invisible(NULL))

  frac <- getOption("nemeton.terra_memfrac", .NEMETON_TERRA_MEMFRAC)
  frac <- suppressWarnings(as.numeric(frac)[1])
  # terra rejects anything outside (0, 0.9]; never abort a package load over it.
  if (!is.na(frac) && frac > 0 && frac <= 0.9) {
    tryCatch(terra::terraOptions(memfrac = frac),
             error = function(e) invisible(NULL))
  }

  mx <- getOption("nemeton.terra_memmax", NULL)
  if (is.null(mx)) {
    env <- Sys.getenv("NEMETON_TERRA_MEMMAX", unset = "")
    mx <- if (nzchar(env)) env else .NEMETON_TERRA_MEMMAX
  }
  mx <- suppressWarnings(as.numeric(mx)[1])
  # Any non-positive value means "no cap" — terra spells that -1.
  if (!is.na(mx)) {
    tryCatch(terra::terraOptions(memmax = if (mx > 0) mx else -1),
             error = function(e) invisible(NULL))
  }

  invisible(NULL)
}
