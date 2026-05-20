# Tests for Sentinel-2 reprocessing-duplicate handling.
#
# ESA reprocessing campaigns republish an acquisition under a new
# product id (only the trailing processing-baseline timestamp
# changes). A STAC search returns both; nemeton must keep only the
# latest baseline so the cache is not doubled and FORDEAD does not
# receive two items with the same datetime.

test_that(".s2_split_product_id parses a 6-field Planetary Computer id", {
  s <- nemeton:::.s2_split_product_id(
    "S2A_MSIL2A_20211029T104151_R008_T31TGM_20211030T012431"
  )
  expect_identical(s$key, "S2A_20211029T104151_R008_T31TGM")
  expect_identical(s$proc, "20211030T012431")
})


test_that(".s2_split_product_id parses the 7-field ESA .SAFE id to the same key", {
  pc   <- nemeton:::.s2_split_product_id(
    "S2A_MSIL2A_20211029T104151_R008_T31TGM_20211030T012431"
  )
  esa  <- nemeton:::.s2_split_product_id(
    "S2A_MSIL2A_20211029T104151_N0301_R008_T31TGM_20230128T045356.SAFE"
  )
  # Same physical acquisition -> same key regardless of the id form.
  expect_identical(pc$key, esa$key)
  expect_identical(esa$proc, "20230128T045356")
})


test_that(".s2_split_product_id treats an unrecognised id as its own key", {
  s <- nemeton:::.s2_split_product_id("weird-non-s2-id")
  expect_identical(s$key, "weird-non-s2-id")
  expect_true(is.na(s$proc))
})


test_that(".dedup_s2_reprocessed keeps the latest processing baseline", {
  # The real 2021-10-29 case observed in the user's cache.
  df <- data.frame(
    scene_id = c(
      "S2A_MSIL2A_20211029T104151_R008_T31TGM_20211030T012431",
      "S2A_MSIL2A_20211029T104151_R008_T31TGM_20230128T045356"
    ),
    obs_date = as.Date(c("2021-10-29", "2021-10-29")),
    stringsAsFactors = FALSE
  )
  out <- nemeton:::.dedup_s2_reprocessed(df)
  expect_identical(nrow(out), 1L)
  expect_identical(out$scene_id,
                   "S2A_MSIL2A_20211029T104151_R008_T31TGM_20230128T045356")
})


test_that(".dedup_s2_reprocessed dedups across the 6-field and .SAFE id forms", {
  df <- data.frame(
    scene_id = c(
      "S2A_MSIL2A_20211029T104151_R008_T31TGM_20211030T012431",
      "S2A_MSIL2A_20211029T104151_N0301_R008_T31TGM_20230128T045356.SAFE"
    ),
    stringsAsFactors = FALSE
  )
  out <- nemeton:::.dedup_s2_reprocessed(df)
  expect_identical(nrow(out), 1L)
  expect_match(out$scene_id, "20230128T045356")
})


test_that(".dedup_s2_reprocessed preserves row order and keeps unique scenes", {
  df <- data.frame(
    scene_id = c(
      "S2A_MSIL2A_20211029T104151_R008_T31TGM_20230128T045356",  # winner
      "S2A_MSIL2A_20210815T104151_R008_T31TGM_20210816T012431",  # unique
      "S2A_MSIL2A_20211029T104151_R008_T31TGM_20211030T012431"   # loser
    ),
    stringsAsFactors = FALSE
  )
  out <- nemeton:::.dedup_s2_reprocessed(df)
  expect_identical(out$scene_id, c(
    "S2A_MSIL2A_20211029T104151_R008_T31TGM_20230128T045356",
    "S2A_MSIL2A_20210815T104151_R008_T31TGM_20210816T012431"
  ))
})


test_that(".dedup_s2_reprocessed never merges genuinely different acquisitions", {
  # Same MGRS tile, but different mission / sensing time / orbit:
  # two real observations that must both survive.
  df <- data.frame(
    scene_id = c(
      "S2A_MSIL2A_20221026T103021_R108_T31TGM_20221026T140000",
      "S2B_MSIL2A_20221026T103629_R008_T31TGM_20221026T150000"
    ),
    stringsAsFactors = FALSE
  )
  expect_identical(nrow(nemeton:::.dedup_s2_reprocessed(df)), 2L)
})


test_that(".dedup_s2_reprocessed is a no-op on empty or column-less input", {
  expect_identical(
    nrow(nemeton:::.dedup_s2_reprocessed(
      data.frame(scene_id = character(0), stringsAsFactors = FALSE))),
    0L
  )
  no_col <- data.frame(x = 1:2)
  expect_identical(nemeton:::.dedup_s2_reprocessed(no_col), no_col)
})


test_that("stac_search_s2 drops reprocessing duplicates from a backend", {
  skip_if_not_installed("httr2")
  dup <- data.frame(
    scene_id = c(
      "S2A_MSIL2A_20211029T104151_R008_T31TGM_20211030T012431",
      "S2A_MSIL2A_20211029T104151_R008_T31TGM_20230128T045356"
    ),
    obs_date = as.Date("2021-10-29"),
    cloud_pct = 5,
    source = "cdse",
    stringsAsFactors = FALSE
  )
  testthat::local_mocked_bindings(
    stac_search_s2_cdse = function(bbox, start, end,
                                   max_cloud = 20, limit = 10000L) dup,
    .package = "nemeton"
  )
  res <- stac_search_s2(c(5, 46, 6, 47), "2021-10-01", "2021-11-01")
  expect_identical(nrow(res), 1L)
  expect_identical(res$scene_id,
                   "S2A_MSIL2A_20211029T104151_R008_T31TGM_20230128T045356")
})
