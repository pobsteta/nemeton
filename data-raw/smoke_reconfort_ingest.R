# Minimal REAL smoke test for reconfort_ingest_s2() — NOT a unit test.
# Downloads a few real MUSCATE S2 L2A scenes from GEODES for one tile
# over a short window, then unzips into the IOTA2 layout. Opt-in, heavy.
# Run: Rscript data-raw/smoke_reconfort_ingest.R
suppressMessages(devtools::load_all("."))

options(nemeton.geodes_config =
          "/home/pascal/.local/share/nemeton/pygeodes-config.json")

s2_root <- file.path(path.expand("~/.cache/nemeton/reconfort/smoke"))
dir.create(s2_root, recursive = TRUE, showWarnings = FALSE)

tile      <- "T31UDP"            # Loiret (Centre-Val de Loire, RECONFORT valid)
date_from <- "2026-05-08"
date_to   <- "2026-05-13"

cat(sprintf("[smoke] tile=%s window=%s..%s root=%s\n",
            tile, date_from, date_to, s2_root))

t0 <- Sys.time()
res <- reconfort_ingest_s2(
  tiles     = tile,
  date_from = date_from,
  date_to   = date_to,
  s2_root   = s2_root,
  quiet     = FALSE
)
cat(sprintf("[smoke] ingest returned in %.1f min\n",
            as.numeric(difftime(Sys.time(), t0, units = "mins"))))

# Verify the extracted layout actually contains SENTINEL2 scene folders.
for (d in res$extracted) {
  scenes <- list.dirs(d, recursive = FALSE)
  cat(sprintf("[smoke] %s -> %d scene folder(s)\n", d, length(scenes)))
  for (s in scenes) cat("        ", basename(s), "\n")
}
cat("[smoke] DONE\n")
