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
  default_crs = 2154L  # Lambert 93
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
    indicators = c("C1", "C2")
  ),
  B = list(
    code = "B",
    name_fr = "Biodiversit\u00e9",
    name_en = "Biodiversity",
    icon = "bug-fill",
    color = "#9932CC",
    indicators = c("B1", "B2", "B3")
  ),
  W = list(
    code = "W",
    name_fr = "Eau",
    name_en = "Water",
    icon = "droplet-fill",
    color = "#1E90FF",
    indicators = c("W1", "W2", "W3")
  ),
  A = list(
    code = "A",
    name_fr = "Air & Microclimat",
    name_en = "Air & Microclimate",
    icon = "wind",
    color = "#87CEEB",
    indicators = c("A1", "A2")
  ),
  F = list(
    code = "F",
    name_fr = "Fertilit\u00e9 des Sols",
    name_en = "Soil Fertility",
    icon = "globe-americas",
    color = "#8B4513",
    indicators = c("F1", "F2")
  ),
  L = list(
    code = "L",
    name_fr = "Paysage",
    name_en = "Landscape",
    icon = "image-fill",
    color = "#32CD32",
    indicators = c("L1", "L2")
  ),
  T = list(
    code = "T",
    name_fr = "Dynamique Temporelle",
    name_en = "Temporal Dynamics",
    icon = "clock-fill",
    color = "#FFD700",
    indicators = c("T1", "T2")
  ),
  R = list(
    code = "R",
    name_fr = "Risques & R\u00e9silience",
    name_en = "Risks & Resilience",
    icon = "exclamation-triangle-fill",
    color = "#DC143C",
    indicators = c("R1", "R2", "R3", "R4")
  ),
  S = list(
    code = "S",
    name_fr = "Social & R\u00e9cr\u00e9atif",
    name_en = "Social & Recreational",
    icon = "people-fill",
    color = "#FF69B4",
    indicators = c("S1", "S2", "S3")
  ),
  P = list(
    code = "P",
    name_fr = "Production",
    name_en = "Production",
    icon = "box-seam-fill",
    color = "#006400",
    indicators = c("P1", "P2", "P3")
  ),
  E = list(
    code = "E",
    name_fr = "\u00c9nergie & Climat",
    name_en = "Energy & Climate",
    icon = "lightning-fill",
    color = "#FF8C00",
    indicators = c("E1", "E2")
  ),
  N = list(
    code = "N",
    name_fr = "Naturalit\u00e9",
    name_en = "Naturalness",
    icon = "flower1",
    color = "#2E8B57",
    indicators = c("N1", "N2", "N3")
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
