# Test Suite for Package Datasets
# massif_demo_units with 12-family referential

test_that("massif_demo_units has correct structure", {
  skip_if_not_installed("sf")

  data("massif_demo_units", package = "nemeton")

  expect_s3_class(massif_demo_units, "sf")
  expect_equal(nrow(massif_demo_units), 20)
  expect_true("geometry" %in% names(massif_demo_units))
  expect_true("parcel_id" %in% names(massif_demo_units))
  expect_equal(sf::st_crs(massif_demo_units)$epsg, 2154)
})

test_that("massif_demo_units has all 29 indicators present", {
  skip_if_not_installed("sf")

  data("massif_demo_units", package = "nemeton")

  required_indicators <- c(
    "C1", "C2", "B1", "B2", "B3", "W1", "W2", "W3", "A1", "A2",
    "F1", "F2", "L1", "L2", "T1", "T2", "R1", "R2", "R3",
    "S1", "S2", "S3", "P1", "P2", "P3", "E1", "E2", "N1", "N2", "N3"
  )

  missing_indicators <- setdiff(required_indicators, names(massif_demo_units))
  expect_length(missing_indicators, 0)

  for (ind in required_indicators) {
    expect_type(massif_demo_units[[ind]], "double")
    expect_true(any(!is.na(massif_demo_units[[ind]])))
  }
})

test_that("massif_demo_units has all 12 family composites in valid range", {
  skip_if_not_installed("sf")

  data("massif_demo_units", package = "nemeton")

  required_families <- paste0("family_", c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N"))

  missing_families <- setdiff(required_families, names(massif_demo_units))
  expect_length(missing_families, 0)

  for (fam in required_families) {
    expect_type(massif_demo_units[[fam]], "double")
    values <- massif_demo_units[[fam]]
    expect_true(all(values >= 0 & values <= 100, na.rm = TRUE))
    expect_true(any(!is.na(values)))
  }
})

test_that("massif_demo_units has base attributes", {
  skip_if_not_installed("sf")

  data("massif_demo_units", package = "nemeton")

  # Base attributes from original massif_demo_units
  expect_true("parcel_id" %in% names(massif_demo_units))
  expect_true("species" %in% names(massif_demo_units))
  expect_true("age" %in% names(massif_demo_units))
  expect_true("density" %in% names(massif_demo_units))
  expect_true("surface_ha" %in% names(massif_demo_units))

  expect_true(all(massif_demo_units$surface_ha > 0, na.rm = TRUE))
})

test_that("massif_demo_units covers realistic value ranges", {
  skip_if_not_installed("sf")

  data("massif_demo_units", package = "nemeton")

  # Social indicators
  expect_true(all(massif_demo_units$S1 >= 0 & massif_demo_units$S1 <= 5, na.rm = TRUE))
  expect_true(all(massif_demo_units$S2 >= 0 & massif_demo_units$S2 <= 100, na.rm = TRUE))
  expect_true(all(massif_demo_units$S3 >= 0, na.rm = TRUE))

  # Production indicators
  expect_true(all(massif_demo_units$P1 >= 0 & massif_demo_units$P1 <= 1000, na.rm = TRUE))
  expect_true(all(massif_demo_units$P2 >= 0 & massif_demo_units$P2 <= 20, na.rm = TRUE))
  expect_true(all(massif_demo_units$P3 >= 0 & massif_demo_units$P3 <= 100, na.rm = TRUE))

  # Energy indicators
  expect_true(all(massif_demo_units$E1 >= 0 & massif_demo_units$E1 <= 15, na.rm = TRUE))
  expect_true(all(massif_demo_units$E2 >= 0 & massif_demo_units$E2 <= 30, na.rm = TRUE))

  # Naturality indicators
  expect_true(all(massif_demo_units$N1 >= 0 & massif_demo_units$N1 <= 10000, na.rm = TRUE))
  expect_true(all(massif_demo_units$N2 >= 0, na.rm = TRUE))
  expect_true(all(massif_demo_units$N3 >= 0 & massif_demo_units$N3 <= 100, na.rm = TRUE))
})
