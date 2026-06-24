# test-reconfort-crop.R — AOI-scoped preprocessing helpers (spec 021 prod).
# The clip / OSO-mask / ground-truth functions need GDAL + the conda env +
# real data (validated by live runs, not in CI); here we cover the pure AOI
# window geometry, which drives all three.

test_that(".reconfort_aoi_window pads + snaps the AOI bbox to a 20 m grid", {
  skip_if_not_installed("sf")
  # ~157 m AOI in EPSG:2154 (lajoux_feu-like)
  aoi <- sf::st_as_sfc(sf::st_bbox(
    c(xmin = 932714, ymin = 6593803, xmax = 932871, ymax = 6593957),
    crs = 2154))
  win <- nemeton:::.reconfort_aoi_window(aoi, target_crs = 2154,
                                         buffer_m = 3000)
  # buffered well beyond the AOI on every side
  expect_lt(win[["xmin"]], 932714 - 2900)
  expect_gt(win[["xmax"]], 932871 + 2900)
  expect_lt(win[["ymin"]], 6593803 - 2900)
  expect_gt(win[["ymax"]], 6593957 + 2900)
  # snapped to a 20 m grid (10 m and 20 m bands stay aligned)
  expect_true(all(win %% 20 == 0))
  # window strictly contains the AOI bbox
  expect_lt(win[["xmin"]], 932714); expect_gt(win[["xmax"]], 932871)
})

test_that(".reconfort_aoi_window reprojects the AOI to the target CRS", {
  skip_if_not_installed("sf")
  # AOI given in EPSG:4326; window requested in 2154 must be Lambert-93 metres
  aoi <- sf::st_as_sfc(sf::st_bbox(
    c(xmin = 5.92, ymin = 46.38, xmax = 5.93, ymax = 46.39), crs = 4326))
  win <- nemeton:::.reconfort_aoi_window(aoi, target_crs = 2154,
                                         buffer_m = 1000)
  # Lambert-93 easting for the Jura is ~9.3e5, northing ~6.59e6
  expect_gt(win[["xmin"]], 9e5); expect_lt(win[["xmin"]], 1e6)
  expect_gt(win[["ymin"]], 6.5e6); expect_lt(win[["ymin"]], 6.7e6)
})
