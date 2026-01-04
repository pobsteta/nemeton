# Spécification Technique : Package R nemeton

**Version** : 1.0.0
**Date** : 2026-01-04
**Statut** : Draft
**Auteur** : Architecture logicielle

---

## Table des matières

1. [Vue d'ensemble](#1-vue-densemble)
2. [Périmètre fonctionnel](#2-périmètre-fonctionnel)
3. [Architecture du package](#3-architecture-du-package)
4. [Design de l'API](#4-design-de-lapi)
5. [Modules et responsabilités](#5-modules-et-responsabilités)
6. [Catalogue des fonctions](#6-catalogue-des-fonctions)
7. [Structures de données](#7-structures-de-données)
8. [Dépendances](#8-dépendances)
9. [Stratégie de tests](#9-stratégie-de-tests)
10. [Documentation et exemples](#10-documentation-et-exemples)
11. [Extensibilité et personnalisation](#11-extensibilité-et-personnalisation)
12. [Feuille de route](#12-feuille-de-route)

---

## 1. Vue d'ensemble

### 1.1 Contexte et motivation

Le package **nemeton** implémente la méthode Néméton, un cadre systémique d'évaluation forestière qui intègre :

- **Indicateurs biophysiques** : carbone, biodiversité, eau, sol, paysage, risques climatiques
- **Dimensions temporelles** : états historiques, présents et futurs (scénarios prospectifs)
- **Dimensions sociales et symboliques** : usages, gouvernance, patrimoine, perception culturelle

Le package s'adresse aux :
- Forestiers et gestionnaires de territoire
- Écologues et chercheurs en sciences environnementales
- Bureaux d'études et collectivités territoriales
- Acteurs de la planification territoriale

### 1.2 Principes directeurs

1. **Open data first** : priorité aux données ouvertes et accessibles
2. **Interopérabilité** : compatibilité avec l'écosystème R spatial (sf, terra, stars)
3. **Modularité** : séparation claire entre acquisition, calcul, agrégation et visualisation
4. **Transparence** : traçabilité des calculs et paramètres explicites
5. **Extensibilité** : possibilité d'ajouter de nouveaux indicateurs via fonctions custom
6. **Reproductibilité** : intégration avec targets/drake pour pipelines reproductibles

### 1.3 Objectifs principaux

- Fournir une API claire et cohérente pour analyser des territoires forestiers selon la méthode Néméton
- Automatiser le calcul d'indicateurs spatiaux à partir de sources de données standard
- Permettre l'analyse comparative multi-temporelle (passé-présent-futur)
- Offrir des visualisations prêtes à l'emploi
- Faciliter l'export vers SIG (QGIS, ArcGIS) et formats ouverts

---

## 2. Périmètre fonctionnel

### 2.1 Fonctionnalités principales (MVP)

#### Gestion des unités spatiales
- Définition d'unités d'analyse (parcelles, îlots, grilles) comme objets `sf`
- Métadonnées associées (nom du site, époque, système de coordonnées, sources)
- Support de géométries polygonales et multi-polygonales

#### Acquisition et préparation des données
- Chargement de rasters (NDVI, MNT, indices climatiques, risques)
- Chargement de vecteurs (limites administratives, réseau hydro, Natura 2000, routes)
- Harmonisation spatiale (reprojection, découpage, masquage)
- Validation et nettoyage basique

#### Calcul d'indicateurs Néméton
- API pour calculer des indicateurs par unité spatiale
- Support de fonctions d'agrégation spatiale (mean, median, sum, sd, etc.)
- Calcul à partir de rasters (extraction zonale via exactextractr)
- Calcul à partir de vecteurs (overlay, distances, densités)
- Indicateurs biophysiques, sociaux, productifs, paysagers

#### Gestion multi-temporelle
- Stockage de plusieurs "états Néméton" (époques/scénarios)
- Comparaison d'états (différences, ratios, tendances)
- Visualisation de trajectoires temporelles

#### Normalisation et indices composites
- Normalisation d'indicateurs (0-100, z-score, quantiles, min-max)
- Agrégation en indices thématiques (biodiversité, eau, social, etc.)
- Calcul d'un indice global Néméton (paramétrable par poids)

#### Visualisations
- Cartes thématiques par indicateur (ggplot2 + sf)
- Diagrammes radar (profils Néméton)
- Comparaisons multi-époques (barres, radars juxtaposés)
- Timelines d'évolution

### 2.2 Fonctionnalités secondaires (post-MVP)

- Support de calculs à la volée depuis API externes (Copernicus, IGN Géoservices)
- Analyse de sensibilité des indices aux poids
- Export de rapports HTML interactifs (Rmarkdown, Quarto)
- Intégration avec base de données spatiales (PostGIS)
- Support de calculs parallèles (future, parallel)
- Interface Shiny pour exploration interactive

### 2.3 Hors périmètre

- Collecte primaire de données terrain
- Modélisation prédictive (machine learning, modèles de croissance)
- Optimisation de gestion forestière (programmation linéaire)
- Interface graphique desktop (GUI standalone)

---

## 3. Architecture du package

### 3.1 Structure de répertoires

```
nemeton/
├── R/
│   ├── nemeton-package.R          # Documentation du package
│   ├── data-units.R               # Fonctions de gestion des unités
│   ├── data-layers.R              # Fonctions de chargement de couches
│   ├── data-preprocessing.R       # Fonctions de préparation
│   ├── indicators-core.R          # Moteur de calcul d'indicateurs
│   ├── indicators-biophysical.R   # Indicateurs biophysiques
│   ├── indicators-social.R        # Indicateurs sociaux
│   ├── indicators-landscape.R     # Indicateurs paysagers
│   ├── temporal.R                 # Gestion multi-temporelle
│   ├── normalization.R            # Normalisation et agrégation
│   ├── visualization.R            # Visualisations
│   ├── utils.R                    # Utilitaires internes
│   ├── zzz.R                      # Hooks de chargement
│   └── nemeton-class.R            # Définitions S3
├── data/                          # Données d'exemple
│   └── massif_demo.rda            # Exemple de massif forestier
├── data-raw/                      # Scripts de préparation de données
│   └── massif_demo.R
├── inst/
│   ├── extdata/                   # Données externes
│   └── templates/                 # Templates Rmarkdown
├── man/                           # Documentation générée
├── tests/
│   ├── testthat/
│   │   ├── fixtures/              # Données de test
│   │   ├── test-units.R
│   │   ├── test-indicators.R
│   │   ├── test-temporal.R
│   │   └── test-visualization.R
│   └── testthat.R
├── vignettes/
│   ├── intro-nemeton.Rmd          # Introduction
│   ├── workflow-basic.Rmd         # Workflow de base
│   ├── multi-temporal.Rmd         # Analyse temporelle
│   ├── custom-indicators.Rmd      # Indicateurs personnalisés
│   └── integration-targets.Rmd    # Intégration avec targets
├── DESCRIPTION
├── NAMESPACE
├── LICENSE
├── README.md
└── NEWS.md
```

### 3.2 Paradigme de programmation

- **Programmation fonctionnelle** : fonctions pures autant que possible
- **Classes S3** : pour les objets nemeton (simplicité, compatibilité tidyverse)
- **Pipe-friendly** : fonctions compatibles avec `%>%` et `|>`
- **Tidy evaluation** : utilisation de rlang pour NSE quand nécessaire

### 3.3 Principes de conception

1. **Séparation des responsabilités** : chaque module a un rôle clair
2. **Composition** : fonctions de haut niveau composent des fonctions de bas niveau
3. **Validation précoce** : vérification des inputs dès l'entrée de fonction
4. **Messages informatifs** : warnings et errors explicites
5. **Traçabilité** : metadata tracking pour les opérations

---

## 4. Design de l'API

### 4.1 Philosophie de l'API

L'API suit un workflow en 5 étapes :

```r
# 1. Définir les unités d'analyse
units <- nemeton_units(polygons, metadata = list(site = "Massif XYZ"))

# 2. Charger et préparer les couches spatiales
layers <- nemeton_layers(
  rasters = list(ndvi = "ndvi.tif", dem = "dem.tif"),
  vectors = list(hydro = "rivers.gpkg")
)

# 3. Calculer les indicateurs
results <- nemeton_compute(
  units = units,
  layers = layers,
  indicators = c("carbon", "biodiversity", "water", "landscape")
)

# 4. Normaliser et agréger en indices
indices <- nemeton_index(results, method = "weighted", weights = c(0.3, 0.3, 0.2, 0.2))

# 5. Visualiser
nemeton_map(results, indicator = "carbon")
nemeton_radar(results, unit_id = 1)
```

### 4.2 Workflow multi-temporel

```r
# Créer un projet multi-époques
project <- nemeton_project(
  units = forest_units,
  name = "Forêt de Fontainebleau"
)

# Ajouter plusieurs états
project <- project |>
  add_epoch("1950", layers = layers_1950, indicators = all_indicators) |>
  add_epoch("2020", layers = layers_2020, indicators = all_indicators) |>
  add_epoch("2050_RCP45", layers = layers_2050, indicators = all_indicators)

# Comparer
changes <- nemeton_compare(project, from = "1950", to = "2020")

# Visualiser
nemeton_timeline(project, indicator = "carbon", unit_id = 5)
nemeton_radar_compare(project, epochs = c("1950", "2020", "2050_RCP45"), unit_id = 5)
```

### 4.3 Personnalisation d'indicateurs

```r
# Définir un indicateur custom
my_indicator <- nemeton_indicator(
  name = "fragmentation",
  type = "landscape",
  fun = function(units, layers) {
    # Calcul personnalisé
    fragmentation_index(units, layers$landcover)
  },
  dependencies = c("landcover"),
  description = "Indice de fragmentation forestière"
)

# L'utiliser
results <- nemeton_compute(
  units = units,
  layers = layers,
  indicators = list(my_indicator, "carbon", "biodiversity")
)
```

---

## 5. Modules et responsabilités

### 5.1 Module : Gestion des unités (`data-units.R`)

**Responsabilité** : Définir, valider et manipuler les unités spatiales d'analyse.

**Fonctions principales** :
- `nemeton_units()` : créer un objet d'unités Néméton
- `validate_units()` : valider la géométrie et les attributs
- `units_metadata()` : getter/setter de métadonnées
- `units_transform()` : reprojection des unités
- `units_grid()` : générer une grille régulière

**Responsabilités** :
- Validation des géométries (valid, non-empty, CRS défini)
- Ajout d'identifiants uniques si absents
- Stockage de métadonnées (site, date, CRS, sources)

### 5.2 Module : Couches spatiales (`data-layers.R`)

**Responsabilité** : Charger et référencer les couches spatiales externes.

**Fonctions principales** :
- `nemeton_layers()` : créer un catalogue de couches
- `add_raster()` : ajouter un raster
- `add_vector()` : ajouter un vecteur
- `layers_summary()` : résumer les couches disponibles

**Responsabilités** :
- Chargement lazy (ne charge pas en mémoire tant que non utilisé)
- Validation de l'existence des fichiers
- Stockage de métadonnées (CRS, résolution, extent)

### 5.3 Module : Prétraitement (`data-preprocessing.R`)

**Responsabilité** : Harmoniser les couches spatiales avec les unités.

**Fonctions principales** :
- `harmonize_crs()` : aligner les CRS
- `crop_to_units()` : découper les couches sur l'extent des unités
- `mask_to_units()` : masquer les rasters
- `clean_geometries()` : nettoyer les géométries invalides

**Responsabilités** :
- Reprojection automatique si nécessaire
- Découpage spatial pour réduire la charge mémoire
- Warnings informatifs sur les opérations effectuées

### 5.4 Module : Moteur d'indicateurs (`indicators-core.R`)

**Responsabilité** : Orchestrer le calcul des indicateurs.

**Fonctions principales** :
- `nemeton_compute()` : fonction principale de calcul
- `compute_indicator()` : calculer un indicateur unique
- `register_indicator()` : enregistrer un nouvel indicateur
- `list_indicators()` : lister les indicateurs disponibles

**Responsabilités** :
- Dispatcher vers les fonctions de calcul spécifiques
- Gestion des dépendances entre indicateurs
- Gestion des erreurs et warnings par indicateur
- Ajout des résultats aux unités sf

### 5.5 Module : Indicateurs biophysiques (`indicators-biophysical.R`)

**Responsabilité** : Calculer les indicateurs biophysiques.

**Fonctions** :
- `indicator_carbon()` : stock de carbone (biomasse, sol)
- `indicator_biodiversity()` : indices de biodiversité (richesse, Shannon, Simpson)
- `indicator_water()` : régulation hydrique (TWI, proximité hydro)
- `indicator_soil()` : qualité des sols (érosion, texture)
- `indicator_climate_risk()` : risques climatiques (sécheresse, incendie)

### 5.6 Module : Indicateurs sociaux (`indicators-social.R`)

**Responsabilité** : Calculer les indicateurs sociaux et culturels.

**Fonctions** :
- `indicator_accessibility()` : accessibilité (distance aux routes, sentiers)
- `indicator_protection()` : niveau de protection (Natura 2000, etc.)
- `indicator_usage()` : intensité d'usage (densité sentiers, équipements)
- `indicator_heritage()` : valeur patrimoniale (sites classés, arbres remarquables)

### 5.7 Module : Indicateurs paysagers (`indicators-landscape.R`)

**Responsabilité** : Calculer les indicateurs de structure paysagère.

**Fonctions** :
- `indicator_fragmentation()` : fragmentation (patches, connectivité)
- `indicator_heterogeneity()` : hétérogénéité (diversité paysagère)
- `indicator_naturalness()` : degré de naturalité (distance à l'intervention humaine)
- `indicator_continuity()` : continuité forestière (taille des massifs)

### 5.8 Module : Gestion temporelle (`temporal.R`)

**Responsabilité** : Gérer les analyses multi-temporelles.

**Fonctions principales** :
- `nemeton_project()` : créer un projet multi-époques
- `add_epoch()` : ajouter un état temporel
- `remove_epoch()` : supprimer un état
- `list_epochs()` : lister les époques
- `nemeton_compare()` : comparer deux états
- `compute_trends()` : calculer les tendances

**Responsabilités** :
- Stockage cohérent des états multiples
- Validation de la compatibilité des unités entre époques
- Calcul de différences, ratios, taux de changement

### 5.9 Module : Normalisation et agrégation (`normalization.R`)

**Responsabilité** : Normaliser et agréger les indicateurs.

**Fonctions principales** :
- `normalize_indicators()` : normaliser (0-100, z-score, quantiles)
- `nemeton_index()` : calculer des indices composites
- `weight_indicators()` : définir des poids
- `aggregate_thematic()` : agréger par thème

**Responsabilités** :
- Gestion de la polarité (plus c'est haut, mieux c'est ?)
- Support de différentes méthodes de normalisation
- Agrégation paramétrable (moyenne pondérée, géométrique, min/max)

### 5.10 Module : Visualisation (`visualization.R`)

**Responsabilité** : Générer des visualisations prêtes à l'emploi.

**Fonctions principales** :
- `nemeton_map()` : carte thématique d'un indicateur
- `nemeton_radar()` : diagramme radar pour une unité
- `nemeton_timeline()` : évolution temporelle
- `nemeton_radar_compare()` : radars multi-époques
- `nemeton_matrix()` : heatmap de corrélation d'indicateurs

**Responsabilités** :
- Génération de ggplot2 personnalisables
- Palettes de couleurs adaptées (viridis, RColorBrewer)
- Légendes et titres informatifs
- Export facile (ggsave compatible)

### 5.11 Module : Utilitaires (`utils.R`)

**Responsabilité** : Fonctions utilitaires internes.

**Fonctions** :
- `check_crs()` : vérifier compatibilité CRS
- `validate_sf()` : valider objet sf
- `validate_raster()` : valider objet SpatRaster
- `message_nemeton()` : messages formatés
- `progress_bar()` : barre de progression optionnelle

---

## 6. Catalogue des fonctions

### 6.1 Fonctions de haut niveau (High-level API)

#### `nemeton_units()`
**Signature** :
```r
nemeton_units(
  x,
  id_col = NULL,
  metadata = list(),
  validate = TRUE
)
```

**Arguments** :
- `x` : objet sf, ou chemin vers shapefile/geopackage
- `id_col` : nom de la colonne d'identifiant (créée si NULL)
- `metadata` : liste nommée de métadonnées
- `validate` : valider les géométries ?

**Retour** : objet `nemeton_units` (hérite de `sf`)

**Exemple** :
```r
units <- nemeton_units(
  st_read("parcelles.gpkg"),
  metadata = list(site = "Forêt de Compiègne", year = 2024)
)
```

---

#### `nemeton_layers()`
**Signature** :
```r
nemeton_layers(
  rasters = NULL,
  vectors = NULL,
  validate = TRUE
)
```

**Arguments** :
- `rasters` : liste nommée de chemins vers rasters
- `vectors` : liste nommée de chemins vers vecteurs
- `validate` : vérifier l'existence des fichiers ?

**Retour** : objet `nemeton_layers` (liste S3)

**Exemple** :
```r
layers <- nemeton_layers(
  rasters = list(
    ndvi = "sentinel2_ndvi.tif",
    dem = "ign_mnt_25m.tif"
  ),
  vectors = list(
    hydro = "bdtopo_hydro.gpkg",
    roads = "routes.shp"
  )
)
```

---

#### `nemeton_compute()`
**Signature** :
```r
nemeton_compute(
  units,
  layers,
  indicators = "all",
  preprocess = TRUE,
  parallel = FALSE,
  progress = TRUE,
  ...
)
```

**Arguments** :
- `units` : objet nemeton_units
- `layers` : objet nemeton_layers
- `indicators` : vecteur de noms d'indicateurs ou "all"
- `preprocess` : harmoniser automatiquement les CRS/extent ?
- `parallel` : calcul parallèle (future backend) ?
- `progress` : afficher barre de progression ?
- `...` : arguments passés aux fonctions d'indicateurs

**Retour** : objet `sf` avec colonnes d'indicateurs

**Exemple** :
```r
results <- nemeton_compute(
  units = my_units,
  layers = my_layers,
  indicators = c("carbon", "biodiversity", "water"),
  preprocess = TRUE
)
```

---

#### `nemeton_index()`
**Signature** :
```r
nemeton_index(
  data,
  method = c("weighted", "geometric", "harmonic"),
  weights = NULL,
  normalize = TRUE,
  normalize_method = c("minmax", "zscore", "rank"),
  thematic_groups = NULL
)
```

**Arguments** :
- `data` : sf avec indicateurs calculés
- `method` : méthode d'agrégation
- `weights` : vecteur de poids (NULL = équipondéré)
- `normalize` : normaliser avant agrégation ?
- `normalize_method` : méthode de normalisation
- `thematic_groups` : liste pour indices thématiques

**Retour** : `sf` avec colonnes d'indices

**Exemple** :
```r
indices <- nemeton_index(
  results,
  method = "weighted",
  weights = c(carbon = 0.3, biodiversity = 0.4, water = 0.3),
  thematic_groups = list(
    ecological = c("biodiversity", "water"),
    climate = c("carbon", "climate_risk")
  )
)
```

---

#### `nemeton_project()`
**Signature** :
```r
nemeton_project(
  units,
  name = NULL,
  description = NULL
)
```

**Arguments** :
- `units` : objet nemeton_units (template spatial)
- `name` : nom du projet
- `description` : description optionnelle

**Retour** : objet `nemeton_project` (liste S3)

**Exemple** :
```r
project <- nemeton_project(
  units = forest_units,
  name = "Analyse diachronique Fontainebleau",
  description = "Comparaison 1950-2020-2050"
)
```

---

#### `add_epoch()`
**Signature** :
```r
add_epoch(
  project,
  epoch_name,
  layers = NULL,
  data = NULL,
  indicators = "all",
  compute = TRUE,
  ...
)
```

**Arguments** :
- `project` : objet nemeton_project
- `epoch_name` : identifiant de l'époque (ex: "2020", "scenario_RCP45")
- `layers` : nemeton_layers pour cette époque
- `data` : ou directement sf avec indicateurs pré-calculés
- `indicators` : indicateurs à calculer
- `compute` : calculer maintenant ou plus tard ?
- `...` : arguments pour nemeton_compute()

**Retour** : `nemeton_project` modifié

**Exemple** :
```r
project <- project |>
  add_epoch("1950", layers = layers_1950) |>
  add_epoch("2020", layers = layers_2020) |>
  add_epoch("2050", layers = layers_2050_rcp45)
```

---

#### `nemeton_compare()`
**Signature** :
```r
nemeton_compare(
  project,
  from,
  to,
  method = c("difference", "ratio", "percent_change"),
  indicators = NULL
)
```

**Arguments** :
- `project` : nemeton_project
- `from` : nom de l'époque de référence
- `to` : nom de l'époque de comparaison
- `method` : type de comparaison
- `indicators` : indicateurs à comparer (NULL = tous)

**Retour** : `sf` avec colonnes de changement

**Exemple** :
```r
changes <- nemeton_compare(
  project,
  from = "1950",
  to = "2020",
  method = "percent_change"
)
```

---

### 6.2 Fonctions de visualisation

#### `nemeton_map()`
**Signature** :
```r
nemeton_map(
  data,
  indicator,
  palette = "viridis",
  title = NULL,
  breaks = NULL,
  ...
)
```

**Arguments** :
- `data` : sf avec indicateurs
- `indicator` : nom de l'indicateur à cartographier
- `palette` : palette de couleurs (viridis, RColorBrewer)
- `title` : titre de la carte
- `breaks` : breaks pour les classes (NULL = automatique)
- `...` : arguments passés à geom_sf()

**Retour** : objet `ggplot`

---

#### `nemeton_radar()`
**Signature** :
```r
nemeton_radar(
  data,
  unit_id = NULL,
  indicators = NULL,
  normalize = TRUE,
  fill_alpha = 0.3,
  color = "steelblue"
)
```

**Arguments** :
- `data` : sf avec indicateurs
- `unit_id` : identifiant de l'unité (NULL = moyenne de toutes)
- `indicators` : indicateurs à afficher (NULL = tous)
- `normalize` : normaliser 0-100 ?
- `fill_alpha` : transparence du remplissage
- `color` : couleur principale

**Retour** : objet `ggplot`

---

#### `nemeton_timeline()`
**Signature** :
```r
nemeton_timeline(
  project,
  indicator,
  unit_id = NULL,
  stat = c("mean", "median", "min", "max"),
  smooth = FALSE
)
```

**Arguments** :
- `project` : nemeton_project
- `indicator` : indicateur à suivre
- `unit_id` : unité spécifique (NULL = moyenne de toutes)
- `stat` : statistique si unit_id = NULL
- `smooth` : ajouter une courbe lissée ?

**Retour** : objet `ggplot`

---

#### `nemeton_radar_compare()`
**Signature** :
```r
nemeton_radar_compare(
  project,
  epochs,
  unit_id,
  indicators = NULL,
  facet = FALSE
)
```

**Arguments** :
- `project` : nemeton_project
- `epochs` : vecteur d'époques à comparer
- `unit_id` : identifiant de l'unité
- `indicators` : indicateurs à afficher
- `facet` : afficher en facettes séparées ?

**Retour** : objet `ggplot`

---

### 6.3 Fonctions d'indicateurs

Toutes les fonctions d'indicateurs suivent cette signature standard :

```r
indicator_<name>(
  units,
  layers,
  method = "default",
  params = list(),
  fun = c("mean", "median", "sum", "sd"),
  na.rm = TRUE
)
```

**Retour** : vecteur numérique (même longueur que nrow(units))

#### Exemples

**`indicator_carbon()`**
```r
indicator_carbon(
  units,
  layers,
  method = c("biomass", "soil", "total"),
  biomass_var = "AGB",  # Above-Ground Biomass
  soil_depth = 30,      # cm
  fun = "sum"
)
```

**`indicator_biodiversity()`**
```r
indicator_biodiversity(
  units,
  layers,
  method = c("richness", "shannon", "simpson"),
  species_layer = "species_raster",
  fun = "mean"
)
```

**`indicator_water()`**
```r
indicator_water(
  units,
  layers,
  method = c("twi", "proximity", "retention"),
  dem_layer = "dem",
  hydro_layer = "rivers",
  buffer = 100  # mètres
)
```

**`indicator_accessibility()`**
```r
indicator_accessibility(
  units,
  layers,
  roads_layer = "roads",
  trails_layer = "trails",
  max_distance = 1000,  # mètres
  decay_function = "exponential"
)
```

---

### 6.4 Fonctions de normalisation

#### `normalize_indicators()`
**Signature** :
```r
normalize_indicators(
  data,
  indicators = NULL,
  method = c("minmax", "zscore", "rank", "percentile"),
  polarity = NULL,
  range = c(0, 100)
)
```

**Arguments** :
- `data` : sf avec indicateurs
- `indicators` : indicateurs à normaliser (NULL = numériques)
- `method` : méthode de normalisation
- `polarity` : vecteur nommé (+1 ou -1) pour direction souhaitée
- `range` : intervalle cible pour minmax

**Retour** : `sf` avec colonnes normalisées

**Exemple** :
```r
normalized <- normalize_indicators(
  results,
  method = "minmax",
  polarity = c(carbon = 1, fragmentation = -1),  # fragmentation : moins = mieux
  range = c(0, 100)
)
```

---

### 6.5 Fonctions utilitaires

#### `harmonize_crs()`
```r
harmonize_crs(layers, target_crs, verbose = TRUE)
```

#### `crop_to_units()`
```r
crop_to_units(layers, units, buffer = 0)
```

#### `list_indicators()`
```r
list_indicators(category = NULL, return = c("names", "details"))
```

#### `register_indicator()`
```r
register_indicator(
  name,
  fun,
  category = "custom",
  dependencies = NULL,
  description = NULL
)
```

---

## 7. Structures de données

### 7.1 Classe `nemeton_units`

**Héritage** : `sf` → `data.frame`

**Attributs obligatoires** :
- Colonne géométrique (POLYGON ou MULTIPOLYGON)
- Colonne `nemeton_id` (character ou integer unique)

**Métadonnées** (attribut `metadata`) :
```r
list(
  site_name = "Forêt de ...",
  year = 2024,
  crs = st_crs(units),
  n_units = nrow(units),
  area_total = sum(st_area(units)),
  created_at = Sys.time(),
  source = "IGN BD Forêt v2",
  ...
)
```

**Méthodes S3** :
- `print.nemeton_units()`
- `summary.nemeton_units()`
- `plot.nemeton_units()`

---

### 7.2 Classe `nemeton_layers`

**Structure** : liste nommée

```r
list(
  rasters = list(
    ndvi = list(path = "...", loaded = FALSE, metadata = ...),
    dem = list(path = "...", loaded = FALSE, metadata = ...)
  ),
  vectors = list(
    hydro = list(path = "...", loaded = FALSE, metadata = ...)
  ),
  metadata = list(
    created_at = ...,
    n_rasters = 2,
    n_vectors = 1
  )
)
```

**Méthodes S3** :
- `print.nemeton_layers()`
- `summary.nemeton_layers()`

---

### 7.3 Classe `nemeton_project`

**Structure** : liste S3

```r
list(
  name = "Projet X",
  description = "...",
  units_template = <nemeton_units>,  # Template spatial
  epochs = list(
    "1950" = list(
      layers = <nemeton_layers>,
      data = <sf with indicators>,
      computed_at = <timestamp>,
      metadata = list(...)
    ),
    "2020" = list(...),
    "2050_RCP45" = list(...)
  ),
  metadata = list(
    created_at = ...,
    n_epochs = 3,
    indicators_computed = c("carbon", "biodiversity", ...),
    ...
  )
)
```

**Méthodes S3** :
- `print.nemeton_project()`
- `summary.nemeton_project()`
- `plot.nemeton_project()`

---

### 7.4 Classe `nemeton_indicator`

Pour les indicateurs personnalisés :

```r
structure(
  list(
    name = "my_indicator",
    category = "custom",
    fun = function(units, layers, ...) { ... },
    dependencies = c("layer1", "layer2"),
    description = "...",
    params = list(default_param = value)
  ),
  class = "nemeton_indicator"
)
```

---

## 8. Dépendances

### 8.1 Dépendances obligatoires (Imports)

| Package | Version minimale | Usage |
|---------|------------------|-------|
| `sf` | >= 1.0-0 | Manipulation de vecteurs, classe de base |
| `terra` | >= 1.7-0 | Manipulation de rasters |
| `exactextractr` | >= 0.9.0 | Extraction zonale performante |
| `dplyr` | >= 1.1.0 | Manipulation de données |
| `ggplot2` | >= 3.4.0 | Visualisations |
| `rlang` | >= 1.1.0 | Métaprogrammation, NSE |
| `cli` | >= 3.6.0 | Messages formatés |

### 8.2 Dépendances suggérées (Suggests)

| Package | Usage |
|---------|-------|
| `units` | Conversion d'unités (hectares, m², etc.) |
| `purrr` | Programmation fonctionnelle |
| `tidyr` | Reshaping pour visualisations |
| `scales` | Formatage d'axes dans ggplot2 |
| `viridis` | Palettes de couleurs |
| `ggradar` | Diagrammes radar (ou réimplémentation) |
| `lwgeom` | Opérations géométriques avancées |
| `stars` | Support rasters alternatif (datacubes) |
| `furrr` | Calculs parallèles avec future |
| `targets` | Pipelines reproductibles |
| `testthat` | Tests unitaires |
| `knitr` | Vignettes |
| `rmarkdown` | Vignettes et rapports |
| `covr` | Couverture de code |

### 8.3 Dépendances système

- **GDAL** >= 3.0 (via sf/terra)
- **PROJ** >= 6.0 (projections)
- **GEOS** >= 3.8 (opérations géométriques)

---

## 9. Stratégie de tests

### 9.1 Principes

- **Couverture cible** : >= 80%
- **Tests systématiques** : toute fonction exportée doit avoir au moins un test
- **Tests de non-régression** : fixtures pour valeurs attendues
- **Tests d'intégration** : workflows complets de bout en bout

### 9.2 Catégories de tests

#### Tests unitaires

**Fichier** : `tests/testthat/test-units.R`
- Création d'unités depuis sf
- Validation de géométries
- Ajout/modification de métadonnées
- Transformation CRS

**Fichier** : `tests/testthat/test-layers.R`
- Création de catalogue de couches
- Validation de chemins
- Chargement lazy
- Harmonisation CRS

**Fichier** : `tests/testthat/test-indicators.R`
- Calcul de chaque indicateur individuellement
- Gestion des NA
- Gestion de couches manquantes
- Polarité des indicateurs

**Fichier** : `tests/testthat/test-normalization.R`
- Normalisation min-max
- Normalisation z-score
- Agrégation pondérée
- Indices thématiques

**Fichier** : `tests/testthat/test-temporal.R`
- Création de projet
- Ajout/suppression d'époques
- Comparaison d'états
- Calcul de tendances

**Fichier** : `tests/testthat/test-visualization.R`
- Génération de cartes (retour ggplot valide)
- Génération de radars
- Timelines
- Comparaisons

#### Tests d'intégration

**Fichier** : `tests/testthat/test-workflow.R`

```r
test_that("workflow complet fonctionne de bout en bout", {
  # 1. Créer unités
  units <- nemeton_units(demo_polygons)

  # 2. Charger couches
  layers <- nemeton_layers(
    rasters = list(ndvi = demo_ndvi_path),
    vectors = list(hydro = demo_hydro_path)
  )

  # 3. Calculer indicateurs
  results <- nemeton_compute(units, layers, indicators = c("carbon", "water"))

  # 4. Normaliser et agréger
  indices <- nemeton_index(results)

  # 5. Visualiser
  map <- nemeton_map(results, "carbon")

  # Assertions
  expect_s3_class(results, "sf")
  expect_true("carbon" %in% names(results))
  expect_s3_class(map, "ggplot")
})
```

#### Tests de données

**Fichier** : `tests/testthat/test-data.R`
- Validation des données d'exemple (massif_demo)
- Cohérence des fixtures de test

### 9.3 Fixtures de test

**Répertoire** : `tests/testthat/fixtures/`

Contenu :
- `demo_units.gpkg` : 10 polygones de test
- `demo_ndvi.tif` : raster NDVI 100x100
- `demo_dem.tif` : MNT 100x100
- `demo_hydro.gpkg` : réseau hydro fictif
- `expected_carbon.rds` : valeurs attendues pour indicateur carbone

### 9.4 Tests de régression

À chaque modification d'un indicateur, vérifier que les valeurs calculées sur les fixtures ne changent pas (ou documenter pourquoi).

```r
test_that("carbon indicator gives expected values", {
  results <- indicator_carbon(demo_units, demo_layers)
  expected <- readRDS("fixtures/expected_carbon.rds")
  expect_equal(results, expected, tolerance = 1e-6)
})
```

### 9.5 Tests de performance (optionnel)

**Fichier** : `tests/testthat/test-performance.R`

```r
test_that("nemeton_compute scales to 1000 units", {
  large_units <- generate_grid(n = 1000)

  time <- system.time({
    results <- nemeton_compute(large_units, demo_layers)
  })

  expect_lt(time["elapsed"], 60)  # Moins de 60 secondes
})
```

---

## 10. Documentation et exemples

### 10.1 README.md

**Sections** :

```markdown
# nemeton

Analyse systémique de territoires forestiers selon la méthode Néméton.

## Installation

## Démarrage rapide

## Fonctionnalités principales

## Exemples

## Documentation

## Citation

## Contribution

## Licence
```

**Exemple de code minimal** :

```r
library(nemeton)

# Charger des unités
units <- nemeton_units(st_read("parcelles.gpkg"))

# Charger des couches
layers <- nemeton_layers(
  rasters = list(ndvi = "ndvi.tif", dem = "dem.tif"),
  vectors = list(hydro = "rivers.gpkg")
)

# Calculer les indicateurs
results <- nemeton_compute(units, layers)

# Visualiser
nemeton_map(results, "carbon")
```

### 10.2 Vignettes

#### `vignettes/intro-nemeton.Rmd`

**Objectif** : Introduction à la méthode et au package

**Contenu** :
- Qu'est-ce que la méthode Néméton ?
- Philosophie du package
- Concepts clés (unités, indicateurs, indices)
- Installation et dépendances

#### `vignettes/workflow-basic.Rmd`

**Objectif** : Workflow complet de A à Z

**Contenu** :
1. Définir des unités d'analyse
2. Charger des couches spatiales
3. Calculer des indicateurs
4. Normaliser et agréger
5. Visualiser les résultats
6. Exporter vers QGIS

**Dataset** : massif forestier fictif de 50 parcelles

#### `vignettes/multi-temporal.Rmd`

**Objectif** : Analyse diachronique

**Contenu** :
1. Créer un projet multi-époques
2. Ajouter des états (1950, 2020, 2050)
3. Comparer les changements
4. Visualiser les trajectoires
5. Identifier les tendances

**Dataset** : évolution d'une forêt sur 100 ans

#### `vignettes/custom-indicators.Rmd`

**Objectif** : Créer ses propres indicateurs

**Contenu** :
1. Anatomie d'un indicateur
2. Écrire une fonction d'indicateur
3. Enregistrer l'indicateur
4. L'utiliser dans nemeton_compute()
5. Exemples : indicateur de maturité forestière, connectivité écologique

#### `vignettes/integration-targets.Rmd`

**Objectif** : Automatisation avec {targets}

**Contenu** :
1. Pourquoi targets ?
2. Structure d'un projet targets + nemeton
3. Définir un pipeline
4. Exécuter et visualiser
5. Mise à jour incrémentale

**Code** :
```r
# _targets.R
library(targets)
library(nemeton)

tar_option_set(packages = c("nemeton", "sf", "terra"))

list(
  tar_target(units, nemeton_units(st_read("data/parcelles.gpkg"))),
  tar_target(layers, nemeton_layers(
    rasters = list(ndvi = "data/ndvi.tif"),
    vectors = list(hydro = "data/hydro.gpkg")
  )),
  tar_target(results, nemeton_compute(units, layers)),
  tar_target(indices, nemeton_index(results)),
  tar_target(map_carbon, nemeton_map(results, "carbon"))
)
```

### 10.3 Documentation des fonctions (roxygen2)

**Template standard** :

```r
#' Calculer les indicateurs Néméton
#'
#' Calcule un ensemble d'indicateurs spatiaux pour des unités forestières
#' à partir de couches géospatiales.
#'
#' @param units Un objet \code{nemeton_units} ou \code{sf} représentant
#'   les unités d'analyse.
#' @param layers Un objet \code{nemeton_layers} contenant les couches spatiales.
#' @param indicators Vecteur de noms d'indicateurs à calculer, ou \code{"all"}
#'   pour tous les indicateurs disponibles.
#' @param preprocess Logique. Si \code{TRUE}, harmonise automatiquement les CRS
#'   et découpe les couches sur l'emprise des unités.
#' @param parallel Logique. Si \code{TRUE}, utilise le backend \code{future}
#'   pour le calcul parallèle.
#' @param progress Logique. Afficher une barre de progression ?
#' @param ... Arguments additionnels passés aux fonctions d'indicateurs.
#'
#' @return Un objet \code{sf} identique à \code{units} avec des colonnes
#'   additionnelles pour chaque indicateur calculé.
#'
#' @details
#' Les indicateurs disponibles peuvent être listés avec \code{list_indicators()}.
#' Chaque indicateur est calculé indépendamment ; les erreurs pour un indicateur
#' spécifique génèrent un avertissement mais n'arrêtent pas le calcul des autres.
#'
#' Si \code{preprocess = TRUE}, la fonction vérifie la compatibilité des CRS
#' entre \code{units} et chaque couche, et reprojette si nécessaire dans le CRS
#' de \code{units}.
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#'
#' # Charger des unités
#' units <- nemeton_units(st_read("parcelles.gpkg"))
#'
#' # Charger des couches
#' layers <- nemeton_layers(
#'   rasters = list(ndvi = "ndvi.tif", dem = "dem.tif")
#' )
#'
#' # Calculer tous les indicateurs
#' results <- nemeton_compute(units, layers)
#'
#' # Calculer seulement certains indicateurs
#' results <- nemeton_compute(
#'   units, layers,
#'   indicators = c("carbon", "biodiversity", "water")
#' )
#' }
#'
#' @seealso
#' \code{\link{nemeton_units}}, \code{\link{nemeton_layers}},
#' \code{\link{list_indicators}}
#'
#' @export
nemeton_compute <- function(units, layers, indicators = "all",
                            preprocess = TRUE, parallel = FALSE,
                            progress = TRUE, ...) {
  # Implementation
}
```

### 10.4 Site web (pkgdown)

**Configuration** : `_pkgdown.yml`

```yaml
url: https://yourorg.github.io/nemeton

template:
  bootstrap: 5

reference:
  - title: "Workflow principal"
    desc: "Fonctions de haut niveau pour le workflow Néméton"
    contents:
      - nemeton_units
      - nemeton_layers
      - nemeton_compute
      - nemeton_index

  - title: "Analyse temporelle"
    contents:
      - nemeton_project
      - add_epoch
      - nemeton_compare

  - title: "Indicateurs biophysiques"
    contents:
      - starts_with("indicator_carbon")
      - starts_with("indicator_biodiversity")
      - starts_with("indicator_water")

  - title: "Visualisation"
    contents:
      - nemeton_map
      - nemeton_radar
      - nemeton_timeline

articles:
  - title: "Tutoriels"
    contents:
      - intro-nemeton
      - workflow-basic
      - multi-temporal
      - custom-indicators
      - integration-targets
```

---

## 11. Extensibilité et personnalisation

### 11.1 Système d'indicateurs modulaire

Les utilisateurs peuvent ajouter leurs propres indicateurs de deux façons :

#### Approche 1 : Fonction inline

```r
results <- nemeton_compute(
  units = my_units,
  layers = my_layers,
  indicators = list(
    "carbon",  # indicateur built-in
    custom_maturity = function(units, layers) {
      # Calcul personnalisé
      maturity_scores <- ...
      return(maturity_scores)
    }
  )
)
```

#### Approche 2 : Enregistrement global

```r
# Définir l'indicateur
my_indicator <- nemeton_indicator(
  name = "forest_maturity",
  category = "biophysical",
  fun = function(units, layers, age_threshold = 100) {
    # Extraction de l'âge depuis un raster
    ages <- exactextractr::exact_extract(
      layers$rasters$forest_age,
      units,
      fun = "mean"
    )
    # Score de maturité
    scores <- ifelse(ages >= age_threshold, 1, ages / age_threshold)
    return(scores * 100)
  },
  dependencies = c("forest_age"),
  description = "Indice de maturité forestière basé sur l'âge moyen",
  params = list(age_threshold = 100)
)

# Enregistrer
register_indicator(my_indicator)

# Utiliser
results <- nemeton_compute(units, layers, indicators = "forest_maturity")
```

### 11.2 Personnalisation des poids

```r
# Définir des poids custom
my_weights <- c(
  carbon = 0.25,
  biodiversity = 0.30,
  water = 0.20,
  soil = 0.15,
  landscape = 0.10
)

# Calculer l'indice
indices <- nemeton_index(results, weights = my_weights)

# Ou par groupes thématiques
thematic <- list(
  ecological = c("biodiversity", "water", "soil"),
  climate = c("carbon", "climate_risk"),
  social = c("accessibility", "heritage")
)

indices <- nemeton_index(results, thematic_groups = thematic)
```

### 11.3 Personnalisation des visualisations

Toutes les fonctions de visualisation retournent des objets `ggplot`, personnalisables :

```r
# Carte de base
p <- nemeton_map(results, "carbon")

# Personnalisation
p +
  scale_fill_viridis_c(option = "plasma", name = "Stock de carbone\n(t/ha)") +
  theme_minimal() +
  labs(title = "Stock de carbone - Forêt de Fontainebleau",
       subtitle = "Année 2024") +
  theme(legend.position = "bottom")
```

### 11.4 Hooks et callbacks

Possibilité d'ajouter des hooks à certaines étapes (avancé) :

```r
# Hook exécuté après calcul de chaque indicateur
options(nemeton.post_indicator_hook = function(indicator_name, values, units) {
  message("Calculé : ", indicator_name, " | Moyenne : ", mean(values, na.rm = TRUE))
})

results <- nemeton_compute(units, layers)
# → affiche les moyennes au fur et à mesure
```

---

## 12. Feuille de route

### 12.1 Version 0.1.0 (MVP - 3 mois)

**Objectif** : Package fonctionnel minimal

- [x] Structure du package
- [ ] Module `data-units` : création et validation
- [ ] Module `data-layers` : chargement et catalogage
- [ ] Module `data-preprocessing` : harmonisation basique
- [ ] 5 indicateurs biophysiques essentiels :
  - `indicator_carbon()`
  - `indicator_biodiversity()`
  - `indicator_water()`
  - `indicator_fragmentation()`
  - `indicator_accessibility()`
- [ ] Fonction `nemeton_compute()` complète
- [ ] Normalisation et indices (`nemeton_index()`)
- [ ] 2 visualisations de base :
  - `nemeton_map()`
  - `nemeton_radar()`
- [ ] Documentation complète (README, 1 vignette intro)
- [ ] Tests unitaires (couverture >= 70%)
- [ ] Dataset d'exemple `massif_demo`

**Livrables** :
- Package installable depuis GitHub
- Documentation pkgdown
- 1 article de blog d'introduction

---

### 12.2 Version 0.2.0 (Multi-temporel - 2 mois)

**Objectif** : Support de l'analyse diachronique

- [ ] Classe `nemeton_project`
- [ ] Fonction `add_epoch()`
- [ ] Fonction `nemeton_compare()`
- [ ] Visualisations temporelles :
  - `nemeton_timeline()`
  - `nemeton_radar_compare()`
- [ ] Vignette "Analyse multi-temporelle"
- [ ] Tests d'intégration temporels

**Livrables** :
- Package v0.2.0 sur GitHub
- Article : "Suivre l'évolution de votre forêt avec nemeton"

---

### 12.3 Version 0.3.0 (Extensibilité - 2 mois)

**Objectif** : Personnalisation avancée

- [ ] Système `nemeton_indicator()` formalisé
- [ ] `register_indicator()` global
- [ ] 5 indicateurs additionnels (paysage, social)
- [ ] Support de fonctions custom inline
- [ ] Vignette "Créer vos indicateurs"
- [ ] Export vers formats multiples (GeoPackage, GeoJSON, shapefile)

**Livrables** :
- Package v0.3.0
- Tutoriel vidéo : "Ajouter un indicateur personnalisé"

---

### 12.4 Version 0.4.0 (Performance - 1 mois)

**Objectif** : Optimisation pour grands territoires

- [ ] Support calcul parallèle (`future` backend)
- [ ] Chunking pour rasters volumineux
- [ ] Optimisation mémoire (chargement lazy avancé)
- [ ] Benchmarks et profiling
- [ ] Tests de performance (1000+ unités)

**Livrables** :
- Package v0.4.0
- Rapport de performance

---

### 12.5 Version 0.5.0 (Intégrations - 2 mois)

**Objectif** : Écosystème étendu

- [ ] Support API externes (Copernicus, IGN)
- [ ] Intégration targets (vignette dédiée)
- [ ] Export rapports HTML/PDF (Rmarkdown templates)
- [ ] Interface Shiny exploratoire (package séparé ou module)

**Livrables** :
- Package v0.5.0
- Application Shiny de démonstration

---

### 12.6 Version 1.0.0 (Stable - 3 mois)

**Objectif** : Publication CRAN

- [ ] Refactoring API (stabilisation)
- [ ] Documentation exhaustive
- [ ] Vignettes complètes (5 minimum)
- [ ] Tests complets (couverture >= 90%)
- [ ] Revue externe de code
- [ ] Soumission CRAN

**Livrables** :
- Package sur CRAN
- Article scientifique (Journal of Open Source Software)
- Site web complet

---

### 12.7 Post-1.0 (Évolutions futures)

**Idées** :
- Support rasters cloud-optimized (COG)
- Intégration avec Earth Engine (rgee)
- Module d'optimisation (scénarios de gestion)
- Support 3D (lidar, canopy height)
- API REST pour calculs à la demande
- Package Python (port ou binding)

---

## Annexes

### A. Conventions de nommage

**Fonctions exportées** :
- Préfixe `nemeton_` pour fonctions principales
- Préfixe `indicator_` pour indicateurs
- Verbes à l'infinitif : `compute`, `normalize`, `compare`

**Arguments** :
- `snake_case`
- Noms explicites : `normalize_method` plutôt que `method`

**Objets S3** :
- `nemeton_units`, `nemeton_layers`, `nemeton_project`

**Fichiers** :
- `nom-module.R` (tirets)
- `test-nom-module.R` pour tests

### B. Style de code

- **Linter** : `lintr::lint_package()`
- **Formatter** : `styler::style_pkg()`
- **Guide** : Tidyverse style guide
- **Longueur de ligne** : <= 80 caractères
- **Indentation** : 2 espaces

### C. Workflow de contribution

1. Fork + branche feature
2. Développement + tests
3. `devtools::check()` sans erreurs ni warnings
4. Pull request avec description claire
5. Revue de code
6. Merge après approbation

### D. Ressources externes

**Données open data recommandées** :
- IGN (France) : BD Forêt, MNT, orthophotos
- Copernicus : Sentinel-2 (NDVI), Corine Land Cover
- OpenStreetMap : routes, sentiers, POI
- Natura 2000 : zones protégées
- INPN : biodiversité

**Packages R inspirants** :
- `landscapemetrics` : métriques paysagères
- `biodivMapR` : cartographie de biodiversité
- `rgugik` : accès données polonaises (modèle pour API)
- `rstac` : accès STAC pour imagerie satellite

---

## Changelog

### Version 1.0.0 (2026-01-04)
- Spécification initiale complète
- Architecture du package définie
- API et modules décrits
- Feuille de route établie

---

**Fin de la spécification technique**
