# Tests for Commune Service
# Phase 2: Commune search and autocomplete

test_that("get_departments returns all French departments", {
  depts <- nemeton:::get_departments()

  expect_type(depts, "character")
  expect_true(length(depts) >= 100)  # France has ~100 departments

  # Check some known departments
  expect_true("01" %in% depts)   # Ain
  expect_true("75" %in% depts)   # Paris
  expect_true("2A" %in% depts)   # Corse-du-Sud
  expect_true("974" %in% depts)  # La Réunion
})

test_that("get_departments returns named vector", {
  depts <- nemeton:::get_departments()

  expect_true(!is.null(names(depts)))
  expect_true(all(nchar(names(depts)) > 0))

  # Check format: "01 - Ain"
  expect_true(grepl("^[0-9A-B]{2,3} - ", names(depts)[1]))
})

test_that("format_communes_for_selectize returns correct structure", {
  # Create mock commune data
  communes <- data.frame(
    code_insee = c("01001", "01002"),
    nom = c("Commune A", "Commune B"),
    code_postal = c("01100", "01200"),
    label = c("Commune A (01001)", "Commune B (01002)"),
    stringsAsFactors = FALSE
  )

  result <- nemeton:::format_communes_for_selectize(communes)

  expect_type(result, "character")
  expect_length(result, 2)
  expect_equal(names(result)[1], "Commune A (01001)")
  expect_equal(result[[1]], "01001")
})

test_that("format_communes_for_selectize handles empty data", {
  communes <- data.frame(
    code_insee = character(0),
    nom = character(0),
    code_postal = character(0),
    label = character(0)
  )

  result <- nemeton:::format_communes_for_selectize(communes)

  expect_length(result, 0)
  expect_type(result, "character")
})

test_that("validate_insee_code accepts valid codes", {
  validate <- nemeton:::validate_insee_code

  expect_true(validate("75056"))   # Paris
  expect_true(validate("01001"))   # Ain
  expect_true(validate("2A004"))   # Corsica
  expect_true(validate("97411"))   # La Réunion
})

test_that("validate_insee_code rejects invalid codes", {
  validate <- nemeton:::validate_insee_code

  expect_false(validate("1234"))      # Too short
  expect_false(validate("123456"))    # Too long
  expect_false(validate("ABCDE"))     # Invalid chars
  expect_false(validate(""))          # Empty
  expect_false(validate(NA))          # NA
})

test_that("search_communes validates query parameter", {
  skip_if_offline()

  # Empty query should return empty result
  result <- nemeton:::search_communes("")
  expect_equal(nrow(result), 0)
})

test_that("search_communes returns correct structure", {
  skip_if_offline()
  skip_on_cran()

  result <- nemeton:::search_communes("Paris", limit = 5)

  if (nrow(result) > 0) {
    expect_true("code_insee" %in% names(result))
    expect_true("nom" %in% names(result))
    expect_true("departement" %in% names(result))
  }
})

test_that("search_by_postal_code validates input", {
  # Invalid postal code format returns empty result
  result <- nemeton:::search_by_postal_code("123")
  expect_equal(nrow(result), 0)

  result <- nemeton:::search_by_postal_code("ABCDE")
  expect_equal(nrow(result), 0)
})

test_that("get_commune_geometry validates INSEE code", {
  # Invalid code returns NULL with warning
  expect_warning(
    result <- nemeton:::get_commune_geometry("invalid"),
    regexp = "Invalid"
  )
  expect_null(result)
})

test_that("get_commune_geometry returns sf object", {
  skip_if_offline()
  skip_on_cran()

  # Use Paris as test case (stable)
  geom <- nemeton:::get_commune_geometry("75056")

  if (!is.null(geom)) {
    expect_s3_class(geom, "sf")
    expect_true(sf::st_crs(geom)$epsg == 4326)
  }
})

test_that("get_communes_in_department filters correctly", {
  skip_if_offline()
  skip_on_cran()

  result <- nemeton:::get_communes_in_department("75")

  if (nrow(result) > 0) {
    # All should be Paris arrondissements
    expect_true(all(grepl("^75", result$code_insee)))
  }
})
