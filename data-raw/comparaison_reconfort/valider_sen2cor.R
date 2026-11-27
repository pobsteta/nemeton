#!/usr/bin/env Rscript
# Mission 095 : rejoue la validation de la voie Sen2Cor contre un VRAI run IOTA2.
#
# (a) mode "maja"    : les scenes MAJA du run alimentent le predicteur R ; la
#                      carte est comparee pixel a pixel (tout le masque feuillus)
#                      a Classif_Seed_0.tif et ProbabilityMap_seed_0.tif d'IOTA2.
# (b) mode "sen2cor" : les scenes Sen2Cor de Planetary Computer (reseau requis)
#                      alimentent le meme predicteur ; on mesure le taux de
#                      changement de classe contre (a) et contre IOTA2.
#
# Usage (depuis la racine du depot, nemeton charge) :
#   Rscript data-raw/comparaison_reconfort/valider_sen2cor.R <output_zone_N> <travail> maja|sen2cor [fin=2025-10-29]
# <output_zone_N> : dossier d'un run IOTA2 (results/<run>/final, model/, s2_download/extracted/<tuile>).
# Rien de ce que lit ce script n'est versionne ni execute : rasters et texte seuls.
suppressPackageStartupMessages({ library(terra); library(sf) })
if (!"nemeton" %in% loadedNamespaces()) suppressMessages(pkgload::load_all(".", quiet = TRUE))
a <- commandArgs(TRUE)
zone <- a[1]; trav <- a[2]; mode <- a[3]
fin <- as.Date(if (length(a) >= 4) a[4] else "2025-10-29")
dir.create(trav, showWarnings = FALSE, recursive = TRUE)
res <- list.dirs(file.path(zone, "results"), recursive = FALSE)[1]
final <- file.path(res, "final")
s2_year <- as.integer(sub(".*S2_([0-9]{4}).*", "\\1", res))
grille <- rast(rast(file.path(final, "Classif_Seed_0.tif")), nlyrs = 1)
msk <- values(rast(file.path(final, sprintf("Final_Classif_masked_%d.tif", s2_year))), mat = FALSE)
msk <- !is.na(msk) & msk > 0
cat(sprintf("grille %d x %d, masque %d pixels, annee %d, fin %s\n", ncol(grille), nrow(grille), sum(msk), s2_year, fin))
modele <- reconfort_sharkrf_lire(file.path(res, "model", "model_1_seed_0.txt"), cache_dir = file.path(trav, "rf"))
dg <- nemeton:::.reconfort_dates_grille(s2_year)
sdir <- file.path(trav, paste0("scenes_", mode)); dir.create(sdir, showWarnings = FALSE)

if (mode == "maja") {
  dossiers <- sort(list.dirs(Sys.glob(file.path(zone, "s2_download", "extracted", "*"))[1], recursive = FALSE))
  dossiers <- dossiers[grepl("^SENTINEL2", basename(dossiers))]
  dd <- as.Date(sub(".*_(20[0-9]{6})-.*", "\\1", basename(dossiers)), "%Y%m%d")
  dossiers <- dossiers[dd <= fin]; dd <- dd[dd <= fin]
  lire <- function(f) values(project(rast(f), grille, method = "near"), mat = FALSE)
  chemins <- character(length(dossiers))
  for (i in seq_along(dossiers)) {
    id <- basename(dossiers[i]); dest <- file.path(sdir, sprintf("%s_%s.tif", format(dd[i], "%Y%m%d"), id))
    chemins[i] <- dest
    if (file.exists(dest)) next
    B <- vapply(c("B4", "B5", "B6", "B8A", "B11", "B12"), function(b)
      lire(file.path(dossiers[i], sprintf("%s_FRE_%s.tif", id, b))), numeric(ncell(grille)))
    B[B <= -10000] <- NA
    mk <- function(k, r) lire(file.path(dossiers[i], "MASKS", sprintf("%s_%s_%s.tif", id, k, r)))
    ok <- mk("CLM", "R1") == 0 & mk("CLM", "R2") == 0 & mk("EDG", "R1") == 0 &
      mk("SAT", "R1") == 0 & mk("SAT", "R2") == 0
    B[is.na(ok) | !ok, ] <- NA
    r <- rast(grille, nlyrs = 6); values(r) <- B; names(r) <- c("B04", "B05", "B06", "B8A", "B11", "B12")
    writeRaster(r, dest, overwrite = TRUE, datatype = "INT2S", NAflag = -32768, gdal = "COMPRESS=DEFLATE")
    if (i %% 20 == 0) cat("scene", i, "/", length(dossiers), "\n")
  }
  scenes <- data.frame(date = dd, chemin = chemins)
} else {
  e <- ext(grille)
  aoi <- st_as_sf(st_as_sfc(st_bbox(c(xmin = xmin(e), xmax = xmax(e), ymin = ymin(e), ymax = ymax(e)), crs = st_crs(2154))))
  tuile <- sub(".*/", "", Sys.glob(file.path(zone, "s2_download", "extracted", "*"))[1])
  scenes <- nemeton:::.reconfort_sen2cor_preparer(
    aoi, tuile, format(dg[1]), format(fin), grille,
    s2_cache_dir = file.path(trav, "s2_bands"), dossier = sdir)
}
cat(sprintf("%d scenes\n", nrow(scenes)))
t0 <- Sys.time()
out <- nemeton:::.reconfort_sen2cor_classer(scenes, modele, grille, msk, s2_year, dg,
                                            file.path(trav, paste0("final_", mode)), quiet = FALSE)
cat(sprintf("classification : %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))

# --- comparaison pixel a pixel sur tout le masque ---------------------------
cl <- values(rast(out$classif), mat = FALSE)[msk]
pr <- values(rast(out$probability), mat = TRUE)[msk, ]
cl_i <- values(rast(file.path(final, "Classif_Seed_0.tif")), mat = FALSE)[msk]
pr_i <- values(rast(file.path(final, "ProbabilityMap_seed_0.tif")), mat = TRUE)[msk, ]
pr_i[is.na(pr_i)] <- 0
ok <- cl > 0
cat(sprintf("\n== %s contre IOTA2 (%d pixels du masque, %d classes) ==\n", mode, sum(msk), sum(ok)))
cat(sprintf("classe identique : %.2f %%\n", 100 * mean(cl[ok] == cl_i[ok])))
cat(sprintf("ecart absolu moyen des votes (sur 1000) : %.1f\n", mean(abs(pr[ok, ] - pr_i[ok, ]))))
cat("matrice de confusion (lignes IOTA2, colonnes port) :\n"); print(table(IOTA2 = cl_i[ok], port = cl[ok]))
saveRDS(cl, file.path(trav, paste0("classes_", mode, ".rds")))
if (mode == "sen2cor" && file.exists(file.path(trav, "classes_maja.rds"))) {
  cm <- readRDS(file.path(trav, "classes_maja.rds"))
  cat(sprintf("\n== changement de classe Sen2Cor contre MAJA (meme predicteur) : %.2f %% ==\n", 100 * mean(cl[ok] != cm[ok])))
  print(table(MAJA = cm[ok], Sen2Cor = cl[ok]))
}
