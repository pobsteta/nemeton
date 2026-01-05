## ----setup, include = FALSE---------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  fig.width = 7,
  fig.height = 5,
  warning = FALSE,
  message = FALSE
)

## -----------------------------------------------------------------------------
library(nemeton)
library(ggplot2)

## ----eval = FALSE-------------------------------------------------------------
# # C1 - Stock de biomasse aérienne (tC/ha)
# carbon_biomass <- nemeton_compute(
#   units,
#   layers,
#   indicators = "carbon_biomass"
# )
# 
# # C2 - NDVI et tendance vitalité
# carbon_ndvi <- nemeton_compute(
#   units,
#   layers,
#   indicators = "carbon_ndvi"
# )

## ----eval = FALSE-------------------------------------------------------------
# # W1 - Densité réseau hydrographique (m/ha)
# water_network <- nemeton_compute(
#   units,
#   layers,
#   indicators = "water_network"
# )
# 
# # W2 - Surface en zones humides (%)
# water_wetlands <- nemeton_compute(
#   units,
#   layers,
#   indicators = "water_wetlands"
# )
# 
# # W3 - Topographic Wetness Index
# water_twi <- nemeton_compute(
#   units,
#   layers,
#   indicators = "water_twi"
# )

## ----eval = FALSE-------------------------------------------------------------
# # F1 - Classe de fertilité (BD Sol)
# soil_fertility <- nemeton_compute(
#   units,
#   layers,
#   indicators = "soil_fertility"
# )
# 
# # F2 - Risque d'érosion (pente × couverture)
# soil_erosion <- nemeton_compute(
#   units,
#   layers,
#   indicators = "soil_erosion"
# )

## ----eval = FALSE-------------------------------------------------------------
# # L1 - Fragmentation (nb patches / surface moyenne)
# landscape_frag <- nemeton_compute(
#   units,
#   layers,
#   indicators = "landscape_fragmentation"
# )
# 
# # L2 - Ratio lisière / surface
# landscape_edge <- nemeton_compute(
#   units,
#   layers,
#   indicators = "landscape_edge"
# )

## ----eval = FALSE-------------------------------------------------------------
# # Les indicateurs bruts suivent le pattern : famille_nom
# # Exemples :
# carbon_biomass    # Famille C
# water_network     # Famille W
# soil_fertility    # Famille F
# 
# # Les indicateurs normalisés ajoutent le suffixe _norm :
# carbon_biomass_norm
# water_network_norm

## ----eval = FALSE-------------------------------------------------------------
# # Détecter la famille d'un indicateur
# detect_indicator_family("carbon_biomass")
# # [1] "C"
# 
# detect_indicator_family("water_twi_norm")
# # [1] "W"
# 
# # Obtenir le nom complet de la famille
# get_family_name("C")
# # [1] "Carbone & Vitalité"
# 
# get_family_name("W", lang = "en")
# # [1] "Water Regulation"

## ----eval = FALSE-------------------------------------------------------------
# # Charger les données
# data(massif_demo_units)
# layers <- massif_demo_layers()
# 
# # Calculer indicateurs des familles C et W
# results <- nemeton_compute(
#   massif_demo_units,
#   layers,
#   indicators = c("carbon", "water", "biodiversity")
# )
# 
# # Normaliser tous les indicateurs
# normalized <- normalize_indicators(
#   results,
#   indicators = c("carbon", "water", "biodiversity"),
#   method = "minmax"
# )
# 
# # Les colonnes normalisées ont le suffixe _norm
# names(normalized)

## ----eval = FALSE-------------------------------------------------------------
# # Exemple fictif (nécessite indicateurs C1 et C2)
# # Indice famille C (Carbone)
# score_carbon <- create_family_index(
#   normalized,
#   family = "C",
#   name = "score_carbon"
# )
# 
# # Indice famille W (Eau)
# score_water <- create_family_index(
#   normalized,
#   family = "W",
#   name = "score_water"
# )

## ----eval = FALSE-------------------------------------------------------------
# # Créer scores pour chaque famille
# families <- c("C", "W", "F", "L")
# for (fam in families) {
#   normalized <- create_family_index(
#     normalized,
#     family = fam,
#     name = paste0("score_", tolower(fam))
#   )
# }
# 
# # Radar avec 4 familles
# nemeton_radar(
#   normalized,
#   unit_id = "P01",
#   indicators = c("score_c", "score_w", "score_f", "score_l"),
#   title = "Profil multi-famille - Parcelle P01"
# )

## ----eval = FALSE-------------------------------------------------------------
# # Visualiser les scores de famille
# plot_indicators_map(
#   normalized,
#   indicators = c("score_c", "score_w", "score_f"),
#   palette = "viridis",
#   facet = TRUE,
#   ncol = 3,
#   title = "Scores par famille"
# )

## ----eval = FALSE-------------------------------------------------------------
# # 1. Charger données
# data(massif_demo_units)
# layers <- massif_demo_layers()
# 
# # 2. Calculer indicateurs de 3 familles
# results <- nemeton_compute(
#   massif_demo_units,
#   layers,
#   indicators = c(
#     "carbon",        # Famille C
#     "water",         # Famille W
#     "biodiversity"   # Famille B
#   )
# )
# 
# # 3. Normaliser
# normalized <- normalize_indicators(
#   results,
#   indicators = c("carbon", "water", "biodiversity"),
#   method = "minmax"
# )
# 
# # 4. Créer indices par famille
# normalized <- create_family_index(normalized, family = "C", name = "score_carbon")
# normalized <- create_family_index(normalized, family = "W", name = "score_water")
# normalized <- create_family_index(normalized, family = "B", name = "score_bio")
# 
# # 5. Indice global multi-famille
# global_index <- create_composite_index(
#   normalized,
#   indicators = c("score_carbon", "score_water", "score_bio"),
#   weights = c(0.4, 0.3, 0.3),
#   name = "ecosystem_services_index"
# )
# 
# # 6. Visualisation
# plot_indicators_map(
#   global_index,
#   indicators = "ecosystem_services_index",
#   palette = "RdYlGn",
#   title = "Indice global de services écosystémiques",
#   legend_title = "Score (0-100)"
# )

## ----eval = FALSE-------------------------------------------------------------
# # Lister tous les indicateurs disponibles
# list_indicators()
# 
# # Filtrer par famille
# list_indicators(family = "C")
# list_indicators(family = "W")

## -----------------------------------------------------------------------------
sessionInfo()

