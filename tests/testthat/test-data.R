# Test Suite for Package Datasets
# US6: massif_demo_units_extended with 12-family referential

test_that("massif_demo_units_extended has correct structure (T096)", {
  skip_if_not_installed("sf")

  data("massif_demo_units_extended", package = "nemeton")

  expect_s3_class(massif_demo_units_extended, "sf")
  expect_equal(nrow(massif_demo_units_extended), 20)
  expect_true("geometry" %in% names(massif_demo_units_extended))
  expect_true("id" %in% names(massif_demo_units_extended))
  expect_equal(sf::st_crs(massif_demo_units_extended)$epsg, 2154)
})

test_that("massif_demo_units_extended has all 29 indicators present (T097)", {
  skip_if_not_installed("sf")

  data("massif_demo_units_extended", package = "nemeton")

  required_indicators <- c(
    "C1", "C2", "B1", "B2", "B3", "W1", "W2", "W3", "A1", "A2",
    "F1", "F2", "L1", "L2", "T1", "T2", "R1", "R2", "R3",
    "S1", "S2", "S3", "P1", "P2", "P3", "E1", "E2", "N1", "N2", "N3"
  )

  missing_indicators <- setdiff(required_indicators, names(massif_demo_units_extended))
  expect_length(missing_indicators, 0)

  for (ind in required_indicators) {
    expect_type(massif_demo_units_extended[[ind]], "double")
    expect_true(any(!is.na(massif_demo_units_extended[[ind]])))
  }
})

test_that("massif_demo_units_extended has all 12 family composites in valid range (T098)", {
  skip_if_not_installed("sf")

  data("massif_demo_units_extended", package = "nemeton")

  required_families <- paste0("family_", c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N"))

  missing_families <- setdiff(required_families, names(massif_demo_units_extended))
  expect_length(missing_families, 0)

  for (fam in required_families) {
    expect_type(massif_demo_units_extended[[fam]], "double")
    values <- massif_demo_units_extended[[fam]]
    expect_true(all(values >= 0 & values <= 100, na.rm = TRUE))
    expect_true(any(!is.na(values)))
    expect_true(sd(values, na.rm = TRUE) > 0)
  }
})

test_that("massif_demo_units_extended metadata is complete", {
  skip_if_not_installed("sf")

  data("massif_demo_units_extended", package = "nemeton")

  expect_true("id" %in% names(massif_demo_units_extended))
  expect_true("name" %in% names(massif_demo_units_extended))
  expect_true("area_ha" %in% names(massif_demo_units_extended))
  expect_true("species" %in% names(massif_demo_units_extended))

  expect_true(all(massif_demo_units_extended$area_ha > 0, na.rm = TRUE))
  expect_true(all(nchar(as.character(massif_demo_units_extended$species)) == 4, na.rm = TRUE))
})

test_that("massif_demo_units_extended covers realistic value ranges", {
  skip_if_not_installed("sf")

  data("massif_demo_units_extended", package = "nemeton")

  expect_true(all(massif_demo_units_extended$S1 >= 0 & massif_demo_units_extended$S1 <= 5, na.rm = TRUE))
  expect_true(all(massif_demo_units_extended$S2 >= 0 & massif_demo_units_extended$S2 <= 100, na.rm = TRUE))
  expect_true(all(massif_demo_units_extended$S3 >= 0, na.rm = TRUE))

  expect_true(all(massif_demo_units_extended$P1 >= 0 & massif_demo_units_extended$P1 <= 1000, na.rm = TRUE))
  expect_true(all(massif_demo_units_extended$P2 >= 0 & massif_demo_units_extended$P2 <= 20, na.rm = TRUE))
  expect_true(all(massif_demo_units_extended$P3 >= 0 & massif_demo_units_extended$P3 <= 100, na.rm = TRUE))

  expect_true(all(massif_demo_units_extended$E1 >= 0 & massif_demo_units_extended$E1 <= 15, na.rm = TRUE))
  expect_true(all(massif_demo_units_extended$E2 >= 0 & massif_demo_units_extended$E2 <= 30, na.rm = TRUE))

  expect_true(all(massif_demo_units_extended$N1 >= 0 & massif_demo_units_extended$N1 <= 10000, na.rm = TRUE))
  expect_true(all(massif_demo_units_extended$N2 >= 0, na.rm = TRUE))
  expect_true(all(massif_demo_units_extended$N3 >= 0 & massif_demo_units_extended$N3 <= 100, na.rm = TRUE))
})
