#!/usr/bin/env Rscript
# =============================================================================
# Script d'exécution de la Section 3 du Tutorial 07
# Segmentation d'Arbres Individuels (ITD)
# =============================================================================
# Usage: Rscript run-all-exercises.R
#        ou source("run-all-exercises.R") dans R
#
# Prérequis: avoir exécuté le Tutorial 01 pour télécharger les données LiDAR.
# =============================================================================

cat("\n")
cat("=============================================================================\n")
cat(" TUTORIAL 07 - SECTION 3 : Segmentation d'Arbres Individuels\n")
cat("=============================================================================\n\n")

# =============================================================================
# CONFIGURATION GLOBALE
# =============================================================================

# Répertoire des données
if (requireNamespace("rappdirs", quietly = TRUE)) {
  data_dir <- file.path(rappdirs::user_data_dir("nemeton"), "tutorial_data")
} else {
  data_dir <- file.path(path.expand("~"), "nemeton_tutorial_data")
}
data_dir <- normalizePath(data_dir, mustWork = FALSE)

cat("Répertoire des données:", data_dir, "\n")

# Configuration parallélisation
N_CORES <- 4L
BUFFER_SIZE <- 20L

options(
  timeout = 300,
  lidR.progress = TRUE
)

Sys.setenv(
  GDAL_HTTP_TIMEOUT = "300",
  GDAL_HTTP_CONNECTTIMEOUT = "300"
)

# Chargement des packages requis
required_packages <- c("lidR", "terra", "sf", "future")
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf("Package '%s' requis. Installez-le avec: install.packages('%s')", pkg, pkg))
  }
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}

# lasR requis pour la section 3
if (!requireNamespace("lasR", quietly = TRUE)) {
  stop("Package 'lasR' requis. Installez-le avec:\n
       install.packages('lasR', repos = 'https://r-lidar.r-universe.dev')")
}
suppressPackageStartupMessages(library(lasR))

# =============================================================================
# VARIABLES DE SUIVI
# =============================================================================

# Temps global
start_time_global <- Sys.time()

# Statistiques par exercice
stats <- list(
  ex_3.1 = list(name = "Pipeline ITD", time = 0, files = 0, file_types = list()),
  ex_3.2 = list(name = "Fusion VRT", time = 0, files = 0, file_types = list()),
  ex_3.3 = list(name = "Métriques arbres", time = 0, files = 0, file_types = list())
)

# Surface traitée
surface_ha <- 0

# =============================================================================
# VÉRIFICATION DES DONNÉES
# =============================================================================

fichiers_laz <- list.files(
  file.path(data_dir, "lidar_hd"),
  pattern = "\\.laz$",
  full.names = TRUE,
  recursive = TRUE
)

if (length(fichiers_laz) == 0) {
  stop("Aucune donnée LiDAR trouvée. Exécutez d'abord le Tutorial 01.")
}

cat("Dalles LiDAR:", length(fichiers_laz), "\n")

# Calculer la surface totale
ctg <- readLAScatalog(fichiers_laz)
bbox <- st_bbox(ctg)
surface_m2 <- (bbox["xmax"] - bbox["xmin"]) * (bbox["ymax"] - bbox["ymin"])
surface_ha <- surface_m2 / 10000

cat("Surface totale:", round(surface_ha, 1), "ha\n")
cat("Emprise:", round(bbox["xmax"] - bbox["xmin"]), "x",
    round(bbox["ymax"] - bbox["ymin"]), "m\n")
cat("\n")

# Répertoire résultats
result_itd <- file.path(data_dir, "result_itd")

# =============================================================================
# EXERCICE 3.1 : Pipeline ITD avec normalisation
# =============================================================================

cat("-----------------------------------------------------------------------------\n")
cat(" Exercice 3.1 : Pipeline ITD avec normalisation\n")
cat("-----------------------------------------------------------------------------\n")

start_time <- Sys.time()

# Nettoyer le répertoire
if (dir.exists(result_itd)) {
  unlink(result_itd, recursive = TRUE)
}
dir.create(result_itd, recursive = TRUE)

gc()

cat("Pipeline ITD:\n")
cat("  1. triangulate(ground) -> DTM\n")
cat("  2. rasterize(1m) -> dtm_*.tif\n")
cat("  3. transform_with(dtm_tri) -> normalisation\n")
cat("  4. triangulate(first) -> CHM\n")
cat("  5. rasterize(0.5m) -> chm_*.tif\n")
cat("  6. pit_fill() -> c_filled_*.tif\n")
cat("  7. local_maximum_raster() -> seeds_*.gpkg\n")
cat("  8. region_growing() -> crowns_*.tif\n\n")

cat("Cores:", N_CORES, "| Buffer:", BUFFER_SIZE, "m\n\n")

# Construction du pipeline
dtm_tri <- triangulate(filter = keep_ground())
dtm <- rasterize(1, dtm_tri, ofile = file.path(result_itd, "dtm_*.tif"))
normalize <- transform_with(dtm_tri)
chm_tri <- triangulate(filter = keep_first())
chm <- rasterize(0.5, chm_tri, ofile = file.path(result_itd, "chm_*.tif"))
chm_filled <- pit_fill(chm, ofile = file.path(result_itd, "c_filled_*.tif"))
seeds <- local_maximum_raster(chm_filled, ws = 3, min_height = 5,
                              ofile = file.path(result_itd, "seeds_*.gpkg"))
tree <- region_growing(chm_filled, seeds,
                       ofile = file.path(result_itd, "crowns_*.tif"))

pipeline_itd <- reader_las() + dtm_tri + dtm + normalize +
                chm_tri + chm + chm_filled + seeds + tree

# Exécution
ans <- exec(pipeline_itd, on = ctg,
            buffer = BUFFER_SIZE,
            ncores = concurrent_files(N_CORES))

elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

# Compter les fichiers créés
files_created <- list(
  dtm = length(list.files(result_itd, "^dtm_.*\\.tif$")),
  chm = length(list.files(result_itd, "^chm_.*\\.tif$")),
  c_filled = length(list.files(result_itd, "^c_filled_.*\\.tif$")),
  crowns = length(list.files(result_itd, "^crowns_.*\\.tif$")),
  seeds = length(list.files(result_itd, "^seeds_.*\\.gpkg$"))
)

stats$ex_3.1$time <- elapsed
stats$ex_3.1$files <- sum(unlist(files_created))
stats$ex_3.1$file_types <- files_created

cat("\n[OK] Exercice 3.1 terminé en", round(elapsed, 1), "s\n")
cat("     Fichiers créés:", stats$ex_3.1$files, "\n")

gc()

# =============================================================================
# EXERCICE 3.2 : Fusion VRT et visualisation
# =============================================================================

cat("\n")
cat("-----------------------------------------------------------------------------\n")
cat(" Exercice 3.2 : Fusion VRT et visualisation\n")
cat("-----------------------------------------------------------------------------\n")

start_time <- Sys.time()

# Lister les tuiles
dtm_tiles <- list.files(result_itd, "^dtm_.*\\.tif$", full.names = TRUE)
chm_tiles <- list.files(result_itd, "^chm_.*\\.tif$", full.names = TRUE)
c_filled_tiles <- list.files(result_itd, "^c_filled_.*\\.tif$", full.names = TRUE)
crown_tiles <- list.files(result_itd, "^crowns_.*\\.tif$", full.names = TRUE)
seed_files <- list.files(result_itd, "^seeds_.*\\.gpkg$", full.names = TRUE)

cat("Tuiles à fusionner:\n")
cat("  DTM:", length(dtm_tiles), "\n")
cat("  CHM:", length(chm_tiles), "\n")
cat("  CHM filled:", length(c_filled_tiles), "\n")
cat("  Crowns:", length(crown_tiles), "\n")
cat("  Seeds:", length(seed_files), "\n\n")

files_created <- list()

# Création des VRT
cat("Création des VRT...\n")
dtm_vrt <- vrt(dtm_tiles, file.path(data_dir, "dtm_complet.vrt"), overwrite = TRUE)
files_created$vrt_dtm <- 1

chm_vrt <- vrt(chm_tiles, file.path(data_dir, "chm_complet.vrt"), overwrite = TRUE)
files_created$vrt_chm <- 1

c_filled_vrt <- vrt(c_filled_tiles, file.path(data_dir, "c_filled_complet.vrt"), overwrite = TRUE)
files_created$vrt_c_filled <- 1

crowns_vrt <- vrt(crown_tiles, file.path(data_dir, "crowns_complet.vrt"), overwrite = TRUE)
files_created$vrt_crowns <- 1

# Fusion des seeds
cat("Fusion des seeds...\n")
seeds_list <- lapply(seed_files, st_read, quiet = TRUE)
seeds_all <- do.call(rbind, seeds_list)
st_write(seeds_all, file.path(data_dir, "seeds_complet.gpkg"),
         delete_dsn = TRUE, quiet = TRUE)
files_created$seeds_gpkg <- 1

cat("  Arbres détectés:", nrow(seeds_all), "\n")
cat("  Hauteur moyenne:", round(mean(seeds_all$Z, na.rm = TRUE), 1), "m\n")
cat("  Hauteur max:", round(max(seeds_all$Z, na.rm = TRUE), 1), "m\n\n")

# Fusion physique
cat("Fusion physique des rasters...\n")
dtm_merge <- terra::merge(sprc(dtm_tiles))
writeRaster(dtm_merge, file.path(data_dir, "dtm_complet.tif"), overwrite = TRUE)
files_created$tif_dtm <- 1

chm_merge <- terra::merge(sprc(chm_tiles))
writeRaster(chm_merge, file.path(data_dir, "chm_complet.tif"), overwrite = TRUE)
files_created$tif_chm <- 1

crown_merge <- terra::merge(sprc(crown_tiles))
writeRaster(crown_merge, file.path(data_dir, "crown_complet.tif"), overwrite = TRUE)
files_created$tif_crowns <- 1

# Visualisation 2x2
cat("Génération de la visualisation 2x2...\n")
col_elev <- colorRampPalette(c("darkgreen", "yellow", "brown", "white"))(25)
col_height <- colorRampPalette(c("blue", "cyan2", "yellow", "red"))(25)
col_crowns <- colorRampPalette(c("purple", "blue", "cyan2", "yellow", "red", "green"))(50)

e <- ext(chm_vrt)
center_x <- (e$xmin + e$xmax) / 2
center_y <- (e$ymin + e$ymax) / 2
zoom_ext <- ext(center_x - 50, center_x + 50, center_y - 50, center_y + 50)

dtm_zoom <- crop(dtm_vrt, zoom_ext)
chm_zoom <- crop(chm_vrt, zoom_ext)
chm_filled_zoom <- crop(c_filled_vrt, zoom_ext)
crowns_zoom <- crop(crowns_vrt, zoom_ext)
seeds_zoom <- st_crop(seeds_all, st_bbox(chm_zoom))

par(mfrow = c(2, 2), mar = c(2, 2, 3, 4))
plot(dtm_zoom, main = "DTM - Altitude sol (1m)", col = col_elev)
plot(chm_zoom, main = "CHM - Hauteur canopée (0.5m)", col = col_height)
plot(chm_filled_zoom, main = "CHM filled (0.5m)", col = col_height)
plot(crowns_zoom %% 8, main = "Houppiers + cimes",
     col = col_crowns[sample.int(50, 1000, TRUE)], legend = FALSE)
if (nrow(seeds_zoom) > 0) {
  plot(st_geometry(seeds_zoom), add = TRUE, pch = 3, col = "white", cex = 0.8)
}
par(mfrow = c(1, 1))

elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

stats$ex_3.2$time <- elapsed
stats$ex_3.2$files <- sum(unlist(files_created))
stats$ex_3.2$file_types <- files_created

cat("\n[OK] Exercice 3.2 terminé en", round(elapsed, 1), "s\n")
cat("     Fichiers créés:", stats$ex_3.2$files, "\n")

gc()

# =============================================================================
# EXERCICE 3.3 : Extraction des métriques d'arbres
# =============================================================================

cat("\n")
cat("-----------------------------------------------------------------------------\n")
cat(" Exercice 3.3 : Extraction des métriques d'arbres\n")
cat("-----------------------------------------------------------------------------\n")

start_time <- Sys.time()

chm_tiles <- list.files(result_itd, "^c_filled_.*\\.tif$", full.names = TRUE)
crown_tiles <- list.files(result_itd, "^crowns_.*\\.tif$", full.names = TRUE)
seed_files <- list.files(result_itd, "^seeds_.*\\.gpkg$", full.names = TRUE)

cat("Tuiles à traiter:", length(crown_tiles), "\n\n")

# Fonction de traitement par tuile
process_tile <- function(i) {
  chm <- rast(chm_tiles[i])
  crowns <- rast(crown_tiles[i])
  seeds <- st_read(seed_files[i], quiet = TRUE)

  if (nrow(seeds) == 0) return(NULL)

  # Extraire hauteur depuis géométrie POINT Z
  coords <- st_coordinates(seeds)
  if (ncol(coords) >= 3) {
    seeds$height <- coords[, 3]
  } else {
    seeds$height <- terra::extract(chm, coords[, 1:2])[, 1]
  }

  # Vectoriser houppiers pour calculer surfaces
  crowns_poly <- as.polygons(crowns)
  crowns_sf <- st_as_sf(crowns_poly)
  names(crowns_sf)[1] <- "treeID"
  crowns_sf$area_m2 <- as.numeric(st_area(crowns_sf))

  # Joindre surfaces aux seeds
  seeds_with_area <- st_join(seeds, crowns_sf[, c("treeID", "area_m2")])

  seeds_with_area
}

# Traitement séquentiel
cat("Extraction des métriques par tuile...\n")
results <- lapply(seq_along(crown_tiles), function(i) {
  cat("  Tuile", i, "/", length(crown_tiles), "\r")
  process_tile(i)
})
cat("\n")

results <- results[!sapply(results, is.null)]

files_created <- list()

if (length(results) > 0) {
  trees_all <- do.call(rbind, results)

  # Supprimer doublons éventuels
  trees_all <- trees_all[!duplicated(st_coordinates(trees_all)), ]

  st_write(trees_all, file.path(data_dir, "arbres_metrics.gpkg"),
           delete_dsn = TRUE, quiet = TRUE)
  files_created$arbres_metrics <- 1

  cat("\nStatistiques des arbres:\n")
  cat("  Nombre total:", nrow(trees_all), "\n")
  cat("  Hauteur moyenne:", round(mean(trees_all$height, na.rm = TRUE), 1), "m\n")
  cat("  Hauteur max:", round(max(trees_all$height, na.rm = TRUE), 1), "m\n")
  cat("  Hauteur min:", round(min(trees_all$height, na.rm = TRUE), 1), "m\n")

  if ("area_m2" %in% names(trees_all)) {
    cat("  Surface houppier moyenne:", round(mean(trees_all$area_m2, na.rm = TRUE), 1), "m²\n")
  }

  cat("  Densité:", round(nrow(trees_all) / surface_ha, 0), "arbres/ha\n")
}

elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

stats$ex_3.3$time <- elapsed
stats$ex_3.3$files <- sum(unlist(files_created))
stats$ex_3.3$file_types <- files_created

cat("\n[OK] Exercice 3.3 terminé en", round(elapsed, 1), "s\n")
cat("     Fichiers créés:", stats$ex_3.3$files, "\n")

gc()

# =============================================================================
# SYNTHÈSE FINALE
# =============================================================================

elapsed_global <- as.numeric(difftime(Sys.time(), start_time_global, units = "secs"))

cat("\n")
cat("=============================================================================\n")
cat(" SYNTHÈSE - Section 3 : Segmentation d'Arbres Individuels\n")
cat("=============================================================================\n\n")

cat("SURFACE TRAITÉE\n")
cat("---------------\n")
cat("  Emprise:", round(bbox["xmax"] - bbox["xmin"]), "x",
    round(bbox["ymax"] - bbox["ymin"]), "m\n")
cat("  Surface:", round(surface_ha, 1), "ha\n")
cat("  Dalles LiDAR:", length(fichiers_laz), "\n\n")

cat("TEMPS DE TRAITEMENT\n")
cat("-------------------\n")
cat(sprintf("  %-25s %8.1f s\n", "Exercice 3.1 (Pipeline ITD):", stats$ex_3.1$time))
cat(sprintf("  %-25s %8.1f s\n", "Exercice 3.2 (Fusion VRT):", stats$ex_3.2$time))
cat(sprintf("  %-25s %8.1f s\n", "Exercice 3.3 (Métriques):", stats$ex_3.3$time))
cat("  ", strrep("-", 35), "\n")
cat(sprintf("  %-25s %8.1f s\n", "TOTAL:", elapsed_global))
cat(sprintf("  %-25s %8.1f ha/min\n", "Débit:", surface_ha / (elapsed_global / 60)))
cat("\n")

cat("FICHIERS CRÉÉS PAR EXERCICE\n")
cat("---------------------------\n")

cat("  Exercice 3.1 (Pipeline ITD):", stats$ex_3.1$files, "fichiers\n")
for (type in names(stats$ex_3.1$file_types)) {
  cat(sprintf("    - %s: %d\n", type, stats$ex_3.1$file_types[[type]]))
}

cat("  Exercice 3.2 (Fusion VRT):", stats$ex_3.2$files, "fichiers\n")
for (type in names(stats$ex_3.2$file_types)) {
  cat(sprintf("    - %s: %d\n", type, stats$ex_3.2$file_types[[type]]))
}

cat("  Exercice 3.3 (Métriques):", stats$ex_3.3$files, "fichiers\n")
for (type in names(stats$ex_3.3$file_types)) {
  cat(sprintf("    - %s: %d\n", type, stats$ex_3.3$file_types[[type]]))
}

total_files <- stats$ex_3.1$files + stats$ex_3.2$files + stats$ex_3.3$files
cat("  ", strrep("-", 35), "\n")
cat("  TOTAL:", total_files, "fichiers\n\n")

cat("PRODUITS FINAUX\n")
cat("---------------\n")
final_products <- c(
  "dtm_complet.tif",
  "dtm_complet.vrt",
  "chm_complet.tif",
  "chm_complet.vrt",
  "crown_complet.tif",
  "crowns_complet.vrt",
  "seeds_complet.gpkg",
  "arbres_metrics.gpkg"
)

for (f in final_products) {
  path <- file.path(data_dir, f)
  if (file.exists(path)) {
    size <- file.info(path)$size
    size_str <- if (size > 1e6) {
      sprintf("%.1f MB", size / 1e6)
    } else {
      sprintf("%.1f KB", size / 1e3)
    }
    cat(sprintf("  [OK] %-25s %10s\n", f, size_str))
  } else {
    cat(sprintf("  [--] %s\n", f))
  }
}

cat("\n")
cat("=============================================================================\n")
cat(" FIN - Durée totale:", round(elapsed_global / 60, 1), "minutes\n")
cat("=============================================================================\n")
