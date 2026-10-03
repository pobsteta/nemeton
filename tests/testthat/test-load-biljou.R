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

test_that("build_biljou_soil coerces NULL/NA ewm to the default (UI field cleared)", {
  skip_if_not_installed("biljouR")
  # L'app passe ewm = na_null(input$ewm) -> NULL quand le champ est vide ;
  # sans garde-fou, biljou_soil échoue « between 1 and 3 soil layers ».
  expect_equal(build_biljou_soil(ewm = NULL)$ewm, 150)
  expect_equal(build_biljou_soil(ewm = NA)$ewm, 150)
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

# --- Audit 1.0 : unités SAFRAN perdues signalées, `years` validé -------------

test_that("load_biljou_forcing warns with the ids of units whose SAFRAN request failed", {
  skip_if_not_installed("biljouR")
  local_mocked_bindings(.biljou_forcing_safran = function(points, years, ...) {
    res <- list(`1` = .biljou_raw(2018), `2` = NULL, `3` = .biljou_raw(2018))
    attr(res, "erreurs") <- c(`2` = "HTTP error 504")
    res
  })
  seen <- list()
  expect_warning(
    m <- load_biljou_forcing(aoi = .biljou_units(3), years = 2018,
                             latitude = 48,
                             progress_callback = function(p) seen[[length(seen) + 1L]] <<- p),
    "1 unit out of 3")
  expect_named(m, c("1", "3"))
  fin <- seen[[length(seen)]]
  expect_identical(fin$current, "biljou:complete")
  expect_identical(fin$missing_ids, "2")
})

test_that(".biljou_forcing_safran keeps the reason of each failed request", {
  local_mocked_bindings(read.csv = function(file, ...) stop("HTTP error 504"),
                        .package = "utils")
  pts <- data.frame(id = 1:2, lon = c(5, 5.1), lat = c(45, 45.1))
  res <- nemeton:::.biljou_forcing_safran(pts, 2018)
  expect_null(res[["1"]])
  expect_equal(attr(res, "erreurs"), c(`1` = "HTTP error 504", `2` = "HTTP error 504"))
})

test_that("load_biljou_forcing validates years", {
  skip_if_not_installed("biljouR")
  u <- .biljou_units(1)
  expect_error(load_biljou_forcing(u, years = NULL), "required")
  expect_error(load_biljou_forcing(u, years = 2018.5), "whole years")
  expect_error(load_biljou_forcing(u, years = NA), "whole years")
  expect_error(load_biljou_forcing(u, years = "2018"), "whole years")
  expect_error(load_biljou_forcing(u, years = 1800), "whole years")
  # Injection `raw` : years NULL reste permis (aucun filtre).
  expect_true(is.data.frame(load_biljou_forcing(u, years = NULL,
                                                raw = .biljou_raw(), latitude = 48)))
})

test_that("load_biljou_forcing survives a throwing progress callback", {
  skip_if_not_installed("biljouR")
  expect_true(is.data.frame(load_biljou_forcing(
    .biljou_units(1), years = 2018, raw = .biljou_raw(), latitude = 48,
    progress_callback = function(p) stop("boom"))))
})

# --- Audit 1.0 : forçage ERA5 propre à chaque unité (cache par point) ---------

test_that(".biljou_forcing_era5 does not hand the first unit's ERA5 file to the others", {
  skip_if_not_installed("biljouR")
  skip_if_not_installed("mcera5")
  cd <- withr::local_tempdir()
  seen <- new.env()
  local_mocked_bindings(
    build_era5_request = function(..., outfile_name) {
      seen$outfile <- outfile_name
      list(list(target = paste0(outfile_name, "_2018_6.zip")))
    },
    request_era5 = function(request, out_path, ...)
      .nc_ok(file.path(out_path, paste0(seen$outfile, "_2018_6.nc"))),
    combine_netcdf = function(filenames, combined_name) .nc_ok(combined_name),
    # Température horaire = longitude du point lu dans le NOM du fichier.
    extract_clim = function(src, ...) {
      lon <- as.numeric(sub("p", ".", sub("^era5_([0-9p]+)_.*", "\\1", basename(src))))
      t <- seq(as.POSIXct("2018-06-01", tz = "UTC"), by = "hour", length.out = 48)
      data.frame(obs_time = t, temp = lon, swdown = 200, windspeed = 2,
                 relhum = 70, precip = 0)
    },
    .package = "mcera5")
  pts <- data.frame(id = 1:2, lon = c(5, 12), lat = c(45, 45))
  out <- nemeton:::.biljou_forcing_era5(pts, 2018L, cd)
  expect_named(out, c("1", "2"))
  # Deux combinés distincts dans le même cache_dir, un par point.
  expect_setequal(list.files(cd, pattern = "_2018_2018\\.nc$"),
                  c("era5_5p00_45p00_2018_2018.nc", "era5_12p00_45p00_2018_2018.nc"))
  # Une PET différente par point (température différente) : pas de forçage partagé.
  expect_false(isTRUE(all.equal(out[["1"]]$pet, out[["2"]]$pet)))
})
