## ----setup, include = FALSE---------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  warning = FALSE,
  message = FALSE
)

## -----------------------------------------------------------------------------
library(nemeton)

## -----------------------------------------------------------------------------
# Afficher la langue actuelle
Sys.getenv("LANG")

## -----------------------------------------------------------------------------
# Passer en français
nemeton_set_language("fr")

# Switch to English
nemeton_set_language("en")

## ----eval = FALSE-------------------------------------------------------------
# # La langue est stockée dans une option
# getOption("nemeton.lang")
# # [1] "fr"  ou "en"

## ----eval = FALSE-------------------------------------------------------------
# nemeton_set_language("fr")
#
# # Erreur si données manquantes
# nemeton_compute(NULL, NULL, "carbon")
# # Erreur : Les données 'data' doivent être un objet sf

## ----eval = FALSE-------------------------------------------------------------
# nemeton_set_language("en")
#
# # Error with missing data
# nemeton_compute(NULL, NULL, "carbon")
# # Error: 'data' must be an sf object

## ----eval = FALSE-------------------------------------------------------------
# # En français
# nemeton_set_language("fr")
# get_family_name("C")
# # [1] "Carbone & Vitalité"
#
# get_family_name("W")
# # [1] "Eau"
#
# # In English
# nemeton_set_language("en")
# get_family_name("C")
# # [1] "Carbon & Vitality"
#
# get_family_name("W")
# # [1] "Water Regulation"

## ----eval = FALSE-------------------------------------------------------------
# # Définir le français au début du script
# nemeton_set_language("fr")
#
# # Tous les appels suivants utilisent le français
# results <- nemeton_compute(...)
# normalized <- normalize_indicators(...)
# plot_indicators_map(...)

## ----eval = FALSE-------------------------------------------------------------
# ?nemeton_compute
# ?plot_indicators_map

## ----eval = FALSE-------------------------------------------------------------
# # Exemple de structure interne
# messages <- list(
#   fr = list(
#     error_no_data = "Les données 'data' doivent être un objet sf",
#     info_computing = "Calcul de {n} indicateurs..."
#   ),
#   en = list(
#     error_no_data = "'data' must be an sf object",
#     info_computing = "Computing {n} indicators..."
#   )
# )

## ----eval = FALSE-------------------------------------------------------------
# # ===== VERSION FRANÇAISE =====
# nemeton_set_language("fr")
#
# data(massif_demo_units)
# layers <- massif_demo_layers()
#
# results <- nemeton_compute(
#   massif_demo_units,
#   layers,
#   indicators = "carbon"
# )
# # ℹ Calcul de 1 indicateurs...
# # ✔ 1/1 indicateurs calculés
#
# plot_indicators_map(
#   results,
#   indicators = "carbon",
#   title = "Stock de carbone",
#   legend_title = "Mg C/parcel"
# )
#
# # ===== ENGLISH VERSION =====
# nemeton_set_language("en")
#
# data(massif_demo_units)
# layers <- massif_demo_layers()
#
# results <- nemeton_compute(
#   massif_demo_units,
#   layers,
#   indicators = "carbon"
# )
# # ℹ Computing 1 indicators...
# # ✔ 1/1 indicators computed
#
# plot_indicators_map(
#   results,
#   indicators = "carbon",
#   title = "Carbon Stock",
#   legend_title = "Mg C/parcel"
# )

## -----------------------------------------------------------------------------
sessionInfo()
