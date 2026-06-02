# test-obs_pixel-deprecation.R — the three obs_pixel consumers were
# deprecated in v0.58.0 (removal scheduled v0.60.0) when the obs_pixel
# table was dropped. Each must emit a deprecation warning. Offline:
# the functions warn before any DB work, and `try()` swallows the
# downstream error so `expect_warning()` can capture the warning.

test_that("read_obs_pixel emits a deprecation warning", {
  expect_warning(
    try(read_obs_pixel("not-a-con", 1L), silent = TRUE),
    "deprecated"
  )
})

test_that("list_fast_alerts_for_zone emits a deprecation warning", {
  expect_warning(
    try(list_fast_alerts_for_zone("not-a-con", 1L,
                                  date_from = "2025-01-01",
                                  date_to   = "2025-02-01"),
        silent = TRUE),
    "deprecated"
  )
})

test_that("detect_alerts emits a deprecation warning", {
  expect_warning(
    try(detect_alerts("not-a-con", 1L), silent = TRUE),
    "deprecated"
  )
})
