# tests/testthat/test-uts-calibration-rmqs.R
# Integrity checks on the F1 calibration artifact
# inst/extdata/uts_fertilite_rmqs_calibration.csv produced by
# inst/scripts/calibrate_uts_rmqs.R from the RMQS dataset
# (DOI 10.15454/QSXKGA, Etalab 2.0). This test validates the CSV
# itself — it does NOT re-download RMQS nor re-run the pipeline.

cal_csv_path <- function() {
  system.file("extdata", "uts_fertilite_rmqs_calibration.csv",
              package = "nemeton", mustWork = TRUE)
}

read_calibration <- function() {
  utils::read.csv(cal_csv_path(), stringsAsFactors = FALSE,
                  fileEncoding = "UTF-8")
}

test_that("calibration CSV ships and loads", {
  expect_true(file.exists(cal_csv_path()))
  cal <- read_calibration()
  expect_s3_class(cal, "data.frame")
  expect_gte(nrow(cal), 30)  # We expect coverage of most AFES families
})

test_that("calibration CSV has the expected schema", {
  cal <- read_calibration()
  expect_equal(names(cal),
               c("rpf_code", "n_sites", "cec_median", "cec_q25",
                 "cec_q75", "observed_score", "expert_score",
                 "delta", "flag_outlier"))
})

test_that("every calibrated rpf_code exists in the expert table", {
  cal <- read_calibration()
  expert_codes <- read_uts_fertility_table()$rpf_code
  expect_true(all(cal$rpf_code %in% expert_codes))
})

test_that("all calibrated scores are in [0, 100]", {
  cal <- read_calibration()
  expect_true(all(cal$observed_score >= 0 & cal$observed_score <= 100))
  expect_true(all(cal$expert_score %in% c(15, 35, 55, 75, 90)))
})

test_that("delta = observed - expert (arithmetic consistency)", {
  cal <- read_calibration()
  expect_equal(cal$delta, cal$observed_score - cal$expert_score,
               tolerance = 0.1)
})

test_that("flag_outlier = |delta| > 20", {
  cal <- read_calibration()
  expect_equal(cal$flag_outlier, abs(cal$delta) > 20)
})

test_that("every calibration row represents at least one RMQS site", {
  cal <- read_calibration()
  expect_true(all(cal$n_sites >= 1))
  # RMQS 1st campaign holds ~2240 sites — an aggregate row with more
  # than that many would indicate a join bug.
  expect_true(all(cal$n_sites <= 2500))
})

test_that("CEC quartiles are coherent (Q25 <= median <= Q75)", {
  cal <- read_calibration()
  # Allow ties (n <= 4 sites) where all three may equal.
  expect_true(all(cal$cec_q25 <= cal$cec_median + 1e-6))
  expect_true(all(cal$cec_median <= cal$cec_q75 + 1e-6))
})
