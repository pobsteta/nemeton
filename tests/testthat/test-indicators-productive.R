# Test Suite for Productive & Economic Indicators (Family P)
# US2: P1 (volume), P2 (productivity), P3 (quality)

# Helper: create a minimal sf polygon for tests
make_poly <- function(xoff = 0) {
  sf::st_polygon(list(matrix(
    c(xoff, 0, xoff + 1000, 0, xoff + 1000, 1000, xoff, 1000, xoff, 0),
    ncol = 2, byrow = TRUE
  )))
}

make_sf <- function(data, n = NULL) {
  if (is.null(n)) n <- max(sapply(data, length))
  geoms <- lapply(seq_len(n), function(i) make_poly(xoff = (i - 1) * 1000))
  data$geometry <- sf::st_sfc(geoms, crs = 2154)
  sf::st_sf(data)
}

# ==============================================================================
# indicateur_p1_volume (P1)
# ==============================================================================

test_that("indicateur_p1_volume (P1) calculates with IFN equations", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(
    id = 1:3,
    species = c("FASY", "PIAB", "QUPE"),
    dbh = c(35, 28, 42),
    height = c(25, 22, 30),
    density = c(250, 320, 180)
  ))

  result <- indicateur_p1_volume(
    units = test_units,
    species_field = "species",
    dbh_field = "dbh",
    height_field = "height",
    density_field = "density"
  )

  expect_s3_class(result, "sf")
  expect_true("P1" %in% names(result))
  expect_type(result$P1, "double")
  expect_true(all(result$P1 > 0, na.rm = TRUE))
  expect_true(all(result$P1 < 5000, na.rm = TRUE))
})

test_that("indicateur_p1_volume (P1) handles missing height with estimation", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(
    id = 1L,
    species = "FASY",
    dbh = 35,
    density = 250
  ), n = 1)

  # Without height field - should estimate using Naslund approximation
  result <- indicateur_p1_volume(
    units = test_units,
    species_field = "species",
    dbh_field = "dbh",
    density_field = "density"
  )

  expect_true("P1" %in% names(result))
  expect_false(is.na(result$P1[1]))
  expect_true(result$P1[1] > 0)
})

test_that("indicateur_p1_volume validates input is sf", {
  skip_if_not_installed("terra")
  expect_error(
    indicateur_p1_volume(data.frame(x = 1:3)),
    "must be an sf object"
  )
})

test_that("indicateur_p1_volume errors on missing required fields", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(id = 1L), n = 1)

  expect_error(
    indicateur_p1_volume(test_units),
    "Missing required fields"
  )

  # Only species present, still missing dbh and density
  test_units2 <- make_sf(list(id = 1L, species = "FASY"), n = 1)
  expect_error(
    indicateur_p1_volume(test_units2),
    "Missing required fields"
  )
})

test_that("indicateur_p1_volume handles NA species, dbh, and density", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(
    id = 1:4,
    species = c("FASY", NA, "PIAB", "QUPE"),
    dbh = c(35, 30, NA, 42),
    density = c(250, 200, 320, NA)
  ))

  result <- indicateur_p1_volume(
    units = test_units,
    species_field = "species",
    dbh_field = "dbh",
    density_field = "density"
  )

  expect_false(is.na(result$P1[1]))  # All valid

  expect_true(is.na(result$P1[2]))   # NA species
  expect_true(is.na(result$P1[3]))   # NA dbh
  expect_true(is.na(result$P1[4]))   # NA density
})

test_that("indicateur_p1_volume uses height when present but handles NA height", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(
    id = 1:2,
    species = c("FASY", "PIAB"),
    dbh = c(35, 28),
    height = c(25, NA),
    density = c(250, 320)
  ))

  result <- indicateur_p1_volume(
    units = test_units,
    species_field = "species",
    dbh_field = "dbh",
    height_field = "height",
    density_field = "density"
  )

  # Row 1: uses actual height=25
  expect_false(is.na(result$P1[1]))
  # Row 2: height is NA, should use estimation fallback (1.3 + dbh * 0.65)
  expect_false(is.na(result$P1[2]))
  expect_true(result$P1[2] > 0)
})

test_that("indicateur_p1_volume handles unknown species with fallback", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(
    id = 1L,
    species = "UNKNOWN_SPECIES_XYZ",
    dbh = 30,
    density = 200
  ), n = 1)

  # Unknown species should use BROADLEAF_GENUS fallback
  result <- suppressWarnings(
    indicateur_p1_volume(
      test_units,
      species_field = "species",
      dbh_field = "dbh",
      density_field = "density"
    )
  )

  expect_true("P1" %in% names(result))
  expect_false(is.na(result$P1[1]))
})

test_that("indicateur_p1_volume uses custom column name", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(
    id = 1L,
    species = "FASY",
    dbh = 35,
    density = 250
  ), n = 1)

  result <- indicateur_p1_volume(
    test_units,
    species_field = "species",
    dbh_field = "dbh",
    density_field = "density",
    column_name = "volume_m3_ha"
  )

  expect_true("volume_m3_ha" %in% names(result))
  expect_false("P1" %in% names(result))
})

test_that("indicateur_p1_volume works with zero-row sf", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  empty_sf <- sf::st_sf(
    species = character(0),
    dbh = numeric(0),
    density = numeric(0),
    geometry = sf::st_sfc(crs = 2154)
  )

  result <- indicateur_p1_volume(
    units = empty_sf,
    species_field = "species",
    dbh_field = "dbh",
    density_field = "density"
  )

  expect_s3_class(result, "sf")
  expect_true("P1" %in% names(result))
  expect_equal(nrow(result), 0)
})

test_that("indicateur_p1_volume volume differs for different species", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # Same DBH and density, different species should give different volumes
  test_units <- make_sf(list(
    id = 1:2,
    species = c("FASY", "PIAB"),
    dbh = c(35, 35),
    height = c(25, 25),
    density = c(250, 250)
  ))

  result <- indicateur_p1_volume(
    units = test_units,
    species_field = "species",
    dbh_field = "dbh",
    height_field = "height",
    density_field = "density"
  )

  # Different species have different allometric coefficients
  expect_false(result$P1[1] == result$P1[2])
})

test_that("indicateur_p1_volume scales linearly with density", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(
    id = 1:2,
    species = c("FASY", "FASY"),
    dbh = c(35, 35),
    height = c(25, 25),
    density = c(100, 200)
  ))

  result <- indicateur_p1_volume(
    units = test_units,
    species_field = "species",
    dbh_field = "dbh",
    height_field = "height",
    density_field = "density"
  )

  # Volume per ha should be proportional to density
  expect_equal(result$P1[2], result$P1[1] * 2)
})

test_that("indicateur_p1_volume handles conifer species correctly", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(
    id = 1:3,
    species = c("PIAB", "PISY", "PINI"),
    dbh = c(30, 30, 30),
    height = c(20, 20, 20),
    density = c(300, 300, 300)
  ))

  result <- indicateur_p1_volume(
    units = test_units,
    species_field = "species",
    dbh_field = "dbh",
    height_field = "height",
    density_field = "density"
  )

  expect_true(all(!is.na(result$P1)))
  expect_true(all(result$P1 > 0))
})

# ==============================================================================
# indicateur_p2_station (P2)
# ==============================================================================

test_that("indicateur_p2_station (P2) looks up productivity tables", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(
    id = 1:3,
    species = c("FASY", "PIAB", "QUPE"),
    fertility = c(1, 2, 2),
    climate = c("temperate_oceanic", "mountainous", "temperate_oceanic")
  ))

  result <- indicateur_p2_station(
    units = test_units,
    species_field = "species",
    fertility_field = "fertility",
    climate_field = "climate"
  )

  expect_s3_class(result, "sf")
  expect_true("P2" %in% names(result))
  expect_type(result$P2, "double")
  expect_true(all(result$P2 > 0 & result$P2 < 20, na.rm = TRUE))
})

test_that("indicateur_p2_station validates input is sf", {
  skip_if_not_installed("terra")
  expect_error(
    indicateur_p2_station(data.frame(x = 1:3)),
    "must be an sf object"
  )
})

test_that("indicateur_p2_station errors on missing required fields", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(id = 1L), n = 1)

  expect_error(
    indicateur_p2_station(test_units),
    "Missing required fields"
  )

  # Only species present, still missing fertility and climate
  test_units2 <- make_sf(list(id = 1L, species = "FASY"), n = 1)
  expect_error(
    indicateur_p2_station(test_units2),
    "Missing required fields"
  )
})

test_that("indicateur_p2_station handles NA in all key fields", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(
    id = 1:4,
    species = c(NA, "FASY", "PIAB", "QUPE"),
    fertility = c(1, NA, 2, 1),
    climate = c("temperate_oceanic", "mountainous", NA, "temperate_oceanic")
  ))

  result <- indicateur_p2_station(
    units = test_units,
    species_field = "species",
    fertility_field = "fertility",
    climate_field = "climate"
  )

  expect_true(is.na(result$P2[1]))   # NA species
  expect_true(is.na(result$P2[2]))   # NA fertility
  expect_true(is.na(result$P2[3]))   # NA climate
  expect_false(is.na(result$P2[4]))  # All valid
})

test_that("indicateur_p2_station uses custom productivity_table", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  custom_table <- data.frame(
    species_code = c("FASY", "PIAB"),
    fertility_class = c(1, 2),
    climate_zone = c("temperate_oceanic", "mountainous"),
    annual_increment_m3_ha_yr = c(99.9, 88.8),
    stringsAsFactors = FALSE
  )

  test_units <- make_sf(list(
    id = 1:2,
    species = c("FASY", "PIAB"),
    fertility = c(1, 2),
    climate = c("temperate_oceanic", "mountainous")
  ))

  result <- indicateur_p2_station(
    units = test_units,
    species_field = "species",
    fertility_field = "fertility",
    climate_field = "climate",
    productivity_table = custom_table
  )

  expect_equal(result$P2[1], 99.9)
  expect_equal(result$P2[2], 88.8)
})

test_that("indicateur_p2_station falls back to genus average when species/combo not found", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # Use a species+climate combo that does NOT exist in the bundled table
  # but where BROADLEAF_GENUS or CONIFER_GENUS row with matching fertility exists
  custom_table <- data.frame(
    species_code = c("BROADLEAF_GENUS", "CONIFER_GENUS"),
    fertility_class = c(1, 1),
    climate_zone = c("temperate_oceanic", "temperate_oceanic"),
    annual_increment_m3_ha_yr = c(5.5, 9.0),
    stringsAsFactors = FALSE
  )

  test_units <- make_sf(list(
    id = 1L,
    species = "XXXX",  # Not in table
    fertility = 1,
    climate = "temperate_oceanic"
  ), n = 1)

  result <- indicateur_p2_station(
    units = test_units,
    species_field = "species",
    fertility_field = "fertility",
    climate_field = "climate",
    productivity_table = custom_table
  )

  # Should fall back to genus average (mean of BROADLEAF and CONIFER for fertility=1)
  expect_equal(result$P2[1], mean(c(5.5, 9.0)))
})

test_that("indicateur_p2_station returns NA when no fallback available", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # Custom table with no matching rows at all
  custom_table <- data.frame(
    species_code = "ABCD",
    fertility_class = 99,
    climate_zone = "mars",
    annual_increment_m3_ha_yr = 42,
    stringsAsFactors = FALSE
  )

  test_units <- make_sf(list(
    id = 1L,
    species = "FASY",
    fertility = 1,
    climate = "temperate_oceanic"
  ), n = 1)

  result <- indicateur_p2_station(
    units = test_units,
    species_field = "species",
    fertility_field = "fertility",
    climate_field = "climate",
    productivity_table = custom_table
  )

  # No species match, no genus fallback match => NA
  expect_true(is.na(result$P2[1]))
})

test_that("indicateur_p2_station uses custom column name", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(
    id = 1L,
    species = "FASY",
    fertility = 1,
    climate = "temperate_oceanic"
  ), n = 1)

  result <- indicateur_p2_station(
    test_units,
    species_field = "species",
    fertility_field = "fertility",
    climate_field = "climate",
    column_name = "site_index"
  )

  expect_true("site_index" %in% names(result))
  expect_false("P2" %in% names(result))
})

test_that("indicateur_p2_station works with zero-row sf", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  empty_sf <- sf::st_sf(
    species = character(0),
    fertility = integer(0),
    climate = character(0),
    geometry = sf::st_sfc(crs = 2154)
  )

  result <- indicateur_p2_station(
    units = empty_sf,
    species_field = "species",
    fertility_field = "fertility",
    climate_field = "climate"
  )

  expect_s3_class(result, "sf")
  expect_true("P2" %in% names(result))
  expect_equal(nrow(result), 0)
})

test_that("indicateur_p2_station returns correct values for known species", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # FASY fertility=1 temperate_oceanic should be 8.5 according to bundled table
  test_units <- make_sf(list(
    id = 1L,
    species = "FASY",
    fertility = 1,
    climate = "temperate_oceanic"
  ), n = 1)

  result <- indicateur_p2_station(
    units = test_units,
    species_field = "species",
    fertility_field = "fertility",
    climate_field = "climate"
  )

  expect_equal(result$P2[1], 8.5)
})

test_that("indicateur_p2_station handles lowercase species codes", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # The function uses toupper() so lowercase should work
  test_units <- make_sf(list(
    id = 1L,
    species = "fasy",
    fertility = 1,
    climate = "temperate_oceanic"
  ), n = 1)

  result <- indicateur_p2_station(
    units = test_units,
    species_field = "species",
    fertility_field = "fertility",
    climate_field = "climate"
  )

  expect_equal(result$P2[1], 8.5)
})

# ==============================================================================
# indicateur_p3_qualite_bois (P3)
# ==============================================================================

test_that("indicateur_p3_qualite_bois (P3) scores timber quality", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(
    id = 1:3,
    dbh = c(45, 28, 15),
    species = c("FASY", "PIAB", "QUPE"),
    form_score = c(85, 70, 60),
    defects = c(0, 0, 1)
  ))

  result <- indicateur_p3_qualite_bois(
    units = test_units,
    dbh_field = "dbh",
    form_score_field = "form_score",
    defects_field = "defects",
    species_field = "species"
  )

  expect_s3_class(result, "sf")
  expect_true("P3" %in% names(result))
  expect_type(result$P3, "double")
  expect_true(all(result$P3 >= 0 & result$P3 <= 100))
  # Unit 1 (45cm, no defects, high form) > Unit 3 (15cm, defects, lower form)
  expect_true(result$P3[1] > result$P3[3])
})

test_that("indicateur_p3_qualite_bois validates input is sf", {
  skip_if_not_installed("terra")
  expect_error(
    indicateur_p3_qualite_bois(data.frame(x = 1:3)),
    "must be an sf object"
  )
})

test_that("indicateur_p3_qualite_bois errors on missing dbh field", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(id = 1L), n = 1)

  expect_error(
    indicateur_p3_qualite_bois(test_units),
    "Required field missing"
  )
})

test_that("indicateur_p3_qualite_bois handles NA in dbh", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(
    id = 1:2,
    dbh = c(NA, 35),
    species = c("FASY", "FASY")
  ))

  result <- indicateur_p3_qualite_bois(
    test_units,
    dbh_field = "dbh",
    species_field = "species"
  )

  expect_true(is.na(result$P3[1]))
  expect_false(is.na(result$P3[2]))
})

test_that("indicateur_p3_qualite_bois uses generic thresholds when no species field", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # species_field not in the data => generic sawlog=35, pulp=18
  test_units <- make_sf(list(
    id = 1:3,
    dbh = c(40, 25, 10)
  ))

  result <- indicateur_p3_qualite_bois(
    test_units,
    dbh_field = "dbh",
    species_field = "nonexistent_species"
  )

  expect_true("P3" %in% names(result))
  # DBH 40 >= generic sawlog threshold 35 => diameter_score = 100
  # DBH 25: between 18 and 35 => interpolated
  # DBH 10: below 18 => below pulpwood
  expect_true(all(!is.na(result$P3)))
})

test_that("indicateur_p3_qualite_bois applies conifer thresholds for pine species", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # Conifer species matching ^P[IML] pattern
  test_units <- make_sf(list(
    id = 1:3,
    dbh = c(30, 15, 10),
    species = c("PIAB", "PISY", "PINI")
  ))

  result <- indicateur_p3_qualite_bois(
    test_units,
    dbh_field = "dbh",
    species_field = "species"
  )

  # PIAB dbh=30 >= conifer sawlog threshold 30 => diameter_score = 100
  # Expected P3 with default form=70, default defects=85, weights=(0.4, 0.4, 0.2)
  # P3[1] = 0.4*70 + 0.4*100 + 0.2*85 = 28 + 40 + 17 = 85
  expect_equal(result$P3[1], 85)

  # PISY dbh=15 == conifer pulp threshold 15 => at threshold
  # diameter_score = 50 + 50 * (15-15)/(30-15) = 50
  # P3[2] = 0.4*70 + 0.4*50 + 0.2*85 = 28 + 20 + 17 = 65
  expect_equal(result$P3[2], 65)
})

test_that("indicateur_p3_qualite_bois applies broadleaf thresholds for non-conifer species", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(
    id = 1:3,
    dbh = c(40, 30, 10),
    species = c("FASY", "QUPE", "CASA")
  ))

  result <- indicateur_p3_qualite_bois(
    test_units,
    dbh_field = "dbh",
    species_field = "species"
  )

  # FASY dbh=40 >= broadleaf sawlog threshold 40 => diameter_score = 100
  # default form=70, default defects=85
  # P3[1] = 0.4*70 + 0.4*100 + 0.2*85 = 85
  expect_equal(result$P3[1], 85)

  # QUPE dbh=30: between broadleaf pulp=20 and sawlog=40
  # diameter_score = 50 + 50 * (30-20)/(40-20) = 50 + 25 = 75
  # P3[2] = 0.4*70 + 0.4*75 + 0.2*85 = 28 + 30 + 17 = 75
  expect_equal(result$P3[2], 75)

  # CASA dbh=10: below broadleaf pulp=20
  # diameter_score = 50 * (10/20) = 25
  # P3[3] = 0.4*70 + 0.4*25 + 0.2*85 = 28 + 10 + 17 = 55
  expect_equal(result$P3[3], 55)
})

test_that("indicateur_p3_qualite_bois handles all three diameter score ranges", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # Use broadleaf (FASY): sawlog=40, pulp=20
  test_units <- make_sf(list(
    id = 1:3,
    dbh = c(50, 30, 5),
    species = c("FASY", "FASY", "FASY"),
    form_score = c(80, 80, 80),
    defects = c(0, 0, 0)
  ))

  result <- indicateur_p3_qualite_bois(
    test_units,
    dbh_field = "dbh",
    form_score_field = "form_score",
    defects_field = "defects",
    species_field = "species"
  )

  # Unit 1: dbh=50 >= 40 => diameter_score = 100
  # P3 = 0.4*80 + 0.4*100 + 0.2*100 = 32+40+20 = 92
  expect_equal(result$P3[1], 92)

  # Unit 2: dbh=30, between 20 and 40 => diameter_score = 50+50*(30-20)/(40-20) = 75
  # P3 = 0.4*80 + 0.4*75 + 0.2*100 = 32+30+20 = 82
  expect_equal(result$P3[2], 82)

  # Unit 3: dbh=5 < 20 => diameter_score = 50*(5/20) = 12.5
  # P3 = 0.4*80 + 0.4*12.5 + 0.2*100 = 32+5+20 = 57
  expect_equal(result$P3[3], 57)
})

test_that("indicateur_p3_qualite_bois uses provided form_score and handles NA", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(
    id = 1:3,
    dbh = c(40, 40, 40),
    species = c("FASY", "FASY", "FASY"),
    form_score = c(90, NA, 50),
    defects = c(0, 0, 0)
  ))

  result <- indicateur_p3_qualite_bois(
    test_units,
    dbh_field = "dbh",
    form_score_field = "form_score",
    defects_field = "defects",
    species_field = "species"
  )

  # All have dbh=40 => diameter_score=100, defects=0 => defects_score=100
  # Unit 1: form=90 => P3 = 0.4*90 + 0.4*100 + 0.2*100 = 36+40+20 = 96
  expect_equal(result$P3[1], 96)
  # Unit 2: form_score NA => defaults to 70 => P3 = 0.4*70+0.4*100+0.2*100 = 28+40+20 = 88
  expect_equal(result$P3[2], 88)
  # Unit 3: form=50 => P3 = 0.4*50+0.4*100+0.2*100 = 20+40+20 = 80
  expect_equal(result$P3[3], 80)
})

test_that("indicateur_p3_qualite_bois handles defects field values and NA", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(
    id = 1:3,
    dbh = c(40, 40, 40),
    species = c("FASY", "FASY", "FASY"),
    form_score = c(80, 80, 80),
    defects = c(0, 1, NA)
  ))

  result <- indicateur_p3_qualite_bois(
    test_units,
    dbh_field = "dbh",
    form_score_field = "form_score",
    defects_field = "defects",
    species_field = "species"
  )

  # All: dbh=40 => diameter_score=100, form=80
  # Unit 1: defects=0 => defects_score=100 => P3 = 0.4*80+0.4*100+0.2*100 = 92
  expect_equal(result$P3[1], 92)
  # Unit 2: defects=1 => defects_score=50 => P3 = 0.4*80+0.4*100+0.2*50 = 82
  expect_equal(result$P3[2], 82)
  # Unit 3: defects=NA => defaults to 85 => P3 = 0.4*80+0.4*100+0.2*85 = 89
  expect_equal(result$P3[3], 89)
})

test_that("indicateur_p3_qualite_bois handles missing optional fields entirely", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(
    id = 1:2,
    dbh = c(40, 30),
    species = c("FASY", "PIAB")
  ))

  # Without form_score and defects columns
  result <- indicateur_p3_qualite_bois(
    test_units,
    dbh_field = "dbh",
    species_field = "species"
  )

  expect_true("P3" %in% names(result))
  expect_true(all(result$P3 >= 0 & result$P3 <= 100))
})

test_that("indicateur_p3_qualite_bois uses custom weights", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(
    id = 1L,
    dbh = 40,
    species = "FASY",
    form_score = 100,
    defects = 0
  ), n = 1)

  custom_weights <- c(form = 0.6, diameter = 0.3, defects = 0.1)

  result <- indicateur_p3_qualite_bois(
    test_units,
    dbh_field = "dbh",
    form_score_field = "form_score",
    defects_field = "defects",
    species_field = "species",
    weights = custom_weights
  )

  # dbh=40 (broadleaf) => diameter_score=100, form=100, defects=0 => defects_score=100
  # P3 = 0.6*100 + 0.3*100 + 0.1*100 = 100
  expect_equal(result$P3[1], 100)

  # Now with different values to verify weight impact
  test_units2 <- make_sf(list(
    id = 1L,
    dbh = 10,
    species = "FASY",
    form_score = 100,
    defects = 1
  ), n = 1)

  result2_default <- indicateur_p3_qualite_bois(
    test_units2,
    dbh_field = "dbh",
    form_score_field = "form_score",
    defects_field = "defects",
    species_field = "species"
  )

  result2_custom <- indicateur_p3_qualite_bois(
    test_units2,
    dbh_field = "dbh",
    form_score_field = "form_score",
    defects_field = "defects",
    species_field = "species",
    weights = custom_weights
  )

  # Different weights => different result
  expect_false(result2_default$P3[1] == result2_custom$P3[1])
})

test_that("indicateur_p3_qualite_bois uses custom column name", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(
    id = 1L,
    dbh = 40,
    species = "FASY",
    form_score = 80,
    defects = 0
  ), n = 1)

  result <- indicateur_p3_qualite_bois(
    test_units,
    dbh_field = "dbh",
    form_score_field = "form_score",
    defects_field = "defects",
    species_field = "species",
    column_name = "quality_score"
  )

  expect_true("quality_score" %in% names(result))
  expect_false("P3" %in% names(result))
})

test_that("indicateur_p3_qualite_bois works with zero-row sf", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  empty_sf <- sf::st_sf(
    dbh = numeric(0),
    species = character(0),
    geometry = sf::st_sfc(crs = 2154)
  )

  result <- indicateur_p3_qualite_bois(
    units = empty_sf,
    dbh_field = "dbh",
    species_field = "species"
  )

  expect_s3_class(result, "sf")
  expect_true("P3" %in% names(result))
  expect_equal(nrow(result), 0)
})

# ==============================================================================
# Cross-function and integration tests
# ==============================================================================

test_that("Productive indicators handle missing data correctly", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(
    id = 1:2,
    species = c("FASY", NA),
    dbh = c(35, 30),
    density = c(250, NA),
    fertility = c(1, 2),
    climate = c("temperate_oceanic", "mountainous")
  ))

  # P1 with missing species or density should return NA
  result_p1 <- indicateur_p1_volume(
    units = test_units,
    species_field = "species",
    dbh_field = "dbh",
    density_field = "density"
  )

  expect_false(is.na(result_p1$P1[1]))
  expect_true(is.na(result_p1$P1[2]))

  # P2 with missing species should return NA
  result_p2 <- indicateur_p2_station(
    units = test_units,
    species_field = "species",
    fertility_field = "fertility",
    climate_field = "climate"
  )

  expect_false(is.na(result_p2$P2[1]))
  expect_true(is.na(result_p2$P2[2]))
})

test_that("Productive family indicators integrate with family system", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(
    id = 1:2,
    species = c("FASY", "PIAB"),
    dbh = c(35, 28),
    height = c(25, 22),
    density = c(250, 320),
    fertility = c(1, 2),
    climate = c("temperate_oceanic", "mountainous"),
    form_score = c(85, 70),
    defects = c(0, 0)
  ))

  # Calculate all P indicators
  result <- test_units %>%
    indicateur_p1_volume(
      species_field = "species",
      dbh_field = "dbh",
      height_field = "height",
      density_field = "density"
    ) %>%
    indicateur_p2_station(
      species_field = "species",
      fertility_field = "fertility",
      climate_field = "climate"
    ) %>%
    indicateur_p3_qualite_bois(
      dbh_field = "dbh",
      form_score_field = "form_score",
      defects_field = "defects",
      species_field = "species"
    )

  # Check all indicators present
  expect_true(all(c("P1", "P2", "P3") %in% names(result)))

  # Create family composite
  result_family <- create_family_index(result, family_codes = "P")

  expect_true("famille_production" %in% names(result_family))
  expect_type(result_family$famille_production, "double")
  expect_true(all(result_family$famille_production > 0))
})

test_that("indicateur_p2_station with species not in table but genus in table", {
  skip_if_not_installed("terra")

  skip_if_not_installed("sf")

  # XXXX is not a species, but BROADLEAF_GENUS with fertility=2 exists in bundled table
  test_units <- make_sf(list(
    id = 1L,
    species = "XXXX",
    fertility = 2,
    climate = "temperate_oceanic"
  ), n = 1)

  result <- indicateur_p2_station(
    units = test_units,
    species_field = "species",
    fertility_field = "fertility",
    climate_field = "climate"
  )

  # Genus rows for fertility=2 in the bundled table:
  # BROADLEAF_GENUS,2,temperate_oceanic,5.0 and CONIFER_GENUS,2,temperate_oceanic,8.0
  # Mean = 6.5
  expect_equal(result$P2[1], mean(c(5.0, 8.0)))
})

test_that("indicateur_p1_volume result preserves original columns", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_sf(list(
    id = 1L,
    species = "FASY",
    dbh = 35,
    height = 25,
    density = 250,
    extra_col = "keep_me"
  ), n = 1)

  result <- indicateur_p1_volume(
    units = test_units,
    species_field = "species",
    dbh_field = "dbh",
    height_field = "height",
    density_field = "density"
  )

  expect_true("extra_col" %in% names(result))
  expect_equal(result$extra_col[1], "keep_me")
})
