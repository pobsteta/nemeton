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

# Ajouter attributs de base
forest_type <- sample(
  c("Futaie feuillue", "Futaie r\u00e9sineuse", "Futaie mixte", "Taillis"),
  n_parcels,
  replace = TRUE,
  prob = c(0.4, 0.3, 0.2, 0.1)
)

age_class <- sample(
  c("Jeune", "Moyen", "Mature", "Surann\u00e9e"),
  n_parcels,
  replace = TRUE,
  prob = c(0.2, 0.3, 0.4, 0.1)
)

management <- sample(
  c("Production", "Conservation", "Mixte"),
  n_parcels,
  replace = TRUE,
  prob = c(0.5, 0.2, 0.3)
)

# Colonnes d\u00e9riv\u00e9es pour les indicateurs

# species: Code IFN de l'esp\u00e8ce principale (bas\u00e9 sur forest_type)
species <- sapply(forest_type, function(ft) {
  switch(ft,
    "Futaie feuillue" = sample(c("03", "09", "52"), 1, prob = c(0.5, 0.3, 0.2)),  # Ch\u00eane, H\u00eatre, Ch\u00e2taignier
    "Futaie r\u00e9sineuse" = sample(c("61", "62", "64"), 1, prob = c(0.4, 0.4, 0.2)),  # Sapin, \u00c9pic\u00e9a, Douglas
    "Futaie mixte" = sample(c("03", "61", "09", "62"), 1),  # M\u00e9lange
    "Taillis" = sample(c("17", "52", "03"), 1, prob = c(0.5, 0.3, 0.2))  # Charme, Ch\u00e2taignier, Ch\u00eane
  )
})

# age: \u00c2ge num\u00e9rique en ann\u00e9es (bas\u00e9 sur age_class)
age <- sapply(age_class, function(ac) {
  switch(ac,
    "Jeune" = round(runif(1, 10, 30)),
    "Moyen" = round(runif(1, 30, 60)),
    "Mature" = round(runif(1, 60, 100)),
    "Surann\u00e9e" = round(runif(1, 100, 180))
  )
})

# establishment_year: Ann\u00e9e d'\u00e9tablissement
establishment_year <- as.integer(format(Sys.Date(), "%Y")) - age

# density: Densit\u00e9 de tiges/ha (d\u00e9pend du type et de l'\u00e2ge)
density <- mapply(function(ft, a) {
  base_density <- switch(ft,
    "Futaie feuillue" = 250,
    "Futaie r\u00e9sineuse" = 400,
    "Futaie mixte" = 320,
    "Taillis" = 1500
  )
  # La densit\u00e9 diminue avec l'\u00e2ge (auto-\u00e9claircie)
  age_factor <- if (a < 30) 1.5 else if (a < 60) 1.0 else if (a < 100) 0.7 else 0.5
  round(base_density * age_factor * runif(1, 0.8, 1.2))
}, forest_type, age)

# height: Hauteur dominante en m (bas\u00e9e sur esp\u00e8ce et \u00e2ge, courbe de croissance simplifi\u00e9e)
height <- mapply(function(sp, a) {
  # Hauteur maximale selon esp\u00e8ce (code IFN)
  h_max <- switch(sp,
    "03" = 35,  # Ch\u00eane
    "09" = 40,  # H\u00eatre
    "52" = 30,  # Ch\u00e2taignier
    "61" = 45,  # Sapin
    "62" = 40,  # \u00c9pic\u00e9a
    "64" = 50,  # Douglas
    "17" = 25,  # Charme
    30  # D\u00e9faut
  )
  # Courbe de croissance: h = h_max * (1 - exp(-k * age))
  k <- 0.025
  h <- h_max * (1 - exp(-k * a)) * runif(1, 0.85, 1.15)
  round(h, 1)
}, species, age)

# dbh: Diam\u00e8tre moyen \u00e0 1.30m en cm (relation hauteur-diam\u00e8tre)
dbh <- mapply(function(sp, h, a) {
  # Ratio hauteur/diam\u00e8tre selon esp\u00e8ce
  hd_ratio <- switch(sp,
    "03" = 0.7,   # Ch\u00eane (trapu)
    "09" = 0.65,  # H\u00eatre
    "52" = 0.75,  # Ch\u00e2taignier
    "61" = 0.55,  # Sapin (\u00e9lanc\u00e9)
    "62" = 0.5,   # \u00c9pic\u00e9a
    "64" = 0.5,   # Douglas
    "17" = 0.8,   # Charme (petit)
    0.6  # D\u00e9faut
  )
  d <- h / hd_ratio * runif(1, 0.9, 1.1)
  round(d, 1)
}, species, height, age)

# volume: Volume sur pied en m\u00b3/ha (formule simplifi\u00e9e: V = G * H * 0.4)
# G = surface terri\u00e8re = N * pi * (D/200)\u00b2
volume <- mapply(function(n, d, h) {
  g <- n * pi * (d / 200)^2  # Surface terri\u00e8re m\u00b2/ha
  v <- g * h * 0.42  # Coefficient de forme moyen
  round(v, 1)
}, density, dbh, height)

# strata: Nombre de strates de v\u00e9g\u00e9tation (1-4)
strata <- sapply(forest_type, function(ft) {
  switch(ft,
    "Futaie feuillue" = sample(2:4, 1, prob = c(0.2, 0.5, 0.3)),
    "Futaie r\u00e9sineuse" = sample(1:3, 1, prob = c(0.3, 0.5, 0.2)),
    "Futaie mixte" = sample(2:4, 1, prob = c(0.1, 0.4, 0.5)),
    "Taillis" = sample(1:2, 1, prob = c(0.6, 0.4))
  )
})

# fertility: Classe de fertilit\u00e9 (1=bonne, 2=moyenne, 3=faible)
fertility <- sample(1:3, n_parcels, replace = TRUE, prob = c(0.3, 0.5, 0.2))

# climate: Zone climatique (pour indicateur P2)
climate <- sample(
  c("atlantique", "continental", "montagnard"),
  n_parcels,
  replace = TRUE,
  prob = c(0.5, 0.3, 0.2)
)

# Cr\u00e9er le sf object avec toutes les colonnes
massif_demo_units <- st_sf(
  parcel_id = sprintf("P%02d", 1:n_parcels),
  forest_type = forest_type,
  age_class = age_class,
  management = management,
  species = species,
  age = as.integer(age),
  establishment_year = establishment_year,
  density = as.integer(density),
  height = height,
  dbh = dbh,
  volume = volume,
  strata = as.integer(strata),
  fertility = as.integer(fertility),
  climate = climate,
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

# Sauvegarder les autres vecteurs maintenant (sans indicateurs)
st_write(massif_demo_roads, "inst/extdata/massif_demo_roads.gpkg", delete_dsn = TRUE, quiet = TRUE)
st_write(massif_demo_water, "inst/extdata/massif_demo_water.gpkg", delete_dsn = TRUE, quiet = TRUE)

cat("  ✓ Vecteurs (routes, cours d'eau) sauvegardés dans inst/extdata/\n")

# =============================================================================
# 4b. AJOUTER LES 29 INDICATEURS SYNTHÉTIQUES + 12 COMPOSITES FAMILLE
# =============================================================================
# Valeurs générées de façon déterministe (set.seed) pour les tests reproductibles.
# Les indicateurs sont corrélés avec les attributs de base (species, age,
# density, volume, dbh, etc.) pour rester cohérents.

cat("Ajout des 29 indicateurs et 12 composites famille...\n")
set.seed(42)
n <- nrow(massif_demo_units)

# Helper: normalisation min-max vers 0-100
nm <- function(x, lo = NULL, hi = NULL) {
  if (is.null(lo)) lo <- min(x, na.rm = TRUE)
  if (is.null(hi)) hi <- max(x, na.rm = TRUE)
  if (hi == lo) return(rep(50, length(x)))
  pmax(0, pmin(100, (x - lo) / (hi - lo) * 100))
}

age_val <- massif_demo_units$age
vol_val <- massif_demo_units$volume
dens_val <- massif_demo_units$density
dbh_val <- massif_demo_units$dbh
height_val <- massif_demo_units$height
surf_val <- massif_demo_units$surface_ha

# ---- Famille C : Carbone & Vitalité ----
massif_demo_units$C1 <- pmin(300, pmax(20, vol_val * 0.45 + rnorm(n, 0, 15)))
massif_demo_units$C2 <- runif(n, 0.3, 0.85) + (age_val / 500)

# ---- Famille B : Biodiversité ----
massif_demo_units$B1 <- runif(n, 0, 100)
massif_demo_units$B2 <- pmin(100, pmax(0, 50 + (age_val - 80) / 3 + rnorm(n, 0, 10)))
massif_demo_units$B3 <- runif(n, 20, 95)

# ---- Famille W : Eau & Régulation ----
massif_demo_units$W1 <- runif(n, 0, 8)
massif_demo_units$W2 <- runif(n, 0, 40)
massif_demo_units$W3 <- runif(n, 3, 12)

# ---- Famille A : Air & Microclimat ----
massif_demo_units$A1 <- pmin(100, pmax(0, 60 + (vol_val / 10) + rnorm(n, 0, 15)))
massif_demo_units$A2 <- runif(n, 45, 95)

# ---- Famille F : Fertilité des sols ----
massif_demo_units$F1 <- as.integer(massif_demo_units$fertility)
massif_demo_units$F2 <- runif(n, 0, 35)

# ---- Famille L : Paysage ----
massif_demo_units$L1 <- runif(n, 30, 90)
massif_demo_units$L2 <- runif(n, 20, 80)

# ---- Famille T : Temporel ----
massif_demo_units$T1 <- as.numeric(age_val)
massif_demo_units$T2 <- runif(n, 0, 18)

# ---- Famille R : Risques & Résilience ----
massif_demo_units$R1 <- pmin(100, pmax(0, 40 + rnorm(n, 0, 20)))
massif_demo_units$R2 <- pmin(100, pmax(0, (height_val / 30) * 60 + rnorm(n, 0, 15)))
massif_demo_units$R3 <- pmin(100, pmax(0, 35 + rnorm(n, 0, 20)))
massif_demo_units$R4 <- pmin(100, pmax(0, 30 + rnorm(n, 0, 20)))

# ---- Famille S : Social & Usages ----
massif_demo_units$S1 <- runif(n, 0, 4.5)
massif_demo_units$S2 <- runif(n, 20, 95)
massif_demo_units$S3 <- runif(n, 0, 80000)

# ---- Famille P : Production & Économie ----
massif_demo_units$P1 <- pmin(1000, pmax(0, vol_val + rnorm(n, 0, 30)))
massif_demo_units$P2 <- pmin(20, pmax(0, 8 + (massif_demo_units$fertility - 3) * 1.5 + rnorm(n, 0, 2)))
massif_demo_units$P3 <- pmin(100, pmax(0, 50 + (dbh_val - 30) + rnorm(n, 0, 10)))

# ---- Famille E : Énergie & Climat ----
massif_demo_units$E1 <- pmin(15, pmax(0, (vol_val * 0.02) + rnorm(n, 0, 1)))
massif_demo_units$E2 <- pmin(30, pmax(0, massif_demo_units$E1 * 2.2))

# ---- Famille N : Naturalité ----
massif_demo_units$N1 <- runif(n, 100, 9500)
massif_demo_units$N2 <- runif(n, 10, 9500)
massif_demo_units$N3 <- pmin(100, pmax(0, (age_val / 2) + rnorm(n, 0, 15)))

# ---- Versions normalisées (0-100) pour les 29 indicateurs ----
indicator_cols <- c(
  "C1", "C2", "B1", "B2", "B3", "W1", "W2", "W3",
  "A1", "A2", "F1", "F2", "L1", "L2", "T1", "T2",
  "R1", "R2", "R3", "R4", "S1", "S2", "S3",
  "P1", "P2", "P3", "E1", "E2", "N1", "N2", "N3"
)
for (col in indicator_cols) {
  massif_demo_units[[paste0(col, "_norm")]] <- nm(massif_demo_units[[col]])
}

# ---- Composites famille (moyenne des indicateurs normalisés) ----
fam_components <- list(
  famille_carbone      = c("C1_norm", "C2_norm"),
  famille_biodiversite = c("B1_norm", "B2_norm", "B3_norm"),
  famille_eau          = c("W1_norm", "W2_norm", "W3_norm"),
  famille_air          = c("A1_norm", "A2_norm"),
  famille_sol          = c("F1_norm", "F2_norm"),
  famille_paysage      = c("L1_norm", "L2_norm"),
  famille_temporel     = c("T1_norm", "T2_norm"),
  famille_risque       = c("R1_norm", "R2_norm", "R3_norm", "R4_norm"),
  famille_social       = c("S1_norm", "S2_norm", "S3_norm"),
  famille_production   = c("P1_norm", "P2_norm", "P3_norm"),
  famille_energie      = c("E1_norm", "E2_norm"),
  famille_naturalite   = c("N1_norm", "N2_norm", "N3_norm")
)
for (fam in names(fam_components)) {
  cols <- fam_components[[fam]]
  massif_demo_units[[fam]] <- rowMeans(
    sf::st_drop_geometry(massif_demo_units)[, cols, drop = FALSE],
    na.rm = TRUE
  )
}

cat("  ✓ 29 indicateurs + 12 composites famille ajoutés\n")

# Sauvegarder le .gpkg APRÈS l'ajout des indicateurs (pour que le fichier
# partage contienne toutes les colonnes utilisées par les tests et vignettes)
st_write(massif_demo_units, "inst/extdata/massif_demo_units.gpkg", delete_dsn = TRUE, quiet = TRUE)
cat("  ✓ massif_demo_units.gpkg sauvegardé avec indicateurs\n")

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
