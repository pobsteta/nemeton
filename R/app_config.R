#' nemetonApp Configuration
#'
#' @description
#' Configuration constants and settings for the nemetonApp Shiny application.
#'
#' @name app_config
#' @keywords internal
NULL


#' Application configuration constants
#'
#' @noRd
APP_CONFIG <- list(
  # App metadata
  app_name = "N\u00e9m\u00e9ton",
  app_version = "0.9.0",
  app_title_fr = "N\u00e9m\u00e9ton - Diagnostic Forestier",
  app_title_en = "N\u00e9m\u00e9ton - Forest Diagnostic",

  # Limits
  max_parcels = 20L,
  max_project_name_length = 100L,
  max_description_length = 500L,

  # Timeouts (milliseconds)
  api_timeout = 30000L,
  wfs_timeout = 60000L,
  computation_timeout = 600000L,  # 10 minutes

  # Retry settings
  max_retries = 3L,
  retry_delay = 2000L,  # 2 seconds

  # Performance
  parallel_workers = NULL,  # NULL = auto-detect

  # Cache settings
  cache_format = "parquet",

  # Project states
  project_states = c("draft", "downloading", "computing", "completed", "error"),

  # CRS
  default_crs = 2154L,  # Lambert 93

  # LLM settings
  llm_provider = "mistral",
  llm_models = list(
    anthropic = "claude-sonnet-4-5-20250929",
    mistral = "mistral-large-latest",
    openai = "gpt-4o",
    google = "gemini-2.0-flash",
    deepseek = "deepseek-chat",
    ollama = "llama3.1"
  )
)


#' Get app configuration value
#'
#' @param key Character. Configuration key to retrieve.
#' @param default Default value if key not found.
#' @return Configuration value.
#' @noRd
get_app_config <- function(key, default = NULL) {
  if (key %in% names(APP_CONFIG)) {
    return(APP_CONFIG[[key]])
  }
  return(default)
}


#' Indicator families configuration
#'
#' @description
#' Configuration for the 12 indicator families used in nemeton.
#'
#' @noRd
INDICATOR_FAMILIES <- list(
  C = list(
    code = "C",
    name_fr = "Carbone & Vitalit\u00e9",
    name_en = "Carbon & Vitality",
    icon = "tree-fill",
    color = "#228B22",
    indicators = c("C1", "C2"),
    column_names = c("carbon_biomass", "carbon_ndvi"),
    indicator_labels = list(
      C1 = list(fr = "Biomasse carbone (tC/ha)", en = "Carbon Biomass (tC/ha)"),
      C2 = list(fr = "NDVI - Vitalit\u00e9", en = "NDVI - Vitality")
    )
  ),
  B = list(
    code = "B",
    name_fr = "Biodiversit\u00e9",
    name_en = "Biodiversity",
    icon = "bug-fill",
    color = "#9932CC",
    indicators = c("B1", "B2", "B3"),
    column_names = c("biodiversity_protection", "biodiversity_structure", "biodiversity_connectivity"),
    indicator_labels = list(
      B1 = list(fr = "Protection biodiversit\u00e9", en = "Biodiversity Protection"),
      B2 = list(fr = "Diversit\u00e9 structurale", en = "Structural Diversity"),
      B3 = list(fr = "Connectivit\u00e9 \u00e9cologique", en = "Ecological Connectivity")
    )
  ),
  W = list(
    code = "W",
    name_fr = "Eau",
    name_en = "Water",
    icon = "droplet-fill",
    color = "#1E90FF",
    indicators = c("W1", "W2", "W3"),
    column_names = c("water_network", "water_wetlands", "water_twi"),
    indicator_labels = list(
      W1 = list(fr = "R\u00e9seau hydrographique", en = "Water Network"),
      W2 = list(fr = "Zones humides", en = "Wetlands"),
      W3 = list(fr = "Indice topographique d'humidit\u00e9", en = "Topographic Wetness Index")
    )
  ),
  A = list(
    code = "A",
    name_fr = "Air & Microclimat",
    name_en = "Air & Microclimate",
    icon = "wind",
    color = "#87CEEB",
    indicators = c("A1", "A2"),
    column_names = c("air_forest_buffer", "air_quality"),
    indicator_labels = list(
      A1 = list(fr = "Tampon forestier", en = "Forest Buffer"),
      A2 = list(fr = "Qualit\u00e9 de l'air", en = "Air Quality")
    )
  ),
  F = list(
    code = "F",
    name_fr = "Fertilit\u00e9 des Sols",
    name_en = "Soil Fertility",
    icon = "globe-americas",
    color = "#8B4513",
    indicators = c("F1", "F2"),
    column_names = c("fertility_soil", "fertility_erosion"),
    indicator_labels = list(
      F1 = list(fr = "Fertilit\u00e9 des sols", en = "Soil Fertility"),
      F2 = list(fr = "Risque d'\u00e9rosion", en = "Erosion Risk")
    )
  ),
  L = list(
    code = "L",
    name_fr = "Paysage",
    name_en = "Landscape",
    icon = "image-fill",
    color = "#32CD32",
    indicators = c("L1", "L2"),
    column_names = c("landscape_fragmentation", "landscape_edge_ratio"),
    indicator_labels = list(
      L1 = list(fr = "Fragmentation paysag\u00e8re", en = "Landscape Fragmentation"),
      L2 = list(fr = "Ratio bordure/surface", en = "Edge-to-Area Ratio")
    )
  ),
  T = list(
    code = "T",
    name_fr = "Dynamique Temporelle",
    name_en = "Temporal Dynamics",
    icon = "clock-fill",
    color = "#FFD700",
    indicators = c("T1", "T2"),
    column_names = c("temporal_age", "temporal_change"),
    indicator_labels = list(
      T1 = list(fr = "Anciennet\u00e9 foresti\u00e8re", en = "Forest Age"),
      T2 = list(fr = "Taux de changement", en = "Change Rate")
    )
  ),
  R = list(
    code = "R",
    name_fr = "Risques & R\u00e9silience",
    name_en = "Risks & Resilience",
    icon = "exclamation-triangle-fill",
    color = "#DC143C",
    indicators = c("R1", "R2", "R3", "R4"),
    column_names = c("risk_fire", "risk_storm", "risk_drought", "risk_browsing"),
    indicator_labels = list(
      R1 = list(fr = "Risque incendie", en = "Fire Risk"),
      R2 = list(fr = "Risque temp\u00eate", en = "Storm Risk"),
      R3 = list(fr = "Risque s\u00e9cheresse", en = "Drought Risk"),
      R4 = list(fr = "Risque abroutissement", en = "Browsing Risk")
    )
  ),
  S = list(
    code = "S",
    name_fr = "Social & R\u00e9cr\u00e9atif",
    name_en = "Social & Recreational",
    icon = "people-fill",
    color = "#FF69B4",
    indicators = c("S1", "S2", "S3"),
    column_names = c("social_trails", "social_accessibility", "social_population"),
    indicator_labels = list(
      S1 = list(fr = "Densit\u00e9 de sentiers", en = "Trail Density"),
      S2 = list(fr = "Accessibilit\u00e9", en = "Accessibility"),
      S3 = list(fr = "Proximit\u00e9 population", en = "Population Proximity")
    )
  ),
  P = list(
    code = "P",
    name_fr = "Production",
    name_en = "Production",
    icon = "box-seam-fill",
    color = "#006400",
    indicators = c("P1", "P2", "P3"),
    column_names = c("production_volume", "production_productivity", "production_quality"),
    indicator_labels = list(
      P1 = list(fr = "Volume de bois (m\u00b3/ha)", en = "Timber Volume (m\u00b3/ha)"),
      P2 = list(fr = "Productivit\u00e9", en = "Productivity"),
      P3 = list(fr = "Qualit\u00e9 du bois", en = "Timber Quality")
    )
  ),
  E = list(
    code = "E",
    name_fr = "\u00c9nergie & Climat",
    name_en = "Energy & Climate",
    icon = "lightning-fill",
    color = "#FF8C00",
    indicators = c("E1", "E2"),
    column_names = c("energy_wood", "energy_co2"),
    indicator_labels = list(
      E1 = list(fr = "Bois-\u00e9nergie", en = "Wood Energy"),
      E2 = list(fr = "\u00c9vitement CO2", en = "CO2 Avoidance")
    )
  ),
  N = list(
    code = "N",
    name_fr = "Naturalit\u00e9",
    name_en = "Naturalness",
    icon = "flower1",
    color = "#2E8B57",
    indicators = c("N1", "N2", "N3"),
    column_names = c("naturalness_distance", "naturalness_continuity", "naturalness_score"),
    indicator_labels = list(
      N1 = list(fr = "Distance infrastructures", en = "Infrastructure Distance"),
      N2 = list(fr = "Continuit\u00e9 foresti\u00e8re", en = "Forest Continuity"),
      N3 = list(fr = "Score de naturalit\u00e9", en = "Naturalness Score")
    )
  )
)


#' Get all indicator family codes
#'
#' @return Character vector of family codes
#' @noRd
get_family_codes <- function() {
  names(INDICATOR_FAMILIES)
}


#' Get family configuration
#'
#' @param code Character. Family code (e.g., "C", "B", "W")
#' @return List with family configuration, or NULL if not found
#' @noRd
get_family_config <- function(code) {
  INDICATOR_FAMILIES[[toupper(code)]]
}


#' Get all indicator codes
#'
#' @return Character vector of all indicator codes
#' @noRd
get_all_indicator_codes <- function() {
  unlist(lapply(INDICATOR_FAMILIES, function(f) f$indicators), use.names = FALSE)
}


#' Get all indicator column names
#'
#' @return Character vector of all long-form column names
#' @noRd
get_all_column_names <- function() {
  unlist(lapply(INDICATOR_FAMILIES, function(f) f$column_names), use.names = FALSE)
}


#' Get column-to-family mapping
#'
#' @description
#' Returns a named character vector mapping column names to family codes.
#' Supports both short codes (C1, B2) and long-form names (carbon_biomass).
#'
#' @return Named character vector (names = column names, values = family codes)
#' @noRd
get_column_family_map <- function() {
  result <- character(0)
  for (fam in INDICATOR_FAMILIES) {
    # Map long-form column_names to family code
    if (!is.null(fam$column_names)) {
      names_vec <- rep(fam$code, length(fam$column_names))
      names(names_vec) <- fam$column_names
      result <- c(result, names_vec)
    }
    # Map short indicators to family code
    names_vec2 <- rep(fam$code, length(fam$indicators))
    names(names_vec2) <- fam$indicators
    result <- c(result, names_vec2)
  }
  result
}


#' Data sources configuration
#'
#' @noRd
DATA_SOURCES <- list(
  cadastre = list(
    name = "cadastre",
    primary = "api_cadastre",
    fallback = "happign",
    required = TRUE
  ),
  bdforet = list(
    name = "bdforet",
    primary = "ign_wfs",
    fallback = "local_cache",
    required = TRUE
  ),
  protection = list(
    name = "protection",
    primary = "inpn_wfs",
    fallback = "local_cache",
    required = FALSE
  ),
  oso = list(
    name = "oso",
    primary = "recherche_data_gouv",
    fallback = "local_cache",
    required = FALSE
  ),
  hydro = list(
    name = "hydro",
    primary = "sandre_wfs",
    fallback = "local_cache",
    required = FALSE
  ),
  mnt = list(
    name = "mnt",
    primary = "ign_wfs",
    fallback = "local_cache",
    required = FALSE
  )
)


#' Get data source configuration
#'
#' @param name Character. Data source name
#' @return List with source configuration
#' @noRd
get_data_source_config <- function(name) {
  DATA_SOURCES[[name]]
}
