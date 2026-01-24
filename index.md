# nemeton

> **Analyse systémique de territoires forestiers selon la méthode
> Nemeton**

`nemeton` est un package R pour l’analyse intégrée d’écosystèmes
forestiers à partir de données spatiales ouvertes. Il implémente la
méthode Nemeton pour calculer, normaliser et visualiser des
**indicateurs biophysiques multi-famille** essentiels à la gestion
forestière durable.

## ✨ Fonctionnalités principales

### Référentiel Complet (v0.6.1)

- 🌳 **12 familles d’indicateurs** (100% implémenté) :
  - **C** - Carbone & Vitalité \| **B** - Biodiversité \| **W** - Eau \|
    **A** - Air & Microclimat
  - **F** - Fertilité Sols \| **L** - Paysage \| **T** - Temporel \|
    **R** - Risques & Résilience
  - **S** - Social & Usages 🆕 \| **P** - Production & Économie 🆕 \|
    **E** - Énergie & Climat 🆕 \| **N** - Naturalité 🆕
- 📊 **32 sous-indicateurs** : C1-C2, B1-B3, W1-W3, A1-A2, F1-F2, L1-L3,
  T1-T2, R1-R4, S1-S3, P1-P3, E1-E2, N1-N3

### Outils d’Analyse Avancée

- 🎯 **Optimisation multi-critères** : Analyse de Pareto, identification
  des solutions non-dominées
- 🔍 **Clustering intelligent** : K-means & hiérarchique avec
  auto-détermination du k optimal (silhouette)
- ⚖️ **Trade-off analysis** : Visualisation des compromis entre services
  écosystémiques

### Infrastructure & Qualité

- ⏱️ **Analyse temporelle** : Datasets multi-périodes, calcul de taux de
  changement, visualisations
- 📈 **Normalisation avancée** : min-max, z-score, quantiles, par
  famille, avec référence
- 🎯 **Agrégation flexible** : 5 méthodes (moyenne, pondérée,
  géométrique, harmonique, min)
- 🗺️ **Visualisations riches** : Cartes, radar 12-axes, matrices de
  corrélation, frontières de Pareto
- 🔄 **Workflow intégré** : De la donnée brute aux zonages
  multifonctionnels
- 📦 **Production-ready** : 1322 tests (100% pass), 85.8% coverage,
  backward compatible

## 📋 Prérequis

- R ≥ 4.1.0
- Packages spatiaux : `sf`, `terra`, `exactextractr`
- Visualisation : `ggplot2`, `tidyr`

## 🚀 Installation

``` r
# Depuis GitHub (version développement)
# install.packages("remotes")
remotes::install_github("pobsteta/nemeton")
```

## 🌟 Nouveautés v0.4.x (Janvier 2026)

### 4 Nouvelles Familles d’Indicateurs

- **Famille S (Social & Usages)** : Densité sentiers, accessibilité
  multimodale, proximité population
- **Famille P (Production & Économie)** : Volume bois, productivité
  station, qualité bois d’œuvre
- **Famille E (Énergie & Climat)** : Potentiel bois-énergie, évitement
  CO₂ par substitution
- **Famille N (Naturalité & Wilderness)** : Distance infrastructures,
  continuité forestière, indice composite

### Analyse Multi-Critères Avancée

``` r
# Identifier les parcelles Pareto-optimales (non-dominées)
result <- identify_pareto_optimal(
  data,
  objectives = c("family_C", "family_B", "family_P"),
  maximize = c(TRUE, TRUE, TRUE)
)

# Clustering automatique (k optimal via silhouette)
clusters <- cluster_parcels(
  data,
  families = c("family_C", "family_B", "family_P", "family_S"),
  k = NULL  # Auto-détermination
)

# Visualiser les trade-offs avec frontière de Pareto
plot_tradeoff(
  result,
  x = "family_C",
  y = "family_B",
  pareto_frontier = TRUE
)
```

### Dataset Étendu

- `massif_demo_units_extended` : 20 parcelles avec **toutes les 12
  familles** calculées
- Prêt à l’emploi pour tester le référentiel complet

## 🎯 Quick Start

### Workflow Complet 12 Familles (Recommandé)

``` r
library(nemeton)
library(ggplot2)

# Charger le dataset étendu (20 parcelles, 12 familles calculées)
data(massif_demo_units_extended)

# 1. Créer les indices de famille (auto-détection des 12 familles)
result <- create_family_index(massif_demo_units_extended)

# 2. Visualiser le profil 12-axes d'une parcelle
nemeton_radar(
  result,
  parcel_id = "parcel_1",
  families = c("family_C", "family_B", "family_W", "family_A",
               "family_F", "family_L", "family_T", "family_R",
               "family_S", "family_P", "family_E", "family_N")
)

# 3. Analyse de Pareto (identifier les meilleures parcelles)
pareto <- identify_pareto_optimal(
  result,
  objectives = c("family_C", "family_B", "family_P"),
  maximize = c(TRUE, TRUE, TRUE)
)
sum(pareto$is_optimal)  # Nombre de parcelles Pareto-optimales

# 4. Clustering & zonage multifonctionnel
zones <- cluster_parcels(
  result,
  families = c("family_C", "family_B", "family_P", "family_S"),
  k = NULL  # Auto-détermination du k optimal
)
attr(zones, "optimal_k")  # k optimal déterminé

# 5. Visualiser les trade-offs
plot_tradeoff(
  pareto,
  x = "family_C",
  y = "family_B",
  pareto_frontier = TRUE,
  title = "Trade-off Carbone vs Biodiversité"
)
```

### Workflow Classique v0.1.0 (Compatible)

``` r
# Toujours fonctionnel pour compatibilité arrière
results <- nemeton_compute(massif_demo_units, layers, indicators = "all")
normalized <- normalize_indicators(results, method = "minmax")
health <- create_composite_index(
  normalized,
  indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
  name = "ecosystem_health"
)
plot_indicators_map(health, indicators = "ecosystem_health", palette = "RdYlGn")
```

### Avec vos propres données

``` r
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

Le package inclut `massif_demo`, un dataset synthétique représentant un
massif forestier de 136 ha avec 20 parcelles.

### Contenu

``` r
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
  - `water` : Cours d’eau (3 rivières)

### Exemples d’utilisation

``` r
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

``` r
# Exemple avec BD Forêt attributes
data(massif_demo_units)

# Prepare units with required BD Forêt attributes
massif_demo_units$species <- c("Quercus", "Fagus", "Pinus")
massif_demo_units$age <- c(80, 60, 40)
massif_demo_units$density <- c(0.7, 0.8, 0.6)

# Calculate carbon stock using allometric models
carbon <- indicator_carbon_biomass(massif_demo_units)
summary(carbon)  # Stock de carbone en tC/ha
```

**Données requises** : Attributs BD Forêt (espèce, âge, densité)
**Source recommandée** : BD Forêt v2 IGN, inventaires forestiers locaux

### 🦋 Indicateur Biodiversité

Protection et diversité structurelle des habitats.

``` r
# Exemple - Protection status (B1)
data(massif_demo_units)
layers <- massif_demo_layers()

biodiv_prot <- indicator_biodiversity_protection(
  massif_demo_units,
  layers,
  protection_layer = "protected_areas"
)
summary(biodiv_prot)  # Score de protection des habitats
```

**Données requises** : Couches de zones protégées, diversité
structurelle **Source recommandée** : INPN, ZNIEFF, réserves naturelles

### 💧 Indicateur Eau

Régulation hydrique via TWI et réseau hydrographique.

``` r
# Exemple - Topographic Wetness Index (W3)
data(massif_demo_units)
layers <- massif_demo_layers()

water_twi <- indicator_water_twi(
  massif_demo_units,
  layers,
  dem_layer = "dem"
)
summary(water_twi)  # Indice 0-1 (zones humides potentielles)
```

**Données requises** : MNT (DEM), réseau hydrographique, zones humides
**Source recommandée** : IGN RGE ALTI, BD TOPO Hydrographie

### 🌿 Indicateur Paysage

Fragmentation forestière et connectivité.

``` r
# Exemple - Landscape fragmentation (L1)
data(massif_demo_units)
layers <- massif_demo_layers()

frag <- indicator_landscape_fragmentation(
  massif_demo_units,
  layers,
  landcover_layer = "landcover",
  forest_classes = c(1, 2, 3)  # Classes forestières
)
summary(frag)  # Métriques de fragmentation paysagère
```

**Données requises** : Raster d’occupation du sol **Source recommandée**
: OSO (Theia), Corine Land Cover

### 🛤️ Indicateur Social

Accessibilité et services récréatifs.

``` r
# Exemple - Social accessibility (S2)
data(massif_demo_units)
layers <- massif_demo_layers()

access <- indicator_social_accessibility(
  massif_demo_units,
  layers,
  roads_layer = "roads",
  trails_layer = "trails"
)
summary(access)  # Indice 0-1 (accessibilité pour loisirs/services)
```

**Données requises** : Vecteurs routes, sentiers, équipements **Source
recommandée** : BD TOPO Routes, OpenStreetMap, IGN

## 🔄 Workflow complet

### Exemple 1 : Avec massif_demo (Débutants)

``` r
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

``` r
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

``` r
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

``` r
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

``` r
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

# Approche conservatrice (facteur limitant) - v0.3.0
limiting <- create_family_index(
  normalized,
  method = "min"  # Prend la valeur minimale par famille
)
```

### 5. Visualisations

``` r
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

``` r
# Viridis (défaut) - Perceptuellement uniforme, daltonien-friendly
plot_indicators_map(data, indicators = "carbon", palette = "viridis")

# ColorBrewer séquentielles
plot_indicators_map(data, indicators = "carbon", palette = "Greens")
plot_indicators_map(data, indicators = "water", palette = "Blues")
plot_indicators_map(data, indicators = "biodiversity", palette = "YlOrRd")

# ColorBrewer divergente (pour indices composites)
plot_indicators_map(data, indicators = "ecosystem_health", palette = "RdYlGn")
```

## 📊 Données d’entrée recommandées

| Indicateur        | Couche requise      | Format              | Source recommandée       |
|-------------------|---------------------|---------------------|--------------------------|
| **Carbone**       | Biomasse aérienne   | Raster (Mg/ha)      | Copernicus Biomass, GEDI |
| **Biodiversité**  | Richesse spécifique | Raster (nb espèces) | INPN, GBIF, inventaires  |
| **Eau**           | MNT + Hydrographie  | Raster + Vecteur    | IGN RGE ALTI + BD TOPO   |
| **Fragmentation** | Occupation du sol   | Raster (classes)    | OSO (Theia), CLC         |
| **Accessibilité** | Routes + Sentiers   | Vecteur (lignes)    | BD TOPO, OpenStreetMap   |

### Projections recommandées

- **France métropolitaine** : Lambert-93 (EPSG:2154)
- **Autres** : Projections locales appropriées

Le package gère automatiquement la reprojection si `preprocess = TRUE`.

## 🔧 Configuration avancée

### Métadonnées et traçabilité

``` r
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

``` r
# Sans préprocessing automatique
results <- nemeton_compute(units, layers, preprocess = FALSE)

# Ou préprocessing manuel
layers_harmonized <- harmonize_crs(layers, target_crs = st_crs(units))
layers_cropped <- crop_to_units(layers_harmonized, units, buffer = 100)
layers_masked <- mask_to_units(layers_cropped, units)

results <- nemeton_compute(units, layers_masked, preprocess = FALSE)
```

### Gestion des erreurs

``` r
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

### Vignettes (Guides Complets)

``` r
# Introduction et workflows de base
vignette("getting-started", package = "nemeton")

# Analyse multi-période et détection de changements
vignette("temporal-analysis", package = "nemeton")

# Référentiel complet des 12 familles d'indicateurs
vignette("indicator-families", package = "nemeton")

# Support bilingue français/anglais
vignette("internationalization", package = "nemeton")
```

### Référence des Fonctions

- **Manuel complet** :
  [`?nemeton`](https://pobsteta.github.io/nemeton/reference/nemeton-package.md)
  ou [`help(package = "nemeton")`](https://rdrr.io/pkg/nemeton/man)
- **Fonctions principales** :
  - [`?nemeton_compute`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md) -
    Calculer les indicateurs
  - [`?nemeton_temporal`](https://pobsteta.github.io/nemeton/reference/nemeton_temporal.md) -
    Analyse multi-période (v0.2.0)
  - [`?create_family_index`](https://pobsteta.github.io/nemeton/reference/create_family_index.md) -
    Indices de famille (v0.2.0)
  - [`?normalize_indicators`](https://pobsteta.github.io/nemeton/reference/normalize_indicators.md) -
    Normaliser les valeurs
  - [`?create_composite_index`](https://pobsteta.github.io/nemeton/reference/create_composite_index.md) -
    Créer des indices composites
  - [`?nemeton_radar`](https://pobsteta.github.io/nemeton/reference/nemeton_radar.md) -
    Radar multi-famille (v0.2.0)
  - [`?plot_indicators_map`](https://pobsteta.github.io/nemeton/reference/plot_indicators_map.md) -
    Visualiser sur carte

## 🤝 Contribution

Les contributions sont bienvenues ! Pour contribuer :

1.  Fork le projet
2.  Créer une branche (`git checkout -b feature/amelioration`)
3.  Commiter les changements (`git commit -m 'Ajout fonctionnalité'`)
4.  Push vers la branche (`git push origin feature/amelioration`)
5.  Ouvrir une Pull Request

### Développement

``` r
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

Ce projet est sous licence MIT. Voir le fichier
[LICENSE](https://pobsteta.github.io/nemeton/LICENSE) pour plus de
détails.

## 📚 Citation

Si vous utilisez `nemeton` dans vos travaux de recherche, veuillez citer
:

    Obstétar, P. (2026). nemeton: Systemic Forest Analysis Using the Nemeton Method.
    R package version 0.6.1. https://github.com/pobsteta/nemeton

BibTeX :

``` bibtex
@Manual{nemeton2026,
  title = {nemeton: Systemic Forest Analysis Using the Nemeton Method},
  author = {Pascal Obstétar},
  year = {2026},
  note = {R package version 0.6.1},
  url = {https://github.com/pobsteta/nemeton},
}
```

### Nouveautés v0.3.0 (2026)

- 🌿 **4 nouvelles familles** : Biodiversité (B), Résilience (R),
  Temporel (T), Air & Microclimat (A)
- 📊 **10 nouveaux indicateurs** : B1-B3 (protection, structure,
  connectivité), R1-R3 (incendie, tempête, sécheresse), T1-T2
  (ancienneté, changement), A1-A2 (couverture, qualité air)
- 🎨 **Radar 9-axes** : Visualisation radar extensible jusqu’à 12
  familles, mode comparaison multi-unités
- 📈 **Agrégation min** : Nouvelle méthode d’agrégation conservatrice
  (facteur limitant)
- 📈 **845+ tests** : +28% vs v0.2.0 (661 tests), 100% backward
  compatible
- 🔄 **Infrastructure étendue** : Support complet des 9 familles dans
  normalisation, agrégation, visualisation

### Nouveautés v0.2.0 (2025)

- 🎯 **Système multi-famille** : 12 familles d’indicateurs (5
  implémentées)
- ⏱️ **Analyse temporelle** : Datasets multi-périodes, taux de
  changement
- 📊 **10 indicateurs biophysiques** : C1-C2, W1-W3, F1-F2, L1-L2
- 📈 **661 tests** : +195% vs v0.1.0 (225 tests)
- 🔄 **100% rétro-compatible** : Tous workflows v0.1.0 fonctionnent
- 📚 **2 nouvelles vignettes** : temporal-analysis, indicator-families

## 🙏 Remerciements

- **IGN** pour les données géographiques de référence
- **Theia** pour les données OSO d’occupation du sol
- **Copernicus** pour les données de biomasse
- Communautés **sf**, **terra**, et **ggplot2** pour les outils spatiaux

## 🔗 Liens utiles

- [Documentation complète](https://pobsteta.github.io/nemeton/) (à
  venir)
- [Issues et suggestions](https://github.com/pobsteta/nemeton/issues)
- [Discussions](https://github.com/pobsteta/nemeton/discussions)

------------------------------------------------------------------------

**Développé avec** ❤️ **et** [Claude
Code](https://claude.com/claude-code)
