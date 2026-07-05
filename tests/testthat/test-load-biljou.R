# test-load-biljou.R — acquisition forçage/sol BILJOU (spec 027 L2, option B).
#
# Les téléchargements SAFRAN (dataverse) et ERA5 (mcera5 + CDS) ne sont pas
# jouables en CI : on teste le chemin d'injection `raw` (conversion
# safran_to_meteo), la construction du sol, la dérivation des points, et la
# dégradation propre.

.biljou_raw <- function(year = 2018, n = 20) {
  data.frame(
    DATE     = seq(as.Date(sprintf("%d-06-01", year)), by = "day", length.out = n),
    PRELIQ_Q = stats::runif(n, 0, 8),
    PRENEI_Q = 0,
    ETP_Q    = stats::runif(n, 2, 5),
    T_Q      = stats::runif(n, 14, 26),
    SSI_Q    = stats::runif(n, 100, 300),
    FF_Q     = stats::runif(n, 1, 3),
    HU_Q     = stats::runif(n, 55, 90))
}

.biljou_units <- function(n = 2) {
  polys <- lapply(seq_len(n), function(i) sf::st_polygon(list(rbind(
    c(i, 0), c(i + 0.8, 0), c(i + 0.8, 0.8), c(i, 0.8), c(i, 0)))))
  sf::st_sf(id = seq_len(n), geometry = sf::st_sfc(polys, crs = 4326))
}

test_that("build_biljou_soil returns a biljou_soil with the requested ewm", {
  skip_if_not_installed("biljouR")
  s <- build_biljou_soil(ewm = 150)
  expect_s3_class(s, "biljou_soil")
  expect_equal(s$ewm, 150)
  # ewm surchargeable
  expect_equal(build_biljou_soil(ewm = 90)$ewm, 90)
})

test_that("build_biljou_soil degrades to NULL without biljouR", {
  testthat::local_mocked_bindings(
    requireNamespace = function(pkg, ...) if (identical(pkg, "biljouR")) FALSE else TRUE,
    .package = "base")
  expect_null(build_biljou_soil(ewm = 150))
})

test_that(".biljou_points derives id/lon/lat centroids in WGS84", {
  skip_if_not_installed("sf")
  pts <- nemeton:::.biljou_points(.biljou_units(3))
  expect_identical(names(pts), c("id", "lon", "lat"))
  expect_identical(pts$id, 1:3)
  expect_true(all(pts$lon > 0 & pts$lon < 10))     # cohérent avec l'emprise test
})

test_that("load_biljou_forcing converts an injected raw SAFRAN frame (tested path)", {
  skip_if_not_installed("biljouR")
  m <- load_biljou_forcing(aoi = .biljou_units(1), years = 2018,
                           raw = .biljou_raw(2018), latitude = 48)
  expect_true(is.data.frame(m))
  expect_true(all(c("date", "doy", "pet", "rain") %in% names(m)))
  expect_true(all(as.integer(format(m$date, "%Y")) == 2018))
})

test_that("load_biljou_forcing filters the raw series to the requested years", {
  skip_if_not_installed("biljouR")
  raw <- rbind(.biljou_raw(2017), .biljou_raw(2018))
  m <- load_biljou_forcing(aoi = .biljou_units(1), years = 2018, raw = raw, latitude = 48)
  expect_true(all(as.integer(format(m$date, "%Y")) == 2018))
})

test_that("load_biljou_forcing degrades to NULL without biljouR", {
  testthat::local_mocked_bindings(
    requireNamespace = function(pkg, ...) if (identical(pkg, "biljouR")) FALSE else TRUE,
    .package = "base")
  expect_null(load_biljou_forcing(aoi = .biljou_units(1), years = 2018,
                                  raw = .biljou_raw()))
})

test_that("load_biljou_forcing output + soil feed regen_bilan_hydrique", {
  skip_if_not_installed("biljouR")
  # Un an complet (biljou_run_grid a besoin d'un cycle) partagé sur 2 unités.
  raw <- .biljou_raw(2018, n = 365)
  meteo <- load_biljou_forcing(aoi = .biljou_units(2), years = 2018,
                               raw = raw, latitude = 48)
  sol <- build_biljou_soil(ewm = 150)
  u <- sf::st_transform(.biljou_units(2), 2154)
  out <- regen_bilan_hydrique(u, meteo = meteo, sol = sol, lai_max = 5,
                              years = 2018)
  expect_true(all(c("njstress", "istress", "rew_min", "deb_stress") %in% names(out)))
})

test_that("load_biljou_forcing emits progress (raw path -> complete)", {
  skip_if_not_installed("biljouR")
  seen <- character(0)
  load_biljou_forcing(aoi = .biljou_units(1), years = 2018, raw = .biljou_raw(),
                      latitude = 48,
                      progress_callback = function(p) seen[[length(seen) + 1L]] <<- p$current)
  expect_identical(seen, "biljou:complete")
})

test_that("load_biljou_forcing emits an unavailable payload without biljouR", {
  testthat::local_mocked_bindings(
    requireNamespace = function(pkg, ...) if (identical(pkg, "biljouR")) FALSE else TRUE,
    .package = "base")
  seen <- list()
  load_biljou_forcing(aoi = .biljou_units(1), years = 2018, raw = .biljou_raw(),
                      progress_callback = function(p) seen[[length(seen) + 1L]] <<- p)
  expect_identical(seen[[length(seen)]]$current, "biljou:unavailable")
})

test_that(".biljou_safran_edr_url builds a valid GéoSAS EDR position query", {
  u <- nemeton:::.biljou_safran_edr_url(961000, 6451000, c(2018, 2020))
  expect_true(grepl("safran-isba/position", u))
  expect_true(grepl("crs=EPSG:2154", u))               # CRS robuste (pas CRS84 bêta)
  expect_true(grepl("POINT\\(961000.0%20", u))         # coords L93, espace encodé
  expect_true(grepl("datetime=2018-01-01.*/2020-12-31", u))
  expect_true(grepl("parameter-name=ETP_Q,PRELIQ_Q,PRENEI_Q", u))
  expect_true(grepl("f=CSV", u))
})
