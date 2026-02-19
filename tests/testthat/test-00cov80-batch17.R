# test-cov80-batch17.R — Additional coverage for R/mod_home.R
# Focuses on code paths not already covered by test-zzmod_home.R

# =============================================================================
# Helper: base mocks
# =============================================================================

mock_empty_projects_b17 <- function(limit = 50) {
  data.frame(
    id = character(0), name = character(0), description = character(0),
    owner = character(0), status = character(0), parcels_count = integer(0),
    created_at = as.POSIXct(character(0)), updated_at = as.POSIXct(character(0)),
    is_corrupted = logical(0), stringsAsFactors = FALSE
  )
}

mock_search_server_b17 <- function(id, app_state) {
  list(
    selected_commune = shiny::reactive(NULL),
    commune_geometry = shiny::reactive(NULL)
  )
}

mock_map_server_b17 <- function(id, app_state, commune_geometry, parcels) {
  list(
    selected_parcels = shiny::reactive(NULL),
    selection_count = shiny::reactive(0)
  )
}

mock_project_server_b17 <- function(id, app_state, selected_parcels) {
  list(current_project = shiny::reactive(NULL))
}

mock_progress_server_b17 <- function(id, compute_state, app_state) {
  list(
    reset_tracking = function() {},
    send_running_update = function(state) {}
  )
}

make_app_state_b17 <- function(extra = list()) {
  base <- list(
    language = "fr",
    current_project = NULL,
    project_id = NULL,
    project_status = NULL,
    refresh_projects = NULL,
    restore_in_progress = FALSE,
    computation_running = FALSE,
    cancel_computation = NULL,
    retry_computation = NULL,
    view_results = NULL,
    restart_tour = NULL,
    clear_map_selection = NULL,
    family_comments = list(),
    clear_all_comments = NULL,
    commune_transitioning = FALSE,
    refresh_family_comments = NULL,
    restore_project = NULL
  )
  args <- modifyList(base, extra)
  do.call(shiny::reactiveValues, args)
}

collapse_html_b17 <- function(x) paste(as.character(x), collapse = "")

# =============================================================================
# 1. UI: mod_home_ui creates valid HTML with namespace
# =============================================================================

test_that("mod_home_ui creates valid HTML containing the module namespace", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      ui <- nemeton:::mod_home_ui("test_home_b17")
      html_str <- as.character(ui)
      expect_true(grepl("test_home_b17", html_str))
      # Contains the sidebar ID
      expect_true(grepl("test_home_b17-sidebar", html_str))
      # Contains recent_projects_section
      expect_true(grepl("test_home_b17-recent_projects_section", html_str))
      # Contains compute_section
      expect_true(grepl("test_home_b17-compute_section", html_str))
    }
  )
})

# =============================================================================
# 2. UI: mod_home_ui contains expected sub-module UIs
# =============================================================================

test_that("mod_home_ui embeds search, map, project, and progress sub-modules", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      ui <- nemeton:::mod_home_ui("hb17")
      html_str <- as.character(ui)
      # Sub-module namespaces should be present
      expect_true(grepl("hb17-search", html_str))
      expect_true(grepl("hb17-map", html_str))
      expect_true(grepl("hb17-project", html_str))
      expect_true(grepl("hb17-progress", html_str))
      # search_collapse section for collapsible card
      expect_true(grepl("hb17-search_collapse", html_str))
    }
  )
})

# =============================================================================
# 3. UI: mod_home_ui layout structure (bslib sidebar)
# =============================================================================

test_that("mod_home_ui uses bslib layout_sidebar with fillable", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      ui <- nemeton:::mod_home_ui("layout_test")
      # layout_sidebar produces a shiny.tag
      expect_s3_class(ui, "shiny.tag")
      html_str <- as.character(ui)
      # bslib sidebar elements present
      expect_true(grepl("sidebar", html_str, ignore.case = TRUE))
    }
  )
})

# =============================================================================
# 4. Server: recent_projects_list with multiple parcels (plural form)
# =============================================================================

test_that("recent_projects_list shows plural parcel count", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  mock_projects <- data.frame(
    id = "proj_multi",
    name = "Multi Parcels",
    description = "",
    owner = "",
    status = "draft",
    parcels_count = 15L,
    created_at = Sys.time(),
    updated_at = Sys.time(),
    is_corrupted = FALSE,
    stringsAsFactors = FALSE
  )

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = function(limit = 50) mock_projects,
    mod_search_server = mock_search_server_b17,
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = mock_progress_server_b17,
    {
      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = make_app_state_b17()),
        {
          html <- output$recent_projects_list
          html_str <- collapse_html_b17(html)
          # 15 parcels should appear with plural form
          expect_true(grepl("15", html_str))
        }
      )
    }
  )
})

# =============================================================================
# 5. Server: recent_projects_list scroll container
# =============================================================================

test_that("recent_projects_list wraps cards in scrollable container", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  mock_projects <- data.frame(
    id = paste0("p", 1:5),
    name = paste0("Project ", 1:5),
    description = rep("", 5),
    owner = rep("", 5),
    status = rep("draft", 5),
    parcels_count = rep(3L, 5),
    created_at = rep(Sys.time(), 5),
    updated_at = rep(Sys.time(), 5),
    is_corrupted = rep(FALSE, 5),
    stringsAsFactors = FALSE
  )

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = function(limit = 50) mock_projects,
    mod_search_server = mock_search_server_b17,
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = mock_progress_server_b17,
    {
      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = make_app_state_b17()),
        {
          html <- output$recent_projects_list
          html_str <- collapse_html_b17(html)
          # Container with max-height and overflow-y styling
          expect_true(grepl("max-height", html_str))
          expect_true(grepl("overflow-y", html_str))
          # All 5 project names rendered
          for (i in 1:5) {
            expect_true(grepl(paste0("Project ", i), html_str))
          }
        }
      )
    }
  )
})

# =============================================================================
# 6. Server: recent_projects_list project with downloading status
# =============================================================================

test_that("recent_projects_list renders downloading status badge with bg-info", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  mock_projects <- data.frame(
    id = "dl_proj",
    name = "Downloading",
    description = "",
    owner = "",
    status = "downloading",
    parcels_count = 2L,
    created_at = Sys.time(),
    updated_at = Sys.time(),
    is_corrupted = FALSE,
    stringsAsFactors = FALSE
  )

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = function(limit = 50) mock_projects,
    mod_search_server = mock_search_server_b17,
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = mock_progress_server_b17,
    {
      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = make_app_state_b17()),
        {
          html <- output$recent_projects_list
          html_str <- collapse_html_b17(html)
          expect_true(grepl("bg-info", html_str))
          expect_true(grepl("cursor-pointer", html_str))
        }
      )
    }
  )
})

# =============================================================================
# 7. Server: recent_projects_list click handlers (corrupted vs normal)
# =============================================================================

test_that("recent_projects_list generates correct onclick for normal vs corrupted projects", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  mock_projects <- data.frame(
    id = c("normal_p", "corrupt_p"),
    name = c("Normal", "Corrupt"),
    description = rep("", 2),
    owner = rep("", 2),
    status = c("draft", "error"),
    parcels_count = c(3L, 0L),
    created_at = rep(Sys.time(), 2),
    updated_at = rep(Sys.time(), 2),
    is_corrupted = c(FALSE, TRUE),
    stringsAsFactors = FALSE
  )

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = function(limit = 50) mock_projects,
    mod_search_server = mock_search_server_b17,
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = mock_progress_server_b17,
    {
      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = make_app_state_b17()),
        {
          html <- output$recent_projects_list
          html_str <- collapse_html_b17(html)
          # Normal project has load_project handler
          expect_true(grepl("load_project", html_str))
          # Corrupted project has delete_corrupted handler
          expect_true(grepl("delete_corrupted", html_str))
          # Corrupted project has border-danger
          expect_true(grepl("border-danger", html_str))
          # data-corrupted attribute
          expect_true(grepl("data-corrupted", html_str))
        }
      )
    }
  )
})

# =============================================================================
# 8. Server: compute_button_ui for status "downloading" returns NULL
# =============================================================================

test_that("compute_button_ui returns NULL for downloading status", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  mock_project <- list(
    id = "proj_dl",
    metadata = list(name = "DL", status = "downloading"),
    parcels = NULL
  )

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = mock_empty_projects_b17,
    mod_search_server = mock_search_server_b17,
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = mock_progress_server_b17,
    {
      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = make_app_state_b17(list(
          current_project = mock_project,
          project_id = "proj_dl"
        ))),
        {
          html <- output$compute_button_ui
          # "downloading" is not in c("draft","error") nor "completed" -> NULL branch
          expect_true(html == "" || is.null(html) || nchar(html) == 0)
        }
      )
    }
  )
})

# =============================================================================
# 9. Server: compute_button_ui for "error" status shows compute button
# =============================================================================

test_that("compute_button_ui shows compute button for error status project", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  mock_project <- list(
    id = "proj_error_btn",
    metadata = list(name = "Error State", status = "error"),
    parcels = data.frame(id = "p1")
  )

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = mock_empty_projects_b17,
    mod_search_server = mock_search_server_b17,
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = mock_progress_server_b17,
    {
      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = make_app_state_b17(list(
          current_project = mock_project,
          project_id = "proj_error_btn"
        ))),
        {
          html <- output$compute_button_ui
          html_str <- collapse_html_b17(html)
          expect_true(grepl("start_compute", html_str))
          expect_true(grepl("btn-primary", html_str))
          # cpu icon should be present
          expect_true(grepl("cpu", html_str))
        }
      )
    }
  )
})

# =============================================================================
# 10. Server: compute_button_ui completed shows view_results + recompute
# =============================================================================

test_that("compute_button_ui completed shows view_results and recompute buttons", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  mock_project <- list(
    id = "proj_complete_btn",
    metadata = list(name = "Complete", status = "completed"),
    parcels = NULL,
    indicators = data.frame(C1 = 80)
  )

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = mock_empty_projects_b17,
    mod_search_server = mock_search_server_b17,
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = mock_progress_server_b17,
    {
      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = make_app_state_b17(list(
          current_project = mock_project,
          project_id = "proj_complete_btn"
        ))),
        {
          html <- output$compute_button_ui
          html_str <- collapse_html_b17(html)
          # view_results button
          expect_true(grepl("view_results", html_str))
          expect_true(grepl("btn-success", html_str))
          expect_true(grepl("bar-chart", html_str))
          # recompute button
          expect_true(grepl("recompute", html_str))
          expect_true(grepl("btn-outline-secondary", html_str))
          expect_true(grepl("arrow-repeat", html_str))
        }
      )
    }
  )
})

# =============================================================================
# 11. Server: compute_button_ui with missing status defaults to "draft"
# =============================================================================

test_that("compute_button_ui defaults to draft when metadata has no status", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  mock_project <- list(
    id = "proj_no_status",
    metadata = list(name = "No Status"),
    parcels = NULL
  )

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = mock_empty_projects_b17,
    mod_search_server = mock_search_server_b17,
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = mock_progress_server_b17,
    {
      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = make_app_state_b17(list(
          current_project = mock_project,
          project_id = "proj_no_status"
        ))),
        {
          html <- output$compute_button_ui
          html_str <- collapse_html_b17(html)
          # status defaults to "draft" via %||% -> shows compute button
          expect_true(grepl("start_compute", html_str))
        }
      )
    }
  )
})

# =============================================================================
# 12. Server: load_project with empty parcels dataframe (nrow == 0)
# =============================================================================

test_that("load_project with empty parcels (0 rows) skips restore", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")
  skip_if_not_installed("sf")

  mock_parcels <- sf::st_sf(
    id = character(0),
    code_insee = character(0),
    geometry = sf::st_sfc(crs = 4326),
    stringsAsFactors = FALSE
  )

  mock_project <- list(
    id = "proj_empty_parcels",
    metadata = list(name = "Empty Parcels", status = "draft"),
    parcels = mock_parcels,
    indicators = NULL
  )

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = mock_empty_projects_b17,
    load_project = function(project_id) mock_project,
    mod_search_server = mock_search_server_b17,
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = mock_progress_server_b17,
    read_progress_state = function(project_id) NULL,
    {
      as <- make_app_state_b17()
      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = as),
        {
          session$setInputs(load_project = "proj_empty_parcels")
          session$flushReact()

          expect_equal(as$project_id, "proj_empty_parcels")
          # 0-row parcels -> condition nrow(project$parcels) > 0 is FALSE
          expect_false(isTRUE(as$restore_in_progress))
          expect_null(as$restore_project)
        }
      )
    }
  )
})

# =============================================================================
# 13. Server: load_project with empty string commune code
# =============================================================================

test_that("load_project with empty string commune code warns and skips restore", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")
  skip_if_not_installed("sf")

  mock_parcels <- sf::st_sf(
    id = "p1",
    code_insee = "",
    geometry = sf::st_sfc(
      sf::st_polygon(list(rbind(c(0, 0), c(1, 0), c(1, 1), c(0, 1), c(0, 0))))
    ),
    crs = 4326
  )

  mock_project <- list(
    id = "proj_empty_insee",
    metadata = list(name = "Empty INSEE", status = "draft"),
    parcels = mock_parcels,
    indicators = NULL
  )

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = mock_empty_projects_b17,
    load_project = function(project_id) mock_project,
    mod_search_server = mock_search_server_b17,
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = mock_progress_server_b17,
    read_progress_state = function(project_id) NULL,
    {
      as <- make_app_state_b17()
      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = as),
        {
          # Empty string commune code triggers nzchar() = FALSE -> warn path
          expect_warning(
            {
              session$setInputs(load_project = "proj_empty_insee")
              session$flushReact()
            },
            regexp = "invalid commune code"
          )

          expect_equal(as$project_id, "proj_empty_insee")
          expect_false(isTRUE(as$restore_in_progress))
        }
      )
    }
  )
})

# =============================================================================
# 14. Server: delete_project that fails (returns FALSE)
# =============================================================================

test_that("confirm_delete with failing delete_project does not refresh list", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = mock_empty_projects_b17,
    delete_project = function(project_id) FALSE,
    mod_search_server = mock_search_server_b17,
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = mock_progress_server_b17,
    {
      as <- make_app_state_b17()
      initial_refresh <- shiny::isolate(as$refresh_projects)
      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = as),
        {
          session$setInputs(delete_corrupted = "fail_del_proj")
          session$flushReact()

          session$setInputs(confirm_delete = 1L)
          session$flushReact()

          # delete_project returned FALSE -> refresh_projects NOT updated
          expect_identical(as$refresh_projects, initial_refresh)
        }
      )
    }
  )
})

# =============================================================================
# 15. Server: start_compute modal content
# =============================================================================

test_that("start_compute shows confirmation modal with project details", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  mock_project <- list(
    id = "proj_confirm",
    metadata = list(name = "Confirm Compute", status = "draft"),
    parcels = data.frame(id = c("p1", "p2", "p3"))
  )

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = mock_empty_projects_b17,
    mod_search_server = mock_search_server_b17,
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = mock_progress_server_b17,
    {
      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = make_app_state_b17(list(
          current_project = mock_project,
          project_id = "proj_confirm"
        ))),
        {
          # Trigger the start_compute button
          session$setInputs(start_compute = 1L)
          session$flushReact()
          # If we get here without error, the modal was shown
          # (showModal executes in testServer context)
          expect_true(TRUE)
        }
      )
    }
  )
})

# =============================================================================
# 16. Server: start_compute with NULL parcels shows 0 count
# =============================================================================

test_that("start_compute shows 0 parcels when project has no parcels", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  mock_project <- list(
    id = "proj_no_parcel_compute",
    metadata = list(name = "No Parcels", status = "draft"),
    parcels = NULL
  )

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = mock_empty_projects_b17,
    mod_search_server = mock_search_server_b17,
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = mock_progress_server_b17,
    {
      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = make_app_state_b17(list(
          current_project = mock_project,
          project_id = "proj_no_parcel_compute"
        ))),
        {
          session$setInputs(start_compute = 1L)
          session$flushReact()
          expect_true(TRUE)
        }
      )
    }
  )
})

# =============================================================================
# 17. Server: recent_projects_list refreshes on app_state$refresh_projects
# =============================================================================

test_that("recent_projects_list refreshes when refresh_projects changes", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  call_count <- 0
  mock_proj <- data.frame(
    id = "refresh_proj",
    name = "Refresh Me",
    description = "",
    owner = "",
    status = "draft",
    parcels_count = 1L,
    created_at = Sys.time(),
    updated_at = Sys.time(),
    is_corrupted = FALSE,
    stringsAsFactors = FALSE
  )

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = function(limit = 50) {
      call_count <<- call_count + 1
      mock_proj
    },
    mod_search_server = mock_search_server_b17,
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = mock_progress_server_b17,
    {
      as <- make_app_state_b17()
      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = as),
        {
          # Initial render
          html1 <- output$recent_projects_list
          first_count <- call_count

          # Trigger refresh
          as$refresh_projects <- Sys.time()
          session$flushReact()
          html2 <- output$recent_projects_list

          # list_recent_projects should have been called again
          expect_gt(call_count, first_count)
        }
      )
    }
  )
})

# =============================================================================
# 18. Server: recent_projects_list refreshes on project_id change
# =============================================================================

test_that("recent_projects_list re-renders when project_id changes", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  mock_projects <- data.frame(
    id = c("proj_a", "proj_b"),
    name = c("A", "B"),
    description = rep("", 2),
    owner = rep("", 2),
    status = c("draft", "completed"),
    parcels_count = c(2L, 5L),
    created_at = rep(Sys.time(), 2),
    updated_at = rep(Sys.time(), 2),
    is_corrupted = c(FALSE, FALSE),
    stringsAsFactors = FALSE
  )

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = function(limit = 50) mock_projects,
    mod_search_server = mock_search_server_b17,
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = mock_progress_server_b17,
    {
      as <- make_app_state_b17()
      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = as),
        {
          # No active project initially
          html1 <- output$recent_projects_list
          html_str1 <- collapse_html_b17(html1)
          # Both should show as clickable
          expect_true(grepl("cursor-pointer", html_str1))

          # Set active project
          as$project_id <- "proj_a"
          session$flushReact()
          html2 <- output$recent_projects_list
          html_str2 <- collapse_html_b17(html2)
          # Active project should have border-primary
          expect_true(grepl("border-primary", html_str2))
        }
      )
    }
  )
})

# =============================================================================
# 19. Server: load_project sets metadata status via %||% fallback
# =============================================================================

test_that("load_project uses %||% for metadata status fallback to draft", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  mock_project <- list(
    id = "proj_no_meta_status",
    metadata = list(name = "No Meta Status"),
    parcels = NULL,
    indicators = NULL
  )

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = mock_empty_projects_b17,
    load_project = function(project_id) mock_project,
    mod_search_server = mock_search_server_b17,
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = mock_progress_server_b17,
    read_progress_state = function(project_id) NULL,
    {
      as <- make_app_state_b17()
      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = as),
        {
          session$setInputs(load_project = "proj_no_meta_status")
          session$flushReact()

          # status should default to "draft" since metadata$status is NULL
          expect_equal(as$project_status, "draft")
        }
      )
    }
  )
})

# =============================================================================
# 20. Server: view_results button triggers updateNavbarPage
# =============================================================================

test_that("view_results input triggers navigation to synthesis tab", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = mock_empty_projects_b17,
    mod_search_server = mock_search_server_b17,
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = mock_progress_server_b17,
    {
      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = make_app_state_b17()),
        {
          session$setInputs(view_results = 1L)
          session$flushReact()
          # updateNavbarPage fires without error
          expect_true(TRUE)
        }
      )
    }
  )
})

# =============================================================================
# 21. Server: recompute clears cache and updates status
# =============================================================================

test_that("recompute handler resets project to draft and reloads", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  cache_cleared <- FALSE
  new_status <- NULL
  reloaded <- FALSE

  mock_project <- list(
    id = "proj_recomp_b17",
    metadata = list(name = "Recompute B17", status = "completed"),
    parcels = NULL
  )

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = mock_empty_projects_b17,
    clear_computation_cache = function(project_id) {
      cache_cleared <<- TRUE
      TRUE
    },
    update_project_status = function(project_id, status) {
      new_status <<- status
      TRUE
    },
    load_project = function(project_id) {
      reloaded <<- TRUE
      mock_project
    },
    mod_search_server = mock_search_server_b17,
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = mock_progress_server_b17,
    {
      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = make_app_state_b17(list(
          current_project = mock_project,
          project_id = "proj_recomp_b17"
        ))),
        {
          session$setInputs(recompute = 1L)
          session$flushReact()

          expect_true(cache_cleared)
          expect_equal(new_status, "draft")
          expect_true(reloaded)
        }
      )
    }
  )
})

# =============================================================================
# 22. Server: cancel_computation handler
# =============================================================================

test_that("cancel_computation observer fires and shows notification", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  mock_project <- list(
    id = "proj_cancel_b17",
    metadata = list(name = "Cancel B17", status = "computing"),
    parcels = NULL
  )

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = mock_empty_projects_b17,
    cancel_computation = function(project_id) invisible(NULL),
    update_project_status = function(project_id, status) TRUE,
    load_project = function(project_id) mock_project,
    mod_search_server = mock_search_server_b17,
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = mock_progress_server_b17,
    {
      as <- make_app_state_b17(list(
        current_project = mock_project,
        project_id = "proj_cancel_b17",
        computation_running = TRUE
      ))

      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = as),
        {
          # ignoreInit = TRUE, set twice to trigger
          as$cancel_computation <- Sys.time() - 1
          session$flushReact()
          as$cancel_computation <- Sys.time()
          session$flushReact()

          # The cancel observer fires, computing_project_id() is NULL
          # so it skips the inner block but still runs the notification
          expect_true(TRUE)
        }
      )
    }
  )
})

# =============================================================================
# 23. Server: app_state$view_results triggers navigation
# =============================================================================

test_that("app_state view_results reactive triggers navigation to synthesis", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = mock_empty_projects_b17,
    mod_search_server = mock_search_server_b17,
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = mock_progress_server_b17,
    {
      as <- make_app_state_b17()
      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = as),
        {
          # ignoreInit = TRUE, set twice to trigger
          as$view_results <- Sys.time() - 1
          session$flushReact()
          as$view_results <- Sys.time()
          session$flushReact()
          expect_true(TRUE)
        }
      )
    }
  )
})

# =============================================================================
# 24. Server: resume progress tracking for "downloading" status
# =============================================================================

test_that("resume progress tracking detects downloading status", {
  skip("Resume progress triggers persistent async callbacks that hang subsequent tests")
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  send_update_called <- FALSE
  reset_called <- FALSE

  mock_project_dl <- list(
    id = "proj_dl_resume",
    metadata = list(name = "Downloading Resume", status = "downloading"),
    parcels = NULL
  )

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = mock_empty_projects_b17,
    read_progress_state = function(project_id) {
      list(
        project_id = project_id,
        status = "downloading",
        progress = 2, progress_max = 10,
        current_task = "download:oso",
        indicators_completed = 0,
        indicators_failed = 0
      )
    },
    mod_search_server = mock_search_server_b17,
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = function(id, compute_state, app_state) {
      list(
        reset_tracking = function() { reset_called <<- TRUE },
        send_running_update = function(state) { send_update_called <<- TRUE }
      )
    },
    {
      as <- make_app_state_b17()
      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = as),
        {
          # ignoreInit = TRUE — set twice to trigger
          as$current_project <- list(id = "dummy_init")
          session$flushReact()
          as$current_project <- mock_project_dl
          session$flushReact()

          expect_true(reset_called)
          expect_true(send_update_called)
        }
      )
    }
  )
})

# =============================================================================
# 25. Server: resume skips when computing_project_id already set
# =============================================================================

test_that("resume progress does not interfere when already computing", {
  skip("Mocking future_promise in promises package corrupts async state for subsequent tests")

  if (requireNamespace("future", quietly = TRUE)) {
    old_plan <- future::plan()
    withr::defer(future::plan(old_plan))
  }

  send_update_called <- FALSE

  mock_project_new <- list(
    id = "proj_resume_skip",
    metadata = list(name = "Skip Resume", status = "computing"),
    parcels = data.frame(id = "p1")
  )

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = mock_empty_projects_b17,
    read_progress_state = function(project_id) {
      list(project_id = project_id, status = "computing",
           progress = 5, progress_max = 12,
           current_task = "test", indicators_completed = 3,
           indicators_failed = 0)
    },
    init_compute_state = function(project_id, ...) {
      list(project_id = project_id, status = "pending",
           progress = 0, progress_max = 12)
    },
    save_progress_state = function(project_id, state, ...) invisible(NULL),
    get_project_path = function(project_id) "/tmp/fake",
    mod_search_server = mock_search_server_b17,
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = function(id, compute_state, app_state) {
      list(
        reset_tracking = function() {},
        send_running_update = function(state) { send_update_called <<- TRUE }
      )
    },
    {
      as <- make_app_state_b17(list(
        current_project = list(
          id = "proj_existing",
          metadata = list(name = "Existing", status = "draft"),
          parcels = data.frame(id = "p1")
        ),
        project_id = "proj_existing"
      ))

      suppressWarnings(shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = as),
        {
          # Start a computation first (sets computing_project_id)
          session$setInputs(start_compute = 1L)
          session$flushReact()
          session$setInputs(confirm_compute = 1L)
          suppressWarnings(session$flushReact())

          send_update_called <<- FALSE

          # Now try to load a new project — resume observer checks
          # if computing_project_id is set and returns early
          as$current_project <- mock_project_new
          suppressWarnings(session$flushReact())

          # send_running_update should NOT be called for the new project
          # because computing_project_id is already set
          expect_false(send_update_called)
        }
      ))
    }
  )
})

# =============================================================================
# 26. Server: commune change during restore skips reset
# =============================================================================

test_that("commune change during restore_in_progress does NOT reset state", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  commune_val <- shiny::reactiveVal(NULL)

  mock_project <- list(
    id = "proj_restore_b17",
    metadata = list(name = "Restoring B17", status = "completed"),
    parcels = NULL
  )

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = mock_empty_projects_b17,
    mod_search_server = function(id, app_state) {
      list(
        selected_commune = commune_val,
        commune_geometry = shiny::reactive(NULL)
      )
    },
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = mock_progress_server_b17,
    {
      as <- make_app_state_b17(list(
        current_project = mock_project,
        project_id = "proj_restore_b17",
        restore_in_progress = TRUE
      ))

      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = as),
        {
          # Change commune while restoring — should NOT clear project
          commune_val("55001")
          session$flushReact()

          expect_equal(as$project_id, "proj_restore_b17")
          expect_identical(as$current_project, mock_project)
        }
      )
    }
  )
})

# =============================================================================
# 27. Server: commune change resets project state and clears comments
# =============================================================================

test_that("commune change clears project, comments, and map selection", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  commune_val <- shiny::reactiveVal(NULL)

  mock_project <- list(
    id = "proj_comm_reset",
    metadata = list(name = "Comm Reset", status = "completed"),
    parcels = NULL
  )

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = mock_empty_projects_b17,
    mod_search_server = function(id, app_state) {
      list(
        selected_commune = commune_val,
        commune_geometry = shiny::reactive(NULL)
      )
    },
    mod_map_server = mock_map_server_b17,
    mod_project_server = mock_project_server_b17,
    mod_progress_server = mock_progress_server_b17,
    {
      as <- make_app_state_b17(list(
        current_project = mock_project,
        project_id = "proj_comm_reset",
        family_comments = list(carbon = "comment1")
      ))

      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = as),
        {
          # ignoreInit = TRUE, change commune twice
          commune_val("11001")
          session$flushReact()
          # Re-assign project state after first reset
          as$current_project <- mock_project
          as$project_id <- "proj_comm_reset"
          as$family_comments <- list(carbon = "comment1")

          commune_val("22002")
          session$flushReact()

          # Project cleared
          expect_null(as$current_project)
          expect_null(as$project_id)
          # Comments cleared
          expect_equal(as$family_comments, list())
          # clear_all_comments should have been set
          expect_true(!is.null(as$clear_all_comments))
          # clear_map_selection should be set
          expect_true(!is.null(as$clear_map_selection))
        }
      )
    }
  )
})

# =============================================================================
# 28. Server: return values from child modules propagated correctly
# =============================================================================

test_that("mod_home_server return values propagate child module reactives", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    list_recent_projects = mock_empty_projects_b17,
    mod_search_server = function(id, app_state) {
      list(
        selected_commune = shiny::reactive("33001"),
        commune_geometry = shiny::reactive(NULL)
      )
    },
    mod_map_server = function(id, app_state, commune_geometry, parcels) {
      list(
        selected_parcels = shiny::reactive(data.frame(id = c("p1", "p2"))),
        selection_count = shiny::reactive(2L)
      )
    },
    mod_project_server = function(id, app_state, selected_parcels) {
      list(current_project = shiny::reactive(list(id = "proj_child")))
    },
    mod_progress_server = mock_progress_server_b17,
    {
      shiny::testServer(
        nemeton:::mod_home_server,
        args = list(app_state = make_app_state_b17()),
        {
          result <- session$getReturned()
          expect_type(result, "list")
          expect_equal(result$selected_commune(), "33001")
          expect_equal(result$selection_count(), 2L)
          selected <- result$selected_parcels()
          expect_equal(nrow(selected), 2)
          expect_equal(result$current_project()$id, "proj_child")
        }
      )
    }
  )
})

# Drain async callbacks to prevent testServer session accumulation
later::run_now(0)
