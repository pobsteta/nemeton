# Tests for detect_ndp() ML-augmented flag (ADR-011 amendment, spec 005)

test_that("detect_ndp returns ndp_result object", {
  df <- data.frame(x = 1)
  r <- detect_ndp(df)
  expect_s3_class(r, "ndp_result")
  expect_named(r, c("level", "confidence", "augmented", "sources"))
  expect_type(r$level, "integer")
  expect_type(r$confidence, "double")
  expect_type(r$augmented, "character")
  expect_type(r$sources, "character")
})

test_that("detect_ndp has empty augmented by default", {
  df <- data.frame(x = 1)
  expect_length(detect_ndp(df)$augmented, 0)
})

test_that("detect_ndp flags height_ml when chm_source is opencanopy", {
  df <- data.frame(x = 1)
  attr(df, "chm_source") <- "opencanopy"
  r <- detect_ndp(df)
  expect_equal(r$level, 0L)
  expect_true("height_ml" %in% r$augmented)
})

test_that("detect_ndp does not flag height_ml for other chm_source", {
  df <- data.frame(x = 1)
  attr(df, "chm_source") <- "lidar_hd"
  expect_false("height_ml" %in% detect_ndp(df)$augmented)
})

test_that("detect_ndp level is unchanged by chm_source", {
  # Le flag augmented ne doit pas modifier le niveau NDP
  df <- data.frame(x = 1)
  attr(df, "chm_source") <- "opencanopy"
  expect_equal(detect_ndp(df)$level, 0L)

  attr(df, "has_lidar_hd") <- TRUE
  expect_equal(detect_ndp(df)$level, 1L)
  expect_true("height_ml" %in% detect_ndp(df)$augmented)
})

test_that("detect_ndp flags species_ml for tree_sat and maestro", {
  df <- data.frame(x = 1)
  attr(df, "species_source") <- "tree_sat"
  expect_true("species_ml" %in% detect_ndp(df)$augmented)

  attr(df, "species_source") <- "maestro"
  expect_true("species_ml" %in% detect_ndp(df)$augmented)
})

test_that("detect_ndp flags texture_ml for maestro texture", {
  df <- data.frame(x = 1)
  attr(df, "texture_source") <- "maestro"
  expect_true("texture_ml" %in% detect_ndp(df)$augmented)
})

test_that("detect_ndp accumulates multiple augmented flags", {
  df <- data.frame(x = 1)
  attr(df, "chm_source") <- "opencanopy"
  attr(df, "species_source") <- "tree_sat"
  attr(df, "texture_source") <- "maestro"
  aug <- detect_ndp(df)$augmented
  expect_true(all(c("height_ml", "species_ml", "texture_ml") %in% aug))
  expect_length(aug, 3)
})

test_that("detect_ndp exposes matching confidence", {
  df <- data.frame(x = 1)
  expect_equal(detect_ndp(df)$confidence, get_ndp_confidence(0))

  attr(df, "has_lidar_hd") <- TRUE
  expect_equal(detect_ndp(df)$confidence, get_ndp_confidence(1))
})

test_that("detect_ndp includes baseline sources at NDP 0", {
  df <- data.frame(x = 1)
  srcs <- detect_ndp(df)$sources
  expect_true(all(c("sentinel_2", "bd_topo") %in% srcs))
})

test_that("detect_ndp extends sources at higher NDP", {
  df <- data.frame(x = 1)
  attr(df, "has_lidar_hd") <- TRUE
  srcs <- detect_ndp(df)$sources
  expect_true("lidar_hd" %in% srcs)
})

test_that("detect_ndp NULL input returns NDP 0 result", {
  r <- detect_ndp(NULL)
  expect_s3_class(r, "ndp_result")
  expect_equal(r$level, 0L)
  expect_length(r$augmented, 0)
})

test_that("as.integer coerces ndp_result to level", {
  df <- data.frame(x = 1)
  attr(df, "has_lidar_hd") <- TRUE
  expect_equal(as.integer(detect_ndp(df)), 1L)
})

test_that("print.ndp_result produces output", {
  df <- data.frame(x = 1)
  attr(df, "chm_source") <- "opencanopy"
  out <- capture.output(print(detect_ndp(df)))
  expect_true(any(grepl("NDP 0", out)))
  expect_true(any(grepl("height_ml", out)))
})

test_that("get_ndp_augmented accessor works", {
  df <- data.frame(x = 1)
  attr(df, "chm_source") <- "opencanopy"
  expect_equal(get_ndp_augmented(detect_ndp(df)), "height_ml")
})

test_that("get_ndp_augmented errors on non ndp_result", {
  expect_error(get_ndp_augmented(0L), "ndp_result")
  expect_error(get_ndp_augmented(list(level = 0L)), "ndp_result")
})


test_that("chm_source='lidar_hd' reports height_lidar augmented flag", {
  df <- data.frame(x = 1)
  # has_lidar_hd lifts the NDP to 1 (Observation) AND the augmented
  # vector records "height_lidar" so downstream code can distinguish
  # the direct LiDAR HD measurement from the opencanopy ML
  # prediction.
  attr(df, "has_lidar_hd") <- TRUE
  attr(df, "chm_source")   <- "lidar_hd"
  r <- detect_ndp(df)
  expect_equal(r$level, 1L)
  expect_true("height_lidar" %in% r$augmented)
  expect_false("height_ml" %in% r$augmented)
})
