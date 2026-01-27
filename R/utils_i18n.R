#' Internationalization (i18n) for nemetonApp
#'
#' @description
#' Translation system for the nemetonApp Shiny application.
#' Supports French (fr) and English (en).
#'
#' @name utils_i18n
#' @keywords internal
NULL


#' Translation dictionary
#'
#' @description
#' Complete translation dictionary for all UI strings.
#'
#' @noRd
TRANSLATIONS <- list(
  # ============================================================
  # Application
  # ============================================================
  app_title = list(
    fr = "N\u00e9m\u00e9ton - Diagnostic Forestier",
    en = "N\u00e9m\u00e9ton - Forest Diagnostic"
  ),

  # ============================================================
  # Navigation
  # ============================================================
  tab_selection = list(fr = "S\u00e9lection", en = "Selection"),
  tab_synthesis = list(fr = "Synth\u00e8se", en = "Synthesis"),
  tab_families = list(fr = "Familles d'indicateurs", en = "Indicator Families"),

  # ============================================================
  # Search & Selection
  # ============================================================
  search_title = list(fr = "Recherche", en = "Search"),
  department = list(fr = "D\u00e9partement", en = "Department"),
  select_department = list(fr = "-- S\u00e9lectionnez --", en = "-- Select --"),
  commune = list(fr = "Commune", en = "Municipality"),
  search_commune = list(fr = "Rechercher une commune...", en = "Search for a municipality..."),
  postal_code = list(fr = "Code postal", en = "Postal code"),

  # ============================================================
  # Map
  # ============================================================
  map_title = list(fr = "Carte des parcelles", en = "Parcel Map"),
  basemap_osm = list(fr = "OSM", en = "OSM"),
  basemap_satellite = list(fr = "Satellite", en = "Satellite"),
  loading_parcels = list(fr = "Chargement des parcelles...", en = "Loading parcels..."),
  loading_commune = list(fr = "Chargement de la commune...", en = "Loading commune..."),
  click_to_select = list(fr = "Cliquez pour s\u00e9lectionner", en = "Click to select"),

  # ============================================================
  # Selection
  # ============================================================
  selected_parcels = list(fr = "Parcelles s\u00e9lectionn\u00e9es", en = "Selected Parcels"),
  parcels_selected = list(fr = "parcelles", en = "parcels"),
  no_selection = list(fr = "Aucune parcelle s\u00e9lectionn\u00e9e", en = "No parcel selected"),
  max_parcels_warning = list(
    fr = "Limite de 20 parcelles atteinte",
    en = "Maximum 20 parcels reached"
  ),
  clear_selection = list(fr = "Tout d\u00e9s\u00e9lectionner", en = "Clear selection"),

  # ============================================================
  # Project
  # ============================================================
  project_info = list(fr = "Informations projet", en = "Project Information"),
  project_name = list(fr = "Nom du projet", en = "Project name"),
  project_name_placeholder = list(fr = "Mon projet forestier", en = "My forest project"),
  project_description = list(fr = "Description", en = "Description"),
  project_description_placeholder = list(
    fr = "Description optionnelle...",
    en = "Optional description..."
  ),
  project_owner = list(fr = "Propri\u00e9taire / Gestionnaire", en = "Owner / Manager"),
  project_owner_placeholder = list(fr = "Nom du propri\u00e9taire", en = "Owner name"),
  project_date = list(fr = "Date de cr\u00e9ation", en = "Creation date"),
  created_at = list(fr = "Cr\u00e9\u00e9 le", en = "Created on"),
  auto_generated = list(fr = "G\u00e9n\u00e9r\u00e9 automatiquement", en = "Auto-generated"),
  create_project = list(fr = "Cr\u00e9er le projet", en = "Create project"),
  update_project = list(fr = "Mettre \u00e0 jour", en = "Update"),
  project_updated = list(fr = "Projet mis \u00e0 jour", en = "Project updated"),
  field_required = list(fr = "Ce champ est obligatoire", en = "This field is required"),
  max_chars = list(fr = "Maximum", en = "Maximum"),
  characters = list(fr = "caract\u00e8res", en = "characters"),
  name_required = list(fr = "Le nom du projet est obligatoire", en = "Project name is required"),
  name_too_long = list(fr = "Le nom ne doit pas d\u00e9passer 100 caract\u00e8res", en = "Name must not exceed 100 characters"),
  description_too_long = list(fr = "La description ne doit pas d\u00e9passer 500 caract\u00e8res", en = "Description must not exceed 500 characters"),
  owner_too_long = list(fr = "Le propri\u00e9taire ne doit pas d\u00e9passer 100 caract\u00e8res", en = "Owner must not exceed 100 characters"),
  no_parcels_selected = list(fr = "Veuillez s\u00e9lectionner au moins une parcelle", en = "Please select at least one parcel"),
  project_created = list(fr = "Projet cr\u00e9\u00e9", en = "Project created"),
  project_loaded = list(fr = "Projet charg\u00e9", en = "Project loaded"),
  project_not_found = list(fr = "Projet non trouv\u00e9", en = "Project not found"),
  project_deleted = list(fr = "Projet supprim\u00e9", en = "Project deleted"),

  # Recent projects
  recent_projects = list(fr = "Projets r\u00e9cents", en = "Recent projects"),
  no_recent_projects = list(fr = "Aucun projet r\u00e9cent", en = "No recent projects"),

  # Project status
  status_draft = list(fr = "Brouillon", en = "Draft"),
  status_downloading = list(fr = "T\u00e9l\u00e9chargement", en = "Downloading"),
  status_computing = list(fr = "Calcul en cours", en = "Computing"),
  status_completed = list(fr = "Termin\u00e9", en = "Completed"),
  status_error = list(fr = "Erreur", en = "Error"),
  status_unknown = list(fr = "Inconnu", en = "Unknown"),
  corrupted = list(fr = "Corrompu", en = "Corrupted"),

  # Delete corrupted projects
  delete_corrupted_project = list(fr = "Supprimer le projet corrompu", en = "Delete corrupted project"),
  delete_corrupted_confirm = list(
    fr = "Ce projet est corrompu et ne peut pas \u00eatre ouvert. Voulez-vous le supprimer d\u00e9finitivement ?",
    en = "This project is corrupted and cannot be opened. Do you want to delete it permanently?"
  ),

  # Parcels
  parcels = list(fr = "parcelles", en = "parcels"),
  created = list(fr = "Cr\u00e9\u00e9", en = "Created"),
  parcels_loaded = list(fr = "parcelles charg\u00e9es", en = "parcels loaded"),
  error_loading_parcels = list(fr = "Erreur chargement parcelles", en = "Error loading parcels"),

  # General
  error = list(fr = "Erreur", en = "Error"),

  # ============================================================
  # Computation
  # ============================================================
  compute_button = list(fr = "Lancer les calculs", en = "Start Calculations"),
  computing = list(fr = "Calcul en cours...", en = "Computing..."),
  downloading_data = list(fr = "T\u00e9l\u00e9chargement des donn\u00e9es...", en = "Downloading data..."),
  computing_indicator = list(
    fr = "Calcul de l'indicateur {indicator}...",
    en = "Computing indicator {indicator}..."
  ),
  computation_complete = list(fr = "Calculs termin\u00e9s", en = "Calculations complete"),
  computation_error = list(fr = "Erreur lors du calcul", en = "Computation error"),

  # Progress module
  progress_overall = list(fr = "Progression globale", en = "Overall progress"),
  completed = list(fr = "termin\u00e9s", en = "completed"),
  failed = list(fr = "\u00e9chou\u00e9s", en = "failed"),
  pending = list(fr = "en attente", en = "pending"),
  phase_init = list(fr = "Initialisation...", en = "Initializing..."),
  phase_downloading = list(fr = "T\u00e9l\u00e9chargement des donn\u00e9es...", en = "Downloading data..."),
  phase_computing = list(fr = "Calcul des indicateurs...", en = "Computing indicators..."),
  phase_complete = list(fr = "Termin\u00e9", en = "Complete"),
  task_download_start = list(fr = "D\u00e9marrage du t\u00e9l\u00e9chargement", en = "Starting download"),
  task_compute_start = list(fr = "D\u00e9marrage des calculs", en = "Starting calculations"),
  task_complete = list(fr = "Traitement termin\u00e9", en = "Processing complete"),
  task_error = list(fr = "Erreur de traitement", en = "Processing error"),
  elapsed_time = list(fr = "Temps \u00e9coul\u00e9", en = "Elapsed time"),
  errors_title = list(fr = "Erreurs rencontr\u00e9es :", en = "Errors encountered:"),
  computation_summary = list(
    fr = "%d indicateur(s) calcul\u00e9(s) sur %d",
    en = "%d indicator(s) computed out of %d"
  ),
  unknown_error = list(fr = "Erreur inconnue", en = "Unknown error"),
  and_n_more_errors = list(fr = "Et %d autre(s) erreur(s)...", en = "And %d more error(s)..."),
  retry = list(fr = "R\u00e9essayer", en = "Retry"),
  view_results = list(fr = "Voir les r\u00e9sultats", en = "View results"),
  resuming_computation = list(
    fr = "Reprise du calcul - %d indicateur(s) d\u00e9j\u00e0 calcul\u00e9(s)",
    en = "Resuming computation - %d indicator(s) already computed"
  ),
  skipped_indicators = list(
    fr = "%d indicateur(s) saut\u00e9(s) (d\u00e9j\u00e0 calcul\u00e9s)",
    en = "%d indicator(s) skipped (already computed)"
  ),

  # ============================================================
  # Synthesis
  # ============================================================
  synthesis_title = list(fr = "Synth\u00e8se du projet", en = "Project Synthesis"),
  radar_title = list(fr = "Radar des 12 familles", en = "12 Families Radar"),
  summary_table_title = list(fr = "R\u00e9capitulatif par famille", en = "Summary by Family"),
  download_pdf = list(fr = "T\u00e9l\u00e9charger le rapport PDF", en = "Download PDF Report"),
  download_gpkg = list(fr = "T\u00e9l\u00e9charger le GeoPackage", en = "Download GeoPackage"),
  no_project = list(fr = "Aucun projet charg\u00e9", en = "No project loaded"),
  no_data = list(fr = "Pas de donn\u00e9es", en = "No data"),

  # ============================================================
  # Indicator Families
  # ============================================================
  family_C = list(fr = "Carbone & Vitalit\u00e9", en = "Carbon & Vitality"),
  family_B = list(fr = "Biodiversit\u00e9", en = "Biodiversity"),
  family_W = list(fr = "Eau", en = "Water"),
  family_A = list(fr = "Air & Microclimat", en = "Air & Microclimate"),
  family_F = list(fr = "Fertilit\u00e9 des Sols", en = "Soil Fertility"),
  family_L = list(fr = "Paysage", en = "Landscape"),
  family_T = list(fr = "Dynamique Temporelle", en = "Temporal Dynamics"),
  family_R = list(fr = "Risques & R\u00e9silience", en = "Risks & Resilience"),
  family_S = list(fr = "Social & R\u00e9cr\u00e9atif", en = "Social & Recreational"),
  family_P = list(fr = "Production", en = "Production"),
  family_E = list(fr = "\u00c9nergie & Climat", en = "Energy & Climate"),
  family_N = list(fr = "Naturalit\u00e9", en = "Naturalness"),

  # Family descriptions
  family_C_desc = list(
    fr = "Stockage de carbone et vitalit\u00e9 de la v\u00e9g\u00e9tation (biomasse, NDVI)",
    en = "Carbon storage and vegetation vitality (biomass, NDVI)"
  ),
  family_B_desc = list(
    fr = "Protection, diversit\u00e9 structurale et connectivit\u00e9 \u00e9cologique",
    en = "Protection, structural diversity and ecological connectivity"
  ),
  family_W_desc = list(
    fr = "R\u00e9gulation hydrique, zones humides et indice topographique",
    en = "Water regulation, wetlands and topographic index"
  ),
  family_A_desc = list(
    fr = "Couverture foresti\u00e8re tampon et qualit\u00e9 de l'air",
    en = "Forest cover buffer and air quality"
  ),
  family_F_desc = list(
    fr = "Classes de sol et risque d'\u00e9rosion",
    en = "Soil classes and erosion risk"
  ),
  family_L_desc = list(
    fr = "Fragmentation paysag\u00e8re et ratio bordure/surface",
    en = "Landscape fragmentation and edge-to-area ratio"
  ),
  family_T_desc = list(
    fr = "Anciennet\u00e9 foresti\u00e8re et taux de changement",
    en = "Forest age and change rate"
  ),
  family_R_desc = list(
    fr = "Risques feu, temp\u00eate, s\u00e9cheresse et abroutissement",
    en = "Fire, storm, drought and browsing risks"
  ),
  family_S_desc = list(
    fr = "Densit\u00e9 de sentiers, accessibilit\u00e9 et proximit\u00e9 population",
    en = "Trail density, accessibility and population proximity"
  ),
  family_P_desc = list(
    fr = "Volume de bois, productivit\u00e9 et qualit\u00e9",
    en = "Timber volume, productivity and quality"
  ),
  family_E_desc = list(
    fr = "Potentiel bois-\u00e9nergie et \u00e9vitement CO2",
    en = "Wood energy potential and CO2 avoidance"
  ),
  family_N_desc = list(
    fr = "Distance infrastructures, continuit\u00e9 et score de naturalit\u00e9",
    en = "Infrastructure distance, continuity and naturalness score"
  ),

  # ============================================================
  # Data Table
  # ============================================================
  data_table = list(fr = "Tableau des donn\u00e9es", en = "Data Table"),

  # ============================================================
  # Missing Indicators
  # ============================================================
  missing_indicator = list(
    fr = "Indicateur non disponible : {reason}",
    en = "Indicator not available: {reason}"
  ),
  missing_lidar = list(fr = "Donn\u00e9es LiDAR non disponibles", en = "LiDAR data not available"),
  missing_connection = list(
    fr = "Connexion au serveur impossible",
    en = "Unable to connect to server"
  ),
  missing_data = list(fr = "Donn\u00e9es source manquantes", en = "Source data missing"),

  # ============================================================
  # Help & Tour
  # ============================================================
  help = list(fr = "Aide", en = "Help"),
  help_title = list(fr = "Guide d'utilisation", en = "User Guide"),
  help_intro = list(
    fr = "N\u00e9m\u00e9ton vous permet d'analyser des parcelles foresti\u00e8res selon 12 familles d'indicateurs.",
    en = "N\u00e9m\u00e9ton allows you to analyze forest parcels across 12 indicator families."
  ),
  help_steps_title = list(fr = "\u00c9tapes d'utilisation", en = "Usage Steps"),
  help_step1 = list(
    fr = "S\u00e9lectionnez un d\u00e9partement puis une commune",
    en = "Select a department then a municipality"
  ),
  help_step2 = list(
    fr = "Cliquez sur les parcelles \u00e0 analyser (max 20)",
    en = "Click on parcels to analyze (max 20)"
  ),
  help_step3 = list(
    fr = "Renseignez les informations du projet",
    en = "Fill in project information"
  ),
  help_step4 = list(
    fr = "Lancez les calculs et attendez la fin",
    en = "Start calculations and wait for completion"
  ),
  help_step5 = list(
    fr = "Consultez les r\u00e9sultats et t\u00e9l\u00e9chargez le rapport",
    en = "View results and download the report"
  ),
  tour_restart = list(fr = "Relancer le tour guid\u00e9", en = "Restart guided tour"),
  documentation_link = list(
    fr = "Consulter la documentation compl\u00e8te",
    en = "View full documentation"
  ),
  close = list(fr = "Fermer", en = "Close"),

  # Tour steps
  tour_search_title = list(fr = "Recherche de commune", en = "Municipality Search"),
  tour_search_desc = list(
    fr = "S\u00e9lectionnez d'abord un d\u00e9partement, puis recherchez votre commune par nom ou code postal.",
    en = "First select a department, then search for your municipality by name or postal code."
  ),
  tour_map_title = list(fr = "S\u00e9lection des parcelles", en = "Parcel Selection"),
  tour_map_desc = list(
    fr = "Cliquez sur les parcelles cadastrales pour les s\u00e9lectionner. Un second clic les d\u00e9s\u00e9lectionne. Maximum 20 parcelles.",
    en = "Click on cadastral parcels to select them. A second click deselects them. Maximum 20 parcels."
  ),
  tour_project_title = list(fr = "Nom du projet", en = "Project Name"),
  tour_project_desc = list(
    fr = "Donnez un nom \u00e0 votre projet. Ce champ est obligatoire.",
    en = "Give your project a name. This field is required."
  ),
  tour_description_title = list(fr = "Description", en = "Description"),
  tour_description_desc = list(
    fr = "Ajoutez une description optionnelle pour mieux identifier votre projet.",
    en = "Add an optional description to better identify your project."
  ),
  tour_owner_title = list(fr = "Propri\u00e9taire", en = "Owner"),
  tour_owner_desc = list(
    fr = "Indiquez le nom du propri\u00e9taire ou gestionnaire (optionnel).",
    en = "Enter the name of the owner or manager (optional)."
  ),
  tour_create_title = list(fr = "Cr\u00e9er le projet", en = "Create Project"),
  tour_create_desc = list(
    fr = "Cliquez sur ce bouton pour cr\u00e9er votre projet et passer \u00e0 l'\u00e9tape suivante.",
    en = "Click this button to create your project and proceed to the next step."
  ),
  tour_compute_title = list(fr = "Lancement des calculs", en = "Start Calculations"),
  tour_compute_desc = list(
    fr = "Une fois vos parcelles s\u00e9lectionn\u00e9es et le projet nomm\u00e9, lancez les calculs. Ils s'ex\u00e9cutent en arri\u00e8re-plan.",
    en = "Once parcels are selected and project named, start calculations. They run in the background."
  ),

  # ============================================================
  # Language
  # ============================================================
  language_changed = list(
    fr = "Langue chang\u00e9e. Rechargez la page pour appliquer.",
    en = "Language changed. Reload the page to apply."
  ),

  # ============================================================
  # Errors
  # ============================================================
  error_api_cadastre = list(
    fr = "API Cadastre indisponible, utilisation de la source alternative...",
    en = "Cadastre API unavailable, using fallback source..."
  ),
  error_no_parcels = list(
    fr = "Aucune parcelle trouv\u00e9e pour cette commune",
    en = "No parcels found for this municipality"
  ),
  error_invalid_postal = list(
    fr = "Code postal invalide (5 chiffres requis)",
    en = "Invalid postal code (5 digits required)"
  ),
  error_computation = list(
    fr = "Erreur lors du calcul des indicateurs",
    en = "Error computing indicators"
  ),
  error_no_internet = list(
    fr = "Pas de connexion internet. V\u00e9rifiez votre connexion et r\u00e9essayez.",
    en = "No internet connection. Check your connection and try again."
  ),
  error_loading_communes = list(
    fr = "Erreur lors du chargement des communes : ",
    en = "Error loading municipalities: "
  ),

  # ============================================================
  # Corrupted Projects
  # ============================================================
  project_corrupted_title = list(fr = "Projet corrompu", en = "Corrupted Project"),
  project_corrupted_message = list(
    fr = "Ce projet est corrompu ou incomplet. Voulez-vous le supprimer ?",
    en = "This project is corrupted or incomplete. Do you want to delete it?"
  ),
  delete = list(fr = "Supprimer", en = "Delete"),
  cancel = list(fr = "Annuler", en = "Cancel")
)


#' Get translation object
#'
#' @description
#' Returns a translation object for the specified language.
#'
#' @param language Character. Language code ("fr" or "en").
#'
#' @return A list with a $t() method for translation.
#'
#' @noRd
get_i18n <- function(language = "fr") {
  lang <- match.arg(language, c("fr", "en"))

  # Create translator object
  translator <- list(
    language = lang,

    # Translation function
    t = function(key, ...) {
      if (!key %in% names(TRANSLATIONS)) {
        cli::cli_warn("Translation key not found: {key}")
        return(key)
      }

      text <- TRANSLATIONS[[key]][[lang]]

      if (is.null(text)) {
        # Fallback to English
        text <- TRANSLATIONS[[key]][["en"]]
      }

      if (is.null(text)) {
        return(key)
      }

      # Handle string interpolation
      args <- list(...)
      if (length(args) > 0) {
        text <- glue::glue(text, .envir = as.environment(args))
      }

      as.character(text)
    },

    # Get all keys
    keys = function() {
      names(TRANSLATIONS)
    },

    # Check if key exists
    has = function(key) {
      key %in% names(TRANSLATIONS)
    }
  )

  class(translator) <- c("nemeton_i18n", "list")
  translator
}


#' Print method for i18n object
#'
#' @param x i18n object
#' @param ... Additional arguments (ignored)
#' @noRd
print.nemeton_i18n <- function(x, ...) {
  cat(sprintf("nemeton i18n translator [%s]\n", x$language))
  cat(sprintf("  %d translation keys available\n", length(x$keys())))
  invisible(x)
}


#' Get available languages
#'
#' @return Character vector of language codes
#' @noRd
get_available_languages <- function() {
  c("fr", "en")
}


#' Export translations to JSON files
#'
#' @description
#' Exports the translation dictionary to JSON files for use with shiny.i18n
#' or other i18n systems.
#'
#' @param output_dir Directory to write JSON files.
#'
#' @return Invisible NULL. Creates fr.json and en.json files.
#'
#' @noRd
export_translations_json <- function(output_dir = "inst/app/i18n") {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  for (lang in get_available_languages()) {
    translations <- lapply(TRANSLATIONS, function(t) t[[lang]])
    json_path <- file.path(output_dir, paste0(lang, ".json"))

    jsonlite::write_json(
      translations,
      json_path,
      auto_unbox = TRUE,
      pretty = TRUE
    )

    cli::cli_alert_success("Exported {lang}.json to {json_path}")
  }

  invisible(NULL)
}
