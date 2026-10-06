## Script de génération du jeu d'exemple massif_demo (nemeton >= 1.0.0)
##
## Trois étages :
##   1. les 20 parcelles et leur inventaire SYNTHÉTIQUE (essence, âge,
##      densité, hauteur, diamètre, volume, couvert...) — simulés, set.seed(42) ;
##   2. les couches de démo (rasters 25 m, routes, cours d'eau) de
##      inst/extdata/ — simulées elles aussi, mais NON régénérées par défaut
##      (`regenerer_couches <- FALSE`) : elles font référence ;
##   3. les 41 indicateurs, leurs `_norm` et les 12 familles, CALCULÉS par
##      les fonctions actuelles du paquet à partir de massif_demo_layers().
##      Rien n'y est tiré au hasard ; un indicateur que les couches de démo
##      ne permettent pas de calculer reste à NA (colonne présente).
##
## À lancer depuis la racine du dépôt, sans réseau :
##   Rscript data-raw/massif_demo.R
## Le vent de R2 est fixé à 270° (valeur par défaut de get_nasapower_wind)
## pour ne pas interroger NASA POWER ; R4 reçoit un raster de densité de
## gibier vide pour ne pas télécharger les tableaux de chasse.

library(sf)
library(terra)
devtools::load_all(".", quiet = TRUE) # fonctions actuelles du paquet

regenerer_couches <- FALSE # TRUE réécrit inst/extdata/massif_demo_*.tif/.gpkg
annee_reference <- 2026L # année de l'inventaire synthétique (âge -> année)

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
establishment_year <- annee_reference - age

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


# 2-4. COUCHES DE DÉMO (non régénérées par défaut) =========================
if (regenerer_couches) {
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
}

# 1b. COMPLÉMENT D'INVENTAIRE SYNTHÉTIQUE =====================================
# Couvert du peuplement (fraction 0-1), attendu par C1 (`density_col`). Graine
# propre : le tirage ne dépend pas de la régénération des couches.
set.seed(4242)
couvert_base <- c(
  "Futaie feuillue" = 0.85, "Futaie résineuse" = 0.80,
  "Futaie mixte" = 0.82, "Taillis" = 0.70
)
massif_demo_units$couvert <- round(pmin(
  0.98, couvert_base[massif_demo_units$forest_type] * runif(n_parcels, 0.85, 1.1)
), 2)
attributs <- setdiff(names(massif_demo_units), attr(massif_demo_units, "sf_column"))

# 5. INDICATEURS CALCULÉS PAR LE PAQUET =======================================

cat("Calcul des 41 indicateurs par les fonctions du paquet...\n")

couches <- massif_demo_layers()
extdata <- function(f) system.file("extdata", f, package = "nemeton")
landcover_r <- terra::rast(extdata("massif_demo_landcover.tif"))
dem_r <- terra::rast(extdata("massif_demo_dem.tif"))

# Couverture forestière de type BD Forêt dérivée de l'occupation du sol de
# démo (classes 1-3 = feuillus / conifères / mixte) : seule source de
# polygones forestiers de la démo, pour B3, N2 et R4.
foret_r <- terra::ifel(landcover_r <= 3, landcover_r, NA)
bdforet_demo <- sf::st_as_sf(terra::as.polygons(foret_r, dissolve = TRUE))
names(bdforet_demo)[1] <- "classe"
bdforet_demo$tfv <- c("Forêt fermée feuillus", "Forêt fermée conifères",
                      "Forêt fermée mixte")[bdforet_demo$classe]

# Vent dominant de R2 : la valeur par défaut, posée dans le cache mémoire
# pour éviter l'appel NASA POWER.
local({
  ctr <- suppressWarnings(sf::st_centroid(sf::st_union(massif_demo_units)))
  xy <- sf::st_coordinates(sf::st_transform(ctr, 4326))
  cle <- paste0("wind_", round(xy[1, 1], 2), "_", round(xy[1, 2], 2))
  assign(cle, 270, envir = .wind_cache)
})

# Arguments propres à la démo (le reste passe par le dispatcher du paquet,
# comme dans nemeton_compute()).
args_demo <- list(
  indicateur_c1_biomasse = list(density_col = "couvert"),
  indicateur_w1_reseau = list(layers = couches, watercourse_layer = "water"),
  indicateur_a1_couverture = list(land_cover = landcover_r, forest_classes = 1:3),
  indicateur_b3_connectivite = list(bdforet = bdforet_demo, dem = dem_r),
  indicateur_n2_continuite = list(bdforet = bdforet_demo),
  indicateur_r1_feu = list(layers = couches, bdforet = bdforet_demo),
  indicateur_r4_abroutissement = list(bdforet = bdforet_demo,
                                      game_density = terra::init(landcover_r, NA))
)

# Les composites lisent des codes déjà calculés (T2 <- N2, E2 <- E1,
# N3 <- N1/N2/L1/B3) : calculés en dernier, sur `travail` enrichi au fil de
# la boucle, comme dans nemeton_compute().
indicateurs <- list_indicators()
composites <- c("indicateur_t2_changement", "indicateur_e2_evitement",
                "indicateur_n3_naturalite")
ordre <- c(setdiff(indicateurs, composites), composites)
travail <- massif_demo_units
codes <- setNames(vapply(indicateurs, .indicator_short_code, ""), indicateurs)
valeurs <- list()
statuts <- list()
echecs <- character()

for (ind in ordre) {
  code <- codes[[ind]]
  res <- tryCatch(
    suppressWarnings(suppressMessages(
      if (ind %in% names(args_demo)) {
        do.call(get(ind), c(list(units = travail), args_demo[[ind]]))
      } else {
        .compute_indicator_result(ind, travail, couches)
      }
    )),
    error = function(e) {
      echecs[[code]] <<- conditionMessage(e)
      NULL
    }
  )
  v <- if (is.null(res)) rep(NA_real_, nrow(travail)) else as.double(res[[code]])
  valeurs[[code]] <- v
  travail[[code]] <- v
  st <- paste0(tolower(code), "_status")
  if (!is.null(res) && st %in% names(res)) statuts[[st]] <- as.character(res[[st]])
}

# Colonnes dans l'ordre de list_indicators() : valeurs, statuts, `_norm`
code_ordre <- unname(codes[indicateurs])
for (code in code_ordre) massif_demo_units[[code]] <- valeurs[[code]]
for (st in intersect(paste0(tolower(code_ordre), "_status"), names(statuts))) {
  massif_demo_units[[st]] <- statuts[[st]]
}
for (code in code_ordre) {
  st <- statuts[[paste0(tolower(code), "_status")]]
  massif_demo_units[[paste0(code, "_norm")]] <-
    as.double(normalize_indicator(code, valeurs[[code]], statut = st))
}

# Les 12 familles, par la fonction du paquet (moyenne des indicateurs
# normalisés selon leur règle propre, NA ignorés)
massif_demo_units <- suppressWarnings(create_family_index(massif_demo_units))
familles <- vapply(c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N"),
                   get_famille_col, "")
geom_col <- attr(massif_demo_units, "sf_column")
massif_demo_units <- massif_demo_units[, c(
  attributs, code_ordre,
  intersect(paste0(tolower(code_ordre), "_status"), names(massif_demo_units)),
  paste0(code_ordre, "_norm"), unname(familles), geom_col
)]

na_ind <- code_ordre[vapply(code_ordre, function(c) all(is.na(massif_demo_units[[c]])), TRUE)]
cat(sprintf("  ✓ %d indicateurs calculés, %d restés NA : %s\n",
            length(code_ordre) - length(na_ind), length(na_ind),
            paste(na_ind, collapse = ", ")))
if (length(echecs)) {
  cat("  Indicateurs en erreur (mis à NA) :\n")
  for (k in names(echecs)) cat(sprintf("    %s : %s\n", k, echecs[[k]]))
}

# 6. SAUVEGARDER =============================================================

st_write(massif_demo_units, "inst/extdata/massif_demo_units.gpkg",
         delete_dsn = TRUE, quiet = TRUE)
usethis::use_data(massif_demo_units, overwrite = TRUE, compress = "xz")

cat("\n=== MASSIF DEMO ===\n")
cat(sprintf("Parcelles : %d (%.1f ha)\n", nrow(massif_demo_units),
            sum(massif_demo_units$surface_ha)))
cat(sprintf("Colonnes : %d\n", ncol(massif_demo_units)))
cat("Fichiers : data/massif_demo_units.rda, inst/extdata/massif_demo_units.gpkg\n")
