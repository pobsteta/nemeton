# test-indicators-frost.R — R7 risque de gel tardif (chantier microclimat P4).

make_units2 <- function() {
  g <- lapply(1:2, function(i) sf::st_polygon(list(rbind(
    c((i - 1) * 100, 0), c(i * 100, 0), c(i * 100, 100),
    c((i - 1) * 100, 100), c((i - 1) * 100, 0)))))
  sf::st_sf(id = 1:2, geometry = sf::st_sfc(g, crs = 2154))
}

# Tmin journalier doy 90..180 : UGF1 (ouest) gèle (-2 °C) avant doy `frost_until`,
# UGF2 (est) reste doux (+5 °C).
make_tmin <- function(frost_until = 130, warm = 5, cold = -2) {
  dts <- as.Date("2020-01-01") + (90:180 - 1)
  base <- terra::rast(terra::ext(0, 200, 0, 100), resolution = 10, crs = "EPSG:2154")
  cx <- terra::xyFromCell(base, seq_len(terra::ncell(base)))[, 1]
  lays <- lapply(seq_along(dts), function(k) {
    doy <- 90 + k - 1
    v <- rep(warm, terra::ncell(base))
    v[cx < 100 & doy < frost_until] <- cold
    r <- base; terra::values(r) <- v; r
  })
  r <- terra::rast(lays); terra::time(r) <- dts; r
}

test_that("R7 scores late frost: exposed unit low, mild unit high", {
  res <- indicateur_r7_gel(make_units2(), tmin = make_tmin(),
                           budburst_doy = 100, window_end_doy = 180)
  d <- sf::st_drop_geometry(res)
  expect_true(all(c("R7", "r7_gel_days", "r7_status") %in% names(d)))
  expect_equal(d$r7_status, c("calculated", "calculated"))
  expect_lt(d$R7[1], d$R7[2])                 # UGF1 gèle -> risque plus fort
  expect_equal(d$R7[2], 100)                  # UGF2 aucun gel -> risque nul
  expect_gt(d$r7_gel_days[1], 0)
  expect_equal(d$r7_gel_days[2], 0)
})

test_that("R7 skips (NA) without a tmin series", {
  res <- indicateur_r7_gel(make_units2())
  expect_true(all(is.na(res$R7)))
  expect_equal(unique(res$r7_status), "skipped_no_tmin")
})

test_that("frost before budburst does not count", {
  # gelées seulement avant doy 100 -> aucune gelée TARDIVE si budburst = 100.
  res_early <- indicateur_r7_gel(make_units2(), tmin = make_tmin(frost_until = 100),
                                 budburst_doy = 100)
  expect_equal(res_early$r7_gel_days[1], 0)   # rien après débourrement
  expect_equal(res_early$R7[1], 100)
})

test_that("R7 requires a dated tmin raster", {
  r <- make_tmin(); terra::time(r) <- rep(as.Date(NA), terra::nlyr(r))
  expect_error(indicateur_r7_gel(make_units2(), tmin = r), "terra::time")
  expect_error(indicateur_r7_gel(make_units2(), tmin = 42), "SpatRaster")
})

test_that("family R now carries R1..R7", {
  expect_equal(INDICATOR_FAMILIES$R$indicators,
               c("R1", "R2", "R3", "R4", "R5", "R6", "R7"))
  expect_true("indicateur_r7_gel" %in% INDICATOR_FAMILIES$R$column_names)
  expect_false(is.null(INDICATOR_FAMILIES$R$indicator_labels$R7))
  expect_false(is.null(INDICATOR_FAMILIES$R$indicator_tooltips$R7))
})
