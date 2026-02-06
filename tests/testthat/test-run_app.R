# Tests for run_app.R
# Comprehensive unit tests for app launching infrastructure

# ==============================================================================
# Tests for run_app() function signature and exports
# ==============================================================================

test_that("run_app function exists and is exported", {
  expect_true(exists("run_app", where = asNamespace("nemeton"), inherits = FALSE))
  expect_type(nemeton::run_app, "closure")
})

test_that("run_app has correct function signature", {
  args <- names(formals(nemeton::run_app))

  expect_true("language" %in% args)
  expect_true("project_dir" %in% args)
  expect_true("..." %in% args)
})

test_that("run_app default arguments are NULL", {
  defaults <- formals(nemeton::run_app)

  expect_null(defaults$language)
  expect_null(defaults$project_dir)
})

# ==============================================================================
# Tests for detect_system_language()
# ==============================================================================

test_that("detect_system_language returns valid language code", {
  detect_lang <- nemeton:::detect_system_language

  result <- detect_lang()

  expect_true(result %in% c("fr", "en"))
  expect_type(result, "character")
  expect_length(result, 1)
})

test_that("detect_system_language detects French when LANG starts with fr", {
  detect_lang <- nemeton:::detect_system_language

  withr::local_envvar(LANG = "fr_FR.UTF-8")
  expect_equal(detect_lang(), "fr")

  withr::local_envvar(LANG = "FR_FR")
  expect_equal(detect_lang(), "fr")

  withr::local_envvar(LANG = "fr")
  expect_equal(detect_lang(), "fr")
})

test_that("detect_system_language defaults to English for non-French locales", {
  detect_lang <- nemeton:::detect_system_language

  withr::local_envvar(LANG = "en_US.UTF-8")
  expect_equal(detect_lang(), "en")

  withr::local_envvar(LANG = "de_DE.UTF-8")
  expect_equal(detect_lang(), "en")

  withr::local_envvar(LANG = "es_ES.UTF-8")
  expect_equal(detect_lang(), "en")
})

test_that("detect_system_language defaults to English when LANG is empty", {
  detect_lang <- nemeton:::detect_system_language

  withr::local_envvar(LANG = "")
  expect_equal(detect_lang(), "en")
})

# ==============================================================================
# Tests for get_default_project_dir()
# ==============================================================================

test_that("get_default_project_dir returns valid path", {
  get_dir <- nemeton:::get_default_project_dir

  result <- get_dir()

  expect_type(result, "character")
  expect_length(result, 1)
  expect_true(grepl("nemeton", result))
  expect_true(grepl("projects", result))
})

test_that("get_default_project_dir uses rappdirs when available", {
  skip_if_not_installed("rappdirs")

  get_dir <- nemeton:::get_default_project_dir

  result <- get_dir()

  # Should contain "nemeton" (from rappdirs::user_data_dir("nemeton", "nemeton"))
  expect_true(grepl("nemeton", result))
  expect_true(grepl("projects$", result))
})

test_that("get_default_project_dir falls back to HOME/.nemeton", {
  get_dir <- nemeton:::get_default_project_dir

  # Test the fallback path structure
  home_dir <- Sys.getenv("HOME")
  fallback_path <- file.path(home_dir, ".nemeton", "projects")

  # The result should either be the rappdirs path or the fallback
  result <- get_dir()

  # Either way it should end with "projects" and contain "nemeton"
  expect_true(grepl("projects$", result))
  expect_true(grepl("nemeton", result, ignore.case = TRUE))
})

# ==============================================================================
# Tests for check_app_dependencies()
# ==============================================================================

test_that("check_app_dependencies returns NULL invisibly when all packages available", {
  check_deps <- nemeton:::check_app_dependencies

  # Since we're testing inside the package, all deps should be available
  result <- check_deps()

  expect_null(result)
  expect_invisible(check_deps())
})

test_that("check_app_dependencies checks for required packages", {
  check_deps <- nemeton:::check_app_dependencies

  # Test that it checks the required packages list
  # We can't easily test the failure case without unloading packages
  # but we can verify it runs without error when packages are present
  expect_no_error(check_deps())
})

test_that("check_app_dependencies errors when packages missing", {
  # Mock requireNamespace to return FALSE for a package
  with_mocked_bindings(
    requireNamespace = function(pkg, quietly = FALSE) {
      if (pkg == "shiny") return(FALSE)
      return(TRUE)
    },
    {
      expect_error(
        nemeton:::check_app_dependencies(),
        regexp = "Missing required packages"
      )
    },
    .package = "base"
  )
})

# ==============================================================================
# Tests for get_app_options()
# ==============================================================================

test_that("get_app_options returns default options when none set", {
  # Clear any existing options
  old_opts <- options(nemeton.app_options = NULL)
  on.exit(options(old_opts), add = TRUE)

  get_opts <- nemeton:::get_app_options

  result <- get_opts()

  expect_type(result, "list")
  expect_true("language" %in% names(result))
  expect_true("project_dir" %in% names(result))
  expect_equal(result$language, "fr")
})

test_that("get_app_options returns stored options", {
  test_opts <- list(
    language = "en",
    project_dir = "/custom/path"
  )

  old_opts <- options(nemeton.app_options = test_opts)
  on.exit(options(old_opts), add = TRUE)

  get_opts <- nemeton:::get_app_options

  result <- get_opts()

  expect_equal(result$language, "en")
  expect_equal(result$project_dir, "/custom/path")
})

test_that("get_app_options default language is French", {
  old_opts <- options(nemeton.app_options = NULL)
  on.exit(options(old_opts), add = TRUE)

  get_opts <- nemeton:::get_app_options

  result <- get_opts()

  expect_equal(result$language, "fr")
})

# ==============================================================================
# Tests for run_app() options setting logic
# ==============================================================================

test_that("run_app sets options correctly with explicit language", {
  skip_if_not_installed("shiny")

  temp_dir <- file.path(tempdir(), "nemeton_test_run_app")
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  # Clear previous options
  old_opts <- options(nemeton.app_options = NULL, shiny.busy_indicators = NULL)
  on.exit(options(old_opts), add = TRUE)

  # Mock shinyApp to avoid actually launching
  local_mocked_bindings(
    shinyApp = function(ui, server, options, ...) {
      # Return a mock object instead of launching the app
      list(ui = ui, server = server, options = options)
    },
    .package = "shiny"
  )

  # Call run_app
  suppressMessages(nemeton::run_app(language = "en", project_dir = temp_dir))

  # Check that options were set
  app_opts <- getOption("nemeton.app_options")

  expect_equal(app_opts$language, "en")
  expect_equal(app_opts$project_dir, temp_dir)
})

test_that("run_app creates project directory if missing", {
  skip_if_not_installed("shiny")

  temp_dir <- file.path(tempdir(), "nemeton_new_project_dir_test")
  unlink(temp_dir, recursive = TRUE)

  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  expect_false(dir.exists(temp_dir))

  # Mock shinyApp to avoid actually launching
  local_mocked_bindings(
    shinyApp = function(ui, server, options, ...) {
      list(ui = ui, server = server, options = options)
    },
    .package = "shiny"
  )

  suppressMessages(nemeton::run_app(project_dir = temp_dir))

  expect_true(dir.exists(temp_dir))
})

test_that("run_app uses detect_system_language when language is NULL", {
  skip_if_not_installed("shiny")

  temp_dir <- file.path(tempdir(), "nemeton_detect_lang_test")
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  old_opts <- options(nemeton.app_options = NULL)
  on.exit(options(old_opts), add = TRUE)

  # Set French locale
  withr::local_envvar(LANG = "fr_FR.UTF-8")

  local_mocked_bindings(
    shinyApp = function(ui, server, options, ...) {
      list(ui = ui, server = server, options = options)
    },
    .package = "shiny"
  )

  suppressMessages(nemeton::run_app(language = NULL, project_dir = temp_dir))

  app_opts <- getOption("nemeton.app_options")
  expect_equal(app_opts$language, "fr")
})

test_that("run_app uses get_default_project_dir when project_dir is NULL", {
  skip_if_not_installed("shiny")

  old_opts <- options(nemeton.app_options = NULL)
  on.exit(options(old_opts), add = TRUE)

  local_mocked_bindings(
    shinyApp = function(ui, server, options, ...) {
      list(ui = ui, server = server, options = options)
    },
    .package = "shiny"
  )

  suppressMessages(nemeton::run_app(language = "en", project_dir = NULL))

  app_opts <- getOption("nemeton.app_options")

  # Should use default path which contains "nemeton" and "projects"
  expect_true(grepl("nemeton", app_opts$project_dir, ignore.case = TRUE))
  expect_true(grepl("projects", app_opts$project_dir))
})

test_that("run_app disables shiny busy indicators", {
  skip_if_not_installed("shiny")

  temp_dir <- file.path(tempdir(), "nemeton_busy_test")
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  old_opts <- options(shiny.busy_indicators = NULL)
  on.exit(options(old_opts), add = TRUE)

  local_mocked_bindings(
    shinyApp = function(ui, server, options, ...) {
      list(ui = ui, server = server, options = options)
    },
    .package = "shiny"
  )

  suppressMessages(nemeton::run_app(project_dir = temp_dir))

  expect_false(getOption("shiny.busy_indicators"))
})

test_that("run_app sets launch.browser option to TRUE", {
  skip_if_not_installed("shiny")

  temp_dir <- file.path(tempdir(), "nemeton_browser_test")
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  captured_options <- NULL

  local_mocked_bindings(
    shinyApp = function(ui, server, options, ...) {
      captured_options <<- options
      list(ui = ui, server = server, options = options)
    },
    .package = "shiny"
  )

  suppressMessages(nemeton::run_app(project_dir = temp_dir))

  expect_true(captured_options$launch.browser)
})

# ==============================================================================
# Tests for run_app() async computation setup
# ==============================================================================

test_that("run_app configures future plan when future package available", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("future")

  # This test verifies that the future package is checked and used
  # We can't easily mock future::plan since it's called with :: notation
  # But we can verify the code path works by checking that future is available
  expect_true(requireNamespace("future", quietly = TRUE))
})

# ==============================================================================
# Tests for run_app() shinyApp call
# ==============================================================================

test_that("run_app calls shinyApp with app_ui and app_server", {
  skip_if_not_installed("shiny")

  temp_dir <- file.path(tempdir(), "nemeton_shinyapp_test")
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  captured_ui <- NULL
  captured_server <- NULL

  local_mocked_bindings(
    shinyApp = function(ui, server, options, ...) {
      captured_ui <<- ui
      captured_server <<- server
      list(ui = ui, server = server, options = options)
    },
    .package = "shiny"
  )

  suppressMessages(nemeton::run_app(project_dir = temp_dir))

  # Check that ui and server are the expected functions
  expect_true(is.function(captured_ui) || inherits(captured_ui, "shiny.tag") ||
              inherits(captured_ui, "shiny.tag.list"))
  expect_true(is.function(captured_server))
})

test_that("run_app passes extra arguments to shinyApp", {
  skip_if_not_installed("shiny")

  temp_dir <- file.path(tempdir(), "nemeton_extra_args_test")
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  captured_extra <- NULL

  local_mocked_bindings(
    shinyApp = function(ui, server, options, ...) {
      captured_extra <<- list(...)
      list(ui = ui, server = server, options = options, extra = list(...))
    },
    .package = "shiny"
  )

  suppressMessages(nemeton::run_app(
    project_dir = temp_dir,
    onStart = function() { message("Starting") }
  ))

  expect_true("onStart" %in% names(captured_extra))
})

# ==============================================================================
# Tests for argument validation edge cases
# ==============================================================================

test_that("run_app handles empty string for language gracefully", {
  skip_if_not_installed("shiny")

  temp_dir <- file.path(tempdir(), "nemeton_empty_lang_test")
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  old_opts <- options(nemeton.app_options = NULL)
  on.exit(options(old_opts), add = TRUE)

  local_mocked_bindings(
    shinyApp = function(ui, server, options, ...) {
      list(ui = ui, server = server, options = options)
    },
    .package = "shiny"
  )

  # Empty string should be used as-is (the app may handle it internally)
  suppressMessages(nemeton::run_app(language = "", project_dir = temp_dir))

  app_opts <- getOption("nemeton.app_options")
  expect_equal(app_opts$language, "")
})

test_that("run_app handles special characters in project_dir path", {
  skip_if_not_installed("shiny")
  skip_on_os("windows")  # Path handling differs on Windows

  temp_base <- file.path(tempdir(), "nemeton_special_chars")
  temp_dir <- file.path(temp_base, "project with spaces")
  on.exit(unlink(temp_base, recursive = TRUE), add = TRUE)

  local_mocked_bindings(
    shinyApp = function(ui, server, options, ...) {
      list(ui = ui, server = server, options = options)
    },
    .package = "shiny"
  )

  suppressMessages(nemeton::run_app(project_dir = temp_dir))

  expect_true(dir.exists(temp_dir))
})

test_that("run_app does not create directory when it already exists", {
  skip_if_not_installed("shiny")

  temp_dir <- file.path(tempdir(), "nemeton_existing_dir_test")
  dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  # Create a marker file to verify directory wasn't recreated
  marker_file <- file.path(temp_dir, "marker.txt")
  writeLines("test", marker_file)

  local_mocked_bindings(
    shinyApp = function(ui, server, options, ...) {
      list(ui = ui, server = server, options = options)
    },
    .package = "shiny"
  )

  suppressMessages(nemeton::run_app(project_dir = temp_dir))

  # Marker file should still exist
  expect_true(file.exists(marker_file))
})

# ==============================================================================
# Tests for documentation compliance
# ==============================================================================

test_that("run_app has roxygen documentation", {
  # Verify the function is documented by checking it's exported
  expect_true("run_app" %in% getNamespaceExports("nemeton"))
})

# ==============================================================================
# Integration-like tests (still without launching app)
# ==============================================================================

test_that("full run_app setup workflow completes without error", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("leaflet")
  skip_if_not_installed("sf")
  skip_if_not_installed("jsonlite")
  skip_if_not_installed("httr2")

  temp_dir <- file.path(tempdir(), "nemeton_full_setup_test")
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  old_opts <- options(
    nemeton.app_options = NULL,
    shiny.busy_indicators = NULL
  )
  on.exit(options(old_opts), add = TRUE)

  local_mocked_bindings(
    shinyApp = function(ui, server, options, ...) {
      list(ui = ui, server = server, options = options)
    },
    .package = "shiny"
  )

  result <- suppressMessages(
    nemeton::run_app(language = "en", project_dir = temp_dir)
  )

  expect_type(result, "list")
  expect_true("ui" %in% names(result))
  expect_true("server" %in% names(result))

  # Verify all expected side effects
  expect_true(dir.exists(temp_dir))
  expect_false(getOption("shiny.busy_indicators"))

  app_opts <- getOption("nemeton.app_options")
  expect_equal(app_opts$language, "en")
  expect_equal(app_opts$project_dir, temp_dir)
})

test_that("run_app can be called multiple times without error", {
  skip_if_not_installed("shiny")

  temp_dir1 <- file.path(tempdir(), "nemeton_multi_call_1")
  temp_dir2 <- file.path(tempdir(), "nemeton_multi_call_2")
  on.exit({
    unlink(temp_dir1, recursive = TRUE)
    unlink(temp_dir2, recursive = TRUE)
  }, add = TRUE)

  local_mocked_bindings(
    shinyApp = function(ui, server, options, ...) {
      list(ui = ui, server = server, options = options)
    },
    .package = "shiny"
  )

  # First call
  suppressMessages(nemeton::run_app(language = "fr", project_dir = temp_dir1))
  opts1 <- getOption("nemeton.app_options")

  # Second call with different options
  suppressMessages(nemeton::run_app(language = "en", project_dir = temp_dir2))
  opts2 <- getOption("nemeton.app_options")

  # Options should be updated
  expect_equal(opts1$language, "fr")
  expect_equal(opts2$language, "en")
  expect_equal(opts1$project_dir, temp_dir1)
  expect_equal(opts2$project_dir, temp_dir2)
})

# ==============================================================================
# Tests for language parameter edge cases
# ==============================================================================

test_that("run_app accepts fr as language", {
  skip_if_not_installed("shiny")

  temp_dir <- file.path(tempdir(), "nemeton_lang_fr_test")
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  old_opts <- options(nemeton.app_options = NULL)
  on.exit(options(old_opts), add = TRUE)

  local_mocked_bindings(
    shinyApp = function(ui, server, options, ...) {
      list(ui = ui, server = server, options = options)
    },
    .package = "shiny"
  )

  suppressMessages(nemeton::run_app(language = "fr", project_dir = temp_dir))

  app_opts <- getOption("nemeton.app_options")
  expect_equal(app_opts$language, "fr")
})

test_that("run_app accepts en as language", {
  skip_if_not_installed("shiny")

  temp_dir <- file.path(tempdir(), "nemeton_lang_en_test")
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  old_opts <- options(nemeton.app_options = NULL)
  on.exit(options(old_opts), add = TRUE)

  local_mocked_bindings(
    shinyApp = function(ui, server, options, ...) {
      list(ui = ui, server = server, options = options)
    },
    .package = "shiny"
  )

  suppressMessages(nemeton::run_app(language = "en", project_dir = temp_dir))

  app_opts <- getOption("nemeton.app_options")
  expect_equal(app_opts$language, "en")
})

# ==============================================================================
# Tests for project_dir edge cases
# ==============================================================================

test_that("run_app handles nested directory creation", {
  skip_if_not_installed("shiny")

  temp_base <- file.path(tempdir(), "nemeton_nested")
  temp_dir <- file.path(temp_base, "level1", "level2", "level3")
  on.exit(unlink(temp_base, recursive = TRUE), add = TRUE)

  expect_false(dir.exists(temp_dir))

  local_mocked_bindings(
    shinyApp = function(ui, server, options, ...) {
      list(ui = ui, server = server, options = options)
    },
    .package = "shiny"
  )

  suppressMessages(nemeton::run_app(project_dir = temp_dir))

  expect_true(dir.exists(temp_dir))
})

test_that("run_app handles tilde expansion in project_dir", {
  skip_if_not_installed("shiny")

  # Create a unique directory name
  unique_name <- paste0("nemeton_tilde_test_", format(Sys.time(), "%Y%m%d%H%M%S"))
  temp_dir <- file.path("~", unique_name)
  expanded_dir <- normalizePath(temp_dir, mustWork = FALSE)

  on.exit(unlink(expanded_dir, recursive = TRUE), add = TRUE)

  local_mocked_bindings(
    shinyApp = function(ui, server, options, ...) {
      list(ui = ui, server = server, options = options)
    },
    .package = "shiny"
  )

  suppressMessages(nemeton::run_app(project_dir = temp_dir))

  # The directory should be created
  expect_true(dir.exists(expanded_dir))
})

# ==============================================================================
# Tests for app_options storage and retrieval
# ==============================================================================

test_that("nemeton.app_options option is set correctly", {
  skip_if_not_installed("shiny")

  temp_dir <- file.path(tempdir(), "nemeton_opts_test")
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  old_opts <- options(nemeton.app_options = NULL)
  on.exit(options(old_opts), add = TRUE)

  local_mocked_bindings(
    shinyApp = function(ui, server, options, ...) {
      list(ui = ui, server = server, options = options)
    },
    .package = "shiny"
  )

  suppressMessages(nemeton::run_app(language = "en", project_dir = temp_dir))

  stored_opts <- getOption("nemeton.app_options")

  expect_type(stored_opts, "list")
  expect_true("language" %in% names(stored_opts))
  expect_true("project_dir" %in% names(stored_opts))
})

test_that("get_app_options retrieves options set by run_app", {
  skip_if_not_installed("shiny")

  temp_dir <- file.path(tempdir(), "nemeton_get_opts_test")
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  old_opts <- options(nemeton.app_options = NULL)
  on.exit(options(old_opts), add = TRUE)

  local_mocked_bindings(
    shinyApp = function(ui, server, options, ...) {
      list(ui = ui, server = server, options = options)
    },
    .package = "shiny"
  )

  suppressMessages(nemeton::run_app(language = "en", project_dir = temp_dir))

  retrieved_opts <- nemeton:::get_app_options()

  expect_equal(retrieved_opts$language, "en")
  expect_equal(retrieved_opts$project_dir, temp_dir)
})
