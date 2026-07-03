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

# --- chemin SpatRaster (extraction estivale par an sur l'AOI, spec 027 L2) ---

.mcy_rast <- function(vals, years, left = NULL, right = NULL) {
  # 2 lignes x 4 colonnes ; une couche par année. Si left/right fournis, moitié
  # gauche = left[i], moitié droite = right[i] (pour tester crop+mask sur l'AOI).
  r <- terra::rast(nrows = 2, ncols = 4, xmin = 0, xmax = 4, ymin = 0, ymax = 2,
                   nlyrs = length(years), crs = "EPSG:2154")
  for (i in seq_along(years)) {
    if (is.null(left)) {
      terra::values(r[[i]]) <- rep(vals[i], terra::ncell(r))
    } else {
      # ordre des cellules : ligne par ligne, gauche->droite
      row <- c(left[i], left[i], right[i], right[i])
      terra::values(r[[i]]) <- rep(row, times = 2)
    }
  }
  names(r) <- as.character(years)
  r
}

test_that("detects years from a per-year summer SpatRaster over the AOI", {
  skip_if_not_installed("terra")
  vals <- c(20, 22, 24, 21, 26)                    # 2022 le plus chaud, médiane 22
  r <- .mcy_rast(vals, c(2018, 2019, 2020, 2021, 2022))
  aoi <- sf::st_as_sf(sf::st_sfc(
    sf::st_polygon(list(rbind(c(0, 0), c(4, 0), c(4, 2), c(0, 2), c(0, 0)))),
    crs = 2154))
  out <- microclimate_detect_years(eobs = r, aoi = aoi)
  expect_identical(out$year_canicule, 2022L)
  expect_identical(out$year_moyenne, 2019L)
  expect_equal(unname(out$index[["2022"]]), 26)
})

test_that("SpatRaster path averages only within the AOI (crop + mask)", {
  skip_if_not_installed("terra")
  # gauche froid / droite chaud ; AOI sur la moitié GAUCHE -> index = froid.
  r <- .mcy_rast(vals = NULL, years = c(2020, 2021),
                 left = c(10, 12), right = c(30, 32))
  aoi_left <- sf::st_as_sf(sf::st_sfc(
    sf::st_polygon(list(rbind(c(0, 0), c(2, 0), c(2, 2), c(0, 2), c(0, 0)))),
    crs = 2154))
  out <- microclimate_detect_years(eobs = r, aoi = aoi_left)
  expect_equal(unname(out$index[["2020"]]), 10)
  expect_equal(unname(out$index[["2021"]]), 12)
  expect_identical(out$year_canicule, 2021L)
})

test_that("years argument overrides / supplies the layer years", {
  skip_if_not_installed("terra")
  r <- .mcy_rast(c(20, 26, 22), years = c(1, 2, 3))   # noms non-années
  names(r) <- c("a", "b", "c")                         # pas parsables en années
  aoi <- sf::st_as_sf(sf::st_sfc(
    sf::st_polygon(list(rbind(c(0, 0), c(4, 0), c(4, 2), c(0, 2), c(0, 0)))),
    crs = 2154))
  expect_error(microclimate_detect_years(eobs = r, aoi = aoi), "one year per")
  out <- microclimate_detect_years(eobs = r, aoi = aoi, years = c(2015, 2016, 2017))
  expect_identical(out$year_canicule, 2016L)
})

test_that("year_window works on the SpatRaster path", {
  skip_if_not_installed("terra")
  r <- .mcy_rast(c(30, 22, 24, 26), c(2010, 2020, 2021, 2022))
  aoi <- sf::st_as_sf(sf::st_sfc(
    sf::st_polygon(list(rbind(c(0, 0), c(4, 0), c(4, 2), c(0, 2), c(0, 0)))),
    crs = 2154))
  out <- microclimate_detect_years(eobs = r, aoi = aoi, year_window = 3)
  expect_identical(out$year_canicule, 2022L)
  expect_false("2010" %in% names(out$index))
})
