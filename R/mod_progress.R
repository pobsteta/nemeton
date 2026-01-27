#' Progress Module for nemetonApp
#'
#' @description
#' Shiny module for displaying computation progress.
#' Shows download and computation status with detailed progress.
#'
#' @name mod_progress
#' @keywords internal
NULL


#' Progress Module UI
#'
#' @param id Module namespace ID.
#'
#' @return Shiny UI elements.
#'
#' @noRd
mod_progress_ui <- function(id) {
  ns <- shiny::NS(id)
  opts <- get_app_options()
  i18n <- get_i18n(opts$language)

  htmltools::tagList(
    # Progress card (hidden by default)
    shiny::conditionalPanel(
      condition = sprintf("output['%s'] == true", ns("show_progress")),
      ns = ns,
      bslib::card(
        id = ns("progress_card"),
        class = "border-primary",
        bslib::card_header(
          class = "bg-primary text-white d-flex align-items-center",
          bsicons::bs_icon("cpu", class = "me-2"),
          htmltools::span(
            id = ns("progress_title"),
            i18n$t("computing")
          )
        ),
        bslib::card_body(
          # Phase indicator
          htmltools::div(
            class = "mb-3",
            htmltools::tags$small(
              class = "text-muted",
              shiny::textOutput(ns("phase_text"), inline = TRUE)
            )
          ),

          # Main progress bar
          htmltools::div(
            class = "mb-3",
            shiny::tags$label(
              class = "form-label d-flex justify-content-between",
              htmltools::span(i18n$t("progress_overall")),
              htmltools::span(
                id = ns("progress_percent"),
                class = "text-primary fw-bold",
                "0%"
              )
            ),
            htmltools::div(
              class = "progress",
              style = "height: 24px;",
              htmltools::div(
                id = ns("progress_bar"),
                class = "progress-bar progress-bar-striped progress-bar-animated",
                role = "progressbar",
                style = "width: 0%;",
                `aria-valuenow` = "0",
                `aria-valuemin` = "0",
                `aria-valuemax` = "100"
              )
            )
          ),

          # Current task
          htmltools::div(
            class = "mb-3",
            htmltools::tags$small(
              class = "text-muted",
              bsicons::bs_icon("arrow-right", class = "me-1"),
              shiny::textOutput(ns("current_task"), inline = TRUE)
            )
          ),

          # Indicators summary
          htmltools::div(
            class = "d-flex justify-content-between mb-2",
            htmltools::div(
              class = "text-success",
              bsicons::bs_icon("check-circle", class = "me-1"),
              htmltools::span(id = ns("completed_count"), "0"),
              " ",
              i18n$t("completed")
            ),
            htmltools::div(
              class = "text-danger",
              bsicons::bs_icon("x-circle", class = "me-1"),
              htmltools::span(id = ns("failed_count"), "0"),
              " ",
              i18n$t("failed")
            ),
            htmltools::div(
              class = "text-muted",
              bsicons::bs_icon("clock", class = "me-1"),
              htmltools::span(id = ns("pending_count"), "0"),
              " ",
              i18n$t("pending")
            )
          ),

          # Errors list (if any)
          shiny::uiOutput(ns("errors_list"))
        ),
        bslib::card_footer(
          class = "d-flex justify-content-between align-items-center",
          htmltools::div(
            id = ns("elapsed_time"),
            class = "text-muted small"
          ),
          shiny::actionButton(
            ns("cancel"),
            label = i18n$t("cancel"),
            icon = shiny::icon("times"),
            class = "btn-outline-danger btn-sm"
          )
        )
      )
    ),

    # Completion card (shown when done)
    shiny::conditionalPanel(
      condition = sprintf("output['%s'] == true", ns("show_complete")),
      ns = ns,
      bslib::card(
        id = ns("complete_card"),
        class = "border-success",
        bslib::card_header(
          class = "bg-success text-white d-flex align-items-center",
          bsicons::bs_icon("check-circle", class = "me-2"),
          i18n$t("computation_complete")
        ),
        bslib::card_body(
          htmltools::div(
            class = "text-center py-3",
            htmltools::p(
              class = "lead mb-3",
              shiny::textOutput(ns("completion_message"), inline = TRUE)
            ),
            shiny::actionButton(
              ns("view_results"),
              label = i18n$t("view_results"),
              icon = shiny::icon("chart-bar"),
              class = "btn-success"
            )
          )
        )
      )
    ),

    # Error card (shown on fatal error)
    shiny::conditionalPanel(
      condition = sprintf("output['%s'] == true", ns("show_error")),
      ns = ns,
      bslib::card(
        id = ns("error_card"),
        class = "border-danger",
        bslib::card_header(
          class = "bg-danger text-white d-flex align-items-center",
          bsicons::bs_icon("exclamation-triangle", class = "me-2"),
          i18n$t("computation_error")
        ),
        bslib::card_body(
          shiny::uiOutput(ns("error_message")),
          htmltools::div(
            class = "mt-3",
            shiny::actionButton(
              ns("retry"),
              label = i18n$t("retry"),
              icon = shiny::icon("redo"),
              class = "btn-outline-danger"
            )
          )
        )
      )
    )
  )
}


#' Progress Module Server
#'
#' @param id Character. Module namespace ID.
#' @param compute_state Reactive. Computation state object.
#' @param app_state Reactive values. Application state.
#'
#' @return List with reactive values for module state.
#'
#' @noRd
mod_progress_server <- function(id, compute_state, app_state) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Get translations
    opts <- get_app_options()
    lang <- opts$language %||% "fr"
    i18n <- get_i18n(lang)

    # Local state
    rv <- shiny::reactiveValues(
      show_progress = FALSE,
      show_complete = FALSE,
      show_error = FALSE,
      start_time = NULL
    )

    # ========================================
    # Visibility outputs
    # ========================================

    output$show_progress <- shiny::reactive({
      rv$show_progress
    })
    shiny::outputOptions(output, "show_progress", suspendWhenHidden = FALSE)

    output$show_complete <- shiny::reactive({
      rv$show_complete
    })
    shiny::outputOptions(output, "show_complete", suspendWhenHidden = FALSE)

    output$show_error <- shiny::reactive({
      rv$show_error
    })
    shiny::outputOptions(output, "show_error", suspendWhenHidden = FALSE)

    # ========================================
    # Progress updates
    # ========================================

    shiny::observe({
      state <- compute_state()
      shiny::req(state)

      # Update visibility based on status
      rv$show_progress <- state$status %in% c(
        COMPUTE_STATUS$DOWNLOADING,
        COMPUTE_STATUS$COMPUTING
      )
      rv$show_complete <- state$status == COMPUTE_STATUS$COMPLETED
      rv$show_error <- state$status == COMPUTE_STATUS$ERROR

      if (state$status == COMPUTE_STATUS$DOWNLOADING ||
          state$status == COMPUTE_STATUS$COMPUTING) {
        # Track start time
        if (is.null(rv$start_time)) {
          rv$start_time <- Sys.time()
        }

        # Update progress bar via JavaScript
        progress_pct <- round(state$progress / state$progress_max * 100)

        session$sendCustomMessage("updateProgressBar", list(
          barId = ns("progress_bar"),
          percentId = ns("progress_percent"),
          percent = progress_pct
        ))

        # Update counters
        session$sendCustomMessage("updateText", list(
          id = ns("completed_count"),
          text = as.character(state$indicators_completed)
        ))
        session$sendCustomMessage("updateText", list(
          id = ns("failed_count"),
          text = as.character(state$indicators_failed)
        ))

        pending <- state$indicators_total - state$indicators_completed - state$indicators_failed
        session$sendCustomMessage("updateText", list(
          id = ns("pending_count"),
          text = as.character(pending)
        ))
      }
    })

    # Phase text
    output$phase_text <- shiny::renderText({
      state <- compute_state()
      shiny::req(state)

      switch(
        state$phase,
        "init" = i18n$t("phase_init"),
        "downloading" = i18n$t("phase_downloading"),
        "computing" = i18n$t("phase_computing"),
        "complete" = i18n$t("phase_complete"),
        ""
      )
    })

    # Current task text
    output$current_task <- shiny::renderText({
      state <- compute_state()
      shiny::req(state)

      if (is.null(state$current_task)) {
        return("")
      }

      # Translate task or show indicator name
      if (state$current_task %in% c("download_start", "compute_start", "complete", "error")) {
        i18n$t(paste0("task_", state$current_task))
      } else {
        paste(i18n$t("computing_indicator"), state$current_task)
      }
    })

    # Errors list
    output$errors_list <- shiny::renderUI({
      state <- compute_state()
      shiny::req(state)

      if (length(state$errors) == 0) {
        return(NULL)
      }

      htmltools::div(
        class = "mt-3",
        htmltools::tags$small(class = "text-danger fw-bold", i18n$t("errors_title")),
        htmltools::tags$ul(
          class = "list-unstyled small text-danger mt-1",
          lapply(state$errors, function(err) {
            htmltools::tags$li(
              bsicons::bs_icon("exclamation-circle", class = "me-1"),
              if (!is.null(err$indicator)) paste0(err$indicator, ": "),
              err$message
            )
          })
        )
      )
    })

    # Completion message
    output$completion_message <- shiny::renderText({
      state <- compute_state()
      shiny::req(state)

      sprintf(
        i18n$t("computation_summary"),
        state$indicators_completed,
        state$indicators_total
      )
    })

    # Error message
    output$error_message <- shiny::renderUI({
      state <- compute_state()
      shiny::req(state)

      if (length(state$errors) == 0) {
        return(htmltools::p(i18n$t("unknown_error")))
      }

      # Get fatal error
      fatal_error <- state$errors[[length(state$errors)]]

      htmltools::div(
        htmltools::p(class = "text-danger", fatal_error$message),
        if (length(state$errors) > 1) {
          htmltools::div(
            htmltools::tags$small(
              class = "text-muted",
              sprintf(i18n$t("and_n_more_errors"), length(state$errors) - 1)
            )
          )
        }
      )
    })

    # Elapsed time updater (only active during computation)
    shiny::observe({
      # Only run when progress is visible
      if (rv$show_progress && !is.null(rv$start_time)) {
        elapsed <- as.numeric(difftime(Sys.time(), rv$start_time, units = "secs"))
        mins <- floor(elapsed / 60)
        secs <- floor(elapsed %% 60)

        session$sendCustomMessage("updateText", list(
          id = ns("elapsed_time"),
          text = sprintf("%s: %02d:%02d", i18n$t("elapsed_time"), mins, secs)
        ))

        # Only continue polling while showing progress
        shiny::invalidateLater(1000, session)
      }
    })

    # ========================================
    # Button handlers
    # ========================================

    # Cancel button
    shiny::observeEvent(input$cancel, {
      # Signal cancellation to app_state
      app_state$cancel_computation <- Sys.time()
    })

    # Retry button
    shiny::observeEvent(input$retry, {
      rv$show_error <- FALSE
      rv$start_time <- NULL
      app_state$retry_computation <- Sys.time()
    })

    # View results button
    shiny::observeEvent(input$view_results, {
      app_state$view_results <- Sys.time()
    })

    # ========================================
    # Return
    # ========================================

    list(
      show_progress = shiny::reactive(rv$show_progress),
      show_complete = shiny::reactive(rv$show_complete),
      show_error = shiny::reactive(rv$show_error)
    )
  })
}
