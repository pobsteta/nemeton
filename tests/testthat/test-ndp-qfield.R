# test-ndp-qfield.R
# Tests for the QField "alternative path" bump in detect_ndp().

test_that("detect_ndp bumps to NDP 2 when placettes without trees are tagged", {
  df <- data.frame(x = 1)
  attr(df, "field_plots_count") <- 25L
  attr(df, "field_trees_count") <- 0L

  res <- detect_ndp(df)
  expect_equal(res$level, 2L)
  expect_true("field_qfield" %in% res$sources)
})

test_that("detect_ndp bumps to NDP 3 when trees/plot average >= 10", {
  df <- data.frame(x = 1)
  attr(df, "field_plots_count") <- 20L
  attr(df, "field_trees_count") <- 220L  # 11 per plot

  res <- detect_ndp(df)
  expect_equal(res$level, 3L)
})

test_that("detect_ndp leaves the level untouched when no field data is tagged", {
  df <- data.frame(x = 1)
  expect_equal(detect_ndp(df)$level, 0L)
})

test_that("detect_ndp respects an existing higher level rather than downgrading", {
  df <- data.frame(x = 1)
  attr(df, "has_lidar_hd")        <- TRUE
  attr(df, "has_drone_rgb")       <- TRUE
  attr(df, "has_lidar_drone")     <- TRUE
  attr(df, "has_inventaire_terrain") <- TRUE
  attr(df, "has_scanner_terrestre") <- TRUE
  # Also tag field data (only implies level 2) — should not demote.
  attr(df, "field_plots_count") <- 5L
  attr(df, "field_trees_count") <- 0L

  res <- detect_ndp(df)
  expect_equal(res$level, 4L)  # remains at the cumulative level
  expect_true("field_qfield" %in% res$sources)
})


test_that("tag_field_data_sources writes the counts that detect_ndp reads", {
  placettes <- data.frame(plot_id = c("P1", "P2", "P3"))
  arbres    <- data.frame(plot_id = rep(c("P1", "P2"), each = 12))
  df <- tag_field_data_sources(data.frame(x = 1), placettes, arbres)

  expect_equal(attr(df, "field_plots_count"), 3L)
  expect_equal(attr(df, "field_trees_count"), 24L)  # 12 + 12

  res <- detect_ndp(df)
  # 24 trees / 3 plots = 8 per plot → below 10 → NDP 2
  expect_equal(res$level, 2L)
})

test_that("tag_field_data_sources handles a NULL arbres input", {
  placettes <- data.frame(plot_id = c("P1"))
  df <- tag_field_data_sources(data.frame(x = 1), placettes, arbres = NULL)
  expect_equal(attr(df, "field_trees_count"), 0L)
  expect_equal(detect_ndp(df)$level, 2L)
})


test_that("field_qfield is declared in inst/datasources/FR.json", {
  # Tolerates a missing datasources folder in test environments.
  path <- system.file("datasources", "FR.json", package = "nemeton")
  skip_if(!nzchar(path), "FR.json not installed")
  ds <- jsonlite::read_json(path)
  expect_true("field_qfield" %in% names(ds$datasets))
  expect_equal(ds$datasets$field_qfield$required_crs, "EPSG:2154")
})
