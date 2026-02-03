#' Family Indicator Module - Server
#'
#' @description
#' Generic server module for displaying one indicator family.
#' Used for all 12 families (C, B, W, A, F, L, T, R, S, P, E, N).
#'
#' @param id Character. Module namespace ID.
#' @param family_code Character. Single-letter family code.
#' @param app_state reactiveValues. Application state containing current_project.
#'
#' @return NULL (called for side effects)
#'
#' @noRd
mod_family_server <- function(id, family_code, app_state) {
  shiny::moduleServer(id, function(input, output, session) {

    family_config <- get_family_config(family_code)

    # ================================================================
    # REACTIVE: Extract family indicator columns from project
    # ================================================================
    indicators_data <- shiny::reactive({
      project <- app_state$current_project
      if (is.null(project) || is.null(project$indicators)) return(NULL)

      ind_codes <- family_config$indicators
      df <- project$indicators

      # Find columns matching this family's indicators (exact or with _norm suffix)
      all_cols <- names(df)
      matched <- character(0)
      for (code in ind_codes) {
        # Prefer normalized version
        norm_col <- paste0(code, "_norm")
        if (norm_col %in% all_cols) {
          matched <- c(matched, norm_col)
        } else if (code %in% all_cols) {
          matched <- c(matched, code)
        }
      }

      if (length(matched) == 0) return(NULL)

      # Keep id column for joining + matched indicator columns
      id_col <- intersect(c("nemeton_id", "id", "geo_parcelle"), all_cols)
      keep_cols <- c(id_col, matched)
      df[, keep_cols, drop = FALSE]
    })

    # ================================================================
    # REACTIVE: Join indicators with parcel geometries for maps
    # ================================================================
    indicators_sf <- shiny::reactive({
      ind_data <- indicators_data()
      if (is.null(ind_data)) return(NULL)

      project <- app_state$current_project
      if (is.null(project$parcels)) return(NULL)

      parcels <- project$parcels

      # Determine join column
      ind_cols <- names(ind_data)
      parcel_cols <- names(parcels)
      join_col <- NULL
      for (candidate in c("nemeton_id", "id", "geo_parcelle")) {
        if (candidate %in% ind_cols && candidate %in% parcel_cols) {
          join_col <- candidate
          break
        }
      }

      if (is.null(join_col)) return(NULL)

      # Merge: keep geometry from parcels, add indicator values
      merged <- merge(parcels[, join_col, drop = FALSE], ind_data, by = join_col, all.x = FALSE)
      if (nrow(merged) == 0) return(NULL)

      merged
    })

    # ================================================================
    # OUTPUT: Plot 1 - Map of first indicator
    # ================================================================
    output$plot1 <- shiny::renderPlot({
      i18n <- get_i18n(app_state$language)
      sf_data <- indicators_sf()

      if (is.null(sf_data)) {
        plot.new()
        text(0.5, 0.5, i18n$t("no_data"), cex = 1.5, col = "gray50")
        return()
      }

      # Get first indicator column (skip id columns)
      ind_cols <- get_indicator_cols(sf_data)
      if (length(ind_cols) == 0) {
        plot.new()
        text(0.5, 0.5, i18n$t("no_data"), cex = 1.5, col = "gray50")
        return()
      }

      plot_indicators_map(
        sf_data,
        indicators = ind_cols[1],
        palette = "viridis",
        title = clean_indicator_label(ind_cols[1], i18n),
        facet = FALSE
      )
    })

    # ================================================================
    # OUTPUT: Plot 2 - Map of 2nd indicator or barplot if only 1
    # ================================================================
    output$plot2 <- shiny::renderPlot({
      i18n <- get_i18n(app_state$language)
      sf_data <- indicators_sf()

      if (is.null(sf_data)) {
        plot.new()
        text(0.5, 0.5, i18n$t("no_data"), cex = 1.5, col = "gray50")
        return()
      }

      ind_cols <- get_indicator_cols(sf_data)
      if (length(ind_cols) == 0) {
        plot.new()
        text(0.5, 0.5, i18n$t("no_data"), cex = 1.5, col = "gray50")
        return()
      }

      if (length(ind_cols) >= 2) {
        # Map of second indicator
        plot_indicators_map(
          sf_data,
          indicators = ind_cols[2],
          palette = "viridis",
          title = clean_indicator_label(ind_cols[2], i18n),
          facet = FALSE
        )
      } else {
        # Barplot of first indicator when only one exists
        vals <- sf::st_drop_geometry(sf_data)
        id_col <- intersect(c("nemeton_id", "id", "geo_parcelle"), names(vals))
        labels <- if (length(id_col) > 0) vals[[id_col[1]]] else seq_len(nrow(vals))
        barplot(
          vals[[ind_cols[1]]],
          names.arg = labels,
          col = family_config$color,
          main = clean_indicator_label(ind_cols[1], i18n),
          ylab = ind_cols[1],
          las = 2,
          border = NA
        )
      }
    })

    # ================================================================
    # OUTPUT: Indicator data table
    # ================================================================
    output$indicator_table <- shiny::renderTable({
      ind_data <- indicators_data()
      if (is.null(ind_data)) return(NULL)

      # Drop geometry if present (should be a data.frame already)
      if (inherits(ind_data, "sf")) {
        ind_data <- sf::st_drop_geometry(ind_data)
      }

      # Round numeric columns
      num_cols <- vapply(ind_data, is.numeric, logical(1))
      ind_data[num_cols] <- lapply(ind_data[num_cols], round, digits = 3)

      ind_data
    }, striped = TRUE, hover = TRUE, bordered = TRUE)

    # ================================================================
    # OUTPUT: Missing indicators warning
    # ================================================================
    output$missing_warning <- shiny::renderUI({
      i18n <- get_i18n(app_state$language)
      project <- app_state$current_project

      if (is.null(project) || is.null(project$indicators)) {
        return(htmltools::div(
          class = "alert alert-info",
          shiny::icon("info-circle"),
          " ", i18n$t("no_data")
        ))
      }

      ind_codes <- family_config$indicators
      df <- project$indicators
      all_cols <- names(df)

      # Check which indicators are missing entirely
      missing <- character(0)
      all_na <- character(0)
      for (code in ind_codes) {
        norm_col <- paste0(code, "_norm")
        if (norm_col %in% all_cols) {
          if (all(is.na(df[[norm_col]]))) all_na <- c(all_na, code)
        } else if (code %in% all_cols) {
          if (all(is.na(df[[code]]))) all_na <- c(all_na, code)
        } else {
          missing <- c(missing, code)
        }
      }

      warnings <- list()
      if (length(missing) > 0) {
        warnings <- c(warnings, list(htmltools::p(
          class = "mb-1",
          shiny::icon("exclamation-triangle"),
          sprintf(" %s: %s", i18n$t("missing_data"), paste(missing, collapse = ", "))
        )))
      }
      if (length(all_na) > 0) {
        warnings <- c(warnings, list(htmltools::p(
          class = "mb-1",
          shiny::icon("exclamation-triangle"),
          sprintf(" %s: %s", i18n$t("no_data"), paste(all_na, collapse = ", "))
        )))
      }

      if (length(warnings) == 0) return(NULL)

      htmltools::div(
        class = "alert alert-warning mt-2",
        warnings
      )
    })

  })
}


# ================================================================
# HELPER FUNCTIONS
# ================================================================

#' Get indicator columns from an sf/data.frame (exclude id/geometry cols)
#' @noRd
get_indicator_cols <- function(data) {
  all_cols <- names(data)
  exclude <- c("nemeton_id", "id", "geo_parcelle", "geometry", "geom",
                "nomcommune", "codecommune", "area", "surface_geo")
  setdiff(all_cols, exclude)
}

#' Clean indicator label for display
#' @noRd
clean_indicator_label <- function(col_name, i18n) {
  # Strip _norm suffix for display
  base <- sub("_norm$", "", col_name)
  # Try i18n key first
  key <- paste0("indicator_", base)
  if (i18n$has(key)) {
    return(i18n$t(key))
  }
  base
}
