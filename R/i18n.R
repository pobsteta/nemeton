#' Internationalization System for nemeton
#'
#' Provides translated messages in French and English based on system locale.
#'
#' @keywords internal
#' @noRd

# Package environment to store language settings
.nemeton_env <- new.env(parent = emptyenv())

#' Get current language setting
#'
#' @return Language code ("fr" or "en")
#' @keywords internal
#' @noRd
get_language <- function() {
  # Check if already set
  if (exists("language", envir = .nemeton_env)) {
    return(.nemeton_env$language)
  }

  # Auto-detect from system locale
  locale <- Sys.getenv("LANG", "en_US.UTF-8")

  # Extract language code (first 2 chars)
  lang <- substr(locale, 1, 2)

  # Default to English if not French
  if (!lang %in% c("fr", "en")) {
    lang <- "en"
  }

  # Store for session
  .nemeton_env$language <- lang

  lang
}

#' Set language manually
#'
#' @param lang Language code ("fr" or "en")
#' @export
#' @examples
#' \dontrun{
#' # Set French
#' nemeton_set_language("fr")
#'
#' # Set English
#' nemeton_set_language("en")
#' }
nemeton_set_language <- function(lang = c("fr", "en")) {
  lang <- match.arg(lang)
  .nemeton_env$language <- lang
  cli::cli_alert_success(msg("language_set", lang = lang))
  invisible(lang)
}

#' Get translated message
#'
#' Internal function to retrieve translated messages.
#'
#' @param key Message key
#' @param ... Named arguments for message interpolation
#' @return Translated message string
#' @keywords internal
#' @noRd
msg <- function(key, ...) {
  lang <- get_language()

  # Get message from dictionary
  message <- .messages[[lang]][[key]]

  if (is.null(message)) {
    # Fallback to English
    message <- .messages[["en"]][[key]]

    if (is.null(message)) {
      # Last resort: return key
      return(key)
    }
  }

  # Interpolate variables if provided
  args <- list(...)
  if (length(args) > 0) {
    message <- do.call(sprintf, c(list(message), args))
  }

  message
}

#' CLI message wrappers with i18n support
#'
#' Wrapper functions that combine cli and translated messages.
#'
#' @keywords internal
#' @noRd
msg_info <- function(key, ...) {
  cli::cli_alert_info(msg(key, ...))
}

msg_success <- function(key, ...) {
  cli::cli_alert_success(msg(key, ...))
}

msg_warn <- function(key, ...) {
  warning(msg(key, ...), call. = FALSE)
}

msg_error <- function(key, ...) {
  cli::cli_abort(msg(key, ...))
}

#' Message dictionary
#'
#' All translatable strings in the package.
#'
#' @keywords internal
#' @noRd
.messages <- list(
  en = list(
    # General
    language_set = "Language set to: %s",

    # nemeton_units
    units_created = "Created nemeton_units: %d features, %s",
    units_missing_geom = "Input data has no geometry column",
    units_not_sf = "Input must be an sf object or path to spatial file",
    units_id_created = "Generated %d unique IDs",

    # nemeton_layers
    layers_created = "Created layer catalog: %d rasters, %d vectors",
    layers_no_input = "At least one of rasters or vectors must be provided",
    layers_no_names = "Layer names are required (use named list)",
    layers_file_missing = "File not found: %s",
    layers_invalid_type = "Invalid layer type: %s (expected SpatRaster or sf)",

    # Preprocessing
    preprocess_start = "Preprocessing layers...",
    preprocess_harmonizing = "Harmonizing CRS...",
    preprocess_crs_harmonized = "CRS harmonized to %s",
    preprocess_cropping = "Cropping layers...",
    preprocess_cropped = "Cropped layers to extent of units (buffer: %dm)",
    preprocess_layer_loaded = "Loaded layer: %s",

    # Indicators
    indicator_computing = "Computing %d indicators...",
    indicator_calculated = "Calculating: %s",
    indicator_computed = "Computed %d/%d indicators",
    indicator_failed = "Indicator '%s' calculation failed",
    indicator_set_na = "Setting '%s' to NA",
    indicator_no_valid = "No valid indicators to compute",

    # Normalization
    normalize_auto_detected = "Auto-detected %d indicators: %s",
    normalize_normalized = "Normalized %d indicators using %s method",
    normalize_missing = "Indicator columns not found: %s",
    normalize_no_indicators = "No indicators found to normalize",
    normalize_ref_missing = "Reference data missing %s, using current data",
    normalize_all_identical = "All values are identical, setting to 50",
    normalize_sd_zero = "Standard deviation is 0, setting to 0",

    # Composite index
    composite_equal_weights = "Using equal weights for %d indicators",
    composite_created = "Created composite index '%s' from %d indicators",
    composite_missing = "Indicators missing: %s",
    composite_weights_length = "Number of weights must match number of indicators",
    composite_weights_negative = "Weights must be non-negative",
    composite_negative_geomean = "Negative values found, using absolute values for geometric mean",

    # Inversion
    invert_inverted = "Inverted %d indicators",

    # Visualization
    viz_no_indicators = "No indicator columns found",
    viz_specify_indicators = "Specify indicators explicitly",
    viz_detected = "Auto-detected %d indicators: %s",
    viz_missing = "Indicator columns not found: %s",
    viz_multiple_no_facet = "Multiple indicators provided but facet = FALSE",
    viz_creating_facet = "Creating faceted plot anyway. Set facet = TRUE or select single indicator.",
    viz_not_sf = "data must be an sf object",
    viz_both_not_sf = "Both data1 and data2 must be sf objects",
    viz_indicator_missing_both = "Indicator '%s' must exist in both datasets",

    # Data demo
    demo_loading = "Loading Massif Demo spatial layers...",
    demo_loaded = "Loaded %d raster layers and %d vector layers",
    demo_pkg_not_found = "Package nemeton not found",
    demo_install_first = "Install the package first: devtools::install()",
    demo_dir_not_found = "Demo data directory not found: %s",
    demo_reinstall = "Reinstall the package to include demo data",
    demo_files_missing = "Missing demo data file%s: %s",

    # v0.2.0 - Temporal analysis
    temporal_created = "Created temporal dataset: %d periods, %d units",
    temporal_no_periods = "No periods provided",
    temporal_alignment_warning = "%d units not present in all periods",
    temporal_change_calculated = "Calculated change rates for %d indicators",
    temporal_period_missing = "Period '%s' not found in temporal dataset",

    # v0.2.0 - Family C: Carbone/\u00c9nerg\u00e9tique
    indicator_carbon_biomass = "Carbon stock via allometric models (C: Carbone/\u00c9nerg\u00e9tique)",
    indicator_carbon_ndvi = "NDVI vitality index (C: Carbone/\u00c9nerg\u00e9tique)",
    carbon_species_missing = "Species column '%s' not found",
    carbon_age_missing = "Age column '%s' not found",
    carbon_density_missing = "Density column '%s' not found",
    carbon_allometric_applied = "Applied allometric equation: %s",

    # v0.2.0 - Family W: Water/Infiltr\u00e9e
    indicator_water_network = "Hydrographic network density (W: Water/Infiltr\u00e9e)",
    indicator_water_wetlands = "Wetland coverage (W: Water/Infiltr\u00e9e)",
    indicator_water_twi = "Topographic Wetness Index (W: Water/Infiltr\u00e9e)",
    water_twi_method = "Using TWI method: %s",
    water_wetland_detected = "Detected %d wetland pixels",

    # v0.2.0 - Family F: Fertilit\u00e9/Riche
    indicator_soil_fertility = "Soil fertility class (F: Fertilit\u00e9/Riche)",
    indicator_soil_erosion = "Soil fertility index TWI+slope (F: Fertilit\u00e9/Riche)",
    soil_fertility_extracted = "Extracted fertility data for %d parcels",
    soil_erosion_calculated = "Calculated erosion risk (slope \u00d7 land cover)",

    # v0.2.0 - Family L: Landscape/Esth\u00e9tique
    indicator_landscape_fragmentation = "Sylvosphere - edge effect (L: Landscape/Esth\u00e9tique)",
    indicator_landscape_edge = "Landscape fragmentation (L: Landscape/Esth\u00e9tique)",
    landscape_patches_detected = "Detected %d forest patches in buffer zone",
    landscape_edge_calculated = "Calculated edge density for %d parcels",

    # v0.2.0 - Family system
    family_index_created = "Created family index '%s' from %d indicators",
    family_weights_applied = "Applied custom weights: %s",
    family_no_indicators = "No indicators found for family '%s'",

    # v0.3.0 - Family B: Biodiversity/Vivant
    indicator_biodiversity_protection = "Protected area coverage (B: Biodiversity/Vivant)",
    indicator_biodiversity_structure = "Structural diversity (B: Biodiversity/Vivant)",
    indicator_biodiversity_connectivity = "Ecological connectivity (B: Biodiversity/Vivant)",
    biodiversity_wfs_fetching = "Fetching protected areas from INPN WFS...",
    biodiversity_wfs_fetched = "Retrieved %d protected area features",
    biodiversity_wfs_failed = "WFS fetch failed, using local data fallback",
    biodiversity_shannon_calculated = "Calculated Shannon diversity H=%0.2f",
    biodiversity_no_bdforet = "No BD Foret data available, using fallback connectivity score (50)",
    biodiversity_b3_components = "B3 components: structural=%d, cost=%d, graph=%d, kernel=%d",
    biodiversity_corridor_distance = "Minimum corridor distance: %0.0f m",

    # v0.3.0 - Family R: Risk & Resilience/Flexible
    indicator_risk_fire = "Fire risk index (R: Risk & Resilience/Flexible)",
    indicator_risk_storm = "Storm vulnerability (R: Risk & Resilience/Flexible)",
    indicator_risk_drought = "Drought stress (R: Risk & Resilience/Flexible)",
    risk_fire_factors = "Fire risk: slope=%0.1f, species=%0.1f, climate=%0.1f",
    risk_storm_factors = "Storm vulnerability: height=%0.1f, density=%0.1f, exposure=%0.1f",
    risk_drought_factors = "Drought stress: TWI=%0.1f, precip=%0.1f, species=%0.1f",
    risk_species_unknown = "Unknown species '%s', using default sensitivity",

    # v0.3.0 - Family T: Temporal Dynamics/Nervur\u00e9e
    indicator_temporal_age = "Stand age (T: Temporal Dynamics/Nervur\u00e9e)",
    indicator_temporal_change = "Land use change rate (T: Temporal Dynamics/Nervur\u00e9e)",
    temporal_age_calculated = "Calculated stand age: median=%0.0f years",
    temporal_change_detected = "Detected %0.2f%% area change over %d years",
    temporal_change_interpretation = "Using interpretation mode: %s",

    # v0.3.0 - Family A: Air Quality & Microclimate/Vaporeuse
    indicator_air_coverage = "Tree coverage buffer (A: Air Quality/Vaporeuse)",
    indicator_air_quality = "Air quality index (A: Air Quality/Vaporeuse)",
    air_coverage_calculated = "Forest coverage in buffer: %0.1f%%",
    air_quality_method = "Using air quality method: %s",
    air_quality_proxy_warning = "ATMO data unavailable, using distance proxy",
    air_quality_roads_distance = "Mean distance to major roads: %0.0f m",
    air_quality_urban_distance = "Mean distance to urban areas: %0.0f m",

    # v0.3.0 - Cross-Family Correlation Analysis (US6)
    correlation_computing = "Computing correlation matrix for %d families using %s method",
    correlation_computed = "Correlation matrix computed: %d x %d",
    correlation_auto_detected = "Auto-detected %d family indices: %s",
    correlation_synergy = "Strong positive correlation detected: %s \u00d7 %s (r=%0.2f)",
    correlation_tradeoff = "Trade-off detected: %s \u00d7 %s (r=%0.2f)",
    hotspot_identifying = "Identifying hotspots: threshold=%0.0f%%, min_families=%d",
    hotspot_identified = "Identified %d hotspot parcels (%0.1f%% of total)",
    hotspot_parcel = "Hotspot parcel %s: high in %d families (%s)",
    hotspot_none = "No hotspots found with current thresholds",
    correlation_matrix_plotting = "Creating correlation matrix heatmap",

    # v0.4.0 - Family S: Social & Recreational/Usages r\u00e9cr\u00e9atifs
    indicator_social_trails = "Distance to roads (S: Social & Recreational)",
    indicator_social_accessibility = "Distance to buildings (S: Social & Recreational)",
    indicator_social_proximity = "Population proximity (S: Social & Recreational)",
    social_population_calculated = "Population within buffers: 5km=%d, 10km=%d, 20km=%d",

    # v0.4.0 - Family P: Productive & Economic/Productif
    indicator_productive_volume = "Standing timber volume (P: Productive & Economic)",
    indicator_productive_station = "Site productivity index (P: Productive & Economic)",
    indicator_productive_quality = "Timber quality score (P: Productive & Economic)",
    productive_volume_calculated = "Standing volume: %0.1f m\u00b3/ha (species: %s)",
    productive_allometry_applied = "Applied IFN equation: %s (DBH=%0.1f cm, H=%0.1f m)",
    productive_station_score = "Station productivity: %0.1f m\u00b3/ha/yr (fertility=%s, climate=%s)",
    productive_quality_assessed = "Timber quality: %0.1f/100 (form=%0.1f, diameter=%0.1f, defects=%0.1f)",

    # v0.4.0 - Family E: Energy & Climate/\u00c9nergie
    indicator_energy_fuelwood = "Mobilizable fuelwood potential (E: Energy & Climate)",
    indicator_energy_avoidance = "Carbon emission avoidance (E: Energy & Climate)",
    energy_fuelwood_calculated = "Fuelwood potential: %0.1f tonnes DM/yr (residues=%0.1f, coppice=%0.1f)",
    energy_avoidance_calculated = "CO2 avoided: %0.1f tCO2eq/yr (energy=%0.1f, material=%0.1f)",
    energy_substitution_scenario = "Substitution scenario: %s (factor=%0.3f kgCO2eq/unit)",

    # v0.4.0 - Family N: Naturalness & Wilderness/Naturalit\u00e9
    indicator_naturalness_distance = "Infrastructure distance (N: Naturalness & Wilderness)",
    indicator_naturalness_continuity = "Forest continuity (N: Naturalness & Wilderness)",
    indicator_naturalness_composite = "Wilderness composite index (N: Naturalness & Wilderness)",
    naturalness_distance_calculated = "Min distance to infrastructure: %0.0f m (roads=%0.0f, buildings=%0.0f)",
    naturalness_continuity_calculated = "Continuous forest patch: %0.1f ha (connectivity=%dm)",
    naturalness_composite_score = "Wilderness score: %0.1f/100 (distance=%0.1f, continuity=%0.1f, age=%0.1f)",

    # v0.4.0 - Advanced Analysis (US7)
    # Pareto analysis
    msg_pareto_computing = "Computing Pareto optimality for %d parcels across %d objectives...",
    msg_pareto_complete = "Found %d Pareto optimal parcels (%.1f%%)",

    # Clustering analysis
    msg_cluster_auto_k = "Determining optimal k using silhouette analysis (k=2 to %d)...",
    msg_cluster_optimal_k = "Optimal k determined: %d (silhouette = %.3f)",
    msg_cluster_computing = "Clustering %d parcels into %d groups using %s...",
    msg_cluster_complete = "Clustering complete. Cluster sizes: %s",

    # Errors
    error_invalid_data_type = "Data must be a data.frame or sf object",
    error_objectives_not_found = "Objectives not found in data: %s",
    error_non_numeric_objectives = "Objectives must be numeric: %s",
    error_maximize_length = "Length of 'maximize' (%d) must match length of 'objectives' (%d)",
    error_na_values = "Variables contain NA values: %s",
    error_families_not_found = "Families not found in data: %s",
    error_non_numeric_families = "Families must be numeric: %s",
    error_invalid_method = "Method must be either 'kmeans' or 'hierarchical'",
    error_k_too_small = "k must be at least 2",
    error_k_too_large = "k must be less than number of parcels (%d)",
    error_ggplot2_required = "Package 'ggplot2' is required for plotting. Install with: install.packages('ggplot2')",
    error_variable_not_found = "Variable '%s' not found in data",
    error_non_numeric_variable = "Variable '%s' must be numeric",
    error_is_optimal_required = "Column 'is_optimal' is required for Pareto frontier overlay. Run identify_pareto_optimal() first.",
    warning_ggrepel_not_installed = "Package 'ggrepel' not installed. Labels may overlap. Install with: install.packages('ggrepel')"
  ),
  fr = list(
    # G\u00e9n\u00e9ral
    language_set = "Langue d\u00e9finie : %s",

    # nemeton_units
    units_created = "Unit\u00e9s nemeton cr\u00e9\u00e9es : %d entit\u00e9s, %s",
    units_missing_geom = "Les donn\u00e9es d'entr\u00e9e n'ont pas de colonne g\u00e9om\u00e9trique",
    units_not_sf = "L'entr\u00e9e doit \u00eatre un objet sf ou un chemin vers un fichier spatial",
    units_id_created = "%d identifiants uniques g\u00e9n\u00e9r\u00e9s",

    # nemeton_layers
    layers_created = "Catalogue de couches cr\u00e9\u00e9 : %d rasters, %d vecteurs",
    layers_no_input = "Au moins un des arguments rasters ou vectors doit \u00eatre fourni",
    layers_no_names = "Les noms de couches sont requis (utilisez une liste nomm\u00e9e)",
    layers_file_missing = "Fichier introuvable : %s",
    layers_invalid_type = "Type de couche invalide : %s (attendu SpatRaster ou sf)",

    # Pr\u00e9traitement
    preprocess_start = "Pr\u00e9traitement des couches...",
    preprocess_harmonizing = "Harmonisation du CRS...",
    preprocess_crs_harmonized = "CRS harmonis\u00e9 vers %s",
    preprocess_cropping = "Recadrage des couches...",
    preprocess_cropped = "Couches recadr\u00e9es \u00e0 l'emprise des unit\u00e9s (buffer : %dm)",
    preprocess_layer_loaded = "Couche charg\u00e9e : %s",

    # Indicateurs
    indicator_computing = "Calcul de %d indicateurs...",
    indicator_calculated = "Calcul en cours : %s",
    indicator_computed = "%d/%d indicateurs calcul\u00e9s",
    indicator_failed = "\u00c9chec du calcul de l'indicateur '%s'",
    indicator_set_na = "D\u00e9finition de '%s' \u00e0 NA",
    indicator_no_valid = "Aucun indicateur valide \u00e0 calculer",

    # Normalisation
    normalize_auto_detected = "%d indicateurs auto-d\u00e9tect\u00e9s : %s",
    normalize_normalized = "%d indicateurs normalis\u00e9s avec la m\u00e9thode %s",
    normalize_missing = "Colonnes d'indicateur introuvables : %s",
    normalize_no_indicators = "Aucun indicateur trouv\u00e9 \u00e0 normaliser",
    normalize_ref_missing = "Donn\u00e9es de r\u00e9f\u00e9rence manquantes %s, utilisation des donn\u00e9es actuelles",
    normalize_all_identical = "Toutes les valeurs sont identiques, d\u00e9finition \u00e0 50",
    normalize_sd_zero = "L'\u00e9cart-type est 0, d\u00e9finition \u00e0 0",

    # Indice composite
    composite_equal_weights = "Utilisation de poids \u00e9gaux pour %d indicateurs",
    composite_created = "Indice composite '%s' cr\u00e9\u00e9 \u00e0 partir de %d indicateurs",
    composite_missing = "Indicateurs manquants : %s",
    composite_weights_length = "Le nombre de poids doit correspondre au nombre d'indicateurs",
    composite_weights_negative = "Les poids doivent \u00eatre non n\u00e9gatifs",
    composite_negative_geomean = "Valeurs n\u00e9gatives trouv\u00e9es, utilisation de valeurs absolues pour la moyenne g\u00e9om\u00e9trique",

    # Inversion
    invert_inverted = "%d indicateurs invers\u00e9s",

    # Visualisation
    viz_no_indicators = "Aucune colonne d'indicateur trouv\u00e9e",
    viz_specify_indicators = "Sp\u00e9cifiez les indicateurs explicitement",
    viz_detected = "%d indicateurs auto-d\u00e9tect\u00e9s : %s",
    viz_missing = "Colonnes d'indicateur introuvables : %s",
    viz_multiple_no_facet = "Plusieurs indicateurs fournis mais facet = FALSE",
    viz_creating_facet = "Cr\u00e9ation d'un graphique \u00e0 facettes. D\u00e9finissez facet = TRUE ou s\u00e9lectionnez un seul indicateur.",
    viz_not_sf = "data doit \u00eatre un objet sf",
    viz_both_not_sf = "data1 et data2 doivent tous deux \u00eatre des objets sf",
    viz_indicator_missing_both = "L'indicateur '%s' doit exister dans les deux jeux de donn\u00e9es",

    # Donn\u00e9es d\u00e9mo
    demo_loading = "Chargement des couches spatiales Massif Demo...",
    demo_loaded = "%d couches raster et %d couches vecteur charg\u00e9es",
    demo_pkg_not_found = "Package nemeton introuvable",
    demo_install_first = "Installez d'abord le package : devtools::install()",
    demo_dir_not_found = "R\u00e9pertoire de donn\u00e9es d\u00e9mo introuvable : %s",
    demo_reinstall = "R\u00e9installez le package pour inclure les donn\u00e9es d\u00e9mo",
    demo_files_missing = "Fichier%s de donn\u00e9es d\u00e9mo manquant%s : %s",

    # v0.2.0 - Analyse temporelle
    temporal_created = "Dataset temporel cr\u00e9\u00e9 : %d p\u00e9riodes, %d unit\u00e9s",
    temporal_no_periods = "Aucune p\u00e9riode fournie",
    temporal_alignment_warning = "%d unit\u00e9s absentes dans certaines p\u00e9riodes",
    temporal_change_calculated = "Taux de changement calcul\u00e9s pour %d indicateurs",
    temporal_period_missing = "P\u00e9riode '%s' introuvable dans le dataset temporel",

    # v0.2.0 - Famille C : Carbone/\u00c9nerg\u00e9tique
    indicator_carbon_biomass = "Stock de carbone via mod\u00e8les allom\u00e9triques (C: Carbone/\u00c9nerg\u00e9tique)",
    indicator_carbon_ndvi = "Indice de vitalit\u00e9 NDVI (C: Carbone/\u00c9nerg\u00e9tique)",
    carbon_species_missing = "Colonne d'essence '%s' introuvable",
    carbon_age_missing = "Colonne d'\u00e2ge '%s' introuvable",
    carbon_density_missing = "Colonne de densit\u00e9 '%s' introuvable",
    carbon_allometric_applied = "\u00c9quation allom\u00e9trique appliqu\u00e9e : %s",

    # v0.2.0 - Famille W : Water/Infiltr\u00e9e
    indicator_water_network = "Densit\u00e9 du r\u00e9seau hydrographique (W: Water/Infiltr\u00e9e)",
    indicator_water_wetlands = "Couverture en zones humides (W: Water/Infiltr\u00e9e)",
    indicator_water_twi = "Indice topographique d'humidit\u00e9 (W: Water/Infiltr\u00e9e)",
    water_twi_method = "M\u00e9thode TWI utilis\u00e9e : %s",
    water_wetland_detected = "%d pixels de zones humides d\u00e9tect\u00e9s",

    # v0.2.0 - Famille F : Fertilit\u00e9/Riche
    indicator_soil_fertility = "Classe de fertilit\u00e9 du sol (F: Fertilit\u00e9/Riche)",
    indicator_soil_erosion = "Indice fertilit\u00e9 TWI+pente (F: Fertilit\u00e9/Riche)",
    soil_fertility_extracted = "Donn\u00e9es de fertilit\u00e9 extraites pour %d parcelles",
    soil_erosion_calculated = "Risque d'\u00e9rosion calcul\u00e9 (pente \u00d7 couvert)",

    # v0.2.0 - Famille L : Landscape/Esth\u00e9tique
    indicator_landscape_fragmentation = "Sylvosph\u00e8re - effet lisi\u00e8re (L: Landscape/Esth\u00e9tique)",
    indicator_landscape_edge = "Fragmentation paysag\u00e8re (L: Landscape/Esth\u00e9tique)",
    landscape_patches_detected = "%d taches foresti\u00e8res d\u00e9tect\u00e9es dans la zone tampon",
    landscape_edge_calculated = "Densit\u00e9 de lisi\u00e8re calcul\u00e9e pour %d parcelles",

    # v0.2.0 - Syst\u00e8me de familles
    family_index_created = "Indice de famille '%s' cr\u00e9\u00e9 \u00e0 partir de %d indicateurs",
    family_weights_applied = "Poids personnalis\u00e9s appliqu\u00e9s : %s",
    family_no_indicators = "Aucun indicateur trouv\u00e9 pour la famille '%s'",

    # v0.3.0 - Famille B : Biodiversit\u00e9/Vivant
    indicator_biodiversity_protection = "Couverture en zones prot\u00e9g\u00e9es (B: Biodiversit\u00e9/Vivant)",
    indicator_biodiversity_structure = "Diversit\u00e9 structurelle (B: Biodiversit\u00e9/Vivant)",
    indicator_biodiversity_connectivity = "Connectivit\u00e9 \u00e9cologique (B: Biodiversit\u00e9/Vivant)",
    biodiversity_wfs_fetching = "R\u00e9cup\u00e9ration des zones prot\u00e9g\u00e9es depuis INPN WFS...",
    biodiversity_wfs_fetched = "%d entit\u00e9s de zones prot\u00e9g\u00e9es r\u00e9cup\u00e9r\u00e9es",
    biodiversity_wfs_failed = "\u00c9chec WFS, utilisation des donn\u00e9es locales",
    biodiversity_shannon_calculated = "Diversit\u00e9 Shannon calcul\u00e9e H=%0.2f",
    biodiversity_no_bdforet = "Pas de donn\u00e9es BD For\u00eat disponibles, score de connectivit\u00e9 par d\u00e9faut (50)",
    biodiversity_b3_components = "Composantes B3 : structurelle=%d, co\u00fbt=%d, graphe=%d, kernel=%d",
    biodiversity_corridor_distance = "Distance minimale au corridor : %0.0f m",

    # v0.3.0 - Famille R : R\u00e9silience/Flexible
    indicator_risk_fire = "Indice de risque incendie (R: R\u00e9silience/Flexible)",
    indicator_risk_storm = "Vuln\u00e9rabilit\u00e9 temp\u00eate (R: R\u00e9silience/Flexible)",
    indicator_risk_drought = "Stress hydrique (R: R\u00e9silience/Flexible)",
    risk_fire_factors = "Risque incendie : pente=%0.1f, essence=%0.1f, climat=%0.1f",
    risk_storm_factors = "Vuln\u00e9rabilit\u00e9 temp\u00eate : hauteur=%0.1f, densit\u00e9=%0.1f, exposition=%0.1f",
    risk_drought_factors = "Stress hydrique : TWI=%0.1f, pr\u00e9cip=%0.1f, essence=%0.1f",
    risk_species_unknown = "Essence inconnue '%s', utilisation sensibilit\u00e9 par d\u00e9faut",

    # v0.3.0 - Famille T : Trame/Nervur\u00e9e
    indicator_temporal_age = "Anciennet\u00e9 du peuplement (T: Trame/Nervur\u00e9e)",
    indicator_temporal_change = "Taux de changement d'occupation (T: Trame/Nervur\u00e9e)",
    temporal_age_calculated = "Anciennet\u00e9 calcul\u00e9e : m\u00e9diane=%0.0f ans",
    temporal_change_detected = "%0.2f%% de changement d\u00e9tect\u00e9 sur %d ans",
    temporal_change_interpretation = "Mode d'interpr\u00e9tation : %s",

    # v0.3.0 - Famille A : Air/Vaporeuse
    indicator_air_coverage = "Couverture arbor\u00e9e buffer (A: Air/Vaporeuse)",
    indicator_air_quality = "Indice qualit\u00e9 de l'air (A: Air/Vaporeuse)",
    air_coverage_calculated = "Couverture foresti\u00e8re dans buffer : %0.1f%%",
    air_quality_method = "M\u00e9thode qualit\u00e9 air utilis\u00e9e : %s",
    air_quality_proxy_warning = "Donn\u00e9es ATMO indisponibles, utilisation proxy distance",
    air_quality_roads_distance = "Distance moyenne routes principales : %0.0f m",
    air_quality_urban_distance = "Distance moyenne zones urbaines : %0.0f m",

    # v0.3.0 - Analyse Crois\u00e9e Inter-Familles (US6)
    correlation_computing = "Calcul matrice de corr\u00e9lation pour %d familles (m\u00e9thode %s)",
    correlation_computed = "Matrice de corr\u00e9lation calcul\u00e9e : %d x %d",
    correlation_auto_detected = "%d indices familles auto-d\u00e9tect\u00e9s : %s",
    correlation_synergy = "Forte corr\u00e9lation positive d\u00e9tect\u00e9e : %s \u00d7 %s (r=%0.2f)",
    correlation_tradeoff = "Conflit d\u00e9tect\u00e9 : %s \u00d7 %s (r=%0.2f)",
    hotspot_identifying = "Identification hotspots : seuil=%0.0f%%, min_familles=%d",
    hotspot_identified = "%d parcelles hotspots identifi\u00e9es (%0.1f%% du total)",
    hotspot_parcel = "Parcelle hotspot %s : \u00e9lev\u00e9e dans %d familles (%s)",
    hotspot_none = "Aucun hotspot trouv\u00e9 avec les seuils actuels",
    correlation_matrix_plotting = "Cr\u00e9ation heatmap matrice de corr\u00e9lation",

    # v0.4.0 - Famille S : Social & Usages r\u00e9cr\u00e9atifs
    indicator_social_trails = "Distance aux routes (S : Social & Usages r\u00e9cr\u00e9atifs)",
    indicator_social_accessibility = "Distance aux b\u00e2timents (S : Social & Usages r\u00e9cr\u00e9atifs)",
    indicator_social_proximity = "Proximit\u00e9 de population (S : Social & Usages r\u00e9cr\u00e9atifs)",
    social_population_calculated = "Population dans les buffers : 5km=%d, 10km=%d, 20km=%d",

    # v0.4.0 - Famille P : Productif & \u00c9conomie foresti\u00e8re
    indicator_productive_volume = "Volume bois sur pied (P : Productif & \u00c9conomie)",
    indicator_productive_station = "Indice productivit\u00e9 station (P : Productif & \u00c9conomie)",
    indicator_productive_quality = "Score qualit\u00e9 bois \u0153uvre (P : Productif & \u00c9conomie)",
    productive_volume_calculated = "Volume sur pied : %0.1f m\u00b3/ha (essence : %s)",
    productive_allometry_applied = "\u00c9quation IFN appliqu\u00e9e : %s (DHP=%0.1f cm, H=%0.1f m)",
    productive_station_score = "Productivit\u00e9 station : %0.1f m\u00b3/ha/an (fertilit\u00e9=%s, climat=%s)",
    productive_quality_assessed = "Qualit\u00e9 bois : %0.1f/100 (forme=%0.1f, diam\u00e8tre=%0.1f, d\u00e9fauts=%0.1f)",

    # v0.4.0 - Famille E : \u00c9nergie & Climat
    indicator_energy_fuelwood = "Potentiel bois-\u00e9nergie mobilisable (E : \u00c9nergie & Climat)",
    indicator_energy_avoidance = "\u00c9vitement \u00e9missions carbone (E : \u00c9nergie & Climat)",
    energy_fuelwood_calculated = "Potentiel bois-\u00e9nergie : %0.1f tonnes MS/an (r\u00e9manents=%0.1f, taillis=%0.1f)",
    energy_avoidance_calculated = "CO2 \u00e9vit\u00e9 : %0.1f tCO2eq/an (\u00e9nergie=%0.1f, mat\u00e9riaux=%0.1f)",
    energy_substitution_scenario = "Sc\u00e9nario substitution : %s (facteur=%0.3f kgCO2eq/unit\u00e9)",

    # v0.4.0 - Famille N : Naturalit\u00e9 & Caract\u00e8re sauvage
    indicator_naturalness_distance = "Distance infrastructures (N : Naturalit\u00e9 & Caract\u00e8re sauvage)",
    indicator_naturalness_continuity = "Continuit\u00e9 foresti\u00e8re (N : Naturalit\u00e9 & Caract\u00e8re sauvage)",
    indicator_naturalness_composite = "Indice composite wilderness (N : Naturalit\u00e9 & Caract\u00e8re sauvage)",
    naturalness_distance_calculated = "Distance min infrastructures : %0.0f m (routes=%0.0f, b\u00e2timents=%0.0f)",
    naturalness_continuity_calculated = "Patch for\u00eat continue : %0.1f ha (connectivit\u00e9=%dm)",
    naturalness_composite_score = "Score wilderness : %0.1f/100 (distance=%0.1f, continuit\u00e9=%0.1f, \u00e2ge=%0.1f)",

    # v0.4.0 - Analyse Avanc\u00e9e (US7)
    # Analyse Pareto
    msg_pareto_computing = "Calcul optimalit\u00e9 Pareto pour %d parcelles sur %d objectifs...",
    msg_pareto_complete = "%d parcelles Pareto-optimales trouv\u00e9es (%.1f%%)",

    # Analyse de clustering
    msg_cluster_auto_k = "D\u00e9termination k optimal par analyse silhouette (k=2 \u00e0 %d)...",
    msg_cluster_optimal_k = "k optimal d\u00e9termin\u00e9 : %d (silhouette = %.3f)",
    msg_cluster_computing = "Clustering de %d parcelles en %d groupes via %s...",
    msg_cluster_complete = "Clustering termin\u00e9. Tailles clusters : %s",

    # Erreurs
    error_invalid_data_type = "Les donn\u00e9es doivent \u00eatre un objet data.frame ou sf",
    error_objectives_not_found = "Objectifs introuvables dans les donn\u00e9es : %s",
    error_non_numeric_objectives = "Les objectifs doivent \u00eatre num\u00e9riques : %s",
    error_maximize_length = "Longueur de 'maximize' (%d) doit correspondre \u00e0 longueur de 'objectives' (%d)",
    error_na_values = "Les variables contiennent des valeurs NA : %s",
    error_families_not_found = "Familles introuvables dans les donn\u00e9es : %s",
    error_non_numeric_families = "Les familles doivent \u00eatre num\u00e9riques : %s",
    error_invalid_method = "La m\u00e9thode doit \u00eatre 'kmeans' ou 'hierarchical'",
    error_k_too_small = "k doit \u00eatre au moins 2",
    error_k_too_large = "k doit \u00eatre inf\u00e9rieur au nombre de parcelles (%d)",
    error_ggplot2_required = "Le package 'ggplot2' est requis pour les graphiques. Installer avec : install.packages('ggplot2')",
    error_variable_not_found = "Variable '%s' introuvable dans les donn\u00e9es",
    error_non_numeric_variable = "La variable '%s' doit \u00eatre num\u00e9rique",
    error_is_optimal_required = "La colonne 'is_optimal' est requise pour l'affichage fronti\u00e8re Pareto. Ex\u00e9cuter identify_pareto_optimal() d'abord.",
    warning_ggrepel_not_installed = "Package 'ggrepel' non install\u00e9. Les \u00e9tiquettes peuvent se chevaucher. Installer avec : install.packages('ggrepel')"
  )
)
