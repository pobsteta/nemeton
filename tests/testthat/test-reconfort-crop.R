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

test_that(".reconfort_crop_scene_to_aoi garde la structure quand le chemin contient des metacaracteres (audit 1.0)", {
  # Le chemin de la scene servait d'expression reguliere : avec un `+` ou une
  # parenthese, le prefixe n'etait pas retire et la sortie partait ailleurs.
  root <- withr::local_tempdir()
  scene <- file.path(root, "run+1 (bis)", "SENTINEL2A_X")
  dir.create(file.path(scene, "MASKS"), recursive = TRUE)
  file.create(file.path(scene, "SENTINEL2A_X_FRE_B4.tif"),
              file.path(scene, "MASKS", "SENTINEL2A_X_CLM_R1.tif"),
              file.path(scene, "SENTINEL2A_X_MTD_ALL.xml"))
  out <- file.path(root, "out")
  dest <- character()
  testthat::local_mocked_bindings(
    .reconfort_warp_one = function(src, dst, ...) dest <<- c(dest, dst))

  n <- .reconfort_crop_scene_to_aoi(scene, out, win = c(xmin = 0, ymin = 0, xmax = 1, ymax = 1))
  expect_identical(n, 2L)
  expect_setequal(dest, c(file.path(out, "SENTINEL2A_X_FRE_B4.tif"),
                          file.path(out, "MASKS", "SENTINEL2A_X_CLM_R1.tif")))
  expect_true(file.exists(file.path(out, "SENTINEL2A_X_MTD_ALL.xml")))
})
