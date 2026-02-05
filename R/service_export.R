#' Export Services
#'
#' @description
#' Functions for exporting nemeton project data and generating reports.
#'
#' @name service_export
#' @keywords internal
NULL


#' Check if Quarto is installed
#'
#' @description
#' Checks if Quarto CLI is available on the system.
#'
#' @return Logical. TRUE if Quarto is installed.
#' @noRd
is_quarto_installed <- function() {
  quarto_path <- Sys.which("quarto")
  nchar(quarto_path) > 0
}


#' Ensure Quarto is installed
#'
#' @description
#' Checks if Quarto is installed and attempts to install it if not.
#' Uses the quarto R package for installation if available.
#'
#' @return Logical. TRUE if Quarto is available after check/install.
#' @noRd
ensure_quarto_installed <- function() {
  if (is_quarto_installed()) {
    return(TRUE)
  }


  # Try to install via quarto package

  if (requireNamespace("quarto", quietly = TRUE)) {
    tryCatch({
      cli::cli_alert_info("Quarto not found. Attempting installation...")
      quarto::quarto_install()
      return(is_quarto_installed())
    }, error = function(e) {
      cli::cli_warn("Failed to install Quarto: {conditionMessage(e)}")
      return(FALSE)
    })
  }

  cli::cli_warn("Quarto is not installed and the 'quarto' package is not available for auto-installation.")
  cli::cli_alert_info("Please install Quarto manually from https://quarto.org/docs/get-started/")
  FALSE
}


#' Generate PDF report for a project
#'
#' @description
#' Generates a PDF report using Quarto with all project data,
#' including radar chart, family scores, and indicator maps.
#'
#' @param project List. The project object with metadata, parcels, and indicators.
#' @param family_scores sf. Family scores computed by create_family_index().
#' @param output_file Character. Path to output PDF file.
#' @param language Character. Language code ("fr" or "en").
#' @param synthesis_comments Character. Optional synthesis comments to include.
#'
#' @return Character. Path to generated PDF file, or NULL on failure.
#'
#' @noRd
generate_pdf_report <- function(project,
                                family_scores,
                                output_file,
                                language = "fr",
                                synthesis_comments = NULL) {
  # Check Quarto installation
  if (!ensure_quarto_installed()) {
    stop("Quarto is required for PDF report generation but is not available.",
         call. = FALSE)
  }

  # Create temporary directory for report generation
  temp_dir <- tempfile("nemeton_report_")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  # Copy template to temp directory
  template_path <- system.file("quarto", "report_template.qmd", package = "nemeton")
  if (!file.exists(template_path)) {
    stop("Report template not found. Package may be incomplete.", call. = FALSE)
  }

  report_qmd <- file.path(temp_dir, "report.qmd")
  file.copy(template_path, report_qmd)

  # Prepare data for the report
  report_data <- prepare_report_data(project, family_scores, language, synthesis_comments)

  # Save data as RDS for the template to load
  data_file <- file.path(temp_dir, "report_data.rds")
  saveRDS(report_data, data_file)

  # Generate radar plot as static image
  radar_file <- file.path(temp_dir, "radar_plot.png")
  generate_radar_image(family_scores, radar_file, language)

  # Render with Quarto
  tryCatch({
    quarto::quarto_render(
      input = report_qmd,
      output_format = "pdf",
      execute_params = list(
        data_file = data_file,
        radar_file = radar_file,
        language = language
      ),
      quiet = TRUE
    )

    # Find and copy output file
    pdf_output <- sub("\\.qmd$", ".pdf", report_qmd)
    if (file.exists(pdf_output)) {
      file.copy(pdf_output, output_file, overwrite = TRUE)
      return(output_file)
    } else {
      stop("PDF file was not generated")
    }
  }, error = function(e) {
    cli::cli_warn("Quarto render failed: {conditionMessage(e)}")
    NULL
  })
}


#' Prepare report data structure
#'
#' @description
#' Prepares all data needed for the report template.
#'
#' @param project List. Project object.
#' @param family_scores sf. Family scores.
#' @param language Character. Language code.
#' @param synthesis_comments Character. Optional comments.
#'
#' @return List with all report data.
#' @noRd
prepare_report_data <- function(project, family_scores, language, synthesis_comments) {
  i18n <- get_i18n(language)

  # Drop geometry for data processing
  scores_df <- if (inherits(family_scores, "sf")) {
    sf::st_drop_geometry(family_scores)
  } else {
    family_scores
  }

  # Get family columns
  family_cols <- grep("^family_[A-Z]$", names(scores_df), value = TRUE)

  # Calculate family statistics
  family_stats <- lapply(family_cols, function(col) {
    code <- sub("^family_", "", col)
    fam <- INDICATOR_FAMILIES[[code]]
    vals <- scores_df[[col]]

    list(
      code = code,
      name = if (language == "fr") fam$name_fr else fam$name_en,
      mean = round(mean(vals, na.rm = TRUE), 1),
      min = round(min(vals, na.rm = TRUE), 1),
      max = round(max(vals, na.rm = TRUE), 1),
      sd = round(sd(vals, na.rm = TRUE), 1),
      color = fam$color,
      icon = fam$icon
    )
  })
  names(family_stats) <- sub("^family_", "", family_cols)

  # Global score
  family_means <- vapply(family_cols, function(col) {
    mean(scores_df[[col]], na.rm = TRUE)
  }, numeric(1))
  global_score <- round(mean(family_means, na.rm = TRUE), 1)

  # Metadata
  meta <- project$metadata
  n_parcels <- nrow(family_scores)

  list(
    # Metadata
    project_name = meta$name,
    project_description = meta$description,
    project_owner = meta$owner,
    created_at = meta$created_at,
    n_parcels = n_parcels,

    # Scores
    global_score = global_score,
    family_stats = family_stats,

    # Comments
    synthesis_comments = synthesis_comments,

    # Language
    language = language,

    # Translations
    labels = list(
      title = if (language == "fr") "Diagnostic Forestier Németon" else "Németon Forest Diagnostic",
      subtitle = if (language == "fr") "Rapport de synthèse" else "Synthesis Report",
      project_info = i18n$t("project_info"),
      global_score_label = i18n$t("global_score"),
      parcels = i18n$t("parcels"),
      created_at = i18n$t("created_at"),
      family_scores = if (language == "fr") "Scores par famille" else "Scores by family",
      radar_title = i18n$t("radar_title"),
      comments_title = i18n$t("comments_title"),
      generated_by = if (language == "fr") "Généré par nemeton" else "Generated by nemeton"
    )
  )
}


#' Generate radar plot as PNG image
#'
#' @param family_scores sf. Family scores data.
#' @param output_file Character. Path to output PNG file.
#' @param language Character. Language code.
#'
#' @return Invisible NULL.
#' @noRd
generate_radar_image <- function(family_scores, output_file, language) {
  grDevices::png(output_file, width = 800, height = 800, res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)

  i18n <- get_i18n(language)

  tryCatch({
    nemeton_radar(family_scores, mode = "family", normalize = FALSE,
                  title = i18n$t("radar_title"))
  }, error = function(e) {
    # Fallback: empty plot with message
    plot.new()
    text(0.5, 0.5, "Radar plot unavailable", cex = 1.5)
  })

  invisible(NULL)
}


#' Export project data to GeoPackage
#'
#' @description
#' Exports the project data with all indicators and family scores
#' to a GeoPackage file.
#'
#' @param family_scores sf. Family scores with geometry.
#' @param output_file Character. Path to output .gpkg file.
#' @param layer_name Character. Layer name in GeoPackage.
#'
#' @return Character. Path to created file.
#'
#' @noRd
export_geopackage <- function(family_scores, output_file, layer_name = "nemeton_results") {
  if (!inherits(family_scores, "sf")) {
    stop("family_scores must be an sf object", call. = FALSE)
  }

  sf::st_write(
    family_scores,
    output_file,
    layer = layer_name,
    driver = "GPKG",
    delete_dsn = TRUE,
    quiet = TRUE
  )

  output_file
}


#' Generate simple PDF report without Quarto
#'
#' @description
#' Fallback PDF generation using base R graphics when Quarto is not available.
#' Creates a basic multi-page PDF with project summary and radar chart.
#'
#' @param project List. Project object.
#' @param family_scores sf. Family scores.
#' @param output_file Character. Path to output PDF.
#' @param language Character. Language code.
#' @param synthesis_comments Character. Optional comments.
#'
#' @return Character. Path to generated PDF.
#' @noRd
generate_simple_pdf_report <- function(project,
                                       family_scores,
                                       output_file,
                                       language = "fr",
                                       synthesis_comments = NULL) {
  i18n <- get_i18n(language)

  # Prepare data
  report_data <- prepare_report_data(project, family_scores, language, synthesis_comments)

  # Open PDF device
  grDevices::pdf(output_file, width = 8.27, height = 11.69, paper = "a4")
  on.exit(grDevices::dev.off(), add = TRUE)

  # Page 1: Title and Summary
  plot.new()
  # Title
  graphics::text(0.5, 0.9, report_data$labels$title,
                 cex = 2, font = 2, col = "#2E7D32")
  graphics::text(0.5, 0.85, report_data$labels$subtitle,
                 cex = 1.2, col = "gray50")

  # Project info
  graphics::text(0.5, 0.75, report_data$project_name, cex = 1.5, font = 2)
  if (!is.null(report_data$project_description) && nchar(report_data$project_description) > 0) {
    graphics::text(0.5, 0.70, report_data$project_description, cex = 1)
  }

  # Stats
  info_y <- 0.60
  graphics::text(0.5, info_y,
                 sprintf("%s: %d", report_data$labels$parcels, report_data$n_parcels),
                 cex = 1)
  graphics::text(0.5, info_y - 0.05,
                 sprintf("%s: %s", report_data$labels$created_at, report_data$created_at),
                 cex = 1)

  # Global score with color
  score_color <- if (report_data$global_score >= 60) "#228B22"
  else if (report_data$global_score >= 40) "#FF8C00"
  else "#DC143C"

  graphics::text(0.5, 0.40, report_data$labels$global_score_label, cex = 1.2)
  graphics::text(0.5, 0.30, sprintf("%.1f / 100", report_data$global_score),
                 cex = 3, font = 2, col = score_color)

  # Footer
  graphics::text(0.5, 0.05, report_data$labels$generated_by, cex = 0.8, col = "gray50")

  # Page 2: Radar Chart
  tryCatch({
    nemeton_radar(family_scores, mode = "family", normalize = FALSE,
                  title = report_data$labels$radar_title)
  }, error = function(e) {
    plot.new()
    graphics::text(0.5, 0.5, "Radar plot unavailable", cex = 1.5)
  })

  # Page 3: Family Scores Table
  plot.new()
  graphics::text(0.5, 0.95, report_data$labels$family_scores, cex = 1.5, font = 2)

  # Draw table
  y_start <- 0.85
  y_step <- 0.06

  # Header
  graphics::text(0.15, y_start, "Code", font = 2, cex = 0.9)
  graphics::text(0.45, y_start, if (language == "fr") "Famille" else "Family", font = 2, cex = 0.9)
  graphics::text(0.75, y_start, "Score", font = 2, cex = 0.9)
  graphics::text(0.90, y_start, "Min-Max", font = 2, cex = 0.9)

  graphics::abline(h = y_start - 0.02, col = "gray70")

  # Data rows
  y <- y_start - y_step
  for (fam in report_data$family_stats) {
    graphics::text(0.15, y, fam$code, cex = 0.85)
    graphics::text(0.45, y, fam$name, cex = 0.85)
    graphics::text(0.75, y, sprintf("%.1f", fam$mean), cex = 0.85, col = fam$color, font = 2)
    graphics::text(0.90, y, sprintf("%.0f-%.0f", fam$min, fam$max), cex = 0.75, col = "gray50")
    y <- y - y_step
  }

  # Page 4: Comments (if provided)
  if (!is.null(synthesis_comments) && nchar(synthesis_comments) > 0) {
    plot.new()
    graphics::text(0.5, 0.95, report_data$labels$comments_title, cex = 1.5, font = 2)

    # Wrap text
    wrapped <- strwrap(synthesis_comments, width = 80)
    y <- 0.85
    for (line in wrapped) {
      if (y < 0.1) break
      graphics::text(0.5, y, line, cex = 0.8)
      y <- y - 0.03
    }
  }

  output_file
}


#' Generate PDF report (main entry point)
#'
#' @description
#' Generates a PDF report, using Quarto if available or falling back
#' to simple PDF generation.
#'
#' @param project List. Project object.
#' @param family_scores sf. Family scores.
#' @param output_file Character. Path to output PDF.
#' @param language Character. Language code.
#' @param synthesis_comments Character. Optional comments.
#' @param use_quarto Logical. Whether to try Quarto first. Default TRUE.
#'
#' @return Character. Path to generated PDF.
#' @export
generate_report_pdf <- function(project,
                                family_scores,
                                output_file,
                                language = "fr",
                                synthesis_comments = NULL,
                                use_quarto = TRUE) {
  if (use_quarto && is_quarto_installed()) {
    result <- tryCatch(
      generate_pdf_report(project, family_scores, output_file, language, synthesis_comments),
      error = function(e) {
        cli::cli_warn("Quarto report failed, falling back to simple PDF: {conditionMessage(e)}")
        NULL
      }
    )
    if (!is.null(result)) return(result)
  }

  # Fallback to simple PDF
  generate_simple_pdf_report(project, family_scores, output_file, language, synthesis_comments)
}
