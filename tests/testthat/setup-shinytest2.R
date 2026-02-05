# shinytest2 Setup Configuration
# This file is automatically loaded before shinytest2 tests

# Helper function to create AppDriver for nemeton app
# This provides a consistent way to launch the app for integration tests
create_nemeton_app_driver <- function(name = "nemeton-test",
                                       language = "en",
                                       timeout = 30000,
                                       ...) {
  # Ensure shinytest2 is available
  if (!requireNamespace("shinytest2", quietly = TRUE)) {
    stop("shinytest2 is required for integration tests")
  }

  # Create app expression that properly initializes nemeton
  app_expr <- sprintf(
    'nemeton::run_app(language = "%s")',
    language
  )

  # Create AppDriver with sensible defaults for nemeton

  app <- shinytest2::AppDriver$new(
    app_dir = system.file("app", package = "nemeton"),
    name = name,
    timeout = timeout,
    load_timeout = timeout,
    # Use the run_app function
    variant = NULL,
    seed = 12345,
    shiny_args = list(
      launch.browser = FALSE
    ),
    options = list(
      shiny.testmode = TRUE
    ),
    ...
  )

  app
}


# Helper function to wait for element to be present
wait_for_element <- function(app, selector, timeout = 10000) {
  tryCatch({
    app$wait_for_js(
      sprintf(
        "document.querySelector('%s') !== null",
        selector
      ),
      timeout = timeout
    )
    TRUE
  }, error = function(e) {
    FALSE
  })
}


# Helper function to wait for shiny to be idle
wait_for_idle <- function(app, timeout = 10000) {
  tryCatch({
    app$wait_for_idle(timeout = timeout)
    TRUE
  }, error = function(e) {
    FALSE
  })
}


# Helper function to safely get input value
safe_get_value <- function(app, input_id) {
  tryCatch({
    app$get_value(input = input_id)
  }, error = function(e) {
    NULL
  })
}


# Helper function to safely click
safe_click <- function(app, selector) {
  tryCatch({
    app$click(selector = selector)
    TRUE
  }, error = function(e) {
    FALSE
  })
}
