# Package index

## Gestion des donnees

Creer et gerer les unites spatiales et les couches

- [`nemeton_units()`](https://pobsteta.github.io/nemeton/reference/nemeton_units.md)
  : Create nemeton_units object
- [`nemeton_layers()`](https://pobsteta.github.io/nemeton/reference/nemeton_layers.md)
  : Create nemeton_layers object
- [`massif_demo_units`](https://pobsteta.github.io/nemeton/reference/massif_demo_units.md)
  : Massif Demo - Example Forest Dataset
- [`massif_demo_layers()`](https://pobsteta.github.io/nemeton/reference/massif_demo_layers.md)
  : Load Massif Demo Spatial Layers

## Workflow principal

Fonctions principales pour le calcul d’indicateurs

- [`nemeton_compute()`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md)
  : Calculate Nemeton indicators for spatial units
- [`list_indicators()`](https://pobsteta.github.io/nemeton/reference/list_indicators.md)
  : List available indicators

## Famille C : Carbone & Vitalite

Stockage de carbone et vitalite de la vegetation

- [`indicateur_c1_biomasse()`](https://pobsteta.github.io/nemeton/reference/indicateur_c1_biomasse.md)
  : Carbon Stock via Biomass and Allometric Models (C1)
- [`indicateur_c2_ndvi()`](https://pobsteta.github.io/nemeton/reference/indicateur_c2_ndvi.md)
  : NDVI Mean and Trend Analysis (C2)

## Famille B : Biodiversite

Protection, diversite structurelle et connectivite ecologique

- [`indicateur_b1_protection()`](https://pobsteta.github.io/nemeton/reference/indicateur_b1_protection.md)
  : Calculate Protected Area Coverage (B1)
- [`indicateur_b2_structure()`](https://pobsteta.github.io/nemeton/reference/indicateur_b2_structure.md)
  : Calculate Structural Diversity (B2)
- [`indicateur_b3_connectivite()`](https://pobsteta.github.io/nemeton/reference/indicateur_b3_connectivite.md)
  : Calculate Ecological Connectivity (B3)
- [`indicateur_b4_div_spectrale()`](https://pobsteta.github.io/nemeton/reference/indicateur_b4_div_spectrale.md)
  : Indicator B4 — Spectral alpha diversity (family B)

## Famille W : Regulation de l’eau

Regulation hydrologique et zones humides

- [`indicateur_w1_reseau()`](https://pobsteta.github.io/nemeton/reference/indicateur_w1_reseau.md)
  : Hydrographic Network Density (W1)
- [`indicateur_w2_zones_humides()`](https://pobsteta.github.io/nemeton/reference/indicateur_w2_zones_humides.md)
  : Wetland Coverage (W2)
- [`indicateur_w3_humidite()`](https://pobsteta.github.io/nemeton/reference/indicateur_w3_humidite.md)
  : Topographic Wetness Index (W3)

## Famille A : Air & Microclimat

Couverture arboree et qualite de l’air

- [`indicateur_a1_couverture()`](https://pobsteta.github.io/nemeton/reference/indicateur_a1_couverture.md)
  : Calculate Tree Coverage Buffer Index (A1)
- [`indicateur_a2_qualite_air()`](https://pobsteta.github.io/nemeton/reference/indicateur_a2_qualite_air.md)
  : Calculate Air Quality Index (A2)

## Famille F : Fertilite des sols

Qualite du sol et risque d’erosion

- [`indicateur_f1_fertilite()`](https://pobsteta.github.io/nemeton/reference/indicateur_f1_fertilite.md)
  : Soil Fertility Class (F1)
- [`indicateur_f2_erosion()`](https://pobsteta.github.io/nemeton/reference/indicateur_f2_erosion.md)
  : Soil Fertility Index (F2)

## Famille L : Paysage

Structure du paysage et connectivite

- [`indicateur_l2_fragmentation()`](https://pobsteta.github.io/nemeton/reference/indicateur_l2_fragmentation.md)
  : Sylvosphere - Edge Effect (L1)
- [`indicateur_l1_sylvosphere()`](https://pobsteta.github.io/nemeton/reference/indicateur_l1_sylvosphere.md)
  : Landscape Fragmentation (L2)
- [`indicateur_l3_het_spectrale()`](https://pobsteta.github.io/nemeton/reference/indicateur_l3_het_spectrale.md)
  : Indicator L3 — Spectral beta diversity / landscape heterogeneity
  (family L)

## Famille T : Dynamique temporelle

Anciennete des peuplements et changements d’occupation

- [`indicateur_t1_anciennete()`](https://pobsteta.github.io/nemeton/reference/indicateur_t1_anciennete.md)
  : Calculate Stand Age Index (T1)
- [`indicateur_t2_changement()`](https://pobsteta.github.io/nemeton/reference/indicateur_t2_changement.md)
  : Calculate Stability / Change Rate Index (T2)
- [`indicateur_t3_coupes_rases()`](https://pobsteta.github.io/nemeton/reference/indicateur_t3_coupes_rases.md)
  : Calculate Clear-cut Pressure Index (T3)

## Famille R : Risques & Resilience

Vulnerabilite aux incendies, tempetes et secheresse

- [`indicateur_r1_feu()`](https://pobsteta.github.io/nemeton/reference/indicateur_r1_feu.md)
  : Calculate Fire Risk Index (R1)
- [`indicateur_r2_tempete()`](https://pobsteta.github.io/nemeton/reference/indicateur_r2_tempete.md)
  : Calculate Storm Vulnerability Index (R2)
- [`indicateur_r3_secheresse()`](https://pobsteta.github.io/nemeton/reference/indicateur_r3_secheresse.md)
  : Calculate Drought Stress Index (R3)
- [`indicateur_r4_abroutissement()`](https://pobsteta.github.io/nemeton/reference/indicateur_r4_abroutissement.md)
  : Calculate Game Browsing Pressure Index (R4)
- [`compute_game_pressure_index()`](https://pobsteta.github.io/nemeton/reference/compute_game_pressure_index.md)
  : Compute Game Browsing Pressure Index by Department
- [`download_hunting_data()`](https://pobsteta.github.io/nemeton/reference/download_hunting_data.md)
  : Download Hunting Statistics from data.gouv.fr
- [`get_game_pressure_raster()`](https://pobsteta.github.io/nemeton/reference/get_game_pressure_raster.md)
  : Get Game Pressure Raster for R4 Indicator

## Famille S : Social & Usages

Distance routes, distance bati et proximite population

- [`indicateur_s1_routes()`](https://pobsteta.github.io/nemeton/reference/indicateur_s1_routes.md)
  : S1: Distance to Roads Indicator
- [`indicateur_s2_bati()`](https://pobsteta.github.io/nemeton/reference/indicateur_s2_bati.md)
  : S2: Distance to Buildings Indicator
- [`indicateur_s3_population()`](https://pobsteta.github.io/nemeton/reference/indicateur_s3_population.md)
  : S3: Population Proximity Indicator

## Famille P : Production & Economie

Volume bois, productivite station et qualite bois d’oeuvre

- [`indicateur_p1_volume()`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md)
  : P1: Standing Timber Volume Indicator
- [`indicateur_p2_station()`](https://pobsteta.github.io/nemeton/reference/indicateur_p2_station.md)
  : P2: Site Productivity Index Indicator
- [`indicateur_p3_qualite_bois()`](https://pobsteta.github.io/nemeton/reference/indicateur_p3_qualite_bois.md)
  : P3: Timber Quality Score Indicator

## Famille E : Energie & Climat

Potentiel bois-energie et evitement carbone

- [`indicateur_e1_bois_energie()`](https://pobsteta.github.io/nemeton/reference/indicateur_e1_bois_energie.md)
  : E1: Fuelwood Potential Indicator
- [`indicateur_e2_evitement()`](https://pobsteta.github.io/nemeton/reference/indicateur_e2_evitement.md)
  : E2: Carbon Emission Avoidance Indicator

## Famille N : Naturalite

Distance infrastructures, continuite forestiere et indice wilderness

- [`indicateur_n1_distance()`](https://pobsteta.github.io/nemeton/reference/indicateur_n1_distance.md)
  : N1: Infrastructure Distance Indicator
- [`indicateur_n2_continuite()`](https://pobsteta.github.io/nemeton/reference/indicateur_n2_continuite.md)
  : N2: Forest Continuity Indicator
- [`indicateur_n3_naturalite()`](https://pobsteta.github.io/nemeton/reference/indicateur_n3_naturalite.md)
  : N3: Composite Naturalness Index

## CHM et indice de station (spec 005)

Nettoyage d’un Canopy Height Model et estimation de l’indice de station
H0

- [`sanitize_chm()`](https://pobsteta.github.io/nemeton/reference/sanitize_chm.md)
  : Sanitize a Canopy Height Model raster
- [`extract_h_dom()`](https://pobsteta.github.io/nemeton/reference/extract_h_dom.md)
  : Extract dominant height from a CHM for a set of spatial units
- [`compute_site_index()`](https://pobsteta.github.io/nemeton/reference/compute_site_index.md)
  : Estimate the site index from a dominant height and a stand age
- [`list_site_index_species()`](https://pobsteta.github.io/nemeton/reference/list_site_index_species.md)
  : List species covered by the site-index curves
- [`read_site_index_curves()`](https://pobsteta.github.io/nemeton/reference/read_site_index_curves.md)
  : Read the site-index reference curves

## Systeme NDP (Niveau De Precision)

Ponderation Fibonacci et confiance phi

- [`ndp_table()`](https://pobsteta.github.io/nemeton/reference/ndp_table.md)
  : NDP levels as a data.frame
- [`get_ndp_level()`](https://pobsteta.github.io/nemeton/reference/get_ndp_level.md)
  : Get NDP level configuration
- [`get_ndp_name()`](https://pobsteta.github.io/nemeton/reference/get_ndp_name.md)
  : Get NDP level name
- [`get_ndp_weight()`](https://pobsteta.github.io/nemeton/reference/get_ndp_weight.md)
  : Get NDP Fibonacci weight
- [`get_ndp_confidence()`](https://pobsteta.github.io/nemeton/reference/get_ndp_confidence.md)
  : Get NDP confidence ratio
- [`compute_general_index()`](https://pobsteta.github.io/nemeton/reference/compute_general_index.md)
  : Compute Fibonacci-weighted general index
- [`compute_general_index_mixed()`](https://pobsteta.github.io/nemeton/reference/compute_general_index_mixed.md)
  : Compute general index with mixed NDP per indicator
- [`detect_ndp()`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md)
  : Detect NDP level and ML augmentation from data

## Configuration essences (ADR-007)

Classification d’essences par region biogeographique

- [`get_species_config()`](https://pobsteta.github.io/nemeton/reference/get_species_config.md)
  : Get species configuration for a region
- [`list_species_classes()`](https://pobsteta.github.io/nemeton/reference/list_species_classes.md)
  : Get species classes for a region
- [`list_species_regions()`](https://pobsteta.github.io/nemeton/reference/list_species_regions.md)
  : List available species regions
- [`map_bdforet_essence()`](https://pobsteta.github.io/nemeton/reference/map_bdforet_essence.md)
  : Map BD Foret essence to NMT species class
- [`map_oso_class()`](https://pobsteta.github.io/nemeton/reference/map_oso_class.md)
  : Map OSO class to possible NMT species classes
- [`get_allometric_key()`](https://pobsteta.github.io/nemeton/reference/get_allometric_key.md)
  : Get allometric key for a species class

## Sources de donnees (ADR-002)

Abstraction des sources par pays

- [`get_country_config()`](https://pobsteta.github.io/nemeton/reference/get_country_config.md)
  : Get country data source configuration
- [`get_data_source()`](https://pobsteta.github.io/nemeton/reference/get_data_source.md)
  : Get data source URL or configuration
- [`get_layer_service()`](https://pobsteta.github.io/nemeton/reference/get_layer_service.md)
  : Get service URL for a layer
- [`get_national_crs()`](https://pobsteta.github.io/nemeton/reference/get_national_crs.md)
  : Get national CRS for a country
- [`get_metric_crs()`](https://pobsteta.github.io/nemeton/reference/get_metric_crs.md)
  : Get metric CRS for a country
- [`get_storage_crs()`](https://pobsteta.github.io/nemeton/reference/get_storage_crs.md)
  : Get storage CRS (pan-European)
- [`list_countries()`](https://pobsteta.github.io/nemeton/reference/list_countries.md)
  : List available countries

## Analyse temporelle

Analyse multi-periodes et detection de changements

- [`nemeton_temporal()`](https://pobsteta.github.io/nemeton/reference/nemeton_temporal.md)
  : Create Multi-Period Temporal Dataset
- [`calculate_change_rate()`](https://pobsteta.github.io/nemeton/reference/calculate_change_rate.md)
  : Calculate Change Rates Between Periods

## Analyse inter-familles

Correlations et hotspots multi-criteres

- [`compute_family_correlations()`](https://pobsteta.github.io/nemeton/reference/compute_family_correlations.md)
  : Compute Correlation Matrix Between Family Indices
- [`identify_hotspots()`](https://pobsteta.github.io/nemeton/reference/identify_hotspots.md)
  : Identify Multi-Criteria Hotspots
- [`plot_correlation_matrix()`](https://pobsteta.github.io/nemeton/reference/plot_correlation_matrix.md)
  : Plot Correlation Matrix Heatmap

## Analyse multi-criteres avancee

Optimisation Pareto, clustering et trade-offs

- [`identify_pareto_optimal()`](https://pobsteta.github.io/nemeton/reference/identify_pareto_optimal.md)
  : Identify Pareto Optimal Solutions
- [`cluster_parcels()`](https://pobsteta.github.io/nemeton/reference/cluster_parcels.md)
  : Cluster Parcels by Multi-Family Profiles
- [`plot_tradeoff()`](https://pobsteta.github.io/nemeton/reference/plot_tradeoff.md)
  : Plot Trade-off Analysis Between Two Objectives

## Normalisation & Agregation

Transformer et combiner les indicateurs

- [`normalize_indicators()`](https://pobsteta.github.io/nemeton/reference/normalize_indicators.md)
  : Normalize indicator values
- [`normalize_indicator()`](https://pobsteta.github.io/nemeton/reference/normalize_indicator.md)
  : Normalize a single indicator to 0-100 scale
- [`create_composite_index()`](https://pobsteta.github.io/nemeton/reference/create_composite_index.md)
  : Create composite index from multiple indicators
- [`create_family_index()`](https://pobsteta.github.io/nemeton/reference/create_family_index.md)
  : Create Family Composite Indices
- [`invert_indicator()`](https://pobsteta.github.io/nemeton/reference/invert_indicator.md)
  : Invert indicator values

## Visualisation

Cartes et graphiques

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

## Internationalisation

Support multi-langues

- [`nemeton_set_language()`](https://pobsteta.github.io/nemeton/reference/nemeton_set_language.md)
  : Set language manually

## Application Shiny

L’application interactive est dans le package separe nemetonshiny.
Installez-le avec remotes::install_github(“pobsteta/nemetonshiny”) puis
lancez nemetonshiny::run_app(language = “fr”).

## Methodes S3

Methodes print et summary pour les objets nemeton

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

## Documentation du package

- [`nemeton-package`](https://pobsteta.github.io/nemeton/reference/nemeton-package.md)
  [`nemeton`](https://pobsteta.github.io/nemeton/reference/nemeton-package.md)
  : nemeton: Systemic Forest Analysis Using the Nemeton Method

## Utilitaires

Fonctions de traitement parallele

- [`smart_map()`](https://pobsteta.github.io/nemeton/reference/smart_map.md)
  : Smart Map with Adaptive Parallelization
- [`smart_map_sf()`](https://pobsteta.github.io/nemeton/reference/smart_map_sf.md)
  : Smart Map for Spatial Data with Row Indices
- [`get_global_cache_dir()`](https://pobsteta.github.io/nemeton/reference/get_global_cache_dir.md)
  : Get global shared cache directory
- [`detect_indicator_family()`](https://pobsteta.github.io/nemeton/reference/detect_indicator_family.md)
  : Detect Indicator Family from Name
- [`get_family_name()`](https://pobsteta.github.io/nemeton/reference/get_family_name.md)
  : Get Family Name from Code

## Internal documentation

Package-level and internal documentation pages

- [`NDP_LEVELS`](https://pobsteta.github.io/nemeton/reference/NDP_LEVELS.md)
  : NDP level definitions
- [`ndp`](https://pobsteta.github.io/nemeton/reference/ndp.md) : NDP
  System (Niveau De Precision)
- [`datasources`](https://pobsteta.github.io/nemeton/reference/datasources.md)
  : Data Source Configuration by Country
- [`family-system`](https://pobsteta.github.io/nemeton/reference/family-system.md)
  : Multi-Family Indicator System
- [`species-config`](https://pobsteta.github.io/nemeton/reference/species-config.md)
  : Species Configuration by Region (ADR-007)
- [`temporal`](https://pobsteta.github.io/nemeton/reference/temporal.md)
  : Multi-Temporal Analysis Infrastructure
- [`indicators-families`](https://pobsteta.github.io/nemeton/reference/indicators-families.md)
  : Indicator Family Functions - v0.2.0 Extension
- [`indicators-energy`](https://pobsteta.github.io/nemeton/reference/indicators-energy.md)
  : Energy & Climate Services Indicators (Family E)
- [`indicators-naturalness`](https://pobsteta.github.io/nemeton/reference/indicators-naturalness.md)
  : Naturalness & Wilderness Character Indicators (Family N)
- [`indicators-productive`](https://pobsteta.github.io/nemeton/reference/indicators-productive.md)
  : Productive & Economic Services Indicators (Family P)
- [`indicators-social`](https://pobsteta.github.io/nemeton/reference/indicators-social.md)
  : Social & Recreational Services Indicators (Family S)

## Suivi sanitaire feuillus — RECONFORT (spec 021)

Domaine de validite de la methode RECONFORT (dieback feuillus,
Centre-Val de Loire). Garde-fou G3 : avertit, ne bloque pas.

- [`RECONFORT_VALIDITY_DEPARTMENTS`](https://pobsteta.github.io/nemeton/reference/RECONFORT_VALIDITY_DEPARTMENTS.md)
  : Department codes covered by the RECONFORT calibration validity zone
- [`RECONFORT_VALIDITY_SPECIES`](https://pobsteta.github.io/nemeton/reference/RECONFORT_VALIDITY_SPECIES.md)
  : Tree species considered valid by the RECONFORT calibration
- [`load_reconfort_validity_zones()`](https://pobsteta.github.io/nemeton/reference/load_reconfort_validity_zones.md)
  : Load the RECONFORT validity zones layer
- [`check_reconfort_validity()`](https://pobsteta.github.io/nemeton/reference/check_reconfort_validity.md)
  : Check whether an AOI lies within the RECONFORT calibration domain
- [`RECONFORT_MODELS`](https://pobsteta.github.io/nemeton/reference/RECONFORT_MODELS.md)
  : RECONFORT Random-Forest model registry
- [`reconfort_model_info()`](https://pobsteta.github.io/nemeton/reference/reconfort_model_info.md)
  : Look up a RECONFORT model registry entry
- [`ensure_reconfort_model()`](https://pobsteta.github.io/nemeton/reference/ensure_reconfort_model.md)
  : Fetch (and cache) a RECONFORT Random-Forest model
- [`RECONFORT_BANDS`](https://pobsteta.github.io/nemeton/reference/RECONFORT_BANDS.md)
  : Sentinel-2 bands used by the RECONFORT indices
- [`reconfort_aoi_tiles()`](https://pobsteta.github.io/nemeton/reference/reconfort_aoi_tiles.md)
  : Sentinel-2 MGRS tile(s) covering an AOI
- [`reconfort_ingest_s2()`](https://pobsteta.github.io/nemeton/reference/reconfort_ingest_s2.md)
  : Acquire Sentinel-2 scenes for an AOI into the IOTA² layout
- [`RECONFORT_OSO_MASK`](https://pobsteta.github.io/nemeton/reference/RECONFORT_OSO_MASK.md)
  : RECONFORT deciduous (OSO 2021) binary mask registry entry
- [`ensure_reconfort_oso_mask()`](https://pobsteta.github.io/nemeton/reference/ensure_reconfort_oso_mask.md)
  : Fetch (and cache) the RECONFORT deciduous (OSO) binary mask
- [`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)
  : Run the RECONFORT broadleaf-dieback map production end-to-end
- [`RECONFORT_CLASSES`](https://pobsteta.github.io/nemeton/reference/RECONFORT_CLASSES.md)
  : Canonical RECONFORT classes by target species
- [`RECONFORT_ALERT_CLASSES`](https://pobsteta.github.io/nemeton/reference/RECONFORT_ALERT_CLASSES.md)
  : Default trustworthy RECONFORT classes for garde-fou G1
- [`RECONFORT_CONFIDENCE_WEIGHTS`](https://pobsteta.github.io/nemeton/reference/RECONFORT_CONFIDENCE_WEIGHTS.md)
  : Provisional RECONFORT confidence weights (garde-fou G1)
- [`read_reconfort_pixel_series()`](https://pobsteta.github.io/nemeton/reference/read_reconfort_pixel_series.md)
  : Read the RECONFORT CRswir/CRre pixel diagnostic series
- [`read_reconfort_alert_mask()`](https://pobsteta.github.io/nemeton/reference/read_reconfort_alert_mask.md)
  : Read the RECONFORT broadleaf-classification raster for a zone

## Suivi sanitaire, monitoring et autres fonctions

Pipelines FORDEAD/FAST, zones de monitoring, validation terrain, corpus
de connaissances, helpers CHM / echantillonnage et utilitaires.

- [`aggregate_plot_metrics()`](https://pobsteta.github.io/nemeton/reference/aggregate_plot_metrics.md)
  : Compute per-plot aggregates from field data

- [`attach_field_data_to_units()`](https://pobsteta.github.io/nemeton/reference/attach_field_data_to_units.md)
  : Attach per-plot field aggregates to a units sf

- [`bai_drift_factor()`](https://pobsteta.github.io/nemeton/reference/bai_drift_factor.md)
  : Species BAI drift factor (Charru 2017)

- [`bdforet_v2_mapping()`](https://pobsteta.github.io/nemeton/reference/bdforet_v2_mapping.md)
  : BD Forêt v2 -\> CV context mapping

- [`build_foret_ancienne_mask()`](https://pobsteta.github.io/nemeton/reference/build_foret_ancienne_mask.md)
  : Build an ancient-forest polygon layer for N2 continuity

- [`build_index_stack()`](https://pobsteta.github.io/nemeton/reference/build_index_stack.md)
  : Build a multi-temporal NDVI or NBR stack from cached Sentinel-2
  bands

- [`build_knowledge_corpus()`](https://pobsteta.github.io/nemeton/reference/build_knowledge_corpus.md)
  : Build (or grow) the RAG knowledge base from the manifest

- [`build_project_monitoring_zones()`](https://pobsteta.github.io/nemeton/reference/build_project_monitoring_zones.md)
  : Build a project's monitoring zones from UGF x BD Forêt v2 strata

- [`cec_to_fertility_score()`](https://pobsteta.github.io/nemeton/reference/cec_to_fertility_score.md)
  : Map SoilGrids CEC values to a 0-100 fertility score

- [`charru_bai_drift_table()`](https://pobsteta.github.io/nemeton/reference/charru_bai_drift_table.md)
  : Charru 2017 BAI drift lookup table

- [`charru_selfthinning_table()`](https://pobsteta.github.io/nemeton/reference/charru_selfthinning_table.md)
  : Charru 2012 self-thinning coefficients table

- [`check_fordead_validity()`](https://pobsteta.github.io/nemeton/reference/check_fordead_validity.md)
  : Check whether an AOI lies within the FORDEAD calibration domain

- [`classify_disturbance()`](https://pobsteta.github.io/nemeton/reference/classify_disturbance.md)
  : Tag each alert with the disturbance type it most likely reflects
  (G2)

- [`compute_dtm_chm_from_laz()`](https://pobsteta.github.io/nemeton/reference/compute_dtm_chm_from_laz.md)
  : Derive DTM and CHM rasters from IGN LiDAR HD point clouds

- [`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md)
  : Compute and persist a FAST alert mask on the 0-4 categorical scale

- [`compute_sample_size()`](https://pobsteta.github.io/nemeton/reference/compute_sample_size.md)
  : Sample size for a target relative error and a given CV

- [`create_monitoring_zone()`](https://pobsteta.github.io/nemeton/reference/create_monitoring_zone.md)
  : Create a monitoring zone (geometry only, no placettes)

- [`create_qgis_project()`](https://pobsteta.github.io/nemeton/reference/create_qgis_project.md)
  [`create_qfield_project()`](https://pobsteta.github.io/nemeton/reference/create_qgis_project.md)
  : Create a QGIS project from a sampling plan

- [`create_sampling_plan()`](https://pobsteta.github.io/nemeton/reference/create_sampling_plan.md)
  : Generate a forest sampling plan (GRTS with graceful fallback)

- [`create_trend_sanitary_plan()`](https://pobsteta.github.io/nemeton/reference/create_trend_sanitary_plan.md)
  :

  Create a SANITARY plot plan on the multi-year `trend` (spec 025)

- [`create_validation_sampling_plan()`](https://pobsteta.github.io/nemeton/reference/create_validation_sampling_plan.md)
  : Create a validation sampling plan over an alert raster (spec 014 A3)

- [`cv_from_bdforet()`](https://pobsteta.github.io/nemeton/reference/cv_from_bdforet.md)
  : Compute an area-weighted CV from a BD Forêt v2 coverage

- [`cv_lookup()`](https://pobsteta.github.io/nemeton/reference/cv_lookup.md)
  : Read a CV value from the typology table

- [`cv_typology()`](https://pobsteta.github.io/nemeton/reference/cv_typology.md)
  : CV typology reference table

- [`db`](https://pobsteta.github.io/nemeton/reference/db.md) : Database
  Connection and Migration Helpers (E6 monitoring)

- [`db_connect()`](https://pobsteta.github.io/nemeton/reference/db_connect.md)
  : Connect to the monitoring database

- [`db_disconnect()`](https://pobsteta.github.io/nemeton/reference/db_disconnect.md)
  : Disconnect from the monitoring database

- [`db_migrate()`](https://pobsteta.github.io/nemeton/reference/db_migrate.md)
  : Apply pending SQL migrations

- [`delete_knowledge_document()`](https://pobsteta.github.io/nemeton/reference/delete_knowledge_document.md)
  : Delete a document and its chunks from the knowledge base

- [`diagnose_s2_cache()`](https://pobsteta.github.io/nemeton/reference/diagnose_s2_cache.md)
  : Diagnose an S2 band cache directory

- [`embed_query()`](https://pobsteta.github.io/nemeton/reference/embed_query.md)
  : Embed a query string into a numeric vector

- [`enable_rag()`](https://pobsteta.github.io/nemeton/reference/enable_rag.md)
  : Enable the RAG knowledge base schema (opt-in migration)

- [`enrich_parcels_bdforet()`](https://pobsteta.github.io/nemeton/reference/enrich_parcels_bdforet.md)
  : Enrich Parcels with BD Forêt V2 Data

- [`estimate_dq_from_hdom()`](https://pobsteta.github.io/nemeton/reference/estimate_dq_from_hdom.md)
  : Estimate a quadratic mean diameter from dominant height

- [`estimate_synthetic_inventory()`](https://pobsteta.github.io/nemeton/reference/estimate_synthetic_inventory.md)
  : Estimate a synthetic stand inventory per unit

- [`extract_pixel_timeseries()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_timeseries.md)
  : Extract a per-pixel NDVI / NBR time series at one geographic point

- [`extract_pixel_trend()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_trend.md)
  : Per-pixel trend diagnostic at a point (composites + Theil-Sen / MK)

- [`extract_trend_series()`](https://pobsteta.github.io/nemeton/reference/extract_trend_series.md)
  : Zone-level trend trajectory (yearly composite series + Theil-Sen
  fit)

- [`field_schema`](https://pobsteta.github.io/nemeton/reference/field_schema.md)
  : Field Data Schema for QField Integration

- [`find_zone_by_project()`](https://pobsteta.github.io/nemeton/reference/find_zone_by_project.md)
  : Find the monitoring zone bound to a project UUID

- [`find_zones_by_project()`](https://pobsteta.github.io/nemeton/reference/find_zones_by_project.md)
  : List the monitoring zones bound to a project UUID

- [`fordead_alert_mask()`](https://pobsteta.github.io/nemeton/reference/fordead_alert_mask.md)
  : Extract an alert mask from a categorical 0-4 raster (spec 014 A1)

- [`FORDEAD_BANDS`](https://pobsteta.github.io/nemeton/reference/FORDEAD_BANDS.md)
  : Sentinel-2 bands required by FORDEAD 2.x

- [`FORDEAD_CLASSES`](https://pobsteta.github.io/nemeton/reference/FORDEAD_CLASSES.md)
  : Canonical ordered FORDEAD anomaly classes

- [`FORDEAD_CONFIDENCE_WEIGHTS`](https://pobsteta.github.io/nemeton/reference/FORDEAD_CONFIDENCE_WEIGHTS.md)
  : Confidence weights from the ONF/DSF FORDEAD validation report

- [`fordead_pipeline`](https://pobsteta.github.io/nemeton/reference/fordead_pipeline.md)
  : FORDEAD Dieback Detection Pipeline (E6.c.1, spec 008)

- [`fordead_pixel_series`](https://pobsteta.github.io/nemeton/reference/fordead_pixel_series.md)
  : FORDEAD pixel CRSWIR diagnostic (spec 008 section 14.4, L2)

- [`fordead_postprocess`](https://pobsteta.github.io/nemeton/reference/fordead_postprocess.md)
  : FORDEAD Post-Processing: Rasters to Alert Clusters (E6.c.2, spec
  008)

- [`fordead_python`](https://pobsteta.github.io/nemeton/reference/fordead_python.md)
  : FORDEAD Python Environment Helpers (E6.c.1, spec 008)

- [`FORDEAD_VALIDITY_DEPARTMENTS`](https://pobsteta.github.io/nemeton/reference/FORDEAD_VALIDITY_DEPARTMENTS.md)
  : Department codes covered by the FORDEAD calibration validity zone

- [`FORDEAD_VALIDITY_SPECIES`](https://pobsteta.github.io/nemeton/reference/FORDEAD_VALIDITY_SPECIES.md)
  : Conifer species considered valid by the FORDEAD calibration

- [`format_citations()`](https://pobsteta.github.io/nemeton/reference/format_citations.md)
  : Format retrieved chunks as a citation block

- [`generate_health_validation_plots()`](https://pobsteta.github.io/nemeton/reference/generate_health_validation_plots.md)
  : Draw a stratified sample of alerts to be validated in the field

- [`get_arbre_schema()`](https://pobsteta.github.io/nemeton/reference/get_arbre_schema.md)
  : Get the arbre layer schema

- [`get_datasource_product()`](https://pobsteta.github.io/nemeton/reference/get_datasource_product.md)
  : Get a sub-product of a multi-product datasource

- [`get_health_validation_schema()`](https://pobsteta.github.io/nemeton/reference/get_health_validation_schema.md)
  : QGIS form schema for the health-validation \`placette\` layer

- [`get_ndp_augmented()`](https://pobsteta.github.io/nemeton/reference/get_ndp_augmented.md)
  : Extract augmentation flags from a detect_ndp() result

- [`get_placette_schema()`](https://pobsteta.github.io/nemeton/reference/get_placette_schema.md)
  : Get the placette layer schema

- [`h_to_dq_params()`](https://pobsteta.github.io/nemeton/reference/h_to_dq_params.md)
  : H_dom -\> D_g calibration table (IFN / Charru)

- [`HEALTH_VALIDATION_CAUSES`](https://pobsteta.github.io/nemeton/reference/HEALTH_VALIDATION_CAUSES.md)
  : Free-form causes proposed in the QGIS form

- [`HEALTH_VALIDATION_CAUSES_FEUILLUS`](https://pobsteta.github.io/nemeton/reference/HEALTH_VALIDATION_CAUSES_FEUILLUS.md)
  :

  Free-form causes proposed in the **broadleaf** validation form

- [`HEALTH_VALIDATION_STADES`](https://pobsteta.github.io/nemeton/reference/HEALTH_VALIDATION_STADES.md)
  : DSF-aligned dieback stages used by the terrain validation form

- [`HEALTH_VALIDATION_STADES_FEUILLUS`](https://pobsteta.github.io/nemeton/reference/HEALTH_VALIDATION_STADES_FEUILLUS.md)
  : DSF DEPERIS broadleaf dieback stages (RECONFORT, spec 021 G4)

- [`import_qgis_gpkg()`](https://pobsteta.github.io/nemeton/reference/import_qgis_gpkg.md)
  [`import_qfield_gpkg()`](https://pobsteta.github.io/nemeton/reference/import_qgis_gpkg.md)
  : Read placettes + arbres layers from a field-returned GPKG

- [`indicateur_r5_deperissement()`](https://pobsteta.github.io/nemeton/reference/indicateur_r5_deperissement.md)
  : Compute the R5 dieback indicator (unified FORDEAD / RECONFORT)

- [`ingest_health_validation()`](https://pobsteta.github.io/nemeton/reference/ingest_health_validation.md)
  : Ingest a health-validation GPKG and update \`alert\` rows

- [`ingest_knowledge_document()`](https://pobsteta.github.io/nemeton/reference/ingest_knowledge_document.md)
  : Ingest a document into the RAG knowledge base

- [`ingest_knowledge_reference()`](https://pobsteta.github.io/nemeton/reference/ingest_knowledge_reference.md)
  : Ingest a reference-only document into the RAG knowledge base

- [`ingest_s2_raw_bands_to_cache()`](https://pobsteta.github.io/nemeton/reference/ingest_s2_raw_bands_to_cache.md)
  : Populate the Sentinel-2 COG cache with raw bands (no DB writes)

- [`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)
  : Ingest a Sentinel-2 time series for the plots of a monitoring zone

- [`knowledge_manifest_path()`](https://pobsteta.github.io/nemeton/reference/knowledge_manifest_path.md)
  : Resolve the path to the knowledge-corpus manifest

- [`knowledge_manifest_vocab()`](https://pobsteta.github.io/nemeton/reference/knowledge_manifest_vocab.md)
  : Controlled vocabularies for the knowledge-corpus manifest

- [`knowledge-corpus`](https://pobsteta.github.io/nemeton/reference/knowledge-corpus.md)
  : Knowledge-corpus manifest and ingestion orchestration (spec 009.2)

- [`list_alerts()`](https://pobsteta.github.io/nemeton/reference/list_alerts.md)
  : List alerts of a zone with G1 default filtering

- [`list_knowledge_documents()`](https://pobsteta.github.io/nemeton/reference/list_knowledge_documents.md)
  : List the documents in the RAG knowledge base

- [`load_fordead_validity_zones()`](https://pobsteta.github.io/nemeton/reference/load_fordead_validity_zones.md)
  : Load the FORDEAD validity zones layer

- [`load_raster_source()`](https://pobsteta.github.io/nemeton/reference/load_raster_source.md)
  : Load a raster datasource as a SpatRaster

- [`load_theia_source()`](https://pobsteta.github.io/nemeton/reference/load_theia_source.md)
  : Load a THEIA datasource as a SpatRaster

- [`monitoring_ingest`](https://pobsteta.github.io/nemeton/reference/monitoring_ingest.md)
  : Sentinel-2 Time Series Ingestion (E6 monitoring)

- [`n_max_selfthinning()`](https://pobsteta.github.io/nemeton/reference/n_max_selfthinning.md)
  : Maximum stand density under self-thinning (Charru 2012)

- [`probe_ign_lidar_tile()`](https://pobsteta.github.io/nemeton/reference/probe_ign_lidar_tile.md)
  : Probe an IGN LiDAR HD tile URL to diagnose download failures

- [`probe_ign_lidar_tiles()`](https://pobsteta.github.io/nemeton/reference/probe_ign_lidar_tiles.md)
  : Batch-probe a vector of IGN LiDAR HD tile URLs

- [`prune_orphan_zone_caches()`](https://pobsteta.github.io/nemeton/reference/prune_orphan_zone_caches.md)
  : Remove cache directories of monitoring zones that no longer exist

- [`qgis_export`](https://pobsteta.github.io/nemeton/reference/qgis_export.md)
  : QGIS Project Export

- [`qgis_import`](https://pobsteta.github.io/nemeton/reference/qgis_import.md)
  : QGIS Project Import and Aggregation

- [`rag`](https://pobsteta.github.io/nemeton/reference/rag.md) : RAG
  knowledge base for AI perspectives (E7 / spec 009)

- [`read_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_mask.md)
  : Read the most recent FAST alert mask for a monitoring zone

- [`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
  : FAST alert raster at native S2 pixel resolution (spec 013)

- [`read_fast_alert_rasters()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_rasters.md)
  : Build the full FAST alert raster set (indices x modes)

- [`read_fordead_dieback_mask()`](https://pobsteta.github.io/nemeton/reference/read_fordead_dieback_mask.md)
  : Read the FORDEAD dieback classified raster for a zone

- [`read_fordead_layer()`](https://pobsteta.github.io/nemeton/reference/read_fordead_layer.md)
  : Read an auxiliary FORDEAD diagnostic raster (model bundle)

- [`read_fordead_pixel_series()`](https://pobsteta.github.io/nemeton/reference/read_fordead_pixel_series.md)
  : Read the FORDEAD CRSWIR pixel diagnostic series

- [`read_knowledge_manifest()`](https://pobsteta.github.io/nemeton/reference/read_knowledge_manifest.md)
  : Read the knowledge-corpus manifest

- [`read_s2_band_raster()`](https://pobsteta.github.io/nemeton/reference/read_s2_band_raster.md)
  : Read a single cached Sentinel-2 band as a SpatRaster

- [`read_s2_band_stack()`](https://pobsteta.github.io/nemeton/reference/read_s2_band_stack.md)
  : Read a multi-temporal stack for one Sentinel-2 band

- [`read_uts_fertility_table()`](https://pobsteta.github.io/nemeton/reference/read_uts_fertility_table.md)
  : Read the UTS → fertility crosswalk shipped with the package

- [`register_monitoring_zone()`](https://pobsteta.github.io/nemeton/reference/register_monitoring_zone.md)
  : Register a monitoring zone and its plots in the database

- [`reset_knowledge_manifest()`](https://pobsteta.github.io/nemeton/reference/reset_knowledge_manifest.md)
  : Reset the writable knowledge manifest to the packaged corpus

- [`resolve_project_dem()`](https://pobsteta.github.io/nemeton/reference/resolve_project_layers.md)
  [`resolve_project_chm()`](https://pobsteta.github.io/nemeton/reference/resolve_project_layers.md)
  : Discover the best available DEM / CHM raster in a Nemeton project

- [`resolve_theia_assets()`](https://pobsteta.github.io/nemeton/reference/resolve_theia_assets.md)
  :

  Looks up a Theia datasource declared in
  `inst/datasources/<country>.json` and returns the matching asset paths
  normalised to `/vsis3/` so that GDAL reads the objects directly from
  the S3 store (call `theia_configure_s3` once first to authenticate).

- [`retrieve_knowledge()`](https://pobsteta.github.io/nemeton/reference/retrieve_knowledge.md)
  : Retrieve the most relevant knowledge chunks for a query

- [`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
  : Run the FORDEAD dieback detection pipeline on a monitoring zone

- [`sampling_plan`](https://pobsteta.github.io/nemeton/reference/sampling_plan.md)
  : Sampling Plan Generator (GRTS + stratification)

- [`schema_to_df()`](https://pobsteta.github.io/nemeton/reference/schema_to_df.md)
  : Convert a schema to a tidy data.frame

- [`stac_search_s2_cdse()`](https://pobsteta.github.io/nemeton/reference/sentinel2_stac.md)
  [`stac_search_s2_pc()`](https://pobsteta.github.io/nemeton/reference/sentinel2_stac.md)
  [`stac_search_s2_theia_muscate()`](https://pobsteta.github.io/nemeton/reference/sentinel2_stac.md)
  : Sentinel-2 STAC Search Helpers (E6 monitoring)

- [`site_index_reference_points()`](https://pobsteta.github.io/nemeton/reference/site_index_reference_points.md)
  : Published calibration points for the site-index curves

- [`smooth_pixel_series()`](https://pobsteta.github.io/nemeton/reference/smooth_pixel_series.md)
  : Robustly smooth a per-pixel spectral series (spec 026)

- [`stac_get_item()`](https://pobsteta.github.io/nemeton/reference/stac_get_item.md)
  : Fetch a single STAC item by id

- [`stac_search_items()`](https://pobsteta.github.io/nemeton/reference/stac_search_items.md)
  : Search a STAC API for items

- [`stac_search_s2()`](https://pobsteta.github.io/nemeton/reference/stac_search_s2.md)
  : Search Sentinel-2 L2A scenes via STAC

- [`tag_field_data_sources()`](https://pobsteta.github.io/nemeton/reference/tag_field_data_sources.md)
  : Tag an sf object with field-data NDP attributes

- [`texture_to_erosion_resistance()`](https://pobsteta.github.io/nemeton/reference/texture_to_erosion_resistance.md)
  : Map soil texture to a 0-100 erosion-resistance score

- [`texture_to_fertility_score()`](https://pobsteta.github.io/nemeton/reference/texture_to_fertility_score.md)
  : Map soil texture to a 0-100 fertility score

- [`theia_configure_s3()`](https://pobsteta.github.io/nemeton/reference/theia_configure_s3.md)
  : Configure GDAL for authenticated THEIA S3 reads

- [`theia_signed_href()`](https://pobsteta.github.io/nemeton/reference/theia_signed_href.md)
  : Resolve a signed THEIA asset URL via the teledetection SDK

- [`theia_stac`](https://pobsteta.github.io/nemeton/reference/theia_stac.md)
  : THEIA STAC resolver

- [`units_add_species_from_raster()`](https://pobsteta.github.io/nemeton/reference/units_add_species_from_raster.md)
  : Add a dominant-species column from a classification raster

- [`validate_field_data()`](https://pobsteta.github.io/nemeton/reference/validate_field_data.md)
  : Validate field data against placette + arbre schemas

- [`validate_knowledge_manifest()`](https://pobsteta.github.io/nemeton/reference/validate_knowledge_manifest.md)
  : Validate the knowledge-corpus manifest

- [`write_knowledge_manifest()`](https://pobsteta.github.io/nemeton/reference/write_knowledge_manifest.md)
  : Write the knowledge-corpus manifest

## Fonctions exportees additionnelles

Primitives et indicateurs recents (a recategoriser par famille/theme)

- [`compute_spectral_diversity()`](https://pobsteta.github.io/nemeton/reference/compute_spectral_diversity.md)
  : Compute spectral diversity rasters (alpha & beta) via biodivMapR
- [`create_qgis_project()`](https://pobsteta.github.io/nemeton/reference/create_qgis_project.md)
  [`create_qfield_project()`](https://pobsteta.github.io/nemeton/reference/create_qgis_project.md)
  : Create a QGIS project from a sampling plan
- [`ensure_inventory_fields()`](https://pobsteta.github.io/nemeton/reference/ensure_inventory_fields.md)
  : Fill in missing inventory fields from a CHM
- [`extract_indicator_value()`](https://pobsteta.github.io/nemeton/reference/extract_indicator_value.md)
  : Extract an indicator's value column from its result
- [`filter_alerts_to_zone()`](https://pobsteta.github.io/nemeton/reference/filter_alerts_to_zone.md)
  : Restrict an alert layer to the UGF zone, at read time (spec 021 L7)
- [`import_qgis_gpkg()`](https://pobsteta.github.io/nemeton/reference/import_qgis_gpkg.md)
  [`import_qfield_gpkg()`](https://pobsteta.github.io/nemeton/reference/import_qgis_gpkg.md)
  : Read placettes + arbres layers from a field-returned GPKG
- [`resolve_project_dem()`](https://pobsteta.github.io/nemeton/reference/resolve_project_layers.md)
  [`resolve_project_chm()`](https://pobsteta.github.io/nemeton/reference/resolve_project_layers.md)
  : Discover the best available DEM / CHM raster in a Nemeton project
- [`indicateur_a3_microclimat()`](https://pobsteta.github.io/nemeton/reference/indicateur_a3_microclimat.md)
  : A3 — summer under-canopy maximum temperature (regeneration
  microclimate)
- [`indicateur_a4_tamponnement()`](https://pobsteta.github.io/nemeton/reference/indicateur_a4_tamponnement.md)
  : A4 — canopy thermal buffering (regeneration microclimate)
- [`indicateur_a5_rafraichissement()`](https://pobsteta.github.io/nemeton/reference/indicateur_a5_rafraichissement.md)
  : Calculate Urban Cooling Index (A5)
- [`indicateur_r6_sensibilite()`](https://pobsteta.github.io/nemeton/reference/indicateur_r6_sensibilite.md)
  : R6 — microsite climate sensitivity (heatwave vs average year)
- [`indicateur_w4_vpd()`](https://pobsteta.github.io/nemeton/reference/indicateur_w4_vpd.md)
  : W4 — summer under-canopy vapour-pressure deficit (regeneration)
- [`indice_priorite_regen()`](https://pobsteta.github.io/nemeton/reference/indice_priorite_regen.md)
  : Regeneration priority index (spec 027 L3)
- [`regen_species_choices()`](https://pobsteta.github.io/nemeton/reference/regen_species_choices.md)
  : Species choices for the reGénération target-species selector
- [`regen_sensibilite()`](https://pobsteta.github.io/nemeton/reference/regen_sensibilite.md)
  : Microclimate exposure per unit — microclimf engine (spec 027 L1)
- [`regen_bilan_hydrique()`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)
  : Soil water balance per unit — BILJOU engine (spec 027 L2)
- [`pai_depuis_nuage()`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md)
  : Plant Area Index from a LiDAR-HD point cloud (spec 027 L1)
- [`tendances_estivales_eobs()`](https://pobsteta.github.io/nemeton/reference/tendances_estivales_eobs.md)
  : Summer E-OBS climate trends over the project area (spec 027 §6,
  branch A)
- [`regeneration_tolerances()`](https://pobsteta.github.io/nemeton/reference/regeneration_tolerances.md)
  : Regeneration tolerance table (per species)
- [`microclimate_detect_years()`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md)
  : Detect the average / heatwave reference years for R6 (spec 027
  §6bis)
- [`microclimate_run()`](https://pobsteta.github.io/nemeton/reference/microclimate_run.md)
  : Run the under-canopy microclimate model (scaffold — spec 027 L1)
- [`prepare_pixel_dieback_series()`](https://pobsteta.github.io/nemeton/reference/prepare_pixel_dieback_series.md)
  : Prepare the derived series for the pixel-dieback plot (CRswir +
  CRre)
- [`read_reconfort_layer()`](https://pobsteta.github.io/nemeton/reference/read_reconfort_layer.md)
  : Read a RECONFORT output raster, masked to the UGF zone by default
  (L7)
- [`reconfort_cache_manifest()`](https://pobsteta.github.io/nemeton/reference/reconfort_cache_manifest.md)
  : Discover the persisted RECONFORT display layers from the cache (L6)
- [`reconfort_latest_complete_year()`](https://pobsteta.github.io/nemeton/reference/reconfort_latest_complete_year.md)
  : Most recent RECONFORT \`s2_year\` whose season is already complete
- [`reconfort_layer_manifest()`](https://pobsteta.github.io/nemeton/reference/reconfort_layer_manifest.md)
  : RECONFORT layer manifest: describe a run's displayable outputs (L6)
- [`reconfort_year_bounds()`](https://pobsteta.github.io/nemeton/reference/reconfort_year_bounds.md)
  : Bounds for a RECONFORT \`s2_year\` picker
- [`run_reticulate_isolated()`](https://pobsteta.github.io/nemeton/reference/run_reticulate_isolated.md)
  : Run a Python/reticulate task in an isolated subprocess (pinned env)
- [`stac_search_s2_cdse()`](https://pobsteta.github.io/nemeton/reference/sentinel2_stac.md)
  [`stac_search_s2_pc()`](https://pobsteta.github.io/nemeton/reference/sentinel2_stac.md)
  [`stac_search_s2_theia_muscate()`](https://pobsteta.github.io/nemeton/reference/sentinel2_stac.md)
  : Sentinel-2 STAC Search Helpers (E6 monitoring)
