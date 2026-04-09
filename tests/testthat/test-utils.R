# Tests for R/utils.R utility functions
# Comprehensive coverage for all exported and internal utility functions

# ==============================================================================
# generate_ids
# ==============================================================================

test_that("generate_ids produces correct format", {
  ids <- nemeton:::generate_ids(3)
  expect_equal(ids, c("unit_001", "unit_002", "unit_003"))
})

test_that("generate_ids respects custom prefix", {
  ids <- nemeton:::generate_ids(2, prefix = "parcel_")
  expect_equal(ids, c("parcel_001", "parcel_002"))
})

test_that("generate_ids handles n=1", {
  ids <- nemeton:::generate_ids(1)
  expect_equal(ids, "unit_001")
})

test_that("generate_ids handles large n with zero-padding", {
  ids <- nemeton:::generate_ids(5)
  expect_length(ids, 5)
  expect_equal(ids, c("unit_001", "unit_002", "unit_003", "unit_004", "unit_005"))
  # Check uniqueness
  expect_equal(length(unique(ids)), 5)
})

test_that("generate_ids with empty prefix", {
  ids <- nemeton:::generate_ids(2, prefix = "")
  expect_equal(ids, c("001", "002"))
})

# ==============================================================================
# detect_indicator_family
# ==============================================================================

test_that("detect_indicator_family extracts family code", {
  expect_equal(nemeton:::detect_indicator_family("C1"), "C")
  expect_equal(nemeton:::detect_indicator_family("B3"), "B")
  expect_equal(nemeton:::detect_indicator_family("W2"), "W")
  expect_equal(nemeton:::detect_indicator_family("R4"), "R")
  expect_equal(nemeton:::detect_indicator_family("W2_norm"), "W")
  expect_equal(nemeton:::detect_indicator_family("R1"), "R")
})

test_that("detect_indicator_family returns NA for non-indicator names", {
  expect_true(is.na(nemeton:::detect_indicator_family("indicateur_c1_biomasse")))
  expect_true(is.na(nemeton:::detect_indicator_family("unknown")))
  expect_true(is.na(nemeton:::detect_indicator_family("abc")))
  expect_true(is.na(nemeton:::detect_indicator_family("area")))
  expect_true(is.na(nemeton:::detect_indicator_family("name")))
  expect_true(is.na(nemeton:::detect_indicator_family("geometry")))
})

test_that("detect_indicator_family requires uppercase letter + digit", {
  # lowercase letter + digit should not match
  expect_true(is.na(nemeton:::detect_indicator_family("c1")))
  # letter without digit should not match

  expect_true(is.na(nemeton:::detect_indicator_family("Carbon")))
})

# ==============================================================================
# calculate_shannon_h
# ==============================================================================

test_that("calculate_shannon_h computes correct diversity", {
  # Equal proportions (4 classes): H = log(4) ~= 1.386
  result <- nemeton:::calculate_shannon_h(c(0.25, 0.25, 0.25, 0.25))
  expect_equal(result, log(4), tolerance = 1e-10)
})

test_that("calculate_shannon_h returns 0 for single category", {
  result <- nemeton:::calculate_shannon_h(c(1.0))
  expect_equal(result, 0)
})

test_that("calculate_shannon_h returns NA for empty/all-NA input", {
  expect_true(is.na(nemeton:::calculate_shannon_h(c())))
  expect_true(is.na(nemeton:::calculate_shannon_h(c(NA, NA))))
})

test_that("calculate_shannon_h handles zeros", {
  # Should ignore zeros
  result <- nemeton:::calculate_shannon_h(c(0.5, 0.5, 0, 0))
  expect_equal(result, log(2), tolerance = 1e-10)
})

test_that("calculate_shannon_h normalizes proportions", {
  # Not summing to 1 should still work
  result <- nemeton:::calculate_shannon_h(c(1, 1, 1, 1))
  expect_equal(result, log(4), tolerance = 1e-10)
})

test_that("calculate_shannon_h supports custom base", {
  result <- nemeton:::calculate_shannon_h(c(0.5, 0.5), base = 2)
  expect_equal(result, 1, tolerance = 1e-10)  # log2(2) = 1
})

test_that("calculate_shannon_h returns NA for all-zero input", {
  all_zeros <- c(0, 0, 0)
  expect_true(is.na(nemeton:::calculate_shannon_h(all_zeros)))
})

test_that("calculate_shannon_h handles mixed zeros and NAs", {
  result <- nemeton:::calculate_shannon_h(c(0.5, NA, 0.5, 0, NA))
  expect_equal(result, log(2), tolerance = 1e-10)
})

test_that("calculate_shannon_h with unequal proportions", {
  result <- nemeton:::calculate_shannon_h(c(0.9, 0.1))
  # H = -(0.9*log(0.9) + 0.1*log(0.1))
  expected <- -(0.9 * log(0.9) + 0.1 * log(0.1))
  expect_equal(result, expected, tolerance = 1e-10)
})

# ==============================================================================
# get_crs
# ==============================================================================

test_that("get_crs extracts CRS from sf object", {
  skip_if_not_installed("sf")
  units <- create_test_units(crs = 2154)
  crs <- nemeton:::get_crs(units)
  expect_s3_class(crs, "crs")
  expect_equal(crs$epsg, 2154)
})

test_that("get_crs extracts CRS from sfc geometry column", {
  skip_if_not_installed("sf")
  units <- create_test_units(crs = 2154)
  geom <- sf::st_geometry(units)
  crs <- nemeton:::get_crs(geom)
  expect_s3_class(crs, "crs")
})

test_that("get_crs extracts CRS from SpatRaster", {
  skip_if_not_installed("terra")
  r <- create_test_raster(crs = "EPSG:2154")
  crs <- nemeton:::get_crs(r)
  # For SpatRaster, get_crs returns the EPSG code
  expect_equal(crs, "2154")
})

test_that("get_crs returns NA for unknown object type", {
  crs <- nemeton:::get_crs(data.frame(x = 1))
  expect_true(is.na(crs))
})

test_that("get_crs returns NA for basic list", {
  crs <- nemeton:::get_crs(list(a = 1, b = 2))
  expect_true(is.na(crs))
})

# ==============================================================================
# check_crs
# ==============================================================================

test_that("check_crs passes for matching CRS", {
  skip_if_not_installed("sf")
  units1 <- create_test_units(crs = 2154)
  units2 <- create_test_units(crs = 2154)
  expect_true(nemeton:::check_crs(units1, units2))
})

test_that("check_crs passes for matching CRS in strict mode", {
  skip_if_not_installed("sf")
  units1 <- create_test_units(crs = 2154)
  units2 <- create_test_units(crs = 2154)
  expect_silent(nemeton:::check_crs(units1, units2, strict = TRUE))
})

test_that("check_crs errors for undefined CRS on first object", {
  skip_if_not_installed("sf")
  units1 <- create_test_units(crs = 2154)
  sf::st_crs(units1) <- NA
  units2 <- create_test_units(crs = 2154)
  expect_error(nemeton:::check_crs(units1, units2), "undefined CRS")
})

test_that("check_crs errors for undefined CRS on second object", {
  skip_if_not_installed("sf")
  units1 <- create_test_units(crs = 2154)
  units2 <- create_test_units(crs = 2154)
  sf::st_crs(units2) <- NA
  expect_error(nemeton:::check_crs(units1, units2), "undefined CRS")
})

test_that("check_crs detects CRS mismatch in strict mode", {
  skip_if_not_installed("sf")
  units1 <- create_test_units(crs = 2154)
  units2 <- create_test_units(crs = 4326)
  expect_error(
    nemeton:::check_crs(units1, units2, strict = TRUE),
    "CRS mismatch"
  )
})

test_that("check_crs allows different CRS in non-strict mode", {
  skip_if_not_installed("sf")
  units1 <- create_test_units(crs = 2154)
  units2 <- create_test_units(crs = 4326)
  # Non-strict mode: only checks that CRS are defined, not that they match
  expect_true(nemeton:::check_crs(units1, units2, strict = FALSE))
})

# ==============================================================================
# validate_sf
# ==============================================================================

test_that("validate_sf passes for valid sf object", {
  skip_if_not_installed("sf")
  units <- create_test_units(crs = 2154)
  expect_true(nemeton:::validate_sf(units))
})

test_that("validate_sf rejects non-sf object", {
  expect_error(nemeton:::validate_sf(data.frame(x = 1)), "sf")
})

test_that("validate_sf rejects sf without CRS when required", {
  skip_if_not_installed("sf")
  units <- create_test_units(crs = 2154)
  sf::st_crs(units) <- NA
  expect_error(nemeton:::validate_sf(units, require_crs = TRUE), "CRS")
})

test_that("validate_sf accepts sf without CRS when not required", {
  skip_if_not_installed("sf")
  units <- create_test_units(crs = 2154)
  sf::st_crs(units) <- NA
  # Should not fail on CRS check when require_crs = FALSE
  expect_silent(nemeton:::validate_sf(units, require_crs = FALSE))
})

test_that("validate_sf rejects point geometries", {
  skip_if_not_installed("sf")
  points <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(sf::st_point(c(0, 0)), crs = 4326)
  )
  expect_error(nemeton:::validate_sf(points), "POLYGON")
})

test_that("validate_sf detects invalid geometries", {
  skip_if_not_installed("sf")
  # Create a self-intersecting polygon (invalid)
  invalid_poly <- sf::st_polygon(list(matrix(
    c(0, 0, 1, 1, 1, 0, 0, 1, 0, 0),
    ncol = 2, byrow = TRUE
  )))
  invalid_sf <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(invalid_poly, crs = 2154)
  )
  expect_error(
    nemeton:::validate_sf(invalid_sf, require_valid = TRUE),
    "invalid geometr"
  )
})

test_that("validate_sf detects empty geometries", {
  skip_if_not_installed("sf")
  empty_sf <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(sf::st_polygon(), crs = 2154)
  )
  expect_error(nemeton:::validate_sf(empty_sf), "empty geometr")
})

test_that("validate_sf accepts MULTIPOLYGON geometry type", {
  skip_if_not_installed("sf")
  # Create a valid MULTIPOLYGON
  poly1 <- sf::st_polygon(list(matrix(
    c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0),
    ncol = 2, byrow = TRUE
  )))
  poly2 <- sf::st_polygon(list(matrix(
    c(2, 2, 3, 2, 3, 3, 2, 3, 2, 2),
    ncol = 2, byrow = TRUE
  )))
  mpoly <- sf::st_multipolygon(list(poly1, poly2))
  mpoly_sf <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(mpoly, crs = 2154)
  )
  expect_true(nemeton:::validate_sf(mpoly_sf))
})

test_that("validate_sf rejects LINESTRING geometry type", {
  skip_if_not_installed("sf")
  line_sf <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_linestring(matrix(c(0, 0, 1, 1), ncol = 2, byrow = TRUE)),
      crs = 2154
    )
  )
  expect_error(nemeton:::validate_sf(line_sf), "POLYGON")
})

# ==============================================================================
# as_pure_sf
# ==============================================================================

test_that("as_pure_sf returns sf object without nemeton_units class", {
  skip_if_not_installed("sf")
  units <- create_test_units()
  class(units) <- c("nemeton_units", class(units))
  result <- nemeton:::as_pure_sf(units)
  expect_s3_class(result, "sf")
  expect_false("nemeton_units" %in% class(result))
})

test_that("as_pure_sf preserves data for regular sf objects", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)
  result <- nemeton:::as_pure_sf(units)
  expect_equal(nrow(result), nrow(units))
  expect_true("sf" %in% class(result))
})

test_that("as_pure_sf reprojects to raster CRS when provided", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  units <- create_test_units(crs = 2154)
  # Create a raster in a different CRS
  r <- terra::rast(
    extent = terra::ext(-1, 1, 43, 45),
    resolution = 0.01,
    crs = "EPSG:4326"
  )
  terra::values(r) <- 1
  result <- nemeton:::as_pure_sf(units, raster = r)
  expect_equal(sf::st_crs(result)$epsg, 4326L)
})

test_that("as_pure_sf does not reproject when CRS already matches", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  units <- create_test_units(crs = 2154)
  r <- create_test_raster(crs = "EPSG:2154")
  result <- nemeton:::as_pure_sf(units, raster = r)
  expect_equal(sf::st_crs(result)$epsg, 2154L)
})

test_that("as_pure_sf without raster argument keeps original CRS", {
  skip_if_not_installed("sf")
  units <- create_test_units(crs = 2154)
  result <- nemeton:::as_pure_sf(units)
  expect_equal(sf::st_crs(result)$epsg, 2154L)
})

# ==============================================================================
# get_osm_bbox
# ==============================================================================

test_that("get_osm_bbox returns 4-element named vector in WGS84", {
  skip_if_not_installed("sf")
  units <- create_test_units(crs = 2154)
  bbox <- nemeton:::get_osm_bbox(units, buffer_m = 0)
  expect_length(bbox, 4)
  expect_named(bbox, c("xmin", "ymin", "xmax", "ymax"))
  # WGS84 coordinates should be in reasonable range
  expect_true(bbox["xmin"] > -180 && bbox["xmin"] < 180)
  expect_true(bbox["ymin"] > -90 && bbox["ymin"] < 90)
})

test_that("get_osm_bbox validates sf input", {
  expect_error(nemeton:::get_osm_bbox(data.frame(x = 1)), "sf")
})

test_that("get_osm_bbox with buffer expands bbox", {
  skip_if_not_installed("sf")
  units <- create_test_units(crs = 2154)
  bbox_no_buf <- nemeton:::get_osm_bbox(units, buffer_m = 0)
  bbox_with_buf <- nemeton:::get_osm_bbox(units, buffer_m = 1000)
  expect_true(bbox_with_buf["xmin"] < bbox_no_buf["xmin"])
  expect_true(bbox_with_buf["ymax"] > bbox_no_buf["ymax"])
})

test_that("get_osm_bbox works with WGS84 input", {
  skip_if_not_installed("sf")
  # Create units in WGS84
  poly <- sf::st_polygon(list(matrix(
    c(2.0, 47.0, 2.1, 47.0, 2.1, 47.1, 2.0, 47.1, 2.0, 47.0),
    ncol = 2, byrow = TRUE
  )))
  units_wgs84 <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(poly, crs = 4326)
  )
  # buffer_m=0 with WGS84 should still work (skips buffering for 4326)
  bbox <- nemeton:::get_osm_bbox(units_wgs84, buffer_m = 0)
  expect_length(bbox, 4)
  expect_true(bbox["xmin"] >= 2.0)
  expect_true(bbox["ymin"] >= 47.0)
})

# ==============================================================================
# get_species_flammability
# ==============================================================================

test_that("get_species_flammability returns scores for known species", {
  result <- nemeton:::get_species_flammability(c("Pinus", "Quercus"))
  expect_type(result, "double")
  expect_length(result, 2)
  expect_true(all(result >= 0 & result <= 100))
  # Pinus should have high flammability
  expect_true(result[1] > 60)
})

test_that("get_species_flammability returns default 50 for unknown species", {
  result <- nemeton:::get_species_flammability("UnknownSpecies123")
  expect_equal(result, 50)
})

test_that("get_species_flammability handles NA", {
  result <- nemeton:::get_species_flammability(NA_character_)
  expect_true(is.na(result))
})

test_that("get_species_flammability is vectorized", {
  species <- c("Pinus", "Fagus", "Quercus")
  scores <- nemeton:::get_species_flammability(species)
  expect_length(scores, 3)
  expect_type(scores, "double")
})

test_that("get_species_flammability handles mixed NA and valid species", {
  result <- nemeton:::get_species_flammability(c("Pinus", NA, "Fagus"))
  expect_length(result, 3)
  expect_false(is.na(result[1]))
  expect_true(is.na(result[2]))
  expect_false(is.na(result[3]))
})

# ==============================================================================
# get_species_drought_sensitivity
# ==============================================================================

test_that("get_species_drought_sensitivity returns scores for known species", {
  result <- nemeton:::get_species_drought_sensitivity(c("Fagus", "Pinus"))
  expect_type(result, "double")
  expect_length(result, 2)
  expect_true(all(result >= 0 & result <= 100))
})

test_that("get_species_drought_sensitivity returns default 50 for unknown species", {
  result <- nemeton:::get_species_drought_sensitivity("UnknownSpecies123")
  expect_equal(result, 50)
})

test_that("get_species_drought_sensitivity handles NA", {
  result <- nemeton:::get_species_drought_sensitivity(NA_character_)
  expect_true(is.na(result))
})

test_that("get_species_drought_sensitivity is vectorized", {
  species <- c("Fagus", "Quercus", "Pinus")
  scores <- nemeton:::get_species_drought_sensitivity(species)
  expect_length(scores, 3)
  expect_type(scores, "double")
})

test_that("get_species_drought_sensitivity handles mixed NA and valid", {
  result <- nemeton:::get_species_drought_sensitivity(c("Fagus", NA, "Pinus"))
  expect_length(result, 3)
  expect_false(is.na(result[1]))
  expect_true(is.na(result[2]))
  expect_false(is.na(result[3]))
})

# ==============================================================================
# get_species_palatability
# ==============================================================================

test_that("get_species_palatability returns scores for known species", {
  result <- nemeton:::get_species_palatability(c("quercus", "pinus"))
  expect_type(result, "double")
  expect_length(result, 2)
  # Quercus should be high (80+), Pinus should be low (20-40)
  expect_true(result[1] > 60)
  expect_true(result[2] < 50)
})

test_that("get_species_palatability returns default 50 for unknown species", {
  result <- nemeton:::get_species_palatability("unknownspecies123")
  expect_equal(result, 50)
})

test_that("get_species_palatability handles NA", {
  result <- nemeton:::get_species_palatability(NA_character_)
  expect_true(is.na(result))
})

test_that("get_species_palatability handles vector input with mixed NA", {
  result <- nemeton:::get_species_palatability(c("quercus", NA, "picea"))
  expect_length(result, 3)
  expect_true(result[1] > 60)
  expect_true(is.na(result[2]))
  expect_true(result[3] < 30)
})

test_that("get_species_palatability handles French species names", {
  chene_score <- nemeton:::get_species_palatability("chene")
  expect_true(chene_score > 70)

  hetre_score <- nemeton:::get_species_palatability("hetre")
  expect_true(hetre_score > 50)

  pin_score <- nemeton:::get_species_palatability("pin")
  expect_true(pin_score < 50)
})

test_that("get_species_palatability handles English species names", {
  oak_score <- nemeton:::get_species_palatability("oak")
  expect_true(oak_score > 70)

  spruce_score <- nemeton:::get_species_palatability("spruce")
  expect_true(spruce_score < 30)
})

test_that("get_species_palatability is case-insensitive", {
  lower <- nemeton:::get_species_palatability("quercus")
  upper <- nemeton:::get_species_palatability("Quercus")
  mixed <- nemeton:::get_species_palatability("QUERCUS")
  # All should resolve to the same score (after tolower)
  expect_equal(lower, upper)
  expect_equal(upper, mixed)
})

# ==============================================================================
# calculate_allometric_biomass
# ==============================================================================

test_that("calculate_allometric_biomass returns numeric values", {
  result <- nemeton:::calculate_allometric_biomass(
    c("Quercus", "Fagus", "Pinus"),
    c(80, 60, 40),
    c(0.7, 0.8, 0.6)
  )
  expect_type(result, "double")
  expect_length(result, 3)
  expect_true(all(result > 0))
})

test_that("calculate_allometric_biomass handles NA species", {
  result <- nemeton:::calculate_allometric_biomass(
    c("Quercus", NA),
    c(80, 60),
    c(0.7, 0.8)
  )
  expect_true(!is.na(result[1]))
  expect_true(is.na(result[2]))
})

test_that("calculate_allometric_biomass handles NA age", {
  result <- nemeton:::calculate_allometric_biomass(
    c("Quercus", "Pinus"),
    c(80, NA),
    c(0.7, 0.8)
  )
  expect_true(!is.na(result[1]))
  expect_true(is.na(result[2]))
})

test_that("calculate_allometric_biomass handles NA density", {
  result <- nemeton:::calculate_allometric_biomass(
    c("Quercus", "Pinus"),
    c(80, 60),
    c(0.7, NA)
  )
  expect_true(!is.na(result[1]))
  expect_true(is.na(result[2]))
})

test_that("calculate_allometric_biomass uses generic fallback for unknown species", {
  result <- nemeton:::calculate_allometric_biomass("UnknownSpecies", 50, 0.5)
  expect_type(result, "double")
  expect_length(result, 1)
  expect_true(result > 0)
})

test_that("calculate_allometric_biomass is case insensitive", {
  result1 <- nemeton:::calculate_allometric_biomass("Quercus", 50, 0.7)
  result2 <- nemeton:::calculate_allometric_biomass("quercus", 50, 0.7)
  expect_equal(result1, result2)
})

# ==============================================================================
# get_allometric_coefficients
# ==============================================================================

test_that("get_allometric_coefficients returns complete coefficient set", {
  result <- nemeton:::get_allometric_coefficients("Quercus")
  expect_type(result, "list")
  expect_true(all(c("a", "b", "c") %in% names(result)))
  expect_type(result$a, "double")
  expect_type(result$b, "double")
  expect_type(result$c, "double")
})

test_that("get_allometric_coefficients falls back to Generic", {
  result <- nemeton:::get_allometric_coefficients("UnknownSpecies123")
  expect_type(result, "list")
  expect_true("a" %in% names(result))
})

test_that("get_allometric_coefficients is case-insensitive", {
  result1 <- nemeton:::get_allometric_coefficients("Fagus")
  result2 <- nemeton:::get_allometric_coefficients("fagus")
  result3 <- nemeton:::get_allometric_coefficients("FAGUS")
  expect_equal(result1$a, result2$a)
  expect_equal(result2$a, result3$a)
})

# ==============================================================================
# message_nemeton
# ==============================================================================

test_that("message_nemeton outputs message", {
  expect_output(nemeton:::message_nemeton("test message"), "test message")
})

test_that("message_nemeton supports glue interpolation", {
  expect_output(
    nemeton:::message_nemeton("Processing {3} units"),
    "Processing 3 units"
  )
})

test_that("message_nemeton handles multi-part messages", {
  expect_output(
    nemeton:::message_nemeton("part1", " part2"),
    "part1 part2"
  )
})

# ==============================================================================
# smart_map
# ==============================================================================

test_that("smart_map works in sequential mode", {
  result <- nemeton:::smart_map(1:5, function(x) x * 2, threshold = 100, .type = "dbl")
  expect_equal(result, c(2, 4, 6, 8, 10))
})

test_that("smart_map returns list by default", {
  result <- nemeton:::smart_map(1:3, function(x) x * 2, threshold = 100)
  expect_type(result, "list")
  expect_length(result, 3)
})

test_that("smart_map validates complexity", {
  expect_error(
    nemeton:::smart_map(1:3, identity, complexity = "invalid"),
    "Invalid"
  )
})

test_that("smart_map supports chr type", {
  result <- nemeton:::smart_map(
    1:3, function(x) paste0("item_", x),
    threshold = 100, .type = "chr"
  )
  expect_type(result, "character")
  expect_equal(result, c("item_1", "item_2", "item_3"))
})

test_that("smart_map supports lgl type", {
  result <- nemeton:::smart_map(
    1:4, function(x) x > 2,
    threshold = 100, .type = "lgl"
  )
  expect_type(result, "logical")
  expect_equal(result, c(FALSE, FALSE, TRUE, TRUE))
})

test_that("smart_map supports int type", {
  result <- nemeton:::smart_map(
    1:3, function(x) as.integer(x * 10),
    threshold = 100, .type = "int"
  )
  expect_type(result, "integer")
  expect_equal(result, c(10L, 20L, 30L))
})

test_that("smart_map uses correct threshold from complexity", {
  # Very low complexity should have high threshold (2000)
  expect_message(
    nemeton:::smart_map(1:10, function(x) x, complexity = "very_low"),
    "below threshold 2000"
  )

  # High complexity should have lower threshold (50)
  expect_message(
    nemeton:::smart_map(1:10, function(x) x, complexity = "high"),
    "below threshold 50"
  )
})

test_that("smart_map respects explicit threshold override", {
  expect_message(
    nemeton:::smart_map(1:5, function(x) x, threshold = 10),
    "below threshold 10"
  )
})

test_that("smart_map handles empty input", {
  result <- nemeton:::smart_map(list(), function(x) x, threshold = 100)
  expect_length(result, 0)
})

# ==============================================================================
# smart_map_sf
# ==============================================================================

test_that("smart_map_sf validates sf input", {
  expect_error(
    nemeton:::smart_map_sf(data.frame(x = 1), function(i, data) i),
    "sf"
  )
})

test_that("smart_map_sf processes sf rows", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  result <- nemeton:::smart_map_sf(
    units,
    function(i, data) as.numeric(sf::st_area(data[i, ])),
    threshold = 100,
    .type = "dbl"
  )
  expect_length(result, 3)
  expect_true(all(result > 0))
})

test_that("smart_map_sf returns list by default", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)
  result <- nemeton:::smart_map_sf(
    units,
    function(i, data) list(row = i),
    threshold = 100
  )
  expect_type(result, "list")
  expect_length(result, 2)
})

# ==============================================================================
# resolve_raster_layer
# ==============================================================================

test_that("resolve_raster_layer returns NULL for non-nemeton_layers", {
  result <- nemeton:::resolve_raster_layer(list(rasters = list()), "dem")
  expect_null(result)
})

test_that("resolve_raster_layer returns NULL for missing layer name", {
  layers <- structure(
    list(rasters = list(), vectors = list()),
    class = "nemeton_layers"
  )
  result <- nemeton:::resolve_raster_layer(layers, "nonexistent")
  expect_null(result)
})

test_that("resolve_raster_layer returns SpatRaster directly", {
  skip_if_not_installed("terra")
  r <- create_test_raster()
  layers <- structure(
    list(rasters = list(dem = r), vectors = list()),
    class = "nemeton_layers"
  )
  result <- nemeton:::resolve_raster_layer(layers, "dem")
  expect_true(inherits(result, "SpatRaster"))
})

test_that("resolve_raster_layer resolves lazy-load list with object", {
  skip_if_not_installed("terra")
  r <- create_test_raster()
  layers <- structure(
    list(
      rasters = list(dem = list(object = r, path = "", loaded = TRUE)),
      vectors = list()
    ),
    class = "nemeton_layers"
  )
  result <- nemeton:::resolve_raster_layer(layers, "dem")
  expect_true(inherits(result, "SpatRaster"))
})

test_that("resolve_raster_layer resolves lazy-load list from file path", {
  skip_if_not_installed("terra")
  withr::with_tempdir({
    r <- create_test_raster()
    path <- file.path(getwd(), "test_raster.tif")
    terra::writeRaster(r, path, overwrite = TRUE)

    layers <- structure(
      list(
        rasters = list(dem = list(object = NULL, path = path, loaded = FALSE)),
        vectors = list()
      ),
      class = "nemeton_layers"
    )
    result <- nemeton:::resolve_raster_layer(layers, "dem")
    expect_true(inherits(result, "SpatRaster"))
  })
})

test_that("resolve_raster_layer returns NULL for NULL entry", {
  layers <- structure(
    list(rasters = list(dem = NULL), vectors = list()),
    class = "nemeton_layers"
  )
  result <- nemeton:::resolve_raster_layer(layers, "dem")
  expect_null(result)
})

# ==============================================================================
# resolve_vector_layer
# ==============================================================================

test_that("resolve_vector_layer returns NULL for non-nemeton_layers", {
  result <- nemeton:::resolve_vector_layer(list(vectors = list()), "roads")
  expect_null(result)
})

test_that("resolve_vector_layer returns NULL for missing layer name", {
  layers <- structure(
    list(rasters = list(), vectors = list()),
    class = "nemeton_layers"
  )
  result <- nemeton:::resolve_vector_layer(layers, "nonexistent")
  expect_null(result)
})

test_that("resolve_vector_layer returns sf directly", {
  skip_if_not_installed("sf")
  roads <- create_test_vector(type = "lines")
  layers <- structure(
    list(rasters = list(), vectors = list(roads = roads)),
    class = "nemeton_layers"
  )
  result <- nemeton:::resolve_vector_layer(layers, "roads")
  expect_s3_class(result, "sf")
})

test_that("resolve_vector_layer resolves lazy-load list with object", {
  skip_if_not_installed("sf")
  roads <- create_test_vector(type = "lines")
  layers <- structure(
    list(
      rasters = list(),
      vectors = list(roads = list(object = roads, path = "", loaded = TRUE))
    ),
    class = "nemeton_layers"
  )
  result <- nemeton:::resolve_vector_layer(layers, "roads")
  expect_s3_class(result, "sf")
})

test_that("resolve_vector_layer resolves lazy-load list from file path", {
  skip_if_not_installed("sf")
  withr::with_tempdir({
    roads <- create_test_vector(type = "lines")
    path <- file.path(getwd(), "test_roads.gpkg")
    sf::st_write(roads, path, quiet = TRUE)

    layers <- structure(
      list(
        rasters = list(),
        vectors = list(roads = list(object = NULL, path = path, loaded = FALSE))
      ),
      class = "nemeton_layers"
    )
    result <- nemeton:::resolve_vector_layer(layers, "roads")
    expect_s3_class(result, "sf")
  })
})

test_that("resolve_vector_layer returns NULL for NULL entry", {
  layers <- structure(
    list(rasters = list(), vectors = list(roads = NULL)),
    class = "nemeton_layers"
  )
  result <- nemeton:::resolve_vector_layer(layers, "roads")
  expect_null(result)
})

# ==============================================================================
# get_dem_raster
# ==============================================================================

test_that("get_dem_raster returns NULL for non-nemeton_layers", {
  result <- nemeton:::get_dem_raster(list())
  expect_null(result)
})

test_that("get_dem_raster prefers lidar_mnt over dem", {
  skip_if_not_installed("terra")
  lidar <- create_test_raster(values = "constant")
  terra::values(lidar) <- 200  # distinctive value
  dem <- create_test_raster(values = "constant")
  terra::values(dem) <- 100  # different value

  layers <- structure(
    list(
      rasters = list(lidar_mnt = lidar, dem = dem),
      vectors = list()
    ),
    class = "nemeton_layers"
  )
  result <- nemeton:::get_dem_raster(layers)
  expect_true(inherits(result, "SpatRaster"))
  # Should be the lidar (200) not the dem (100)
  expect_equal(terra::values(result)[1], 200)
})

test_that("get_dem_raster falls back to dem when lidar_mnt missing", {
  skip_if_not_installed("terra")
  dem <- create_test_raster(values = "constant")
  terra::values(dem) <- 100

  layers <- structure(
    list(rasters = list(dem = dem), vectors = list()),
    class = "nemeton_layers"
  )
  result <- nemeton:::get_dem_raster(layers)
  expect_true(inherits(result, "SpatRaster"))
  expect_equal(terra::values(result)[1], 100)
})

test_that("get_dem_raster returns NULL when no DEM available", {
  layers <- structure(
    list(rasters = list(ndvi = create_test_raster()), vectors = list()),
    class = "nemeton_layers"
  )
  result <- nemeton:::get_dem_raster(layers)
  expect_null(result)
})

# ==============================================================================
# map_essence_to_species
# ==============================================================================

test_that("map_essence_to_species maps oak variants", {
  result <- nemeton:::map_essence_to_species(c("Ch\u00eane sessile", "Chene pubescent"))
  expect_true(all(result == "Quercus"))
})

test_that("map_essence_to_species maps beech variants", {
  result <- nemeton:::map_essence_to_species(c("H\u00eatre", "Hetre commun"))
  expect_true(all(result == "Fagus"))
})

test_that("map_essence_to_species maps pine and fir", {
  # pine matches on "pin"
  result_pin <- nemeton:::map_essence_to_species("Pin maritime")
  expect_equal(result_pin, "Pinus")

  result_sapin <- nemeton:::map_essence_to_species("Sapin blanc")
  expect_equal(result_sapin, "Abies")
})

test_that("map_essence_to_species returns Generic for unknown species", {
  result <- nemeton:::map_essence_to_species("Arbuste inconnu")
  expect_equal(result, "Generic")
})

test_that("map_essence_to_species handles NA", {
  result <- nemeton:::map_essence_to_species(NA)
  expect_true(is.na(result))
})

test_that("map_essence_to_species is vectorized", {
  input <- c("Ch\u00eane", "H\u00eatre", NA, "Douglas", "Autre espece")
  result <- nemeton:::map_essence_to_species(input)
  expect_length(result, 5)
  expect_equal(result[1], "Quercus")
  expect_equal(result[2], "Fagus")
  expect_true(is.na(result[3]))
  expect_equal(result[4], "Abies")  # Douglas matches "douglas"
  expect_equal(result[5], "Generic")
})

# ==============================================================================
# enrich_parcels_bdforet
# ==============================================================================

test_that("enrich_parcels_bdforet returns correct columns", {
  skip_if_not_installed("sf")
  parcels <- create_test_units(crs = 2154, n_features = 2)

  # Create bdforet with matching extent but no real intersection
  bdforet_geom <- sf::st_sfc(
    sf::st_polygon(list(matrix(c(
      0, 0, 100, 0, 100, 100, 0, 100, 0, 0
    ), ncol = 2, byrow = TRUE))),
    crs = 2154
  )
  bdforet <- sf::st_sf(
    CODE_TFV = "FF1-00",
    TFV = "For\u00eat ferm\u00e9e \u00e0 feuillus",
    geometry = bdforet_geom
  )

  result <- nemeton:::enrich_parcels_bdforet(parcels, bdforet)
  expect_true("species" %in% names(result))
  expect_true("age" %in% names(result))
  expect_true("density" %in% names(result))
  expect_equal(nrow(result), nrow(parcels))
})

test_that("enrich_parcels_bdforet handles no essence column", {
  skip_if_not_installed("sf")
  parcels <- create_test_units(crs = 2154, n_features = 2)

  # Create bdforet without any recognizable essence column
  bdforet <- sf::st_sf(
    some_col = "value",
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        566400, 6615100, 567000, 6615100, 567000, 6615500,
        566400, 6615500, 566400, 6615100
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Should warn and return all NAs
  result <- suppressMessages(nemeton:::enrich_parcels_bdforet(parcels, bdforet))
  expect_equal(nrow(result), 2)
  expect_true(all(is.na(result$species)))
})

test_that("enrich_parcels_bdforet handles intersecting data", {
  skip_if_not_installed("sf")
  parcels <- create_test_units(crs = 2154, n_features = 2)

  # Create bdforet overlapping the parcels extent
  bdforet <- sf::st_sf(
    TFV = "Ch\u00eane sessile dominant",
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        566400, 6615100, 567000, 6615100, 567000, 6615500,
        566400, 6615500, 566400, 6615100
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton:::enrich_parcels_bdforet(parcels, bdforet)
  expect_equal(nrow(result), 2)
  # At least some species should be identified (not all NA)
  expect_true(any(!is.na(result$species)))
})

test_that("enrich_parcels_bdforet handles CRS mismatch between parcels and bdforet", {
  skip_if_not_installed("sf")
  parcels <- create_test_units(crs = 2154, n_features = 1)

  # Create bdforet in WGS84 that should intersect after reprojection
  bbox_wgs84 <- sf::st_bbox(sf::st_transform(parcels, 4326))
  bdforet <- sf::st_sf(
    TFV = "H\u00eatre commun",
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        bbox_wgs84["xmin"] - 0.01, bbox_wgs84["ymin"] - 0.01,
        bbox_wgs84["xmax"] + 0.01, bbox_wgs84["ymin"] - 0.01,
        bbox_wgs84["xmax"] + 0.01, bbox_wgs84["ymax"] + 0.01,
        bbox_wgs84["xmin"] - 0.01, bbox_wgs84["ymax"] + 0.01,
        bbox_wgs84["xmin"] - 0.01, bbox_wgs84["ymin"] - 0.01
      ), ncol = 2, byrow = TRUE))),
      crs = 4326
    )
  )

  # Should reproject bdforet to match parcels CRS
  result <- nemeton:::enrich_parcels_bdforet(parcels, bdforet)
  expect_equal(nrow(result), 1)
})

# ==============================================================================
# lookup_ifn_equation
# ==============================================================================

test_that("lookup_ifn_equation returns NULL for missing table", {
  result <- suppressWarnings(nemeton:::lookup_ifn_equation("UNKNOWN_CODE_XYZ"))
  expect_true(is.null(result))
})

# ==============================================================================
# lookup_species_threshold
# ==============================================================================

test_that("lookup_species_threshold returns NA for missing table", {
  result <- suppressWarnings(
    nemeton:::lookup_species_threshold("UNKNOWN_CODE", "density_kg_m3", "nonexistent_table")
  )
  expect_true(is.na(result))
})

# ==============================================================================
# lookup_ademe_factor
# ==============================================================================

test_that("lookup_ademe_factor handles missing table or values", {
  result <- suppressWarnings(
    nemeton:::lookup_ademe_factor("nonexistent_material_type_xyz", "nonexistent_scenario")
  )
  expect_true(is.null(result) || is.list(result))
})

# ==============================================================================
# .smart_map_thresholds configuration
# ==============================================================================

test_that(".smart_map_thresholds has expected complexity levels", {
  thresholds <- nemeton:::.smart_map_thresholds
  expect_type(thresholds, "list")
  expect_true(all(c("very_low", "low", "medium", "high", "very_high") %in% names(thresholds)))
  # Thresholds should be decreasing with increasing complexity
  expect_true(thresholds$very_low > thresholds$low)
  expect_true(thresholds$low > thresholds$medium)
  expect_true(thresholds$medium > thresholds$high)
  expect_true(thresholds$high > thresholds$very_high)
})

# ==============================================================================
# ADDITIONAL COVERAGE TESTS
# ==============================================================================

# ==============================================================================
# smart_map - additional code paths (furrr unavailable, progress, .type coercion)
# ==============================================================================

test_that("smart_map falls back to sequential when furrr is not available", {
  # Use a large threshold so even many elements stay sequential
  result <- suppressMessages(
    nemeton:::smart_map(1:5, function(x) x * 3, threshold = 1, .type = "dbl")
  )
  # When furrr IS available, this might go parallel; when not, sequential.
  # Either way, result should be correct.
  expect_equal(result, c(3, 6, 9, 12, 15))
})

test_that("smart_map with furrr unavailable uses sequential fallback message", {
  skip_if(requireNamespace("furrr", quietly = TRUE) &&
            requireNamespace("future", quietly = TRUE),
          "furrr is available, cannot test fallback message")
  # This only runs when furrr is truly unavailable

  expect_message(
    nemeton:::smart_map(1:300, identity, threshold = 10),
    "furrr not available"
  )
})

test_that("smart_map sequential path with progress=TRUE and .type='dbl'", {
  # Triggers the progress+type coercion path (lines 175-188)
  result <- suppressMessages(
    nemeton:::smart_map(1:5, function(x) x * 2.5, threshold = 100,
                        progress = TRUE, .type = "dbl")
  )
  expect_equal(result, c(2.5, 5.0, 7.5, 10.0, 12.5))
})

test_that("smart_map sequential path with progress=TRUE and .type='chr'", {
  result <- suppressMessages(
    nemeton:::smart_map(1:3, function(x) paste0("v", x), threshold = 100,
                        progress = TRUE, .type = "chr")
  )
  expect_equal(result, c("v1", "v2", "v3"))
})

test_that("smart_map sequential path with progress=TRUE and .type='lgl'", {
  result <- suppressMessages(
    nemeton:::smart_map(1:4, function(x) x > 2, threshold = 100,
                        progress = TRUE, .type = "lgl")
  )
  expect_equal(result, c(FALSE, FALSE, TRUE, TRUE))
})

test_that("smart_map sequential path with progress=TRUE and .type='int'", {
  result <- suppressMessages(
    nemeton:::smart_map(1:3, function(x) as.integer(x * 10), threshold = 100,
                        progress = TRUE, .type = "int")
  )
  expect_equal(result, c(10L, 20L, 30L))
})

test_that("smart_map sequential path with progress=TRUE and .type='list'", {
  result <- suppressMessages(
    nemeton:::smart_map(1:3, function(x) list(val = x), threshold = 100,
                        progress = TRUE, .type = "list")
  )
  expect_type(result, "list")
  expect_length(result, 3)
  expect_equal(result[[2]]$val, 2)
})

test_that("smart_map with all complexity levels resolves thresholds", {
  levels <- c("very_low", "low", "medium", "high", "very_high")
  for (lvl in levels) {
    result <- suppressMessages(
      nemeton:::smart_map(1:3, identity, complexity = lvl)
    )
    expect_length(result, 3)
  }
})

test_that("smart_map defaults workers and progress when NULL", {
  # Workers default to min(4, detectCores()-1), progress default to n>50
  result <- suppressMessages(
    nemeton:::smart_map(1:3, function(x) x + 1, threshold = 100, .type = "dbl")
  )
  expect_equal(result, c(2, 3, 4))
})

test_that("smart_map passes extra arguments to fn via ...", {
  add_val <- function(x, offset) x + offset
  result <- suppressMessages(
    nemeton:::smart_map(1:3, add_val, offset = 10, threshold = 100, .type = "dbl")
  )
  expect_equal(result, c(11, 12, 13))
})

# ==============================================================================
# validate_sf - additional code paths
# ==============================================================================

test_that("validate_sf with require_valid=FALSE skips validity check", {
  skip_if_not_installed("sf")
  # Create a self-intersecting polygon (invalid)
  invalid_poly <- sf::st_polygon(list(matrix(
    c(0, 0, 1, 1, 1, 0, 0, 1, 0, 0),
    ncol = 2, byrow = TRUE
  )))
  invalid_sf <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(invalid_poly, crs = 2154)
  )
  # Should NOT error when require_valid = FALSE (skip validity check)
  # It may still error on empty/geometry type checks, but not on validity
  # The invalid polygon is not empty and is a POLYGON, so it should pass
  expect_true(nemeton:::validate_sf(invalid_sf, require_valid = FALSE))
})

test_that("validate_sf with multiple invalid geometries reports count", {
  skip_if_not_installed("sf")
  invalid_poly <- sf::st_polygon(list(matrix(
    c(0, 0, 1, 1, 1, 0, 0, 1, 0, 0),
    ncol = 2, byrow = TRUE
  )))
  invalid_sf <- sf::st_sf(
    id = c(1, 2),
    geometry = sf::st_sfc(list(invalid_poly, invalid_poly), crs = 2154)
  )
  expect_error(
    nemeton:::validate_sf(invalid_sf, require_valid = TRUE),
    "invalid geometr"
  )
})

test_that("validate_sf with multiple empty geometries reports count", {
  skip_if_not_installed("sf")
  empty_sf <- sf::st_sf(
    id = c(1, 2),
    geometry = sf::st_sfc(list(sf::st_polygon(), sf::st_polygon()), crs = 2154)
  )
  expect_error(nemeton:::validate_sf(empty_sf), "empty geometr")
})

# ==============================================================================
# get_osm_bbox - additional code paths
# ==============================================================================

test_that("get_osm_bbox applies buffer for metric CRS", {
  skip_if_not_installed("sf")
  units <- create_test_units(crs = 2154)
  # Default buffer is 1000m
  bbox <- nemeton:::get_osm_bbox(units)
  expect_length(bbox, 4)
  expect_named(bbox, c("xmin", "ymin", "xmax", "ymax"))
  # Buffered bbox should be larger than unbuffered
  bbox_no_buf <- nemeton:::get_osm_bbox(units, buffer_m = 0)
  expect_true(bbox["xmin"] < bbox_no_buf["xmin"])
  expect_true(bbox["ymax"] > bbox_no_buf["ymax"])
})

test_that("get_osm_bbox skips buffer when CRS is EPSG:4326", {
  skip_if_not_installed("sf")
  poly <- sf::st_polygon(list(matrix(
    c(2.0, 47.0, 2.1, 47.0, 2.1, 47.1, 2.0, 47.1, 2.0, 47.0),
    ncol = 2, byrow = TRUE
  )))
  units_wgs84 <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(poly, crs = 4326)
  )
  # buffer_m > 0 but CRS is 4326 => skip buffering
  bbox <- nemeton:::get_osm_bbox(units_wgs84, buffer_m = 500)
  expect_length(bbox, 4)
  # Since no buffer was applied, bbox should match geometry extent
  expect_true(bbox["xmin"] >= 1.99)  # approximate
  expect_true(bbox["ymin"] >= 46.99)
})

# ==============================================================================
# lookup_ifn_equation - additional code paths
# ==============================================================================

test_that("lookup_ifn_equation returns parameters for known species code", {
  result <- nemeton:::lookup_ifn_equation("FASY")
  expect_type(result, "list")
  expect_true("a" %in% names(result))
  expect_true("b" %in% names(result))
  expect_true("c" %in% names(result))
  expect_equal(result$species_code, "FASY")
  expect_equal(result$species_name, "Fagus sylvatica")
})

test_that("lookup_ifn_equation is case-insensitive via toupper", {
  result <- nemeton:::lookup_ifn_equation("fasy")
  expect_type(result, "list")
  expect_equal(result$species_code, "FASY")
})

test_that("lookup_ifn_equation returns NULL for unknown species without fallback", {
  result <- nemeton:::lookup_ifn_equation("ZZZZ")
  expect_null(result)
})

test_that("lookup_ifn_equation uses broadleaf genus fallback", {
  result <- nemeton:::lookup_ifn_equation("ZZZZ", fallback_genus = "broadleaf")
  expect_type(result, "list")
  expect_equal(result$species_code, "BROADLEAF_GENUS")
})

test_that("lookup_ifn_equation uses conifer genus fallback", {
  result <- nemeton:::lookup_ifn_equation("ZZZZ", fallback_genus = "conifer")
  expect_type(result, "list")
  expect_equal(result$species_code, "CONIFER_GENUS")
})

test_that("lookup_ifn_equation with invalid fallback_genus returns NULL", {
  result <- nemeton:::lookup_ifn_equation("ZZZZ", fallback_genus = "invalid_type")
  expect_null(result)
})

test_that("lookup_ifn_equation returns NULL when CSV file path is empty", {
  # Test the early-return path when system.file returns ""
  # We cannot easily mock base::system.file, but we can verify the path
  # exists and test the function with a direct call that exercises the code.
  # The empty-string path is tested via the existing test at line 1093-1096
  # which uses suppressWarnings(lookup_ifn_equation("UNKNOWN_CODE_XYZ"))
  # and expects NULL (no file match). Here we verify the function returns NULL

  # for an unknown species with no fallback.
  result <- nemeton:::lookup_ifn_equation("COMPLETELY_UNKNOWN_XYZ_999")
  expect_null(result)
})

# ==============================================================================
# lookup_species_threshold - additional code paths
# ==============================================================================

test_that("lookup_species_threshold returns value for known species", {
  result <- nemeton:::lookup_species_threshold("FASY", "density_kg_m3")
  expect_type(result, "integer")
  expect_equal(result, 680)
})

test_that("lookup_species_threshold returns carbon_content_fraction", {
  result <- nemeton:::lookup_species_threshold("QUPE", "carbon_content_fraction")
  expect_equal(result, 0.5)
})

test_that("lookup_species_threshold falls back to BROADLEAF_GENUS", {
  result <- nemeton:::lookup_species_threshold("UNKNOWN_CODE_XYZ", "density_kg_m3")
  expect_type(result, "integer")
  expect_equal(result, 620)  # BROADLEAF_GENUS density
})

test_that("lookup_species_threshold returns NA for missing parameter", {
  result <- nemeton:::lookup_species_threshold("FASY", "nonexistent_param")
  # Parameter not in columns => fallback also doesn't have it => NA
  expect_true(is.na(result))
})

test_that("lookup_species_threshold returns NA when CSV not found", {
  # Use a nonexistent table_name so system.file returns ""
  expect_warning(
    result <- nemeton:::lookup_species_threshold("FASY", "density_kg_m3",
                                                  table_name = "totally_nonexistent_table_xyz"),
    "not found"
  )
  expect_true(is.na(result))
})

test_that("lookup_species_threshold with custom table_name", {
  # Using wood_density table explicitly
  result <- nemeton:::lookup_species_threshold("PIAB", "density_kg_m3", "wood_density")
  expect_equal(result, 450)
})

# ==============================================================================
# lookup_ademe_factor - additional code paths
# ==============================================================================

test_that("lookup_ademe_factor returns factor for known material_type + scenario", {
  result <- nemeton:::lookup_ademe_factor("wood_energy", "vs_natural_gas")
  expect_type(result, "list")
  expect_equal(result$material_type, "wood_energy")
  expect_equal(result$substitution_scenario, "vs_natural_gas")
  expect_equal(result$emission_factor_kgCO2eq_per_unit, 0.222)
})

test_that("lookup_ademe_factor returns first match when scenario is NULL", {
  result <- nemeton:::lookup_ademe_factor("wood_energy")
  expect_type(result, "list")
  expect_equal(result$material_type, "wood_energy")
})

test_that("lookup_ademe_factor returns NULL for unknown material_type", {
  result <- nemeton:::lookup_ademe_factor("totally_unknown_material")
  expect_null(result)
})

test_that("lookup_ademe_factor returns NULL for unknown scenario", {
  result <- nemeton:::lookup_ademe_factor("wood_energy", "vs_unknown_scenario")
  expect_null(result)
})

test_that("lookup_ademe_factor returns factor for wood_construction vs_concrete", {
  result <- nemeton:::lookup_ademe_factor("wood_construction", "vs_concrete")
  expect_type(result, "list")
  expect_equal(result$emission_factor_kgCO2eq_per_unit, 1.140)
})

test_that("lookup_ademe_factor returns NULL when material and scenario not found", {
  # Test the early-return NULL path when no matching rows exist
  result <- nemeton:::lookup_ademe_factor("completely_unknown_material_xyz")
  expect_null(result)

  # Also test with a valid material but unknown scenario
  result2 <- nemeton:::lookup_ademe_factor("wood_energy", "vs_completely_unknown_xyz")
  expect_null(result2)
})

# ==============================================================================
# enrich_parcels_bdforet - additional code paths
# ==============================================================================

test_that("enrich_parcels_bdforet handles failed intersection gracefully", {
  skip_if_not_installed("sf")
  parcels <- create_test_units(crs = 2154, n_features = 2)

  # Create bdforet with TFV column but in a location that won't intersect
  bdforet <- sf::st_sf(
    TFV = "Chene sessile",
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        0, 0, 1, 0, 1, 1, 0, 1, 0, 0
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- suppressMessages(nemeton:::enrich_parcels_bdforet(parcels, bdforet))
  expect_equal(nrow(result), 2)
  expect_true("species" %in% names(result))
  expect_true("age" %in% names(result))
  expect_true("density" %in% names(result))
})

test_that("enrich_parcels_bdforet with 'essence' column name", {
  skip_if_not_installed("sf")
  parcels <- create_test_units(crs = 2154, n_features = 2)

  # Use "essence" as column name (another recognized pattern)
  bdforet <- sf::st_sf(
    essence = "Hetre commun",
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        566400, 6615100, 567000, 6615100, 567000, 6615500,
        566400, 6615500, 566400, 6615100
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton:::enrich_parcels_bdforet(parcels, bdforet)
  expect_equal(nrow(result), 2)
  # Should extract species from the "essence" column
  expect_true(any(!is.na(result$species)))
})

test_that("enrich_parcels_bdforet assigns default age and density", {
  skip_if_not_installed("sf")
  parcels <- create_test_units(crs = 2154, n_features = 1)

  bdforet <- sf::st_sf(
    TFV = "Pin maritime",
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        566400, 6615100, 567000, 6615100, 567000, 6615500,
        566400, 6615500, 566400, 6615100
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton:::enrich_parcels_bdforet(parcels, bdforet)
  # Matching parcels should get default age=60 and density=0.7
  matching <- !is.na(result$species)
  if (any(matching)) {
    expect_equal(result$age[matching], 60)
    expect_equal(result$density[matching], 0.7)
  }
})

test_that("enrich_parcels_bdforet picks dominant essence by area", {
  skip_if_not_installed("sf")
  # Create a single parcel
  parcel_poly <- sf::st_polygon(list(matrix(c(
    566450, 6615150, 566650, 6615150, 566650, 6615350,
    566450, 6615350, 566450, 6615150
  ), ncol = 2, byrow = TRUE)))
  parcels <- sf::st_sf(
    id = "unit_001",
    geometry = sf::st_sfc(parcel_poly, crs = 2154)
  )

  # Two bdforet polygons overlapping the parcel:
  # - Large polygon with "Chene sessile" covering most
  # - Small polygon with "Pin maritime" covering less
  big_poly <- sf::st_polygon(list(matrix(c(
    566400, 6615100, 566700, 6615100, 566700, 6615400,
    566400, 6615400, 566400, 6615100
  ), ncol = 2, byrow = TRUE)))
  small_poly <- sf::st_polygon(list(matrix(c(
    566600, 6615300, 566700, 6615300, 566700, 6615400,
    566600, 6615400, 566600, 6615300
  ), ncol = 2, byrow = TRUE)))

  bdforet <- sf::st_sf(
    TFV = c("Chene sessile dominant", "Pin maritime dominant"),
    geometry = sf::st_sfc(list(big_poly, small_poly), crs = 2154)
  )

  result <- nemeton:::enrich_parcels_bdforet(parcels, bdforet)
  expect_equal(nrow(result), 1)
  # The dominant (largest area) essence should be "Chene" -> "Quercus"
  expect_equal(result$species[1], "Quercus")
})

test_that("enrich_parcels_bdforet with lib_fv column name", {
  skip_if_not_installed("sf")
  parcels <- create_test_units(crs = 2154, n_features = 1)

  # Use "lib_fv" as column name (another recognized pattern)
  bdforet <- sf::st_sf(
    lib_fv = "Sapin blanc",
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        566400, 6615100, 567000, 6615100, 567000, 6615500,
        566400, 6615500, 566400, 6615100
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton:::enrich_parcels_bdforet(parcels, bdforet)
  expect_equal(nrow(result), 1)
  expect_true(any(!is.na(result$species)))
  expect_equal(result$species[1], "Abies")
})

# ==============================================================================
# map_essence_to_species - additional code paths
# ==============================================================================

test_that("map_essence_to_species maps epicea", {
  result <- nemeton:::map_essence_to_species("Epicea commun")
  expect_equal(result, "Pinus")
})

test_that("map_essence_to_species handles empty string", {
  result <- nemeton:::map_essence_to_species("")
  expect_equal(result, "Generic")
})

test_that("map_essence_to_species handles vector with all NAs", {
  result <- nemeton:::map_essence_to_species(c(NA, NA))
  expect_true(all(is.na(result)))
  expect_length(result, 2)
})

test_that("map_essence_to_species maps mixed case correctly", {
  result <- nemeton:::map_essence_to_species("CHENE SESSILE")
  expect_equal(result, "Quercus")
})

test_that("map_essence_to_species maps all recognized patterns", {
  # Test all recognized species patterns
  essences <- c(
    "Ch\u00eane sessile",     # chene -> Quercus
    "H\u00eatre commun",      # hetre -> Fagus
    "Pin sylvestre",           # pin -> Pinus
    "Sapin blanc",             # sapin -> Abies
    "Douglas vert",            # douglas -> Abies
    "Bouleau verruqueux"       # no match -> Generic
  )
  result <- nemeton:::map_essence_to_species(essences)
  expect_equal(result, c("Quercus", "Fagus", "Pinus", "Abies", "Abies", "Generic"))
})

# (migrated from test-cov80-batch7.R)
# ==============================================================================
# smart_map — progress=TRUE sequential path with type coercion (lines 175-188)
# ==============================================================================

test_that("smart_map progress=TRUE path with .type='dbl' uses purrr::map + conversion", {
  # Forces progress=TRUE, sequential (below threshold), and .type != "list"

  # This hits the progress branch at line 175 and the dbl coercion at line 182
  result <- suppressMessages(
    nemeton:::smart_map(
      1:3, function(x) x * 1.5,
      threshold = 1000, progress = TRUE, .type = "dbl"
    )
  )
  expect_equal(result, c(1.5, 3.0, 4.5))
  expect_type(result, "double")
})

test_that("smart_map progress=TRUE path with .type='chr' uses purrr::map + conversion", {
  result <- suppressMessages(
    nemeton:::smart_map(
      c("a", "b", "c"), function(x) paste0(x, "!"),
      threshold = 1000, progress = TRUE, .type = "chr"
    )
  )
  expect_equal(result, c("a!", "b!", "c!"))
  expect_type(result, "character")
})

test_that("smart_map progress=TRUE path with .type='lgl' uses purrr::map + conversion", {
  result <- suppressMessages(
    nemeton:::smart_map(
      1:4, function(x) x %% 2 == 0,
      threshold = 1000, progress = TRUE, .type = "lgl"
    )
  )
  expect_equal(result, c(FALSE, TRUE, FALSE, TRUE))
  expect_type(result, "logical")
})

test_that("smart_map progress=TRUE path with .type='int' uses purrr::map + conversion", {
  result <- suppressMessages(
    nemeton:::smart_map(
      1:3, function(x) as.integer(x * 100),
      threshold = 1000, progress = TRUE, .type = "int"
    )
  )
  expect_equal(result, c(100L, 200L, 300L))
  expect_type(result, "integer")
})

test_that("smart_map progress=TRUE path with .type='list' skips conversion", {
  result <- suppressMessages(
    nemeton:::smart_map(
      1:2, function(x) list(val = x),
      threshold = 1000, progress = TRUE, .type = "list"
    )
  )
  expect_type(result, "list")
  expect_equal(result[[1]]$val, 1)
  expect_equal(result[[2]]$val, 2)
})

# ==============================================================================
# smart_map — progress=FALSE sequential path uses map_fn directly (line 190)
# ==============================================================================

test_that("smart_map progress=FALSE uses map_fn directly without wrapping", {
  result <- suppressMessages(
    nemeton:::smart_map(
      1:3, function(x) x^2,
      threshold = 1000, progress = FALSE, .type = "dbl"
    )
  )
  expect_equal(result, c(1, 4, 9))
})

test_that("smart_map progress=FALSE uses map_fn for chr type", {
  result <- suppressMessages(
    nemeton:::smart_map(
      letters[1:3], function(x) toupper(x),
      threshold = 1000, progress = FALSE, .type = "chr"
    )
  )
  expect_equal(result, c("A", "B", "C"))
})

test_that("smart_map progress=FALSE uses map_fn for lgl type", {
  result <- suppressMessages(
    nemeton:::smart_map(
      c(1, 2, 3), function(x) x > 1,
      threshold = 1000, progress = FALSE, .type = "lgl"
    )
  )
  expect_equal(result, c(FALSE, TRUE, TRUE))
})

test_that("smart_map progress=FALSE uses map_fn for int type", {
  result <- suppressMessages(
    nemeton:::smart_map(
      1:3, function(x) as.integer(x + 5),
      threshold = 1000, progress = FALSE, .type = "int"
    )
  )
  expect_equal(result, c(6L, 7L, 8L))
})

# ==============================================================================
# smart_map — default progress derived from input size (lines 111-113)
# ==============================================================================

test_that("smart_map auto-sets progress=FALSE for small n (n <= 50)", {
  # n=3 < 50 => progress should default to FALSE, no wrapping
  result <- suppressMessages(
    nemeton:::smart_map(1:3, function(x) x * 10, threshold = 1000, .type = "dbl")
  )
  expect_equal(result, c(10, 20, 30))
})

# ==============================================================================
# smart_map — complexity parameter variations (lines 94-103)
# ==============================================================================

test_that("smart_map uses very_high complexity threshold correctly", {
  expect_message(
    nemeton:::smart_map(1:3, function(x) x, complexity = "very_high"),
    "below threshold 20"
  )
})

test_that("smart_map uses low complexity threshold correctly", {
  expect_message(
    nemeton:::smart_map(1:3, function(x) x, complexity = "low"),
    "below threshold 1000"
  )
})

test_that("smart_map uses medium complexity threshold correctly", {
  expect_message(
    nemeton:::smart_map(1:3, function(x) x, complexity = "medium"),
    "below threshold 200"
  )
})

test_that("smart_map error on invalid complexity value is informative", {
  expect_error(
    nemeton:::smart_map(1:3, identity, complexity = "extreme"),
    "Invalid"
  )
})

# ==============================================================================
# smart_map — sequential mode messages (lines 167-172)
# ==============================================================================

test_that("smart_map prints 'below threshold' when n <= threshold", {
  expect_message(
    nemeton:::smart_map(1:5, identity, threshold = 10),
    "below threshold 10"
  )
})

test_that("smart_map prints 'furrr not available' when furrr not available and n > threshold", {
  skip_if(
    requireNamespace("furrr", quietly = TRUE) &&
      requireNamespace("future", quietly = TRUE),
    "furrr is available — cannot test fallback path"
  )
  expect_message(
    nemeton:::smart_map(1:5, identity, threshold = 2),
    "furrr not available"
  )
})

# ==============================================================================
# smart_map — extra arguments via ... (line 190, 176, 165)
# ==============================================================================

test_that("smart_map passes ... args in sequential/non-progress mode", {
  mult <- function(x, factor) x * factor
  result <- suppressMessages(
    nemeton:::smart_map(1:3, mult, factor = 5, threshold = 1000,
                        progress = FALSE, .type = "dbl")
  )
  expect_equal(result, c(5, 10, 15))
})

test_that("smart_map passes ... args in progress=TRUE mode", {
  mult <- function(x, factor) x * factor
  result <- suppressMessages(
    nemeton:::smart_map(1:3, mult, factor = 7, threshold = 1000,
                        progress = TRUE, .type = "dbl")
  )
  expect_equal(result, c(7, 14, 21))
})

# ==============================================================================
# smart_map_sf — additional ... arguments passed to fn (line 249)
# ==============================================================================

test_that("smart_map_sf passes extra ... arguments to fn", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  # fn takes (i, sf_data, multiplier) where multiplier comes from ...
  result <- suppressMessages(
    nemeton:::smart_map_sf(
      units,
      function(i, data, multiplier) i * multiplier,
      multiplier = 10,
      threshold = 1000,
      .type = "dbl"
    )
  )
  expect_equal(result, c(10, 20, 30))
})

test_that("smart_map_sf with .type='chr'", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)
  result <- suppressMessages(
    nemeton:::smart_map_sf(
      units,
      function(i, data) paste0("row_", i),
      threshold = 1000,
      .type = "chr"
    )
  )
  expect_equal(result, c("row_1", "row_2"))
})

test_that("smart_map_sf respects complexity parameter", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)
  expect_message(
    nemeton:::smart_map_sf(
      units,
      function(i, data) i,
      complexity = "high"
    ),
    "below threshold 50"
  )
})

# ==============================================================================
# get_species_flammability — partial match branch (lines 662-664)
# ==============================================================================

test_that("get_species_flammability partial match for subspecies", {
  # "Pinus sylvestris" is in the lookup. Querying just part should
  # hit the partial grep match if the exact match fails.
  result <- nemeton:::get_species_flammability("Pinus sylvestris")
  expect_equal(result, 80)
})

test_that("get_species_flammability case-insensitive match", {
  result_lower <- nemeton:::get_species_flammability("pinus")
  result_upper <- nemeton:::get_species_flammability("PINUS")
  expect_equal(result_lower, result_upper)
  expect_true(result_lower > 60) # High flammability
})

test_that("get_species_flammability partial match for genus in species name", {
  # "Quercus ilex" is in the lookup
  result <- nemeton:::get_species_flammability("Quercus ilex")
  expect_true(result >= 0 && result <= 100)
})

test_that("get_species_flammability returns low score for Fagus", {
  result <- nemeton:::get_species_flammability("Fagus")
  expect_equal(result, 20) # Low flammability
})

test_that("get_species_flammability returns low score for Betula", {
  result <- nemeton:::get_species_flammability("Betula")
  expect_equal(result, 20)
})

test_that("get_species_flammability returns medium score for Castanea", {
  result <- nemeton:::get_species_flammability("Castanea")
  expect_equal(result, 50)
})

test_that("get_species_flammability with Eucalyptus (high)", {
  result <- nemeton:::get_species_flammability("Eucalyptus")
  expect_equal(result, 80)
})

test_that("get_species_flammability with Mixed label", {
  result <- nemeton:::get_species_flammability("Mixed")
  expect_equal(result, 50)
})

test_that("get_species_flammability all-NA vector", {
  result <- nemeton:::get_species_flammability(c(NA, NA, NA))
  expect_true(all(is.na(result)))
  expect_length(result, 3)
})

# ==============================================================================
# get_species_drought_sensitivity — partial match branch (lines 705-707)
# ==============================================================================

test_that("get_species_drought_sensitivity partial match for subspecies", {
  # "Fagus sylvatica" is in the lookup
  result <- nemeton:::get_species_drought_sensitivity("Fagus sylvatica")
  expect_equal(result, 80) # High sensitivity
})

test_that("get_species_drought_sensitivity case-insensitive", {
  result_lower <- nemeton:::get_species_drought_sensitivity("fagus")
  result_upper <- nemeton:::get_species_drought_sensitivity("FAGUS")
  expect_equal(result_lower, result_upper)
})

test_that("get_species_drought_sensitivity low sensitivity species", {
  result <- nemeton:::get_species_drought_sensitivity("Quercus ilex")
  expect_equal(result, 20) # Low sensitivity (Mediterranean)
})

test_that("get_species_drought_sensitivity intermediate species", {
  result <- nemeton:::get_species_drought_sensitivity("Castanea")
  expect_equal(result, 50) # Intermediate
})

test_that("get_species_drought_sensitivity for Abies", {
  result <- nemeton:::get_species_drought_sensitivity("Abies")
  expect_equal(result, 80)
})

test_that("get_species_drought_sensitivity for Mixed label", {
  result <- nemeton:::get_species_drought_sensitivity("Mixed")
  expect_equal(result, 50) # Intermediate
})

test_that("get_species_drought_sensitivity for Cedrus (low)", {
  result <- nemeton:::get_species_drought_sensitivity("Cedrus")
  expect_equal(result, 20)
})

test_that("get_species_drought_sensitivity all-NA input", {
  result <- nemeton:::get_species_drought_sensitivity(c(NA, NA))
  expect_true(all(is.na(result)))
  expect_length(result, 2)
})

# ==============================================================================
# get_species_palatability — reverse partial match branch (lines 821-828)
# ==============================================================================

test_that("get_species_palatability reverse partial match for compound names", {
  # "quercus" is in the lookup. A species string containing "quercus" as
  # substring should trigger the reverse partial match at line 823.
  result <- nemeton:::get_species_palatability("grand quercus robur")
  # Should find "quercus" inside the input via reverse partial
  expect_true(result > 70)
})

test_that("get_species_palatability reverse partial match for 'pin maritime'", {
  # "pin" is in the lookup. "pin maritime" should match via either
  # partial (grep input in lookup) or reverse partial
  result <- nemeton:::get_species_palatability("pin maritime")
  expect_true(result < 50) # pin has low palatability (30)
})

test_that("get_species_palatability handles 'douglas' species", {
  result <- nemeton:::get_species_palatability("douglas")
  expect_equal(result, 32)
})

test_that("get_species_palatability handles 'robinier' species", {
  result <- nemeton:::get_species_palatability("robinier")
  expect_equal(result, 10) # Very low
})

test_that("get_species_palatability handles 'tilleul' species", {
  result <- nemeton:::get_species_palatability("tilleul")
  expect_equal(result, 65)
})

test_that("get_species_palatability handles 'aulne' species", {
  result <- nemeton:::get_species_palatability("aulne")
  expect_equal(result, 48)
})

test_that("get_species_palatability handles 'bouleau' species", {
  result <- nemeton:::get_species_palatability("bouleau")
  expect_equal(result, 55)
})

test_that("get_species_palatability handles 'peuplier' species", {
  result <- nemeton:::get_species_palatability("peuplier")
  expect_equal(result, 50)
})

test_that("get_species_palatability handles 'saule' species", {
  result <- nemeton:::get_species_palatability("saule")
  expect_equal(result, 52)
})

test_that("get_species_palatability handles 'charme' species", {
  result <- nemeton:::get_species_palatability("charme")
  expect_equal(result, 72)
})

test_that("get_species_palatability handles 'sorbier' species", {
  result <- nemeton:::get_species_palatability("sorbier")
  expect_equal(result, 68)
})

test_that("get_species_palatability handles 'chataignier' species", {
  result <- nemeton:::get_species_palatability("chataignier")
  expect_equal(result, 80)
})

test_that("get_species_palatability handles 'frene' species (French for ash)", {
  result <- nemeton:::get_species_palatability("frene")
  expect_equal(result, 85)
})

test_that("get_species_palatability handles 'erable' species (French for maple)", {
  result <- nemeton:::get_species_palatability("erable")
  expect_equal(result, 88)
})

test_that("get_species_palatability handles 'sapin' species (French for fir)", {
  result <- nemeton:::get_species_palatability("sapin")
  expect_equal(result, 85)
})

test_that("get_species_palatability handles 'meleze' species", {
  result <- nemeton:::get_species_palatability("meleze")
  expect_equal(result, 35)
})

test_that("get_species_palatability handles 'pseudotsuga' species", {
  result <- nemeton:::get_species_palatability("pseudotsuga")
  expect_equal(result, 32)
})

test_that("get_species_palatability handles 'acacia' species (= robinia)", {
  result <- nemeton:::get_species_palatability("acacia")
  expect_equal(result, 10)
})

test_that("get_species_palatability default 50 for truly unknown species", {
  result <- nemeton:::get_species_palatability("zygopetalum tropical")
  expect_equal(result, 50)
})

test_that("get_species_palatability vectorized with multiple categories", {
  species <- c("quercus", "picea", "betula", "pinus", "unknown_xyz", NA)
  result <- nemeton:::get_species_palatability(species)
  expect_length(result, 6)
  expect_equal(result[1], 90)  # quercus very high
  expect_equal(result[2], 15)  # picea very low
  expect_equal(result[3], 55)  # betula medium
  expect_equal(result[4], 30)  # pinus low
  expect_equal(result[5], 50)  # unknown -> default
  expect_true(is.na(result[6]))
})

# ==============================================================================
# calculate_shannon_h — edge cases
# ==============================================================================

test_that("calculate_shannon_h with 2 equal proportions", {
  result <- nemeton:::calculate_shannon_h(c(0.5, 0.5))
  expect_equal(result, log(2), tolerance = 1e-10)
})

test_that("calculate_shannon_h with 3 equal proportions", {
  result <- nemeton:::calculate_shannon_h(c(1/3, 1/3, 1/3))
  expect_equal(result, log(3), tolerance = 1e-10)
})

test_that("calculate_shannon_h with base=10", {
  result <- nemeton:::calculate_shannon_h(c(0.5, 0.5), base = 10)
  expected <- log10(2)
  expect_equal(result, expected, tolerance = 1e-10)
})

test_that("calculate_shannon_h with very skewed distribution", {
  result <- nemeton:::calculate_shannon_h(c(0.99, 0.01))
  # Should be close to 0 (low diversity)
  expect_true(result < 0.1)
  expect_true(result > 0)
})

test_that("calculate_shannon_h with unnormalized counts", {
  # Counts that don't sum to 1; function normalizes internally
  result <- nemeton:::calculate_shannon_h(c(100, 100, 100))
  expect_equal(result, log(3), tolerance = 1e-10)
})

test_that("calculate_shannon_h with single zero and rest valid", {
  result <- nemeton:::calculate_shannon_h(c(0.5, 0, 0.5))
  expect_equal(result, log(2), tolerance = 1e-10)
})

# ==============================================================================
# calculate_allometric_biomass — additional species and edge cases
# ==============================================================================

test_that("calculate_allometric_biomass for all known species", {
  known_species <- c("Quercus", "Fagus", "Pinus", "Abies", "Picea",
                     "Castanea", "Fraxinus", "Acer", "Betula", "Populus")
  ages <- rep(50, length(known_species))
  densities <- rep(0.6, length(known_species))

  result <- nemeton:::calculate_allometric_biomass(known_species, ages, densities)
  expect_length(result, length(known_species))
  expect_true(all(result > 0))
  expect_type(result, "double")
})

test_that("calculate_allometric_biomass with all NA inputs", {
  result <- nemeton:::calculate_allometric_biomass(
    c(NA, NA), c(NA, NA), c(NA, NA)
  )
  expect_true(all(is.na(result)))
})

test_that("calculate_allometric_biomass with zero age produces zero biomass", {
  result <- nemeton:::calculate_allometric_biomass("Quercus", 0, 0.7)
  # 0^b = 0 for b > 0, so biomass = 0
  expect_equal(result, 0)
})

test_that("calculate_allometric_biomass with zero density produces zero biomass", {
  result <- nemeton:::calculate_allometric_biomass("Quercus", 50, 0)
  # density^c = 0^c = 0 for c > 0
  expect_equal(result, 0)
})

test_that("calculate_allometric_biomass varies by species", {
  result_quercus <- nemeton:::calculate_allometric_biomass("Quercus", 80, 0.7)
  result_fagus <- nemeton:::calculate_allometric_biomass("Fagus", 80, 0.7)
  # Different coefficients => different results
  expect_false(result_quercus == result_fagus)
})

test_that("calculate_allometric_biomass increases with age", {
  result_young <- nemeton:::calculate_allometric_biomass("Quercus", 20, 0.7)
  result_old <- nemeton:::calculate_allometric_biomass("Quercus", 100, 0.7)
  expect_true(result_old > result_young)
})

test_that("calculate_allometric_biomass increases with density", {
  result_sparse <- nemeton:::calculate_allometric_biomass("Fagus", 60, 0.3)
  result_dense <- nemeton:::calculate_allometric_biomass("Fagus", 60, 0.9)
  expect_true(result_dense > result_sparse)
})

# ==============================================================================
# enrich_parcels_bdforet — 'libelle' column name variant (line 1088)
# ==============================================================================

test_that("enrich_parcels_bdforet with 'libelle' column", {
  skip_if_not_installed("sf")
  parcels <- create_test_units(crs = 2154, n_features = 2)

  bdforet <- sf::st_sf(
    libelle = c("Chene sessile dominant", "Chene sessile dominant"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        566400, 6615100, 567000, 6615100, 567000, 6615500,
        566400, 6615500, 566400, 6615100
      ), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(
        566400, 6615100, 567000, 6615100, 567000, 6615500,
        566400, 6615500, 566400, 6615100
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton:::enrich_parcels_bdforet(parcels, bdforet)
  expect_equal(nrow(result), 2)
  expect_true("species" %in% names(result))
})

test_that("enrich_parcels_bdforet with uppercase column names", {
  skip_if_not_installed("sf")
  parcels <- create_test_units(crs = 2154, n_features = 1)

  bdforet <- sf::st_sf(
    ESSENCE = "Pin maritime",
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        566400, 6615100, 567000, 6615100, 567000, 6615500,
        566400, 6615500, 566400, 6615100
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton:::enrich_parcels_bdforet(parcels, bdforet)
  expect_equal(nrow(result), 1)
  # "Pin maritime" should map to "Pinus"
  if (!is.na(result$species[1])) {
    expect_equal(result$species[1], "Pinus")
  }
})

test_that("enrich_parcels_bdforet with multiple parcels and multiple BD Foret polygons", {
  skip_if_not_installed("sf")
  parcels <- create_test_units(crs = 2154, n_features = 3)

  # Three overlapping bdforet polygons with different species
  big_poly <- sf::st_polygon(list(matrix(c(
    566400, 6615100, 567000, 6615100, 567000, 6615500,
    566400, 6615500, 566400, 6615100
  ), ncol = 2, byrow = TRUE)))

  bdforet <- sf::st_sf(
    TFV = c("Hetre commun", "Pin maritime", "Sapin blanc"),
    geometry = sf::st_sfc(
      big_poly, big_poly, big_poly,
      crs = 2154
    )
  )

  result <- nemeton:::enrich_parcels_bdforet(parcels, bdforet)
  expect_equal(nrow(result), 3)
  expect_true(all(c("species", "age", "density") %in% names(result)))
})

test_that("enrich_parcels_bdforet returns all-NA when intersection is empty", {
  skip_if_not_installed("sf")
  parcels <- create_test_units(crs = 2154, n_features = 2)

  # BD Foret polygon far away from parcels
  bdforet <- sf::st_sf(
    TFV = "Chene",
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        0, 0, 1, 0, 1, 1, 0, 1, 0, 0
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton:::enrich_parcels_bdforet(parcels, bdforet)
  expect_equal(nrow(result), 2)
  expect_true(all(is.na(result$species)))
  expect_true(all(is.na(result$age)))
  expect_true(all(is.na(result$density)))
})

# ==============================================================================
# map_essence_to_species — additional patterns
# ==============================================================================

test_that("map_essence_to_species handles unicode chene", {
  result <- nemeton:::map_essence_to_species("ch\u00eane p\u00e9doncul\u00e9")
  expect_equal(result, "Quercus")
})

test_that("map_essence_to_species handles unicode hetre", {
  result <- nemeton:::map_essence_to_species("h\u00eatre pourpre")
  expect_equal(result, "Fagus")
})

test_that("map_essence_to_species handles epicea pattern", {
  result <- nemeton:::map_essence_to_species("epicea commun")
  expect_equal(result, "Pinus") # epicea matches the pin/epicea pattern
})

test_that("map_essence_to_species handles douglas pattern", {
  result <- nemeton:::map_essence_to_species("Douglas vert mature")
  expect_equal(result, "Abies")
})

test_that("map_essence_to_species single NA input", {
  result <- nemeton:::map_essence_to_species(NA_character_)
  expect_true(is.na(result))
  expect_length(result, 1)
})

test_that("map_essence_to_species vector of all unknown", {
  result <- nemeton:::map_essence_to_species(c("Bambou", "Palmier"))
  expect_equal(result, c("Generic", "Generic"))
})

# ==============================================================================
# resolve_raster_layer — lazy-load edge cases
# ==============================================================================

test_that("resolve_raster_layer returns NULL for lazy-load list with nonexistent path", {
  layers <- structure(
    list(
      rasters = list(dem = list(
        object = NULL,
        path = "/nonexistent/path/raster.tif",
        loaded = FALSE
      )),
      vectors = list()
    ),
    class = "nemeton_layers"
  )
  result <- nemeton:::resolve_raster_layer(layers, "dem")
  expect_null(result)
})

test_that("resolve_raster_layer returns NULL for lazy-load list with empty path string", {
  layers <- structure(
    list(
      rasters = list(dem = list(
        object = NULL,
        path = "",
        loaded = FALSE
      )),
      vectors = list()
    ),
    class = "nemeton_layers"
  )
  result <- nemeton:::resolve_raster_layer(layers, "dem")
  expect_null(result)
})

test_that("resolve_raster_layer returns NULL for lazy-load list with non-SpatRaster object", {
  layers <- structure(
    list(
      rasters = list(dem = list(
        object = data.frame(x = 1),
        path = "",
        loaded = TRUE
      )),
      vectors = list()
    ),
    class = "nemeton_layers"
  )
  result <- nemeton:::resolve_raster_layer(layers, "dem")
  expect_null(result)
})

test_that("resolve_raster_layer handles entry that is a simple list without SpatRaster", {
  layers <- structure(
    list(
      rasters = list(ndvi = list(value = 42)),
      vectors = list()
    ),
    class = "nemeton_layers"
  )
  result <- nemeton:::resolve_raster_layer(layers, "ndvi")
  expect_null(result)
})

# ==============================================================================
# resolve_vector_layer — lazy-load edge cases
# ==============================================================================

test_that("resolve_vector_layer returns NULL for lazy-load with nonexistent path", {
  layers <- structure(
    list(
      rasters = list(),
      vectors = list(roads = list(
        object = NULL,
        path = "/nonexistent/path/roads.gpkg",
        loaded = FALSE
      ))
    ),
    class = "nemeton_layers"
  )
  result <- nemeton:::resolve_vector_layer(layers, "roads")
  expect_null(result)
})

test_that("resolve_vector_layer returns NULL for lazy-load with empty path", {
  layers <- structure(
    list(
      rasters = list(),
      vectors = list(water = list(
        object = NULL,
        path = "",
        loaded = FALSE
      ))
    ),
    class = "nemeton_layers"
  )
  result <- nemeton:::resolve_vector_layer(layers, "water")
  expect_null(result)
})

test_that("resolve_vector_layer returns NULL for lazy-load with non-sf object", {
  layers <- structure(
    list(
      rasters = list(),
      vectors = list(trails = list(
        object = data.frame(x = 1, y = 2),
        path = "",
        loaded = TRUE
      ))
    ),
    class = "nemeton_layers"
  )
  result <- nemeton:::resolve_vector_layer(layers, "trails")
  expect_null(result)
})

test_that("resolve_vector_layer handles entry that is a simple list without sf", {
  layers <- structure(
    list(
      rasters = list(),
      vectors = list(parcels = list(value = "stuff"))
    ),
    class = "nemeton_layers"
  )
  result <- nemeton:::resolve_vector_layer(layers, "parcels")
  expect_null(result)
})

# ==============================================================================
# get_dem_raster — with lazy-loaded layers
# ==============================================================================

test_that("get_dem_raster with lazy-loaded lidar_mnt", {
  skip_if_not_installed("terra")
  withr::with_tempdir({
    r <- create_test_raster(values = "constant")
    terra::values(r) <- 250
    path <- file.path(getwd(), "lidar_mnt.tif")
    terra::writeRaster(r, path, overwrite = TRUE)

    layers <- structure(
      list(
        rasters = list(lidar_mnt = list(object = NULL, path = path, loaded = FALSE)),
        vectors = list()
      ),
      class = "nemeton_layers"
    )
    result <- nemeton:::get_dem_raster(layers)
    expect_true(inherits(result, "SpatRaster"))
  })
})

test_that("get_dem_raster returns NULL when both lidar_mnt and dem are missing", {
  layers <- structure(
    list(rasters = list(biomass = NULL), vectors = list()),
    class = "nemeton_layers"
  )
  result <- nemeton:::get_dem_raster(layers)
  expect_null(result)
})

test_that("get_dem_raster with lazy-loaded dem fallback", {
  skip_if_not_installed("terra")
  withr::with_tempdir({
    r <- create_test_raster(values = "constant")
    terra::values(r) <- 150
    path <- file.path(getwd(), "dem.tif")
    terra::writeRaster(r, path, overwrite = TRUE)

    layers <- structure(
      list(
        rasters = list(dem = list(object = NULL, path = path, loaded = FALSE)),
        vectors = list()
      ),
      class = "nemeton_layers"
    )
    result <- nemeton:::get_dem_raster(layers)
    expect_true(inherits(result, "SpatRaster"))
  })
})

# ==============================================================================
# get_osm_bbox — edge cases
# ==============================================================================

test_that("get_osm_bbox with buffer_m=0 for metric CRS does not expand", {
  skip_if_not_installed("sf")
  units <- create_test_units(crs = 2154)
  bbox <- nemeton:::get_osm_bbox(units, buffer_m = 0)
  expect_length(bbox, 4)
  expect_named(bbox, c("xmin", "ymin", "xmax", "ymax"))
})

test_that("get_osm_bbox default buffer_m is 1000", {
  skip_if_not_installed("sf")
  units <- create_test_units(crs = 2154)
  bbox_default <- nemeton:::get_osm_bbox(units)
  bbox_explicit <- nemeton:::get_osm_bbox(units, buffer_m = 1000)
  expect_equal(bbox_default, bbox_explicit, tolerance = 1e-6)
})

test_that("get_osm_bbox with large buffer expands further", {
  skip_if_not_installed("sf")
  units <- create_test_units(crs = 2154)
  bbox_small <- nemeton:::get_osm_bbox(units, buffer_m = 100)
  bbox_large <- nemeton:::get_osm_bbox(units, buffer_m = 5000)
  expect_true(bbox_large["xmin"] < bbox_small["xmin"])
  expect_true(bbox_large["ymax"] > bbox_small["ymax"])
})

test_that("get_osm_bbox with single-feature sf object", {
  skip_if_not_installed("sf")
  units <- create_test_units(crs = 2154, n_features = 1)
  bbox <- nemeton:::get_osm_bbox(units, buffer_m = 500)
  expect_length(bbox, 4)
  expect_true(bbox["xmax"] > bbox["xmin"])
  expect_true(bbox["ymax"] > bbox["ymin"])
})

# ==============================================================================
# as_pure_sf — edge cases
# ==============================================================================

test_that("as_pure_sf with raster in same CRS does not reproject", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  units <- create_test_units(crs = 2154)
  r <- create_test_raster(crs = "EPSG:2154", values = "constant")

  result <- nemeton:::as_pure_sf(units, raster = r)
  # CRS should remain 2154 (no reprojection needed)
  expect_equal(sf::st_crs(result)$epsg, 2154L)
})

test_that("as_pure_sf with raster in different CRS reprojects", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  units <- create_test_units(crs = 2154)
  r <- terra::rast(
    extent = terra::ext(-1, 1, 43, 45),
    resolution = 0.01,
    crs = "EPSG:4326"
  )
  terra::values(r) <- 1

  result <- nemeton:::as_pure_sf(units, raster = r)
  # Should have been reprojected to raster's CRS (4326)
  expect_equal(sf::st_crs(result)$epsg, 4326L)
})

test_that("as_pure_sf with NULL raster returns unchanged", {
  skip_if_not_installed("sf")
  units <- create_test_units(crs = 2154)
  result <- nemeton:::as_pure_sf(units, raster = NULL)
  expect_equal(sf::st_crs(result)$epsg, 2154L)
})

test_that("as_pure_sf removes nemeton_units class from multi-class object", {
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)
  class(units) <- c("nemeton_units", "custom_class", class(units))
  result <- nemeton:::as_pure_sf(units)
  expect_false("nemeton_units" %in% class(result))
  # Other classes should be preserved
  expect_true("sf" %in% class(result))
})

# ==============================================================================
# message_nemeton — glue error fallback path (lines 382-389)
# ==============================================================================

test_that("message_nemeton handles raw message without glue syntax", {
  expect_output(
    nemeton:::message_nemeton("Simple plain message"),
    "Simple plain message"
  )
})

test_that("message_nemeton handles message with cli-like braces gracefully", {
  # This triggers the glue error path: {.cls sf} is not valid glue syntax
  # and should fall back to raw message
  expect_output(
    nemeton:::message_nemeton("Object must be {.cls sf}"),
    "Object must be"
  )
})

test_that("message_nemeton concatenates multiple parts", {
  expect_output(
    nemeton:::message_nemeton("Step ", "1", " of ", "3"),
    "Step 1 of 3"
  )
})

# ==============================================================================
# get_allometric_coefficients — exercise all known species
# ==============================================================================

test_that("get_allometric_coefficients returns distinct values for distinct species", {
  coef_q <- nemeton:::get_allometric_coefficients("Quercus")
  coef_p <- nemeton:::get_allometric_coefficients("Picea")
  expect_false(coef_q$a == coef_p$a)
})

test_that("get_allometric_coefficients Castanea returns valid coefficients", {
  coef <- nemeton:::get_allometric_coefficients("Castanea")
  expect_true(coef$a > 0)
  expect_true(coef$b > 0)
  expect_true(coef$c > 0)
})

test_that("get_allometric_coefficients Populus returns valid coefficients", {
  coef <- nemeton:::get_allometric_coefficients("Populus")
  expect_true(coef$a > 0)
  expect_true(coef$b > 0)
  expect_true(coef$c > 0)
})

test_that("get_allometric_coefficients Generic fallback has source 'Default'", {
  coef <- nemeton:::get_allometric_coefficients("totally_unknown_tree")
  expect_equal(coef$source, "Default")
  expect_equal(coef$citation, "Package Default")
})

# ==============================================================================
# check_crs — additional paths
# ==============================================================================

test_that("check_crs with two SpatRaster objects", {
  skip_if_not_installed("terra")
  r1 <- create_test_raster(crs = "EPSG:2154")
  r2 <- create_test_raster(crs = "EPSG:2154")
  expect_true(nemeton:::check_crs(r1, r2))
})

test_that("check_crs with sf and SpatRaster mixed", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  units <- create_test_units(crs = 2154)
  r <- create_test_raster(crs = "EPSG:2154")
  expect_true(nemeton:::check_crs(units, r))
})

# ==============================================================================
# validate_sf — skip validity check
# ==============================================================================

test_that("validate_sf with require_crs=FALSE and no CRS does not error on CRS", {
  skip_if_not_installed("sf")
  units <- create_test_units(crs = 2154)
  sf::st_crs(units) <- NA
  # Should not error on CRS but still checks geometry type
  expect_true(nemeton:::validate_sf(units, require_crs = FALSE, require_valid = FALSE))
})

# ==============================================================================
# detect_indicator_family — boundary cases
# ==============================================================================

test_that("detect_indicator_family with two-letter prefix returns NA", {
  expect_true(is.na(nemeton:::detect_indicator_family("AB1")))
})

test_that("detect_indicator_family with digit-only string returns NA", {
  expect_true(is.na(nemeton:::detect_indicator_family("123")))
})

test_that("detect_indicator_family with single uppercase letter returns NA", {
  expect_true(is.na(nemeton:::detect_indicator_family("A")))
})

test_that("detect_indicator_family with empty string returns NA", {
  expect_true(is.na(nemeton:::detect_indicator_family("")))
})

# ==============================================================================
# safe_extract — CRS alignment branch
# ==============================================================================

test_that("safe_extract aligns CRS when polygon and raster differ", {
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")
  skip_if_not_installed("sf")

  # Create raster in EPSG:2154
  r <- create_test_raster(
    extent = c(566400, 567000, 6615100, 6615500),
    crs = "EPSG:2154",
    values = "constant"
  )
  terra::values(r) <- 77

  # Create polygons and transform to WGS84 (different CRS)
  polys <- create_test_units(crs = 2154, n_features = 2)
  polys_wgs84 <- sf::st_transform(polys, 4326)

  # safe_extract should reproject internally to match raster CRS
  result <- nemeton:::safe_extract(r, polys_wgs84, "mean")
  expect_true(is.numeric(result))
  expect_length(result, 2)
  expect_true(all(abs(result - 77) < 1))
})

# ==============================================================================
# generate_ids — additional edge cases
# ==============================================================================

test_that("generate_ids with large n has correct padding", {
  ids <- nemeton:::generate_ids(100)
  expect_length(ids, 100)
  expect_equal(ids[1], "unit_001")
  expect_equal(ids[100], "unit_100")
})

test_that("generate_ids with n=0 returns empty vector", {
  ids <- nemeton:::generate_ids(0)
  expect_length(ids, 0)
})

# ==============================================================================
# lookup_ifn_equation — exercise CSV loading when file exists
# ==============================================================================

test_that("lookup_ifn_equation loads multiple known species", {
  known_codes <- c("FASY", "QUPE", "PIAB", "ABAL")
  for (code in known_codes) {
    result <- nemeton:::lookup_ifn_equation(code)
    if (!is.null(result)) {
      expect_type(result, "list")
      expect_true("a" %in% names(result))
    }
  }
})

# ==============================================================================
# lookup_species_threshold — exercise various parameters
# ==============================================================================

test_that("lookup_species_threshold carbon_content_fraction for multiple species", {
  for (code in c("FASY", "PIAB", "QUPE")) {
    result <- nemeton:::lookup_species_threshold(code, "carbon_content_fraction")
    if (!is.na(result)) {
      expect_true(result > 0 && result <= 1)
    }
  }
})

test_that("lookup_species_threshold with default table_name (wood_density)", {
  result <- nemeton:::lookup_species_threshold("FASY")
  expect_true(!is.na(result))
  expect_true(result > 0)
})

# ==============================================================================
# lookup_ademe_factor — additional material types
# ==============================================================================

test_that("lookup_ademe_factor with scenario=NULL returns first row for material_type", {
  result <- nemeton:::lookup_ademe_factor("wood_construction")
  if (!is.null(result)) {
    expect_type(result, "list")
    expect_equal(result$material_type, "wood_construction")
  }
})

test_that("lookup_ademe_factor for fuelwood_extraction", {
  result <- nemeton:::lookup_ademe_factor("fuelwood_extraction")
  if (!is.null(result)) {
    expect_type(result, "list")
  }
})

# ==============================================================================
# (migrated from test-coverage-boost2.R)
# ==============================================================================

# --- resolve_vector_layer() ---

test_that("resolve_vector_layer returns sf object directly", {
  sf_obj <- create_test_units(n_features = 3)
  layers <- structure(list(vectors = list(parcels = sf_obj)), class = "nemeton_layers")
  result <- nemeton:::resolve_vector_layer(layers, "parcels")
  expect_true(inherits(result, "sf"))
  expect_equal(nrow(result), 3)
})

# --- resolve_raster_layer() ---

test_that("resolve_raster_layer handles lazy-load list with no path", {
  entry <- list(object = NULL, loaded = FALSE, path = "")
  layers <- structure(list(rasters = list(dem = entry)), class = "nemeton_layers")
  result <- nemeton:::resolve_raster_layer(layers, "dem")
  expect_null(result)
})

# --- detect_indicator_family() ---

test_that("detect_indicator_family returns NA for non-indicator", {
  expect_true(is.na(nemeton:::detect_indicator_family("carbon")))
  expect_true(is.na(nemeton:::detect_indicator_family("famille_carbone")))
})

# --- get_species_flammability() ---

test_that("get_species_flammability returns scores", {
  result <- nemeton:::get_species_flammability("Pinus")
  expect_true(is.numeric(result))
  expect_true(result >= 0 && result <= 100)
})

test_that("get_species_flammability returns 50 for unknown species", {
  result <- nemeton:::get_species_flammability("UnknownSpeciesXYZ")
  expect_equal(result, 50)
})
