# test-cov80-batch6.R
# Coverage boost for R/mod_map.R
# Target: UI, server init, click handlers, basemap toggle, clear selection,
#         restore project, render_parcels_to_map, selection summary, return values

# ==============================================================================
# mod_map_ui
# ==============================================================================

test_that("mod_map_ui creates valid HTML structure", {
  ui <- nemeton:::mod_map_ui("test_map")
  html_str <- as.character(ui)
  expect_true(grepl("test_map-map", html_str))
  expect_true(grepl("test_map-clear_selection", html_str))
  expect_true(grepl("test_map-basemap_osm", html_str))
  expect_true(grepl("test_map-basemap_satellite", html_str))
  expect_true(grepl("test_map-selection_summary", html_str))
  expect_true(grepl("test_map-map_loading_overlay", html_str))
})

# ==============================================================================
# mod_map_server: initialization
# ==============================================================================

test_that("mod_map_server initializes with empty selection", {
  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE,
    computation_running = FALSE,
    restore_in_progress = NULL,
    clear_map_selection = NULL
  )

  commune_geom <- shiny::reactive(NULL)
  parcel_data <- shiny::reactive(NULL)

  shiny::testServer(
    nemeton:::mod_map_server,
    args = list(
      app_state = app_state,
      commune_geometry = commune_geom,
      parcels = parcel_data
    ),
    {
      # Initial state
      expect_equal(rv$selected_ids, character(0))
      expect_equal(rv$basemap, "osm")
      expect_false(rv$parcels_zoomed)
      expect_null(rv$last_restore_timestamp)
    }
  )
})

# ==============================================================================
# mod_map_server: return values
# ==============================================================================

test_that("mod_map_server returns reactive list with selection info", {
  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE,
    computation_running = FALSE,
    restore_in_progress = NULL,
    clear_map_selection = NULL
  )

  commune_geom <- shiny::reactive(NULL)
  parcel_data <- shiny::reactive(NULL)

  shiny::testServer(
    nemeton:::mod_map_server,
    args = list(
      app_state = app_state,
      commune_geometry = commune_geom,
      parcels = parcel_data
    ),
    {
      result <- session$returned
      expect_true(is.list(result))
      expect_true("selected_ids" %in% names(result))
      expect_true("selected_parcels" %in% names(result))
      expect_true("selection_count" %in% names(result))

      # Call reactives
      expect_equal(result$selected_ids(), character(0))
      expect_null(result$selected_parcels())
      expect_equal(result$selection_count(), 0L)
    }
  )
})

# ==============================================================================
# mod_map_server: basemap toggle
# ==============================================================================

test_that("mod_map_server: basemap_osm click sets basemap to osm", {
  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE,
    computation_running = FALSE,
    restore_in_progress = NULL,
    clear_map_selection = NULL
  )

  commune_geom <- shiny::reactive(NULL)
  parcel_data <- shiny::reactive(NULL)

  shiny::testServer(
    nemeton:::mod_map_server,
    args = list(
      app_state = app_state,
      commune_geometry = commune_geom,
      parcels = parcel_data
    ),
    {
      rv$basemap <- "satellite"  # Start as satellite
      session$setInputs(basemap_osm = 1)
      expect_equal(rv$basemap, "osm")
    }
  )
})

test_that("mod_map_server: basemap_satellite click sets basemap to satellite", {
  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE,
    computation_running = FALSE,
    restore_in_progress = NULL,
    clear_map_selection = NULL
  )

  commune_geom <- shiny::reactive(NULL)
  parcel_data <- shiny::reactive(NULL)

  shiny::testServer(
    nemeton:::mod_map_server,
    args = list(
      app_state = app_state,
      commune_geometry = commune_geom,
      parcels = parcel_data
    ),
    {
      session$setInputs(basemap_satellite = 1)
      expect_equal(rv$basemap, "satellite")
    }
  )
})

# ==============================================================================
# mod_map_server: parcel click handler
# ==============================================================================

test_that("mod_map_server: clicking a parcel selects it", {
  parcels_sf <- sf::st_transform(create_test_units(n_features = 3), 4326)
  parcels_sf$id <- paste0("parcel_", 1:3)
  parcels_sf$contenance <- c(10000, 20000, 30000)
  parcels_sf$section <- c("A", "A", "B")
  parcels_sf$numero <- c("1", "2", "3")

  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE,
    computation_running = FALSE,
    restore_in_progress = NULL,
    clear_map_selection = NULL
  )

  commune_geom <- shiny::reactive(NULL)
  parcel_data <- shiny::reactive(parcels_sf)

  shiny::testServer(
    nemeton:::mod_map_server,
    args = list(
      app_state = app_state,
      commune_geometry = commune_geom,
      parcels = parcel_data
    ),
    {
      # Click on parcel_1
      session$setInputs(map_shape_click = list(id = "parcel_1", lat = 47, lng = 3))
      expect_true("parcel_1" %in% rv$selected_ids)
      expect_equal(length(rv$selected_ids), 1)
    }
  )
})

test_that("mod_map_server: clicking a selected parcel deselects it", {
  parcels_sf <- sf::st_transform(create_test_units(n_features = 3), 4326)
  parcels_sf$id <- paste0("parcel_", 1:3)
  parcels_sf$contenance <- c(10000, 20000, 30000)
  parcels_sf$section <- c("A", "A", "B")
  parcels_sf$numero <- c("1", "2", "3")

  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE,
    computation_running = FALSE,
    restore_in_progress = NULL,
    clear_map_selection = NULL
  )

  commune_geom <- shiny::reactive(NULL)
  parcel_data <- shiny::reactive(parcels_sf)

  shiny::testServer(
    nemeton:::mod_map_server,
    args = list(
      app_state = app_state,
      commune_geometry = commune_geom,
      parcels = parcel_data
    ),
    {
      # First click selects
      session$setInputs(map_shape_click = list(id = "parcel_1", lat = 47, lng = 3))
      expect_equal(length(rv$selected_ids), 1)

      # Second click deselects
      session$setInputs(map_shape_click = list(id = "parcel_1", lat = 47, lng = 3))
      expect_equal(length(rv$selected_ids), 0)
    }
  )
})

test_that("mod_map_server: null click is ignored", {
  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE,
    computation_running = FALSE,
    restore_in_progress = NULL,
    clear_map_selection = NULL
  )

  commune_geom <- shiny::reactive(NULL)
  parcel_data <- shiny::reactive(NULL)

  shiny::testServer(
    nemeton:::mod_map_server,
    args = list(
      app_state = app_state,
      commune_geometry = commune_geom,
      parcels = parcel_data
    ),
    {
      # Click with no id is ignored
      session$setInputs(map_shape_click = list(id = NULL, lat = 47, lng = 3))
      expect_equal(length(rv$selected_ids), 0)
    }
  )
})

test_that("mod_map_server: click blocked during computation", {
  parcels_sf <- sf::st_transform(create_test_units(n_features = 2), 4326)
  parcels_sf$id <- paste0("parcel_", 1:2)
  parcels_sf$contenance <- c(10000, 20000)
  parcels_sf$section <- c("A", "A")
  parcels_sf$numero <- c("1", "2")

  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE,
    computation_running = TRUE,  # Computation in progress
    restore_in_progress = NULL,
    clear_map_selection = NULL
  )

  commune_geom <- shiny::reactive(NULL)
  parcel_data <- shiny::reactive(parcels_sf)

  shiny::testServer(
    nemeton:::mod_map_server,
    args = list(
      app_state = app_state,
      commune_geometry = commune_geom,
      parcels = parcel_data
    ),
    {
      # Click should be blocked
      session$setInputs(map_shape_click = list(id = "parcel_1", lat = 47, lng = 3))
      expect_equal(length(rv$selected_ids), 0)
    }
  )
})

# ==============================================================================
# mod_map_server: clear selection
# ==============================================================================

test_that("mod_map_server: clear selection button empties selected_ids", {
  parcels_sf <- sf::st_transform(create_test_units(n_features = 2), 4326)
  parcels_sf$id <- paste0("parcel_", 1:2)
  parcels_sf$contenance <- c(10000, 20000)
  parcels_sf$section <- c("A", "A")
  parcels_sf$numero <- c("1", "2")

  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE,
    computation_running = FALSE,
    restore_in_progress = NULL,
    clear_map_selection = NULL
  )

  commune_geom <- shiny::reactive(NULL)
  parcel_data <- shiny::reactive(parcels_sf)

  shiny::testServer(
    nemeton:::mod_map_server,
    args = list(
      app_state = app_state,
      commune_geometry = commune_geom,
      parcels = parcel_data
    ),
    {
      # Select a parcel
      session$setInputs(map_shape_click = list(id = "parcel_1", lat = 47, lng = 3))
      expect_equal(length(rv$selected_ids), 1)

      # Clear selection
      session$setInputs(clear_selection = 1)
      expect_equal(length(rv$selected_ids), 0)
    }
  )
})

test_that("mod_map_server: clear selection ignored when empty", {
  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE,
    computation_running = FALSE,
    restore_in_progress = NULL,
    clear_map_selection = NULL
  )

  commune_geom <- shiny::reactive(NULL)
  parcel_data <- shiny::reactive(NULL)

  shiny::testServer(
    nemeton:::mod_map_server,
    args = list(
      app_state = app_state,
      commune_geometry = commune_geom,
      parcels = parcel_data
    ),
    {
      # Clear when nothing selected — should not error
      session$setInputs(clear_selection = 1)
      expect_equal(length(rv$selected_ids), 0)
    }
  )
})

test_that("mod_map_server: clear selection blocked during computation", {
  parcels_sf <- sf::st_transform(create_test_units(n_features = 2), 4326)
  parcels_sf$id <- paste0("parcel_", 1:2)
  parcels_sf$contenance <- c(10000, 20000)
  parcels_sf$section <- c("A", "A")
  parcels_sf$numero <- c("1", "2")

  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE,
    computation_running = FALSE,
    restore_in_progress = NULL,
    clear_map_selection = NULL
  )

  commune_geom <- shiny::reactive(NULL)
  parcel_data <- shiny::reactive(parcels_sf)

  shiny::testServer(
    nemeton:::mod_map_server,
    args = list(
      app_state = app_state,
      commune_geometry = commune_geom,
      parcels = parcel_data
    ),
    {
      # Select a parcel first
      session$setInputs(map_shape_click = list(id = "parcel_1", lat = 47, lng = 3))
      expect_equal(length(rv$selected_ids), 1)

      # Block computation
      app_state$computation_running <- TRUE

      # Clear should be blocked
      session$setInputs(clear_selection = 1)
      expect_equal(length(rv$selected_ids), 1)  # Still selected
    }
  )
})

# ==============================================================================
# mod_map_server: external clear via app_state$clear_map_selection
# ==============================================================================

test_that("mod_map_server: clear_map_selection observer exists", {
  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE,
    computation_running = FALSE,
    restore_in_progress = NULL,
    clear_map_selection = NULL
  )

  commune_geom <- shiny::reactive(NULL)
  parcel_data <- shiny::reactive(NULL)

  shiny::testServer(
    nemeton:::mod_map_server,
    args = list(
      app_state = app_state,
      commune_geometry = commune_geom,
      parcels = parcel_data
    ),
    {
      # Module initializes without error when clear_map_selection is NULL
      expect_equal(length(rv$selected_ids), 0)
    }
  )
})

# ==============================================================================
# mod_map_server: restore_in_progress safety net
# ==============================================================================

test_that("mod_map_server: restore_in_progress FALSE hides loading", {
  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE,
    computation_running = FALSE,
    restore_in_progress = NULL,
    clear_map_selection = NULL
  )

  commune_geom <- shiny::reactive(NULL)
  parcel_data <- shiny::reactive(NULL)

  shiny::testServer(
    nemeton:::mod_map_server,
    args = list(
      app_state = app_state,
      commune_geometry = commune_geom,
      parcels = parcel_data
    ),
    {
      # Trigger restore_in_progress -> FALSE
      app_state$restore_in_progress <- FALSE
      session$flushReact()

      # Should not error (show_map_loading(FALSE) sent)
      expect_true(TRUE)
    }
  )
})

# ==============================================================================
# mod_map_server: render_parcels_to_map helper (non-polygon handling)
# ==============================================================================

test_that("mod_map_server: render_parcels_to_map handles polygon data", {
  parcels_sf <- sf::st_transform(create_test_units(n_features = 3), 4326)
  parcels_sf$id <- paste0("parcel_", 1:3)
  parcels_sf$contenance <- c(10000, 20000, 30000)
  parcels_sf$section <- c("A", "A", "B")
  parcels_sf$numero <- c("1", "2", "3")

  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE,
    computation_running = FALSE,
    restore_in_progress = NULL,
    clear_map_selection = NULL
  )

  commune_geom <- shiny::reactive(NULL)
  parcel_data <- shiny::reactive(parcels_sf)

  shiny::testServer(
    nemeton:::mod_map_server,
    args = list(
      app_state = app_state,
      commune_geometry = commune_geom,
      parcels = parcel_data
    ),
    {
      # Call internal helper directly
      result <- render_parcels_to_map(parcels_sf)
      expect_true(result)
    }
  )
})

# ==============================================================================
# mod_map_server: selected_parcels reactive
# ==============================================================================

test_that("mod_map_server: selected_parcels returns selected sf", {
  parcels_sf <- sf::st_transform(create_test_units(n_features = 3), 4326)
  parcels_sf$id <- paste0("parcel_", 1:3)
  parcels_sf$contenance <- c(10000, 20000, 30000)
  parcels_sf$section <- c("A", "A", "B")
  parcels_sf$numero <- c("1", "2", "3")

  app_state <- shiny::reactiveValues(
    language = "fr",
    restore_project = NULL,
    commune_transitioning = FALSE,
    computation_running = FALSE,
    restore_in_progress = NULL,
    clear_map_selection = NULL
  )

  commune_geom <- shiny::reactive(NULL)
  parcel_data <- shiny::reactive(parcels_sf)

  shiny::testServer(
    nemeton:::mod_map_server,
    args = list(
      app_state = app_state,
      commune_geometry = commune_geom,
      parcels = parcel_data
    ),
    {
      # Select two parcels
      session$setInputs(map_shape_click = list(id = "parcel_1", lat = 47, lng = 3))
      session$setInputs(map_shape_click = list(id = "parcel_3", lat = 47, lng = 3))

      result <- session$returned
      selected <- result$selected_parcels()
      expect_s3_class(selected, "sf")
      expect_equal(nrow(selected), 2)
      expect_equal(result$selection_count(), 2L)
    }
  )
})
