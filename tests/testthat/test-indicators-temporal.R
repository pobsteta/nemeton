# test-indicators-temporal.R
# Tests for Temporal Dynamics Family (T) Indicators
# Aligned with tuto 04 methodology

library(testthat)
library(sf)

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
