# Volet A — pouvoir discriminant d'ALSroads sur donnée française (spec 041, D4).
# Critère annoncé AVANT exécution : si les distributions de largeur ne séparent
# pas sentier / chemin / route empierrée / route à 1 chaussée, le signal est nul.
suppressMessages({library(sf); library(lidR); library(ALSroads); library(terra); library(raster)})

D    <- path.expand("~/.local/share/nemeton/tutorial_data")
LAS  <- file.path(D, "lidar_hd", "NUALHD_1-0__LAZ_LAMB93_PM_2025-03-25")
ctg  <- readLAScatalog(LAS)
# ALSroads attend un RasterLayer (paquet `raster`), PAS un terra::SpatRaster :
# passer un SpatRaster provoque "No such slot: extent" sur chaque troncon.
dtm  <- raster::raster(file.path(D, "altitude_1m.vrt"))
routes <- st_read(file.path(D, "routes.gpkg"), quiet = TRUE)

# On ne garde que les tronçons réellement couverts par les tuiles.
emprise <- st_as_sfc(st_bbox(ctg))
st_crs(emprise) <- st_crs(routes)
routes <- routes[st_intersects(routes, emprise, sparse = FALSE)[, 1], ]
routes$longueur_m <- as.numeric(st_length(routes))
routes <- routes[routes$longueur_m >= 50, ]   # trop court = mesure instable
cat("tronçons retenus :", nrow(routes), "\n")
print(table(routes$nature))

# Échantillon stratifié par nature : le volet A teste la SÉPARATION des classes,
# pas la couverture exhaustive. n par classe plafonné pour tenir le budget temps.
set.seed(42)
N_MAX <- as.integer(Sys.getenv("VOLET_A_N", "12"))
idx <- unlist(lapply(split(seq_len(nrow(routes)), routes$nature), function(i)
  if (length(i) <= N_MAX) i else sample(i, N_MAX)))
ech <- routes[idx, ]
cat("échantillon :", nrow(ech), "tronçons\n"); print(table(ech$nature))

res <- vector("list", nrow(ech))
t0 <- Sys.time()
for (k in seq_len(nrow(ech))) {
  r <- tryCatch(
    measure_road(ctg, ech[k, ], dtm = dtm),
    error = function(e) structure(list(msg = conditionMessage(e)), class = "err"))
  res[[k]] <- if (inherits(r, "err")) {
    data.frame(nature = ech$nature[k], largeur = NA_real_, largeur_corr = NA_real_,
               score = NA_real_, classe = NA_character_, erreur = r$msg,
               stringsAsFactors = FALSE)
  } else {
    d <- st_drop_geometry(r)
    num <- function(col) if (col %in% names(d)) suppressWarnings(as.numeric(d[[col]])[1]) else NA_real_
    # DRIVABLEWIDTH = largeur CARROSSABLE (ce que places_depot() attend).
    # ROADWIDTH = largeur du corridor, bien plus large : sur un sentier elle
    # vaut ~5 m alors que la largeur carrossable est 0. Ne pas confondre.
    data.frame(nature = ech$nature[k],
               largeur      = num("DRIVABLEWIDTH"),
               largeur_corr = num("ROADWIDTH"),
               score        = num("SCORE"),
               classe       = if ("CLASS" %in% names(d)) as.character(d$CLASS)[1] else NA_character_,
               erreur = NA_character_, stringsAsFactors = FALSE)
  }
  cat(sprintf("[%d/%d] %-20s %s\n", k, nrow(ech), ech$nature[k],
              if (is.na(res[[k]]$largeur)) paste("ERREUR:", substr(res[[k]]$erreur,1,60))
              else sprintf("%.2f m", res[[k]]$largeur)))
}
out <- do.call(rbind, res)
cat("\ndurée totale :", round(as.numeric(difftime(Sys.time(), t0, units="min")), 1), "min",
    "| par tronçon :", round(as.numeric(difftime(Sys.time(), t0, units="secs"))/nrow(ech), 1), "s\n")
cat("mesures abouties :", sum(!is.na(out$largeur)), "/", nrow(out), "\n\n")
ok <- out[!is.na(out$largeur), ]
if (nrow(ok) > 0) {
  cat("=== LARGEUR CARROSSABLE (DRIVABLEWIDTH, m) ===\n")
  print(aggregate(largeur ~ nature, ok, function(x)
    c(n = length(x), med = round(median(x), 2),
      q1 = round(quantile(x, .25), 2), q3 = round(quantile(x, .75), 2))))
  cat("\n=== dont largeur carrossable NULLE (non praticable) ===\n")
  print(tapply(ok$largeur, ok$nature, function(x) sprintf("%d/%d", sum(x == 0), length(x))))
  cat("\n=== SCORE de confiance ALSroads ===\n")
  print(aggregate(score ~ nature, ok, function(x) round(median(x), 3)))
  cat("\n=== largeur du CORRIDOR (ROADWIDTH) — a ne pas confondre ===\n")
  print(aggregate(largeur_corr ~ nature, ok, function(x) round(median(x), 2)))
  if (length(unique(ok$nature)) >= 2)
    cat("\nKruskal-Wallis p =",
        signif(kruskal.test(largeur ~ factor(nature), ok)$p.value, 3), "\n")
}
saveRDS(out, "volet_a_resultats.rds")
