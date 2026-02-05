# Tests for service_export.R

test_that("is_quarto_installed returns logical", {
  result <- nemeton:::is_quarto_installed()
  expect_type(result, "logical")
})

test_that("prepare_report_data creates valid structure", {
  skip_if_not_installed("sf")

  # Create mock project
  project <- list(
    metadata = list(
      name = "Test Project",
      description = "A test project",
      owner = "Test Owner",
      created_at = "2026-01-01"
    )
  )

  # Create mock family scores
  family_scores <- sf::st_sf(
    id = 1:3,
    family_C = c(60, 70, 65),
    family_B = c(55, 60, 58),
    family_W = c(40, 45, 42),
    family_A = c(50, 55, 52),
    family_F = c(45, 50, 48),
    family_L = c(35, 40, 38),
    family_T = c(70, 75, 72),
    family_R = c(30, 35, 32),
    family_S = c(25, 30, 28),
    family_P = c(65, 70, 68),
    family_E = c(55, 60, 58),
    family_N = c(80, 85, 82),
    geometry = sf::st_sfc(
      sf::st_point(c(0, 0)),
      sf::st_point(c(1, 0)),
      sf::st_point(c(0, 1)),
      crs = 2154
    )
  )

  result <- nemeton:::prepare_report_data(project, family_scores, "fr", NULL)

  expect_type(result, "list")
  expect_equal(result$project_name, "Test Project")
  expect_equal(result$n_parcels, 3)
  expect_true(result$global_score > 0 && result$global_score <= 100)
  expect_type(result$family_stats, "list")
  expect_equal(length(result$family_stats), 12)
  expect_equal(result$language, "fr")
})

test_that("prepare_report_data works with en language", {
  skip_if_not_installed("sf")

  project <- list(
    metadata = list(
      name = "Test",
      description = NULL,
      owner = NULL,
      created_at = "2026-01-01"
    )
  )

  family_scores <- sf::st_sf(
    id = 1,
    family_C = 50,
    family_B = 50,
    family_W = 50,
    family_A = 50,
    family_F = 50,
    family_L = 50,
    family_T = 50,
    family_R = 50,
    family_S = 50,
    family_P = 50,
    family_E = 50,
    family_N = 50,
    geometry = sf::st_sfc(sf::st_point(c(0, 0)), crs = 2154)
  )

  result <- nemeton:::prepare_report_data(project, family_scores, "en", "Test comments")

  expect_equal(result$language, "en")
  expect_equal(result$synthesis_comments, "Test comments")
  expect_equal(result$global_score, 50)
})

test_that("nemeton:::export_geopackage creates valid file", {
  skip_if_not_installed("sf")

  # Create test data
  test_sf <- sf::st_sf(
    id = 1:2,
    family_C = c(60, 70),
    geometry = sf::st_sfc(
      sf::st_point(c(0, 0)),
      sf::st_point(c(1, 1)),
      crs = 2154
    )
  )

  temp_file <- tempfile(fileext = ".gpkg")
  on.exit(unlink(temp_file), add = TRUE)

  result <- nemeton:::export_geopackage(test_sf, temp_file)

  expect_true(file.exists(result))
  expect_equal(result, temp_file)

  # Verify content
  read_back <- sf::st_read(temp_file, quiet = TRUE)
  expect_equal(nrow(read_back), 2)
  expect_true("family_C" %in% names(read_back))
})

test_that("nemeton:::export_geopackage fails for non-sf input", {
  expect_error(
    nemeton:::export_geopackage(data.frame(x = 1), tempfile()),
    "must be an sf object"
  )
})

test_that("nemeton:::generate_simple_pdf_report creates file", {
  skip_if_not_installed("sf")

  project <- list(
    metadata = list(
      name = "Test PDF",
      description = "Test description",
      owner = "Owner",
      created_at = "2026-01-01"
    )
  )

  family_scores <- sf::st_sf(
    id = 1:2,
    family_C = c(60, 70),
    family_B = c(55, 60),
    family_W = c(40, 45),
    family_A = c(50, 55),
    family_F = c(45, 50),
    family_L = c(35, 40),
    family_T = c(70, 75),
    family_R = c(30, 35),
    family_S = c(25, 30),
    family_P = c(65, 70),
    family_E = c(55, 60),
    family_N = c(80, 85),
    geometry = sf::st_sfc(
      sf::st_point(c(0, 0)),
      sf::st_point(c(1, 1)),
      crs = 2154
    )
  )

  temp_file <- tempfile(fileext = ".pdf")
  on.exit(unlink(temp_file), add = TRUE)

  result <- nemeton:::generate_simple_pdf_report(
    project, family_scores, temp_file,
    language = "fr",
    synthesis_comments = "Test comments for PDF"
  )

  expect_true(file.exists(result))
  expect_equal(result, temp_file)
  expect_true(file.size(result) > 0)
})

test_that("nemeton:::generate_report_pdf works without Quarto", {
  skip_if_not_installed("sf")

  project <- list(
    metadata = list(
      name = "Fallback Test",
      description = NULL,
      owner = NULL,
      created_at = "2026-01-01"
    )
  )

  family_scores <- sf::st_sf(
    id = 1,
    family_C = 50, family_B = 50, family_W = 50, family_A = 50,
    family_F = 50, family_L = 50, family_T = 50, family_R = 50,
    family_S = 50, family_P = 50, family_E = 50, family_N = 50,
    geometry = sf::st_sfc(sf::st_point(c(0, 0)), crs = 2154)
  )

  temp_file <- tempfile(fileext = ".pdf")
  on.exit(unlink(temp_file), add = TRUE)

  # Force fallback by setting use_quarto = FALSE
  result <- nemeton:::generate_report_pdf(
    project, family_scores, temp_file,
    language = "en",
    use_quarto = FALSE
  )

  expect_true(file.exists(result))
})
