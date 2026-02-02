#' Search Module for nemetonApp
#'
#' @description
#' Shiny module for searching and selecting French communes.
#' Provides department filtering and commune selection.
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

    # Results info
    shiny::uiOutput(ns("search_info")),

    # Loading indicator
    shiny::conditionalPanel(
      condition = sprintf("input['%s']", ns("commune")),
      ns = ns,
      htmltools::div(
        class = "text-center py-2",
        id = ns("loading_indicator"),
        style = "display: none;",
        htmltools::div(
          class = "spinner-border spinner-border-sm text-primary",
          role = "status"
        ),
        htmltools::span(class = "ms-2 text-muted", i18n$t("loading_commune"))
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
      is_loading = FALSE,
      is_restoring = FALSE,
      department_changed = NULL  # Signal when department changes (timestamp)
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
      i18n <- get_i18n(get_lang())

      # During project restore, the restore observer handles commune loading
      # directly via later::later - skip redundant API call here
      if (rv$is_restoring) return()

      # Signal that department changed (so other modules can reset state)
      rv$department_changed <- Sys.time()

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

      # Fetch communes asynchronously so the browser stays responsive
      promises::future_promise({
        get_communes_in_department(dept)
      }) %...>% (function(communes) {
        # Check for errors (returned as attribute)
        error_type <- attr(communes, "error")
        if (!is.null(error_type)) {
          if (error_type == "network") {
            shiny::showNotification(
              i18n$t("error_no_internet"),
              type = "error",
              duration = 8
            )
          } else {
            shiny::showNotification(
              paste(i18n$t("error_loading_communes"), attr(communes, "error_message")),
              type = "error",
              duration = 8
            )
          }
          shiny::updateSelectizeInput(
            session,
            "commune",
            choices = character(0),
            selected = "",
            server = FALSE
          )
        } else if (!is.null(communes) && nrow(communes) > 0) {
          choices <- format_communes_for_selectize(communes)
          shiny::updateSelectizeInput(
            session,
            "commune",
            choices = choices,
            selected = "",
            server = FALSE
          )
        } else {
          shiny::updateSelectizeInput(
            session,
            "commune",
            choices = character(0),
            selected = "",
            server = FALSE
          )
        }

        rv$is_loading <- FALSE
      }) %...!% (function(err) {
        cli::cli_alert_danger("Error loading communes: {err$message}")
        shiny::showNotification(
          paste(i18n$t("error_loading_communes"), err$message),
          type = "error",
          duration = 8
        )
        rv$is_loading <- FALSE
      })
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
      is_restoring <- rv$is_restoring
      dept <- input$departement

      # Fetch commune geometry + info asynchronously
      promises::future_promise({
        geometry <- get_commune_geometry(code)
        communes <- get_communes_in_department(dept)
        list(geometry = geometry, communes = communes)
      }) %...>% (function(result) {
        if (!is.null(result$geometry)) {
          rv$selected_commune <- code
          rv$commune_geometry <- result$geometry

          communes <- result$communes
          if (!is.null(communes) && nrow(communes) > 0) {
            info <- communes[communes$code_insee == code, ]
            if (nrow(info) > 0) {
              rv$commune_info <- as.list(info[1, ])
            }
          }
        }

        if (is_restoring) {
          rv$is_restoring <- FALSE
        }
        rv$is_loading <- FALSE
      }) %...!% (function(err) {
        cli::cli_alert_danger("Error loading commune: {err$message}")
        if (is_restoring) {
          rv$is_restoring <- FALSE
        }
        rv$is_loading <- FALSE
      })
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
    # Restore Project Location
    # ========================================

    shiny::observeEvent(app_state$restore_project, {
      restore <- app_state$restore_project
      if (is.null(restore) || is.null(restore$commune_code)) return()

      dept_code <- restore$department_code
      commune_code <- restore$commune_code

      cli::cli_alert_info("Restoring location: dept={dept_code}, commune={commune_code}")

      # Flag to prevent department observer from making redundant API calls
      rv$is_restoring <- TRUE

      # Update department dropdown
      shiny::updateSelectInput(session, "departement", selected = dept_code)

      # Load communes for department and update with delay to ensure dept is updated first
      later::later(function() {
        communes <- get_communes_in_department(dept_code)
        if (!is.null(communes) && nrow(communes) > 0) {
          choices <- format_communes_for_selectize(communes)

          cli::cli_alert_info("Updating commune dropdown with {nrow(communes)} choices")

          # Update commune dropdown with choices and selection
          # This triggers the input$commune observer which handles
          # commune_geometry, commune_info, and selected_commune
          shiny::updateSelectizeInput(
            session,
            "commune",
            choices = choices,
            selected = commune_code,
            server = FALSE
          )

          cli::cli_alert_success("Location restored successfully")
        }

        # NOTE: Do NOT clear rv$is_restoring here. The updateSelectizeInput
        # above queues a message to the browser; the commune observer fires
        # on a LATER flush when the browser sends back the new input$commune.
        # If we clear the flag now, the commune observer sees is_restoring=FALSE
        # and uses withProgress, which causes the green flash.
        # The flag is cleared in the commune observer after load_commune().
      }, delay = 0.5)  # 500ms delay to ensure department dropdown is updated
    }, ignoreInit = TRUE)


    # ========================================
    # Return Values
    # ========================================

    list(
      selected_commune = shiny::reactive(rv$selected_commune),
      commune_info = shiny::reactive(rv$commune_info),
      commune_geometry = shiny::reactive(rv$commune_geometry),
      is_loading = shiny::reactive(rv$is_loading),
      department_changed = shiny::reactive(rv$department_changed)
    )
  })
}
