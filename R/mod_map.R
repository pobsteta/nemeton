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
      basemap = "osm",
      parcels_zoomed = FALSE,  # Flag to zoom only once per commune
      pending_restore = NULL,  # Pending restoration data
      pending_zoom = NULL,     # Pending zoom bbox (to execute in Shiny context)
      pending_styles = NULL    # Pending style updates
    )


    # ========================================
    # Base Map Rendering
    # ========================================

    output$map <- leaflet::renderLeaflet({
      leaflet::leaflet() |>
        # Set default view (France)
        leaflet::setView(lng = 2.5, lat = 46.5, zoom = 6) |>
        # Add OSM tiles (default basemap)
        leaflet::addProviderTiles(
          leaflet::providers$OpenStreetMap,
          group = "basemap",
          layerId = "basemap_tiles",
          options = leaflet::providerTileOptions(
            updateWhenZooming = FALSE,
            updateWhenIdle = TRUE
          )
        ) |>
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
      cli::cli_alert_info("Switching to OSM basemap")

      leaflet::leafletProxy(ns("map")) |>
        leaflet::clearGroup("basemap") |>
        leaflet::addProviderTiles(
          leaflet::providers$OpenStreetMap,
          group = "basemap",
          layerId = "basemap_tiles"
        )
    })

    shiny::observeEvent(input$basemap_satellite, {
      rv$basemap <- "satellite"
      cli::cli_alert_info("Switching to Satellite basemap")

      leaflet::leafletProxy(ns("map")) |>
        leaflet::clearGroup("basemap") |>
        leaflet::addProviderTiles(
          leaflet::providers$Esri.WorldImagery,
          group = "basemap",
          layerId = "basemap_tiles"
        )
    })


    # ========================================
    # Zoom to Commune
    # ========================================

    shiny::observe({
      geom <- commune_geometry()

      if (is.null(geom)) return()

      # Reset parcels zoom flag for new commune
      rv$parcels_zoomed <- FALSE

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
          lng1 = as.numeric(bbox[["xmin"]]),
          lat1 = as.numeric(bbox[["ymin"]]),
          lng2 = as.numeric(bbox[["xmax"]]),
          lat2 = as.numeric(bbox[["ymax"]])
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

      # Create popups and labels
      popups <- sapply(seq_len(nrow(parcel_data)), function(i) {
        create_parcel_popup(parcel_data[i, ])
      })

      labels <- sapply(seq_len(nrow(parcel_data)), function(i) {
        create_parcel_label(parcel_data[i, ])
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
          label = lapply(labels, htmltools::HTML),
          labelOptions = leaflet::labelOptions(
            style = list(
              "font-size" = "12px",
              "font-weight" = "normal",
              "padding" = "4px 8px"
            ),
            direction = "top",
            offset = c(0, -10)
          ),
          highlightOptions = leaflet::highlightOptions(
            weight = STYLE$parcel_hover$weight,
            fillOpacity = STYLE$parcel_hover$fillOpacity,
            bringToFront = TRUE
          ),
          options = leaflet::pathOptions(
            className = "parcel-polygon"
          )
        )

      # Zoom to parcels extent only on first load (not on selection updates)
      # Skip if there's a pending restore - let the restore handle the zoom
      if (!rv$parcels_zoomed && is.null(rv$pending_restore)) {
        cli::cli_alert_info("Zooming to all parcels (no pending restore)")
        bbox <- sf::st_bbox(parcel_data)
        leaflet::leafletProxy(ns("map")) |>
          leaflet::fitBounds(
            lng1 = as.numeric(bbox[["xmin"]]),
            lat1 = as.numeric(bbox[["ymin"]]),
            lng2 = as.numeric(bbox[["xmax"]]),
            lat2 = as.numeric(bbox[["ymax"]])
          )
        rv$parcels_zoomed <- TRUE
      } else if (!is.null(rv$pending_restore)) {
        cli::cli_alert_info("Skipping zoom - pending restore exists")
      }

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
    # Restore Project Selection
    # ========================================

    # Capture restore request
    shiny::observeEvent(app_state$restore_project, {
      restore <- app_state$restore_project
      if (!is.null(restore) && !is.null(restore$selected_ids)) {
        rv$pending_restore <- restore
        cli::cli_alert_info("Restoration pending for {length(restore$selected_ids)} parcels")
      }
    }, ignoreInit = TRUE)

    # Apply restoration when parcels are loaded
    shiny::observe({
      restore <- rv$pending_restore
      if (is.null(restore)) return()

      parcel_data <- parcels()
      if (is.null(parcel_data) || nrow(parcel_data) == 0) return()

      # Find matching parcel IDs
      matching_ids <- intersect(restore$selected_ids, parcel_data$id)

      if (length(matching_ids) > 0) {
        cli::cli_alert_info("Found {length(matching_ids)} matching parcels to restore")

        # Set selected IDs
        rv$selected_ids <- matching_ids

        # Mark as zoomed to prevent "Display Parcels" from overriding
        rv$parcels_zoomed <- TRUE

        # Clear pending restore now to avoid race conditions
        rv$pending_restore <- NULL

        # Capture the bbox and store for delayed execution
        selected_parcels <- parcel_data[parcel_data$id %in% matching_ids, ]
        bbox <- sf::st_bbox(selected_parcels)

        # Store pending operations to be executed by the delayed observer
        rv$pending_styles <- matching_ids
        rv$pending_zoom <- list(
          xmin = as.numeric(bbox[["xmin"]]),
          ymin = as.numeric(bbox[["ymin"]]),
          xmax = as.numeric(bbox[["xmax"]]),
          ymax = as.numeric(bbox[["ymax"]])
        )

        cli::cli_alert_info("Bbox stored: xmin={rv$pending_zoom$xmin}, ymin={rv$pending_zoom$ymin}")
        cli::cli_alert_success("Restored {length(matching_ids)} selected parcels (zoom pending)")
      } else {
        cli::cli_alert_warning("No matching parcels found in current data")
        # No matching parcels, clear pending restore
        rv$pending_restore <- NULL
      }
    })

    # Delayed observer to apply zoom and styles (runs in Shiny context)
    shiny::observe({
      # Check if there are pending operations
      zoom <- rv$pending_zoom
      styles <- rv$pending_styles

      if (is.null(zoom) && is.null(styles)) return()

      # Use invalidateLater to delay execution
      shiny::invalidateLater(500)  # 500ms delay

      # Only execute once
      shiny::isolate({
        if (!is.null(styles)) {
          cli::cli_alert_info("Applying {length(styles)} style updates...")
          for (pid in styles) {
            update_parcel_style(pid, selected = TRUE)
          }
          rv$pending_styles <- NULL
        }

        if (!is.null(zoom)) {
          cli::cli_alert_info("Applying zoom to selected parcels...")
          leaflet::leafletProxy(ns("map")) |>
            leaflet::fitBounds(
              lng1 = zoom$xmin,
              lat1 = zoom$ymin,
              lng2 = zoom$xmax,
              lat2 = zoom$ymax
            )
          rv$pending_zoom <- NULL
          cli::cli_alert_success("Zoomed to selected parcels")
        }
      })
    })


    # ========================================
    # Update Parcel Style Helper
    # ========================================

    update_parcel_style <- function(parcel_id, selected) {
      parcel_data <- shiny::isolate(parcels())
      if (is.null(parcel_data)) return()

      parcel <- parcel_data[parcel_data$id == parcel_id, ]
      if (nrow(parcel) == 0) return()

      style <- if (selected) STYLE$parcel_selected else STYLE$parcel_default
      popup <- create_parcel_popup(parcel)
      label <- create_parcel_label(parcel)

      # Replace polygon with updated style (layerId ensures replacement)
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
          label = htmltools::HTML(label),
          labelOptions = leaflet::labelOptions(
            style = list(
              "font-size" = "12px",
              "font-weight" = "normal",
              "padding" = "4px 8px"
            ),
            direction = "top",
            offset = c(0, -10)
          ),
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
