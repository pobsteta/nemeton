# test-cov80-batch2.R
# Coverage boost for R/service_export.R — PDF generation, maps, tables
# Target: generate_simple_pdf_report, draw_standard_cover_page, draw_indicator_map_page,
#         draw_parcel_table, add_parcel_labels, generate_family_maps, generate_radar_image,
#         generate_indicator_map, is_quarto_installed, export_geopackage, prepare_report_data

# Helper: create minimal project and family_scores for report tests
create_test_report_data <- function() {
  units <- create_test_units(n_features = 3)
  # Add family columns (12 families)
  family_codes <- c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")
  for (code in family_codes) {
    units[[paste0("family_", code)]] <- runif(3, 20, 90)
  }
  # Add some indicator columns
  units$C1 <- runif(3, 0, 100)
  units$C2 <- runif(3, 0, 100)
  units$B1 <- runif(3, 0, 100)

  project <- list(
    metadata = list(
      name = "Test Project",
      description = "A test project for coverage",
      owner = "Tester",
      created_at = "2025-01-01"
    )
  )
  list(project = project, family_scores = units)
}

# ==============================================================================
# is_quarto_installed() — failure paths
# ==============================================================================

test_that("is_quarto_installed returns FALSE when quarto package missing", {
  local_mocked_bindings(
    requireNamespace = function(pkg, ...) FALSE,
    .package = "base"
  )
  result <- nemeton:::is_quarto_installed()
  expect_false(result)
})

test_that("is_quarto_installed returns FALSE when CLI not found", {
  local_mocked_bindings(
    requireNamespace = function(pkg, ...) TRUE,
    .package = "base"
  )
  local_mocked_bindings(
    Sys.which = function(...) c(quarto = ""),
    .package = "base"
  )
  result <- nemeton:::is_quarto_installed()
  expect_false(result)
})

test_that("is_quarto_installed returns FALSE when system2 fails", {
  local_mocked_bindings(
    requireNamespace = function(pkg, ...) TRUE,
    .package = "base"
  )
  local_mocked_bindings(
    Sys.which = function(...) c(quarto = "/usr/bin/quarto"),
    .package = "base"
  )
  local_mocked_bindings(
    system2 = function(...) stop("simulated error"),
    .package = "base"
  )
  result <- nemeton:::is_quarto_installed()
  expect_false(result)
})

# ==============================================================================
# prepare_report_data()
# ==============================================================================

test_that("prepare_report_data returns complete structure", {
  td <- create_test_report_data()
  result <- nemeton:::prepare_report_data(
    td$project, td$family_scores, "fr"
  )
  expect_type(result, "list")
  expect_equal(result$project_name, "Test Project")
  expect_true(is.numeric(result$global_score))
  expect_true(result$n_parcels == 3)
  expect_type(result$family_stats, "list")
  expect_type(result$labels, "list")
  expect_equal(result$language, "fr")
})

test_that("prepare_report_data works in English", {
  td <- create_test_report_data()
  result <- nemeton:::prepare_report_data(
    td$project, td$family_scores, "en"
  )
  expect_equal(result$language, "en")
  expect_true(grepl("Forest", result$labels$title))
})

test_that("prepare_report_data includes synthesis_comments", {
  td <- create_test_report_data()
  result <- nemeton:::prepare_report_data(
    td$project, td$family_scores, "fr",
    synthesis_comments = "Test comment"
  )
  expect_equal(result$synthesis_comments, "Test comment")
})

test_that("prepare_report_data includes family_comments", {
  td <- create_test_report_data()
  comments <- list(C = "Carbon comment", B = "Biodiversity comment")
  result <- nemeton:::prepare_report_data(
    td$project, td$family_scores, "fr",
    family_comments = comments
  )
  expect_equal(result$family_comments$C, "Carbon comment")
})

test_that("prepare_report_data creates default family_comments when NULL", {
  td <- create_test_report_data()
  result <- nemeton:::prepare_report_data(
    td$project, td$family_scores, "fr"
  )
  expect_true(all(names(nemeton:::INDICATOR_FAMILIES) %in% names(result$family_comments)))
})

test_that("prepare_report_data handles non-sf family_scores", {
  td <- create_test_report_data()
  df <- sf::st_drop_geometry(td$family_scores)
  result <- nemeton:::prepare_report_data(td$project, df, "fr")
  expect_type(result, "list")
  expect_true(is.numeric(result$global_score))
})

test_that("prepare_report_data computes parcel_scores with ids", {
  td <- create_test_report_data()
  result <- nemeton:::prepare_report_data(td$project, td$family_scores, "fr")
  expect_true(length(result$parcel_scores) > 0)
  expect_true("C" %in% names(result$parcel_scores))
  expect_true("id" %in% names(result$parcel_scores$C))
})

# ==============================================================================
# draw_standard_cover_page()
# ==============================================================================

test_that("draw_standard_cover_page renders without error", {
  td <- create_test_report_data()
  report_data <- nemeton:::prepare_report_data(td$project, td$family_scores, "fr")

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_standard_cover_page(report_data, "fr"))
})

test_that("draw_standard_cover_page handles low global score", {
  td <- create_test_report_data()
  # Set low scores
  family_codes <- c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")
  for (code in family_codes) {
    td$family_scores[[paste0("family_", code)]] <- rep(15, 3)
  }
  report_data <- nemeton:::prepare_report_data(td$project, td$family_scores, "fr")
  expect_true(report_data$global_score < 20)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_standard_cover_page(report_data, "fr"))
})

test_that("draw_standard_cover_page handles medium global score", {
  td <- create_test_report_data()
  family_codes <- c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")
  for (code in family_codes) {
    td$family_scores[[paste0("family_", code)]] <- rep(50, 3)
  }
  report_data <- nemeton:::prepare_report_data(td$project, td$family_scores, "en")

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_standard_cover_page(report_data, "en"))
})

# ==============================================================================
# draw_parcel_table()
# ==============================================================================

test_that("draw_parcel_table renders table with sf data", {
  units <- create_test_units(n_features = 5)
  units$score_col <- c(90, 70, 50, 30, 10)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_parcel_table(units, "score_col", "id", "fr"))
})

test_that("draw_parcel_table handles all quality levels", {
  units <- create_test_units(n_features = 6)
  units$score_col <- c(95, 65, 45, 25, 5, NA)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_parcel_table(units, "score_col", "id", "fr"))
})

test_that("draw_parcel_table handles English language", {
  units <- create_test_units(n_features = 3)
  units$score_col <- c(85, 50, 15)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_parcel_table(units, "score_col", "id", "en"))
})

test_that("draw_parcel_table returns NULL for missing column", {
  units <- create_test_units(n_features = 3)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  result <- nemeton:::draw_parcel_table(units, "nonexistent", "id", "fr")
  expect_null(result)
})

test_that("draw_parcel_table uses sequential IDs when id_col missing", {
  units <- create_test_units(n_features = 3)
  units$score <- c(80, 60, 40)
  # Remove the id column
  units$id <- NULL

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_parcel_table(units, "score", "missing_id", "fr"))
})

test_that("draw_parcel_table with indicator_title", {
  units <- create_test_units(n_features = 3)
  units$score <- c(80, 60, 40)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_parcel_table(units, "score", "id", "fr",
                                            indicator_title = "C1 - Biomasse carbone"))
})

test_that("draw_parcel_table handles >20 rows", {
  units <- create_test_units(n_features = 25)
  units$score <- runif(25, 0, 100)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_parcel_table(units, "score", "id", "fr"))
})

test_that("draw_parcel_table handles non-sf data", {
  df <- data.frame(id = c("A", "B", "C"), score = c(80, 60, 40))

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_parcel_table(df, "score", "id", "fr"))
})

# ==============================================================================
# add_parcel_labels()
# ==============================================================================

test_that("add_parcel_labels renders labels on map", {
  units <- create_test_units(n_features = 3)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  plot(sf::st_geometry(units))
  expect_silent(nemeton:::add_parcel_labels(units))
})

test_that("add_parcel_labels uses sequential IDs when id_col missing", {
  units <- create_test_units(n_features = 3)
  units$id <- NULL

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  plot(sf::st_geometry(units))
  expect_silent(nemeton:::add_parcel_labels(units, id_col = "missing_col"))
})

test_that("add_parcel_labels returns NULL for non-sf", {
  result <- nemeton:::add_parcel_labels(data.frame(x = 1))
  expect_null(result)
})

# ==============================================================================
# generate_indicator_map()
# ==============================================================================

test_that("generate_indicator_map creates a map", {
  units <- create_test_units(n_features = 3)
  units$score <- c(80, 50, 20)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  result <- nemeton:::generate_indicator_map(units, "score", "Test Map")
  expect_null(result)
})

test_that("generate_indicator_map returns NULL for missing column", {
  units <- create_test_units(n_features = 3)
  result <- nemeton:::generate_indicator_map(units, "nonexistent", "Test")
  expect_null(result)
})

test_that("generate_indicator_map returns NULL for all-NA values", {
  units <- create_test_units(n_features = 3)
  units$score <- NA_real_

  result <- nemeton:::generate_indicator_map(units, "score", "Test")
  expect_null(result)
})

test_that("generate_indicator_map returns NULL for non-sf data", {
  df <- data.frame(score = c(80, 50, 20))
  result <- nemeton:::generate_indicator_map(df, "score", "Test")
  expect_null(result)
})

test_that("generate_indicator_map writes to output_file", {
  units <- create_test_units(n_features = 3)
  units$score <- c(80, 50, 20)

  withr::with_tempdir({
    output <- file.path(getwd(), "test_map.png")
    nemeton:::generate_indicator_map(units, "score", "Test", output_file = output)
    expect_true(file.exists(output))
  })
})

test_that("generate_indicator_map handles NA values mixed with valid", {
  units <- create_test_units(n_features = 3)
  units$score <- c(80, NA, 20)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  result <- nemeton:::generate_indicator_map(units, "score", "Test")
  expect_null(result)
})

# ==============================================================================
# draw_indicator_map_page()
# ==============================================================================

test_that("draw_indicator_map_page renders fallback map", {
  units <- create_test_units(n_features = 3)
  units$score <- c(80, 50, 20)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_indicator_map_page(units, "score", "Test Map", "#228B22", "fr"))
})

test_that("draw_indicator_map_page handles missing column", {
  units <- create_test_units(n_features = 3)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  nemeton:::draw_indicator_map_page(units, "nonexistent", "Test", "#228B22", "fr")
  # Should not error
  expect_true(TRUE)
})

test_that("draw_indicator_map_page handles all-NA values", {
  units <- create_test_units(n_features = 3)
  units$score <- NA_real_

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  nemeton:::draw_indicator_map_page(units, "score", "Test", "#228B22", "en")
  expect_true(TRUE)
})

test_that("draw_indicator_map_page handles mixed NA values", {
  units <- create_test_units(n_features = 3)
  units$score <- c(80, NA, 20)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_indicator_map_page(units, "score", "Test", "#228B22", "fr"))
})

# ==============================================================================
# generate_family_maps() — fallback (no maptiles)
# ==============================================================================

test_that("generate_family_maps creates map files without maptiles", {
  td <- create_test_report_data()

  withr::with_tempdir({
    out_dir <- file.path(getwd(), "maps")
    dir.create(out_dir)

    local_mocked_bindings(
      requireNamespace = function(pkg, ...) {
        if (pkg == "maptiles") return(FALSE)
        TRUE
      },
      .package = "base"
    )

    nemeton:::generate_family_maps(td$family_scores, out_dir, "fr")
    files <- list.files(out_dir, pattern = "\\.png$")
    expect_true(length(files) > 0)
  })
})

test_that("generate_family_maps returns NULL for non-sf data", {
  result <- nemeton:::generate_family_maps(data.frame(x = 1), tempdir(), "fr")
  expect_null(result)
})

# ==============================================================================
# generate_radar_image()
# ==============================================================================

test_that("generate_radar_image creates PNG file", {
  td <- create_test_report_data()

  withr::with_tempdir({
    output <- file.path(getwd(), "radar.png")
    nemeton:::generate_radar_image(td$family_scores, output, "fr")
    expect_true(file.exists(output))
  })
})

# ==============================================================================
# generate_simple_pdf_report() — the big one
# ==============================================================================

test_that("generate_simple_pdf_report creates PDF without cover image", {
  td <- create_test_report_data()

  withr::with_tempdir({
    output <- file.path(getwd(), "report.pdf")
    result <- nemeton:::generate_simple_pdf_report(
      td$project, td$family_scores, output, "fr"
    )
    expect_equal(result, output)
    expect_true(file.exists(output))
  })
})

test_that("generate_simple_pdf_report creates PDF with synthesis comments", {
  td <- create_test_report_data()

  withr::with_tempdir({
    output <- file.path(getwd(), "report.pdf")
    result <- nemeton:::generate_simple_pdf_report(
      td$project, td$family_scores, output, "fr",
      synthesis_comments = "## Summary\n\nThis is a **test** report with:\n- Item 1\n- Item 2"
    )
    expect_equal(result, output)
    expect_true(file.exists(output))
  })
})

test_that("generate_simple_pdf_report creates PDF with family comments", {
  td <- create_test_report_data()
  comments <- list(C = "Carbon analysis:\n- Good biomass", B = "Biodiversity is **strong**")

  withr::with_tempdir({
    output <- file.path(getwd(), "report.pdf")
    result <- nemeton:::generate_simple_pdf_report(
      td$project, td$family_scores, output, "en",
      family_comments = comments
    )
    expect_equal(result, output)
    expect_true(file.exists(output))
  })
})

test_that("generate_simple_pdf_report creates PDF with PNG cover image", {
  td <- create_test_report_data()

  withr::with_tempdir({
    # Create a minimal PNG cover image
    cover_path <- file.path(getwd(), "cover.png")
    grDevices::png(cover_path, width = 200, height = 200)
    plot(1:10, type = "l")
    grDevices::dev.off()

    output <- file.path(getwd(), "report.pdf")
    result <- nemeton:::generate_simple_pdf_report(
      td$project, td$family_scores, output, "fr",
      cover_image = cover_path
    )
    expect_equal(result, output)
    expect_true(file.exists(output))
  })
})

test_that("generate_simple_pdf_report handles missing cover image gracefully", {
  td <- create_test_report_data()

  withr::with_tempdir({
    output <- file.path(getwd(), "report.pdf")
    result <- nemeton:::generate_simple_pdf_report(
      td$project, td$family_scores, output, "fr",
      cover_image = "/nonexistent/cover.png"
    )
    expect_equal(result, output)
    expect_true(file.exists(output))
  })
})

test_that("generate_simple_pdf_report handles English language", {
  td <- create_test_report_data()

  withr::with_tempdir({
    output <- file.path(getwd(), "report.pdf")
    result <- nemeton:::generate_simple_pdf_report(
      td$project, td$family_scores, output, "en",
      synthesis_comments = "English synthesis"
    )
    expect_true(file.exists(output))
  })
})

# ==============================================================================
# generate_report_pdf() — main entry point
# ==============================================================================

test_that("generate_report_pdf falls back to simple PDF when quarto unavailable", {
  td <- create_test_report_data()

  local_mocked_bindings(
    is_quarto_installed = function() FALSE,
    .package = "nemeton"
  )

  withr::with_tempdir({
    output <- file.path(getwd(), "report.pdf")
    result <- nemeton::generate_report_pdf(
      td$project, td$family_scores, output, "fr", use_quarto = FALSE
    )
    expect_true(file.exists(output))
  })
})

# ==============================================================================
# export_geopackage()
# ==============================================================================

test_that("export_geopackage creates gpkg file", {
  units <- create_test_units(n_features = 3)
  units$score <- c(80, 50, 20)

  withr::with_tempdir({
    output <- file.path(getwd(), "export.gpkg")
    result <- nemeton:::export_geopackage(units, output)
    expect_equal(result, output)
    expect_true(file.exists(output))
  })
})

test_that("export_geopackage rejects non-sf data", {
  expect_error(
    nemeton:::export_geopackage(data.frame(x = 1), tempfile()),
    "must be an sf object"
  )
})
