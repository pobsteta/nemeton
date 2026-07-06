# test-load-eobs.R — acquisition E-OBS (spec 034).
#
# Le chemin CDS (téléchargement ecmwfr) n'est pas jouable en CI : on teste le
# chemin PUR (réduction estivale par année depuis un raster quotidien daté),
# l'injection `nc`, la dégradation, et l'alimentation des deux consommateurs.

# Raster quotidien synthétique daté sur 2 ans (JJA + un peu de printemps).
.eobs_daily <- function(years = c(2014, 2018), months = 5:8, per_month = 3,
                        base = 20) {
  dates <- do.call(c, lapply(years, function(y)
    as.Date(sprintf("%d-%02d-%02d", y, rep(months, each = per_month),
                    rep(seq_len(per_month) * 5, times = length(months))))))
  n <- length(dates)
  r <- terra::rast(nrows = 4, ncols = 4, xmin = 3, xmax = 4, ymin = 45, ymax = 46,
                   nlyrs = n, crs = "EPSG:4326")
  # valeur = base + (année - min) * 5 + mois (l'été 2018 plus chaud que 2014).
  yy <- as.integer(format(dates, "%Y")); mm <- as.integer(format(dates, "%m"))
  for (i in seq_len(n)) {
    terra::values(r[[i]]) <- base + (yy[i] - min(years)) * 5 + mm[i]
  }
  terra::time(r) <- dates
  r
}

test_that(".eobs_summer_by_year reduces daily E-OBS to one summer layer per year", {
  skip_if_not_installed("terra")
  daily <- .eobs_daily()
  out <- nemeton:::.eobs_summer_by_year(daily, years = c(2014, 2018), months = 6:8)
  expect_true(inherits(out, "SpatRaster"))
  expect_equal(terra::nlyr(out), 2L)
  expect_identical(names(out), c("2014", "2018"))
  # 2018 (plus chaud) > 2014 en T°max estivale moyenne.
  m <- terra::global(out, "mean", na.rm = TRUE)[[1]]
  expect_gt(m[2], m[1])
})

test_that(".eobs_summer_by_year honours months and reducers", {
  skip_if_not_installed("terra")
  daily <- .eobs_daily()
  # juillet seul (mois 7) : moyenne = base + dyear + 7.
  jul <- nemeton:::.eobs_summer_by_year(daily, years = 2014, months = 7, reducer = "mean")
  expect_equal(terra::global(jul, "mean", na.rm = TRUE)[[1]][1], 20 + 0 + 7)
  # sum sur JJA (3 mois × 3 valeurs = 9 couches) != mean.
  s <- nemeton:::.eobs_summer_by_year(daily, years = 2014, months = 6:8, reducer = "sum")
  expect_gt(terra::global(s, "mean", na.rm = TRUE)[[1]][1], 100)
})

test_that(".eobs_summer_by_year aborts on a raster without time", {
  skip_if_not_installed("terra")
  r <- terra::rast(nrows = 2, ncols = 2, nlyrs = 2)
  expect_error(nemeton:::.eobs_summer_by_year(r), "time")
})

test_that("load_eobs_source runs the pure path from an injected `nc` raster", {
  skip_if_not_installed("terra")
  out <- load_eobs_source(aoi = NULL, var = "tx", years = c(2014, 2018),
                          nc = .eobs_daily(), source = "nc")
  expect_true(inherits(out, "SpatRaster"))
  expect_identical(names(out), c("2014", "2018"))
})

test_that("load_eobs_source degrades to NULL (no nc, non-cds source)", {
  skip_if_not_installed("terra")
  expect_null(load_eobs_source(aoi = NULL, source = "nope"))
})

test_that("load_eobs_source emits step progress (read -> reduce -> complete)", {
  skip_if_not_installed("terra")
  steps <- character(0)
  out <- load_eobs_source(
    aoi = NULL, var = "tx", years = c(2014, 2018),
    nc = .eobs_daily(), source = "nc",
    progress_callback = function(p) steps[[length(steps) + 1L]] <<- p$current)
  expect_true(inherits(out, "SpatRaster"))
  expect_identical(steps, c("eobs:read", "eobs:reduce", "eobs:complete"))
})

test_that("load_eobs_source emits an unavailable payload on degradation", {
  skip_if_not_installed("terra")
  seen <- list()
  load_eobs_source(aoi = NULL, source = "nope",
                   progress_callback = function(p) seen[[length(seen) + 1L]] <<- p)
  expect_identical(seen[[length(seen)]]$current, "eobs:unavailable")
  expect_identical(seen[[length(seen)]]$reason, "no_source")
})

test_that("load_eobs_source rejects an unknown variable", {
  skip_if_not_installed("terra")
  expect_error(load_eobs_source(aoi = NULL, var = "zzz", nc = .eobs_daily()),
               "var")
})

test_that("E-OBS period block inference covers a within-block year range", {
  # Bloc courant (ouvert) : la borne haute suit l'année demandée la plus récente
  # -> plus de plafond figé à 2024 (régression v0.139.0).
  expect_identical(nemeton:::.eobs_cds_period(2014:2020), "2011_2020")
  expect_identical(nemeton:::.eobs_cds_period(2015:2025), "2011_2025")
  expect_identical(nemeton:::.eobs_cds_period(2011:2030), "2011_2030")
  # Bloc clos : borne réelle, inchangée.
  expect_identical(nemeton:::.eobs_cds_period(1996:2005), "1995_2010")
  expect_null(nemeton:::.eobs_cds_period(c(2008, 2015)))   # chevauche 2 blocs
})

test_that("load_eobs_source output feeds microclimate_detect_years", {
  skip_if_not_installed("terra")
  # 4 ans pour laisser detect_years choisir moyenne vs canicule.
  daily <- .eobs_daily(years = c(2014, 2016, 2019, 2022))
  tx <- load_eobs_source(aoi = NULL, nc = daily, source = "nc")
  det <- microclimate_detect_years(eobs = tx)
  expect_true(is.list(det))
  expect_true(all(c("year_moyenne", "year_canicule") %in% names(det)))
})

test_that(".eobs_cds_fetch normalise version/résolution en underscore pour le CDS", {
  skip_if_not_installed("ecmwfr")
  captured <- NULL
  testthat::local_mocked_bindings(
    wf_request = function(request, ...) { captured <<- request; NULL },
    .package = "ecmwfr")
  nemeton:::.eobs_cds_fetch("maximum_temperature", years = 2022L,
                            cache_dir = withr::local_tempdir(),
                            version = "30.0e", resolution = "0.1deg")
  expect_identical(captured$version, "30_0e")          # point -> underscore
  expect_identical(captured$grid_resolution, "0_1deg")
  expect_identical(captured$period, "2011_2022")       # borne haute = année demandée
})

test_that(".eobs_cds_fetch reuses a cached block without re-downloading", {
  skip_if_not_installed("ecmwfr")
  cache_dir <- withr::local_tempdir()
  # Pré-seed le fichier de cache attendu pour (var × période × version × résolution).
  period <- nemeton:::.eobs_cds_period(2015:2020)          # "2011_2020"
  ncf <- nemeton:::.eobs_cache_file("maximum_temperature", period,
                                    "30.0e", "0.1deg", cache_dir)
  writeLines("stub", ncf)
  called <- FALSE
  testthat::local_mocked_bindings(
    wf_request = function(request, ...) { called <<- TRUE; NULL },
    .package = "ecmwfr")
  out <- nemeton:::.eobs_cds_fetch("maximum_temperature", years = 2015:2020,
                                   cache_dir = cache_dir,
                                   version = "30.0e", resolution = "0.1deg")
  expect_identical(normalizePath(out), normalizePath(ncf)) # cache-hit renvoyé
  expect_false(called)                                     # AUCUN re-téléchargement
})
