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
    # Progress card (hidden by default, shown via JavaScript)
    htmltools::div(
      id = ns("progress_card_wrapper"),
      style = "display: none;",
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
              htmltools::span(id = ns("phase_text"))
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

          # Current task (updated via JavaScript only)
          htmltools::div(
            class = "mb-3",
            htmltools::tags$small(
              class = "text-muted",
              bsicons::bs_icon("arrow-right", class = "me-1"),
              htmltools::span(id = ns("current_task_text"))
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

          # Errors list (updated via JavaScript only)
          htmltools::div(id = ns("errors_list"))
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

    # Completion card (shown when done, via JavaScript)
    # Auto-hides after 5 seconds - main "View Results" button is in the interface
    htmltools::div(
      id = ns("complete_card_wrapper"),
      style = "display: none;",
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
            class = "text-center py-2",
            htmltools::p(
              class = "mb-0",
              htmltools::span(id = ns("completion_message_text"))
            )
          )
        )
      )
    ),

    # Error card (shown on fatal error, via JavaScript)
    htmltools::div(
      id = ns("error_card_wrapper"),
      style = "display: none;",
      bslib::card(
        id = ns("error_card"),
        class = "border-danger",
        bslib::card_header(
          class = "bg-danger text-white d-flex align-items-center",
          bsicons::bs_icon("exclamation-triangle", class = "me-2"),
          i18n$t("computation_error")
        ),
        bslib::card_body(
          htmltools::div(id = ns("error_message_content")),
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
    # Visibility outputs (removed - unused, caused unnecessary reactivity)
    # Visibility is managed via JavaScript showElement/hideElement in mod_home.R
    # ========================================

    # ========================================
    # Progress updates (all via JavaScript to avoid re-renders)
    # ========================================

    # Helper: translate task message
    translate_task <- function(task) {
      if (is.null(task)) return("")
      if (task %in% c("download_start", "compute_start", "complete", "error", "resuming")) {
        return(i18n$t(paste0("task_", task)))
      }
      if (task == "download_complete") return(i18n$t("download_complete"))
      if (grepl("^download_oso_progress:", task)) {
        pct <- sub("^download_oso_progress:", "", task)
        return(paste0("T\u00e9l\u00e9chargement OSO : ", pct, " %"))
      }
      if (grepl("^download:", task)) {
        source_key <- sub("^download:", "", task)
        return(i18n$t("downloading_source", source = i18n$t(source_key)))
      }
      if (grepl("^compute:", task)) {
        indicator_key <- sub("^compute:", "", task)
        return(i18n$t("computing_indicator_name", indicator = i18n$t(indicator_key)))
      }
      paste(i18n$t("computing_indicator"), task)
    }

    # Helper: translate phase
    translate_phase <- function(phase) {
      switch(
        phase %||% "",
        "init" = i18n$t("phase_init"),
        "downloading" = i18n$t("phase_downloading"),
        "computing" = i18n$t("phase_computing"),
        "complete" = i18n$t("phase_complete"),
        ""
      )
    }

    shiny::observe({
      state <- compute_state()
      shiny::req(state)

      # Update visibility flags only when they actually change
      # (avoids unnecessary reactive invalidation that causes UI flickering)
      new_show_progress <- state$status %in% c(
        COMPUTE_STATUS$PENDING,
        COMPUTE_STATUS$DOWNLOADING,
        COMPUTE_STATUS$COMPUTING
      )
      new_show_complete <- state$status == COMPUTE_STATUS$COMPLETED
      new_show_error <- state$status == COMPUTE_STATUS$ERROR

      if (!identical(rv$show_progress, new_show_progress)) {
        rv$show_progress <- new_show_progress
      }
      if (!identical(rv$show_complete, new_show_complete)) {
        rv$show_complete <- new_show_complete
      }
      if (!identical(rv$show_error, new_show_error)) {
        rv$show_error <- new_show_error
      }

      if (rv$show_progress) {
        # Track start time
        if (is.null(rv$start_time)) {
          rv$start_time <- Sys.time()
        }

        # All updates via JavaScript (no renderText/renderUI re-renders)
        progress_pct <- round(state$progress / state$progress_max * 100)

        session$sendCustomMessage("updateProgressBar", list(
          barId = ns("progress_bar"),
          percentId = ns("progress_percent"),
          percent = progress_pct
        ))

        # Phase text
        session$sendCustomMessage("updateText", list(
          id = ns("phase_text"),
          text = translate_phase(state$phase)
        ))

        # Current task
        session$sendCustomMessage("updateText", list(
          id = ns("current_task_text"),
          text = translate_task(state$current_task)
        ))

        # Counters
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

        # Errors list (as HTML via JavaScript)
        if (length(state$errors) > 0) {
          error_items <- vapply(state$errors, function(err) {
            prefix <- if (!is.null(err$indicator)) paste0(err$indicator, ": ") else ""
            paste0("<li>\u26a0 ", htmltools::htmlEscape(prefix),
                   htmltools::htmlEscape(err$message), "</li>")
          }, character(1))
          errors_html <- paste0(
            '<div class="mt-3"><small class="text-danger fw-bold">',
            htmltools::htmlEscape(i18n$t("errors_title")),
            '</small><ul class="list-unstyled small text-danger mt-1">',
            paste(error_items, collapse = ""),
            '</ul></div>'
          )
          session$sendCustomMessage("updateHTML", list(
            id = ns("errors_list"),
            html = errors_html
          ))
        } else {
          session$sendCustomMessage("updateHTML", list(
            id = ns("errors_list"),
            html = ""
          ))
        }
      }

      # Completion message (only set once at the end, no re-render loop)
      if (rv$show_complete) {
        session$sendCustomMessage("updateText", list(
          id = ns("completion_message_text"),
          text = sprintf(
            i18n$t("computation_summary"),
            state$indicators_completed,
            state$indicators_total
          )
        ))
      }

      # Error message (only set once at the end)
      if (rv$show_error) {
        error_msg <- if (length(state$errors) > 0) {
          state$errors[[length(state$errors)]]$message
        } else {
          i18n$t("unknown_error")
        }
        extra <- if (length(state$errors) > 1) {
          paste0('<small class="text-muted">',
                 sprintf(i18n$t("and_n_more_errors"), length(state$errors) - 1),
                 '</small>')
        } else {
          ""
        }
        session$sendCustomMessage("updateHTML", list(
          id = ns("error_message_content"),
          html = paste0('<p class="text-danger">',
                        htmltools::htmlEscape(error_msg), '</p>', extra)
        ))
      }
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
