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

      all_cols <- names(df)

      # Try both short codes (C1, C2) and long-form column names (carbon_biomass)
      candidates <- c(family_config$indicators, family_config$column_names)
      matched <- character(0)
      for (col in candidates) {
        # Prefer normalized version
        norm_col <- paste0(col, "_norm")
        if (norm_col %in% all_cols) {
          matched <- c(matched, norm_col)
        } else if (col %in% all_cols) {
          matched <- c(matched, col)
        }
      }

      # Deduplicate (in case short and long both matched)
      matched <- unique(matched)
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
    # OUTPUT: Map 1 - Leaflet map of first indicator
    # ================================================================
    output$map1 <- leaflet::renderLeaflet({
      i18n <- get_i18n(app_state$language)
      sf_data <- indicators_sf()

      if (is.null(sf_data)) {
        return(leaflet::leaflet() |>
          leaflet::addTiles() |>
          leaflet::setView(lng = 2.5, lat = 46.5, zoom = 6))
      }

      ind_cols <- get_indicator_cols(sf_data)
      if (length(ind_cols) == 0) {
        return(leaflet::leaflet() |>
          leaflet::addTiles() |>
          leaflet::setView(lng = 2.5, lat = 46.5, zoom = 6))
      }

      make_indicator_leaflet(sf_data, ind_cols[1],
                             clean_indicator_label(ind_cols[1], i18n))
    })

    # ================================================================
    # OUTPUT: Plot 2 UI - Leaflet map or barplot depending on indicators
    # ================================================================
    output$plot2_ui <- shiny::renderUI({
      ns <- session$ns
      i18n <- get_i18n(app_state$language)
      sf_data <- indicators_sf()

      if (is.null(sf_data)) {
        return(htmltools::div(
          class = "text-muted text-center p-4",
          i18n$t("no_data")
        ))
      }

      ind_cols <- get_indicator_cols(sf_data)
      if (length(ind_cols) == 0) {
        return(htmltools::div(
          class = "text-muted text-center p-4",
          i18n$t("no_data")
        ))
      }

      if (length(ind_cols) >= 2) {
        leaflet::leafletOutput(ns("map2"), height = "450px")
      } else {
        shiny::plotOutput(ns("barplot1"), height = "450px")
      }
    })

    # Leaflet map for second indicator
    output$map2 <- leaflet::renderLeaflet({
      i18n <- get_i18n(app_state$language)
      sf_data <- indicators_sf()
      if (is.null(sf_data)) return(NULL)

      ind_cols <- get_indicator_cols(sf_data)
      if (length(ind_cols) < 2) return(NULL)

      make_indicator_leaflet(sf_data, ind_cols[2],
                             clean_indicator_label(ind_cols[2], i18n))
    })

    # Barplot fallback when only one indicator
    output$barplot1 <- shiny::renderPlot({
      i18n <- get_i18n(app_state$language)
      sf_data <- indicators_sf()
      if (is.null(sf_data)) return(NULL)

      ind_cols <- get_indicator_cols(sf_data)
      if (length(ind_cols) != 1) return(NULL)

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
    })

    # ================================================================
    # OUTPUT: Indicator data table
    # ================================================================
    output$indicator_table <- DT::renderDataTable({
      ind_data <- indicators_data()
      if (is.null(ind_data)) return(NULL)

      # Drop geometry if present (should be a data.frame already)
      if (inherits(ind_data, "sf")) {
        ind_data <- sf::st_drop_geometry(ind_data)
      }

      # Round numeric columns
      num_cols <- vapply(ind_data, is.numeric, logical(1))
      ind_data[num_cols] <- lapply(ind_data[num_cols], round, digits = 3)

      DT::datatable(ind_data,
                     selection = "single",
                     options = list(
                       pageLength = 10,
                       scrollX = TRUE,
                       language = list(
                         url = if (identical(app_state$language, "fr"))
                           "//cdn.datatables.net/plug-ins/1.13.7/i18n/fr-FR.json"
                         else ""
                       )
                     ),
                     class = "table table-striped table-hover table-bordered")
    })

    # ================================================================
    # OBSERVER: Click on table row → zoom to parcel on maps
    # ================================================================
    shiny::observeEvent(input$indicator_table_rows_selected, {
      row_idx <- input$indicator_table_rows_selected
      if (is.null(row_idx) || length(row_idx) == 0) return()

      sf_data <- indicators_sf()
      if (is.null(sf_data) || row_idx > nrow(sf_data)) return()

      # Get the selected parcel geometry and compute bbox with padding
      selected <- sf_data[row_idx, ]
      selected_wgs84 <- sf::st_transform(selected, 4326)
      bbox <- sf::st_bbox(selected_wgs84)

      # Expand bbox by 20% in each direction for comfortable view
      dx <- (bbox[["xmax"]] - bbox[["xmin"]]) * 0.2
      dy <- (bbox[["ymax"]] - bbox[["ymin"]]) * 0.2
      # Ensure a minimum padding for very small parcels
      dx <- max(dx, 0.001)
      dy <- max(dy, 0.001)

      lng1 <- bbox[["xmin"]] - dx
      lat1 <- bbox[["ymin"]] - dy
      lng2 <- bbox[["xmax"]] + dx
      lat2 <- bbox[["ymax"]] + dy

      # Zoom map1
      leaflet::leafletProxy("map1", session) |>
        leaflet::fitBounds(lng1 = lng1, lat1 = lat1, lng2 = lng2, lat2 = lat2)

      # Zoom map2 if it exists (when there are >= 2 indicators)
      ind_cols <- get_indicator_cols(sf_data)
      if (length(ind_cols) >= 2) {
        leaflet::leafletProxy("map2", session) |>
          leaflet::fitBounds(lng1 = lng1, lat1 = lat1, lng2 = lng2, lat2 = lat2)
      }
    })

    # ================================================================
    # OUTPUT: Analysis - descriptive statistics + alerts
    # ================================================================
    output$analysis_stats <- shiny::renderUI({
      i18n <- get_i18n(app_state$language)
      ind_data <- indicators_data()
      if (is.null(ind_data)) return(NULL)

      if (inherits(ind_data, "sf")) {
        ind_data <- sf::st_drop_geometry(ind_data)
      }

      ind_cols <- get_indicator_cols(ind_data)
      if (length(ind_cols) == 0) return(NULL)

      # Build stats table for each indicator
      stats_rows <- lapply(ind_cols, function(col) {
        vals <- ind_data[[col]]
        n_total <- length(vals)
        n_na <- sum(is.na(vals))
        vals_clean <- vals[!is.na(vals)]
        n <- length(vals_clean)

        if (n == 0) return(NULL)

        mn <- min(vals_clean)
        mx <- max(vals_clean)
        avg <- mean(vals_clean)
        med <- stats::median(vals_clean)
        sd_val <- if (n > 1) stats::sd(vals_clean) else 0
        cv <- if (avg != 0) abs(sd_val / avg) * 100 else 0

        label <- clean_indicator_label(col, i18n)

        # Alerts
        alerts <- list()
        if (cv > 50) {
          alerts <- c(alerts, list(htmltools::div(
            class = "text-warning small",
            shiny::icon("exclamation-triangle"),
            " ", i18n$t("alert_high_variability")
          )))
        }
        if (n_na > 0) {
          msg <- gsub("\\{n\\}", n_na, gsub("\\{total\\}", n_total,
                       i18n$t("alert_many_na")))
          alerts <- c(alerts, list(htmltools::div(
            class = "text-danger small",
            shiny::icon("exclamation-circle"),
            " ", msg
          )))
        }

        htmltools::div(
          class = "mb-3",
          htmltools::tags$strong(label),
          htmltools::tags$table(
            class = "table table-sm table-borderless mb-1",
            style = "font-size: 0.85em;",
            htmltools::tags$tbody(
              htmltools::tags$tr(
                htmltools::tags$td(i18n$t("stat_n")),
                htmltools::tags$td(class = "text-end", n),
                htmltools::tags$td(i18n$t("stat_min")),
                htmltools::tags$td(class = "text-end", round(mn, 3))
              ),
              htmltools::tags$tr(
                htmltools::tags$td(i18n$t("stat_max")),
                htmltools::tags$td(class = "text-end", round(mx, 3)),
                htmltools::tags$td(i18n$t("stat_mean")),
                htmltools::tags$td(class = "text-end", round(avg, 3))
              ),
              htmltools::tags$tr(
                htmltools::tags$td(i18n$t("stat_median")),
                htmltools::tags$td(class = "text-end", round(med, 3)),
                htmltools::tags$td(i18n$t("stat_sd")),
                htmltools::tags$td(class = "text-end", round(sd_val, 3))
              )
            )
          ),
          if (length(alerts) > 0) htmltools::tagList(alerts)
        )
      })

      htmltools::div(
        htmltools::tagList(stats_rows)
      )
    })

    # ================================================================
    # AI ANALYSIS: Generate analysis via ellmer/Claude
    # ================================================================
    shiny::observeEvent(input$ai_generate, {
      i18n <- get_i18n(app_state$language)

      # Check API key for providers that require one
      provider <- get_app_config("llm_provider", "anthropic")
      key_var <- get_llm_api_key_var(provider)
      if (!is.null(key_var) && nchar(Sys.getenv(key_var)) == 0) {
        msg <- gsub("\\{key_var\\}", key_var, i18n$t("ai_no_api_key"))
        shiny::showNotification(
          msg,
          type = "warning",
          duration = 8
        )
        return()
      }

      ind_data <- indicators_data()
      if (is.null(ind_data)) return()

      # Disable button during call
      shiny::updateActionButton(session, "ai_generate",
                                label = i18n$t("ai_generating"),
                                icon = shiny::icon("spinner", class = "fa-spin"))

      language <- if (identical(app_state$language, "fr")) "fran\u00e7ais" else "English"
      prompt <- build_analysis_prompt(family_config, ind_data, language)
      expert <- input$expert_profile %||% "generalist"
      system_prompt <- build_system_prompt(language, expert = expert)

      tryCatch({
        chat <- create_llm_chat(system_prompt)
        response <- chat$chat(prompt, echo = FALSE)

        shiny::updateTextAreaInput(session, "analysis_comments", value = response)
      }, error = function(e) {
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

      df <- project$indicators
      all_cols <- names(df)

      # Check both short codes and long-form column names
      candidates <- c(family_config$indicators, family_config$column_names)

      # Check which indicators are missing entirely
      missing <- character(0)
      all_na <- character(0)
      # Check in pairs: short code + long-form name
      for (i in seq_along(family_config$indicators)) {
        code <- family_config$indicators[i]
        long_name <- if (!is.null(family_config$column_names) &&
                         i <= length(family_config$column_names)) {
          family_config$column_names[i]
        } else {
          NULL
        }
        # Check if any form exists
        found_col <- NULL
        for (col in c(paste0(code, "_norm"), code,
                      if (!is.null(long_name)) c(paste0(long_name, "_norm"), long_name))) {
          if (col %in% all_cols) { found_col <- col; break }
        }
        if (is.null(found_col)) {
          missing <- c(missing, code)
        } else if (all(is.na(df[[found_col]]))) {
          all_na <- c(all_na, code)
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

#' Create an LLM chat object based on configured provider
#'
#' @description
#' Factory function that reads `llm_provider` from app config and dispatches
#' to the appropriate `ellmer::chat_*()` constructor.
#'
#' @param system_prompt Character. System prompt for the chat.
#' @return An ellmer chat object.
#' @noRd
create_llm_chat <- function(system_prompt) {
  provider <- get_app_config("llm_provider", "anthropic")
  models <- get_app_config("llm_models", list())
  model <- models[[provider]]

  switch(provider,
    anthropic = ellmer::chat_anthropic(system_prompt = system_prompt, model = model),
    mistral = ellmer::chat_mistral(system_prompt = system_prompt, model = model),
    openai = ellmer::chat_openai(system_prompt = system_prompt, model = model),
    google = ellmer::chat_google_gemini(system_prompt = system_prompt, model = model),
    deepseek = ellmer::chat_deepseek(system_prompt = system_prompt, model = model),
    ollama = ellmer::chat_ollama(system_prompt = system_prompt, model = model),
    stop(sprintf("Unknown LLM provider: '%s'", provider))
  )
}

#' Get the environment variable name for an LLM provider's API key
#'
#' @param provider Character. Provider name.
#' @return Character. Environment variable name, or NULL for providers without keys.
#' @noRd
get_llm_api_key_var <- function(provider) {
  key_map <- list(
    anthropic = "ANTHROPIC_API_KEY",
    mistral = "MISTRAL_API_KEY",
    openai = "OPENAI_API_KEY",
    google = "GOOGLE_API_KEY",
    deepseek = "DEEPSEEK_API_KEY"
  )
  key_map[[provider]]
}

#' Create a Leaflet choropleth map for an indicator column
#' @param sf_data An sf object with indicator data and geometries.
#' @param ind_col Character. Column name of the indicator to map.
#' @param title Character. Title for the legend.
#' @return A leaflet map object.
#' @noRd
make_indicator_leaflet <- function(sf_data, ind_col, title) {
  # Transform to WGS84 for Leaflet
  sf_wgs84 <- sf::st_transform(sf_data, 4326)

  vals <- sf_wgs84[[ind_col]]

  # Handle case where all values are NA
  if (all(is.na(vals))) {
    return(leaflet::leaflet(sf_wgs84) |>
      leaflet::addTiles() |>
      leaflet::addPolygons(color = "#999", weight = 1, fillOpacity = 0.3))
  }

  pal <- leaflet::colorNumeric("viridis", domain = vals, na.color = "#cccccc")

  # Build hover labels
  id_col <- intersect(c("nemeton_id", "id", "geo_parcelle"), names(sf_wgs84))
  ids <- if (length(id_col) > 0) sf_wgs84[[id_col[1]]] else seq_len(nrow(sf_wgs84))
  labels <- sprintf("<strong>%s</strong><br/>%s: %s",
                    ids, title, round(vals, 3)) |>
    lapply(htmltools::HTML)

  # Build layerId from parcel identifier
  layer_ids <- as.character(ids)

  leaflet::leaflet(sf_wgs84) |>
    leaflet::addTiles() |>
    leaflet::addPolygons(
      fillColor = ~pal(vals),
      weight = 1,
      color = "#333",
      fillOpacity = 0.7,
      layerId = layer_ids,
      highlightOptions = leaflet::highlightOptions(
        weight = 2, color = "#000", fillOpacity = 0.9, bringToFront = TRUE
      ),
      label = labels,
      labelOptions = leaflet::labelOptions(
        style = list("font-size" = "12px", "padding" = "4px 8px"),
        textsize = "12px",
        direction = "auto"
      )
    ) |>
    leaflet::addLegend(
      position = "bottomright",
      pal = pal,
      values = vals,
      title = title,
      opacity = 0.7
    )
}

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

  # Try matching long-form name against INDICATOR_FAMILIES config first
  # (maps column_names -> short codes -> i18n keys with richer labels)
  for (fam in INDICATOR_FAMILIES) {
    if (!is.null(fam$column_names) && base %in% fam$column_names) {
      idx <- which(fam$column_names == base)
      if (idx <= length(fam$indicators)) {
        short_key <- paste0("indicator_", fam$indicators[idx])
        if (i18n$has(short_key)) {
          return(i18n$t(short_key))
        }
      }
    }
  }

  # Try i18n key directly (works for short codes like C1, B2)
  key <- paste0("indicator_", base)
  if (i18n$has(key)) {
    return(i18n$t(key))
  }

  # Fallback: humanize the column name
  gsub("_", " ", base)
}
