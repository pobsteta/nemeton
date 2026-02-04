#' Synthesis Module - Server
#'
#' @description
#' Server module for the project synthesis view.
#' Displays radar chart, summary table, and download buttons.
#'
#' @param id Character. Module namespace ID.
#' @param app_state reactiveValues. Application state containing current_project.
#'
#' @return NULL (called for side effects)
#'
#' @noRd
mod_synthesis_server <- function(id, app_state) {
  shiny::moduleServer(id, function(input, output, session) {

    # ================================================================
    # REACTIVE: Project indicators
    # ================================================================
    project_indicators <- shiny::reactive({
      project <- app_state$current_project
      if (is.null(project) || is.null(project$indicators)) return(NULL)

      df <- project$indicators

      # Drop geometry if sf (indicators from parquet may have geoarrow geometry)
      if (inherits(df, "sf")) {
        df <- tryCatch(sf::st_drop_geometry(df),
                       error = function(e) {
                         geo_col <- attr(df, "sf_column") %||% "geometry"
                         result <- df[, setdiff(names(df), geo_col), drop = FALSE]
                         class(result) <- "data.frame"
                         result
                       })
      }

      df
    })

    # ================================================================
    # REACTIVE: Build sf with family scores
    # ================================================================
    family_scores <- shiny::reactive({
      indicators <- project_indicators()
      if (is.null(indicators)) return(NULL)

      project <- app_state$current_project
      if (is.null(project$parcels)) return(NULL)

      parcels <- project$parcels

      # Determine join column
      ind_cols <- names(indicators)
      parcel_cols <- names(parcels)
      join_col <- NULL
      for (candidate in c("nemeton_id", "id", "geo_parcelle")) {
        if (candidate %in% ind_cols && candidate %in% parcel_cols) {
          join_col <- candidate
          break
        }
      }

      if (is.null(join_col)) return(NULL)

      # Subset indicators to only keep join column + actual indicator columns
      # (avoid duplicating metadata columns like section, numero, contenance, etc.)
      all_indicator_cols <- get_all_column_names()
      # Also include _norm variants
      norm_cols <- paste0(all_indicator_cols, "_norm")
      keep_cols <- intersect(names(indicators),
                             c(join_col, all_indicator_cols, norm_cols))
      indicators_subset <- indicators[, keep_cols, drop = FALSE]

      # Merge: parcels (sf) + indicators subset (data.frame)
      merged <- merge(parcels, indicators_subset, by = join_col, all.x = FALSE)
      if (nrow(merged) == 0) return(NULL)

      # Compute family indices
      tryCatch(
        create_family_index(merged, method = "mean", na.rm = TRUE),
        error = function(e) {
          cli::cli_warn("Failed to compute family index: {conditionMessage(e)}")
          NULL
        }
      )
    })

    # ================================================================
    # OUTPUT: Project summary
    # ================================================================
    output$project_summary <- shiny::renderUI({
      i18n <- get_i18n(app_state$language)
      project <- app_state$current_project

      if (is.null(project)) {
        return(htmltools::div(
          class = "text-muted",
          i18n$t("no_project")
        ))
      }

      meta <- project$metadata
      nb_parcels <- if (!is.null(project$parcels)) nrow(project$parcels) else 0L

      htmltools::div(
        shiny::h5(meta$name),
        if (!is.null(meta$description) && nzchar(meta$description)) {
          shiny::p(meta$description)
        },
        shiny::p(
          class = "small text-muted",
          sprintf("%s: %s", i18n$t("created_at"), meta$created_at)
        ),
        shiny::p(
          class = "small",
          sprintf("%d %s", nb_parcels, i18n$t("parcels"))
        ),
        shiny::tags$span(
          class = paste0("badge bg-", if (meta$status == "completed") "success" else "secondary"),
          i18n$t(paste0("status_", meta$status))
        )
      )
    })

    # ================================================================
    # OUTPUT: Global score (mean of all family scores)
    # ================================================================
    output$global_score <- shiny::renderUI({
      i18n <- get_i18n(app_state$language)
      sf_data <- family_scores()

      if (is.null(sf_data)) {
        return(htmltools::div(
          class = "text-center text-muted py-4",
          shiny::icon("chart-line", class = "fa-2x"),
          shiny::p(i18n$t("no_data"))
        ))
      }

      family_cols <- grep("^family_[A-Z]$", names(sf_data), value = TRUE)
      if (length(family_cols) == 0) {
        return(htmltools::div(class = "text-muted", i18n$t("no_data")))
      }

      # Compute global score: mean of family means across all parcels
      df <- sf::st_drop_geometry(sf_data)
      family_means <- vapply(family_cols, function(col) {
        mean(df[[col]], na.rm = TRUE)
      }, numeric(1))
      global <- round(mean(family_means, na.rm = TRUE), 1)

      # Color based on score
      score_color <- if (global >= 60) "#228B22" else if (global >= 40) "#FF8C00" else "#DC143C"

      htmltools::div(
        class = "text-center py-3",
        shiny::p(class = "text-muted mb-1", "Score global"),
        htmltools::div(
          style = paste0(
            "font-size: 4rem; font-weight: bold; color: ", score_color,
            "; line-height: 1;"
          ),
          global
        ),
        shiny::p(
          class = "text-muted mt-1 mb-0",
          sprintf("/ 100 (%d %s)", length(family_cols),
                  if (i18n$language == "fr") "familles" else "families")
        )
      )
    })

    # ================================================================
    # OUTPUT: Radar plot
    # ================================================================
    output$radar_plot <- shiny::renderPlot({
      i18n <- get_i18n(app_state$language)
      sf_data <- family_scores()

      if (is.null(sf_data)) {
        plot.new()
        text(0.5, 0.5, i18n$t("no_data"), cex = 1.5, col = "gray50")
        return()
      }

      # Check that family columns exist
      family_cols <- grep("^family_[A-Z]$", names(sf_data), value = TRUE)
      if (length(family_cols) == 0) {
        plot.new()
        text(0.5, 0.5, i18n$t("no_data"), cex = 1.5, col = "gray50")
        return()
      }

      nemeton_radar(sf_data, mode = "family", normalize = FALSE,
                    title = i18n$t("radar_title"))
    })

    # ================================================================
    # OUTPUT: Summary table (one row per family)
    # ================================================================
    output$summary_table <- shiny::renderTable({
      i18n <- get_i18n(app_state$language)
      sf_data <- family_scores()

      if (is.null(sf_data)) return(NULL)

      lang <- app_state$language
      families <- INDICATOR_FAMILIES
      codes <- names(families)

      # Build summary data.frame
      rows <- lapply(codes, function(code) {
        col_name <- paste0("family_", code)
        fam <- families[[code]]
        fam_name <- if (lang == "fr") fam$name_fr else fam$name_en

        if (col_name %in% names(sf_data)) {
          vals <- sf::st_drop_geometry(sf_data)[[col_name]]
          score <- mean(vals, na.rm = TRUE)
        } else {
          score <- NA_real_
        }

        data.frame(
          Family = fam_name,
          Code = code,
          Score = round(score, 2),
          Indicators = length(fam$indicators),
          stringsAsFactors = FALSE
        )
      })

      result <- do.call(rbind, rows)

      # Rename columns for display
      col_names <- c(
        i18n$t("family_C"),  # reuse as generic "Family" label
        "Code",
        "Score",
        i18n$t("indicator_column")
      )
      # Simpler: just use standard names
      names(result) <- c(
        if (lang == "fr") "Famille" else "Family",
        "Code",
        "Score",
        if (lang == "fr") "Nb indicateurs" else "Nb indicators"
      )

      result
    }, striped = TRUE, hover = TRUE, bordered = TRUE)

    # ================================================================
    # AI ANALYSIS: Generate synthesis analysis via ellmer
    # ================================================================
    shiny::observeEvent(input$ai_generate, {
      i18n <- get_i18n(app_state$language)

      # Check API key for providers that require one
      provider <- get_app_config("llm_provider", "anthropic")
      key_var <- get_llm_api_key_var(provider)
      if (!is.null(key_var) && nchar(Sys.getenv(key_var)) == 0) {
        msg <- gsub("\\{key_var\\}", key_var, i18n$t("ai_no_api_key"))
        shiny::showNotification(msg, type = "warning", duration = 8)
        return()
      }

      sf_data <- family_scores()
      if (is.null(sf_data)) return()

      # Disable button during call
      shiny::updateActionButton(session, "ai_generate",
                                label = i18n$t("ai_generating"),
                                icon = shiny::icon("spinner", class = "fa-spin"))

      # Show notification while AI is thinking
      notif_id <- shiny::showNotification(
        htmltools::div(
          shiny::icon("spinner", class = "fa-spin me-2"),
          i18n$t("ai_generating")
        ),
        type = "message",
        duration = NULL
      )

      language <- if (identical(app_state$language, "fr")) "fran\u00e7ais" else "English"
      prompt <- build_synthesis_prompt(sf_data, language)
      expert <- input$expert_profile %||% "generalist"
      system_prompt <- build_system_prompt(language, expert = expert)

      tryCatch({
        chat <- create_llm_chat(system_prompt)
        response <- chat$chat(prompt, echo = FALSE)

        shiny::updateTextAreaInput(session, "synthesis_comments", value = response)
        shiny::removeNotification(notif_id)
      }, error = function(e) {
        shiny::removeNotification(notif_id)
        shiny::showNotification(
          paste(i18n$t("ai_error"), ":", conditionMessage(e)),
          type = "error",
          duration = 8
        )
      })

      # Restore button
      shiny::updateActionButton(session, "ai_generate",
                                label = i18n$t("ai_generate"),
                                icon = shiny::icon("robot"))
    })

    # ================================================================
    # DOWNLOAD: GeoPackage export
    # ================================================================
    output$download_gpkg <- shiny::downloadHandler(
      filename = function() {
        project <- app_state$current_project
        name <- if (!is.null(project$metadata$name)) {
          gsub("[^a-zA-Z0-9_-]", "_", project$metadata$name)
        } else {
          "nemeton_export"
        }
        paste0(name, ".gpkg")
      },
      content = function(file) {
        sf_data <- family_scores()
        if (is.null(sf_data)) {
          # Write empty file
          writeLines("No data available", file)
          return()
        }

        sf::st_write(sf_data, file, driver = "GPKG", delete_dsn = TRUE, quiet = TRUE)
      }
    )

    # ================================================================
    # DOWNLOAD: PDF report (placeholder - Phase 6)
    # ================================================================
    output$download_pdf <- shiny::downloadHandler(
      filename = function() {
        project <- app_state$current_project
        name <- if (!is.null(project$metadata$name)) {
          gsub("[^a-zA-Z0-9_-]", "_", project$metadata$name)
        } else {
          "nemeton_report"
        }
        paste0(name, "_report.pdf")
      },
      content = function(file) {
        i18n <- get_i18n(app_state$language)
        # Phase 6 will implement full Quarto report generation
        shiny::showNotification(
          "PDF report generation will be available in a future version.",
          type = "warning"
        )
        # Create a minimal placeholder file
        writeLines("PDF report - Coming soon (Phase 6)", file)
      }
    )

  })
}
