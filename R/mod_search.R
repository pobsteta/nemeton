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
    # ExtendedTask: non-blocking API calls
    #
    # Unlike future_promise() in observers (which still blocks the
    # current session), ExtendedTask truly frees the session so the
    # browser stays responsive during the API call.
    # ========================================

    .pkg_path <- tryCatch(pkgload::pkg_path(), error = function(e) NULL)

    # Helper: ensure future plan is parallel in the worker
    ensure_future_plan <- function() {
      if (requireNamespace("future", quietly = TRUE)) {
        plan_classes <- class(future::plan())
        is_parallel <- any(c("multisession", "multicore", "cluster") %in% plan_classes)
        if (!is_parallel) future::plan("multisession")
      }
    }

    # Helper: load nemeton in the future worker process
    load_nemeton_in_worker <- function() {
      if (!is.null(.pkg_path) && requireNamespace("pkgload", quietly = TRUE)) {
        pkgload::load_all(.pkg_path, quiet = TRUE)
      } else if (requireNamespace("nemeton", quietly = TRUE)) {
        loadNamespace("nemeton")
      }
    }

    # ExtendedTask: fetch communes for a department
    dept_task <- shiny::ExtendedTask$new(function(dept) {
      ensure_future_plan()
      promises::future_promise({
        load_nemeton_in_worker()
        get_communes_in_department(dept)
      }, seed = TRUE)
    })

    # ExtendedTask: fetch commune geometry + info
    commune_task <- shiny::ExtendedTask$new(function(code, dept) {
      ensure_future_plan()
      promises::future_promise({
        load_nemeton_in_worker()
        geometry <- get_commune_geometry(code)
        communes <- get_communes_in_department(dept)
        list(geometry = geometry, communes = communes, code = code)
      }, seed = TRUE)
    })

    # ExtendedTask: fetch communes + commune geometry for project restore.
    # By fetching geometry here (instead of relying on input$commune →
    # commune_task chain), we eliminate the fragile 4-step async chain
    # and set commune_geometry directly in the result handler.
    restore_task <- shiny::ExtendedTask$new(function(dept_code, commune_code) {
      ensure_future_plan()
      promises::future_promise({
        load_nemeton_in_worker()
        communes <- get_communes_in_department(dept_code)
        geometry <- get_commune_geometry(commune_code)
        list(communes = communes, commune_code = commune_code, geometry = geometry)
      }, seed = TRUE)
    })


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

    # Step 1: invoke the ExtendedTask (non-blocking)
    shiny::observeEvent(input$departement, {
      dept <- input$departement

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

      # Show loading and invoke async task
      rv$is_loading <- TRUE
      dept_task$invoke(dept)
    }, ignoreInit = TRUE)

    # Step 2: handle the result when the task completes
    shiny::observeEvent(dept_task$result(), {
      # Safety net: if a restore is still in progress, the dept_task was
      # triggered by a stale department change. Don't overwrite the commune
      # dropdown that restore_task already populated.
      if (rv$is_restoring) return()

      i18n <- get_i18n(get_lang())
      communes <- tryCatch(dept_task$result(), error = function(e) {
        cli::cli_alert_danger("Error loading communes: {e$message}")
        shiny::showNotification(
          paste(i18n$t("error_loading_communes"), e$message),
          type = "error",
          duration = 8
        )
        NULL
      })

      if (is.null(communes)) {
        shiny::updateSelectizeInput(
          session, "commune",
          choices = character(0), selected = "", server = FALSE
        )
        rv$is_loading <- FALSE
        return()
      }

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
          session, "commune",
          choices = character(0), selected = "", server = FALSE
        )
      } else if (!is.null(communes) && nrow(communes) > 0) {
        choices <- format_communes_for_selectize(communes)
        shiny::updateSelectizeInput(
          session, "commune",
          choices = choices, selected = "", server = FALSE
        )
      } else {
        shiny::updateSelectizeInput(
          session, "commune",
          choices = character(0), selected = "", server = FALSE
        )
      }

      rv$is_loading <- FALSE
    })


    # ========================================
    # Handle Commune Selection
    # ========================================

    # Step 1: invoke the ExtendedTask (non-blocking)
    shiny::observeEvent(input$commune, {
      code <- input$commune

      if (is.null(code) || code == "") {
        # During restore, selectize may briefly fire "" when choices are
        # updated before the selected value is applied. Don't clear
        # geometry that restore_task just set.
        if (rv$is_restoring) return()
        rv$selected_commune <- NULL
        rv$commune_info <- NULL
        rv$commune_geometry <- NULL
        return()
      }

      # During restore, geometry + selected_commune are set directly by
      # restore_task result handler — skip redundant commune_task call.
      # Delay clearing is_restoring so the department observer
      # (triggered by the updateSelectInput roundtrip that hasn't arrived
      # yet) still sees is_restoring = TRUE and skips dept_task$invoke().
      if (rv$is_restoring) {
        later::later(function() {
          rv$is_restoring <- FALSE
        }, delay = 1)
        return()
      }

      # Also skip if geometry is already available for this exact commune
      # (browser roundtrip from updateSelectizeInput fires input$commune
      # AFTER restore_task already set everything).
      if (!is.null(rv$commune_geometry) && identical(rv$selected_commune, code)) return()

      rv$is_loading <- TRUE
      commune_task$invoke(code, input$departement)
    }, ignoreInit = TRUE)

    # Step 2: handle the result when the task completes
    shiny::observeEvent(commune_task$result(), {
      result <- tryCatch(commune_task$result(), error = function(e) {
        cli::cli_alert_danger("Error loading commune: {e$message}")
        NULL
      })

      if (!is.null(result) && !is.null(result$geometry)) {
        rv$selected_commune <- result$code
        rv$commune_geometry <- result$geometry

        communes <- result$communes
        if (!is.null(communes) && nrow(communes) > 0) {
          info <- communes[communes$code_insee == result$code, ]
          if (nrow(info) > 0) {
            rv$commune_info <- as.list(info[1, ])
          }
        }
      }

      if (rv$is_restoring) {
        rv$is_restoring <- FALSE
      }
      rv$is_loading <- FALSE
    })


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

    # Step 1: invoke restore task (non-blocking)
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

      # Fetch communes asynchronously via ExtendedTask
      restore_task$invoke(dept_code, commune_code)

      # Safety timeout: if restore_task never completes (worker crash, etc.),
      # clear flags after 30 seconds so the spinner doesn't spin forever.
      # isolate() is required because later::later runs outside reactive context.
      later::later(function() {
        if (isTRUE(shiny::isolate(rv$is_restoring))) {
          cli::cli_warn("Restore safety timeout — clearing stale flags")
          rv$is_restoring <- FALSE
        }
        if (isTRUE(shiny::isolate(app_state$restore_in_progress))) {
          app_state$restore_in_progress <- FALSE
        }
      }, delay = 30)
    }, ignoreInit = TRUE)

    # Step 2: handle restore task result
    shiny::observeEvent(restore_task$result(), {
      result <- tryCatch(restore_task$result(), error = function(e) {
        cli::cli_alert_danger("Error restoring location: {e$message}")
        rv$is_restoring <- FALSE
        # Clear restore flag so spinner is hidden (mod_map watches this)
        later::later(function() {
          app_state$restore_in_progress <- FALSE
        }, delay = 0)
        NULL
      })

      if (is.null(result)) return()

      communes <- result$communes
      commune_code <- result$commune_code

      # Set commune geometry and selection DIRECTLY — no need to go
      # through input$commune → commune_task chain. This makes
      # commune_geometry() available immediately for the combined
      # observer in mod_map (together with parcels_data set earlier).
      if (!is.null(result$geometry)) {
        rv$commune_geometry <- result$geometry
        rv$selected_commune <- commune_code

        if (!is.null(communes) && nrow(communes) > 0) {
          info <- communes[communes$code_insee == commune_code, ]
          if (nrow(info) > 0) {
            rv$commune_info <- as.list(info[1, ])
          }
        }
      } else {
        # Geometry fetch failed — clear flags so spinner doesn't spin forever
        cli::cli_warn("Restore: commune geometry is NULL for {commune_code}")
        rv$is_restoring <- FALSE
        later::later(function() {
          app_state$restore_in_progress <- FALSE
        }, delay = 0)
      }

      if (!is.null(communes) && nrow(communes) > 0) {
        choices <- format_communes_for_selectize(communes)
        cli::cli_alert_info("Updating commune dropdown with {nrow(communes)} choices")

        # Update dropdown (for display only — geometry already set above)
        shiny::updateSelectizeInput(
          session,
          "commune",
          choices = choices,
          selected = commune_code,
          server = FALSE
        )

        cli::cli_alert_success("Location restored successfully")
      }

      # NOTE: Don't clear rv$is_restoring here. The updateSelectizeInput
      # above queues a message to the browser. The selectize may briefly
      # fire input$commune="" before the selected value. If is_restoring
      # is already FALSE, the commune observer clears rv$commune_geometry.
      # is_restoring is cleared by the commune observer when the final
      # input$commune value arrives.
      rv$is_loading <- FALSE
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
