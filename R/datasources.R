#' Data Source Configuration by Country
#'
#' @description
#' Abstraction layer for geographic data sources (ADR-002).
#' Data source URLs and service endpoints are never hardcoded in the code.
#' They are declared in JSON configuration files per country
#' (\code{inst/datasources/FR.json}, \code{inst/datasources/DE.json}, etc.).
#'
#' Adding a new country requires only a JSON configuration file,
#' not code modifications.
#'
#' @name datasources
#' @keywords internal
NULL


# Cache pour les configurations chargees
.datasource_cache <- new.env(parent = emptyenv())


#' Get country data source configuration
#'
#' Loads and caches the JSON configuration for a given country.
#'
#' @param country Character. ISO 3166-1 alpha-2 country code (e.g., "FR", "DE").
#'   Use "EU" for pan-European fallback sources.
#'
#' @return A list with the country's data source configuration.
#'
#' @examples
#' config <- get_country_config("FR")
#' config$crs_national  # 2154
#' config$services$ign_wfs$url
#'
#' @export
get_country_config <- function(country = "FR") {
  country <- toupper(country)
  cache_key <- paste0("config_", country)

  # Retourner depuis le cache si disponible

  if (exists(cache_key, envir = .datasource_cache)) {
    return(get(cache_key, envir = .datasource_cache))
  }

  # Chercher le fichier de configuration
  config_file <- system.file("datasources", paste0(country, ".json"),
                             package = "nemeton")

  if (!nzchar(config_file) || !file.exists(config_file)) {
    # Fallback vers EU si le pays n'est pas configure
    if (country != "EU") {
      cli::cli_warn("No data source configuration for country {.val {country}}. Using EU fallback.")
      return(get_country_config("EU"))
    }
    cli::cli_abort("Data source configuration file not found for {.val {country}}")
  }

  config <- jsonlite::read_json(config_file, simplifyVector = FALSE)

  # Mettre en cache
  assign(cache_key, config, envir = .datasource_cache)

  config
}


#' Get data source URL or configuration
#'
#' Returns the URL or configuration for a specific data source in a country.
#'
#' @param source_key Character. The data source key (e.g., "dem", "roads",
#'   "ortho_irc", "oso", "cadastre_api").
#' @param country Character. ISO country code. Default "FR".
#' @param section Character. Configuration section to search in. One of
#'   "layers", "datasets", "services", "communes". Default: auto-detect.
#'
#' @return A list with the source configuration, or NULL if not found.
#'
#' @examples
#' # Get DEM layer config for France
#' dem <- get_data_source("dem", "FR")
#' dem$layer  # "ELEVATION.ELEVATIONGRIDCOVERAGE"
#'
#' # Get OSO dataset URL
#' oso <- get_data_source("oso", "FR")
#' oso$url
#'
#' @export
get_data_source <- function(source_key, country = "FR", section = NULL) {
  config <- get_country_config(country)

  # Recherche automatique dans les sections
  sections_to_search <- if (!is.null(section)) {
    section
  } else {
    c("layers", "datasets", "services", "communes")
  }

  for (sec in sections_to_search) {
    if (!is.null(config[[sec]]) && !is.null(config[[sec]][[source_key]])) {
      return(config[[sec]][[source_key]])
    }
  }

  # Si pas trouve dans le pays, essayer le fallback EU
  if (country != "EU") {
    eu_result <- get_data_source(source_key, "EU", section)
    if (!is.null(eu_result)) {
      return(eu_result)
    }
  }

  NULL
}


#' Get service URL for a layer
#'
#' Resolves the full service URL for a given layer by looking up
#' the service reference in the layer configuration.
#'
#' @param layer_key Character. The layer key (e.g., "dem", "roads").
#' @param country Character. ISO country code. Default "FR".
#'
#' @return A list with \code{url} (service URL) and \code{layer}
#'   or \code{typename} (layer identifier), or NULL.
#'
#' @examples
#' info <- get_layer_service("dem", "FR")
#' info$url    # "https://data.geopf.fr/wms-r/wms"
#' info$layer  # "ELEVATION.ELEVATIONGRIDCOVERAGE"
#'
#' @export
get_layer_service <- function(layer_key, country = "FR") {
  config <- get_country_config(country)
  layer <- config$layers[[layer_key]]

  if (is.null(layer)) return(NULL)

  # Si le layer reference un service, resoudre l'URL
  if (!is.null(layer$service)) {
    service <- config$services[[layer$service]]
    if (!is.null(service)) {
      return(c(layer, list(url = service$url, version = service$version)))
    }
  }

  layer
}


#' Get national CRS for a country
#'
#' Returns the EPSG code of the national coordinate reference system.
#'
#' @param country Character. ISO country code. Default "FR".
#'
#' @return Integer. EPSG code (e.g., 2154 for France Lambert-93).
#'
#' @examples
#' get_national_crs("FR")  # 2154
#'
#' @export
get_national_crs <- function(country = "FR") {
  config <- get_country_config(country)
  as.integer(config$crs_national %||% 3035L)
}


#' Get storage CRS (pan-European)
#'
#' Returns the EPSG code used for internal data storage.
#' EPSG:3035 (ETRS89/LAEA) is the pan-European standard (ADR-008).
#'
#' @return Integer. EPSG code (3035).
#'
#' @examples
#' get_storage_crs()  # 3035
#'
#' @export
get_storage_crs <- function() {
  3035L
}


#' Get metric CRS for a country
#'
#' Returns the CRS to use for metric calculations (distances, areas).
#' Uses the national CRS for precision (Lambert-93 for France, UTM for others).
#'
#' @param country Character. ISO country code. Default "FR".
#'
#' @return Integer. EPSG code for metric calculations.
#'
#' @examples
#' get_metric_crs("FR")  # 2154 (Lambert-93)
#'
#' @export
get_metric_crs <- function(country = "FR") {
  get_national_crs(country)
}


#' List available countries
#'
#' Returns the country codes for which data source configurations exist.
#'
#' @return Character vector of ISO country codes.
#'
#' @examples
#' list_countries()  # c("EU", "FR")
#'
#' @export
list_countries <- function() {
  config_dir <- system.file("datasources", package = "nemeton")
  if (!nzchar(config_dir)) return(character(0))

  files <- list.files(config_dir, pattern = "\\.json$", full.names = FALSE)
  sub("\\.json$", "", files)
}


#' Clear data source configuration cache
#'
#' Forces a fresh reload of configuration files on next access.
#'
#' @return NULL invisibly.
#'
#' @keywords internal
#' @noRd
clear_datasource_cache <- function() {
  rm(list = ls(envir = .datasource_cache), envir = .datasource_cache)
  invisible(NULL)
}
