# Tests for R/utils-chm.R (spec 005 phase 1)

# ---- fixture self-check ----

test_that("make_fixture_chm returns a valid SpatRaster", {
  chm <- make_fixture_chm(size_m = 100, res_m = 1.5)
  expect_s4_class(chm, "SpatRaster")
  expect_equal(terra::crs(chm, describe = TRUE)$code, "2154")
  expect_equal(as.numeric(terra::res(chm)), c(1.5, 1.5))
  vals <- terra::values(chm)
  expect_gt(sum(!is.na(vals)), 0)
})

test_that("make_fixture_chm with add_artefacts produces > 50 m pixels", {
  chm <- make_fixture_chm(size_m = 100, res_m = 1.5, add_artefacts = TRUE)
  expect_true(any(terra::values(chm) > 50, na.rm = TRUE))
})

test_that("make_fixture_chm without artefacts keeps range [5, 35]", {
  chm <- make_fixture_chm(size_m = 60, res_m = 1.5, add_artefacts = FALSE)
  vals <- terra::values(chm)
  vals <- vals[!is.na(vals)]
  expect_gte(min(vals), 5)
  expect_lte(max(vals), 35)
})

test_that("make_fixture_chm(write_cog=TRUE) writes a COG file", {
  chm <- make_fixture_chm(size_m = 60, res_m = 1.5, write_cog = TRUE)
  src <- terra::sources(chm)
  expect_true(file.exists(src))
  info <- terra::describe(src, sds = FALSE)
  # Un COG expose le tag LAYOUT=COG via gdalinfo
  expect_true(any(grepl("COG|TILED|BLOCK", info, ignore.case = TRUE)))
})

# ---- sanitize_chm input validation ----

test_that("sanitize_chm errors on non-SpatRaster chm", {
  expect_error(sanitize_chm(1:10), "SpatRaster")
})

test_that("sanitize_chm errors on non-SpatRaster ndvi", {
  chm <- make_fixture_chm(size_m = 60)
  expect_error(sanitize_chm(chm, ndvi = 1:10), "SpatRaster")
})

test_that("sanitize_chm errors on non-SpatRaster slope", {
  chm <- make_fixture_chm(size_m = 60)
  expect_error(sanitize_chm(chm, slope = 1:10), "SpatRaster")
})

# ---- range step (always applied) ----

test_that("sanitize_chm clamps above max_height", {
  chm <- make_fixture_chm(size_m = 60, add_artefacts = TRUE)
  res <- sanitize_chm(chm, max_height = 50)
  vals <- terra::values(res$chm_clean)
  expect_true(all(is.na(vals) | vals <= 50))
  expect_true("range" %in% res$steps_applied)
})

test_that("sanitize_chm clamps negative heights", {
  chm <- make_fixture_chm(size_m = 60)
  # Injecter une valeur negative
  terra::values(chm)[1] <- -5
  res <- sanitize_chm(chm)
  vals <- terra::values(res$chm_clean)
  expect_true(all(is.na(vals) | vals >= 0))
})

test_that("sanitize_chm without masks returns non-empty result", {
  chm <- make_fixture_chm(size_m = 60)
  res <- sanitize_chm(chm)
  expect_type(res, "list")
  expect_s4_class(res$chm_clean, "SpatRaster")
  expect_type(res$pct_masked, "double")
  expect_equal(res$steps_applied, "range")
})

# ---- forest mask ----

test_that("sanitize_chm applies forest mask (SpatRaster)", {
  chm <- make_fixture_chm(size_m = 60, add_artefacts = FALSE)
  masks <- make_fixture_masks(chm)
  res <- sanitize_chm(chm, forest_mask = masks$forest_mask)
  expect_true("forest" %in% res$steps_applied)
  expect_gt(res$pct_masked, 0)
})

test_that("sanitize_chm errors on invalid forest_mask class", {
  chm <- make_fixture_chm(size_m = 60)
  expect_error(sanitize_chm(chm, forest_mask = list(foo = 1)),
               "SpatRaster or sf")
})

# ---- buildings / water ----

test_that("sanitize_chm masks buildings polygons", {
  chm <- make_fixture_chm(size_m = 60, add_artefacts = FALSE)
  masks <- make_fixture_masks(chm)
  res <- sanitize_chm(chm, buildings = masks$buildings)
  expect_true("buildings" %in% res$steps_applied)
  expect_gte(res$pct_masked, 0)
})

test_that("sanitize_chm masks water polygons", {
  chm <- make_fixture_chm(size_m = 60, add_artefacts = FALSE)
  masks <- make_fixture_masks(chm)
  res <- sanitize_chm(chm, water = masks$water)
  expect_true("water" %in% res$steps_applied)
})

test_that("sanitize_chm errors on non-sf buildings", {
  chm <- make_fixture_chm(size_m = 60)
  expect_error(sanitize_chm(chm, buildings = list()), "sf")
})

# ---- NDVI threshold ----

test_that("sanitize_chm applies NDVI threshold", {
  chm <- make_fixture_chm(size_m = 60, add_artefacts = FALSE)
  ndvi <- make_fixture_ndvi(chm)
  res <- sanitize_chm(chm, ndvi = ndvi, ndvi_threshold = 0.3)
  expect_true("ndvi" %in% res$steps_applied)
  expect_gt(res$pct_masked, 0)
})

test_that("sanitize_chm respects ndvi_threshold ordering", {
  chm <- make_fixture_chm(size_m = 60, add_artefacts = FALSE)
  ndvi <- make_fixture_ndvi(chm)
  # Un seuil plus haut masque plus de pixels qu'un seuil plus bas
  res_high <- suppressWarnings(sanitize_chm(chm, ndvi = ndvi, ndvi_threshold = 0.9))
  res_low  <- sanitize_chm(chm, ndvi = ndvi, ndvi_threshold = -1)
  expect_gte(res_high$pct_masked, res_low$pct_masked)
})

# ---- slope step ----

test_that("sanitize_chm applies slope step", {
  chm <- make_fixture_chm(size_m = 60, add_artefacts = FALSE)
  slope <- make_fixture_slope(chm)
  res <- sanitize_chm(chm, slope = slope)
  expect_true("slope" %in% res$steps_applied)
})

# ---- pct_masked warning ----

test_that("sanitize_chm warns if pct_masked > 0.5", {
  chm <- make_fixture_chm(size_m = 60, add_artefacts = FALSE)
  # Masque foret tres restrictif : un seul pixel foret
  forest_mask <- terra::rast(chm)
  terra::values(forest_mask) <- 0L
  terra::values(forest_mask)[1] <- 1L
  # Force the mask application (coverage check would short-circuit
  # it otherwise — that's a separate safeguard tested below).
  expect_warning(sanitize_chm(chm, forest_mask = forest_mask,
                              forest_coverage_threshold = 0),
                 "masked")
})

test_that("sanitize_chm skips forest step when mask covers too little", {
  chm <- make_fixture_chm(size_m = 60, add_artefacts = FALSE)
  forest_mask <- terra::rast(chm)
  terra::values(forest_mask) <- 0L
  terra::values(forest_mask)[1] <- 1L
  res <- expect_warning(
    sanitize_chm(chm, forest_mask = forest_mask),
    "covers only"
  )
  expect_false("forest" %in% res$steps_applied)
})

# ---- ordering and step list ----

test_that("sanitize_chm runs all steps in declared order", {
  chm <- make_fixture_chm(size_m = 60, add_artefacts = FALSE)
  masks <- make_fixture_masks(chm)
  ndvi <- make_fixture_ndvi(chm)
  slope <- make_fixture_slope(chm)
  res <- suppressWarnings(
    sanitize_chm(chm,
                 forest_mask = masks$forest_mask,
                 buildings   = masks$buildings,
                 water       = masks$water,
                 ndvi        = ndvi,
                 slope       = slope)
  )
  expect_equal(res$steps_applied,
               c("forest", "buildings", "water", "ndvi", "range", "slope"))
})

test_that("sanitize_chm pct_masked is 0 on an already valid CHM", {
  chm <- make_fixture_chm(size_m = 60, add_artefacts = FALSE)
  res <- sanitize_chm(chm)
  expect_lte(res$pct_masked, 0.001)
})

test_that("sanitize_chm returns SpatRaster with same CRS", {
  chm <- make_fixture_chm(size_m = 60)
  res <- sanitize_chm(chm)
  expect_equal(terra::crs(res$chm_clean, describe = TRUE)$code, "2154")
})


# ---- extract_h_dom edge cases (T0.2 coverage top-up) ---------

test_that("extract_h_dom rejects non-SpatRaster chm", {
  poly <- sf::st_polygon(list(rbind(c(0,0), c(10,0), c(10,10),
                                    c(0,10), c(0,0))))
  units <- sf::st_sf(geometry = sf::st_sfc(poly, crs = 2154))
  expect_error(extract_h_dom(matrix(1:4, 2, 2), units),
               regexp = "SpatRaster")
})

test_that("extract_h_dom rejects non-sf units", {
  chm <- terra::rast(nrows = 10, ncols = 10,
                     xmin = 0, xmax = 100, ymin = 0, ymax = 100,
                     crs = "EPSG:2154",
                     vals = rep(20, 100))
  expect_error(extract_h_dom(chm, data.frame(x = 1:3)),
               regexp = "sf/sfc")
})

test_that("extract_h_dom rejects invalid percentile", {
  chm <- terra::rast(nrows = 10, ncols = 10,
                     xmin = 0, xmax = 100, ymin = 0, ymax = 100,
                     crs = "EPSG:2154",
                     vals = rep(20, 100))
  poly <- sf::st_polygon(list(rbind(c(0,0), c(100,0), c(100,100),
                                    c(0,100), c(0,0))))
  units <- sf::st_sf(geometry = sf::st_sfc(poly, crs = 2154))
  expect_error(extract_h_dom(chm, units, percentile = 1.5),
               regexp = "percentile")
  expect_error(extract_h_dom(chm, units, percentile = NA),
               regexp = "percentile")
  expect_error(extract_h_dom(chm, units, percentile = c(0.5, 0.9)),
               regexp = "percentile")
})

test_that("extract_h_dom returns NA when fewer than min_pixels", {
  chm <- terra::rast(nrows = 100, ncols = 100,
                     xmin = 0, xmax = 1000, ymin = 0, ymax = 1000,
                     crs = "EPSG:2154",
                     vals = rep(20, 10000))
  # Tiny polygon covering < 10 pixels
  poly <- sf::st_polygon(list(rbind(c(0, 0), c(5, 0),
                                    c(5, 5), c(0, 5),
                                    c(0, 0))))
  units <- sf::st_sf(geometry = sf::st_sfc(poly, crs = 2154))
  h <- extract_h_dom(chm, units, min_pixels = 100L)
  expect_length(h, 1)
  expect_true(is.na(h))
})
