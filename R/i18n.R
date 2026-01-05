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
    indicator_carbon = "Carbon stock (biomass -> carbon)",
    indicator_biodiversity = "Biodiversity (species richness)",
    indicator_water = "Water regulation (TWI + proximity)",
    indicator_fragmentation = "Fragmentation (forest coverage)",
    indicator_accessibility = "Accessibility (distance to roads)",

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
    demo_files_missing = "Missing demo data file%s: %s"
  ),

  fr = list(
    # Général
    language_set = "Langue définie : %s",

    # nemeton_units
    units_created = "Unités nemeton créées : %d entités, %s",
    units_missing_geom = "Les données d'entrée n'ont pas de colonne géométrique",
    units_not_sf = "L'entrée doit être un objet sf ou un chemin vers un fichier spatial",
    units_id_created = "%d identifiants uniques générés",

    # nemeton_layers
    layers_created = "Catalogue de couches créé : %d rasters, %d vecteurs",
    layers_no_input = "Au moins un des arguments rasters ou vectors doit être fourni",
    layers_no_names = "Les noms de couches sont requis (utilisez une liste nommée)",
    layers_file_missing = "Fichier introuvable : %s",
    layers_invalid_type = "Type de couche invalide : %s (attendu SpatRaster ou sf)",

    # Prétraitement
    preprocess_start = "Prétraitement des couches...",
    preprocess_harmonizing = "Harmonisation du CRS...",
    preprocess_crs_harmonized = "CRS harmonisé vers %s",
    preprocess_cropping = "Recadrage des couches...",
    preprocess_cropped = "Couches recadrées à l'emprise des unités (buffer : %dm)",
    preprocess_layer_loaded = "Couche chargée : %s",

    # Indicateurs
    indicator_computing = "Calcul de %d indicateurs...",
    indicator_calculated = "Calcul en cours : %s",
    indicator_computed = "%d/%d indicateurs calculés",
    indicator_failed = "Échec du calcul de l'indicateur '%s'",
    indicator_set_na = "Définition de '%s' à NA",
    indicator_no_valid = "Aucun indicateur valide à calculer",
    indicator_carbon = "Stock de carbone (biomasse -> carbone)",
    indicator_biodiversity = "Biodiversité (richesse spécifique)",
    indicator_water = "Régulation hydrique (TWI + proximité)",
    indicator_fragmentation = "Fragmentation (couverture forestière)",
    indicator_accessibility = "Accessibilité (distance aux routes)",

    # Normalisation
    normalize_auto_detected = "%d indicateurs auto-détectés : %s",
    normalize_normalized = "%d indicateurs normalisés avec la méthode %s",
    normalize_missing = "Colonnes d'indicateur introuvables : %s",
    normalize_no_indicators = "Aucun indicateur trouvé à normaliser",
    normalize_ref_missing = "Données de référence manquantes %s, utilisation des données actuelles",
    normalize_all_identical = "Toutes les valeurs sont identiques, définition à 50",
    normalize_sd_zero = "L'écart-type est 0, définition à 0",

    # Indice composite
    composite_equal_weights = "Utilisation de poids égaux pour %d indicateurs",
    composite_created = "Indice composite '%s' créé à partir de %d indicateurs",
    composite_missing = "Indicateurs manquants : %s",
    composite_weights_length = "Le nombre de poids doit correspondre au nombre d'indicateurs",
    composite_weights_negative = "Les poids doivent être non négatifs",
    composite_negative_geomean = "Valeurs négatives trouvées, utilisation de valeurs absolues pour la moyenne géométrique",

    # Inversion
    invert_inverted = "%d indicateurs inversés",

    # Visualisation
    viz_no_indicators = "Aucune colonne d'indicateur trouvée",
    viz_specify_indicators = "Spécifiez les indicateurs explicitement",
    viz_detected = "%d indicateurs auto-détectés : %s",
    viz_missing = "Colonnes d'indicateur introuvables : %s",
    viz_multiple_no_facet = "Plusieurs indicateurs fournis mais facet = FALSE",
    viz_creating_facet = "Création d'un graphique à facettes. Définissez facet = TRUE ou sélectionnez un seul indicateur.",
    viz_not_sf = "data doit être un objet sf",
    viz_both_not_sf = "data1 et data2 doivent tous deux être des objets sf",
    viz_indicator_missing_both = "L'indicateur '%s' doit exister dans les deux jeux de données",

    # Données démo
    demo_loading = "Chargement des couches spatiales Massif Demo...",
    demo_loaded = "%d couches raster et %d couches vecteur chargées",
    demo_pkg_not_found = "Package nemeton introuvable",
    demo_install_first = "Installez d'abord le package : devtools::install()",
    demo_dir_not_found = "Répertoire de données démo introuvable : %s",
    demo_reinstall = "Réinstallez le package pour inclure les données démo",
    demo_files_missing = "Fichier%s de données démo manquant%s : %s"
  )
)
