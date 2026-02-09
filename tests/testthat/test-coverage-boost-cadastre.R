# Coverage boost tests for R/service_cadastre.R
# Targets: get_cadastral_parcels() mocked flow, fetch_api_cadastre mocked,
# standardize_parcels edge cases, format_parcel_info edge cases

# Helper: create a minimal polygon sf
make_test_parcels <- function(n = 3, with_id = TRUE) {
  polys <- lapply(seq_len(n), function(i) {
    sf::st_polygon(list(matrix(
      c(i, 0, i + 1, 0, i + 1, 1, i, 1, i, 0),
      ncol = 2, byrow = TRUE
    )))
  })
  geom <- sf::st_sfc(polys, crs = 4326)
  if (with_id) {
    sf::st_sf(
      id = paste0("p", seq_len(n)),
      section = rep("A", n),
      numero = sprintf("%04d", seq_len(n)),
      contenance = rep(15000, n),
      geometry = geom
    )
  } else {
    sf::st_sf(
      value = seq_len(n),
      geometry = geom
    )
  }
}

# ==============================================================================
# get_cadastral_parcels() — mocked API flow
# ==============================================================================

test_that("get_cadastral_parcels with successful API returns standardized parcels", {
  mock_parcels <- make_test_parcels(5)

  with_mocked_bindings(.package = "nemeton",
    fetch_api_cadastre = function(code_insee) mock_parcels,
    {
      result <- nemeton:::get_cadastral_parcels("01001")

      expect_s3_class(result, "sf")
      expect_true(nrow(result) > 0)
      expect_true("id" %in% names(result))
      expect_true("code_insee" %in% names(result))
      expect_equal(result$code_insee[1], "01001")
    }
  )
})

test_that("get_cadastral_parcels falls back to happign when API fails", {
  mock_parcels <- make_test_parcels(3)

  with_mocked_bindings(.package = "nemeton",
    fetch_api_cadastre = function(code_insee) stop("API down"),
    fetch_happign_cadastre = function(code_insee, commune_geometry) mock_parcels,
    {
      result <- nemeton:::get_cadastral_parcels("01001")

      expect_s3_class(result, "sf")
      expect_true(nrow(result) > 0)
    }
  )
})

test_that("get_cadastral_parcels errors when both sources fail", {
  with_mocked_bindings(.package = "nemeton",
    fetch_api_cadastre = function(code_insee) stop("API down"),
    fetch_happign_cadastre = function(code_insee, commune_geometry) stop("WFS down"),
    {
      expect_error(
        nemeton:::get_cadastral_parcels("01001"),
        "Unable to fetch|WFS down"
      )
    }
  )
})

test_that("get_cadastral_parcels falls back when API returns empty", {
  empty_sf <- sf::st_sf(
    id = character(0),
    geometry = sf::st_sfc(crs = 4326)
  )
  mock_parcels <- make_test_parcels(2)

  with_mocked_bindings(.package = "nemeton",
    fetch_api_cadastre = function(code_insee) empty_sf,
    fetch_happign_cadastre = function(code_insee, commune_geometry) mock_parcels,
    {
      result <- nemeton:::get_cadastral_parcels("01001")
      expect_s3_class(result, "sf")
      expect_true(nrow(result) > 0)
    }
  )
})

test_that("get_cadastral_parcels accepts Corsican INSEE codes", {
  mock_parcels <- make_test_parcels(2)

  with_mocked_bindings(.package = "nemeton",
    fetch_api_cadastre = function(code_insee) mock_parcels,
    {
      result <- nemeton:::get_cadastral_parcels("2A004")
      expect_s3_class(result, "sf")
    }
  )
})

test_that("get_cadastral_parcels rejects 6-digit code", {
  expect_error(
    nemeton:::get_cadastral_parcels("123456"),
    "Invalid INSEE"
  )
})

# ==============================================================================
# standardize_parcels() — additional edge cases
# ==============================================================================

test_that("standardize_parcels handles MULTIPOLYGON geometry", {
  mp <- sf::st_multipolygon(list(
    list(matrix(c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE)),
    list(matrix(c(2, 0, 3, 0, 3, 1, 2, 1, 2, 0), ncol = 2, byrow = TRUE))
  ))
  geom <- sf::st_sfc(mp, crs = 4326)
  parcels <- sf::st_sf(id = "mp1", contenance = 20000, geometry = geom)

  result <- nemeton:::standardize_parcels(parcels, "01001")
  expect_s3_class(result, "sf")
  expect_equal(nrow(result), 1)
})

test_that("standardize_parcels preserves existing section column (lowercase)", {
  geom <- sf::st_sfc(
    sf::st_polygon(list(matrix(c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE))),
    crs = 4326
  )
  parcels <- sf::st_sf(
    id = "p1",
    section = "AB",
    numero = "0042",
    contenance = 5000,
    geometry = geom
  )

  result <- nemeton:::standardize_parcels(parcels, "01001")
  expect_equal(result$section[1], "AB")
  expect_equal(result$numero[1], "0042")
})

test_that("standardize_parcels sets NA for missing section and numero", {
  geom <- sf::st_sfc(
    sf::st_polygon(list(matrix(c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE))),
    crs = 4326
  )
  parcels <- sf::st_sf(id = "p1", geometry = geom)

  result <- nemeton:::standardize_parcels(parcels, "01001")
  expect_true(is.na(result$section[1]))
  expect_true(is.na(result$numero[1]))
})

test_that("standardize_parcels calls st_make_valid on geometries", {
  # Create a simple valid polygon
  geom <- sf::st_sfc(
    sf::st_polygon(list(matrix(c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE))),
    crs = 4326
  )
  parcels <- sf::st_sf(id = "p1", contenance = 1000, geometry = geom)

  result <- nemeton:::standardize_parcels(parcels, "01001")
  # Valid input stays valid after st_make_valid
  expect_true(all(sf::st_is_valid(result)))
})

# ==============================================================================
# format_parcel_info() — edge cases
# ==============================================================================

test_that("format_parcel_info handles missing section (NULL)", {
  geom <- sf::st_sfc(
    sf::st_polygon(list(matrix(c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE))),
    crs = 4326
  )
  parcel <- sf::st_sf(
    id = "test",
    section = NA_character_,
    numero = NA_character_,
    contenance = 10000,
    geometry = geom
  )[1, ]

  result_fr <- nemeton:::format_parcel_info(parcel, "fr")
  expect_true(grepl("Parcelle", result_fr))
  expect_true(grepl("1\\.00 ha", result_fr))

  result_en <- nemeton:::format_parcel_info(parcel, "en")
  expect_true(grepl("Parcel", result_en))
  expect_true(grepl("Area", result_en))
})

test_that("format_parcel_info computes area correctly", {
  geom <- sf::st_sfc(
    sf::st_polygon(list(matrix(c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE))),
    crs = 4326
  )
  parcel <- sf::st_sf(
    id = "test",
    section = "C",
    numero = "0007",
    contenance = 25000,
    geometry = geom
  )[1, ]

  result <- nemeton:::format_parcel_info(parcel, "fr")
  expect_true(grepl("2\\.50 ha", result))
})

# ==============================================================================
# create_parcel_popup() — edge cases
# ==============================================================================

test_that("create_parcel_popup computes area in hectares", {
  geom <- sf::st_sfc(
    sf::st_polygon(list(matrix(c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE))),
    crs = 4326
  )
  parcel <- sf::st_sf(
    id = "PARC001",
    section = "D",
    numero = "0012",
    contenance = 33000,
    geometry = geom
  )[1, ]

  result <- nemeton:::create_parcel_popup(parcel)
  expect_true(grepl("3.3", result))
  expect_true(grepl("<strong>PARC001</strong>", result))
  expect_true(grepl("Section: D", result))
})

test_that("create_parcel_popup with NULL section shows dash", {
  parcel <- list(
    id = "test",
    section = NULL,
    numero = NULL,
    contenance = 10000
  )

  result <- nemeton:::create_parcel_popup(parcel)
  expect_type(result, "character")
  expect_true(grepl("<strong>", result))
})

# ==============================================================================
# create_parcel_label() — additional edge cases
# ==============================================================================

test_that("create_parcel_label with empty string lieu_dit", {
  parcel <- list(
    section = "E",
    numero = "0001",
    contenance = 12000,
    nom_com = "",
    lieu_dit = NULL,
    lieudit = NULL
  )

  result <- nemeton:::create_parcel_label(parcel)
  # Empty string should not trigger lieu-dit display
  expect_false(grepl("color:#666", result))
})

# ==============================================================================
# calculate_parcel_stats() — with NA values
# ==============================================================================

test_that("calculate_parcel_stats handles NA contenance", {
  geom <- sf::st_sfc(
    sf::st_polygon(list(matrix(c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE))),
    sf::st_polygon(list(matrix(c(2, 0, 3, 0, 3, 1, 2, 1, 2, 0), ncol = 2, byrow = TRUE))),
    crs = 4326
  )
  parcels <- sf::st_sf(
    id = c("p1", "p2"),
    contenance = c(10000, NA_real_),
    geometry = geom
  )

  stats <- nemeton:::calculate_parcel_stats(parcels)
  expect_equal(stats$count, 2)
  expect_equal(stats$total_area_ha, 1)  # Only p1 counted
})
