#' nemetonApp UI
#'
#' @description
#' Main UI function for the nemetonApp Shiny application.
#' Uses bslib page_navbar with a forest theme.
#'
#' @param request Internal parameter for bookmarking.
#' @return A Shiny UI definition.
#'
#' @noRd
app_ui <- function(request) {
  # Get current language
 opts <- get_app_options()
  lang <- opts$language

  # Get translations
  i18n <- get_i18n(lang)

  htmltools::tagList(
    # Add external resources (CSS, JS)
    app_add_external_resources(),

    # Main page with navbar
    bslib::page_navbar(
      id = "main_nav",
      title = htmltools::div(
        class = "d-flex align-items-center",
        htmltools::img(
          src = "www/img/logo.png",
          height = "36px",
          class = "me-2",
          alt = "nemeton logo"
        ),
        htmltools::span("nemetonApp", class = "fw-bold")
      ),
      window_title = i18n$t("app_title"),
      theme = nemeton_theme(),
      fillable = TRUE,
      bg = "#1B6B1B",

      # === Tab 1: Selection ===
      bslib::nav_panel(
        title = i18n$t("tab_selection"),
        value = "selection",
        icon = bsicons::bs_icon("map"),
        mod_home_ui("home")
      ),

      # === Tab 2: Synthesis (conditional) ===
      bslib::nav_panel(
        title = i18n$t("tab_synthesis"),
        value = "synthesis",
        icon = bsicons::bs_icon("pie-chart"),
        mod_synthesis_ui("synthesis")
      ),

      # === Tabs 3-14: Indicator Families ===
      bslib::nav_menu(
        title = i18n$t("tab_families"),
        icon = bsicons::bs_icon("layers"),

        bslib::nav_panel(
          title = i18n$t("family_C"),
          value = "family_C",
          mod_family_ui("family_C", "C")
        ),
        bslib::nav_panel(
          title = i18n$t("family_B"),
          value = "family_B",
          mod_family_ui("family_B", "B")
        ),
        bslib::nav_panel(
          title = i18n$t("family_W"),
          value = "family_W",
          mod_family_ui("family_W", "W")
        ),
        bslib::nav_panel(
          title = i18n$t("family_A"),
          value = "family_A",
          mod_family_ui("family_A", "A")
        ),
        bslib::nav_panel(
          title = i18n$t("family_F"),
          value = "family_F",
          mod_family_ui("family_F", "F")
        ),
        bslib::nav_panel(
          title = i18n$t("family_L"),
          value = "family_L",
          mod_family_ui("family_L", "L")
        ),
        bslib::nav_panel(
          title = i18n$t("family_T"),
          value = "family_T",
          mod_family_ui("family_T", "T")
        ),
        bslib::nav_panel(
          title = i18n$t("family_R"),
          value = "family_R",
          mod_family_ui("family_R", "R")
        ),
        bslib::nav_panel(
          title = i18n$t("family_S"),
          value = "family_S",
          mod_family_ui("family_S", "S")
        ),
        bslib::nav_panel(
          title = i18n$t("family_P"),
          value = "family_P",
          mod_family_ui("family_P", "P")
        ),
        bslib::nav_panel(
          title = i18n$t("family_E"),
          value = "family_E",
          mod_family_ui("family_E", "E")
        ),
        bslib::nav_panel(
          title = i18n$t("family_N"),
          value = "family_N",
          mod_family_ui("family_N", "N")
        )
      ),

      # === Navbar items (right side) ===
      bslib::nav_spacer(),

      # Language selector
      bslib::nav_item(
        shiny::selectInput(
          inputId = "app_language",
          label = NULL,
          choices = c("FR" = "fr", "EN" = "en"),
          selected = lang,
          width = "80px"
        )
      ),

      # Help button
      bslib::nav_item(
        shiny::actionLink(
          inputId = "show_help",
          label = NULL,
          icon = bsicons::bs_icon("question-circle"),
          class = "nav-link",
          title = i18n$t("help")
        )
      )
    )
  )
}


#' Add external resources to the app
#'
#' @description
#' Adds CSS, JavaScript, and other external resources to the app.
#'
#' @return A tagList of HTML dependencies.
#' @noRd
app_add_external_resources <- function() {
  htmltools::tagList(
    # Add CSS
    htmltools::tags$head(
      # Custom CSS
      htmltools::tags$link(
        rel = "stylesheet",
        type = "text/css",
        href = "www/css/custom.css"
      ),
      # Favicon
      htmltools::tags$link(
        rel = "icon",
        type = "image/png",
        href = "www/img/logo.png"
      ),
      # Meta tags for mobile
      htmltools::tags$meta(
        name = "viewport",
        content = "width=device-width, initial-scale=1"
      ),
      htmltools::tags$meta(
        name = "theme-color",
        content = "#1B6B1B"
      )
    ),

    # Add JS
    htmltools::tags$script(
      src = "www/js/custom.js"
    ),

    # Shiny busy indicator
    shiny::tags$style(
      htmltools::HTML("
        .shiny-busy {
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          height: 3px;
          background: linear-gradient(90deg, #1B6B1B, #32CD32, #1B6B1B);
          background-size: 200% 100%;
          animation: loading 1.5s infinite;
          z-index: 9999;
        }
        @keyframes loading {
          0% { background-position: 200% 0; }
          100% { background-position: -200% 0; }
        }
      ")
    )
  )
}


#' Placeholder for mod_home_ui
#'
#' @param id Module ID
#' @return UI elements
#' @noRd
mod_home_ui <- function(id) {
  ns <- shiny::NS(id)
  opts <- get_app_options()
  i18n <- get_i18n(opts$language)

  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      id = ns("sidebar"),
      title = i18n$t("search_title"),
      width = 350,

      # Department filter
      shiny::selectInput(
        inputId = ns("departement"),
        label = i18n$t("department"),
        choices = NULL,
        selected = NULL
      ),

      # Commune search
      shiny::selectizeInput(
        inputId = ns("commune"),
        label = i18n$t("commune"),
        choices = NULL,
        options = list(
          placeholder = i18n$t("search_commune"),
          maxOptions = 100
        )
      ),

      # Postal code
      shiny::textInput(
        inputId = ns("code_postal"),
        label = i18n$t("postal_code"),
        placeholder = "75001"
      ),

      shiny::hr(),

      # Selection info
      shiny::h5(i18n$t("selected_parcels")),
      shiny::uiOutput(ns("selection_info")),

      shiny::hr(),

      # Project form
      shiny::h5(i18n$t("project_info")),
      shiny::textInput(
        inputId = ns("project_name"),
        label = i18n$t("project_name"),
        placeholder = i18n$t("project_name_placeholder")
      ),
      shiny::textAreaInput(
        inputId = ns("project_description"),
        label = i18n$t("project_description"),
        placeholder = i18n$t("project_description_placeholder"),
        rows = 2
      ),
      shiny::textInput(
        inputId = ns("project_owner"),
        label = i18n$t("project_owner"),
        placeholder = i18n$t("project_owner_placeholder")
      ),

      shiny::hr(),

      # Action buttons
      shiny::actionButton(
        inputId = ns("btn_compute"),
        label = i18n$t("compute_button"),
        icon = shiny::icon("play"),
        class = "btn-primary btn-lg w-100",
        disabled = TRUE
      )
    ),

    # Main content: Map
    bslib::card(
      full_screen = TRUE,
      bslib::card_header(
        class = "d-flex justify-content-between align-items-center",
        htmltools::span(i18n$t("map_title")),
        htmltools::div(
          class = "btn-group",
          role = "group",
          shiny::actionButton(
            ns("basemap_osm"),
            "OSM",
            class = "btn btn-sm btn-outline-secondary active"
          ),
          shiny::actionButton(
            ns("basemap_satellite"),
            "Satellite",
            class = "btn btn-sm btn-outline-secondary"
          )
        )
      ),
      bslib::card_body(
        padding = 0,
        # Placeholder for leaflet map
        shiny::div(
          id = ns("map_container"),
          style = "height: 100%; min-height: 500px;",
          shiny::uiOutput(ns("map_placeholder"))
        )
      )
    )
  )
}


#' Placeholder for mod_synthesis_ui
#'
#' @param id Module ID
#' @return UI elements
#' @noRd
mod_synthesis_ui <- function(id) {
  ns <- shiny::NS(id)
  opts <- get_app_options()
  i18n <- get_i18n(opts$language)

  bslib::layout_columns(
    col_widths = c(12),

    # Top row: Downloads and summary
    bslib::card(
      bslib::card_header(i18n$t("synthesis_title")),
      bslib::card_body(
        bslib::layout_columns(
          col_widths = c(6, 6),

          # Download buttons
          htmltools::div(
            class = "d-grid gap-2",
            shiny::downloadButton(
              ns("download_pdf"),
              label = i18n$t("download_pdf"),
              icon = shiny::icon("file-pdf"),
              class = "btn-success btn-lg"
            ),
            shiny::downloadButton(
              ns("download_gpkg"),
              label = i18n$t("download_gpkg"),
              icon = shiny::icon("database"),
              class = "btn-primary btn-lg"
            )
          ),

          # Project summary
          shiny::uiOutput(ns("project_summary"))
        )
      )
    ),

    # Radar plot
    bslib::card(
      bslib::card_header(i18n$t("radar_title")),
      bslib::card_body(
        shiny::plotOutput(ns("radar_plot"), height = "400px")
      )
    ),

    # Summary table
    bslib::card(
      bslib::card_header(i18n$t("summary_table_title")),
      bslib::card_body(
        shiny::tableOutput(ns("summary_table"))
      )
    )
  )
}


#' Placeholder for mod_family_ui
#'
#' @param id Module ID
#' @param family_code Character. Family code (C, B, W, etc.)
#' @return UI elements
#' @noRd
mod_family_ui <- function(id, family_code) {
  ns <- shiny::NS(id)
  opts <- get_app_options()
  i18n <- get_i18n(opts$language)
  family <- get_family_config(family_code)

  if (is.null(family)) {
    return(htmltools::div("Unknown family"))
  }

  family_name <- if (opts$language == "fr") family$name_fr else family$name_en

  bslib::layout_columns(
    col_widths = c(12),

    # Family header
    bslib::card(
      bslib::card_header(
        class = "d-flex align-items-center",
        bsicons::bs_icon(family$icon, class = "me-2"),
        htmltools::span(family_name, class = "fw-bold")
      ),
      bslib::card_body(
        shiny::p(
          class = "text-muted",
          i18n$t(paste0("family_", family_code, "_desc"))
        )
      )
    ),

    # Plots (2 columns)
    bslib::layout_columns(
      col_widths = c(6, 6),
      bslib::card(
        bslib::card_body(
          shiny::plotOutput(ns("plot1"), height = "300px")
        )
      ),
      bslib::card(
        bslib::card_body(
          shiny::plotOutput(ns("plot2"), height = "300px")
        )
      )
    ),

    # Data table
    bslib::card(
      bslib::card_header(i18n$t("data_table")),
      bslib::card_body(
        shiny::tableOutput(ns("indicator_table"))
      )
    ),

    # Missing indicators warning
    shiny::uiOutput(ns("missing_warning"))
  )
}
