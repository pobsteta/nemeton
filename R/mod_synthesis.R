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
      project$indicators
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

      # Merge indicators into sf
      merged <- merge(parcels, indicators, by = join_col, all.x = FALSE)
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

      nemeton_radar(sf_data, mode = "family", title = i18n$t("radar_title"))
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
