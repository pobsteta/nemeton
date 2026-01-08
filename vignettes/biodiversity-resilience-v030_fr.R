## ----setup, include = FALSE---------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  fig.width = 7,
  fig.height = 5.5,
  warning = FALSE,
  message = FALSE
)

## -----------------------------------------------------------------------------
library(nemeton)
library(sf)
library(ggplot2)
library(dplyr)

## -----------------------------------------------------------------------------
# Charger les données de démonstration
data(massif_demo_units)
units <- massif_demo_units[1:10, ]

# Ajouter des attributs synthétiques pour les exemples
set.seed(42)
units$strata <- sample(c("Emergent", "Dominant", "Intermediate", "Suppressed"),
                       10, replace = TRUE)
units$age_class <- sample(c("Young", "Intermediate", "Mature", "Old", "Ancient"),
                          10, replace = TRUE)
units$species <- sample(c("Quercus", "Fagus", "Pinus", "Abies"), 10, replace = TRUE)
units$age <- sample(c(45, 80, 120, 150, 200), 10, replace = TRUE)
units$height <- runif(10, 15, 30)
units$density <- runif(10, 0.6, 0.95)

# Créer des zones protégées synthétiques
bbox <- st_bbox(units)
zone1 <- st_buffer(st_geometry(st_centroid(units[2, ])), 250)
zone2 <- st_buffer(st_geometry(st_centroid(units[7, ])), 400)

protected_areas <- st_sf(
  zone_id = c("ZNIEFF_001", "N2000_042"),
  type = c("ZNIEFF", "Natura2000"),
  geometry = c(zone1, zone2),
  crs = st_crs(units)
)

# Créer un corridor écologique synthétique
corridor_geom <- st_linestring(cbind(
  c(bbox["xmin"], bbox["xmax"]),
  c(mean(c(bbox["ymin"], bbox["ymax"])), mean(c(bbox["ymin"], bbox["ymax"])))
))

corridor <- st_sf(
  corridor_id = "TVB_001",
  geometry = st_sfc(corridor_geom, crs = st_crs(units))
)

## -----------------------------------------------------------------------------
result <- indicator_biodiversity_protection(
  units,
  protected_areas = protected_areas,
  source = "local"
)

summary(result$B1)

## -----------------------------------------------------------------------------
result <- indicator_biodiversity_structure(
  result,
  strata_field = "strata",
  age_class_field = "age_class",
  species_field = "species",
  method = "shannon",
  weights = c(strata = 0.4, age = 0.3, species = 0.3)
)

summary(result$B2)

## -----------------------------------------------------------------------------
result <- indicator_biodiversity_connectivity(
  result,
  corridors = corridor,
  distance_method = "edge",
  max_distance = 3000
)

summary(result$B3)

## -----------------------------------------------------------------------------
# Simulation des indicateurs de risque
# (Dans un cas réel, utiliser les fonctions avec DEM et données climatiques)
set.seed(43)
result$R1 <- pmin(100, pmax(0, 40 + runif(10, -20, 30)))  # Risque incendie
result$R2 <- pmin(100, pmax(0, 45 + runif(10, -25, 35)))  # Vulnérabilité tempête
result$R3 <- pmin(100, pmax(0, 35 + runif(10, -15, 40)))  # Stress hydrique

# Les pins en pente ont plus de risque incendie
result$R1[result$species == "Pinus"] <- result$R1[result$species == "Pinus"] * 1.3
result$R1 <- pmin(100, result$R1)

# Les peuplements hauts/denses ont plus de risque tempête
result$R2 <- result$R2 * (result$height / 22) * (result$density / 0.8)
result$R2 <- pmin(100, result$R2)

summary(result[, c("R1", "R2", "R3")])

## -----------------------------------------------------------------------------
# Utiliser les âges déjà définis
result$T1 <- result$age  # Directement l'âge en années
summary(result$T1)

## -----------------------------------------------------------------------------
# Simulation de taux de changement (%/an)
set.seed(44)
result$T2 <- runif(10, 0, 25)
# Les forêts anciennes sont plus stables
result$T2[result$T1 > 150] <- result$T2[result$T1 > 150] * 0.3
summary(result$T2)

## -----------------------------------------------------------------------------
# Simulation de couverture dans buffer 1km
set.seed(45)
result$A1 <- runif(10, 40, 95)
summary(result$A1)

## -----------------------------------------------------------------------------
# Simulation d'indice qualité air
set.seed(46)
result$A2 <- runif(10, 55, 95)
summary(result$A2)

## -----------------------------------------------------------------------------
# Normaliser tous les nouveaux indicateurs
result_norm <- normalize_indicators(
  result,
  indicators = c("B1", "B2", "B3", "R1", "R2", "R3", "T1", "T2", "A1", "A2"),
  method = "minmax"
)

# Créer les indices composites par famille
result_norm <- create_family_index(
  result_norm,
  family_codes = c("B", "R", "T", "A"),
  method = "mean"
)

# Afficher les indices par famille
result_norm |>
  st_drop_geometry() |>
  select(parcel_id, family_B, family_R, family_T, family_A) |>
  head()

## -----------------------------------------------------------------------------
# Agrégation conservative pour la famille Risques
result_risk_min <- create_family_index(
  result_norm,
  family_codes = "R",
  method = "min"  # Score = pire indicateur
)

# Comparer méthodes "mean" vs "min"
comparison <- result_norm |>
  st_drop_geometry() |>
  select(parcel_id, R1_norm, R2_norm, R3_norm, family_R) |>
  mutate(
    risk_min = pmin(R1_norm, R2_norm, R3_norm)
  ) |>
  head()

comparison

## ----fig.height=6-------------------------------------------------------------
# Radar pour une parcelle (4 nouvelles familles)
nemeton_radar(
  result_norm,
  unit_id = 1,
  mode = "family",
  title = "Profil v0.3.0 - Parcelle 1 (nouvelles familles)"
)

## -----------------------------------------------------------------------------
# Ajouter quelques indicateurs des familles existantes pour démonstration
result_norm$C1 <- runif(10, 40, 90)  # Carbon biomass
result_norm$W1 <- runif(10, 30, 80)  # Water network
result_norm$F1 <- runif(10, 35, 85)  # Soil fertility
result_norm$L1 <- runif(10, 25, 75)  # Landscape fragmentation

# Normaliser
result_norm <- normalize_indicators(
  result_norm,
  indicators = c("C1", "W1", "F1", "L1"),
  method = "minmax"
)

# Créer indices familles existantes
result_complete <- create_family_index(
  result_norm,
  family_codes = c("C", "W", "F", "L"),
  method = "mean"
)

## ----fig.height=7-------------------------------------------------------------
# Radar complet : 8 familles
nemeton_radar(
  result_complete,
  unit_id = 1,
  mode = "family",
  title = "Profil écosystémique complet - Parcelle 1 (8 familles)"
)

## ----fig.height=7-------------------------------------------------------------
# Comparer 3 parcelles sur le même radar
nemeton_radar(
  result_complete,
  unit_id = c(1, 5, 8),
  mode = "family",
  title = "Comparaison de 3 parcelles - 8 familles"
)

## -----------------------------------------------------------------------------
hotspots_bio <- result_complete |>
  filter(family_B > 60, T1 > 100) |>
  arrange(desc(family_B))

cat("Forêts anciennes à haute biodiversité :", nrow(hotspots_bio), "parcelles\n")

# Afficher les parcelles identifiées
if(nrow(hotspots_bio) > 0) {
  hotspots_bio |>
    st_drop_geometry() |>
    select(parcel_id, family_B, T1, family_R) |>
    head()
}

## -----------------------------------------------------------------------------
multi_risques <- result_complete |>
  mutate(
    nb_risques = (R1_norm > 60) + (R2_norm > 60) + (R3_norm > 60)
  ) |>
  filter(nb_risques >= 2) |>
  arrange(desc(nb_risques))

cat("Parcelles à risques multiples (≥2) :", nrow(multi_risques), "\n")

# Détail des risques
if(nrow(multi_risques) > 0) {
  multi_risques |>
    st_drop_geometry() |>
    select(parcel_id, R1_norm, R2_norm, R3_norm, nb_risques, family_R) |>
    head()
}

## -----------------------------------------------------------------------------
services_climat <- result_complete |>
  filter(A1 > 70, A2 > 70) |>
  arrange(desc(family_A))

cat("Parcelles à fort potentiel climatique :", nrow(services_climat), "\n")

if(nrow(services_climat) > 0) {
  services_climat |>
    st_drop_geometry() |>
    select(parcel_id, A1, A2, family_A) |>
    head()
}

## ----fig.height=8-------------------------------------------------------------
library(patchwork)

p_bio <- plot_indicators_map(result_complete, indicator = "family_B",
                              palette = "Greens", title = "Biodiversité (B)")
p_risk <- plot_indicators_map(result_complete, indicator = "family_R",
                               palette = "YlOrRd", title = "Risques (R)")
p_temp <- plot_indicators_map(result_complete, indicator = "T1",
                               palette = "Blues", title = "Ancienneté (T1)")
p_air <- plot_indicators_map(result_complete, indicator = "family_A",
                              palette = "viridis", title = "Air & Climat (A)")

(p_bio + p_risk) / (p_temp + p_air)

## -----------------------------------------------------------------------------
# Résumé des 10 nouveaux indicateurs v0.3.0
summary_table <- result_complete |>
  st_drop_geometry() |>
  select(parcel_id,
         # Biodiversité
         B1, B2, B3, family_B,
         # Risques
         R1, R2, R3, family_R,
         # Temporel
         T1, T2, family_T,
         # Air
         A1, A2, family_A) |>
  head(5)

summary_table

