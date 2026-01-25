# Quickstart: Tutorial 10 - Classification d'Essences

## Aperçu rapide

Ce tutoriel permet de classifier les essences forestières au niveau couronne en fusionnant LiDAR HD et orthophotos IRC.

## Prérequis

- Tutorial 01 (cache données)
- Tutorial 07 (couronnes segmentées)
- R >= 4.1.0

## Packages essentiels

```r
install.packages(c("sf", "terra", "exactextractr", "dplyr", "ggplot2"))
install.packages(c("ranger", "xgboost", "blockCV"))
```

## Pipeline résumé

```r
# 1. Charger données
crowns <- st_read("arbres_segmentes.gpkg")
irc <- rast("orthophoto_irc.tif")
labels <- read.csv("inventaire_arbres.csv")

# 2. Calculer features
features_lidar <- extract_lidar_features(crowns, las_catalog)
features_irc <- exact_extract(irc, crowns, c("mean", "sd"))

# 3. Assembler dataset
training_data <- cbind(crowns, features_lidar, features_irc, labels)

# 4. Validation spatiale
spatial_folds <- cv_spatial(training_data, size = 200, k = 5)

# 5. Entraîner modèle
model <- ranger(species ~ ., data = training_data, probability = TRUE)

# 6. Prédire et cartographier
crowns$pred <- predict(model, crowns)$predictions
st_write(crowns, "crowns_classified.gpkg")
```

## Durée

~3h30 (210 minutes)

## Sortie principale

`result_classification/crowns_classified.gpkg` avec :
- `pred_class` : essence prédite
- `pred_prob` : probabilité de la classe
- `uncertain` : flag si proba < 50%
