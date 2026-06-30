# test-microclimate-years.R — R6 reference-year selection (spec 027 §6bis)

test_that("detect picks the hottest year as heatwave, median as average", {
  heat <- c("2018" = 20, "2019" = 22, "2020" = 24, "2021" = 21, "2022" = 26)
  r <- microclimate_detect_years(eobs = heat)
  expect_identical(r$year_canicule, 2022L)   # hottest
  expect_identical(r$year_moyenne, 2019L)     # median heat = 22
  expect_true(r$year_moyenne != r$year_canicule)
})

test_that("lidar_year breaks ties on the average year", {
  # two years tie at the median distance; prefer the one near lidar_year
  heat <- c("2019" = 21, "2020" = 23, "2021" = 25, "2023" = 21)  # median 22; 2019 & 2023 tie (|.-22|=1)
  expect_identical(microclimate_detect_years(heat, lidar_year = 2023)$year_moyenne, 2023L)
  expect_identical(microclimate_detect_years(heat, lidar_year = 2019)$year_moyenne, 2019L)
})

test_that("year_window restricts the candidate years", {
  heat <- c("2010" = 30, "2020" = 22, "2021" = 24, "2022" = 26)
  # last 3 years only -> 2010 (the hottest overall) excluded
  r <- microclimate_detect_years(heat, year_window = 3)
  expect_identical(r$year_canicule, 2022L)
  expect_false("2010" %in% names(r$index))
})

test_that("invalid input errors clearly", {
  expect_error(microclimate_detect_years(eobs = NULL), "needs an E-OBS")
  expect_error(microclimate_detect_years(eobs = c(20, 22)), "named numeric")
  expect_error(microclimate_detect_years(eobs = c("2020" = 22)), "named numeric")
})
