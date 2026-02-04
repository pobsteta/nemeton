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

  # Disable Shiny 1.8+ / bslib 0.6+ busy indicators (white overlays)
  busy_indicator_tag <- tryCatch(
    shiny::useBusyIndicators(spinners = FALSE, pulse = FALSE),
    error = function(e) NULL
  )

  htmltools::tagList(
    # Add external resources (CSS, JS)
    app_add_external_resources(),

    # Disable busy indicators (safe — returns NULL if function doesn't exist)
    busy_indicator_tag,

    # Cicerone for guided tours
    if (requireNamespace("cicerone", quietly = TRUE)) cicerone::use_cicerone(),

    # Main page with navbar
    bslib::page_navbar(
      id = "main_nav",
      title = htmltools::img(
        src = "www/img/logo.svg",
        height = "80px",
        alt = "N\u00e9m\u00e9ton logo"
      ),
      window_title = i18n$t("app_title"),
      theme = nemeton_theme(),
      fillable = TRUE,
      navbar_options = bslib::navbar_options(bg = "#1B6B1B"),

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
  # Add resource path for static files (www folder)
  www_path <- system.file("app/www", package = "nemeton")
  if (www_path != "") {
    shiny::addResourcePath("www", www_path)
  }

  htmltools::tagList(
    # Add CSS
    htmltools::tags$head(
      # Critical inline CSS: loads BEFORE external stylesheets to prevent
      # flash of white background while custom.css is being fetched.
      htmltools::tags$style(htmltools::HTML("
        html, body { background-color: #f0f0f0 !important; }
        .bslib-page-fill, .html-fill-container { background-color: #f0f0f0 !important; }
        .card, .bslib-card { background-color: #ffffff !important; }
        .bslib-page-fill::after, .bslib-page-fill::before,
        .html-fill-container::after, .html-fill-container::before {
          content: none !important; display: none !important;
        }
      ")),
      # Custom CSS (cache-busting to ensure latest version)
      htmltools::tags$link(
        rel = "stylesheet",
        type = "text/css",
        href = paste0("www/css/custom.css?v=", as.integer(Sys.time()))
      ),
      # Favicon
      htmltools::tags$link(
        rel = "icon",
        type = "image/svg+xml",
        href = "www/img/logo.svg"
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

    # Custom JS (cache-busting query string forces browser to reload on each app start)
    htmltools::tags$script(
      src = paste0("www/js/custom.js?v=", as.integer(Sys.time()))
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

    # Top row: Downloads, summary, and global score
    bslib::card(
      bslib::card_header(i18n$t("synthesis_title")),
      bslib::card_body(
        bslib::layout_columns(
          col_widths = c(4, 4, 4),

          # Project summary
          shiny::uiOutput(ns("project_summary")),

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

          # Global score
          shiny::uiOutput(ns("global_score"))
        )
      )
    ),

    # Radar plot + Summary table side by side
    bslib::layout_columns(
      col_widths = c(7, 5),
      bslib::card(
        bslib::card_header(i18n$t("radar_title")),
        bslib::card_body(
          shiny::plotOutput(ns("radar_plot"), height = "500px")
        )
      ),
      bslib::card(
        bslib::card_header(i18n$t("summary_table_title")),
        bslib::card_body(
          shiny::tableOutput(ns("summary_table"))
        )
      )
    ),

    # Comments card with AI generation
    bslib::card(
      bslib::card_header(
        class = "d-flex justify-content-between align-items-center flex-wrap gap-2",
        i18n$t("comments_title"),
        htmltools::div(
          class = "d-flex align-items-center gap-2",
          htmltools::div(
            class = "expert-select-inline",
            shiny::selectInput(
              ns("expert_profile"),
              label = NULL,
              choices = stats::setNames(
                c("generalist", "owner", "manager", "politician", "producer", "citizen", "hunter"),
                c(i18n$t("expert_generalist"), i18n$t("expert_owner"), i18n$t("expert_manager"),
                  i18n$t("expert_politician"), i18n$t("expert_producer"), i18n$t("expert_citizen"),
                  i18n$t("expert_hunter"))
              ),
              selected = "generalist",
              width = "auto"
            )
          ),
          shiny::actionButton(
            ns("ai_generate"),
            label = i18n$t("ai_generate"),
            icon = shiny::icon("robot"),
            class = "btn-outline-primary btn-sm"
          )
        )
      ),
      bslib::card_body(
        shiny::textAreaInput(
          ns("synthesis_comments"),
          label = NULL,
          placeholder = i18n$t("synthesis_comments_placeholder"),
          rows = 12,
          width = "100%"
        )
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

  htmltools::tagList(
    # Family header
    htmltools::div(
      class = "d-flex align-items-center mb-3",
      bsicons::bs_icon(family$icon, class = "me-2"),
      htmltools::span(family_name, class = "fw-bold me-2"),
      htmltools::span(
        class = "text-muted",
        paste0("\u2014 ", i18n$t(paste0("family_", family_code, "_desc")))
      )
    ),

    # Maps (dynamic: adapts to number of indicators)
    shiny::uiOutput(ns("maps_row")),

    # Data table + Statistics + Comments (3 columns)
    bslib::layout_columns(
      col_widths = c(4, 4, 4),
      bslib::card(
        bslib::card_header(i18n$t("data_table")),
        bslib::card_body(
          DT::dataTableOutput(ns("indicator_table"))
        )
      ),
      bslib::card(
        bslib::card_header(i18n$t("statistics_title")),
        bslib::card_body(
          shiny::uiOutput(ns("analysis_stats"))
        )
      ),
      bslib::card(
        bslib::card_header(
          class = "d-flex justify-content-between align-items-center flex-wrap gap-2",
          i18n$t("comments_title"),
          htmltools::div(
            class = "d-flex align-items-center gap-2",
            htmltools::div(
              class = "expert-select-inline",
              shiny::selectInput(
                ns("expert_profile"),
                label = NULL,
                choices = stats::setNames(
                  c("generalist", "owner", "manager", "politician", "producer", "citizen", "hunter"),
                  c(i18n$t("expert_generalist"), i18n$t("expert_owner"), i18n$t("expert_manager"),
                    i18n$t("expert_politician"), i18n$t("expert_producer"), i18n$t("expert_citizen"),
                    i18n$t("expert_hunter"))
                ),
                selected = "generalist",
                width = "auto"
              )
            ),
            shiny::actionButton(
              ns("ai_generate"),
              label = i18n$t("ai_generate"),
              icon = shiny::icon("robot"),
              class = "btn-outline-primary btn-sm"
            )
          )
        ),
        bslib::card_body(
          shiny::textAreaInput(
            ns("analysis_comments"),
            label = NULL,
            placeholder = i18n$t("analysis_comments_placeholder"),
            rows = 12,
            width = "100%"
          )
        )
      )
    ),

    # Missing indicators warning
    shiny::uiOutput(ns("missing_warning"))
  )
}
