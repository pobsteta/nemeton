# test-load-eobs.R — acquisition E-OBS (spec 034).
#
# Le chemin CDS (téléchargement ecmwfr) n'est pas jouable en CI : on teste le
# chemin PUR (réduction estivale par année depuis un raster quotidien daté),
# l'injection `nc`, la dégradation, et l'alimentation des deux consommateurs.

# Raster quotidien synthétique daté sur 2 ans (mai-août, TOUS les jours : un
# été incomplet est désormais écarté — audit 1.0). `per_month` borne le nombre
# de jours par mois pour fabriquer un été lacunaire.
.eobs_daily <- function(years = c(2014, 2018), months = 5:8, per_month = 31,
                        base = 20) {
  dates <- do.call(c, lapply(years, function(y) {
    d <- seq(as.Date(sprintf("%d-01-01", y)), as.Date(sprintf("%d-12-31", y)),
             by = "day")
    d <- d[as.integer(format(d, "%m")) %in% months]
    d[as.integer(format(d, "%d")) <= per_month]
  }))
  n <- length(dates)
  r <- terra::rast(nrows = 4, ncols = 4, xmin = 3, xmax = 4, ymin = 45, ymax = 46,
                   nlyrs = n, crs = "EPSG:4326")
  # valeur = base + (année - min) * 5 + mois (l'été 2018 plus chaud que 2014).
  yy <- as.integer(format(dates, "%Y")); mm <- as.integer(format(dates, "%m"))
  v <- base + (yy - min(years)) * 5 + mm
  # Une colonne par couche (vectorisé : ~120 couches par an).
  terra::values(r) <- matrix(rep(v, each = terra::ncell(r)), ncol = n)
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
  # sum sur JJA (92 jours) != mean.
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

test_that("load_eobs_source output feeds microclimate_detect_years", {
  skip_if_not_installed("terra")
  # 4 ans pour laisser detect_years choisir moyenne vs canicule.
  daily <- .eobs_daily(years = c(2014, 2016, 2019, 2022))
  tx <- load_eobs_source(aoi = NULL, nc = daily, source = "nc")
  det <- microclimate_detect_years(eobs = tx)
  expect_true(is.list(det))
  expect_true(all(c("year_moyenne", "year_canicule") %in% names(det)))
})

test_that(".eobs_cds_fetch envoie la requête de novembre 2026 : sans période, avec licence", {
  skip_if_not_installed("ecmwfr")
  captured <- NULL
  testthat::local_mocked_bindings(
    wf_request = function(request, ...) { captured <<- request; NULL },
    .package = "ecmwfr")
  # wf_request factice ne renvoie rien -> erreur explicite (plus de NULL muet).
  expect_error(nemeton:::.eobs_cds_fetch("maximum_temperature", years = 2022L,
                            cache_dir = withr::local_tempdir(),
                            version = "34.0e", resolution = "0.1deg"),
               "returned no\\s+file")
  expect_identical(captured$version, "34_0e")          # point -> underscore
  expect_identical(captured$grid_resolution, "0_1deg")
  # Le CDS refuse toute requête qui porte encore `period` (« invalid request »).
  expect_false("period" %in% names(captured))
  expect_identical(captured$licence_type, "open_data_licence")
})

test_that("la licence suit la version E-OBS", {
  expect_identical(nemeton:::.eobs_licence("34.0e"), "open_data_licence")
  expect_identical(nemeton:::.eobs_licence("35_0e"), "open_data_licence")
  expect_identical(nemeton:::.eobs_licence("30.0e"), "restricted_research_licence")
  expect_identical(nemeton:::.eobs_licence("v33.0e"), "restricted_research_licence")
  expect_identical(nemeton:::.eobs_licence("bizarre"), "restricted_research_licence")
})

test_that("period est ignoré, avec un avertissement", {
  skip_if_not_installed("terra")
  rlang::reset_warning_verbosity("nemeton_eobs_period")
  local_mocked_bindings(.eobs_cds_fetch = function(...) stop("no CDS"))
  vus <- character(0)
  withCallingHandlers(
    load_eobs_source(aoi = NULL, years = 2018, source = "cds", period = "2011_2024"),
    warning = function(w) { vus <<- c(vus, conditionMessage(w)); invokeRestart("muffleWarning") })
  expect_true(any(grepl("`period` is ignored", vus, fixed = TRUE)))
})

test_that(".eobs_cds_fetch refuses a zip-slip CDS archive (audit 1.0, sécurité)", {
  skip_if_not_installed("ecmwfr")
  skip_if(!nzchar(Sys.which("zip")), "zip utility not available")
  root <- withr::local_tempdir()
  cache_dir <- file.path(root, "cache"); dir.create(cache_dir)
  # Archive hostile : une entrée `../evil.nc` (nom réécrit après zip).
  src <- withr::local_tempdir()
  writeLines("x", file.path(src, "aaaaaaa.nc"))
  z <- file.path(root, "cds.zip")
  withr::with_dir(src, utils::zip(z, "aaaaaaa.nc", flags = "-q"))
  b <- readBin(z, "raw", file.size(z))
  pat <- charToRaw("aaaaaaa.nc"); n <- length(pat)
  for (i in seq_len(length(b) - n + 1L)) {
    if (identical(b[i:(i + n - 1L)], pat)) b[i:(i + n - 1L)] <- charToRaw("../evil.nc")
  }
  writeBin(b, z)
  testthat::local_mocked_bindings(
    wf_request = function(request, ...) z, .package = "ecmwfr")
  expect_error(
    nemeton:::.eobs_cds_fetch("maximum_temperature", years = 2022L,
                              cache_dir = cache_dir,
                              version = "34.0e", resolution = "0.1deg"),
    "unsafe entry")
  expect_false(file.exists(file.path(root, "evil.nc")))
})

test_that(".eobs_cds_fetch reuses the cached series without re-downloading", {
  skip_if_not_installed("ecmwfr")
  cache_dir <- withr::local_tempdir()
  # Pré-seed le fichier de cache attendu pour (var × série × version × résolution).
  ncf <- nemeton:::.eobs_cache_file("maximum_temperature", nemeton:::.EOBS_CDS_SERIE,
                                    "34.0e", "0.1deg", cache_dir)
  writeLines("stub", ncf)
  called <- FALSE
  testthat::local_mocked_bindings(
    wf_request = function(request, ...) { called <<- TRUE; NULL },
    .package = "ecmwfr")
  out <- nemeton:::.eobs_cds_fetch("maximum_temperature", years = 2015:2020,
                                   cache_dir = cache_dir,
                                   version = "34.0e", resolution = "0.1deg")
  expect_identical(normalizePath(out), normalizePath(ncf)) # cache-hit renvoyé
  expect_false(called)                                     # AUCUN re-téléchargement
})

# --- Audit 1.0 : été incomplet, années à cheval, erreurs non muettes ---------

test_that(".eobs_summer_by_year drops an incomplete summer with a warning", {
  skip_if_not_installed("terra")
  # 2014 complet ; 2018 réduit à juin (cas de l'été en cours).
  full <- .eobs_daily(years = 2014)
  juin <- .eobs_daily(years = 2018, months = 6)
  daily <- c(full, juin)
  expect_warning(
    out <- nemeton:::.eobs_summer_by_year(daily, months = 6:8),
    "incomplete summer.*2018 \\(30/92 days\\)")
  expect_identical(names(out), "2014")
  # 90 % des jours suffit : 28 jours sur 31 par mois (84/92 = 91 %) -> gardé.
  presque <- .eobs_daily(years = 2014, months = 6:8, per_month = 28)
  expect_no_warning(ok <- nemeton:::.eobs_summer_by_year(presque, months = 6:8))
  expect_identical(names(ok), "2014")
  # Que des étés incomplets -> erreur explicite.
  expect_error(suppressWarnings(nemeton:::.eobs_summer_by_year(juin, months = 6:8)),
               "No E-OBS summer layers")
})

test_that("load_eobs_source keeps the CDS error message in a warning and the payload", {
  skip_if_not_installed("terra")
  local_mocked_bindings(.eobs_cds_fetch = function(...)
    stop("403 required licences not accepted"))
  seen <- list()
  expect_warning(
    out <- load_eobs_source(aoi = NULL, years = 2018, source = "cds",
                            progress_callback = function(p) seen[[length(seen) + 1L]] <<- p),
    "licences not accepted")
  expect_null(out)
  fin <- seen[[length(seen)]]
  expect_identical(fin$current, "eobs:unavailable")
  expect_identical(fin$reason, "cds")
  expect_match(fin$message, "licences not accepted")
})

test_that("load_eobs_source reports a reduce failure with its message", {
  skip_if_not_installed("terra")
  seen <- list()
  expect_warning(
    out <- load_eobs_source(aoi = NULL, years = 2018, source = "nc",
                            nc = .eobs_daily(years = 2014),
                            progress_callback = function(p) seen[[length(seen) + 1L]] <<- p),
    "No E-OBS summer layers")
  expect_null(out)
  expect_identical(seen[[length(seen)]]$reason, "reduce_error")
  expect_match(seen[[length(seen)]]$message, "No E-OBS summer layers")
})

test_that("tn with the min reducer gives the annual minimum (2026.11.32)", {
  skip_if_not_installed("terra")
  jours <- seq(as.Date("2003-01-01"), as.Date("2003-12-31"), by = "day")
  r <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 0.2, ymin = 45,
                   ymax = 45.2, crs = "EPSG:4326", nlyrs = length(jours))
  v <- rep(3, length(jours)); v[40] <- -14
  terra::values(r) <- matrix(rep(v, each = 4), nrow = 4)
  terra::time(r) <- jours
  out <- load_eobs_source(NULL, var = "tn", months = 1:12, reducer = "min", nc = r)
  expect_equal(names(out), "2003")
  expect_equal(unique(terra::values(out)[, 1]), -14)
})

test_that("an upstream message with braces is reported, not parsed by cli", {
  # 2026-11-22 : le CDS renvoie la requête en dict Python (« {'grid_resolution':
  # '0_1deg', … } ») ; passé brut à cli, il levait « Could not parse cli `{}` »
  # au lieu de l'avertissement, et l'app perdait la détection des années.
  skip_if_not_installed("terra")
  local_mocked_bindings(.eobs_cds_fetch = function(...)
    stop("CDS said {'grid_resolution': '0_1deg', 'period': 'full'}"))
  w <- NULL
  out <- withCallingHandlers(
    load_eobs_source(aoi = NULL, var = "tx", years = 2022L, source = "cds"),
    warning = function(x) { w <<- conditionMessage(x); invokeRestart("muffleWarning") })
  expect_null(out)
  expect_match(w, "'grid_resolution': '0_1deg'", fixed = TRUE)
})

test_that("les étés demandés sont choisis avant le découpage de l'emprise", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  # Série longue : seule l'année demandée doit atteindre crop/mask.
  daily <- .eobs_daily(years = c(2014, 2016, 2018))
  aoi <- sf::st_as_sfc(sf::st_bbox(c(xmin = 3, ymin = 45, xmax = 4, ymax = 46),
                                    crs = sf::st_crs(4326)))
  vu <- NULL
  local_mocked_bindings(crop = function(x, ...) { vu <<- terra::nlyr(x); x },
                        .package = "terra")
  out <- nemeton:::.eobs_summer_by_year(daily, aoi = aoi, years = 2016L)
  expect_identical(names(out), "2016")
  expect_equal(vu, 92L)                      # juin-août 2016, pas toute la pile
})

test_that("eobs_cached_file rend la série en cache, sinon NULL", {
  cd <- withr::local_tempdir()
  expect_null(eobs_cached_file("rr", cache_dir = cd))
  f <- nemeton:::.eobs_cache_file("precipitation_amount", nemeton:::.EOBS_CDS_SERIE,
                                  "34.0e", "0.1deg", cd)
  writeLines("stub", f)
  expect_identical(eobs_cached_file("rr", cache_dir = cd), f)
  expect_null(eobs_cached_file("rr", version = "30.0e", cache_dir = cd))
  expect_error(eobs_cached_file("zz", cache_dir = cd), "Unknown E-OBS")
})

test_that("eobs_last_complete_year lit la table des versions mesurées", {
  cd <- withr::local_tempdir()                 # cache vide : voie table
  a34 <- eobs_last_complete_year("34.0e", cache_dir = cd)
  expect_identical(as.integer(a34), 2025L)     # série arrêtée au 2026-06-30
  expect_identical(attr(a34, "end_date"), as.Date("2026-06-30"))
  expect_identical(attr(a34, "source"), "table")
  # Juin seul est complet en 2026 pour la 34.0e.
  expect_identical(as.integer(eobs_last_complete_year("34.0e", months = 6L,
                                                      cache_dir = cd)), 2026L)
  expect_identical(as.integer(eobs_last_complete_year("v33_0e", cache_dir = cd)),
                   2025L)
  expect_warning(inc <- eobs_last_complete_year("99.0e", cache_dir = cd),
                 "Unknown E-OBS version")
  expect_true(is.na(inc))
  expect_error(eobs_last_complete_year(months = 13, cache_dir = cd), "months")
})

test_that("eobs_last_complete_year lit les dates de la série en cache", {
  skip_if_not_installed("terra")
  cd <- withr::local_tempdir()
  ecrire <- function(fin) {
    jours <- seq(as.Date("2025-06-01"), as.Date(fin), by = "day")
    r <- terra::rast(nrows = 2, ncols = 2, nlyrs = length(jours),
                     xmin = 3, xmax = 4, ymin = 45, ymax = 46, vals = 20)
    terra::time(r) <- jours
    f <- nemeton:::.eobs_cache_file("mean_temperature", nemeton:::.EOBS_CDS_SERIE,
                                    "35.0e", "0.1deg", cd)
    unlink(f)
    terra::writeCDF(r, f, varname = "tg", overwrite = TRUE)
    f
  }
  ecrire("2026-08-31")                         # été 2026 complet
  a <- eobs_last_complete_year("35.0e", cache_dir = cd)
  expect_identical(as.integer(a), 2026L)
  expect_identical(attr(a, "source"), "cache")
  expect_identical(attr(a, "end_date"), as.Date("2026-08-31"))
  ecrire("2026-08-10")                         # 71 jours sur 92 < 90 %
  expect_identical(as.integer(eobs_last_complete_year("35.0e", var = "tg",
                                                      cache_dir = cd)), 2025L)
  # La variable demandée n'est pas en cache : retour à la table (inconnue ici).
  expect_warning(eobs_last_complete_year("35.0e", var = "rr", cache_dir = cd),
                 "Unknown E-OBS version")
})
