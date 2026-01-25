#' Map Module for nemetonApp
#'
#' @description
#' Shiny module for displaying an interactive Leaflet map with cadastral parcels.
#' Supports parcel selection/deselection by click, basemap switching, and
#' enforces maximum selection limit.
#'
#' @name mod_map
#' @keywords internal
NULL


#' Map Module UI
#'
#' @param id Module namespace ID.
#'
#' @return Shiny UI elements.
#'
#' @noRd
mod_map_ui <- function(id) {
  ns <- shiny::NS(id)
  opts <- get_app_options()
  i18n <- get_i18n(opts$language)

  bslib::card(
    full_screen = TRUE,
    id = ns("map_card"),

    bslib::card_header(
      class = "d-flex justify-content-between align-items-center py-2",

      # Title
      htmltools::span(
        bsicons::bs_icon("map"),
        i18n$t("map_title"),
        class = "fw-semibold"
      ),

      # Controls
      htmltools::div(
        class = "d-flex gap-2 align-items-center",

        # Basemap toggle
        htmltools::div(
          class = "btn-group btn-group-sm",
          role = "group",
          `aria-label` = "Basemap selection",
          shiny::actionButton(
            ns("basemap_osm"),
            "OSM",
            class = "btn btn-outline-secondary active"
          ),
          shiny::actionButton(
            ns("basemap_satellite"),
            "Satellite",
            class = "btn btn-outline-secondary"
          )
        ),

        # Clear selection button
        shiny::actionButton(
          ns("clear_selection"),
          label = NULL,
          icon = bsicons::bs_icon("x-circle"),
          class = "btn btn-outline-danger btn-sm",
          title = i18n$t("clear_selection")
        )
      )
    ),

    bslib::card_body(
      padding = 0,
      class = "p-0",

      # Map container
      htmltools::div(
        id = ns("map_container"),
        style = "height: 100%; min-height: 500px;",

        # Leaflet output
        leaflet::leafletOutput(ns("map"), height = "100%")
      )
    ),

    bslib::card_footer(
      class = "py-2",

      # Selection summary
      shiny::uiOutput(ns("selection_summary"))
    )
  )
}


#' Map Module Server
#'
#' @param id Module namespace ID.
#' @param app_state Reactive values for app state.
#' @param commune_geometry Reactive sf object with commune boundary.
#' @param parcels Reactive sf object with cadastral parcels.
#'
#' @return List of reactive values:
#'   - selected_ids: Reactive character vector of selected parcel IDs
#'   - selected_parcels: Reactive sf object of selected parcels
#'   - selection_count: Reactive integer
#'
#' @noRd
mod_map_server <- function(id, app_state, commune_geometry, parcels) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # ========================================
    # Constants
    # ========================================

    MAX_PARCELS <- get_app_config("max_parcels", 20L)

    # Map styling
    STYLE <- list(
      # Commune boundary
      commune = list(
        color = "#1B6B1B",
        weight = 3,
        fill = FALSE,
        dashArray = "5, 5"
      ),
      # Unselected parcels
      parcel_default = list(
        color = "#666666",
        weight = 1,
        fillColor = "#CCCCCC",
        fillOpacity = 0.3
      ),
      # Selected parcels
      parcel_selected = list(
        color = "#1B6B1B",
        weight = 2,
        fillColor = "#1B6B1B",
        fillOpacity = 0.5
      ),
      # Hover state
      parcel_hover = list(
        weight = 2,
        fillOpacity = 0.4
      )
    )


    # ========================================
    # Reactive Values
    # ========================================

    rv <- shiny::reactiveValues(
      selected_ids = character(0),
      basemap = "osm"
    )


    # ========================================
    # Base Map Rendering
    # ========================================

    output$map <- leaflet::renderLeaflet({
      leaflet::leaflet() |>
        # Set default view (France)
        leaflet::setView(lng = 2.5, lat = 46.5, zoom = 6) |>
        # Add OSM tiles (default)
        leaflet::addProviderTiles(
          leaflet::providers$OpenStreetMap,
          group = "OSM",
          options = leaflet::providerTileOptions(
            updateWhenZooming = FALSE,
            updateWhenIdle = TRUE
          )
        ) |>
        # Add satellite tiles
        leaflet::addProviderTiles(
          leaflet::providers$Esri.WorldImagery,
          group = "Satellite",
          options = leaflet::providerTileOptions(
            updateWhenZooming = FALSE,
            updateWhenIdle = TRUE
          )
        ) |>
        # Layers control (hidden, controlled by buttons)
        leaflet::hideGroup("Satellite") |>
        # Scale bar
        leaflet::addScaleBar(
          position = "bottomleft",
          options = leaflet::scaleBarOptions(imperial = FALSE)
        ) |>
        # Attribution
        htmlwidgets::onRender("
          function(el, x) {
            // Add keyboard navigation for parcels
            el.addEventListener('keydown', function(e) {
              if (e.key === 'Enter' || e.key === ' ') {
                var target = e.target;
                if (target.classList.contains('leaflet-interactive')) {
                  target.click();
                }
              }
            });
          }
        ")
    })


    # ========================================
    # Basemap Toggle
    # ========================================

    shiny::observeEvent(input$basemap_osm, {
      rv$basemap <- "osm"

      leaflet::leafletProxy(ns("map")) |>
        leaflet::showGroup("OSM") |>
        leaflet::hideGroup("Satellite")

      # Update button states
      shiny::updateActionButton(session, "basemap_osm",
                                class = "btn btn-outline-secondary active")
      shiny::updateActionButton(session, "basemap_satellite",
                                class = "btn btn-outline-secondary")
    })

    shiny::observeEvent(input$basemap_satellite, {
      rv$basemap <- "satellite"

      leaflet::leafletProxy(ns("map")) |>
        leaflet::hideGroup("OSM") |>
        leaflet::showGroup("Satellite")

      # Update button states
      shiny::updateActionButton(session, "basemap_osm",
                                class = "btn btn-outline-secondary")
      shiny::updateActionButton(session, "basemap_satellite",
                                class = "btn btn-outline-secondary active")
    })


    # ========================================
    # Zoom to Commune
    # ========================================

    shiny::observe({
      geom <- commune_geometry()

      if (is.null(geom)) return()

      # Verify geometry is polygon type
      geom_types <- sf::st_geometry_type(geom)
      polygon_idx <- geom_types %in% c("POLYGON", "MULTIPOLYGON")
      if (sum(polygon_idx) == 0) {
        cli::cli_warn("Commune geometry is not a polygon, skipping display")
        return()
      }
      if (sum(!polygon_idx) > 0) {
        geom <- geom[polygon_idx, ]
      }

      # Get bounding box
      bbox <- sf::st_bbox(geom)

      leaflet::leafletProxy(ns("map")) |>
        # Clear previous commune boundary
        leaflet::clearGroup("commune") |>
        # Add new boundary
        leaflet::addPolygons(
          data = geom,
          group = "commune",
          color = STYLE$commune$color,
          weight = STYLE$commune$weight,
          fill = STYLE$commune$fill,
          dashArray = STYLE$commune$dashArray
        ) |>
        # Zoom to bounds
        leaflet::fitBounds(
          lng1 = bbox["xmin"],
          lat1 = bbox["ymin"],
          lng2 = bbox["xmax"],
          lat2 = bbox["ymax"]
        )
    })


    # ========================================
    # Display Parcels
    # ========================================

    shiny::observe({
      parcel_data <- parcels()

      if (is.null(parcel_data) || nrow(parcel_data) == 0) {
        leaflet::leafletProxy(ns("map")) |>
          leaflet::clearGroup("parcels")
        return()
      }

      # Filter to keep only polygon geometries (defensive check)
      geom_types <- sf::st_geometry_type(parcel_data)
      polygon_idx <- geom_types %in% c("POLYGON", "MULTIPOLYGON")
      if (sum(polygon_idx) == 0) {
        cli::cli_warn("No polygon geometries in parcel data")
        leaflet::leafletProxy(ns("map")) |>
          leaflet::clearGroup("parcels")
        return()
      }
      if (sum(!polygon_idx) > 0) {
        parcel_data <- parcel_data[polygon_idx, ]
      }

      # Ensure WGS84
      if (sf::st_crs(parcel_data)$epsg != 4326) {
        parcel_data <- sf::st_transform(parcel_data, 4326)
      }

      # Create popups
      popups <- sapply(seq_len(nrow(parcel_data)), function(i) {
        create_parcel_popup(parcel_data[i, ])
      })

      leaflet::leafletProxy(ns("map")) |>
        leaflet::clearGroup("parcels") |>
        leaflet::addPolygons(
          data = parcel_data,
          layerId = parcel_data$id,
          group = "parcels",
          color = STYLE$parcel_default$color,
          weight = STYLE$parcel_default$weight,
          fillColor = STYLE$parcel_default$fillColor,
          fillOpacity = STYLE$parcel_default$fillOpacity,
          popup = popups,
          highlightOptions = leaflet::highlightOptions(
            weight = STYLE$parcel_hover$weight,
            fillOpacity = STYLE$parcel_hover$fillOpacity,
            bringToFront = TRUE
          ),
          options = leaflet::pathOptions(
            className = "parcel-polygon"
          )
        )

      # Re-apply selection styling if needed
      if (length(rv$selected_ids) > 0) {
        update_parcel_styles(rv$selected_ids)
      }
    })


    # ========================================
    # Handle Parcel Click (Toggle Selection)
    # ========================================

    shiny::observeEvent(input$map_shape_click, {
      click <- input$map_shape_click

      if (is.null(click) || is.null(click$id)) return()

      parcel_id <- click$id
      i18n <- get_i18n(app_state$language)

      # Check if already selected
      if (parcel_id %in% rv$selected_ids) {
        # Deselect
        rv$selected_ids <- setdiff(rv$selected_ids, parcel_id)

        # Update styling
        update_parcel_style(parcel_id, selected = FALSE)

        # Announce to screen reader
        session$sendCustomMessage("announceSelection", list(
          action = "deselected",
          id = parcel_id,
          count = length(rv$selected_ids)
        ))

      } else {
        # Check limit
        if (length(rv$selected_ids) >= MAX_PARCELS) {
          shiny::showNotification(
            i18n$t("max_parcels_warning"),
            type = "warning"
          )
          return()
        }

        # Select
        rv$selected_ids <- c(rv$selected_ids, parcel_id)

        # Update styling
        update_parcel_style(parcel_id, selected = TRUE)

        # Announce
        session$sendCustomMessage("announceSelection", list(
          action = "selected",
          id = parcel_id,
          count = length(rv$selected_ids)
        ))
      }
    })


    # ========================================
    # Clear Selection
    # ========================================

    shiny::observeEvent(input$clear_selection, {
      if (length(rv$selected_ids) == 0) return()

      # Reset all parcel styles
      parcel_data <- parcels()
      if (!is.null(parcel_data) && nrow(parcel_data) > 0) {
        leaflet::leafletProxy(ns("map")) |>
          leaflet::removeShape(rv$selected_ids)

        # Re-add with default style
        for (pid in rv$selected_ids) {
          update_parcel_style(pid, selected = FALSE)
        }
      }

      rv$selected_ids <- character(0)

      shiny::showNotification(
        get_i18n(app_state$language)$t("selection_cleared"),
        type = "message"
      )
    })


    # ========================================
    # Update Parcel Style Helper
    # ========================================

    update_parcel_style <- function(parcel_id, selected) {
      parcel_data <- parcels()
      if (is.null(parcel_data)) return()

      parcel <- parcel_data[parcel_data$id == parcel_id, ]
      if (nrow(parcel) == 0) return()

      style <- if (selected) STYLE$parcel_selected else STYLE$parcel_default

      # Re-add polygon with updated style
      popup <- create_parcel_popup(parcel)

      leaflet::leafletProxy(ns("map")) |>
        leaflet::removeShape(parcel_id) |>
        leaflet::addPolygons(
          data = parcel,
          layerId = parcel_id,
          group = "parcels",
          color = style$color,
          weight = style$weight,
          fillColor = style$fillColor,
          fillOpacity = style$fillOpacity,
          popup = popup,
          highlightOptions = leaflet::highlightOptions(
            weight = STYLE$parcel_hover$weight,
            fillOpacity = STYLE$parcel_hover$fillOpacity,
            bringToFront = TRUE
          )
        )
    }

    update_parcel_styles <- function(selected_ids) {
      for (pid in selected_ids) {
        update_parcel_style(pid, selected = TRUE)
      }
    }


    # ========================================
    # Selection Summary
    # ========================================

    output$selection_summary <- shiny::renderUI({
      i18n <- get_i18n(app_state$language)
      n <- length(rv$selected_ids)

      parcel_data <- parcels()

      if (n == 0) {
        return(htmltools::div(
          class = "text-muted",
          bsicons::bs_icon("cursor-fill", class = "me-1"),
          i18n$t("click_to_select")
        ))
      }

      # Calculate total area
      if (!is.null(parcel_data)) {
        selected <- parcel_data[parcel_data$id %in% rv$selected_ids, ]
        stats <- calculate_parcel_stats(selected)
        area_text <- sprintf("%.2f ha", stats$total_area_ha)
      } else {
        area_text <- ""
      }

      at_limit <- n >= MAX_PARCELS

      htmltools::div(
        class = paste("d-flex justify-content-between align-items-center",
                      if (at_limit) "text-warning" else "text-success"),

        htmltools::span(
          bsicons::bs_icon(if (at_limit) "exclamation-triangle" else "check-circle",
                           class = "me-1"),
          sprintf("%d / %d %s", n, MAX_PARCELS, i18n$t("parcels_selected"))
        ),

        if (area_text != "") {
          htmltools::span(
            class = "text-muted",
            sprintf("| %s", area_text)
          )
        }
      )
    })


    # ========================================
    # Return Values
    # ========================================

    list(
      selected_ids = shiny::reactive(rv$selected_ids),
      selected_parcels = shiny::reactive({
        parcel_data <- parcels()
        if (is.null(parcel_data) || length(rv$selected_ids) == 0) {
          return(NULL)
        }
        filter_selected_parcels(parcel_data, rv$selected_ids)
      }),
      selection_count = shiny::reactive(length(rv$selected_ids))
    )
  })
}
