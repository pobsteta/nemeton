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

.onLoad <- function(libname, pkgname) {
  if (!requireNamespace("terra", quietly = TRUE)) return(invisible(NULL))
  frac <- getOption("nemeton.terra_memfrac", .NEMETON_TERRA_MEMFRAC)
  frac <- suppressWarnings(as.numeric(frac)[1])
  # terra rejects anything outside (0, 0.9]; never abort a package load over it.
  if (is.na(frac) || frac <= 0 || frac > 0.9) return(invisible(NULL))
  tryCatch(terra::terraOptions(memfrac = frac),
           error = function(e) invisible(NULL))
  invisible(NULL)
}
