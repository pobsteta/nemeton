## Script de génération du dataset d'exemple massif_demo
## Dataset synthétique pour démonstration du package nemeton

library(sf)
library(terra)
library(dplyr)

set.seed(42) # Reproductibilité

# Paramètres du Massif Demo
# Zone fictive inspirée des massifs français
# Coordonnées en Lambert-93 (EPSG:2154)
center_x <- 700000 # Centre approximatif France
center_y <- 6500000
extent_size <- 5000 # 5km x 5km

# 1. CRÉER LES PARCELLES FORESTIÈRES ==========================================

cat("Création des parcelles forestières...\n")

# Grille de parcelles irrégulières
n_parcels <- 20

# Générer points centraux avec clustering naturel
cluster_centers <- data.frame(
  x = center_x + rnorm(4, 0, 1500),
  y = center_y + rnorm(4, 0, 1500)
)

# Créer parcelles autour des clusters
parcels_list <- list()

for (i in 1:n_parcels) {
  # Choisir un cluster aléatoire
  cluster <- sample(1:4, 1)
  cx <- cluster_centers$x[cluster]
  cy <- cluster_centers$y[cluster]

  # Position avec offset
  px <- cx + rnorm(1, 0, 800)
  py <- cy + rnorm(1, 0, 800)

  # Taille variable (2-20 ha)
  area_ha <- runif(1, 2, 20)
  side <- sqrt(area_ha * 10000) * runif(1, 0.7, 1.3) # Forme irrégulière

  # Rotation aléatoire
  angle <- runif(1, 0, 2 * pi)

  # Points du polygone (hexagone irrégulier)
  n_sides <- 6
  angles <- seq(0, 2 * pi, length.out = n_sides + 1)[1:n_sides] + angle
  distances <- side / 2 * runif(n_sides, 0.7, 1.3)

  coords <- data.frame(
    x = px + distances * cos(angles),
    y = py + distances * sin(angles)
  )
  coords <- rbind(coords, coords[1, ]) # Fermer le polygone

  parcels_list[[i]] <- st_polygon(list(as.matrix(coords)))
}

# Créer sf object
parcels_geom <- st_sfc(parcels_list, crs = 2154)

# Ajouter attributs
massif_demo_units <- st_sf(
  parcel_id = sprintf("P%02d", 1:n_parcels),
  forest_type = sample(
    c("Futaie feuillue", "Futaie résineuse", "Futaie mixte", "Taillis"),
    n_parcels,
    replace = TRUE,
    prob = c(0.4, 0.3, 0.2, 0.1)
  ),
  age_class = sample(
    c("Jeune", "Moyen", "Mature", "Surannée"),
    n_parcels,
    replace = TRUE,
    prob = c(0.2, 0.3, 0.4, 0.1)
  ),
  management = sample(
    c("Production", "Conservation", "Mixte"),
    n_parcels,
    replace = TRUE,
    prob = c(0.5, 0.2, 0.3)
  ),
  surface_ha = as.numeric(st_area(parcels_geom)) / 10000,
  geometry = parcels_geom
)

cat(sprintf("  ✓ %d parcelles créées\n", n_parcels))

# 2. CRÉER LES RASTERS ========================================================

# Extent global
bbox <- st_bbox(massif_demo_units)
bbox_buffered <- bbox + c(-500, -500, 500, 500) # Buffer 500m

# Résolution 25m (comme IGN)
res <- 25

cat("Création des rasters...\n")

# Raster template
r_template <- rast(
  extent = ext(bbox_buffered[c(1, 3, 2, 4)]),
  resolution = res,
  crs = "EPSG:2154"
)

# 2.1 Biomasse aérienne (Mg/ha)
cat("  - Biomasse...\n")
biomass <- r_template

# Générer pattern réaliste avec gradient + bruit
coords <- xyFromCell(biomass, 1:ncell(biomass))
x_norm <- (coords[, 1] - bbox_buffered[1]) / (bbox_buffered[3] - bbox_buffered[1])
y_norm <- (coords[, 2] - bbox_buffered[2]) / (bbox_buffered[4] - bbox_buffered[2])

# Gradient de biomasse (augmente vers nord-ouest)
gradient <- 100 + 150 * (0.5 * (1 - x_norm) + 0.5 * y_norm)

# Ajouter structure spatiale (patches)
patch_size <- 10 # Nombre de patches
patch_centers <- data.frame(
  x = runif(patch_size, bbox_buffered[1], bbox_buffered[3]),
  y = runif(patch_size, bbox_buffered[2], bbox_buffered[4]),
  intensity = rnorm(patch_size, 0, 50)
)

patches <- sapply(seq_len(nrow(coords)), function(i) {
  dists <- sqrt((coords[i, 1] - patch_centers$x)^2 + (coords[i, 2] - patch_centers$y)^2)
  weights <- exp(-dists / 500) # Décroissance exponentielle
  sum(weights * patch_centers$intensity) / sum(weights)
})

# Combiner gradient + patches + bruit
values(biomass) <- pmax(50, gradient + patches + rnorm(ncell(biomass), 0, 20))

# 2.2 MNT (DEM) - Modèle Numérique de Terrain
cat("  - MNT...\n")
dem <- r_template

# Générer relief réaliste
# Pente générale + ondulations
slope_x <- (coords[, 1] - mean(coords[, 1])) / 2000 * 15 # Pente douce
noise_large <- rnorm(ncell(dem), 0, 30)
noise_small <- rnorm(ncell(dem), 0, 10)

# Altitude de base 400-600m
values(dem) <- 500 + slope_x + noise_large + noise_small
values(dem) <- pmax(350, pmin(700, values(dem))) # Limiter 350-700m

# 2.3 Occupation du sol (classes)
cat("  - Occupation du sol...\n")
landcover <- r_template

# Classes: 1=Forêt feuillue, 2=Forêt résineuse, 3=Forêt mixte,
#          4=Prairie, 5=Eau, 6=Zone bâtie
lc_values <- rep(NA, ncell(landcover))

# Forêt = majorité
forest_prob <- 0.85
for (i in 1:ncell(landcover)) {
  if (runif(1) < forest_prob) {
    # Zone forestière
    lc_values[i] <- sample(1:3, 1, prob = c(0.4, 0.3, 0.3))
  } else {
    # Autres
    lc_values[i] <- sample(4:6, 1, prob = c(0.6, 0.3, 0.1))
  }
}

# Ajouter cohérence spatiale (moyennage avec voisins)
for (pass in 1:3) {
  temp <- focal(rast(r_template, vals = lc_values), w = 3, fun = "modal", na.policy = "omit")
  lc_values <- values(temp)[, 1]
}

values(landcover) <- round(lc_values)

# 2.4 Richesse spécifique (nombre d'espèces)
cat("  - Richesse spécifique...\n")
species_richness <- r_template

# Corrélée avec biomasse et diversité d'habitats
# Plus de biomasse = plus d'espèces (généralement)
biomass_norm <- (values(biomass) - min(values(biomass))) /
  (max(values(biomass)) - min(values(biomass)))

# Diversité d'occupation du sol (calculée localement)
lc_diversity <- focal(landcover, w = 5, fun = function(x) length(unique(x)))

richness_base <- 10 + 30 * biomass_norm + 10 * (values(lc_diversity) / max(values(lc_diversity), na.rm = TRUE))
values(species_richness) <- pmax(5, round(richness_base + rnorm(ncell(species_richness), 0, 5)))

# 3. CRÉER LES VECTEURS =======================================================

cat("Création des vecteurs...\n")

# 3.1 Routes
cat("  - Routes...\n")
n_roads <- 5
roads_list <- list()

for (i in 1:n_roads) {
  # Points de départ et arrivée
  start_x <- runif(1, bbox_buffered[1], bbox_buffered[3])
  start_y <- runif(1, bbox_buffered[2], bbox_buffered[4])
  end_x <- runif(1, bbox_buffered[1], bbox_buffered[3])
  end_y <- runif(1, bbox_buffered[2], bbox_buffered[4])

  # Créer ligne sinueuse (10 points intermédiaires)
  n_pts <- 12
  t_seq <- seq(0, 1, length.out = n_pts)

  # Interpolation avec sinuosité
  x_pts <- start_x + (end_x - start_x) * t_seq + rnorm(n_pts, 0, 200)
  y_pts <- start_y + (end_y - start_y) * t_seq + rnorm(n_pts, 0, 200)

  coords <- cbind(x_pts, y_pts)
  roads_list[[i]] <- st_linestring(coords)
}

massif_demo_roads <- st_sf(
  road_id = sprintf("R%02d", 1:n_roads),
  road_type = sample(
    c("Départementale", "Forestière", "Chemin"),
    n_roads,
    replace = TRUE,
    prob = c(0.2, 0.5, 0.3)
  ),
  geometry = st_sfc(roads_list, crs = 2154)
)

# 3.2 Cours d'eau
cat("  - Cours d'eau...\n")
n_rivers <- 3
rivers_list <- list()

for (i in 1:n_rivers) {
  # Les rivières suivent généralement les vallées (altitudes basses)
  start_x <- runif(1, bbox_buffered[1], bbox_buffered[3])
  start_y <- bbox_buffered[4] # Commence en haut

  # Descendre en suivant la pente
  n_pts <- 20
  x_pts <- numeric(n_pts)
  y_pts <- numeric(n_pts)

  x_pts[1] <- start_x
  y_pts[1] <- start_y

  for (j in 2:n_pts) {
    # Avancer vers le bas avec sinuosité
    x_pts[j] <- x_pts[j - 1] + rnorm(1, 0, 150)
    y_pts[j] <- y_pts[j - 1] - abs(rnorm(1, 200, 50)) # Descendre
  }

  coords <- cbind(x_pts, y_pts)
  rivers_list[[i]] <- st_linestring(coords)
}

massif_demo_water <- st_sf(
  water_id = sprintf("W%02d", 1:n_rivers),
  water_type = sample(
    c("Ruisseau", "Rivière", "Torrent"),
    n_rivers,
    replace = TRUE,
    prob = c(0.5, 0.3, 0.2)
  ),
  geometry = st_sfc(rivers_list, crs = 2154)
)

# 4. SAUVEGARDER =============================================================

cat("\nSauvegarde des données...\n")

# Sauvegarder les rasters
writeRaster(biomass, "inst/extdata/massif_demo_biomass.tif", overwrite = TRUE)
writeRaster(dem, "inst/extdata/massif_demo_dem.tif", overwrite = TRUE)
writeRaster(landcover, "inst/extdata/massif_demo_landcover.tif", overwrite = TRUE)
writeRaster(species_richness, "inst/extdata/massif_demo_species_richness.tif", overwrite = TRUE)

cat("  ✓ Rasters sauvegardés dans inst/extdata/\n")

# Sauvegarder les vecteurs
st_write(massif_demo_units, "inst/extdata/massif_demo_units.gpkg", delete_dsn = TRUE, quiet = TRUE)
st_write(massif_demo_roads, "inst/extdata/massif_demo_roads.gpkg", delete_dsn = TRUE, quiet = TRUE)
st_write(massif_demo_water, "inst/extdata/massif_demo_water.gpkg", delete_dsn = TRUE, quiet = TRUE)

cat("  ✓ Vecteurs sauvegardés dans inst/extdata/\n")

# Sauvegarder aussi comme objets R pour accès rapide
usethis::use_data(massif_demo_units, overwrite = TRUE)

cat("  ✓ Dataset R sauvegardé dans data/\n")

# 5. RÉSUMÉ ==================================================================

cat("\n=== MASSIF DEMO DATASET CRÉÉ ===\n")
cat(sprintf(
  "Parcelles: %d (%.1f ha total)\n",
  nrow(massif_demo_units),
  sum(massif_demo_units$surface_ha)
))
cat(sprintf(
  "Extent: %.0f x %.0f m\n",
  bbox_buffered[3] - bbox_buffered[1],
  bbox_buffered[4] - bbox_buffered[2]
))
cat(sprintf("Rasters: 4 (résolution %dm)\n", res))
cat(sprintf("Routes: %d\n", nrow(massif_demo_roads)))
cat(sprintf("Cours d'eau: %d\n", nrow(massif_demo_water)))
cat("\nFichiers créés:\n")
cat("  - inst/extdata/massif_demo_*.tif (4 rasters)\n")
cat("  - inst/extdata/massif_demo_*.gpkg (3 vecteurs)\n")
cat("  - data/massif_demo_units.rda (objet R)\n")
cat("\nUtilisation:\n")
cat("  data(massif_demo_units)\n")
cat("  layers <- massif_demo_layers()\n")
cat("===============================\n")
