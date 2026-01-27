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

      # Search Section (collapsible)
      htmltools::tags$div(
        class = "card mb-3",
        htmltools::tags$div(
          class = "card-header bg-primary text-white py-2",
          style = "cursor: pointer;",
          `data-bs-toggle` = "collapse",
          `data-bs-target` = paste0("#", ns("search_collapse")),
          `aria-expanded` = "true",
          `aria-controls` = ns("search_collapse"),
          htmltools::div(
            class = "d-flex align-items-center justify-content-between",
            htmltools::div(
              class = "d-flex align-items-center",
              bsicons::bs_icon("search", class = "me-2"),
              i18n$t("search_commune")
            ),
            bsicons::bs_icon("chevron-down", class = "collapse-icon")
          )
        ),
        htmltools::tags$div(
          id = ns("search_collapse"),
          class = "collapse show",
          htmltools::tags$div(
            class = "card-body",
            mod_search_ui(ns("search"))
          )
        )
      ),

      htmltools::hr(class = "my-3"),

      # Project Form Section (shown after parcel selection)
      htmltools::div(
        id = ns("project_form_section"),
        mod_project_ui(ns("project"))
      ),

      htmltools::hr(class = "my-3"),

      # Compute Button Section (shown when project exists)
      htmltools::div(
        id = ns("compute_section"),
        shiny::uiOutput(ns("compute_button_ui"))
      ),

      # Progress Module (shown during computation)
      mod_progress_ui(ns("progress"))
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
        shiny::updateNavbarPage(
          session = session$userData$parent_session %||% shiny::getDefaultReactiveDomain(),
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

      parcels <- NULL

      shiny::withProgress(
        message = i18n$t("loading_parcels"),
        value = 0.5,
        {
          parcels <- tryCatch({
            get_cadastral_parcels(commune, commune_geom)
          }, error = function(e) {
            shiny::showNotification(
              sprintf("%s: %s", i18n$t("error_loading_parcels"), e$message),
              type = "error"
            )
            NULL
          })
        }
      )

      if (!is.null(parcels) && nrow(parcels) > 0) {
        shiny::showNotification(
          sprintf("%d %s", nrow(parcels), i18n$t("parcels_loaded")),
          type = "message",
          duration = 3
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
    # Compute Button
    # ========================================

    output$compute_button_ui <- shiny::renderUI({
      project <- app_state$current_project
      if (is.null(project)) return(NULL)

      # Check project status
      status <- project$metadata$status %||% "draft"

      # Show button only for draft status (not yet computed)
      if (status %in% c("draft", "error")) {
        shiny::actionButton(
          ns("start_compute"),
          label = i18n$t("compute_button"),
          class = "btn-primary w-100",
          icon = bsicons::bs_icon("cpu")
        )
      } else if (status == "completed") {
        # Show "view results" button
        htmltools::div(
          class = "d-grid gap-2",
          shiny::actionButton(
            ns("view_results"),
            label = i18n$t("view_results"),
            class = "btn-success w-100",
            icon = bsicons::bs_icon("bar-chart")
          ),
          shiny::actionButton(
            ns("recompute"),
            label = i18n$t("retry"),
            class = "btn-outline-secondary btn-sm w-100 mt-2",
            icon = bsicons::bs_icon("arrow-repeat")
          )
        )
      } else {
        NULL
      }
    })

    # ========================================
    # Progress Module (ExtendedTask for async computation)
    # ========================================

    # Computation state (reactive)
    compute_state <- shiny::reactiveVal(NULL)

    # Track active computation project
    computing_project_id <- shiny::reactiveVal(NULL)

    # Progress module server
    progress_result <- mod_progress_server(
      "progress",
      compute_state = compute_state,
      app_state = app_state
    )

    # Create ExtendedTask for async computation
    # Note: ExtendedTask runs in a separate R process, so we pass project_path
    # directly to avoid dependency on session options (nemeton.app_options)
    compute_task <- shiny::ExtendedTask$new(function(project_id, project_path) {
      # This runs in a separate R process
      start_computation(
        project_id = project_id,
        indicators = "all",
        progress_callback = NULL,  # No callback in async mode
        use_file_progress = TRUE,  # Write progress to file
        project_path = project_path
      )
    })

    # ========================================
    # Resume progress tracking on project load
    # ========================================
    # When a project is loaded, check if computation is in progress
    shiny::observeEvent(app_state$current_project, {
      project <- app_state$current_project
      if (is.null(project)) return()

      # Don't interfere if we already have an active computation
      if (!is.null(computing_project_id())) return()

      # Check if there's an ongoing computation for this project
      progress_state <- read_progress_state(project$id)

      if (!is.null(progress_state) &&
          progress_state$status %in% c("downloading", "computing")) {

        cli::cli_alert_info("Resuming progress tracking for project {project$id}")

        # Set computing project ID to trigger polling
        computing_project_id(project$id)

        # Update compute state from file
        compute_state(progress_state)

        # Show progress card
        session$sendCustomMessage("showElement", list(
          id = ns("progress-progress_card_wrapper")
        ))

        # Hide completion/error cards
        session$sendCustomMessage("hideElement", list(
          id = ns("progress-complete_card_wrapper")
        ))
        session$sendCustomMessage("hideElement", list(
          id = ns("progress-error_card_wrapper")
        ))
      }
    }, ignoreInit = TRUE)

    # Start computation handler
    shiny::observeEvent(input$start_compute, {
      project <- app_state$current_project
      shiny::req(project)

      # Get project path for async mode
      project_path <- get_project_path(project$id)

      # Initialize computation state
      state <- init_compute_state(project$id)
      compute_state(state)

      # Store project ID for polling
      computing_project_id(project$id)

      # Show progress card immediately
      session$sendCustomMessage("showElement", list(
        id = ns("progress-progress_card_wrapper")
      ))

      # Hide completion/error cards if visible
      session$sendCustomMessage("hideElement", list(
        id = ns("progress-complete_card_wrapper")
      ))
      session$sendCustomMessage("hideElement", list(
        id = ns("progress-error_card_wrapper")
      ))

      # Start the async computation with both project_id and project_path
      compute_task$invoke(project$id, project_path)
    })

    # Poll progress file while computation is running
    # Works both for new computations (ExtendedTask) and resumed tracking
    shiny::observe({
      project_id <- computing_project_id()
      shiny::req(project_id)

      # Read progress from file
      progress_state <- read_progress_state(project_id)

      if (is.null(progress_state)) {
        # No progress file - computation may have finished or never started
        shiny::invalidateLater(1000)
        return()
      }

      # Check if computation is still running (from file status)
      is_running <- progress_state$status %in% c("downloading", "computing")

      if (is_running) {
        # Update reactive state
        compute_state(progress_state)

        # Send JavaScript updates for real-time feedback
        progress_pct <- round(
          (progress_state$progress %||% 0) /
          (progress_state$progress_max %||% 1) * 100
        )

        session$sendCustomMessage("updateProgressBar", list(
          barId = ns("progress-progress_bar"),
          percentId = ns("progress-progress_percent"),
          percent = progress_pct
        ))

        # Current task text - translate
        task_text <- translate_task_message(progress_state$current_task, i18n)
        session$sendCustomMessage("updateText", list(
          id = ns("progress-current_task_text"),
          text = task_text
        ))

        # Counters
        session$sendCustomMessage("updateText", list(
          id = ns("progress-completed_count"),
          text = as.character(progress_state$indicators_completed %||% 0)
        ))
        session$sendCustomMessage("updateText", list(
          id = ns("progress-failed_count"),
          text = as.character(progress_state$indicators_failed %||% 0)
        ))
        pending <- (progress_state$indicators_total %||% 0) -
                   (progress_state$indicators_completed %||% 0) -
                   (progress_state$indicators_failed %||% 0)
        session$sendCustomMessage("updateText", list(
          id = ns("progress-pending_count"),
          text = as.character(pending)
        ))

        # Continue polling every 500ms
        shiny::invalidateLater(500)

      } else {
        # Computation finished - handle completion
        # Hide progress card
        session$sendCustomMessage("hideElement", list(
          id = ns("progress-progress_card_wrapper")
        ))

        if (progress_state$status == "completed") {
          # Show completion card
          session$sendCustomMessage("showElement", list(
            id = ns("progress-complete_card_wrapper")
          ))

          # Reload project to get updated metadata
          app_state$current_project <- load_project(project_id)
          app_state$refresh_projects <- Sys.time()

          shiny::showNotification(
            i18n$t("computation_complete"),
            type = "message"
          )
        } else if (progress_state$status == "error") {
          # Show error card
          session$sendCustomMessage("showElement", list(
            id = ns("progress-error_card_wrapper")
          ))

          error_msg <- if (length(progress_state$errors) > 0) {
            progress_state$errors[[length(progress_state$errors)]]$message
          } else {
            "Unknown error"
          }

          shiny::showNotification(
            paste(i18n$t("computation_error"), error_msg),
            type = "error",
            duration = 10
          )
        }

        # Reset computing state
        computing_project_id(NULL)
      }
    })

    # Note: ExtendedTask completion is handled by the polling observer above
    # which detects status changes from the progress_state.json file

    # Recompute handler
    shiny::observeEvent(input$recompute, {
      project <- app_state$current_project
      shiny::req(project)

      # Reset status to allow recomputation
      update_project_status(project$id, "draft")
      app_state$current_project <- load_project(project$id)
    })

    # View results handler
    shiny::observeEvent(input$view_results, {
      # Navigate to synthesis tab
      shiny::updateNavbarPage(
        session = session$userData$parent_session %||% shiny::getDefaultReactiveDomain(),
        inputId = "main_nav",
        selected = "synthesis"
      )
    })

    # Handle cancel from progress module
    shiny::observeEvent(app_state$cancel_computation, {
      # Cancel the ExtendedTask
      if (compute_task$status() == "running") {
        compute_task$cancel()

        # Hide progress card
        session$sendCustomMessage("hideElement", list(
          id = ns("progress-progress_card_wrapper")
        ))

        # Reset computing state
        computing_project_id(NULL)
      }

      shiny::showNotification(
        i18n$t("computation_cancelled") %||% i18n$t("cancel"),
        type = "warning"
      )
    }, ignoreInit = TRUE)

    # Handle retry from progress module
    shiny::observeEvent(app_state$retry_computation, {
      project <- app_state$current_project
      shiny::req(project)

      # Reset status and trigger UI refresh
      update_project_status(project$id, "draft")
      app_state$current_project <- load_project(project$id)
    }, ignoreInit = TRUE)

    # Handle view_results from progress module
    shiny::observeEvent(app_state$view_results, {
      shiny::updateNavbarPage(
        session = session$userData$parent_session %||% shiny::getDefaultReactiveDomain(),
        inputId = "main_nav",
        selected = "synthesis"
      )
    }, ignoreInit = TRUE)

    # ========================================
    # Guided Tour (cicerone)
    # ========================================

    if (requireNamespace("cicerone", quietly = TRUE)) {
      # Track if tour has been shown in this session
      tour_shown_this_session <- shiny::reactiveVal(FALSE)

      # Function to open collapsed sections
      open_collapsed_sections <- function() {
        shiny::insertUI(
          selector = "body",
          where = "beforeEnd",
          ui = htmltools::tags$script(htmltools::HTML(sprintf("
            $('#%s').collapse('show');
            $('#%s').collapse('show');
          ", ns("search_collapse"), "home-project-project_collapse"))),
          immediate = TRUE
        )
      }

      # Function to create and start tour
      do_start_tour <- function() {
        # Target elements - use element IDs
        el_search <- ns("search_collapse")
        el_map <- "home-map-map_card"
        el_name <- "home-project-name"
        el_desc <- "home-project-description"
        el_owner <- "home-project-owner"
        el_create <- "home-project-create_project"

        tryCatch({
          # Create guide and chain all steps
          cicerone::Cicerone$
            new()$
            step(
              el = el_search,
              title = i18n$t("tour_search_title"),
              description = i18n$t("tour_search_desc")
            )$
            step(
              el = el_map,
              title = i18n$t("tour_map_title"),
              description = i18n$t("tour_map_desc")
            )$
            step(
              el = el_name,
              title = i18n$t("tour_project_title"),
              description = i18n$t("tour_project_desc")
            )$
            step(
              el = el_desc,
              title = i18n$t("tour_description_title"),
              description = i18n$t("tour_description_desc")
            )$
            step(
              el = el_owner,
              title = i18n$t("tour_owner_title"),
              description = i18n$t("tour_owner_desc")
            )$
            step(
              el = el_create,
              title = i18n$t("tour_create_title"),
              description = i18n$t("tour_create_desc")
            )$
            init(session = session)$
            start()
        }, error = function(e) {
          warning("[Tour] Could not start: ", e$message)
        })
      }

      # Combined function: open sections then start tour with delay
      start_tour <- function() {
        open_collapsed_sections()
        # Add delay to allow UI to render before starting tour
        shiny::insertUI(
          selector = "body",
          where = "beforeEnd",
          ui = htmltools::tags$script(htmltools::HTML("
            setTimeout(function() {
              // Trigger Shiny to start tour after UI is ready
              Shiny.setInputValue('home-tour_ready', Date.now());
            }, 500);
          ")),
          immediate = TRUE
        )
      }

      # Start tour when UI is ready (triggered by JavaScript)
      shiny::observeEvent(input$tour_ready, {
        do_start_tour()
      }, ignoreInit = TRUE)

      # Schedule tour to start after delay (one-time)
      tour_timer <- shiny::reactiveVal(0)

      shiny::observe({
        if (!tour_shown_this_session() && tour_timer() == 0) {
          tour_timer(Sys.time())
          shiny::invalidateLater(2000)  # Wait 2 seconds
        } else if (!tour_shown_this_session() && tour_timer() > 0) {
          tour_shown_this_session(TRUE)
          start_tour()
        }
      })

      # Restart tour when requested from app_server
      shiny::observeEvent(app_state$restart_tour, {
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
