# nemeton <img src="man/figures/logo.png" align="right" height="139" alt="" />

<!-- badges: start -->
[![R-CMD-check](https://github.com/pobsteta/nemeton/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/pobsteta/nemeton/actions/workflows/R-CMD-check.yaml)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
<!-- badges: end -->

> **Analyse systémique de territoires forestiers selon la méthode Nemeton**

`nemeton` est un package R pour l'analyse intégrée d'écosystèmes forestiers à partir de données spatiales ouvertes. Il implémente la méthode Nemeton pour calculer, normaliser et visualiser des indicateurs biophysiques essentiels à la gestion forestière durable.

## ✨ Fonctionnalités principales

- 🌳 **5 indicateurs biophysiques** : carbone, biodiversité, eau, fragmentation, accessibilité
- 📊 **Normalisation multi-méthodes** : min-max, z-score, quantiles
- 🎯 **Indices composites** : agrégation pondérée, moyenne géométrique, facteur limitant
- 🗺️ **Visualisations** : cartes thématiques, comparaisons, changements, graphiques radar
- 🔄 **Workflow intégré** : de la donnée brute à la carte finale
- 📦 **Interopérable** : compatible sf, terra, ggplot2, tidyverse

## 📋 Prérequis

- R ≥ 4.1.0
- Packages spatiaux : `sf`, `terra`, `exactextractr`
- Visualisation : `ggplot2`, `tidyr`

## 🚀 Installation

```r
# Depuis GitHub (version développement)
# install.packages("remotes")
remotes::install_github("pobsteta/nemeton")
```

## 🎯 Quick Start

### Avec le dataset de démonstration (recommandé pour débuter)

```r
library(nemeton)

# Charger le dataset de démonstration (136 ha, 20 parcelles forestières)
data(massif_demo_units)
layers <- massif_demo_layers()

# Workflow complet en 5 lignes
results <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = "all",
  forest_values = c(1, 2, 3)  # Classes forestières pour fragmentation
)
normalized <- normalize_indicators(results, method = "minmax")
health <- create_composite_index(
  normalized,
  indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
  weights = c(0.4, 0.4, 0.2),
  name = "ecosystem_health"
)
plot_indicators_map(health, indicators = "ecosystem_health", palette = "RdYlGn")
```

### Avec vos propres données

```r
library(nemeton)
library(sf)

# 1️⃣ Créer les unités d'analyse spatiales
units <- nemeton_units(
  "parcelles.gpkg",
  metadata = list(
    site_name = "Forêt de Fontainebleau",
    year = 2024,
    source = "IGN BD Forêt v2"
  )
)

# 2️⃣ Créer le catalogue de couches spatiales
layers <- nemeton_layers(
  rasters = list(
    biomass = "data/biomass_agb.tif",      # Biomasse aérienne (Mg/ha)
    dem = "data/ign_mnt_25m.tif",          # MNT 25m
    landcover = "data/oso_landcover.tif"   # Occupation du sol
  ),
  vectors = list(
    roads = "data/bdtopo_routes.gpkg",     # Routes
    water = "data/bdtopo_hydro.gpkg"       # Cours d'eau
  )
)

# 3️⃣ Calculer les indicateurs (avec préprocessing automatique)
results <- nemeton_compute(
  units,
  layers,
  indicators = "all",  # Tous les indicateurs
  preprocess = TRUE    # Harmonisation CRS + crop automatique
)

# 4️⃣ Normaliser les valeurs (échelle 0-100)
normalized <- normalize_indicators(
  results,
  method = "minmax"
)

# 5️⃣ Créer un indice de santé écosystémique
health_index <- create_composite_index(
  normalized,
  indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
  weights = c(0.4, 0.4, 0.2),
  name = "ecosystem_health"
)

# 6️⃣ Visualiser sur une carte
plot_indicators_map(
  health_index,
  indicators = "ecosystem_health",
  palette = "RdYlGn",
  title = "Indice de Santé Écosystémique"
)

# 7️⃣ Sauvegarder
ggsave("ecosystem_health.png", width = 10, height = 8, dpi = 300)
```

## 📦 Dataset de Démonstration

Le package inclut `massif_demo`, un dataset synthétique représentant un massif forestier de 136 ha avec 20 parcelles.

### Contenu

```r
# Charger les unités spatiales (parcelles)
data(massif_demo_units)
print(massif_demo_units)
# 20 parcelles forestières en Lambert-93 (EPSG:2154)

# Charger les couches environnementales
layers <- massif_demo_layers()
summary(layers)
# 4 rasters : biomass, dem, landcover, species_richness
# 2 vecteurs : roads, water
```

### Caractéristiques

- **20 parcelles forestières** (surface totale : 136 ha)
- **Projection** : Lambert-93 (EPSG:2154)
- **Résolution rasters** : 25m
- **Données incluses** :
  - `biomass` : Biomasse aérienne (Mg/ha)
  - `dem` : Modèle Numérique de Terrain (m)
  - `landcover` : Occupation du sol (classes 1-5)
  - `species_richness` : Richesse spécifique (nb espèces)
  - `roads` : Réseau routier (5 routes)
  - `water` : Cours d'eau (3 rivières)

### Exemples d'utilisation

```r
library(nemeton)

# 1. Analyse complète
data(massif_demo_units)
layers <- massif_demo_layers()
results <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = "all",
  forest_values = c(1, 2, 3)
)

# 2. Visualiser les indicateurs bruts
plot_indicators_map(
  results,
  indicators = c("carbon", "biodiversity", "water"),
  palette = "viridis",
  facet = TRUE,
  ncol = 3
)

# 3. Créer un indice composite
normalized <- normalize_indicators(results, method = "minmax")
health <- create_composite_index(
  normalized,
  indicators = c("carbon_norm", "biodiversity_norm", "water_norm", "fragmentation_norm"),
  weights = c(0.3, 0.3, 0.2, 0.2),
  name = "ecosystem_health"
)

# 4. Visualiser l'indice
plot_indicators_map(
  health,
  indicators = "ecosystem_health",
  palette = "RdYlGn",
  title = "Santé Écosystémique - Massif Demo"
)
```

## 📚 Indicateurs disponibles

### 🌲 Indicateur Carbone
Stock de carbone forestier à partir de biomasse aérienne.

```r
# Exemple avec massif_demo
data(massif_demo_units)
layers <- massif_demo_layers()
carbon <- indicator_carbon(
  massif_demo_units,
  layers,
  biomass_layer = "biomass",
  conversion_factor = 0.47  # IPCC default
)
summary(carbon)  # Stock de carbone en Mg C/ha
```

**Données requises** : Raster de biomasse (tonnes/ha ou Mg/ha)
**Source recommandée** : Copernicus Biomass, GEDI, ou modèles locaux

### 🦋 Indicateur Biodiversité
Indices de diversité (richesse, Shannon, Simpson).

```r
# Exemple avec massif_demo
biodiv <- indicator_biodiversity(
  massif_demo_units,
  layers,
  richness_layer = "species_richness",
  index = "richness"
)
summary(biodiv)  # Nombre moyen d'espèces par parcelle
```

**Données requises** : Raster de richesse spécifique ou indices pré-calculés
**Source recommandée** : INPN, GBIF, inventaires forestiers

### 💧 Indicateur Eau
Régulation hydrique (TWI + proximité cours d'eau).

```r
# Exemple avec massif_demo
water <- indicator_water(
  massif_demo_units,
  layers,
  dem_layer = "dem",
  water_layer = "water",
  weights = c(0.6, 0.4)
)
summary(water)  # Indice 0-1 (0 = faible, 1 = fort)
```

**Données requises** : MNT (DEM) + vecteur réseau hydrographique
**Source recommandée** : IGN RGE ALTI, BD TOPO Hydrographie

### 🌿 Indicateur Fragmentation
Fragmentation forestière (couverture, connectivité).

```r
# Exemple avec massif_demo
frag <- indicator_fragmentation(
  massif_demo_units,
  layers,
  landcover_layer = "landcover",
  forest_values = c(1, 2, 3)  # Classes forestières
)
summary(frag)  # Pourcentage de couverture forestière
```

**Données requises** : Raster d'occupation du sol
**Source recommandée** : OSO (Theia), Corine Land Cover

### 🛤️ Indicateur Accessibilité
Accessibilité humaine (distance routes/sentiers).

```r
# Exemple avec massif_demo
access <- indicator_accessibility(
  massif_demo_units,
  layers,
  roads_layer = "roads",
  invert = FALSE  # TRUE pour indice de sauvagerie
)
summary(access)  # Indice 0-1 (0 = inaccessible, 1 = très accessible)
```

**Données requises** : Vecteurs routes et sentiers
**Source recommandée** : BD TOPO Routes, OpenStreetMap

## 🔄 Workflow complet

### Exemple 1 : Avec massif_demo (Débutants)

```r
library(nemeton)

# 1️⃣ Charger les données de démonstration
data(massif_demo_units)
layers <- massif_demo_layers()

# 2️⃣ Calculer tous les indicateurs
results <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = "all",
  forest_values = c(1, 2, 3),  # Classes forestières pour fragmentation
  progress = TRUE
)

# 3️⃣ Normaliser (échelle 0-100)
normalized <- normalize_indicators(
  results,
  method = "minmax"
)

# 4️⃣ Créer des indices composites
ecosystem_health <- create_composite_index(
  normalized,
  indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
  weights = c(0.4, 0.4, 0.2),
  name = "ecosystem_health"
)

wilderness_index <- normalized %>%
  invert_indicator(indicators = "accessibility_norm", suffix = "_wilderness") %>%
  create_composite_index(
    indicators = c("biodiversity_norm", "accessibility_norm_wilderness"),
    weights = c(0.6, 0.4),
    name = "wilderness"
  )

# 5️⃣ Visualiser
plot_indicators_map(
  ecosystem_health,
  indicators = "ecosystem_health",
  palette = "RdYlGn",
  title = "Santé Écosystémique"
)

plot_indicators_map(
  wilderness_index,
  indicators = "wilderness",
  palette = "Greens",
  title = "Indice de Sauvagerie"
)
```

### Exemple 2 : Avec vos propres données

```r
library(nemeton)
library(sf)

# 1️⃣ Charger vos parcelles forestières
parcelles <- st_read("mes_parcelles.gpkg")

# Créer l'objet nemeton_units
units <- nemeton_units(
  parcelles,
  id_col = "id_parcelle",
  metadata = list(
    site_name = "Mon site d'étude",
    year = 2024,
    source = "Inventaire terrain + IGN"
  )
)

# Cataloguer les couches spatiales
layers <- nemeton_layers(
  rasters = list(
    biomass = "biomass.tif",
    dem = "mnt.tif",
    landcover = "occupation_sol.tif",
    species_richness = "richesse_specifique.tif"
  ),
  vectors = list(
    roads = "routes.gpkg",
    water = "cours_eau.gpkg"
  )
)
```

### 2. Calcul des indicateurs

```r
# Calculer tous les indicateurs
results <- nemeton_compute(
  units,
  layers,
  indicators = "all",
  preprocess = TRUE,     # Harmonisation CRS automatique
  progress = TRUE,       # Afficher progression
  forest_values = c(1, 2, 3)  # Pour fragmentation
)

# Ou sélectionner des indicateurs spécifiques
results <- nemeton_compute(
  units,
  layers,
  indicators = c("carbon", "biodiversity", "water")
)
```

### 3. Normalisation

```r
# Méthode 1 : Min-max (0-100, par défaut)
normalized <- normalize_indicators(
  results,
  indicators = c("carbon", "biodiversity", "water"),
  method = "minmax"
)

# Méthode 2 : Z-score (standardisation)
normalized_z <- normalize_indicators(
  results,
  method = "zscore"
)

# Méthode 3 : Quantiles (robuste aux outliers)
normalized_q <- normalize_indicators(
  results,
  method = "quantile"
)

# Normalisation avec données de référence
new_normalized <- normalize_indicators(
  new_data,
  reference_data = baseline_data,  # Utilise min/max de baseline
  method = "minmax"
)
```

### 4. Indices composites

```r
# Indice de santé écosystémique (pondération égale)
ecosystem <- create_composite_index(
  normalized,
  indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
  name = "ecosystem_health"
)

# Indice de conservation (pondération personnalisée)
conservation <- create_composite_index(
  normalized,
  indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
  weights = c(0.3, 0.5, 0.2),  # Priorité biodiversité
  name = "conservation_value"
)

# Indice de sauvagerie (inverser accessibilité)
wilderness <- normalized %>%
  invert_indicator(
    indicators = "accessibility_norm",
    suffix = "_wilderness"
  ) %>%
  create_composite_index(
    indicators = c("biodiversity_norm", "accessibility_norm_wilderness"),
    weights = c(0.6, 0.4),
    name = "wilderness_index"
  )

# Approche conservatrice (facteur limitant)
limiting <- create_composite_index(
  normalized,
  indicators = c("carbon_norm", "water_norm"),
  aggregation = "min",  # Prend la valeur minimale
  name = "limiting_factor"
)
```

### 5. Visualisations

```r
# Carte simple - Un indicateur
plot_indicators_map(
  results,
  indicators = "carbon",
  palette = "Greens",
  title = "Stock de Carbone Forestier"
)

# Cartes multiples - Facettes
plot_indicators_map(
  normalized,
  indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
  palette = "viridis",
  facet = TRUE,
  ncol = 3,
  title = "Indicateurs Normalisés"
)

# Indice composite avec breaks personnalisés
plot_indicators_map(
  ecosystem,
  indicators = "ecosystem_health",
  palette = "RdYlGn",
  breaks = c(0, 25, 50, 75, 100),
  labels = c("Faible", "Moyen-Faible", "Moyen-Haut", "Haut", "Très Haut"),
  title = "Santé Écosystémique"
)

# Comparaison de scénarios
plot_comparison_map(
  current_state,
  future_scenario,
  indicator = "ecosystem_health",
  labels = c("État actuel (2024)", "Scénario 2050"),
  palette = "RdYlGn"
)

# Carte de changement
plot_difference_map(
  baseline,
  scenario,
  indicator = "carbon",
  type = "relative",  # Pourcentage de changement
  title = "Évolution du Stock de Carbone (%)"
)

# Graphique radar - Profil multi-dimensionnel
nemeton_radar(
  normalized,
  unit_id = "P01",
  title = "Profil Écosystémique - Parcelle P01"
)

# Radar moyen de toutes les unités
nemeton_radar(
  normalized,
  title = "Profil Moyen du Massif"
)
```

## 🎨 Palettes de couleurs

```r
# Viridis (défaut) - Perceptuellement uniforme, daltonien-friendly
plot_indicators_map(data, indicators = "carbon", palette = "viridis")

# ColorBrewer séquentielles
plot_indicators_map(data, indicators = "carbon", palette = "Greens")
plot_indicators_map(data, indicators = "water", palette = "Blues")
plot_indicators_map(data, indicators = "biodiversity", palette = "YlOrRd")

# ColorBrewer divergente (pour indices composites)
plot_indicators_map(data, indicators = "ecosystem_health", palette = "RdYlGn")
```

## 📊 Données d'entrée recommandées

| Indicateur | Couche requise | Format | Source recommandée |
|------------|----------------|--------|-------------------|
| **Carbone** | Biomasse aérienne | Raster (Mg/ha) | Copernicus Biomass, GEDI |
| **Biodiversité** | Richesse spécifique | Raster (nb espèces) | INPN, GBIF, inventaires |
| **Eau** | MNT + Hydrographie | Raster + Vecteur | IGN RGE ALTI + BD TOPO |
| **Fragmentation** | Occupation du sol | Raster (classes) | OSO (Theia), CLC |
| **Accessibilité** | Routes + Sentiers | Vecteur (lignes) | BD TOPO, OpenStreetMap |

### Projections recommandées

- **France métropolitaine** : Lambert-93 (EPSG:2154)
- **Autres** : Projections locales appropriées

Le package gère automatiquement la reprojection si `preprocess = TRUE`.

## 🔧 Configuration avancée

### Métadonnées et traçabilité

```r
units <- nemeton_units(
  parcelles,
  metadata = list(
    site_name = "Massif des Vosges",
    year = 2024,
    source = "IGN BD Forêt v2 + Inventaires terrain",
    description = "Parcelles de gestion forestière durable",
    contact = "gestionnaire@foret.fr"
  )
)

# Accéder aux métadonnées
meta <- attr(units, "metadata")
meta$crs           # Système de coordonnées
meta$n_units       # Nombre d'unités
meta$area_total    # Surface totale
meta$created_at    # Date de création
```

### Préprocessing manuel

```r
# Sans préprocessing automatique
results <- nemeton_compute(units, layers, preprocess = FALSE)

# Ou préprocessing manuel
layers_harmonized <- harmonize_crs(layers, target_crs = st_crs(units))
layers_cropped <- crop_to_units(layers_harmonized, units, buffer = 100)
layers_masked <- mask_to_units(layers_cropped, units)

results <- nemeton_compute(units, layers_masked, preprocess = FALSE)
```

### Gestion des erreurs

```r
# Si un indicateur échoue, les autres continuent
results <- nemeton_compute(
  units,
  layers,
  indicators = "all",
  forest_values = c(1, 2, 3)  # Requis pour fragmentation
)
# Warning: Indicator 'water' calculation failed
# > Setting 'water' to NA

# Vérifier les indicateurs calculés
meta <- attr(results, "metadata")
meta$indicators_computed  # Indicateurs réussis
```

## 📖 Documentation

- **Manuel de référence** : `help(package = "nemeton")`
- **Fonctions principales** :
  - `?nemeton_compute` - Calculer les indicateurs
  - `?normalize_indicators` - Normaliser les valeurs
  - `?create_composite_index` - Créer des indices composites
  - `?plot_indicators_map` - Visualiser sur carte

## 🤝 Contribution

Les contributions sont bienvenues ! Pour contribuer :

1. Fork le projet
2. Créer une branche (`git checkout -b feature/amelioration`)
3. Commiter les changements (`git commit -m 'Ajout fonctionnalité'`)
4. Push vers la branche (`git push origin feature/amelioration`)
5. Ouvrir une Pull Request

### Développement

```r
# Cloner le dépôt
git clone https://github.com/pobsteta/nemeton.git
cd nemeton

# Installer les dépendances de développement
remotes::install_deps(dependencies = TRUE)

# Charger le package
devtools::load_all()

# Lancer les tests
devtools::test()

# Vérifier le package
devtools::check()
```

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 📚 Citation

Si vous utilisez `nemeton` dans vos travaux de recherche, veuillez citer :

```
Obstétar, P. (2024). nemeton: Systemic Forest Analysis Using the Nemeton Method.
R package version 0.1.0. https://github.com/pobsteta/nemeton
```

BibTeX :
```bibtex
@Manual{nemeton2024,
  title = {nemeton: Systemic Forest Analysis Using the Nemeton Method},
  author = {Pascal Obstétar},
  year = {2024},
  note = {R package version 0.1.0},
  url = {https://github.com/pobsteta/nemeton},
}
```

## 🙏 Remerciements

- **IGN** pour les données géographiques de référence
- **Theia** pour les données OSO d'occupation du sol
- **Copernicus** pour les données de biomasse
- Communautés **sf**, **terra**, et **ggplot2** pour les outils spatiaux

## 🔗 Liens utiles

- [Documentation complète](https://pobsteta.github.io/nemeton/) (à venir)
- [Issues et suggestions](https://github.com/pobsteta/nemeton/issues)
- [Discussions](https://github.com/pobsteta/nemeton/discussions)

---

**Développé avec** ❤️ **et** [Claude Code](https://claude.com/claude-code)
