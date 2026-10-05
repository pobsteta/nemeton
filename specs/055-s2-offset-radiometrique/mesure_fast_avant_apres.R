devtools::load_all(quiet = TRUE)
cache <- path.expand("~/.local/share/nemeton/projects/20260701_204501_ltcp/cache/layers/sentinel2")
con <- structure(list(), class = c("FakeConn", "DBIConnection"))
run <- function(harm, ...) {
  if (!harm) assignInNamespace(".s2_harmonize_band", function(r, scene_id) r, "nemeton")
  on.exit(if (!harm) assignInNamespace(".s2_harmonize_band", .s2_harmonize_band_orig, "nemeton"))
  rc <- tempfile("fastcache"); dir.create(rc)
  suppressWarnings(suppressMessages(read_fast_alert_raster(con, 1L, cache_dir = cache,
    apply_zone_mask = FALSE, result_cache_dir = rc, ...)))
}
.s2_harmonize_band_orig <- get(".s2_harmonize_band", asNamespace("nemeton"))
summ <- function(r) { v <- terra::values(r)[, 1]; v <- v[is.finite(v)]
  c(n = length(v), share_alert = mean(v > 0), mean = mean(v)) }
for (cfg in list(
  list(label = "count NDVI<0.40, 2022-2025", index = "NDVI", mode = "count", date_from = "2022-01-01", date_to = "2025-12-31"),
  list(label = "count NDVI<0.40, 2017-2021", index = "NDVI", mode = "count", date_from = "2017-01-01", date_to = "2021-12-31"),
  list(label = "trend NDMI 2017-2025",       index = "NDMI", mode = "trend", date_from = "2017-01-01", date_to = "2025-12-31"),
  list(label = "trend NDVI 2017-2025",       index = "NDVI", mode = "trend", date_from = "2017-01-01", date_to = "2025-12-31"))) {
  args <- cfg[-1]
  b <- summ(do.call(run, c(list(harm = FALSE), args)))
  a <- summ(do.call(run, c(list(harm = TRUE), args)))
  cat(sprintf("%-28s | pixels %d | en alerte : avant %.1f %%, après %.1f %% | moyenne : avant %.3f, après %.3f\n",
              cfg$label, as.integer(a["n"]), 100*b["share_alert"], 100*a["share_alert"], b["mean"], a["mean"]))
}
