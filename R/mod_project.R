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

  bslib::card(
    bslib::card_header(
      class = "bg-success text-white",
      htmltools::div(
        class = "d-flex align-items-center",
        bsicons::bs_icon("folder-plus", class = "me-2"),
        i18n$t("project_info")
      )
    ),
    bslib::card_body(
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
        htmltools::div(
          class = "form-control bg-light",
          id = ns("date_display"),
          format(Sys.time(), "%d/%m/%Y %H:%M")
        ),
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
      ", ns("name"), ns("description"), ns("owner"))))
    ),
    bslib::card_footer(
      class = "d-flex justify-content-between align-items-center",
      htmltools::div(
        id = ns("validation_message"),
        class = "text-danger small"
      ),
      shiny::actionButton(
        ns("create"),
        label = i18n$t("create_project"),
        class = "btn-success",
        icon = bsicons::bs_icon("plus-circle")
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
      validation_errors = character(0)
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

    # Update validation UI
    shiny::observe({
      name <- input$name

      if (is.null(name) || nchar(trimws(name)) == 0) {
        shinyjs::runjs(sprintf(
          "$('#%s').addClass('is-invalid'); $('#%s').removeClass('d-none');",
          ns("name"), ns("name_feedback")
        ))
      } else {
        shinyjs::runjs(sprintf(
          "$('#%s').removeClass('is-invalid'); $('#%s').addClass('d-none');",
          ns("name"), ns("name_feedback")
        ))
      }
    }) |> shiny::bindEvent(input$name, ignoreInit = TRUE)

    # ========================================
    # Create Project
    # ========================================

    shiny::observe({
      if (!validate_form()) {
        # Show validation errors
        shiny::updateTextInput(
          session,
          "validation_message",
          value = paste(rv$validation_errors, collapse = "; ")
        )
        shinyjs::html(
          ns("validation_message"),
          paste(rv$validation_errors, collapse = "<br>")
        )
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

      # Create project
      tryCatch({
        project <- create_project(
          name = trimws(input$name),
          description = input$description %||% "",
          owner = input$owner %||% "",
          parcels = parcels
        )

        rv$current_project <- project

        # Update app state
        app_state$current_project <- project
        app_state$project_id <- project$id

        # Show success notification
        shiny::showNotification(
          sprintf("%s: %s", i18n$t("project_created"), project$metadata$name),
          type = "message"
        )

        # Clear form
        shiny::updateTextInput(session, "name", value = "")
        shiny::updateTextAreaInput(session, "description", value = "")
        shiny::updateTextInput(session, "owner", value = "")

      }, error = function(e) {
        shiny::showNotification(
          sprintf("%s: %s", i18n$t("error"), e$message),
          type = "error"
        )
      })
    }) |> shiny::bindEvent(input$create)

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

  opts <- get_app_options()
  lang <- opts$language %||% "fr"
  i18n <- get_i18n(lang)

  htmltools::div(
    id = ns("project_info_container"),
    class = "d-none",
    bslib::card(
      class = "border-success",
      bslib::card_header(
        class = "bg-success text-white py-2",
        htmltools::div(
          class = "d-flex align-items-center justify-content-between",
          htmltools::div(
            bsicons::bs_icon("folder-check", class = "me-2"),
            htmltools::span(id = ns("project_name"), class = "fw-bold")
          ),
          htmltools::tags$small(
            id = ns("project_status"),
            class = "badge bg-light text-dark"
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
            htmltools::span(id = ns("parcels_count"))
          ),
          htmltools::div(
            class = "col-md-6",
            htmltools::tags$strong(i18n$t("created")), ": ",
            htmltools::span(id = ns("created_at"))
          )
        ),
        shiny::uiOutput(ns("description_display"))
      )
    )
  )
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

    # Update display when project changes
    shiny::observe({
      proj <- project()

      if (is.null(proj)) {
        shinyjs::runjs(sprintf("$('#%s').addClass('d-none');", ns("project_info_container")))
        return()
      }

      shinyjs::runjs(sprintf("$('#%s').removeClass('d-none');", ns("project_info_container")))

      # Update fields
      shinyjs::html(ns("project_name"), proj$metadata$name)
      shinyjs::html(ns("project_status"), i18n$t(paste0("status_", proj$metadata$status)))
      shinyjs::html(ns("parcels_count"), as.character(proj$metadata$parcels_count))
      shinyjs::html(ns("created_at"), format(
        as.POSIXct(proj$metadata$created_at),
        "%d/%m/%Y"
      ))
    })

    # Description (only if not empty)
    output$description_display <- shiny::renderUI({
      proj <- project()
      if (is.null(proj) || nchar(proj$metadata$description %||% "") == 0) {
        return(NULL)
      }

      htmltools::div(
        class = "mt-2 small text-muted",
        htmltools::tags$em(proj$metadata$description)
      )
    })
  })
}
