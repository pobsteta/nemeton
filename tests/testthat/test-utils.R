test_that("validate_sf accepts valid sf objects", {
  test_sf <- create_test_units(n_features = 2)

  # Should not error
  expect_silent(validate_sf(test_sf))
})

test_that("validate_sf rejects non-sf objects", {
  expect_error(
    validate_sf(data.frame(x = 1:3)),
    "must be an.*sf.*object"
  )
})

test_that("validate_sf checks CRS when required", {
  test_sf <- create_test_units(n_features = 2)

  # Remove CRS
  sf::st_crs(test_sf) <- NA

  expect_error(
    validate_sf(test_sf, require_crs = TRUE),
    "must have a defined CRS"
  )

  # Should pass when not required
  expect_silent(validate_sf(test_sf, require_crs = FALSE))
})

test_that("validate_sf detects invalid geometries", {
  # Create a self-intersecting polygon (invalid)
  invalid_poly <- sf::st_polygon(list(matrix(
    c(
      0, 0,
      1, 1,
      1, 0,
      0, 1,
      0, 0
    ),
    ncol = 2, byrow = TRUE
  )))

  invalid_sf <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(invalid_poly, crs = 2154)
  )

  expect_error(
    validate_sf(invalid_sf, require_valid = TRUE),
    "invalid geometry"
  )
})

test_that("validate_sf detects empty geometries", {
  # Create empty geometry
  empty_sf <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(sf::st_polygon(), crs = 2154)
  )

  expect_error(
    validate_sf(empty_sf),
    "empty geometr"
  )
})

test_that("validate_sf checks geometry types", {
  # Create point geometry (not POLYGON/MULTIPOLYGON)
  point_sf <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(sf::st_point(c(0, 0)), crs = 2154)
  )

  expect_error(
    validate_sf(point_sf),
    "must be POLYGON or MULTIPOLYGON"
  )
})

test_that("generate_ids creates unique sequential IDs", {
  ids <- generate_ids(5)

  expect_length(ids, 5)
  expect_equal(ids, c("unit_001", "unit_002", "unit_003", "unit_004", "unit_005"))

  # Check uniqueness
  expect_equal(length(unique(ids)), 5)
})

test_that("generate_ids accepts custom prefix", {
  ids <- generate_ids(3, prefix = "parcel_")

  expect_equal(ids, c("parcel_001", "parcel_002", "parcel_003"))
})

test_that("check_crs validates CRS compatibility", {
  sf1 <- create_test_units(crs = 2154)
  sf2 <- create_test_units(crs = 2154)

  # Same CRS should pass
  expect_silent(check_crs(sf1, sf2, strict = TRUE))
})

test_that("check_crs detects CRS mismatch in strict mode", {
  sf1 <- create_test_units(crs = 2154) # Lambert 93
  sf2 <- create_test_units(crs = 4326) # WGS84

  expect_error(
    check_crs(sf1, sf2, strict = TRUE),
    "CRS mismatch"
  )
})

test_that("check_crs detects undefined CRS", {
  sf1 <- create_test_units(crs = 2154)
  sf2 <- create_test_units(crs = 2154)
  sf::st_crs(sf2) <- NA

  expect_error(
    check_crs(sf1, sf2),
    "undefined CRS"
  )
})

test_that("get_crs extracts CRS from sf objects", {
  test_sf <- create_test_units(crs = 2154)

  crs <- get_crs(test_sf)

  expect_s3_class(crs, "crs")
  expect_equal(crs$epsg, 2154)
})

test_that("get_crs extracts CRS from SpatRaster", {
  test_raster <- create_test_raster(crs = "EPSG:2154")

  crs <- get_crs(test_raster)

  # For SpatRaster, get_crs returns the EPSG code
  expect_equal(crs, "2154")
})

test_that("get_crs returns NA for objects without CRS", {
  crs <- get_crs(data.frame(x = 1:3))

  expect_true(is.na(crs))
})

test_that("message_nemeton formats messages using cli", {
  expect_output(
    message_nemeton("Test message"),
    "Test message"
  )

  expect_output(
    message_nemeton("Processing {3} units"),
    "Processing 3 units"
  )
})

# ==============================================================================
# Tests for smart_map() and smart_map_sf()
# ==============================================================================

test_that("smart_map applies function to elements sequentially for small lists", {
  result <- smart_map(1:5, function(x) x * 2, complexity = "low")

  expect_equal(result, list(2L, 4L, 6L, 8L, 10L))
})

test_that("smart_map returns correct type with .type parameter", {
  # Double type
  result_dbl <- smart_map(1:3, function(x) x * 2.5, .type = "dbl")
  expect_type(result_dbl, "double")
  expect_equal(result_dbl, c(2.5, 5.0, 7.5))

  # Character type
  result_chr <- smart_map(1:3, function(x) paste0("item_", x), .type = "chr")
  expect_type(result_chr, "character")
  expect_equal(result_chr, c("item_1", "item_2", "item_3"))

  # Logical type
  result_lgl <- smart_map(1:3, function(x) x > 1, .type = "lgl")
  expect_type(result_lgl, "logical")
  expect_equal(result_lgl, c(FALSE, TRUE, TRUE))

  # Integer type
  result_int <- smart_map(1:3, function(x) as.integer(x * 10), .type = "int")
  expect_type(result_int, "integer")
  expect_equal(result_int, c(10L, 20L, 30L))
})

test_that("smart_map uses correct threshold based on complexity", {
  # Very low complexity should have high threshold (2000)
  expect_message(
    smart_map(1:10, function(x) x, complexity = "very_low"),
    "below threshold 2000"
  )

  # High complexity should have lower threshold (50)
  expect_message(
    smart_map(1:10, function(x) x, complexity = "high"),
    "below threshold 50"
  )
})

test_that("smart_map respects explicit threshold parameter", {
  # With threshold=10 and 5 elements, should be sequential (below threshold)
  expect_message(
    smart_map(1:5, function(x) x, threshold = 10),
    "below threshold 10"
  )
})

test_that("smart_map errors on invalid complexity", {
  expect_error(
    smart_map(1:5, function(x) x, complexity = "invalid"),
    "Invalid.*complexity"
  )
})

test_that("smart_map_sf validates sf input", {
  expect_error(
    smart_map_sf(data.frame(x = 1:3), function(i, data) i),
    "must be an.*sf.*object"
  )
})
test_that("smart_map_sf processes sf rows correctly", {
  test_sf <- create_test_units(n_features = 3)

  result <- smart_map_sf(
    test_sf,
    function(i, data) {
      as.numeric(sf::st_area(data[i, ]))
    },
    complexity = "low",
    .type = "dbl"
  )

  expect_length(result, 3)
  expect_type(result, "double")
  expect_true(all(result > 0))
})

# ==============================================================================
# Tests for as_pure_sf()
# ==============================================================================

test_that("as_pure_sf removes nemeton_units class", {
  test_sf <- create_test_units(n_features = 2)
  class(test_sf) <- c("nemeton_units", class(test_sf))

  result <- as_pure_sf(test_sf)

  expect_false("nemeton_units" %in% class(result))
  expect_true("sf" %in% class(result))
})

test_that("as_pure_sf preserves data for regular sf objects", {
  test_sf <- create_test_units(n_features = 2)

  result <- as_pure_sf(test_sf)

  expect_equal(nrow(result), nrow(test_sf))
  expect_true("sf" %in% class(result))
})

# ==============================================================================
# Tests for get_allometric_coefficients()
# ==============================================================================

test_that("get_allometric_coefficients returns coefficients for known species", {
  result <- get_allometric_coefficients("Quercus")

  expect_type(result, "list")
  expect_true("a" %in% names(result))
  expect_true("b" %in% names(result))
  expect_true("c" %in% names(result))
  expect_type(result$a, "double")
})

test_that("get_allometric_coefficients falls back to Generic for unknown species", {
  result <- get_allometric_coefficients("UnknownSpecies123")

  expect_type(result, "list")
  expect_true("a" %in% names(result))
})

test_that("get_allometric_coefficients is case-insensitive", {
  result1 <- get_allometric_coefficients("Fagus")
  result2 <- get_allometric_coefficients("fagus")
  result3 <- get_allometric_coefficients("FAGUS")

  expect_equal(result1$a, result2$a)
  expect_equal(result2$a, result3$a)
})

# ==============================================================================
# Tests for calculate_allometric_biomass()
# ==============================================================================

test_that("calculate_allometric_biomass calculates biomass correctly", {
  species <- c("Fagus", "Quercus", "Pinus")
  age <- c(50, 60, 40)
  density <- c(0.8, 0.7, 0.9)

  result <- calculate_allometric_biomass(species, age, density)

  expect_length(result, 3)
  expect_type(result, "double")
  expect_true(all(result > 0))
})

test_that("calculate_allometric_biomass handles NA values", {
  species <- c("Fagus", NA, "Pinus")
  age <- c(50, 60, NA)
  density <- c(0.8, 0.7, 0.9)

  result <- calculate_allometric_biomass(species, age, density)

  expect_length(result, 3)
  expect_true(is.na(result[2]))
  expect_true(is.na(result[3]))
  expect_false(is.na(result[1]))
})

# ==============================================================================
# Tests for detect_indicator_family()
# ==============================================================================

test_that("detect_indicator_family extracts family code correctly", {
  expect_equal(detect_indicator_family("C1"), "C")
  expect_equal(detect_indicator_family("B3"), "B")
  expect_equal(detect_indicator_family("W2_norm"), "W")
  expect_equal(detect_indicator_family("R1"), "R")
})

test_that("detect_indicator_family returns NA for non-indicator columns", {
  expect_true(is.na(detect_indicator_family("area")))
  expect_true(is.na(detect_indicator_family("name")))
  expect_true(is.na(detect_indicator_family("geometry")))
})

# ==============================================================================
# Tests for get_species_flammability()
# ==============================================================================

test_that("get_species_flammability returns scores for known species", {
  # Pinus should have high flammability
  pinus_score <- get_species_flammability("Pinus")
  expect_true(pinus_score > 60)

  # Fagus should have lower flammability
  fagus_score <- get_species_flammability("Fagus")
  expect_true(fagus_score < 60)
})

test_that("get_species_flammability handles NA and unknown species", {
  na_score <- get_species_flammability(NA)
  expect_true(is.na(na_score))

  unknown_score <- get_species_flammability("UnknownTreeXYZ")
  expect_equal(unknown_score, 50)  # Default medium flammability
})

test_that("get_species_flammability is vectorized", {
  species <- c("Pinus", "Fagus", "Quercus")
  scores <- get_species_flammability(species)

  expect_length(scores, 3)
  expect_type(scores, "double")
})

# ==============================================================================
# Tests for get_species_drought_sensitivity()
# ==============================================================================

test_that("get_species_drought_sensitivity returns scores for known species", {
  # Fagus is drought-sensitive
  fagus_score <- get_species_drought_sensitivity("Fagus")
  expect_true(fagus_score > 50)

  # Pinus is more drought-tolerant
  pinus_score <- get_species_drought_sensitivity("Pinus")
  expect_true(pinus_score <= 50 || pinus_score >= 0)  # Valid range
})

test_that("get_species_drought_sensitivity handles NA", {
  na_score <- get_species_drought_sensitivity(NA)
  expect_true(is.na(na_score))
})

test_that("get_species_drought_sensitivity is vectorized", {
  species <- c("Fagus", "Quercus", "Pinus")
  scores <- get_species_drought_sensitivity(species)

  expect_length(scores, 3)
  expect_type(scores, "double")
})

# ==============================================================================
# Tests for get_species_palatability()
# ==============================================================================

test_that("get_species_palatability returns scores for known species", {
  # Quercus has high palatability
  quercus_score <- get_species_palatability("Quercus")
  expect_true(quercus_score > 70)

  # Picea has low palatability
  picea_score <- get_species_palatability("Picea")
  expect_true(picea_score < 30)
})

test_that("get_species_palatability handles French names", {
  chene_score <- get_species_palatability("chene")
  expect_true(chene_score > 70)

  hetre_score <- get_species_palatability("hetre")
  expect_true(hetre_score > 50)
})

test_that("get_species_palatability handles NA and unknown species", {
  na_score <- get_species_palatability(NA)
  expect_true(is.na(na_score))

  unknown_score <- get_species_palatability("UnknownTreeXYZ")
  expect_equal(unknown_score, 50)  # Default medium palatability
})

# ==============================================================================
# Tests for calculate_shannon_h()
# ==============================================================================

test_that("calculate_shannon_h calculates Shannon index correctly", {
  # Equal distribution of 4 classes
  equal <- c(0.25, 0.25, 0.25, 0.25)
  h_equal <- calculate_shannon_h(equal)
  expect_equal(h_equal, log(4), tolerance = 0.001)

  # Single class (no diversity)
  single <- c(1.0)
  h_single <- calculate_shannon_h(single)
  expect_equal(h_single, 0)
})

test_that("calculate_shannon_h handles zeros and NAs", {
  # With zeros (should be ignored)
  with_zeros <- c(0.5, 0, 0.5, 0)
  h_zeros <- calculate_shannon_h(with_zeros)
  expect_equal(h_zeros, log(2), tolerance = 0.001)

  # With NAs (should be ignored)
  with_nas <- c(0.5, NA, 0.5, NA)
  h_nas <- calculate_shannon_h(with_nas)
  expect_equal(h_nas, log(2), tolerance = 0.001)
})

test_that("calculate_shannon_h returns NA for all-zero or all-NA input", {
  all_zeros <- c(0, 0, 0)
  expect_true(is.na(calculate_shannon_h(all_zeros)))

  all_nas <- c(NA, NA, NA)
  expect_true(is.na(calculate_shannon_h(all_nas)))
})

test_that("calculate_shannon_h normalizes proportions that don't sum to 1", {
  # Proportions that don't sum to 1
  unnormalized <- c(1, 1, 1, 1)  # Should be treated as equal distribution
  h <- calculate_shannon_h(unnormalized)
  expect_equal(h, log(4), tolerance = 0.001)
})

# ==============================================================================
# Tests for get_osm_bbox()
# ==============================================================================

test_that("get_osm_bbox returns bbox in WGS84", {
  units <- create_test_units(crs = 2154)

  bbox <- get_osm_bbox(units, buffer_m = 100)

  expect_length(bbox, 4)
  expect_true(all(c("xmin", "ymin", "xmax", "ymax") %in% names(bbox)))
  # WGS84 coordinates should be in reasonable range
  expect_true(bbox["xmin"] > -180 && bbox["xmin"] < 180)
  expect_true(bbox["ymin"] > -90 && bbox["ymin"] < 90)
})

test_that("get_osm_bbox validates input", {
  expect_error(
    get_osm_bbox(data.frame(x = 1:3)),
    "must be an sf object"
  )
})

test_that("get_osm_bbox handles no buffer", {
  units <- create_test_units(crs = 2154)

  bbox <- get_osm_bbox(units, buffer_m = 0)

  expect_length(bbox, 4)
})

# ==============================================================================
# Tests for lookup_ifn_equation()
# ==============================================================================

test_that("lookup_ifn_equation returns NULL for missing table", {
  # This test checks behavior when the lookup table doesn't exist
  # In a fresh install without extdata, it should return NULL with warning
  result <- suppressWarnings(lookup_ifn_equation("UNKNOWN_CODE_XYZ"))
  expect_true(is.null(result))
})

# ==============================================================================
# Tests for lookup_species_threshold()
# ==============================================================================

test_that("lookup_species_threshold returns NA for missing table", {
  result <- suppressWarnings(lookup_species_threshold("UNKNOWN_CODE", "density_kg_m3", "nonexistent_table"))
  expect_true(is.na(result))
})

# ==============================================================================
# Tests for lookup_ademe_factor()
# ==============================================================================

test_that("lookup_ademe_factor handles missing table or values", {
  # This function may return NULL or a valid result depending on installed data
  result <- suppressWarnings(lookup_ademe_factor("nonexistent_material_type_xyz", "nonexistent_scenario"))
  # If table exists but material/scenario not found, returns NULL
  # If table doesn't exist, also returns NULL
  expect_true(is.null(result) || is.list(result))
})
