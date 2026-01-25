#' Search Module for nemetonApp
#'
#' @description
#' Shiny module for searching and selecting French communes.
#' Provides department filtering, name autocomplete, and postal code search.
#'
#' @name mod_search
#' @keywords internal
NULL


#' Search Module UI
#'
#' @param id Module namespace ID.
#'
#' @return Shiny UI elements.
#'
#' @noRd
mod_search_ui <- function(id) {
  ns <- shiny::NS(id)
  opts <- get_app_options()
  i18n <- get_i18n(opts$language)

  htmltools::tagList(
    # Department selector
    shiny::selectInput(
      inputId = ns("departement"),
      label = htmltools::tagList(
        bsicons::bs_icon("geo-alt"),
        i18n$t("department")
      ),
      choices = NULL,
      selected = NULL,
      width = "100%"
    ),

    # Commune search with autocomplete
    shiny::selectizeInput(
      inputId = ns("commune"),
      label = htmltools::tagList(
        bsicons::bs_icon("building"),
        i18n$t("commune")
      ),
      choices = NULL,
      options = list(
        placeholder = i18n$t("search_commune"),
        maxOptions = 500
      ),
      width = "100%"
    ),

    # Postal code search
    htmltools::div(
      class = "mb-3",
      shiny::textInput(
        inputId = ns("code_postal"),
        label = htmltools::tagList(
          bsicons::bs_icon("mailbox"),
          i18n$t("postal_code")
        ),
        placeholder = "75001",
        width = "100%"
      ),

      # Search by postal code button
      shiny::actionButton(
        inputId = ns("search_postal"),
        label = NULL,
        icon = shiny::icon("search"),
        class = "btn-outline-secondary btn-sm mt-n2",
        style = "position: absolute; right: 15px; top: 50%; transform: translateY(-50%);"
      )
    ),

    # Results info
    shiny::uiOutput(ns("search_info")),

    # Loading indicator
    shiny::conditionalPanel(
      condition = sprintf("input['%s'] || input['%s']",
                          ns("commune"), ns("search_postal")),
      ns = ns,
      htmltools::div(
        class = "text-center py-2",
        id = ns("loading_indicator"),
        style = "display: none;",
        htmltools::div(
          class = "spinner-border spinner-border-sm text-primary",
          role = "status"
        ),
        htmltools::span(class = "ms-2 text-muted", i18n$t("loading_parcels"))
      )
    )
  )
}


#' Search Module Server
#'
#' @param id Module namespace ID.
#' @param app_state Reactive values for app state.
#'
#' @return List of reactive values:
#'   - selected_commune: Reactive with selected commune code
#'   - commune_info: Reactive with commune metadata
#'   - commune_geometry: Reactive with commune sf geometry
#'
#' @noRd
mod_search_server <- function(id, app_state) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Get language with fallback
    get_lang <- function() {
      lang <- app_state$language
      if (is.null(lang) || lang == "") "fr" else lang
    }

    # ========================================
    # Reactive Values
    # ========================================

    rv <- shiny::reactiveValues(
      selected_commune = NULL,
      commune_info = NULL,
      commune_geometry = NULL,
      is_loading = FALSE
    )


    # ========================================
    # Initialize Department Dropdown (once on start)
    # ========================================

    shiny::observeEvent(TRUE, {
      i18n <- get_i18n(get_lang())
      depts <- get_departments()

      shiny::updateSelectInput(
        session,
        "departement",
        choices = c(
          stats::setNames("", i18n$t("select_department")),
          depts
        )
      )
    }, once = TRUE, ignoreInit = FALSE)


    # ========================================
    # Update Communes When Department Changes
    # ========================================

    shiny::observeEvent(input$departement, {
      dept <- input$departement

      if (is.null(dept) || dept == "") {
        shiny::updateSelectizeInput(
          session,
          "commune",
          choices = character(0),
          server = FALSE
        )
        return()
      }

      # Show loading
      rv$is_loading <- TRUE

      # Fetch communes in department
      tryCatch({
        communes <- get_communes_in_department(dept)

        if (!is.null(communes) && nrow(communes) > 0) {
          choices <- format_communes_for_selectize(communes)
          shiny::updateSelectizeInput(
            session,
            "commune",
            choices = choices,
            server = FALSE
          )
        } else {
          shiny::updateSelectizeInput(
            session,
            "commune",
            choices = character(0),
            server = FALSE
          )
        }
      }, error = function(e) {
        cli::cli_warn("Error fetching communes: {e$message}")
        shiny::showNotification(
          paste("Erreur:", e$message),
          type = "error"
        )
      })

      rv$is_loading <- FALSE
    }, ignoreInit = TRUE)


    # ========================================
    # Handle Commune Selection
    # ========================================

    shiny::observeEvent(input$commune, {
      code <- input$commune

      if (is.null(code) || code == "") {
        rv$selected_commune <- NULL
        rv$commune_info <- NULL
        rv$commune_geometry <- NULL
        return()
      }

      rv$is_loading <- TRUE

      # Get commune geometry
      shiny::withProgress(
        message = get_i18n(get_lang())$t("loading_parcels"),
        value = 0.5,
        {
          geometry <- get_commune_geometry(code)

          if (!is.null(geometry)) {
            rv$selected_commune <- code
            rv$commune_geometry <- geometry

            # Get commune info from search
            dept <- input$departement
            communes <- get_communes_in_department(dept)
            info <- communes[communes$code_insee == code, ]

            if (nrow(info) > 0) {
              rv$commune_info <- as.list(info[1, ])
            }
          }
        }
      )

      rv$is_loading <- FALSE
    }, ignoreInit = TRUE)


    # ========================================
    # Handle Postal Code Search
    # ========================================

    shiny::observeEvent(input$search_postal, {
      postal <- input$code_postal

      if (is.null(postal) || !grepl("^[0-9]{5}$", postal)) {
        shiny::showNotification(
          get_i18n(get_lang())$t("error_invalid_postal"),
          type = "warning"
        )
        return()
      }

      rv$is_loading <- TRUE

      # Search by postal code
      communes <- search_by_postal_code(postal)

      if (nrow(communes) == 0) {
        shiny::showNotification(
          get_i18n(get_lang())$t("error_no_parcels"),
          type = "warning"
        )
        rv$is_loading <- FALSE
        return()
      }

      # If multiple communes, show first one
      code <- communes$code_insee[1]

      # Update department if needed
      dept <- communes$departement[1]
      shiny::updateSelectInput(session, "departement", selected = dept)

      # Update commune selection
      shiny::updateSelectizeInput(
        session,
        "commune",
        choices = format_communes_for_selectize(communes),
        selected = code
      )

      rv$is_loading <- FALSE
    })

    # Also search on Enter key
    shiny::observeEvent(input$code_postal, {
      if (!is.null(input$code_postal) && nchar(input$code_postal) == 5) {
        # Trigger search after a short delay
        shiny::invalidateLater(500)
      }
    }, ignoreInit = TRUE)


    # ========================================
    # Search Info Output
    # ========================================

    output$search_info <- shiny::renderUI({
      i18n <- get_i18n(get_lang())

      if (is.null(rv$commune_info)) {
        return(NULL)
      }

      htmltools::div(
        class = "alert alert-info py-2 px-3 mb-3",
        htmltools::tags$small(
          htmltools::strong(rv$commune_info$nom),
          htmltools::br(),
          sprintf("INSEE: %s", rv$commune_info$code_insee),
          if (!is.null(rv$commune_info$code_postal)) {
            htmltools::span(
              class = "ms-2",
              sprintf("| CP: %s", rv$commune_info$code_postal)
            )
          }
        )
      )
    })


    # ========================================
    # Return Values
    # ========================================

    list(
      selected_commune = shiny::reactive(rv$selected_commune),
      commune_info = shiny::reactive(rv$commune_info),
      commune_geometry = shiny::reactive(rv$commune_geometry),
      is_loading = shiny::reactive(rv$is_loading)
    )
  })
}
