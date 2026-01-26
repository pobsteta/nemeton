#' Home Module for nemetonApp
#'
#' @description
#' Main home/selection page module that integrates:
#' - Recent projects list
#' - Commune search
#' - Map with parcel selection
#' - Project creation form
#'
#' @name mod_home
#' @keywords internal
NULL


#' Home Module UI
#'
#' @param id Character. Module namespace ID.
#'
#' @return Shiny UI elements.
#'
#' @noRd
mod_home_ui <- function(id) {
  ns <- shiny::NS(id)

  # Get translations
  opts <- get_app_options()
  lang <- opts$language %||% "fr"
  i18n <- get_i18n(lang)

  bslib::layout_sidebar(
    fillable = TRUE,

    # ========================================
    # Sidebar: Search + Project Form
    # ========================================
    sidebar = bslib::sidebar(
      id = ns("sidebar"),
      width = 350,
      open = TRUE,

      # Recent Projects Section
      htmltools::div(
        id = ns("recent_projects_section"),
        class = "mb-4",
        htmltools::h6(
          class = "text-muted mb-2 d-flex align-items-center",
          bsicons::bs_icon("clock-history", class = "me-2"),
          i18n$t("recent_projects")
        ),
        shiny::uiOutput(ns("recent_projects_list"))
      ),

      htmltools::hr(class = "my-3"),

      # Search Section
      htmltools::div(
        id = ns("search_section"),
        htmltools::h6(
          class = "text-muted mb-2 d-flex align-items-center",
          bsicons::bs_icon("search", class = "me-2"),
          i18n$t("search_commune")
        ),
        mod_search_ui(ns("search"))
      ),

      htmltools::hr(class = "my-3"),

      # Project Form Section (shown after parcel selection)
      htmltools::div(
        id = ns("project_form_section"),
        mod_project_ui(ns("project"))
      )
    ),

    # ========================================
    # Main: Map
    # ========================================
    mod_map_ui(ns("map"))
  )
}


#' Home Module Server
#'
#' @param id Character. Module namespace ID.
#' @param app_state Reactive values. Application state.
#'
#' @return List with reactive values for project and selection state.
#'
#' @noRd
mod_home_server <- function(id, app_state) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Get translations
    opts <- get_app_options()
    lang <- opts$language %||% "fr"
    i18n <- get_i18n(lang)

    # ========================================
    # Recent Projects
    # ========================================

    output$recent_projects_list <- shiny::renderUI({
      # Refresh when requested
      app_state$refresh_projects

      projects <- list_recent_projects(limit = 5)

      if (nrow(projects) == 0) {
        return(htmltools::div(
          class = "text-muted small fst-italic",
          i18n$t("no_recent_projects")
        ))
      }

      # Create project cards
      project_items <- lapply(seq_len(nrow(projects)), function(i) {
        proj <- projects[i, ]

        # Determine status badge color
        status_class <- switch(
          proj$status,
          "completed" = "bg-success",
          "computing" = "bg-warning",
          "downloading" = "bg-info",
          "error" = "bg-danger",
          "bg-secondary"
        )

        # Corrupted project styling
        card_class <- if (proj$is_corrupted) "border-danger" else "border-light"
        icon <- if (proj$is_corrupted) {
          bsicons::bs_icon("exclamation-triangle", class = "text-danger me-1")
        } else {
          bsicons::bs_icon("folder", class = "text-muted me-1")
        }

        htmltools::div(
          class = paste("card mb-2 cursor-pointer project-card", card_class),
          id = ns(paste0("project_", proj$id)),
          `data-project-id` = proj$id,
          `data-corrupted` = tolower(as.character(proj$is_corrupted)),
          onclick = if (proj$is_corrupted) {
            sprintf("Shiny.setInputValue('%s', '%s', {priority: 'event'});",
                    ns("delete_corrupted"), proj$id)
          } else {
            sprintf("Shiny.setInputValue('%s', '%s', {priority: 'event'});",
                    ns("load_project"), proj$id)
          },

          htmltools::div(
            class = "card-body py-2 px-3",
            htmltools::div(
              class = "d-flex justify-content-between align-items-start",
              htmltools::div(
                htmltools::div(
                  class = "fw-semibold small",
                  icon,
                  proj$name
                ),
                htmltools::div(
                  class = "text-muted smaller",
                  sprintf("%d %s", proj$parcels_count, i18n$t("parcels"))
                )
              ),
              htmltools::span(
                class = paste("badge", status_class, "smaller"),
                if (proj$is_corrupted) i18n$t("corrupted") else i18n$t(paste0("status_", proj$status))
              )
            )
          )
        )
      })

      htmltools::tagList(project_items)
    })

    # ========================================
    # Load Project Handler
    # ========================================

    shiny::observe({
      project_id <- input$load_project
      shiny::req(project_id)

      project <- load_project(project_id)

      if (is.null(project)) {
        shiny::showNotification(
          i18n$t("project_not_found"),
          type = "error"
        )
        return()
      }

      # Update app state with loaded project
      app_state$current_project <- project
      app_state$project_id <- project$id

      # Extract commune code from parcels if available
      if (!is.null(project$parcels) && nrow(project$parcels) > 0) {
        commune_code <- unique(project$parcels$code_insee)[1]
        # Extract department from commune code (first 2 or 3 chars)
        dept_code <- if (grepl("^97", commune_code)) {
          substr(commune_code, 1, 3)  # DOM-TOM
        } else {
          substr(commune_code, 1, 2)
        }

        # Signal to restore location and parcels
        app_state$restore_project <- list(
          commune_code = commune_code,
          department_code = dept_code,
          parcels = project$parcels,
          selected_ids = project$parcels$id,  # All saved parcels were selected
          timestamp = Sys.time()  # Force reactivity
        )
      }

      # Notify
      shiny::showNotification(
        sprintf("%s: %s", i18n$t("project_loaded"), project$metadata$name),
        type = "message"
      )

      # If project has indicators, navigate to synthesis
      if (project$metadata$indicators_computed) {
        shiny::updateTabsetPanel(
          session = session$userData$parent_session,
          inputId = "main_nav",
          selected = "synthesis"
        )
      }
    }) |> shiny::bindEvent(input$load_project)

    # ========================================
    # Delete Corrupted Project Handler
    # ========================================

    shiny::observe({
      project_id <- input$delete_corrupted
      shiny::req(project_id)

      # Show confirmation modal
      shiny::showModal(shiny::modalDialog(
        title = htmltools::div(
          class = "text-danger",
          bsicons::bs_icon("exclamation-triangle", class = "me-2"),
          i18n$t("delete_corrupted_project")
        ),
        htmltools::p(i18n$t("delete_corrupted_confirm")),
        footer = htmltools::tagList(
          shiny::modalButton(i18n$t("cancel")),
          shiny::actionButton(
            ns("confirm_delete"),
            i18n$t("delete"),
            class = "btn-danger",
            `data-project-id` = project_id
          )
        )
      ))
    }) |> shiny::bindEvent(input$delete_corrupted)

    shiny::observe({
      # Get project ID from button attribute
      project_id <- input$delete_corrupted

      if (delete_project(project_id)) {
        shiny::removeModal()
        shiny::showNotification(
          i18n$t("project_deleted"),
          type = "message"
        )

        # Refresh project list
        app_state$refresh_projects <- Sys.time()
      }
    }) |> shiny::bindEvent(input$confirm_delete)

    # ========================================
    # Search Module
    # ========================================

    search_result <- mod_search_server("search", app_state)

    # ========================================
    # Cadastre Parcels
    # ========================================

    parcels <- shiny::reactive({
      commune <- search_result$selected_commune()
      shiny::req(commune)

      # Get commune geometry for fallback
      commune_geom <- search_result$commune_geometry()

      # Show loading
      shiny::showNotification(
        i18n$t("loading_parcels"),
        id = "loading_parcels",
        duration = NULL,
        type = "message"
      )

      parcels <- tryCatch({
        get_cadastral_parcels(commune, commune_geom)
      }, error = function(e) {
        shiny::showNotification(
          sprintf("%s: %s", i18n$t("error_loading_parcels"), e$message),
          type = "error"
        )
        NULL
      })

      shiny::removeNotification("loading_parcels")

      if (!is.null(parcels) && nrow(parcels) > 0) {
        shiny::showNotification(
          sprintf("%d %s", nrow(parcels), i18n$t("parcels_loaded")),
          type = "message"
        )
      }

      parcels
    })

    # ========================================
    # Map Module
    # ========================================

    map_result <- mod_map_server(
      "map",
      app_state = app_state,
      commune_geometry = search_result$commune_geometry,
      parcels = parcels
    )

    # ========================================
    # Project Module
    # ========================================

    project_result <- mod_project_server(
      "project",
      app_state = app_state,
      selected_parcels = map_result$selected_parcels
    )

    # ========================================
    # Guided Tour (cicerone)
    # ========================================

    if (requireNamespace("cicerone", quietly = TRUE)) {
      message("[TOUR] Cicerone package loaded")

      # Track if tour has been shown in this session
      tour_shown_this_session <- shiny::reactiveVal(FALSE)

      # Timer for delayed start (NULL = not started, timestamp = when to start)
      tour_start_time <- shiny::reactiveVal(NULL)

      # Function to create and start a fresh guide (must be called in reactive context)
      start_tour <- function() {
        message("[TOUR] Creating and starting guide...")

        # Target elements - use element IDs (cicerone adds # prefix automatically)
        # Using wrapper divs for sections that contain hidden elements
        el1 <- "home-search_section"   # wrapper div around search (visible)
        el2 <- "home-map-map_card"     # map card (visible)
        el3 <- "home-project-name"     # textInput (visible)

        message("[TOUR] Target elements: ", el1, ", ", el2, ", ", el3)

        tryCatch({
          # Create guide and chain all steps
          cicerone::Cicerone$
            new()$
            step(
              el = el1,
              title = i18n$t("tour_search_title"),
              description = i18n$t("tour_search_desc")
            )$
            step(
              el = el2,
              title = i18n$t("tour_map_title"),
              description = i18n$t("tour_map_desc")
            )$
            step(
              el = el3,
              title = i18n$t("tour_project_title"),
              description = i18n$t("tour_project_desc")
            )$
            init(session = session)$
            start()

          message("[TOUR] Tour started successfully!")
        }, error = function(e) {
          message("[TOUR] Error: ", e$message)
        })
      }

      # Schedule tour to start after delay
      shiny::observe({
        if (!tour_shown_this_session()) {
          message("[TOUR] Scheduling tour start in 2 seconds...")
          tour_start_time(Sys.time())
          tour_shown_this_session(TRUE)
        }
      })

      # Poll for tour start time
      shiny::observe({
        start_time <- tour_start_time()
        shiny::req(start_time)

        # Check if 2 seconds have passed
        elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
        if (elapsed >= 2) {
          message("[TOUR] 2 seconds elapsed, starting tour...")
          tour_start_time(NULL)  # Reset to prevent re-triggering
          start_tour()
        } else {
          # Keep polling every 500ms
          shiny::invalidateLater(500, session)
        }
      })

      # Restart tour when requested from app_server
      shiny::observeEvent(app_state$restart_tour, {
        message("[TOUR] Restart requested...")
        start_tour()
      }, ignoreInit = TRUE)
    } else {
      message("[TOUR] Cicerone package not available!")
    }

    # ========================================
    # Return Values
    # ========================================

    list(
      selected_commune = search_result$selected_commune,
      selected_parcels = map_result$selected_parcels,
      selection_count = map_result$selection_count,
      current_project = project_result$current_project
    )
  })
}
