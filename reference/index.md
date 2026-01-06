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
- [`massif_demo_units_extended`](https://pobsteta.github.io/nemeton/reference/massif_demo_units_extended.md)
  : Complete Demo Dataset with 12-Family Ecosystem Services Referential
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

## Family B: Biodiversity / Famille B : Biodiversité (v0.3.0)

Biodiversity protection, structure, and connectivity / Protection,
diversité structurelle et connectivité écologique

- [`indicator_biodiversity_protection()`](https://pobsteta.github.io/nemeton/reference/indicator_biodiversity_protection.md)
  : Calculate Protected Area Coverage (B1)
- [`indicator_biodiversity_structure()`](https://pobsteta.github.io/nemeton/reference/indicator_biodiversity_structure.md)
  : Calculate Structural Diversity (B2)
- [`indicator_biodiversity_connectivity()`](https://pobsteta.github.io/nemeton/reference/indicator_biodiversity_connectivity.md)
  : Calculate Ecological Connectivity (B3)

## Family R: Risk & Resilience / Famille R : Risques & Résilience (v0.3.0)

Fire, storm, and drought vulnerability / Vulnérabilité aux incendies,
tempêtes et sécheresse

- [`indicator_risk_fire()`](https://pobsteta.github.io/nemeton/reference/indicator_risk_fire.md)
  : Calculate Fire Risk Index (R1)
- [`indicator_risk_storm()`](https://pobsteta.github.io/nemeton/reference/indicator_risk_storm.md)
  : Calculate Storm Vulnerability Index (R2)
- [`indicator_risk_drought()`](https://pobsteta.github.io/nemeton/reference/indicator_risk_drought.md)
  : Calculate Drought Stress Index (R3)

## Family T: Temporal Dynamics / Famille T : Dynamique temporelle (v0.3.0)

Forest age and land cover change / Ancienneté des peuplements et
changements d’occupation

- [`indicator_temporal_age()`](https://pobsteta.github.io/nemeton/reference/indicator_temporal_age.md)
  : Calculate Stand Age Index (T1)
- [`indicator_temporal_change()`](https://pobsteta.github.io/nemeton/reference/indicator_temporal_change.md)
  : Calculate Land Cover Change Rate Index (T2)

## Family A: Air & Microclimate / Famille A : Air & Microclimat (v0.3.0)

Tree coverage and air quality / Couverture arborée et qualité de l’air

- [`indicator_air_coverage()`](https://pobsteta.github.io/nemeton/reference/indicator_air_coverage.md)
  : Calculate Tree Coverage Buffer Index (A1)
- [`indicator_air_quality()`](https://pobsteta.github.io/nemeton/reference/indicator_air_quality.md)
  : Calculate Air Quality Index (A2)

## Family S: Social & Recreation / Famille S : Social & Usages récréatifs (v0.4.0)

Trail density, accessibility, and population proximity / Densité de
sentiers, accessibilité et proximité population

- [`indicator_social_trails()`](https://pobsteta.github.io/nemeton/reference/indicator_social_trails.md)
  : S1: Trail Density Indicator
- [`indicator_social_accessibility()`](https://pobsteta.github.io/nemeton/reference/indicator_social_accessibility.md)
  : S2: Multimodal Accessibility Indicator
- [`indicator_social_proximity()`](https://pobsteta.github.io/nemeton/reference/indicator_social_proximity.md)
  : S3: Population Proximity Indicator

## Family P: Production & Economy / Famille P : Production & Économie (v0.4.0)

Wood volume, site productivity, and timber quality / Volume bois,
productivité station et qualité bois d’œuvre

- [`indicator_productive_volume()`](https://pobsteta.github.io/nemeton/reference/indicator_productive_volume.md)
  : P1: Standing Timber Volume Indicator
- [`indicator_productive_station()`](https://pobsteta.github.io/nemeton/reference/indicator_productive_station.md)
  : P2: Site Productivity Index Indicator
- [`indicator_productive_quality()`](https://pobsteta.github.io/nemeton/reference/indicator_productive_quality.md)
  : P3: Timber Quality Score Indicator

## Family E: Energy & Climate / Famille E : Énergie & Climat (v0.4.0)

Fuelwood potential and carbon avoidance / Potentiel bois-énergie et
évitement carbone

- [`indicator_energy_fuelwood()`](https://pobsteta.github.io/nemeton/reference/indicator_energy_fuelwood.md)
  : E1: Fuelwood Potential Indicator
- [`indicator_energy_avoidance()`](https://pobsteta.github.io/nemeton/reference/indicator_energy_avoidance.md)
  : E2: Carbon Emission Avoidance Indicator

## Family N: Naturalness & Wilderness / Famille N : Naturalité (v0.4.0)

Infrastructure distance, forest continuity, and wilderness composite /
Distance infrastructures, continuité forestière et indice wilderness

- [`indicator_naturalness_distance()`](https://pobsteta.github.io/nemeton/reference/indicator_naturalness_distance.md)
  : N1: Infrastructure Distance Indicator
- [`indicator_naturalness_continuity()`](https://pobsteta.github.io/nemeton/reference/indicator_naturalness_continuity.md)
  : N2: Forest Continuity Indicator
- [`indicator_naturalness_composite()`](https://pobsteta.github.io/nemeton/reference/indicator_naturalness_composite.md)
  : N3: Composite Naturalness Index

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

## Cross-Family Analysis / Analyse Croisée Inter-Familles (v0.3.0)

Correlation analysis and multi-criteria hotspot identification / Analyse
de corrélations et identification de hotspots multi-critères

- [`compute_family_correlations()`](https://pobsteta.github.io/nemeton/reference/compute_family_correlations.md)
  : Compute Correlation Matrix Between Family Indices
- [`identify_hotspots()`](https://pobsteta.github.io/nemeton/reference/identify_hotspots.md)
  : Identify Multi-Criteria Hotspots
- [`plot_correlation_matrix()`](https://pobsteta.github.io/nemeton/reference/plot_correlation_matrix.md)
  : Plot Correlation Matrix Heatmap

## Advanced Multi-Criteria Analysis / Analyse Avancée Multi-Critères (v0.4.0)

Pareto optimality, clustering, and trade-off analysis / Optimisation
Pareto, clustering et analyse de trade-offs

- [`identify_pareto_optimal()`](https://pobsteta.github.io/nemeton/reference/identify_pareto_optimal.md)
  : Identify Pareto Optimal Solutions
- [`cluster_parcels()`](https://pobsteta.github.io/nemeton/reference/cluster_parcels.md)
  : Cluster Parcels by Multi-Family Profiles
- [`plot_tradeoff()`](https://pobsteta.github.io/nemeton/reference/plot_tradeoff.md)
  : Plot Trade-off Analysis Between Two Objectives

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
