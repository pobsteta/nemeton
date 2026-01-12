## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ----eval=FALSE---------------------------------------------------------------
# # Packages de base
# install.packages(c("sf", "terra", "ggplot2", "dplyr"))
# 
# # Packages tutoriels
# install.packages(c("learnr", "gradethis", "rappdirs"))
# 
# # Packages acquisition IGN
# install.packages("happign")
# 
# # Packages LiDAR (Tutorial 02)
# install.packages("lidR")
# 
# # Packages visualisation (Tutorial 06)
# install.packages(c("leaflet", "corrplot", "patchwork", "fmsb"))
# 
# # Package nemeton
# remotes::install_github("pobsteta/nemeton")

## ----eval=FALSE---------------------------------------------------------------
# # Lister les tutoriels disponibles
# learnr::available_tutorials("nemeton")
# 
# # Lancer un tutoriel spécifique
# learnr::run_tutorial("01-acquisition", package = "nemeton")

## ----eval=FALSE---------------------------------------------------------------
# # Localisation du cache
# rappdirs::user_data_dir("nemeton")

## ----eval=FALSE---------------------------------------------------------------
# cache_dir <- rappdirs::user_data_dir("nemeton")
# unlink(file.path(cache_dir, "tutorial_data"), recursive = TRUE)

## ----eval=FALSE---------------------------------------------------------------
# # Vérifier l'installation
# packageVersion("nemeton")
# 
# # Réinstaller
# remotes::install_github("pobsteta/nemeton", force = TRUE)

## ----eval=FALSE---------------------------------------------------------------
# # Augmenter la mémoire
# options(future.globals.maxSize = +Inf)

