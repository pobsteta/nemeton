# Package index

## Data Management / Gestion des données

Create and manage spatial units and layers / Créer et gérer les unités
spatiales et les couches

- [`nemeton_units()`](https://pobsteta.github.io/nemeton/reference/nemeton_units.md)
  : Create nemeton_units object
- [`nemeton_layers()`](https://pobsteta.github.io/nemeton/reference/nemeton_layers.md)
  : Create nemeton_layers object
- [`massif_demo_units`](https://pobsteta.github.io/nemeton/reference/massif_demo_units.md)
  : Massif Demo - Example Forest Dataset
- [`massif_demo_layers()`](https://pobsteta.github.io/nemeton/reference/massif_demo_layers.md)
  : Load Massif Demo Spatial Layers

## Core Workflow / Workflow principal

Main functions for indicator calculation / Fonctions principales pour le
calcul d’indicateurs

- [`nemeton_compute()`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md)
  : Calculate Nemeton indicators for spatial units
- [`list_indicators()`](https://pobsteta.github.io/nemeton/reference/list_indicators.md)
  : List available indicators

## Family C: Carbon & Vitality / Famille C : Carbone & Vitalité

Carbon storage and vegetation vitality indicators / Indicateurs de
stockage de carbone et de vitalité de la végétation

- [`indicator_carbon()`](https://pobsteta.github.io/nemeton/reference/indicator_carbon.md)
  : Calculate carbon stock indicator
- [`indicator_carbon_biomass()`](https://pobsteta.github.io/nemeton/reference/indicator_carbon_biomass.md)
  : Carbon Stock via Biomass and Allometric Models (C1)
- [`indicator_carbon_ndvi()`](https://pobsteta.github.io/nemeton/reference/indicator_carbon_ndvi.md)
  : NDVI Mean and Trend Analysis (C2)

## Family W: Water Regulation / Famille W : Régulation de l’eau

Hydrological regulation and water-related indicators / Indicateurs de
régulation hydrologique et relatifs à l’eau

- [`indicator_water()`](https://pobsteta.github.io/nemeton/reference/indicator_water.md)
  : Calculate water regulation indicator
- [`indicator_water_network()`](https://pobsteta.github.io/nemeton/reference/indicator_water_network.md)
  : Hydrographic Network Density (W1)
- [`indicator_water_wetlands()`](https://pobsteta.github.io/nemeton/reference/indicator_water_wetlands.md)
  : Wetland Coverage (W2)
- [`indicator_water_twi()`](https://pobsteta.github.io/nemeton/reference/indicator_water_twi.md)
  : Topographic Wetness Index (W3)

## Family F: Soil Fertility / Famille F : Fertilité des sols

Soil quality and erosion risk indicators / Indicateurs de qualité du sol
et de risque d’érosion

- [`indicator_soil_fertility()`](https://pobsteta.github.io/nemeton/reference/indicator_soil_fertility.md)
  : Soil Fertility Class (F1)
- [`indicator_soil_erosion()`](https://pobsteta.github.io/nemeton/reference/indicator_soil_erosion.md)
  : Erosion Risk Index (F2)

## Family L: Landscape Quality / Famille L : Qualité du paysage

Landscape structure and connectivity indicators / Indicateurs de
structure du paysage et de connectivité

- [`indicator_landscape_fragmentation()`](https://pobsteta.github.io/nemeton/reference/indicator_landscape_fragmentation.md)
  : Landscape Fragmentation (L1)
- [`indicator_landscape_edge()`](https://pobsteta.github.io/nemeton/reference/indicator_landscape_edge.md)
  : Edge-to-Area Ratio (L2)

## Other Indicators (v0.1.0) / Autres indicateurs (v0.1.0)

Biodiversity, fragmentation, accessibility indicators / Indicateurs de
biodiversité, fragmentation, accessibilité

- [`indicator_biodiversity()`](https://pobsteta.github.io/nemeton/reference/indicator_biodiversity.md)
  : Calculate biodiversity indicator
- [`indicator_fragmentation()`](https://pobsteta.github.io/nemeton/reference/indicator_fragmentation.md)
  : Calculate forest fragmentation indicator
- [`indicator_accessibility()`](https://pobsteta.github.io/nemeton/reference/indicator_accessibility.md)
  : Calculate accessibility indicator

## Temporal Analysis / Analyse temporelle

Multi-period analysis and change detection / Analyse multi-périodes et
détection de changements

- [`nemeton_temporal()`](https://pobsteta.github.io/nemeton/reference/nemeton_temporal.md)
  : Create Multi-Period Temporal Dataset
- [`calculate_change_rate()`](https://pobsteta.github.io/nemeton/reference/calculate_change_rate.md)
  : Calculate Change Rates Between Periods

## Normalization & Aggregation / Normalisation & Agrégation

Transform and combine indicators / Transformer et combiner les
indicateurs

- [`normalize_indicators()`](https://pobsteta.github.io/nemeton/reference/normalize_indicators.md)
  : Normalize indicator values
- [`create_composite_index()`](https://pobsteta.github.io/nemeton/reference/create_composite_index.md)
  : Create composite index from multiple indicators
- [`create_family_index()`](https://pobsteta.github.io/nemeton/reference/create_family_index.md)
  : Create Family Composite Indices
- [`invert_indicator()`](https://pobsteta.github.io/nemeton/reference/invert_indicator.md)
  : Invert indicator values

## Visualization / Visualisation

Maps and charts for results / Cartes et graphiques pour les résultats

- [`plot_indicators_map()`](https://pobsteta.github.io/nemeton/reference/plot_indicators_map.md)
  : Create thematic maps for indicators
- [`plot_comparison_map()`](https://pobsteta.github.io/nemeton/reference/plot_comparison_map.md)
  : Create comparison map (before/after or scenarios)
- [`plot_difference_map()`](https://pobsteta.github.io/nemeton/reference/plot_difference_map.md)
  : Create difference map (change visualization)
- [`nemeton_radar()`](https://pobsteta.github.io/nemeton/reference/nemeton_radar.md)
  : Create radar chart for indicator profile
- [`plot_temporal_trend()`](https://pobsteta.github.io/nemeton/reference/plot_temporal_trend.md)
  : Plot Temporal Trend (Time-Series)
- [`plot_temporal_heatmap()`](https://pobsteta.github.io/nemeton/reference/plot_temporal_heatmap.md)
  : Plot Temporal Heatmap

## Internationalization / Internationalisation

Multi-language support / Support multi-langues

- [`nemeton_set_language()`](https://pobsteta.github.io/nemeton/reference/nemeton_set_language.md)
  : Set language manually

## S3 Methods / Méthodes S3

Print and summary methods for nemeton objects / Méthodes print et
summary pour les objets nemeton

- [`print(`*`<nemeton_units>`*`)`](https://pobsteta.github.io/nemeton/reference/print.nemeton_units.md)
  : Print method for nemeton_units
- [`print(`*`<nemeton_layers>`*`)`](https://pobsteta.github.io/nemeton/reference/print.nemeton_layers.md)
  : Print method for nemeton_layers
- [`print(`*`<nemeton_temporal>`*`)`](https://pobsteta.github.io/nemeton/reference/print.nemeton_temporal.md)
  : Print Method for nemeton_temporal Objects
- [`summary(`*`<nemeton_units>`*`)`](https://pobsteta.github.io/nemeton/reference/summary.nemeton_units.md)
  : Summary method for nemeton_units
- [`summary(`*`<nemeton_layers>`*`)`](https://pobsteta.github.io/nemeton/reference/summary.nemeton_layers.md)
  : Summary method for nemeton_layers
- [`summary(`*`<nemeton_temporal>`*`)`](https://pobsteta.github.io/nemeton/reference/summary.nemeton_temporal.md)
  : Summary Method for nemeton_temporal Objects

## Package Documentation / Documentation du package

- [`nemeton-package`](https://pobsteta.github.io/nemeton/reference/nemeton-package.md)
  [`nemeton`](https://pobsteta.github.io/nemeton/reference/nemeton-package.md)
  : nemeton: Systemic Forest Analysis Using the Nemeton Method

## Internal Functions / Fonctions internes

Internal helper functions (for developers) / Fonctions d’aide internes
(pour développeurs)

- [`detect_indicator_family()`](https://pobsteta.github.io/nemeton/reference/detect_indicator_family.md)
  : Detect Indicator Family from Name
- [`get_family_name()`](https://pobsteta.github.io/nemeton/reference/get_family_name.md)
  : Get Family Name from Code
- [`family-system`](https://pobsteta.github.io/nemeton/reference/family-system.md)
  : Multi-Family Indicator System
- [`indicators-families`](https://pobsteta.github.io/nemeton/reference/indicators-families.md)
  : Indicator Family Functions - v0.2.0 Extension
- [`temporal`](https://pobsteta.github.io/nemeton/reference/temporal.md)
  : Multi-Temporal Analysis Infrastructure
