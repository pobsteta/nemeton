# test-bdforet-enrich.R — enrich_parcels_bdforet invalid-geometry repair
# (fix 0.112.1). Real BD Forêt V2 rings can be invalid ("Edge N is
# degenerate (duplicate vertex)") and abort the whole intersection,
# silently zeroing the species enrichment. The function must repair with
# st_make_valid() and retry.

.sq <- function(x0, y0, s = 100) {
  sf::st_polygon(list(rbind(
    c(x0, y0), c(x0 + s, y0), c(x0 + s, y0 + s), c(x0, y0 + s), c(x0, y0))))
}

test_that("enrich_parcels_bdforet repairs an invalid geometry and retries", {
  skip_if_not_installed("sf")

  parcels <- sf::st_sf(id = 1L, geometry = sf::st_sfc(.sq(0, 0), crs = 2154))
  bdforet <- sf::st_sf(essence = "Chêne",
                       geometry = sf::st_sfc(.sq(-10, -10, 120), crs = 2154))

  # Force the first st_intersection to raise the exact GEOS/s2 invalid-ring
  # error, then run the real function on the second (repaired) call.
  real_intersection <- sf::st_intersection
  calls <- 0L
  testthat::local_mocked_bindings(
    st_intersection = function(x, y, ...) {
      calls <<- calls + 1L
      if (calls == 1L) {
        stop("Loop 0 is not valid: Edge 105 is degenerate (duplicate vertex)")
      }
      real_intersection(x, y, ...)
    },
    .package = "sf"
  )

  out <- enrich_parcels_bdforet(parcels, bdforet)

  expect_equal(calls, 2L)                 # errored once, retried once
  expect_equal(nrow(out), 1L)
  expect_false(is.na(out$species[[1]]))   # species recovered, not NA
  expect_identical(out$species[[1]], "Quercus")
})

test_that("enrich_parcels_bdforet returns NA only when the repair also fails", {
  skip_if_not_installed("sf")

  parcels <- sf::st_sf(id = 1L, geometry = sf::st_sfc(.sq(0, 0), crs = 2154))
  bdforet <- sf::st_sf(essence = "Chêne",
                       geometry = sf::st_sfc(.sq(0, 0), crs = 2154))

  testthat::local_mocked_bindings(
    st_intersection = function(x, y, ...) stop("still broken after repair"),
    .package = "sf"
  )

  out <- suppressWarnings(enrich_parcels_bdforet(parcels, bdforet))
  expect_equal(nrow(out), 1L)
  expect_true(is.na(out$species[[1]]))
})

test_that("enrich_parcels_bdforet leaves the valid-geometry path untouched", {
  skip_if_not_installed("sf")

  parcels <- sf::st_sf(id = 1L, geometry = sf::st_sfc(.sq(0, 0), crs = 2154))
  bdforet <- sf::st_sf(essence = "Chêne",
                       geometry = sf::st_sfc(.sq(-10, -10, 120), crs = 2154))

  # No error injected: intersection succeeds on the first call, no repair.
  calls <- 0L
  real_intersection <- sf::st_intersection
  testthat::local_mocked_bindings(
    st_intersection = function(x, y, ...) {
      calls <<- calls + 1L
      real_intersection(x, y, ...)
    },
    .package = "sf"
  )

  out <- enrich_parcels_bdforet(parcels, bdforet)
  expect_equal(calls, 1L)                 # single call, no retry
  expect_identical(out$species[[1]], "Quercus")
})
