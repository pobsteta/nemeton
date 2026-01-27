#' Project Module for nemetonApp
#'
#' @description
#' Shiny module for project metadata form.
#' Handles project name, description, owner, and creation date.
#'
#' @name mod_project
#' @keywords internal
NULL


#' Project Module UI
#'
#' @param id Character. Module namespace ID.
#'
#' @return Shiny UI elements.
#'
#' @noRd
mod_project_ui <- function(id) {
  ns <- shiny::NS(id)

  # Get language for translations
  opts <- get_app_options()
  lang <- opts$language %||% "fr"
  i18n <- get_i18n(lang)

  bslib::accordion(
    id = ns("project_accordion"),
    open = FALSE,  # Collapsed by default
    bslib::accordion_panel(
      title = htmltools::div(
        class = "d-flex align-items-center",
        bsicons::bs_icon("folder-plus", class = "me-2 text-success"),
        i18n$t("project_info")
      ),
      value = "project_panel",
      icon = NULL,

      # Project name (required)
      htmltools::div(
        class = "mb-3",
        shiny::textInput(
          ns("name"),
          label = htmltools::tagList(
            i18n$t("project_name"),
            htmltools::span("*", class = "text-danger")
          ),
          placeholder = i18n$t("project_name_placeholder"),
          width = "100%"
        ),
        htmltools::div(
          id = ns("name_feedback"),
          class = "invalid-feedback d-none",
          i18n$t("field_required")
        ),
        htmltools::tags$small(
          class = "text-muted",
          sprintf("%s: 100 %s", i18n$t("max_chars"), i18n$t("characters"))
        )
      ),

      # Description (optional)
      htmltools::div(
        class = "mb-3",
        shiny::textAreaInput(
          ns("description"),
          label = i18n$t("project_description"),
          placeholder = i18n$t("project_description_placeholder"),
          rows = 3,
          width = "100%"
        ),
        htmltools::tags$small(
          class = "text-muted",
          sprintf("%s: 500 %s", i18n$t("max_chars"), i18n$t("characters"))
        )
      ),

      # Owner (optional)
      htmltools::div(
        class = "mb-3",
        shiny::textInput(
          ns("owner"),
          label = i18n$t("project_owner"),
          placeholder = i18n$t("project_owner_placeholder"),
          width = "100%"
        ),
        htmltools::tags$small(
          class = "text-muted",
          sprintf("%s: 100 %s", i18n$t("max_chars"), i18n$t("characters"))
        )
      ),

      # Creation date (auto)
      htmltools::div(
        class = "mb-3",
        htmltools::tags$label(
          class = "form-label",
          i18n$t("project_date")
        ),
        shiny::uiOutput(ns("date_display")),
        htmltools::tags$small(
          class = "text-muted",
          i18n$t("auto_generated")
        )
      ),

      # Character counters (hidden, for JS validation)
      htmltools::tags$script(htmltools::HTML(sprintf("
        $(document).ready(function() {
          // Name character limit
          $('#%s').on('input', function() {
            if ($(this).val().length > 100) {
              $(this).val($(this).val().substring(0, 100));
            }
          });

          // Description character limit
          $('#%s').on('input', function() {
            if ($(this).val().length > 500) {
              $(this).val($(this).val().substring(0, 500));
            }
          });

          // Owner character limit
          $('#%s').on('input', function() {
            if ($(this).val().length > 100) {
              $(this).val($(this).val().substring(0, 100));
            }
          });
        });
      ", ns("name"), ns("description"), ns("owner"))),

      # Footer with validation and action button
      htmltools::hr(class = "my-2"),
      htmltools::div(
        class = "d-flex justify-content-between align-items-center",
        shiny::uiOutput(ns("validation_message")),
        shiny::uiOutput(ns("action_button"))
      )
    )
  )
}


#' Project Module Server
#'
#' @param id Character. Module namespace ID.
#' @param app_state Reactive values. Application state.
#' @param selected_parcels Reactive. Selected parcels sf object.
#'
#' @return List with reactive values:
#'   - project_created: Reactive that fires when project is created
#'   - current_project: Reactive with current project info
#'
#' @noRd
mod_project_server <- function(id, app_state, selected_parcels) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Get translations
    opts <- get_app_options()
    lang <- opts$language %||% "fr"
    i18n <- get_i18n(lang)

    # Reactive values
    rv <- shiny::reactiveValues(
      current_project = NULL,
      editing_project_id = NULL,  # NULL = create mode, ID = edit mode
      validation_errors = character(0),
      project_date = format(Sys.time(), "%d/%m/%Y %H:%M")
    )

    # ========================================
    # Validation
    # ========================================

    validate_form <- function() {
      errors <- character(0)

      # Name is required
      name <- trimws(input$name %||% "")
      if (nchar(name) == 0) {
        errors <- c(errors, i18n$t("name_required"))
      } else if (nchar(name) > 100) {
        errors <- c(errors, i18n$t("name_too_long"))
      }

      # Description length
      description <- input$description %||% ""
      if (nchar(description) > 500) {
        errors <- c(errors, i18n$t("description_too_long"))
      }

      # Owner length
      owner <- input$owner %||% ""
      if (nchar(owner) > 100) {
        errors <- c(errors, i18n$t("owner_too_long"))
      }

      rv$validation_errors <- errors
      length(errors) == 0
    }

    # Date display (reactive)
    output$date_display <- shiny::renderUI({
      htmltools::div(
        class = "form-control bg-light",
        rv$project_date
      )
    })

    # Dynamic action button (create vs update + delete)
    output$action_button <- shiny::renderUI({
      if (is.null(rv$editing_project_id)) {
        # Create mode
        shiny::actionButton(
          ns("create"),
          label = i18n$t("create_project"),
          class = "btn-success",
          icon = bsicons::bs_icon("plus-circle")
        )
      } else {
        # Edit mode - show update and delete buttons
        htmltools::div(
          class = "d-flex gap-2",
          shiny::actionButton(
            ns("create"),
            label = i18n$t("update_project"),
            class = "btn-primary",
            icon = bsicons::bs_icon("pencil-square")
          ),
          shiny::actionButton(
            ns("delete_project"),
            label = i18n$t("delete"),
            class = "btn-outline-danger",
            icon = bsicons::bs_icon("trash")
          )
        )
      }
    })

    # ========================================
    # Restore Project Form When Loading
    # ========================================

    shiny::observeEvent(app_state$current_project, {
      project <- app_state$current_project
      if (is.null(project) || is.null(project$metadata)) return()

      # Fill in form fields with project data
      shiny::updateTextInput(
        session,
        "name",
        value = project$metadata$name %||% ""
      )
      shiny::updateTextAreaInput(
        session,
        "description",
        value = project$metadata$description %||% ""
      )
      shiny::updateTextInput(
        session,
        "owner",
        value = project$metadata$owner %||% ""
      )

      # Store date for display update
      if (!is.null(project$metadata$created_at)) {
        rv$project_date <- format(as.POSIXct(project$metadata$created_at), "%d/%m/%Y %H:%M")
      }

      # Set editing mode with project ID
      rv$editing_project_id <- project$id
      rv$current_project <- project

      # Open the accordion panel to show project info
      bslib::accordion_panel_open(
        id = "project_accordion",
        values = "project_panel",
        session = session
      )
    }, ignoreInit = TRUE)

    # Open accordion when parcels are selected (new project mode)
    shiny::observeEvent(selected_parcels(), {
      parcels <- selected_parcels()
      if (!is.null(parcels) && nrow(parcels) > 0 && is.null(rv$editing_project_id)) {
        # New parcels selected and not in edit mode - open the form
        bslib::accordion_panel_open(
          id = "project_accordion",
          values = "project_panel",
          session = session
        )
      }
    }, ignoreInit = TRUE)


    # ========================================
    # Create Project
    # ========================================

    # Validation message output
    output$validation_message <- shiny::renderUI({
      errors <- rv$validation_errors
      if (length(errors) == 0) return(NULL)
      htmltools::div(
        class = "text-danger small",
        htmltools::HTML(paste(errors, collapse = "<br>"))
      )
    })

    shiny::observe({
      if (!validate_form()) {
        # Validation errors are displayed via renderUI above
        return()
      }

      # Get parcels
      parcels <- selected_parcels()

      # Check if parcels are selected
      if (is.null(parcels) || nrow(parcels) == 0) {
        shiny::showNotification(
          i18n$t("no_parcels_selected"),
          type = "warning"
        )
        return()
      }

      # Validate parcels are sf objects
      if (!inherits(parcels, "sf")) {
        cli::cli_alert_danger("Parcels are not sf objects! Class: {paste(class(parcels), collapse=', ')}")
        shiny::showNotification(
          "Erreur: les parcelles ne sont pas au format spatial",
          type = "error"
        )
        return()
      }

      cli::cli_alert_info("Saving {nrow(parcels)} parcels (class: {paste(class(parcels), collapse=', ')})")

      tryCatch({
        if (is.null(rv$editing_project_id)) {
          # CREATE mode
          project <- create_project(
            name = trimws(input$name),
            description = input$description %||% "",
            owner = input$owner %||% "",
            parcels = parcels
          )

          rv$current_project <- project
          rv$editing_project_id <- project$id

          # Update app state
          app_state$current_project <- project
          app_state$project_id <- project$id
          app_state$refresh_projects <- Sys.time()  # Refresh recent projects list

          # Show success notification
          shiny::showNotification(
            sprintf("%s: %s", i18n$t("project_created"), project$metadata$name),
            type = "message"
          )
        } else {
          # UPDATE mode
          cli::cli_alert_info("Updating project {rv$editing_project_id}...")

          # Update metadata
          update_project_metadata(
            project_id = rv$editing_project_id,
            updates = list(
              name = trimws(input$name),
              description = input$description %||% "",
              owner = input$owner %||% ""
            )
          )
          cli::cli_alert_success("Project metadata updated")

          # Update parcels if selection changed
          save_parcels(rv$editing_project_id, parcels)
          cli::cli_alert_success("Project parcels updated ({nrow(parcels)} parcels)")

          # Reload the updated project
          project <- load_project(rv$editing_project_id)
          rv$current_project <- project
          app_state$current_project <- project
          app_state$refresh_projects <- Sys.time()  # Refresh recent projects list

          # Show success notification
          shiny::showNotification(
            sprintf("%s: %s (%d %s)",
                    i18n$t("project_updated"),
                    project$metadata$name,
                    nrow(parcels),
                    i18n$t("parcels")),
            type = "message"
          )
        }

      }, error = function(e) {
        shiny::showNotification(
          sprintf("%s: %s", i18n$t("error"), e$message),
          type = "error"
        )
      })
    }) |> shiny::bindEvent(input$create)

    # ========================================
    # Delete Project
    # ========================================

    shiny::observeEvent(input$delete_project, {
      shiny::req(rv$editing_project_id)

      project <- rv$current_project
      project_name <- if (!is.null(project$metadata$name)) project$metadata$name else rv$editing_project_id

      # Show confirmation modal
      shiny::showModal(shiny::modalDialog(
        title = htmltools::div(
          class = "text-danger",
          bsicons::bs_icon("exclamation-triangle-fill", class = "me-2"),
          i18n$t("delete_project")
        ),
        htmltools::p(
          sprintf("%s '%s' ?", i18n$t("confirm_delete_project"), project_name)
        ),
        htmltools::p(
          class = "text-muted small",
          i18n$t("delete_project_warning")
        ),
        footer = htmltools::tagList(
          shiny::modalButton(i18n$t("cancel")),
          shiny::actionButton(
            ns("confirm_delete_project"),
            label = i18n$t("delete"),
            class = "btn-danger"
          )
        ),
        easyClose = TRUE
      ))
    })

    # Confirm delete
    shiny::observeEvent(input$confirm_delete_project, {
      shiny::req(rv$editing_project_id)

      project_id <- rv$editing_project_id

      tryCatch({
        if (delete_project(project_id)) {
          shiny::removeModal()

          # Reset form
          rv$editing_project_id <- NULL
          rv$current_project <- NULL
          rv$project_date <- format(Sys.Date(), "%d/%m/%Y")
          shiny::updateTextInput(session, "name", value = "")
          shiny::updateTextAreaInput(session, "description", value = "")
          shiny::updateTextInput(session, "owner", value = "")

          # Clear app state
          app_state$current_project <- NULL
          app_state$project_id <- NULL
          app_state$refresh_projects <- Sys.time()
          app_state$clear_map_selection <- Sys.time()  # Trigger map selection clear

          shiny::showNotification(
            i18n$t("project_deleted"),
            type = "message"
          )
        }
      }, error = function(e) {
        shiny::showNotification(
          sprintf("%s: %s", i18n$t("error"), e$message),
          type = "error"
        )
      })
    })

    # ========================================
    # Return Values
    # ========================================

    list(
      project_created = shiny::reactive(rv$current_project),
      current_project = shiny::reactive(rv$current_project),
      is_valid = shiny::reactive(validate_form())
    )
  })
}


#' Project Info Display UI
#'
#' @description
#' Read-only display of current project info.
#'
#' @param id Character. Module namespace ID.
#'
#' @noRd
mod_project_info_ui <- function(id) {
  ns <- shiny::NS(id)
  # Entire card is rendered dynamically based on project state

  shiny::uiOutput(ns("project_info_card"))
}


#' Project Info Display Server
#'
#' @param id Character. Module namespace ID.
#' @param project Reactive. Current project object.
#'
#' @noRd
mod_project_info_server <- function(id, project) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    opts <- get_app_options()
    lang <- opts$language %||% "fr"
    i18n <- get_i18n(lang)

    # Render entire card dynamically based on project state
    output$project_info_card <- shiny::renderUI({
      proj <- project()

      # Hide card if no project
      if (is.null(proj)) {
        return(NULL)
      }

      # Build description section if present
      description_ui <- NULL
      if (nchar(proj$metadata$description %||% "") > 0) {
        description_ui <- htmltools::div(
          class = "mt-2 small text-muted",
          htmltools::tags$em(proj$metadata$description)
        )
      }

      # Render the card
      bslib::card(
        class = "border-success",
        bslib::card_header(
          class = "bg-success text-white py-2",
          htmltools::div(
            class = "d-flex align-items-center justify-content-between",
            htmltools::div(
              bsicons::bs_icon("folder-check", class = "me-2"),
              htmltools::span(class = "fw-bold", proj$metadata$name)
            ),
            htmltools::tags$small(
              class = "badge bg-light text-dark",
              i18n$t(paste0("status_", proj$metadata$status))
            )
          )
        ),
        bslib::card_body(
          class = "py-2",
          htmltools::div(
            class = "row small",
            htmltools::div(
              class = "col-md-6",
              htmltools::tags$strong(i18n$t("parcels")), ": ",
              htmltools::span(as.character(proj$metadata$parcels_count))
            ),
            htmltools::div(
              class = "col-md-6",
              htmltools::tags$strong(i18n$t("created")), ": ",
              htmltools::span(format(
                as.POSIXct(proj$metadata$created_at),
                "%d/%m/%Y"
              ))
            )
          ),
          description_ui
        )
      )
    })
  })
}
