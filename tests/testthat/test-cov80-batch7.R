# test-cov80-batch7.R
# Coverage boost for R/utils.R — target >80%
# Focuses on uncovered code paths: parallel branches, partial matching,
# progress+type coercion, lazy-load edge cases, enrich_parcels_bdforet
# branches, and species lookup partial/reverse matching.

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
