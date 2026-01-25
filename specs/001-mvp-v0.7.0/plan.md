# Plan Technique : nemetonApp v0.7.0

**Version** : 1.0.0
**Date** : 2026-01-25
**Statut** : Draft

---

## 1. Vue d'Ensemble Technique

### 1.1 Architecture Globale

```
┌─────────────────────────────────────────────────────────────────┐
│                         nemetonApp                               │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    UI Layer (Shiny)                         │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐│ │
│  │  │ mod_map  │ │mod_search│ │mod_projet│ │  mod_family_*    ││ │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────────────┘│ │
│  └─────────────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                  Business Logic Layer                        │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐│ │
│  │  │ cadastre │ │ compute  │ │ project  │ │     export       ││ │
│  │  │ _service │ │ _service │ │ _service │ │    _service      ││ │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────────────┘│ │
│  └─────────────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    Data Layer                                │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐│ │
│  │  │ API      │ │ Cache    │ │ nemeton  │ │     i18n         ││ │
│  │  │ clients  │ │ manager  │ │ package  │ │    system        ││ │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────────────┘│ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Stack Technique

| Couche | Technologies |
|--------|-------------|
| Framework Shiny | golem, shiny, bslib |
| UI Components | bslib, bsicons, shinyWidgets |
| Cartographie | leaflet, leaflet.extras |
| Données spatiales | sf, terra, arrow (GeoParquet) |
| Async/Parallel | future, promises, callr |
| Internationalisation | shiny.i18n |
| Onboarding | cicerone |
| Reporting | quarto |
| API clients | httr2, happign |

---

## 2. Structure du Package

### 2.1 Arborescence golem

```
nemeton/
├── R/
│   ├── # Fichiers nemeton existants...
│   │
│   ├── # === nemetonApp (golem) ===
│   ├── app_config.R              # Configuration golem
│   ├── app_server.R              # Server principal
│   ├── app_ui.R                  # UI principal
│   ├── run_app.R                 # Point d'entrée nemeton::run_app()
│   │
│   ├── # === Modules UI ===
│   ├── mod_home.R                # Page d'accueil / projets récents
│   ├── mod_search.R              # Recherche commune
│   ├── mod_map.R                 # Carte et sélection parcelles
│   ├── mod_project.R             # Création/gestion projet
│   ├── mod_progress.R            # Barre de progression
│   ├── mod_synthesis.R           # Onglet synthèse
│   ├── mod_family_carbon.R       # Famille C
│   ├── mod_family_biodiversity.R # Famille B
│   ├── mod_family_water.R        # Famille W
│   ├── mod_family_air.R          # Famille A
│   ├── mod_family_fertility.R    # Famille F
│   ├── mod_family_landscape.R    # Famille L
│   ├── mod_family_temporal.R     # Famille T
│   ├── mod_family_risk.R         # Famille R
│   ├── mod_family_social.R       # Famille S
│   ├── mod_family_production.R   # Famille P
│   ├── mod_family_energy.R       # Famille E
│   ├── mod_family_naturalness.R  # Famille N
│   │
│   ├── # === Services ===
│   ├── service_cadastre.R        # API Cadastre + fallback happign
│   ├── service_compute.R         # Orchestration calculs async
│   ├── service_project.R         # Gestion projets et cache
│   ├── service_export.R          # Export PDF et GeoPackage
│   ├── service_communes.R        # Autocomplétion communes
│   │
│   ├── # === Utilitaires App ===
│   ├── utils_app.R               # Helpers génériques
│   ├── utils_map.R               # Helpers cartographiques
│   ├── utils_i18n.R              # Système i18n pour l'app
│   ├── utils_tour.R              # Configuration tour guidé
│   └── utils_theme.R             # Thème bslib forestier
│
├── inst/
│   ├── app/
│   │   ├── www/
│   │   │   ├── css/
│   │   │   │   └── custom.css    # Styles personnalisés
│   │   │   ├── img/
│   │   │   │   └── logo.png      # Logo nemeton
│   │   │   └── js/
│   │   │       └── custom.js     # JS personnalisé
│   │   └── i18n/
│   │       ├── fr.json           # Traductions françaises
│   │       └── en.json           # Traductions anglaises
│   └── quarto/
│       └── report_template.qmd   # Template rapport PDF
│
└── tests/testthat/
    ├── test-app_server.R
    ├── test-mod_*.R
    └── test-service_*.R
```

### 2.2 Fichiers Clés

#### run_app.R
```r
#' Lancer l'application nemetonApp
#'
#' @param ... Arguments passés à shiny::shinyApp()
#' @param language Langue de l'interface ("fr" ou "en")
#' @param project_dir Répertoire des projets (défaut: ~/.nemeton/projects)
#'
#' @export
#' @examples
#' if (interactive()) {
#'   nemeton::run_app()
#' }
run_app <- function(..., language = NULL, project_dir = NULL) {
  # Configuration
  golem::with_golem_options(
    app = shinyApp(
      ui = app_ui,
      server = app_server
    ),
    golem_opts = list(
      language = language %||% detect_system_language(),
      project_dir = project_dir %||% default_project_dir()
    ),
    ...
  )
}
```

---

## 3. Architecture des Modules

### 3.1 Module Map (mod_map.R)

**Responsabilités** :
- Affichage carte Leaflet
- Gestion fonds de carte (OSM/Satellite)
- Affichage parcelles cadastrales
- Gestion sélection/désélection

**Inputs** :
- `commune_geometry` : sf geometry de la commune
- `parcelles` : sf des parcelles cadastrales

**Outputs** :
- `selected_parcelles` : reactive sf des parcelles sélectionnées
- `selection_count` : reactive integer

**Structure** :
```r
mod_map_ui <- function(id) {
 ns <- NS(id)
 tagList(
   div(class = "map-controls",
     switchInput(ns("basemap"), "OSM", "Satellite"),
     actionButton(ns("clear"), i18n$t("clear_selection"))
   ),
   leafletOutput(ns("map"), height = "500px"),
   verbatimTextOutput(ns("selection_info"))
 )
}

mod_map_server <- function(id, commune_geom, parcelles) {
  moduleServer(id, function(input, output, session) {
    # Reactive values pour la sélection
    selected <- reactiveVal(character(0))

    # Render map
    output$map <- renderLeaflet({
      leaflet() %>%
        addProviderTiles(providers$OpenStreetMap) %>%
        addPolygons(data = parcelles(), ...)
    })

    # Gestion clic
    observeEvent(input$map_shape_click, {
      # Toggle selection
    })

    # Return
    list(
      selected_parcelles = reactive({
        parcelles()[parcelles()$id %in% selected(), ]
      }),
      selection_count = reactive(length(selected()))
    )
  })
}
```

### 3.2 Module Search (mod_search.R)

**Responsabilités** :
- Filtre département
- Autocomplétion commune
- Recherche code postal
- Récupération géométrie commune

**Structure** :
```r
mod_search_ui <- function(id) {
  ns <- NS(id)
  tagList(
    selectInput(ns("departement"), i18n$t("department"),
                choices = get_departements()),
    selectizeInput(ns("commune"), i18n$t("commune"),
                   choices = NULL,
                   options = list(
                     placeholder = i18n$t("search_commune"),
                     searchField = c("label", "code_postal")
                   )),
    textInput(ns("code_postal"), i18n$t("postal_code"))
  )
}
```

### 3.3 Module Progress (mod_progress.R)

**Responsabilités** :
- Affichage progression globale
- Détail des jobs en cours
- Gestion états (pending, running, complete, error)

**Structure** :
```r
mod_progress_ui <- function(id) {
  ns <- NS(id)
  tagList(
    progressBar(ns("global"), value = 0, total = 29,
                title = i18n$t("computing")),
    uiOutput(ns("jobs_detail"))
  )
}
```

### 3.4 Modules Familles (mod_family_*.R)

**Pattern commun** pour les 12 modules :

```r
mod_family_carbon_ui <- function(id) {
  ns <- NS(id)
  tagList(
    h3(icon("leaf"), i18n$t("family_carbon")),
    p(class = "family-description", i18n$t("family_carbon_desc")),

    fluidRow(
      column(6, plotOutput(ns("plot_c1"))),
      column(6, plotOutput(ns("plot_c2")))
    ),

    h4(i18n$t("data_table")),
    DT::dataTableOutput(ns("table")),

    # Indicateurs grisés si manquants
    uiOutput(ns("missing_indicators"))
  )
}

mod_family_carbon_server <- function(id, indicators_data) {
  moduleServer(id, function(input, output, session) {

    # Filtrer indicateurs famille C
    family_data <- reactive({
      indicators_data() %>%
        select(id, starts_with("C"))
    })

    # Graphiques
    output$plot_c1 <- renderPlot({
      plot_indicators_map(family_data(), "C1")
    })

    # Gestion indicateurs manquants
    output$missing_indicators <- renderUI({
      missing <- check_missing_indicators(family_data(), "C")
      if (length(missing) > 0) {
        div(class = "missing-alert",
          icon("exclamation-triangle"),
          sprintf(i18n$t("missing_indicators"), paste(missing, collapse = ", "))
        )
      }
    })
  })
}
```

---

## 4. Services

### 4.1 Service Cadastre (service_cadastre.R)

```r
#' Récupérer les parcelles cadastrales d'une commune
#'
#' @param code_insee Code INSEE de la commune
#' @return sf object avec les parcelles
#' @details Utilise API Cadastre avec fallback sur happign
get_parcelles_cadastrales <- function(code_insee) {

  # Tentative API Cadastre
  result <- tryCatch({
    fetch_api_cadastre(code_insee)
  }, error = function(e) {
    cli::cli_warn("API Cadastre indisponible, fallback happign")
    NULL
  })

  # Fallback happign
 if (is.null(result)) {
    result <- tryCatch({
      fetch_happign_cadastre(code_insee)
    }, error = function(e) {
      cli::cli_abort("Impossible de récupérer les parcelles cadastrales")
    })
  }

  result
}

fetch_api_cadastre <- function(code_insee) {
  url <- sprintf(
    "https://cadastre.data.gouv.fr/bundler/cadastre-etalab/communes/%s/geojson/parcelles",
    code_insee
  )

  resp <- httr2::request(url) %>%
    httr2::req_timeout(30) %>%
    httr2::req_retry(max_tries = 3) %>%
    httr2::req_perform()

  sf::st_read(httr2::resp_body_string(resp), quiet = TRUE)
}

fetch_happign_cadastre <- function(code_insee) {
  happign::get_wfs(
    x = get_commune_geometry(code_insee),
    layer = "CADASTRALPARCELS.PARCELLAIRE_EXPRESS:parcelle",
    spatial_filter = "intersects"
  )
}
```

### 4.2 Service Compute (service_compute.R)

```r
#' Phase 1 : Téléchargement préventif de toutes les données
#'
#' @param parcelles sf des parcelles sélectionnées
#' @param project_path Chemin du projet
#' @param progress_callback Fonction de callback pour la progression
#' @return Liste des layers téléchargées
download_all_layers_async <- function(parcelles, project_path, progress_callback) {

  # Liste des sources de données requises
  data_sources <- list(
    list(name = "cadastre", fetch = fetch_cadastre_data),
    list(name = "bdforet", fetch = fetch_bdforet_data),
    list(name = "protection", fetch = fetch_inpn_protection),
    list(name = "corine", fetch = fetch_corine_data),
    list(name = "hydro", fetch = fetch_hydro_data),
    list(name = "mnt", fetch = fetch_mnt_data)
  )

  # Télécharger chaque source avec retry
 results <- lapply(seq_along(data_sources), function(i) {
    source <- data_sources[[i]]
    progress_callback("download", source$name, i, length(data_sources))

    tryCatch({
      data <- source$fetch(parcelles)
      cache_path <- file.path(project_path, "layers", paste0(source$name, ".parquet"))
      arrow::write_parquet(data, cache_path)
      list(name = source$name, status = "success", path = cache_path)
    }, error = function(e) {
      list(name = source$name, status = "error", message = e$message)
    })
  })

  # Vérifier les échecs critiques
  failures <- Filter(function(x) x$status == "error", results)
  if (length(failures) > 0) {
    stop(sprintf("Échec téléchargement: %s",
                 paste(sapply(failures, `[[`, "name"), collapse = ", ")))
  }

  results
}

#' Phase 2 : Lancer les calculs sur données locales
#'
#' @param parcelles sf des parcelles sélectionnées
#' @param project_path Chemin du projet (avec layers en cache)
#' @param progress_callback Fonction de callback pour la progression
#' @return Promise
compute_indicators_async <- function(parcelles, project_path, progress_callback) {

  # Configuration future
  future::plan(future::multisession, workers = parallel::detectCores() - 1)

  # Charger les layers depuis le cache local
  layers <- load_cached_layers(project_path)

  # Liste des indicateurs à calculer
  indicators <- get_all_indicators()

  # Créer les promises pour chaque indicateur
  promises <- lapply(indicators, function(ind) {
    promises::future_promise({
      tryCatch({
        # Calculer l'indicateur sur données locales
        result <- nemeton::compute_indicator(parcelles, layers, ind)

        list(indicator = ind, result = result, status = "success")
      }, error = function(e) {
        list(indicator = ind, result = NA, status = "error", message = e$message)
      })
    }) %>%
      promises::then(function(result) {
        progress_callback("compute", result$indicator, result$status)
        result
      })
  })

  # Combiner toutes les promises
  promises::promise_all(.list = promises) %>%
    promises::then(function(results) {
      combine_indicator_results(parcelles, results)
    })
}

#' Workflow complet : téléchargement + calcul
#'
#' @param parcelles sf des parcelles
#' @param project_path Chemin du projet
#' @param progress_callback Callback progression
compute_full_workflow <- function(parcelles, project_path, progress_callback) {
  # Phase 1 : Téléchargement préventif
  update_project_status(project_path, "downloading")
  download_all_layers_async(parcelles, project_path, progress_callback)

  # Phase 2 : Calculs sur données locales
  update_project_status(project_path, "computing")
  compute_indicators_async(parcelles, project_path, progress_callback)
}
```

### 4.3 Service Project (service_project.R)

```r
#' Créer un nouveau projet
#'
#' @param name Nom du projet
#' @param description Description (optionnel)
#' @param owner Propriétaire/gestionnaire (optionnel)
#' @return Chemin du répertoire projet
create_project <- function(name, description = NULL, owner = NULL) {

  # Validation
  if (nchar(name) > 100) {
    cli::cli_abort("Le nom du projet ne doit pas dépasser 100 caractères")
  }

  # Créer le répertoire
  project_dir <- file.path(get_projects_root(), sanitize_name(name))
  dir.create(project_dir, recursive = TRUE, showWarnings = FALSE)

  # Métadonnées
  metadata <- list(
    name = name,
    description = description,
    owner = owner,
    created_at = Sys.time(),
    status = "draft",
    version = "0.7.0"
  )

  # Sauvegarder
  jsonlite::write_json(
    metadata,
    file.path(project_dir, "metadata.json"),
    auto_unbox = TRUE,
    pretty = TRUE
  )

  project_dir
}

#' Sauvegarder les parcelles sélectionnées
save_parcelles <- function(project_dir, parcelles) {
  arrow::write_parquet(
    parcelles,
    file.path(project_dir, "parcelles.parquet")
  )
}

#' Sauvegarder les indicateurs calculés
save_indicators <- function(project_dir, indicators) {
  arrow::write_parquet(
    indicators,
    file.path(project_dir, "indicateurs.parquet")
  )
}

#' Charger un projet existant
load_project <- function(project_dir) {
  metadata <- jsonlite::read_json(
    file.path(project_dir, "metadata.json")
  )

  parcelles <- NULL
  indicators <- NULL

  if (file.exists(file.path(project_dir, "parcelles.parquet"))) {
    parcelles <- arrow::read_parquet(
      file.path(project_dir, "parcelles.parquet")
    ) %>% sf::st_as_sf()
  }

  if (file.exists(file.path(project_dir, "indicateurs.parquet"))) {
    indicators <- arrow::read_parquet(
      file.path(project_dir, "indicateurs.parquet")
    ) %>% sf::st_as_sf()
  }

  list(
    metadata = metadata,
    parcelles = parcelles,
    indicators = indicators
  )
}

#' Lister les projets récents
list_recent_projects <- function(n = 10) {
  projects_root <- get_projects_root()

  if (!dir.exists(projects_root)) {
    return(tibble::tibble())
  }

  dirs <- list.dirs(projects_root, recursive = FALSE)

  purrr::map_dfr(dirs, function(d) {
    meta_file <- file.path(d, "metadata.json")
    if (file.exists(meta_file)) {
      meta <- jsonlite::read_json(meta_file)
      health <- check_project_health(d)
      tibble::tibble(
        path = d,
        name = meta$name,
        status = meta$status,
        created_at = meta$created_at,
        is_corrupted = health$corrupted,
        corruption_reason = health$reason
      )
    }
  }) %>%
    dplyr::arrange(desc(created_at)) %>%
    head(n)
}

#' Vérifier la santé d'un projet
#'
#' @param project_dir Répertoire du projet
#' @return Liste avec corrupted (logical) et reason (character)
check_project_health <- function(project_dir) {

  # Vérifier metadata.json
  meta_file <- file.path(project_dir, "metadata.json")
  if (!file.exists(meta_file)) {
    return(list(corrupted = TRUE, reason = "metadata_missing"))
  }

  meta <- tryCatch({
    jsonlite::read_json(meta_file)
  }, error = function(e) {
    return(list(corrupted = TRUE, reason = "metadata_invalid"))
  })

  # Vérifier cohérence état
  if (meta$status == "computing") {
    # Projet interrompu pendant le calcul
    indicators_file <- file.path(project_dir, "indicateurs.parquet")
    if (!file.exists(indicators_file)) {
      return(list(corrupted = TRUE, reason = "computation_interrupted"))
    }
  }

  # Vérifier les fichiers parquet
  parquet_files <- c("parcelles.parquet", "indicateurs.parquet")
  for (pf in parquet_files) {
    pf_path <- file.path(project_dir, pf)
    if (file.exists(pf_path)) {
      valid <- tryCatch({
        arrow::read_parquet(pf_path, as_data_frame = FALSE)
        TRUE
      }, error = function(e) FALSE)

      if (!valid) {
        return(list(corrupted = TRUE, reason = paste0(pf, "_corrupted")))
      }
    }
  }

  list(corrupted = FALSE, reason = NULL)
}

#' Supprimer un projet
#'
#' @param project_dir Répertoire du projet
#' @return TRUE si supprimé avec succès
delete_project <- function(project_dir) {
  if (!dir.exists(project_dir)) {
    cli::cli_warn("Projet non trouvé: {project_dir}")
    return(FALSE)
  }

  unlink(project_dir, recursive = TRUE)
  cli::cli_alert_success("Projet supprimé: {basename(project_dir)}")
  TRUE
}
```

### 4.4 Service Export (service_export.R)

```r
#' Vérifier et installer Quarto si nécessaire
#'
#' @return TRUE si Quarto est disponible
ensure_quarto_installed <- function() {
  if (!quarto::quarto_available()) {
    cli::cli_alert_info("Installation de Quarto en cours...")
    tryCatch({
      quarto::quarto_install()
      cli::cli_alert_success("Quarto installé avec succès")
      TRUE
    }, error = function(e) {
      cli::cli_abort(c(
        "Impossible d'installer Quarto automatiquement",
        "i" = "Installez manuellement depuis https://quarto.org/docs/get-started/"
      ))
    })
  } else {
    TRUE
  }
}

#' Générer le rapport PDF
#'
#' @param project_dir Répertoire du projet
#' @param language Langue du rapport
#' @return Chemin du PDF généré
generate_pdf_report <- function(project_dir, language = "fr") {

  # Vérifier/installer Quarto
 ensure_quarto_installed()

  # Charger le projet
  project <- load_project(project_dir)

  # Préparer les données pour Quarto
  params <- list(
    project_name = project$metadata$name,
    description = project$metadata$description,
    owner = project$metadata$owner,
    date = project$metadata$created_at,
    parcelles = project$parcelles,
    indicators = project$indicators,
    language = language
  )

  # Copier le template
  template_path <- system.file("quarto/report_template.qmd", package = "nemeton")
  output_path <- file.path(project_dir, "report.qmd")
  file.copy(template_path, output_path, overwrite = TRUE)

  # Rendre le rapport
  quarto::quarto_render(
    output_path,
    execute_params = params,
    output_format = "pdf"
  )

  file.path(project_dir, "report.pdf")
}

#' Exporter en GeoPackage
#'
#' @param project_dir Répertoire du projet
#' @return Chemin du GeoPackage
export_geopackage <- function(project_dir) {

  project <- load_project(project_dir)

  output_path <- file.path(project_dir, "export.gpkg")

  # Écrire les couches
  sf::st_write(
    project$indicators,
    output_path,
    layer = "indicateurs",
    driver = "GPKG",
    delete_dsn = TRUE
  )

  # Ajouter métadonnées comme table attributaire
  DBI::dbWriteTable(
    DBI::dbConnect(RSQLite::SQLite(), output_path),
    "metadata",
    as.data.frame(project$metadata)
  )

  output_path
}
```

---

## 5. Interface Utilisateur

### 5.1 Thème bslib Forestier

```r
# utils_theme.R

nemeton_theme <- function() {
  bslib::bs_theme(
    version = 5,
    bootswatch = "flatly",

    # Couleurs forestières (WCAG AA compliant - contraste 4.5:1 minimum)
    primary = "#1B6B1B",      # Forest Green (darkened for contrast)
    secondary = "#6B3710",    # Saddle Brown (darkened)
    success = "#1E7B1E",      # Lime Green (darkened)
    info = "#2B5B8B",         # Steel Blue (darkened)
    warning = "#9B7510",      # Goldenrod (darkened)
    danger = "#B01030",       # Crimson (darkened)

    # Fond
    bg = "#FAFAFA",
    fg = "#2C3E50",

    # Typographie
    base_font = bslib::font_google("Open Sans"),
    heading_font = bslib::font_google("Montserrat"),
    code_font = bslib::font_google("Fira Code"),

    # Tailles responsive
    "enable-responsive-font-sizes" = TRUE
  ) %>%
    bslib::bs_add_rules(
      sass::sass_file(
        system.file("app/www/css/custom.scss", package = "nemeton")
      )
    )
}

#' Configuration accessibilité
#'
#' Règles WCAG 2.1 AA appliquées :
#' - Contraste texte : 4.5:1 minimum
#' - Contraste UI : 3:1 minimum
#' - Focus visible sur tous les éléments
#' - Navigation clavier complète
#' - Palettes daltonisme-friendly (viridis)
accessibility_config <- list(
  # Palettes colorblind-friendly uniquement
  color_palettes = c("viridis", "plasma", "inferno", "magma", "cividis"),
  default_palette = "viridis",

  # Toujours utiliser des symboles en plus des couleurs
  use_symbols = TRUE,
  symbol_shapes = c(16, 17, 15, 18, 8, 3, 4),  # circle, triangle, square, diamond...

  # Tailles minimales tactiles (WCAG)
  min_touch_target = 44,  # pixels

  # Focus visible
  focus_ring_width = 3,
  focus_ring_color = "#005FCC"
)
```

### 5.2 Layout Principal

```r
# app_ui.R

app_ui <- function(request) {
  tagList(
    golem_add_external_resources(),

    page_navbar(
      id = "main_nav",
      title = div(
        img(src = "www/img/logo.png", height = "40px"),
        span("nemetonApp", class = "brand-text")
      ),
      theme = nemeton_theme(),

      # Onglet Accueil / Sélection
      nav_panel(
        title = i18n$t("tab_selection"),
        icon = icon("map-location-dot"),
        mod_home_ui("home")
      ),

      # Onglet Synthèse (conditionnel)
      nav_panel(
        title = i18n$t("tab_synthesis"),
        icon = icon("chart-pie"),
        value = "synthesis",
        mod_synthesis_ui("synthesis")
      ),

      # Onglets Familles (12)
      nav_menu(
        title = i18n$t("tab_families"),
        icon = icon("layer-group"),

        nav_panel(i18n$t("family_C"), mod_family_carbon_ui("carbon")),
        nav_panel(i18n$t("family_B"), mod_family_biodiversity_ui("biodiversity")),
        nav_panel(i18n$t("family_W"), mod_family_water_ui("water")),
        nav_panel(i18n$t("family_A"), mod_family_air_ui("air")),
        nav_panel(i18n$t("family_F"), mod_family_fertility_ui("fertility")),
        nav_panel(i18n$t("family_L"), mod_family_landscape_ui("landscape")),
        nav_panel(i18n$t("family_T"), mod_family_temporal_ui("temporal")),
        nav_panel(i18n$t("family_R"), mod_family_risk_ui("risk")),
        nav_panel(i18n$t("family_S"), mod_family_social_ui("social")),
        nav_panel(i18n$t("family_P"), mod_family_production_ui("production")),
        nav_panel(i18n$t("family_E"), mod_family_energy_ui("energy")),
        nav_panel(i18n$t("family_N"), mod_family_naturalness_ui("naturalness"))
      ),

      # Navbar items
      nav_spacer(),
      nav_item(
        selectInput("language", NULL,
                    choices = c("FR" = "fr", "EN" = "en"),
                    width = "80px")
      ),
      nav_item(
        actionLink("help", icon("circle-question"),
                   title = i18n$t("help"))
      )
    )
  )
}
```

### 5.3 Tour Guidé

```r
# utils_tour.R

create_app_tour <- function() {
  cicerone::Cicerone$new()$
    step(
      el = "#home-search",
      title = i18n$t("tour_search_title"),
      description = i18n$t("tour_search_desc")
    )$
    step(
      el = "#home-map",
      title = i18n$t("tour_map_title"),
      description = i18n$t("tour_map_desc")
    )$
    step(
      el = "#home-selection",
      title = i18n$t("tour_selection_title"),
      description = i18n$t("tour_selection_desc")
    )$
    step(
      el = "#home-project",
      title = i18n$t("tour_project_title"),
      description = i18n$t("tour_project_desc")
    )$
    step(
      el = "#home-compute",
      title = i18n$t("tour_compute_title"),
      description = i18n$t("tour_compute_desc")
    )
}
```

---

## 6. Internationalisation

### 6.1 Structure des Fichiers de Traduction

**inst/app/i18n/fr.json** :
```json
{
  "app_title": "nemetonApp - Diagnostic Forestier",
  "tab_selection": "Sélection",
  "tab_synthesis": "Synthèse",
  "tab_families": "Familles d'indicateurs",

  "search_commune": "Rechercher une commune...",
  "department": "Département",
  "postal_code": "Code postal",

  "selected_parcels": "Parcelles sélectionnées",
  "max_parcels_warning": "Maximum 20 parcelles atteint",
  "clear_selection": "Tout désélectionner",

  "project_name": "Nom du projet",
  "project_description": "Description",
  "project_owner": "Propriétaire/Gestionnaire",
  "project_date": "Date d'étude",

  "compute_button": "Lancer les calculs",
  "computing": "Calcul en cours...",
  "computing_indicator": "Calcul de l'indicateur {indicator}",

  "download_pdf": "Télécharger le rapport PDF",
  "download_gpkg": "Télécharger le GeoPackage",

  "family_C": "Carbone & Vitalité",
  "family_B": "Biodiversité",
  "family_W": "Eau",
  "family_A": "Air & Microclimat",
  "family_F": "Fertilité des Sols",
  "family_L": "Paysage",
  "family_T": "Dynamique Temporelle",
  "family_R": "Risques & Résilience",
  "family_S": "Social & Récréatif",
  "family_P": "Production",
  "family_E": "Énergie & Climat",
  "family_N": "Naturalité",

  "missing_indicator": "Indicateur non disponible : {reason}",
  "missing_lidar": "Données LiDAR non disponibles",
  "missing_connection": "Connexion au serveur impossible",

  "help": "Aide",
  "documentation": "Documentation nemeton",
  "tour_restart": "Relancer le tour guidé"
}
```

### 6.2 Implémentation i18n

```r
# utils_i18n.R

#' Initialiser le système i18n
init_i18n <- function(language = "fr") {
  shiny.i18n::Translator$new(
    translation_json_path = system.file(
      "app/i18n",
      package = "nemeton"
    )
  )$set_translation_language(language)
}

#' Obtenir un traducteur réactif
get_i18n_reactive <- function(input) {
  reactive({
    i18n <- init_i18n(input$language)
    i18n
  })
}
```

---

## 7. Gestion des Erreurs

### 7.1 Stratégie de Fallback

```r
# Hiérarchie de fallback pour les sources de données
DATA_SOURCES <- list(
  cadastre = list(
    primary = "api_cadastre",
    fallback = "happign"
  ),
  protection = list(
    primary = "inpn_wfs",
    fallback = "local_cache"
  ),
  foret = list(
    primary = "ign_wfs",
    fallback = "local_cache"
  )
)

#' Récupérer des données avec fallback
fetch_with_fallback <- function(source_config, ...) {
  result <- tryCatch({
    do.call(paste0("fetch_", source_config$primary), list(...))
  }, error = function(e) {
    cli::cli_warn("Source primaire indisponible: {e$message}")
    NULL
  })

  if (is.null(result) && !is.null(source_config$fallback)) {
    result <- tryCatch({
      do.call(paste0("fetch_", source_config$fallback), list(...))
    }, error = function(e) {
      cli::cli_abort("Toutes les sources ont échoué")
    })
  }

  result
}
```

### 7.2 Gestion des Indicateurs Manquants

```r
#' Vérifier les indicateurs manquants
check_missing_indicators <- function(data, family_prefix) {
  expected <- get_indicators_by_family(family_prefix)
  present <- names(data)[grepl(paste0("^", family_prefix, "\\d"), names(data))]

  missing <- setdiff(expected, present)

  # Déterminer la raison
  lapply(missing, function(ind) {
    list(
      indicator = ind,
      reason = diagnose_missing_reason(ind)
    )
  })
}

diagnose_missing_reason <- function(indicator) {
  # Logique pour déterminer pourquoi l'indicateur est manquant
  # (LiDAR absent, connexion KO, données source manquantes, etc.)
}
```

---

## 8. Tests

### 8.1 Stratégie de Tests

| Type | Couverture Cible | Outils |
|------|-----------------|--------|
| Unitaires | Services, utils | testthat |
| Modules | Chaque module UI | shinytest2 |
| Intégration | Flux complets | shinytest2 |
| Snapshot | UI rendering | shinytest2 |

### 8.2 Exemple de Tests

```r
# tests/testthat/test-service_cadastre.R

test_that("get_parcelles_cadastrales retourne un sf valide", {
  skip_if_offline()

  parcelles <- get_parcelles_cadastrales("75056") # Paris

  expect_s3_class(parcelles, "sf")
  expect_gt(nrow(parcelles), 0)
  expect_true("geometry" %in% names(parcelles))
})

test_that("fallback happign fonctionne si API cadastre indisponible", {
  # Mock API cadastre failure
  mockery::stub(
    get_parcelles_cadastrales,
    "fetch_api_cadastre",
    function(...) stop("API error")
  )

  parcelles <- get_parcelles_cadastrales("75056")

  expect_s3_class(parcelles, "sf")
})

# tests/testthat/test-mod_map.R

test_that("mod_map sélectionne et désélectionne correctement", {
  testServer(mod_map_server, {
    # Simuler des parcelles
    session$setInputs(
      map_shape_click = list(id = "parcelle_1")
    )

    expect_equal(selection_count(), 1)

    # Désélectionner
    session$setInputs(
      map_shape_click = list(id = "parcelle_1")
    )

    expect_equal(selection_count(), 0)
  })
})
```

---

## 9. Déploiement

### 9.1 Installation

```r
# Le package nemeton inclut nemetonApp
install.packages("nemeton")

# Ou depuis GitHub
remotes::install_github("pobsteta/nemeton")

# Lancer l'application
nemeton::run_app()
```

### 9.2 Prérequis Système

- **R** >= 4.1.0
- **Quarto** >= 1.3 (pour génération PDF)
- **TinyTeX** ou autre distribution LaTeX (pour PDF)
- Connexion Internet (pour API externes)

### 9.3 Configuration

```r
# Options configurables via options()
options(
  nemeton.project_dir = "~/.nemeton/projects",
  nemeton.language = "fr",
  nemeton.max_parcelles = 20,
  nemeton.timeout_api = 30,
  nemeton.parallel_workers = 4
)
```

---

## 10. Phases d'Implémentation

### Phase 1 : Infrastructure (Semaine 1-2)
- [ ] Setup golem
- [ ] Structure des fichiers
- [ ] Thème bslib
- [ ] Configuration i18n
- [ ] Tests de base

### Phase 2 : Sélection Parcelles (Semaine 3-4)
- [ ] mod_search (communes)
- [ ] mod_map (carte + parcelles)
- [ ] service_cadastre
- [ ] service_communes

### Phase 3 : Gestion Projets (Semaine 5)
- [ ] mod_project
- [ ] service_project
- [ ] Cache GeoParquet

### Phase 4 : Calculs Async (Semaine 6-7)
- [ ] service_compute
- [ ] mod_progress
- [ ] Intégration nemeton_compute()

### Phase 5 : Analyses Familles (Semaine 8-10)
- [ ] mod_synthesis
- [ ] mod_family_* (×12)
- [ ] Visualisations

### Phase 6 : Exports (Semaine 11)
- [ ] service_export
- [ ] Template Quarto
- [ ] Export GeoPackage

### Phase 7 : Finitions (Semaine 12)
- [ ] Tour guidé (cicerone)
- [ ] Documentation
- [ ] Tests complets
- [ ] Responsive design
