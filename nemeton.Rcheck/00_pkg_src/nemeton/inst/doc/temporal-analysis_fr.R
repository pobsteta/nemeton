## ----setup, include = FALSE---------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  fig.width = 8,
  fig.height = 5,
  warning = FALSE,
  message = FALSE
)

## -----------------------------------------------------------------------------
library(nemeton)
library(ggplot2)
library(dplyr)

## ----eval = FALSE-------------------------------------------------------------
# # Exemple de structure pour 3 périodes
# temporal_data <- nemeton_temporal(
#   periods = list(
#     "2015" = list(
#       units = units_2015,
#       layers = layers_2015
#     ),
#     "2020" = list(
#       units = units_2020,
#       layers = layers_2020
#     ),
#     "2025" = list(
#       units = units_2025,
#       layers = layers_2025
#     )
#   ),
#   unit_id = "parcel_id"  # Colonne identifiant les parcelles
# )

## ----eval = FALSE-------------------------------------------------------------
# # Charger les données de base
# data(massif_demo_units)
# layers_2020 <- massif_demo_layers()
# 
# # Simuler des données pour 2015 et 2025 (pour la démo)
# # En pratique, vous chargerez vos vrais datasets historiques
# 
# # Créer le dataset temporel
# temporal <- nemeton_temporal(
#   periods = list(
#     "2015" = list(units = massif_demo_units, layers = layers_2020),
#     "2020" = list(units = massif_demo_units, layers = layers_2020),
#     "2025" = list(units = massif_demo_units, layers = layers_2020)
#   ),
#   unit_id = "parcel_id"
# )
# 
# print(temporal)

## ----eval = FALSE-------------------------------------------------------------
# # Calculer automatiquement pour toutes les périodes
# temporal_results <- nemeton_compute(
#   temporal,
#   indicators = c("carbon", "biodiversity", "water")
# )
# 
# # Afficher la structure
# summary(temporal_results)

## ----eval = FALSE-------------------------------------------------------------
# # Calculer le taux de changement annuel (%)
# change_rates <- calculate_change_rate(
#   temporal_results,
#   indicators = c("carbon", "biodiversity", "water"),
#   period_start = "2015",
#   period_end = "2025"
# )
# 
# # Afficher les taux de changement
# head(change_rates[, c("parcel_id", "carbon_rate", "biodiversity_rate", "water_rate")])

## ----eval = FALSE-------------------------------------------------------------
# # Calculer les différences entre 2020 et 2025
# differences <- calculate_change_rate(
#   temporal_results,
#   indicators = "carbon",
#   period_start = "2020",
#   period_end = "2025",
#   method = "absolute"  # Différence absolue au lieu de taux
# )

## ----eval = FALSE-------------------------------------------------------------
# # Tendance pour une parcelle spécifique
# plot_temporal_trend(
#   temporal_results,
#   unit_id = "P01",
#   indicators = c("carbon", "biodiversity", "water"),
#   title = "Évolution des indicateurs - Parcelle P01"
# )

## ----eval = FALSE-------------------------------------------------------------
# # Heatmap de tous les indicateurs sur toutes les périodes
# plot_temporal_heatmap(
#   temporal_results,
#   indicators = c("carbon", "biodiversity", "water", "fragmentation"),
#   title = "Heatmap temporelle - Tous indicateurs"
# )

## ----eval = FALSE-------------------------------------------------------------
# # Carte montrant les changements de carbone 2015→2025
# plot_difference_map(
#   temporal_results,
#   indicator = "carbon",
#   period_start = "2015",
#   period_end = "2025",
#   title = "Changement de stock carbone (2015-2025)",
#   legend_title = "Δ tC/ha"
# )

## ----eval = FALSE-------------------------------------------------------------
# # 1. Définir les périodes
# # - Avant intervention (2018)
# # - Après intervention (2020)
# # - Suivi à 5 ans (2025)
# 
# temporal_intervention <- nemeton_temporal(
#   periods = list(
#     "avant_2018" = list(units = units_avant, layers = layers_avant),
#     "apres_2020" = list(units = units_apres, layers = layers_apres),
#     "suivi_2025" = list(units = units_suivi, layers = layers_suivi)
#   ),
#   unit_id = "parcel_id"
# )
# 
# # 2. Calculer indicateurs
# results <- nemeton_compute(
#   temporal_intervention,
#   indicators = c("carbon", "biodiversity", "water", "fragmentation")
# )
# 
# # 3. Analyser les impacts
# impact_2020 <- calculate_change_rate(
#   results,
#   period_start = "avant_2018",
#   period_end = "apres_2020",
#   indicators = c("carbon", "biodiversity")
# )
# 
# recovery_2025 <- calculate_change_rate(
#   results,
#   period_start = "apres_2020",
#   period_end = "suivi_2025",
#   indicators = c("carbon", "biodiversity")
# )
# 
# # 4. Visualiser trajectoire
# plot_temporal_trend(
#   results,
#   unit_id = "PARCEL_INTERV_01",
#   indicators = c("carbon", "biodiversity"),
#   title = "Trajectoire post-intervention"
# )

## ----eval = FALSE-------------------------------------------------------------
# # Calculer taux de changement
# rates <- calculate_change_rate(
#   temporal_results,
#   indicators = "carbon",
#   period_start = "2015",
#   period_end = "2025"
# )
# 
# # Filtrer les parcelles avec forte dynamique
# high_change <- rates %>%
#   filter(abs(carbon_rate) > 2.0)  # > ±2% par an
# 
# # Visualiser sur carte
# plot_indicators_map(
#   high_change,
#   indicators = "carbon_rate",
#   palette = "RdBu",
#   title = "Parcelles à forte dynamique carbone",
#   legend_title = "Taux (%/an)"
# )

## ----eval = FALSE-------------------------------------------------------------
# # Classer les trajectoires
# rates <- rates %>%
#   mutate(
#     trajectory = case_when(
#       carbon_rate > 1.0 ~ "Forte augmentation",
#       carbon_rate > 0.2 ~ "Augmentation modérée",
#       abs(carbon_rate) <= 0.2 ~ "Stable",
#       carbon_rate > -1.0 ~ "Diminution modérée",
#       TRUE ~ "Forte diminution"
#     )
#   )
# 
# # Compter les trajectoires
# table(rates$trajectory)

## ----eval = FALSE-------------------------------------------------------------
# # Normaliser les indicateurs de chaque période séparément
# temporal_norm <- normalize_indicators(
#   temporal_results,
#   indicators = c("carbon", "biodiversity", "water"),
#   method = "minmax",
#   by_period = TRUE  # Normalisation intra-période
# )

## ----eval = FALSE-------------------------------------------------------------
# # Normaliser sur toutes les périodes ensemble
# temporal_norm_global <- normalize_indicators(
#   temporal_results,
#   indicators = c("carbon", "biodiversity", "water"),
#   method = "minmax",
#   by_period = FALSE  # Normalisation sur toutes les données
# )

## ----eval = FALSE-------------------------------------------------------------
# # Créer indice composite pour chaque période
# composite_temporal <- create_composite_index(
#   temporal_norm,
#   indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
#   weights = c(0.4, 0.3, 0.3),
#   name = "ecosystem_quality"
# )
# 
# # Analyser l'évolution de l'indice
# plot_temporal_trend(
#   composite_temporal,
#   unit_id = "P01",
#   indicators = "ecosystem_quality",
#   title = "Évolution de la qualité écosystémique"
# )

## ----eval = FALSE-------------------------------------------------------------
# # Créer tableau récapitulatif
# summary_table <- temporal_results %>%
#   group_by(period) %>%
#   summarise(
#     carbon_mean = mean(carbon, na.rm = TRUE),
#     carbon_sd = sd(carbon, na.rm = TRUE),
#     biodiv_mean = mean(biodiversity, na.rm = TRUE),
#     biodiv_sd = sd(biodiversity, na.rm = TRUE)
#   )
# 
# print(summary_table)

## ----eval = FALSE-------------------------------------------------------------
# # Export des taux de changement
# write.csv(
#   change_rates,
#   "results/temporal_change_rates.csv",
#   row.names = FALSE
# )
# 
# # Export cartes temporelles
# for (period in c("2015", "2020", "2025")) {
#   p <- plot_indicators_map(
#     temporal_results[[period]],
#     indicators = "carbon",
#     title = paste("Stock carbone -", period)
#   )
#   ggsave(
#     paste0("results/carbon_map_", period, ".png"),
#     p,
#     width = 8,
#     height = 6
#   )
# }

## -----------------------------------------------------------------------------
sessionInfo()

