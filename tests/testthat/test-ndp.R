# tests/testthat/test-ndp.R
# Tests pour le systeme NDP (Niveau De Precision)

test_that("NDP_LEVELS has 5 levels", {
  expect_length(NDP_LEVELS, 5)
})

test_that("NDP_LEVELS Fibonacci weights follow sequence 1,1,2,3,5", {
  fibs <- vapply(NDP_LEVELS, `[[`, integer(1), "fibonacci")
  expect_equal(fibs, c(1L, 1L, 2L, 3L, 5L))
})

test_that("NDP_LEVELS confidence values are cumulative Fibonacci / 12", {
  confs <- vapply(NDP_LEVELS, `[[`, numeric(1), "confidence")
  expect_equal(confs, c(1/12, 2/12, 4/12, 7/12, 12/12))
})

test_that("NDP_LEVELS keys follow NMT convention", {
  keys <- vapply(NDP_LEVELS, `[[`, character(1), "key")
  expect_equal(keys, c("ndp_decouverte", "ndp_observation", "ndp_exploration",
                        "ndp_diagnostic", "ndp_jumeau"))
})

# ---- Accessor functions ----

test_that("get_ndp_level returns correct level", {
  level0 <- get_ndp_level(0)
  expect_equal(level0$ndp, 0L)
  expect_equal(level0$key, "ndp_decouverte")
  expect_equal(level0$fibonacci, 1L)

  level4 <- get_ndp_level(4)
  expect_equal(level4$ndp, 4L)
  expect_equal(level4$key, "ndp_jumeau")
  expect_equal(level4$fibonacci, 5L)
})

test_that("get_ndp_level rejects invalid input", {
  expect_error(get_ndp_level(-1))
  expect_error(get_ndp_level(5))
  expect_error(get_ndp_level(NA))
  expect_error(get_ndp_level(c(0, 1)))
})

test_that("get_ndp_name returns French names", {
  expect_match(get_ndp_name(0), "couverte")
  expect_equal(get_ndp_name(1), "Observation")
  expect_equal(get_ndp_name(2), "Exploration")
  expect_equal(get_ndp_name(3), "Diagnostic")
  expect_equal(get_ndp_name(4), "Jumeau")
})

test_that("get_ndp_weight returns Fibonacci values", {
  expect_equal(get_ndp_weight(0), 1L)
  expect_equal(get_ndp_weight(1), 1L)
  expect_equal(get_ndp_weight(2), 2L)
  expect_equal(get_ndp_weight(3), 3L)
  expect_equal(get_ndp_weight(4), 5L)
})

test_that("get_ndp_confidence returns correct ratios", {
  expect_equal(get_ndp_confidence(0), 1/12)
  expect_equal(get_ndp_confidence(4), 1.0)
})

# ---- ndp_table ----

test_that("ndp_table returns correct data.frame", {
  tbl <- ndp_table()
  expect_s3_class(tbl, "data.frame")
  expect_equal(nrow(tbl), 5)
  expect_equal(names(tbl), c("ndp", "key", "name", "fibonacci", "confidence"))
  expect_equal(tbl$ndp, 0:4)
  expect_equal(tbl$fibonacci, c(1L, 1L, 2L, 3L, 5L))
})

# ---- detect_ndp ----

test_that("detect_ndp returns 0 for plain data", {
  df <- data.frame(x = 1:3)
  expect_equal(detect_ndp(df)$level, 0L)
})

test_that("detect_ndp returns 0 for NULL", {
  expect_equal(detect_ndp(NULL)$level, 0L)
})

test_that("detect_ndp detects NDP 1 with LiDAR HD", {
  df <- data.frame(x = 1)
  attr(df, "has_lidar_hd") <- TRUE
  expect_equal(detect_ndp(df)$level, 1L)
})

test_that("detect_ndp detects NDP 2 with drone", {
  df <- data.frame(x = 1)
  attr(df, "has_lidar_hd") <- TRUE
  attr(df, "has_drone_rgb") <- TRUE
  expect_equal(detect_ndp(df)$level, 2L)
})

test_that("detect_ndp detects NDP 3 with terrain inventory", {
  df <- data.frame(x = 1)
  attr(df, "has_lidar_hd") <- TRUE
  attr(df, "has_drone_rgb") <- TRUE
  attr(df, "has_inventaire_terrain") <- TRUE
  expect_equal(detect_ndp(df)$level, 3L)
})

test_that("detect_ndp detects NDP 4 with scanner", {
  df <- data.frame(x = 1)
  attr(df, "has_lidar_hd") <- TRUE
  attr(df, "has_drone_rgb") <- TRUE
  attr(df, "has_inventaire_terrain") <- TRUE
  attr(df, "has_scanner_terrestre") <- TRUE
  expect_equal(detect_ndp(df)$level, 4L)
})

test_that("detect_ndp requires cumulative sources (no skip)", {
  # Drone sans LiDAR reste en NDP 0
  df <- data.frame(x = 1)
  attr(df, "has_drone_rgb") <- TRUE
  expect_equal(detect_ndp(df)$level, 0L)
})

# ---- compute_general_index ----

test_that("compute_general_index returns correct structure", {
  scores <- c(C = 50, B = 60, W = 70)
  result <- compute_general_index(scores, ndp = 0)
  expect_type(result, "list")
  expect_named(result, c("score", "ndp", "confidence", "weight", "n_families"))
  expect_equal(result$ndp, 0L)
  expect_equal(result$weight, 1L)
  expect_equal(result$confidence, 1/12)
  expect_equal(result$n_families, 3L)
})

test_that("compute_general_index computes correct score", {
  scores <- c(C = 40, B = 60)
  result <- compute_general_index(scores, ndp = 0)
  expect_equal(result$score, 50.0)
})

test_that("compute_general_index handles famille_ prefix", {
  scores <- c(famille_carbone = 40, famille_biodiversite = 60)
  result <- compute_general_index(scores, ndp = 0)
  expect_equal(result$score, 50.0)
})

test_that("compute_general_index handles all NA", {
  scores <- c(C = NA_real_, B = NA_real_)
  result <- compute_general_index(scores, ndp = 0)
  expect_true(is.na(result$score))
  expect_equal(result$n_families, 0L)
})

test_that("compute_general_index handles partial NA", {
  scores <- c(C = 80, B = NA_real_, W = 60)
  result <- compute_general_index(scores, ndp = 0)
  expect_equal(result$score, 70.0)
  expect_equal(result$n_families, 2L)
})

test_that("compute_general_index works with different NDP levels", {
  scores <- c(C = 50, B = 50)
  for (ndp in 0:4) {
    result <- compute_general_index(scores, ndp = ndp)
    expect_equal(result$score, 50.0)
    expect_equal(result$ndp, ndp)
    expect_equal(result$weight, get_ndp_weight(ndp))
    expect_equal(result$confidence, get_ndp_confidence(ndp))
  }
})

# ---- compute_general_index_mixed ----

test_that("compute_general_index_mixed weights by Fibonacci", {
  # C at NDP 2 (weight 2), B at NDP 0 (weight 1)
  scores <- c(C = 100, B = 0)
  ndps <- c(C = 2L, B = 0L)
  result <- compute_general_index_mixed(scores, ndps)
  # Weighted: (100*2 + 0*1) / (2+1) = 200/3 = 66.7
  expect_equal(result$score, 66.7)
  expect_equal(result$n_families, 2L)
})

test_that("compute_general_index_mixed handles no common families", {
  scores <- c(C = 50)
  ndps <- c(B = 0L)
  result <- compute_general_index_mixed(scores, ndps)
  expect_true(is.na(result$score))
  expect_equal(result$n_families, 0L)
})

test_that("compute_general_index_mixed handles famille_ prefix", {
  scores <- c(famille_carbone = 80, famille_biodiversite = 40)
  ndps <- c(famille_carbone = 1L, famille_biodiversite = 1L)
  result <- compute_general_index_mixed(scores, ndps)
  expect_equal(result$score, 60.0)
})


# ---- detect_ndp_from_layers ----

test_that("detect_ndp_from_layers returns 0 for non-nemeton_layers", {
  expect_equal(detect_ndp_from_layers(list()), 0L)
  expect_equal(detect_ndp_from_layers(NULL), 0L)
})

test_that("detect_ndp_from_layers returns 0 when no LiDAR", {
  layers <- structure(
    list(rasters = list(ndvi = "fake", dem = "fake"),
         vectors = list(), point_clouds = list()),
    class = "nemeton_layers"
  )
  expect_equal(detect_ndp_from_layers(layers), 0L)
})

test_that("detect_ndp_from_layers returns 1 when LiDAR MNH present", {
  layers <- structure(
    list(rasters = list(lidar_mnh = "fake"),
         vectors = list(), point_clouds = list()),
    class = "nemeton_layers"
  )
  expect_equal(detect_ndp_from_layers(layers), 1L)
})

test_that("detect_ndp_from_layers returns 1 when point clouds present", {
  layers <- structure(
    list(rasters = list(),
         vectors = list(), point_clouds = list(tile1 = "fake.copc")),
    class = "nemeton_layers"
  )
  expect_equal(detect_ndp_from_layers(layers), 1L)
})

# ---- set_ndp_attributes / restore_ndp_attributes ----

test_that("set_ndp_attributes sets correct attributes from layers", {
  df <- data.frame(x = 1)
  layers <- structure(
    list(rasters = list(lidar_mnh = "fake"),
         vectors = list(), point_clouds = list()),
    class = "nemeton_layers"
  )
  result <- set_ndp_attributes(df, layers)
  expect_true(attr(result, "has_lidar_hd"))
  expect_false(attr(result, "has_drone_rgb"))
  expect_equal(attr(result, "ndp_detected"), 1L)
  expect_equal(detect_ndp(result)$level, 1L)
})

test_that("set_ndp_attributes without layers defaults to NDP 0", {
  df <- data.frame(x = 1)
  result <- set_ndp_attributes(df, NULL)
  expect_false(attr(result, "has_lidar_hd"))
  expect_equal(detect_ndp(result)$level, 0L)
})

test_that("restore_ndp_attributes round-trips correctly", {
  df <- data.frame(x = 1)
  restored <- restore_ndp_attributes(df, 1L)
  expect_true(attr(restored, "has_lidar_hd"))
  expect_false(attr(restored, "has_drone_rgb"))
  expect_equal(detect_ndp(restored)$level, 1L)
})

test_that("restore_ndp_attributes handles NULL ndp_level", {
  df <- data.frame(x = 1)
  restored <- restore_ndp_attributes(df, NULL)
  expect_equal(detect_ndp(restored)$level, 0L)
})

# ---- detect_ndp_from_cache ----

test_that("detect_ndp_from_cache returns 0 for missing dir", {
  expect_equal(detect_ndp_from_cache(NULL), 0L)
  expect_equal(detect_ndp_from_cache("/nonexistent/path"), 0L)
})

test_that("detect_ndp_from_cache returns 0 when no LiDAR files", {
  withr::with_tempdir({
    dir.create(file.path("cache", "layers"), recursive = TRUE)
    file.create(file.path("cache", "layers", "ndvi.tif"))
    file.create(file.path("cache", "layers", "dem.tif"))
    expect_equal(detect_ndp_from_cache(getwd()), 0L)
  })
})

test_that("detect_ndp_from_cache returns 1 when LiDAR MNH directory present", {
  withr::with_tempdir({
    dir.create(file.path("cache", "layers", "lidar_mnh"), recursive = TRUE)
    expect_equal(detect_ndp_from_cache(getwd()), 1L)
  })
})

test_that("detect_ndp_from_cache returns 1 when LiDAR MNT directory present", {
  withr::with_tempdir({
    dir.create(file.path("cache", "layers", "lidar_mnt"), recursive = TRUE)
    expect_equal(detect_ndp_from_cache(getwd()), 1L)
  })
})

test_that("detect_ndp_from_cache returns 1 when lidar_nuage directory present", {
  withr::with_tempdir({
    dir.create(file.path("cache", "layers", "lidar_nuage"), recursive = TRUE)
    expect_equal(detect_ndp_from_cache(getwd()), 1L)
  })
})

test_that("detect_ndp_from_cache returns 1 when LiDAR file present", {
  withr::with_tempdir({
    dir.create(file.path("cache", "layers"), recursive = TRUE)
    file.create(file.path("cache", "layers", "lidar_mnh.tif"))
    expect_equal(detect_ndp_from_cache(getwd()), 1L)
  })
})

test_that("canopy_provenance maps augmented flags to a canonical key", {
  expect_identical(canopy_provenance(character(0)), "lidar_hd")
  expect_identical(canopy_provenance("lai_ml"), "prosail_s2")
  expect_identical(canopy_provenance("height_ml"), "opencanopy")
  # lai_ml (repli satellite) est prioritaire : sa présence signifie LiDAR absent.
  expect_identical(canopy_provenance(c("height_ml", "lai_ml")), "prosail_s2")
  # flags non-canopée ignorés.
  expect_identical(canopy_provenance(c("species_ml", "texture_ml")), "lidar_hd")
  # cohérent avec detect_ndp().
  df <- data.frame(x = 1)
  attr(df, "lai_source") <- "prosail_s2"
  expect_identical(canopy_provenance(detect_ndp(df)$augmented), "prosail_s2")
})
