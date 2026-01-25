# Tests for Cadastre Service
# Phase 2: Cadastral parcel retrieval

test_that("get_cadastral_parcels validates INSEE code format", {
  expect_error(
    nemeton:::get_cadastral_parcels("123"),
    regexp = "Invalid INSEE"
  )

  expect_error(
    nemeton:::get_cadastral_parcels("ABCDE"),
    regexp = "Invalid INSEE"
  )

  expect_error(
    nemeton:::get_cadastral_parcels(""),
    regexp = "Invalid INSEE"
  )
})

test_that("get_cadastral_parcels accepts valid INSEE codes", {
  skip_if_offline()
  skip_on_cran()

  # Don't actually call the API, just check format validation passes
  # Use a small commune for faster test
  expect_error(
    nemeton:::get_cadastral_parcels("01001"),
    regexp = NA  # Should not error on format
  )
})

test_that("standardize_parcels creates required columns", {
  skip_if_not_installed("sf")

  # Create mock parcel data
  mock_geom <- sf::st_sfc(
    sf::st_polygon(list(matrix(c(0,0, 1,0, 1,1, 0,1, 0,0), ncol = 2, byrow = TRUE))),
    crs = 4326
  )

  mock_parcels <- sf::st_sf(
    idu = "01001000A0001",
    section = "A",
    numero = "0001",
    contenance = 5000,
    geometry = mock_geom
  )

  result <- nemeton:::standardize_parcels(mock_parcels, "01001")

  # Check required columns exist
  expect_true("id" %in% names(result))
  expect_true("section" %in% names(result))
  expect_true("numero" %in% names(result))
  expect_true("contenance" %in% names(result))
  expect_true("code_insee" %in% names(result))

  # Check code_insee is set

  expect_equal(result$code_insee[1], "01001")
})

test_that("standardize_parcels generates IDs if missing", {
  skip_if_not_installed("sf")

  mock_geom <- sf::st_sfc(
    sf::st_polygon(list(matrix(c(0,0, 1,0, 1,1, 0,1, 0,0), ncol = 2, byrow = TRUE))),
    crs = 4326
  )

  mock_parcels <- sf::st_sf(
    other_col = "value",
    geometry = mock_geom
  )

  result <- nemeton:::standardize_parcels(mock_parcels, "01001")

  expect_true("id" %in% names(result))
  expect_true(grepl("^01001_", result$id[1]))
})

test_that("standardize_parcels calculates area if missing", {
  skip_if_not_installed("sf")

  # Create a square polygon (approximately 100m x 100m at equator)
  mock_geom <- sf::st_sfc(
    sf::st_polygon(list(matrix(c(
      0, 0,
      0.001, 0,
      0.001, 0.001,
      0, 0.001,
      0, 0
    ), ncol = 2, byrow = TRUE))),
    crs = 4326
  )

  mock_parcels <- sf::st_sf(
    id = "test_id",
    geometry = mock_geom
  )

  result <- nemeton:::standardize_parcels(mock_parcels, "01001")

  expect_true("contenance" %in% names(result))
  expect_true(result$contenance[1] > 0)
})

test_that("get_parcel_by_id returns correct parcel", {
  skip_if_not_installed("sf")

  mock_geom <- sf::st_sfc(
    sf::st_polygon(list(matrix(c(0,0, 1,0, 1,1, 0,1, 0,0), ncol = 2, byrow = TRUE))),
    sf::st_polygon(list(matrix(c(2,0, 3,0, 3,1, 2,1, 2,0), ncol = 2, byrow = TRUE))),
    crs = 4326
  )

  mock_parcels <- sf::st_sf(
    id = c("parcel_1", "parcel_2"),
    section = c("A", "B"),
    geometry = mock_geom
  )

  result <- nemeton:::get_parcel_by_id("parcel_1", mock_parcels)

  expect_equal(nrow(result), 1)
  expect_equal(result$id, "parcel_1")
  expect_equal(result$section, "A")
})

test_that("get_parcel_by_id returns NULL for non-existent ID", {
  skip_if_not_installed("sf")

  mock_geom <- sf::st_sfc(
    sf::st_polygon(list(matrix(c(0,0, 1,0, 1,1, 0,1, 0,0), ncol = 2, byrow = TRUE))),
    crs = 4326
  )

  mock_parcels <- sf::st_sf(
    id = "parcel_1",
    geometry = mock_geom
  )

  result <- nemeton:::get_parcel_by_id("nonexistent", mock_parcels)

  expect_null(result)
})

test_that("filter_selected_parcels returns subset", {
  skip_if_not_installed("sf")

  mock_geom <- sf::st_sfc(
    sf::st_polygon(list(matrix(c(0,0, 1,0, 1,1, 0,1, 0,0), ncol = 2, byrow = TRUE))),
    sf::st_polygon(list(matrix(c(2,0, 3,0, 3,1, 2,1, 2,0), ncol = 2, byrow = TRUE))),
    sf::st_polygon(list(matrix(c(4,0, 5,0, 5,1, 4,1, 4,0), ncol = 2, byrow = TRUE))),
    crs = 4326
  )

  mock_parcels <- sf::st_sf(
    id = c("p1", "p2", "p3"),
    geometry = mock_geom
  )

  result <- nemeton:::filter_selected_parcels(mock_parcels, c("p1", "p3"))

  expect_equal(nrow(result), 2)
  expect_true("p1" %in% result$id)
  expect_true("p3" %in% result$id)
  expect_false("p2" %in% result$id)
})

test_that("filter_selected_parcels handles empty selection", {
  skip_if_not_installed("sf")

  mock_geom <- sf::st_sfc(
    sf::st_polygon(list(matrix(c(0,0, 1,0, 1,1, 0,1, 0,0), ncol = 2, byrow = TRUE))),
    crs = 4326
  )

  mock_parcels <- sf::st_sf(
    id = "parcel_1",
    geometry = mock_geom
  )

  result <- nemeton:::filter_selected_parcels(mock_parcels, character(0))

  expect_equal(nrow(result), 0)
})

test_that("calculate_parcel_stats returns correct values", {
  skip_if_not_installed("sf")

  mock_geom <- sf::st_sfc(
    sf::st_polygon(list(matrix(c(0,0, 1,0, 1,1, 0,1, 0,0), ncol = 2, byrow = TRUE))),
    sf::st_polygon(list(matrix(c(2,0, 3,0, 3,1, 2,1, 2,0), ncol = 2, byrow = TRUE))),
    crs = 4326
  )

  mock_parcels <- sf::st_sf(
    id = c("p1", "p2"),
    contenance = c(10000, 20000),  # m²
    geometry = mock_geom
  )

  stats <- nemeton:::calculate_parcel_stats(mock_parcels)

  expect_equal(stats$count, 2)
  expect_equal(stats$total_area_ha, 3)  # 30000 m² = 3 ha
  expect_equal(stats$mean_area_ha, 1.5)
  expect_equal(stats$min_area_ha, 1)
  expect_equal(stats$max_area_ha, 2)
})

test_that("calculate_parcel_stats handles NULL input", {
  stats <- nemeton:::calculate_parcel_stats(NULL)

  expect_equal(stats$count, 0)
  expect_equal(stats$total_area_ha, 0)
})

test_that("calculate_parcel_stats handles empty data", {
  skip_if_not_installed("sf")

  mock_geom <- sf::st_sfc(crs = 4326)
  mock_parcels <- sf::st_sf(
    id = character(0),
    contenance = numeric(0),
    geometry = mock_geom
  )

  stats <- nemeton:::calculate_parcel_stats(mock_parcels)

  expect_equal(stats$count, 0)
  expect_equal(stats$total_area_ha, 0)
})

test_that("format_parcel_info returns French format", {
  skip_if_not_installed("sf")

  mock_geom <- sf::st_sfc(
    sf::st_polygon(list(matrix(c(0,0, 1,0, 1,1, 0,1, 0,0), ncol = 2, byrow = TRUE))),
    crs = 4326
  )

  mock_parcel <- sf::st_sf(
    id = "01001000A0001",
    section = "A",
    numero = "0001",
    contenance = 15000,
    geometry = mock_geom
  )[1, ]

  result <- nemeton:::format_parcel_info(mock_parcel, "fr")

  expect_true(grepl("Parcelle", result))
  expect_true(grepl("Section", result))
  expect_true(grepl("Surface", result))
  expect_true(grepl("1\\.50 ha", result))
})

test_that("format_parcel_info returns English format", {
  skip_if_not_installed("sf")

  mock_geom <- sf::st_sfc(
    sf::st_polygon(list(matrix(c(0,0, 1,0, 1,1, 0,1, 0,0), ncol = 2, byrow = TRUE))),
    crs = 4326
  )

  mock_parcel <- sf::st_sf(
    id = "01001000A0001",
    section = "A",
    numero = "0001",
    contenance = 15000,
    geometry = mock_geom
  )[1, ]

  result <- nemeton:::format_parcel_info(mock_parcel, "en")

  expect_true(grepl("Parcel", result))
  expect_true(grepl("Area", result))
})

test_that("create_parcel_popup returns HTML", {
  skip_if_not_installed("sf")

  mock_geom <- sf::st_sfc(
    sf::st_polygon(list(matrix(c(0,0, 1,0, 1,1, 0,1, 0,0), ncol = 2, byrow = TRUE))),
    crs = 4326
  )

  mock_parcel <- sf::st_sf(
    id = "01001000A0001",
    section = "A",
    numero = "0001",
    contenance = 15000,
    geometry = mock_geom
  )[1, ]

  result <- nemeton:::create_parcel_popup(mock_parcel)

  expect_type(result, "character")
  expect_true(grepl("<strong>", result))
  expect_true(grepl("Section", result))
  expect_true(grepl("ha", result))
})
