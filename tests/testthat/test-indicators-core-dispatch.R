# compute_indicator() must match supplied args (units, layers, chm, ...)
# to each function's formals. Indicators that declare neither `layers`
# nor `...` (indicateur_p1_volume / p2 / p3 / e1 / e2) previously aborted
# with "unused argument (layers = ...)" when dispatched via nemeton_compute().

.mini_chm <- function(height, size_m = 80, res_m = 2) {
  r <- terra::rast(xmin = 900000, xmax = 900000 + size_m,
                   ymin = 6300000, ymax = 6300000 + size_m,
                   resolution = res_m, crs = "EPSG:2154")
  terra::values(r) <- rep(as.numeric(height), terra::ncell(r))
  names(r) <- "chm"
  r
}

.mini_units <- function(chm, species = "FASY") {
  ext <- terra::ext(chm)
  poly <- sf::st_polygon(list(rbind(
    c(ext[1], ext[3]), c(ext[2], ext[3]),
    c(ext[2], ext[4]), c(ext[1], ext[4]), c(ext[1], ext[3]))))
  sf::st_sf(species = species,
            geometry = sf::st_sfc(poly, crs = terra::crs(chm)))
}

test_that("compute_indicator passes layers only to functions that accept it", {
  skip_if_not_installed("terra")
  chm   <- .mini_chm(0)                  # clear-cut -> P1 = 0 with v0.107.0 core
  units <- .mini_units(chm)

  # indicateur_p1_volume has NO `layers` and NO `...`. Before the fix,
  # dispatching with `layers =` raised "unused argument". Now it is
  # filtered out and the call succeeds.
  val <- nemeton:::compute_indicator(
    "indicateur_p1_volume", units, layers = list(dummy = TRUE), chm = chm)
  expect_type(val, "double")
  expect_length(val, nrow(units))
  expect_false(anyNA(val))
  expect_true(all(val == 0))
})

test_that("compute_indicator drops any surplus ... arg for a no-dots function", {
  skip_if_not_installed("terra")
  chm   <- .mini_chm(0)
  units <- .mini_units(chm)
  # `bogus_arg` is not a formal of indicateur_p1_volume and must be
  # dropped silently rather than triggering "unused argument".
  expect_no_error(
    nemeton:::compute_indicator(
      "indicateur_p1_volume", units, layers = NULL,
      chm = chm, bogus_arg = 42)
  )
})

test_that("compute_indicator still forwards every arg to a function with ...", {
  skip_if_not_installed("terra")
  # A stub indicator declaring `...`: it must receive the surplus arg.
  seen <- new.env()
  assign("indicateur_stub_dots",
         function(units, layers, ...) {
           seen$got <- names(list(...))
           rep(1, nrow(units))
         },
         envir = globalenv())
  on.exit(rm("indicateur_stub_dots", envir = globalenv()), add = TRUE)

  units <- .mini_units(.mini_chm(10))
  out <- nemeton:::compute_indicator(
    "indicateur_stub_dots", units, layers = list(a = 1), extra_flag = "x")
  expect_equal(out, rep(1, nrow(units)))
  expect_true("extra_flag" %in% seen$got)   # ... function keeps surplus args
})
