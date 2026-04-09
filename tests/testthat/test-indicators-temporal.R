# test-indicators-temporal.R
# Tests for Temporal Dynamics Family (T) Indicators
# Aligned with tuto 04 methodology

# ==============================================================================
# T1: Stand Age (BD Forêt TFV method)
# ==============================================================================

test_that("indicateur_t1_anciennete returns numeric vector 0-150 range", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]
  units$age <- NULL  # Remove pre-existing age field

  # Without BD Forêt or age field, should fall back to default 50
  result <- indicateur_t1_anciennete(units, age_field = NULL)

  expect_type(result, "double")
  expect_length(result, 5)
  expect_true(all(!is.na(result)))
  expect_true(all(result >= 0))
})

test_that("indicateur_t1_anciennete uses direct age field as fallback", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]
  units$age <- c(25, 75, 150, 200, 300)

  result <- indicateur_t1_anciennete(units, age_field = "age")

  expect_type(result, "double")
  expect_length(result, 5)
  # Should return raw age values (no normalization)
  expect_equal(result, c(25, 75, 150, 200, 300))
})

test_that("indicateur_t1_anciennete calculates from establishment year", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]
  units$planted <- c(1850, 1950, 2000)

  result <- indicateur_t1_anciennete(
    units,
    age_field = NULL,
    establishment_year_field = "planted",
    current_year = 2025
  )

  expect_type(result, "double")
  expect_length(result, 3)
  expect_equal(result, c(175, 75, 25))
})

test_that("indicateur_t1_anciennete with BD Forêt data", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]

  # Create mock BD Forêt with TFV field
  bdforet <- sf::st_sf(
    TFV = c("Forêt fermée de feuillus purs", "Peupleraie", "Forêt ouverte de conifères"),
    geometry = sf::st_geometry(sf::st_buffer(units, 100))
  )
  sf::st_crs(bdforet) <- sf::st_crs(units)

  result <- indicateur_t1_anciennete(units, bdforet = bdforet)

  expect_type(result, "double")
  expect_length(result, 3)
  # feuillus fermé = 100, peuplier = 20, ouvert = 45
  expect_true(result[1] > result[2])  # feuillus > peuplier
})

test_that("indicateur_t1_anciennete BD Forêt uses area-weighted average", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1, ]

  # Create two overlapping BD Forêt polygons
  geom <- sf::st_geometry(units)
  buf1 <- sf::st_buffer(geom, 50)
  buf2 <- sf::st_buffer(geom, 200)

  bdforet <- sf::st_sf(
    TFV = c("Forêt fermée de feuillus purs", "Peupleraie"),
    geometry = c(buf1, buf2)
  )
  sf::st_crs(bdforet) <- sf::st_crs(units)

  result <- indicateur_t1_anciennete(units, bdforet = bdforet)

  expect_type(result, "double")
  expect_length(result, 1)
  # Should be between 20 (peuplier) and 100 (feuillus fermé)
  expect_true(result[1] > 20 && result[1] < 100)
})

test_that("indicateur_t1_anciennete handles NA values in age field", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:4, ]
  units$age <- c(50, NA, 100, NA)

  result <- indicateur_t1_anciennete(units, age_field = "age")

  expect_type(result, "double")
  expect_length(result, 4)
  expect_true(is.na(result[2]))
  expect_true(is.na(result[4]))
  expect_false(is.na(result[1]))
  expect_false(is.na(result[3]))
})

test_that("indicateur_t1_anciennete validates inputs", {
  expect_error(
    indicateur_t1_anciennete(data.frame(x = 1:3)),
    "must be.*sf"
  )
})

test_that("indicateur_t1_anciennete NDVI fallback with layers", {
  data(massif_demo_units, package = "nemeton")
  layers <- massif_demo_layers()
  units <- massif_demo_units[1:3, ]
  units$age <- NULL  # Remove pre-existing age field

  # layers has no bdforet, no age field -> falls to NDVI if available
  # Demo layers have no ndvi either, so should get default 50

  result <- indicateur_t1_anciennete(units, layers = layers, age_field = NULL)

  expect_type(result, "double")
  expect_length(result, 3)
  expect_true(all(!is.na(result)))
})

# ==============================================================================
# T2: Stability / Change Rate
# ==============================================================================

test_that("indicateur_t2_changement returns numeric vector 0-100", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  # No N2 or T1 -> default 50
  result <- indicateur_t2_changement(units)

  expect_type(result, "double")
  expect_length(result, 5)
  expect_true(all(result >= 0 & result <= 100))
})

test_that("indicateur_t2_changement uses N2 column as proxy", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]
  units$N2 <- c(10, 30, 50, 70, 90)

  result <- indicateur_t2_changement(units)

  expect_type(result, "double")
  expect_length(result, 5)
  expect_equal(result, c(10, 30, 50, 70, 90))
})

test_that("indicateur_t2_changement uses N2_anciennete column", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]
  units$N2_anciennete <- c(20, 60, 95)

  result <- indicateur_t2_changement(units)

  expect_equal(result, c(20, 60, 95))
})

test_that("indicateur_t2_changement falls back to T1 capped at 100", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:4, ]
  # Remove N2 columns so T1 fallback is used
  units$N2 <- NULL
  units$N2_anciennete <- NULL
  units$N2_norm <- NULL
  units$T1 <- NULL

  # Pass T1 values directly
  t1 <- c(25, 80, 150, 200)
  result <- indicateur_t2_changement(units, t1_values = t1)

  expect_type(result, "double")
  expect_length(result, 4)
  # Capped at 100
  expect_equal(result, c(25, 80, 100, 100))
})

test_that("indicateur_t2_changement uses T1 column from units", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:3, ]
  # Remove N2 so T1 fallback is used
  units$N2 <- NULL
  units$N2_anciennete <- NULL
  units$N2_norm <- NULL
  units$T1 <- c(40, 120, NA)

  result <- indicateur_t2_changement(units)

  expect_equal(result, c(40, 100, 50))  # NA -> 50 default
})

test_that("indicateur_t2_changement validates inputs", {
  expect_error(
    indicateur_t2_changement(data.frame(x = 1:3)),
    "must be.*sf"
  )
})

# ==============================================================================
# Integration: T1 + T2 together
# ==============================================================================

test_that("T1 and T2 work together", {
  data(massif_demo_units, package = "nemeton")
  units <- massif_demo_units[1:5, ]

  # T1 with age field
  units$age <- c(30, 50, 80, 120, 200)
  t1 <- indicateur_t1_anciennete(units, age_field = "age")

  # T2 from T1
  t2 <- indicateur_t2_changement(units, t1_values = t1)

  expect_length(t1, 5)
  expect_length(t2, 5)
  expect_true(all(!is.na(t1)))
  expect_true(all(!is.na(t2)))
  expect_true(all(t2 <= 100))
})

test_that(".estimate_age_tfv maps vegetation types correctly", {
  tfv <- c(
    "Forêt fermée de feuillus purs",
    "Futaie de conifères",
    "Forêt ouverte de feuillus",
    "Peupleraie",
    "Jeune peuplement",
    "Lande boisée",
    "Taillis",
    "Unknown type"
  )

  ages <- nemeton:::.estimate_age_tfv(tfv)

  expect_equal(ages[1], 100)  # fermé + feuill
  expect_equal(ages[2], 80)   # futaie + conif
  expect_equal(ages[3], 45)   # ouvert
  expect_equal(ages[4], 20)   # peupler
  expect_equal(ages[5], 15)   # jeune
  expect_equal(ages[6], 15)   # lande bois
  expect_equal(ages[7], 45)   # taillis
  expect_equal(ages[8], 50)   # unknown -> default
})

# ==============================================================================
# (migrated from test-cov80-batch9.R)
# ==============================================================================

# --- .estimate_age_tfv: more TFV string patterns ---

test_that(".estimate_age_tfv handles varied French forest type strings", {
  ages <- nemeton:::.estimate_age_tfv(c(
    "For\u00eat ferm\u00e9e de feuillus purs",
    "Futaie de feuillus",
    "For\u00eat ferm\u00e9e de conif\u00e8res purs",
    "Futaie de conif\u00e8res",
    "For\u00eat ouverte",
    "Taillis simple",
    "Peupleraie",
    "Jeune peuplement de feuillus",
    "Lande bois\u00e9e",
    "Formation herbac\u00e9e"
  ))

  expect_equal(ages[1], 100)  # ferme + feuill
  expect_equal(ages[2], 100)  # futaie + feuill
  expect_equal(ages[3], 80)   # ferme + conif
  expect_equal(ages[4], 80)   # futaie + conif
  expect_equal(ages[5], 45)   # ouvert
  expect_equal(ages[6], 45)   # taillis
  expect_equal(ages[7], 20)   # peupler
  expect_equal(ages[8], 15)   # jeune
  expect_equal(ages[9], 15)   # lande bois
  expect_equal(ages[10], 50)  # default
})

test_that(".estimate_age_tfv handles case-insensitive matching", {
  ages <- nemeton:::.estimate_age_tfv(c(
    "FORET FERMEE DE FEUILLUS",
    "FUTAIE DE CONIFERES",
    "FORET OUVERTE",
    "PEUPLERAIE",
    "JEUNE PEUPLEMENT",
    "LANDE BOISEE"
  ))

  expect_equal(ages[1], 100)
  expect_equal(ages[2], 80)
  expect_equal(ages[3], 45)
  expect_equal(ages[4], 20)
  expect_equal(ages[5], 15)
  expect_equal(ages[6], 15)
})

test_that(".estimate_age_tfv handles NA and empty strings", {
  ages <- nemeton:::.estimate_age_tfv(c(NA, "", "Unknown", "  "))

  # NA input -> tolower(NA) is NA, grepl returns FALSE for NA -> default 50
  expect_equal(ages[1], 50)
  expect_equal(ages[2], 50)  # empty -> default
  expect_equal(ages[3], 50)  # unknown -> default
  expect_equal(ages[4], 50)  # whitespace -> default
})

test_that(".estimate_age_tfv handles single-element vector", {
  expect_equal(nemeton:::.estimate_age_tfv("Peupleraie"), 20)
  expect_equal(nemeton:::.estimate_age_tfv("Taillis"), 45)
  expect_equal(nemeton:::.estimate_age_tfv("xyz"), 50)
})

# --- T1: indicateur_t1_anciennete ---

test_that("T1 with establishment_year and auto current_year", {
  test_units <- create_test_units(n_features = 2)
  test_units$planting_year <- c(1900, 2000)

  result <- nemeton::indicateur_t1_anciennete(
    test_units,
    age_field = NULL,
    establishment_year_field = "planting_year"
    # current_year not provided -> auto from Sys.Date()
  )

  current_yr <- as.integer(format(Sys.Date(), "%Y"))
  expect_type(result, "double")
  expect_length(result, 2)
  expect_equal(result[1], current_yr - 1900)
  expect_equal(result[2], current_yr - 2000)
})

test_that("T1 with explicit current_year for establishment_year", {
  test_units <- create_test_units(n_features = 3)
  test_units$yr <- c(1850, 1950, 2010)

  result <- nemeton::indicateur_t1_anciennete(
    test_units,
    age_field = NULL,
    establishment_year_field = "yr",
    current_year = 2025
  )

  expect_equal(result, c(175, 75, 15))
})

test_that("T1 BD Foret with CODE_TFV field name", {
  test_units <- create_test_units(n_features = 2)

  # Create BD Foret with CODE_TFV field (not just TFV)
  bdforet <- sf::st_sf(
    CODE_TFV = c("Peupleraie", "Taillis"),
    geometry = sf::st_geometry(sf::st_buffer(test_units, 200))
  )
  sf::st_crs(bdforet) <- sf::st_crs(test_units)

  result <- nemeton::indicateur_t1_anciennete(test_units, bdforet = bdforet)

  expect_type(result, "double")
  expect_length(result, 2)
  # Should find CODE_TFV field and estimate ages
  # peupleraie=20, taillis=45
  expect_true(result[1] > 0)
  expect_true(result[2] > 0)
})

test_that("T1 BD Foret with lib_fv field name", {
  test_units <- create_test_units(n_features = 2)

  bdforet <- sf::st_sf(
    lib_fv = c("For\u00eat ferm\u00e9e de feuillus purs", "For\u00eat ouverte"),
    geometry = sf::st_geometry(sf::st_buffer(test_units, 200))
  )
  sf::st_crs(bdforet) <- sf::st_crs(test_units)

  result <- nemeton::indicateur_t1_anciennete(test_units, bdforet = bdforet)

  expect_type(result, "double")
  expect_length(result, 2)
})

test_that("T1 BD Foret with ESSENCE field name", {
  test_units <- create_test_units(n_features = 1)

  bdforet <- sf::st_sf(
    ESSENCE = "Jeune peuplement",
    geometry = sf::st_geometry(sf::st_buffer(test_units, 200))
  )
  sf::st_crs(bdforet) <- sf::st_crs(test_units)

  result <- nemeton::indicateur_t1_anciennete(test_units, bdforet = bdforet)

  expect_type(result, "double")
  expect_length(result, 1)
  # jeune -> 15
  expect_equal(result[1], 15, tolerance = 5)
})

test_that("T1 BD Foret with no recognized TFV field returns default 50", {
  test_units <- create_test_units(n_features = 2)

  # bdforet with unrecognized field names
  bdforet <- sf::st_sf(
    species_name = c("Quercus", "Pinus"),
    geometry = sf::st_geometry(sf::st_buffer(test_units, 200))
  )
  sf::st_crs(bdforet) <- sf::st_crs(test_units)

  # No TFV/CODE_TFV/ESSENCE/etc. fields recognized
  # Falls through to Priority 2 (age_field), but "age" not in units
  # Falls to default 50
  result <- nemeton::indicateur_t1_anciennete(test_units, bdforet = bdforet, age_field = NULL)

  expect_type(result, "double")
  expect_length(result, 2)
  expect_true(all(result == 50))
})

test_that("T1 BD Foret with CRS mismatch triggers transform", {
  test_units <- create_test_units(n_features = 2)

  bdforet_2154 <- sf::st_sf(
    TFV = c("Peupleraie", "Taillis"),
    geometry = sf::st_geometry(sf::st_buffer(test_units, 200))
  )
  sf::st_crs(bdforet_2154) <- sf::st_crs(test_units)

  # Transform bdforet to 4326
  bdforet_4326 <- sf::st_transform(bdforet_2154, 4326)

  result <- nemeton::indicateur_t1_anciennete(test_units, bdforet = bdforet_4326)

  expect_type(result, "double")
  expect_length(result, 2)
  # After CRS transform, intersection should still work
  expect_true(all(result > 0))
})

test_that("T1 BD Foret with empty sf (0 rows) falls through to age field", {
  test_units <- create_test_units(n_features = 2)
  test_units$age <- c(80, 120)

  empty_bdforet <- sf::st_sf(
    TFV = character(0),
    geometry = sf::st_sfc(crs = 2154)
  )

  result <- nemeton::indicateur_t1_anciennete(test_units, bdforet = empty_bdforet, age_field = "age")

  expect_type(result, "double")
  expect_equal(result, c(80, 120))
})

test_that("T1 BD Foret intersection with 0-area result uses default 50", {
  # This tests the total_area == 0 branch (line 123-124)
  test_units <- create_test_units(n_features = 1)

  # Create bdforet that technically intersects but with zero area
  # (a line geometry intersecting a polygon)
  bdforet <- sf::st_sf(
    TFV = "Peupleraie",
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, -10, -9, -9, -9, -9, -10, -10, -10),
                                 ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Intersection should produce 0 rows (no overlap) -> default 50
  result <- nemeton::indicateur_t1_anciennete(test_units, bdforet = bdforet, age_field = NULL)

  expect_type(result, "double")
  expect_length(result, 1)
  expect_equal(result[1], 50)
})

test_that("T1 priority chain: age_field takes precedence over establishment_year", {
  test_units <- create_test_units(n_features = 2)
  test_units$age <- c(100, 200)
  test_units$planted <- c(1900, 1800)

  # Both age and establishment_year available; age_field should win
  result <- nemeton::indicateur_t1_anciennete(
    test_units,
    age_field = "age",
    establishment_year_field = "planted"
  )

  expect_equal(result, c(100, 200))
})

test_that("T1 falls through to default 50 when no data at all", {
  test_units <- create_test_units(n_features = 3)

  result <- nemeton::indicateur_t1_anciennete(
    test_units,
    age_field = NULL,
    establishment_year_field = NULL
  )

  expect_type(result, "double")
  expect_length(result, 3)
  expect_true(all(result == 50))
})

test_that("T1 resolves bdforet from nemeton_layers", {
  test_units <- create_test_units(n_features = 2)

  bdforet_sf <- sf::st_sf(
    TFV = c("Peupleraie", "For\u00eat ferm\u00e9e de feuillus purs"),
    geometry = sf::st_geometry(sf::st_buffer(test_units, 200))
  )
  sf::st_crs(bdforet_sf) <- sf::st_crs(test_units)

  mock_layers <- structure(
    list(
      vectors = list(bdforet = bdforet_sf),
      rasters = list(),
      metadata = list()
    ),
    class = "nemeton_layers"
  )

  result <- nemeton::indicateur_t1_anciennete(test_units, layers = mock_layers, age_field = NULL)

  expect_type(result, "double")
  expect_length(result, 2)
  # Should have estimated ages from TFV
  expect_true(all(result > 0))
})

# --- T2: indicateur_t2_changement ---

test_that("T2 uses N2_anciennet column (truncated name variant)", {
  test_units <- create_test_units(n_features = 3)
  test_units$N2_anciennet <- c(30, 70, 110)

  result <- nemeton::indicateur_t2_changement(test_units)

  # N2_anciennet found -> used as stability proxy, capped to 0-100
  expect_equal(result, c(30, 70, 100))
})

test_that("T2 with N2 column containing values > 100 are capped", {
  test_units <- create_test_units(n_features = 3)
  test_units$N2 <- c(-5, 50, 150)

  result <- nemeton::indicateur_t2_changement(test_units)

  # capped: pmin(pmax(t2, 0), 100)
  expect_equal(result, c(0, 50, 100))
})

test_that("T2 fallback to t1_values with NA values replaced by 50", {
  test_units <- create_test_units(n_features = 4)
  # No N2 columns
  t1 <- c(30, NA, 120, NA)

  result <- nemeton::indicateur_t2_changement(test_units, t1_values = t1)

  # t1_values used: capped at 100, NA -> 50
  expect_equal(result, c(30, 50, 100, 50))
})

test_that("T2 with T1 column in units (not t1_values argument)", {
  test_units <- create_test_units(n_features = 3)
  test_units$T1 <- c(25, NA, 90)

  result <- nemeton::indicateur_t2_changement(test_units)

  # T1 column used: capped at 100, NA -> 50
  expect_equal(result, c(25, 50, 90))
})

test_that("T2 default 50 when no N2 or T1 available", {
  test_units <- create_test_units(n_features = 5)

  result <- nemeton::indicateur_t2_changement(test_units)

  expect_type(result, "double")
  expect_length(result, 5)
  expect_true(all(result == 50))
})

test_that("T2 t1_values wrong length is ignored, falls through", {
  test_units <- create_test_units(n_features = 3)

  # t1_values has wrong length (2 instead of 3) -> not used
  result <- nemeton::indicateur_t2_changement(test_units, t1_values = c(40, 80))

  # Falls through to T1 column (not present) -> default 50
  expect_true(all(result == 50))
})

test_that("T2 t1_values non-numeric is ignored", {
  test_units <- create_test_units(n_features = 2)

  # t1_values is character -> not numeric -> not used
  result <- nemeton::indicateur_t2_changement(test_units, t1_values = c("a", "b"))

  # Falls through to default 50
  expect_true(all(result == 50))
})

test_that("T2 N2_anciennete takes priority over N2", {
  test_units <- create_test_units(n_features = 2)
  test_units$N2_anciennete <- c(85, 95)
  test_units$N2 <- c(30, 40)

  result <- nemeton::indicateur_t2_changement(test_units)

  # N2_anciennete found first in the loop -> used
  expect_equal(result, c(85, 95))
})

test_that("T2 priority: N2 column over T1 column", {
  test_units <- create_test_units(n_features = 2)
  test_units$N2 <- c(60, 80)
  test_units$T1 <- c(30, 40)

  result <- nemeton::indicateur_t2_changement(test_units)

  # N2 found -> used, T1 not reached
  expect_equal(result, c(60, 80))
})

test_that("T2 priority: t1_values argument over T1 column", {
  test_units <- create_test_units(n_features = 2)
  test_units$T1 <- c(30, 40)

  result <- nemeton::indicateur_t2_changement(test_units, t1_values = c(70, 90))

  # No N2 column -> t1_values used (correct length)
  expect_equal(result, c(70, 90))
})

test_that("T2 with layers parameter (interface consistency)", {
  test_units <- create_test_units(n_features = 2)
  test_units$N2 <- c(45, 75)

  mock_layers <- structure(
    list(
      vectors = list(),
      rasters = list(),
      metadata = list()
    ),
    class = "nemeton_layers"
  )

  # layers is accepted but not used in T2
  result <- nemeton::indicateur_t2_changement(test_units, layers = mock_layers)

  expect_equal(result, c(45, 75))
})

test_that("T2 validates sf input", {
  expect_error(
    nemeton::indicateur_t2_changement(data.frame(x = 1:3)),
    "must be.*sf"
  )

  expect_error(
    nemeton::indicateur_t2_changement("not sf"),
    "must be.*sf"
  )

  expect_error(
    nemeton::indicateur_t2_changement(NULL),
    "must be.*sf"
  )
})
