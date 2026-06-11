test_that("reconfort_validity_zones.geojson ships with the package", {
  p <- system.file("extdata", "reconfort_validity_zones.geojson",
                   package = "nemeton")
  expect_true(nzchar(p))
  expect_true(file.exists(p))
})

test_that("load_reconfort_validity_zones() returns 6 polygons in EPSG:4326", {
  z <- load_reconfort_validity_zones()
  expect_s3_class(z, "sf")
  expect_equal(nrow(z), 6L)
  expect_equal(sf::st_crs(z)$epsg, 4326L)
  expect_setequal(z$code_dept, RECONFORT_VALIDITY_DEPARTMENTS)
  expect_true(all(c("nom_dept", "source", "reference") %in% names(z)))
})

test_that("validity zones cover the expected total area (6 CVL departments)", {
  z <- load_reconfort_validity_zones()
  total_km2 <- as.numeric(sum(sf::st_area(sf::st_transform(z, 2154)))) / 1e6
  # Sum of the six Centre-Val de Loire departments (~39,150 km^2).
  # Tolerate the 100 m simplification applied at build time.
  expect_gt(total_km2, 38500)
  expect_lt(total_km2, 40500)
})

test_that("zones layer is cached across calls (same object identity)", {
  z1 <- load_reconfort_validity_zones()
  z2 <- load_reconfort_validity_zones()
  expect_identical(z1, z2)
})
