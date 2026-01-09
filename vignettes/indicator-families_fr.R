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
# # B1 - Protection réglementaire (% surface en zones protégées)
# biodiversity_protection <- indicator_biodiversity_protection(
#   units,
#   protected_areas = protected_areas,  # sf object ZNIEFF, Natura2000
#   source = "local"  # ou "wfs" pour téléchargement automatique
# )
#
# # B2 - Diversité structurelle (Shannon)
# biodiversity_structure <- indicator_biodiversity_structure(
#   units,
#   strata_field = "strata",          # Strates (Emergent, Dominant, etc.)
#   age_class_field = "age_class",    # Classes d'âge
#   species_field = "species",        # Essences
#   method = "shannon",               # ou "simpson"
#   weights = c(strata = 0.4, age = 0.3, species = 0.3)
# )
#
# # B3 - Connectivité écologique (distance corridors)
# biodiversity_connectivity <- indicator_biodiversity_connectivity(
#   units,
#   corridors = corridors_sf,  # Trames vertes et bleues
#   distance_method = "edge",  # ou "centroid"
#   max_distance = 3000        # Distance max en mètres
# )

## ----eval = FALSE-------------------------------------------------------------
# # R1 - Risque incendie (pente + essence + climat)
# risk_fire <- indicator_risk_fire(
#   units,
#   dem = dem_raster,              # Modèle numérique de terrain
#   species_field = "species",     # Champ essence
#   climate = climate_data         # Température, précipitations
# )
#
# # R2 - Vulnérabilité tempête (hauteur + densité + exposition)
# risk_storm <- indicator_risk_storm(
#   units,
#   dem = dem_raster,
#   height_field = "height",       # Hauteur dominante (m)
#   density_field = "density"      # Densité (0-1)
# )
#
# # R3 - Stress hydrique (TWI + climat + essences)
# risk_drought <- indicator_risk_drought(
#   units,
#   twi_field = "W3",              # Topographic Wetness Index
#   climate = climate_data,
#   species_field = "species"
# )

## ----eval = FALSE-------------------------------------------------------------
# # T1 - Ancienneté des peuplements (années)
# temporal_age <- indicator_temporal_age(
#   units,
#   age_field = "age",                    # Âge actuel
#   establishment_year_field = "planted"  # Année plantation (optionnel)
# )
#
# # T2 - Changements d'occupation du sol (%/an)
# temporal_change <- indicator_temporal_change(
#   units,
#   land_cover_early = lc_1990_raster,
#   land_cover_late = lc_2020_raster,
#   years_elapsed = 30,
#   interpretation = "stability"  # ou "dynamism"
# )

## ----eval = FALSE-------------------------------------------------------------
# # A1 - Couverture arborée dans buffer 1km (%)
# air_coverage <- indicator_air_coverage(
#   units,
#   land_cover = land_cover_raster,
#   buffer_radius = 1000  # Rayon en mètres
# )
#
# # A2 - Qualité de l'air (indice ou proxy distance)
# air_quality <- indicator_air_quality(
#   units,
#   roads = roads_sf,           # Réseau routier (optionnel)
#   urban_areas = urban_sf,     # Zones urbaines (optionnel)
#   atmo_data = NULL,           # Données ATMO si disponibles
#   method = "proxy"            # "atmo" si données disponibles
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
# # Calculer les corrélations entre indices de familles
# corr_matrix <- compute_family_correlations(
#   units,
#   families = NULL,      # Auto-détection des family_*
#   method = "pearson"    # ou "spearman", "kendall"
# )
#
# # Visualiser les corrélations
# plot_correlation_matrix(
#   corr_matrix,
#   method = "circle",    # ou "square", "number", "color"
#   palette = "RdBu",     # Rouge=synergies, Bleu=conflits
#   title = "Synergies et conflits entre services écosystémiques"
# )

## ----eval = FALSE-------------------------------------------------------------
# # Identifier parcelles excellentes sur plusieurs familles
# hotspots <- identify_hotspots(
#   units,
#   threshold = 80,      # Top 20% pour chaque famille
#   min_families = 3     # Au moins 3 familles élevées
# )
#
# # Filtrer les hotspots
# hotspot_parcels <- hotspots[hotspots$is_hotspot, ]
#
# # Afficher détails
# hotspot_parcels[, c("parcel_id", "hotspot_count", "hotspot_families")]
#
# # Cartographier
# plot_indicators_map(
#   hotspots,
#   indicator = "hotspot_count",
#   palette = "YlOrRd",
#   title = "Nombre de familles à haute valeur"
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
