## ----setup, include = FALSE---------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  warning = FALSE,
  message = FALSE
)

## -----------------------------------------------------------------------------
library(nemeton)

## ----eval = FALSE-------------------------------------------------------------
# # Exemple : un raster local dont chaque pixel porte un score 1-5
# layers <- nemeton_layers(
#   rasters = list(soil = "/chemin/vers/stations.tif")
# )
# f1 <- indicateur_f1_fertilite(
#   units         = massif_demo_units,
#   layers        = layers,
#   soil_layer    = "soil",
#   fertility_col = "fertility"     # nom du champ fertilité dans la couche
# )

## ----eval = FALSE-------------------------------------------------------------
# # Aucune couche à préparer — load_raster_source() fait tout en interne.
# # Non exécuté dans cette vignette : dépend d'un accès réseau à ISRIC.
# f1 <- indicateur_f1_fertilite(
#   units  = massif_demo_units,
#   source = "soilgrids"
# )

## ----eval = FALSE-------------------------------------------------------------
# # L'utilisateur a téléchargé le RRP de son département au format GPKG
# rrp <- sf::st_read("/chemin/vers/rrp_loiret.gpkg")
# 
# layers <- nemeton_layers(vectors = list(soil = rrp))
# 
# f1 <- indicateur_f1_fertilite(
#   units         = massif_demo_units,
#   layers        = layers,
#   source        = "gissol",
#   rpf_code_col  = "UTSDom"        # adapte au nom de colonne du RRP
# )

## -----------------------------------------------------------------------------
tbl <- read_uts_fertility_table()
head(tbl[, c("rpf_code", "rpf_name", "fertility_class",
             "fertility_score", "forest_note")], 5)

## -----------------------------------------------------------------------------
cal_path <- system.file("extdata", "uts_fertilite_rmqs_calibration.csv",
                         package = "nemeton")
cal <- utils::read.csv(cal_path, stringsAsFactors = FALSE)

# UTS où l'écart expert vs CEC observée dépasse 20 points
outliers <- cal[cal$flag_outlier, c("rpf_code", "n_sites",
                                      "cec_median", "observed_score",
                                      "expert_score", "delta")]
outliers[order(outliers$delta), ]

