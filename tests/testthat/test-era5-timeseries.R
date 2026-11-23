# Forçage ERA5 par le jeu CDS `reanalysis-era5-single-levels-timeseries`
# (mission 039). Données synthétiques, aucun réseau.

# NetCDF `timeseries` synthétique : une maille, `valid_time` en secondes depuis
# 1970, les 10 variables. `vals` remplace tout ou partie des valeurs par défaut.
.ts_fixture <- function(path, times, vals = list(), sans = character()) {
  skip_if_not_installed("ncdf4")
  n <- length(times)
  def <- list(t2m = 283.15, d2m = 278.15, sp = 95000, u10 = 3, v10 = 4,
              tp = 0.001, tcc = 0.5, ssrd = 1.8e6, fdir = 0.9e6, strd = 1.08e6)
  for (k in names(vals)) def[[k]] <- vals[[k]]
  dx <- ncdf4::ncdim_def("longitude", "degrees_east", 4.75)
  dy <- ncdf4::ncdim_def("latitude", "degrees_north", 47.25)
  dt <- ncdf4::ncdim_def("valid_time", "seconds since 1970-01-01", as.numeric(times),
                         unlim = TRUE)
  noms <- setdiff(names(def), sans)
  vars <- lapply(noms, function(k) ncdf4::ncvar_def(k, "", list(dx, dy, dt), prec = "double"))
  nc <- ncdf4::nc_create(path, vars)
  for (i in seq_along(noms)) ncdf4::ncvar_put(nc, vars[[i]], rep_len(def[[noms[i]]], n))
  ncdf4::nc_close(nc)
  invisible(path)
}

.ts_heures <- function(n = 6, debut = "2023-06-01 00:00") {
  as.numeric(as.POSIXct(debut, tz = "UTC")) + 3600 * (seq_len(n) - 1)
}

.req_mois <- function(annee, n) {
  lapply(seq_len(n), function(m) list(
    target = sprintf("era5_%d_%d_%d.zip", annee, annee, m)))
}

.COLS_MICROCLIMF <- c("obs_time", "temp", "relhum", "pres", "swdown", "difrad",
                      "lwdown", "windspeed", "winddir", "precip")

test_that("cas 1 : la fixture timeseries rend les colonnes et l'ordre de .rsen_forcage_era5", {
  f <- withr::local_tempfile(fileext = ".nc")
  .ts_fixture(f, .ts_heures())
  d <- nemeton:::.rsen_era5ts_lire_maille(f, 2023L, annee_complete = FALSE)
  expect_identical(names(d), .COLS_MICROCLIMF)
  expect_s3_class(d$obs_time, "POSIXct")
  expect_identical(attr(d$obs_time, "tzone"), "UTC")
  expect_equal(nrow(d), 6L)
})

test_that("cas 2 : unités, valeurs calculées à la main", {
  f <- withr::local_tempfile(fileext = ".nc")
  .ts_fixture(f, .ts_heures(3), list(ssrd = 3.6e6, strd = 1.08e6, sp = 90000,
                                     tp = 0.002, t2m = 293.15))
  d <- nemeton:::.rsen_era5ts_lire_maille(f, 2023L, annee_complete = FALSE)
  expect_equal(d$swdown, rep(1000, 3))     # 3.6e6 J/m2 par heure = 1000 W/m2
  expect_equal(d$lwdown, rep(300, 3))      # 1.08e6 / 3600
  expect_equal(d$pres, rep(90, 3))         # Pa -> kPa
  expect_equal(d$precip, rep(2, 3))        # m -> mm
  expect_equal(d$temp, rep(20, 3))         # K -> °C
})

test_that("cas 3 : difrad = (ssrd - fdir)/3600 borné à [0, swdown]", {
  f <- withr::local_tempfile(fileext = ".nc")
  .ts_fixture(f, .ts_heures(3),
              list(ssrd = c(3.6e6, 1.8e6, 3.6e6), fdir = c(1.8e6, 3.6e6, -3.6e6)))
  d <- nemeton:::.rsen_era5ts_lire_maille(f, 2023L, annee_complete = FALSE)
  expect_equal(d$difrad[1], 500)           # (3.6e6 - 1.8e6)/3600
  expect_equal(d$difrad[2], 0)             # fdir > ssrd
  expect_equal(d$difrad[3], d$swdown[3])   # dépasserait swdown : borné
  expect_true(all(d$difrad <= d$swdown))
})

test_that("cas 4 : aucune valeur négative sur swdown, difrad, lwdown, precip", {
  f <- withr::local_tempfile(fileext = ".nc")
  .ts_fixture(f, .ts_heures(3), list(ssrd = c(-50, 0, 1e6), strd = -10, tp = c(-1e-7, 0, 1e-3)))
  d <- nemeton:::.rsen_era5ts_lire_maille(f, 2023L, annee_complete = FALSE)
  for (cn in c("swdown", "difrad", "lwdown", "precip")) expect_true(all(d[[cn]] >= 0), info = cn)
  # Le même bornage sert au chemin classique.
  m <- data.frame(swdown = -1, difrad = -2, lwdown = -3, precip = -4)
  expect_true(all(suppressMessages(nemeton:::.rsen_clamp_flux(
    m, cols = c(nemeton:::.RSEN_NONNEG_COLS, "lwdown"))) == 0))
})

test_that("cas 5 : relhum et vent suivent les formules de mcera5::extract_clim", {
  skip_if_not_installed("mcera5")
  f <- withr::local_tempfile(fileext = ".nc")
  .ts_fixture(f, .ts_heures(2), list(t2m = 288.15, d2m = 283.15, sp = 95000, u10 = 3, v10 = -4))
  d <- nemeton:::.rsen_era5ts_lire_maille(f, 2023L, annee_complete = FALSE)
  ns <- asNamespace("mcera5")
  tc <- 15; pk <- 95
  hs <- get("humfromdew", ns)(10, tc, 95000)
  rh_ref <- min(100, get("converthumidity", ns)(hs, intype = "specific", tc = tc, pk = pk)[["relative"]])
  expect_equal(d$relhum[1], rh_ref, tolerance = 1e-3)   # converthumidity : ~0,003 %HR près
  expect_equal(d$windspeed[1], get("windheight", ns)(sqrt(3^2 + 4^2), 10, 2), tolerance = 1e-9)
  expect_equal(d$winddir[1], (atan2(3, -4) * 180 / pi + 180) %% 360)
  expect_true(all(d$winddir >= 0 & d$winddir < 360))
  # Saturation : td = t -> 100 %, jamais au-delà.
  expect_equal(nemeton:::.rsen_era5ts_relhum(20, 20), 100)
  expect_equal(nemeton:::.rsen_era5ts_relhum(25, 20), 100)
})

test_that("cas 6 : aucun décalage d'horodatage (règle de extract_clim)", {
  f <- withr::local_tempfile(fileext = ".nc")
  h <- .ts_heures(4)
  .ts_fixture(f, h)
  d <- nemeton:::.rsen_era5ts_lire_maille(f, 2023L, annee_complete = FALSE)
  expect_equal(as.numeric(d$obs_time), h)
})

test_that("cas 7 : 4 mailles voisines, poids = inverse de la distance (focal_dist)", {
  m <- nemeton:::.rsen_era5ts_mailles(4.8, 47.3)
  expect_equal(nrow(m), 4L)
  expect_equal(sum(m$w), 1)
  expect_setequal(paste(m$x, m$y), c("4.75 47.25", "4.75 47.5", "5 47.25", "5 47.5"))
  d <- sqrt((4.8 - m$x)^2 + (47.3 - m$y)^2)
  expect_equal(m$w, (1 / d) / sum(1 / d))
  expect_equal(m$w[m$x == 4.75 & m$y == 47.25], max(m$w))   # la plus proche pèse le plus
  # Référence : mcera5:::focal_dist, si installé.
  skip_if_not_installed("mcera5")
  skip_if_not_installed("plyr")
  ref <- get("focal_dist", asNamespace("mcera5"))(4.8, 47.3)
  expect_equal(sort(m$w), sort(ref$inverse_weight))
  # Sur la grille : une seule maille.
  expect_equal(nemeton:::.rsen_era5ts_mailles(4.75, 47.25)$w, 1)

  # Pondération de 4 séries constantes : moyenne pondérée exacte.
  cd <- withr::local_tempdir()
  vals <- c(10, 12, 14, 16)
  tt <- as.numeric(seq(as.POSIXct("2023-01-01", tz = "UTC"), by = "hour", length.out = 8760))
  for (k in 1:4) {
    .ts_fixture(nemeton:::.rsen_era5ts_nom(cd, m$x[k], m$y[k], 2023L), tt,
                list(t2m = 273.15 + vals[k]))
  }
  out <- nemeton:::.rsen_era5ts_forcage(cd, 4.8, 47.3, 2023L)
  expect_equal(out$temp[1], sum(vals * m$w))
  expect_identical(names(out), .COLS_MICROCLIMF)
})

# Accès CDS factice du jeu timeseries : écrit une fixture annuelle au lieu du zip.
.acces_ts_faux <- function(echec = NULL, journal_vu = NULL) {
  appels <- new.env(); appels$req <- list(); appels$journal <- list()
  list(
    appels = appels,
    soumettre = function(req_k, cache_dir) {
      if (!is.null(echec)) stop(echec)
      appels$req[[length(appels$req) + 1L]] <- req_k
      list(req = req_k)
    },
    sonder = function(h) {
      d <- list.files(file.path(dirname(h$cache), "era5_jobs"), full.names = TRUE)
      appels$journal[[length(appels$journal) + 1L]] <- d
      "pret"
    },
    extraire = function(h, req_k, cache_dir) {
      tt <- as.numeric(seq(as.POSIXct("2023-01-01", tz = "UTC"), by = "hour", length.out = 8760))
      .ts_fixture(file.path(cache_dir, sub("\\.zip$", ".nc", req_k$target)), tt)
    },
    liberer = function(h) invisible(NULL),
    url = function(h) "https://cds.example/jobs/abc")
}

test_that("cas 9, 12, 14 : cache par maille, événements, journal des jobs", {
  cd <- withr::local_tempdir()
  acces <- .acces_ts_faux()
  # `soumettre` renvoie le cache_dir pour que sonder retrouve le journal.
  acces$soumettre <- function(req_k, cache_dir) {
    acces$appels$req[[length(acces$appels$req) + 1L]] <- req_k
    list(req = req_k, cache = file.path(cache_dir, "x"))
  }
  ev <- list()
  nemeton:::.rsen_era5_assurer(data.frame(lon = 4.8, lat = 47.3), 2023L, cd,
    emit = function(p) ev[[length(ev) + 1L]] <<- p, source = "timeseries",
    acces_ts = acces, pause = function(...) NULL)
  # 4 mailles, 4 requêtes `timeseries`, une par fichier, nom distinct du classique.
  expect_length(acces$appels$req, 4L)
  expect_true(all(vapply(acces$appels$req, `[[`, "", "dataset_short_name") ==
                    nemeton:::.RSEN_ERA5TS_DATASET))
  fich <- list.files(cd, pattern = "\\.nc$")
  expect_length(fich, 4L)
  expect_true(all(grepl("^era5ts_", fich)))
  expect_false(any(grepl("^era5_", fich)))
  # Événements : mois_i croissant, mois_n constant, dernier mois_i == mois_n.
  mois <- Filter(function(p) identical(p$current, "regen_expo:era5_mois"), ev)
  expect_equal(vapply(mois, `[[`, 1L, "mois_i"), 1:4)
  expect_true(all(vapply(mois, `[[`, 1L, "mois_n") == 4L))
  # Journal : les jobs timeseries ont été écrits (vus pendant le suivi), puis vidé.
  vus <- unlist(acces$appels$journal)
  expect_true(any(grepl("\\.txt$", vus)))
  expect_length(list.files(file.path(cd, "era5_jobs")), 0L)
  # Cache complet : rien n'est redemandé.
  n0 <- length(acces$appels$req)
  nemeton:::.rsen_era5_assurer(data.frame(lon = 4.8, lat = 47.3), 2023L, cd,
    source = "timeseries", acces_ts = acces, pause = function(...) NULL)
  expect_length(acces$appels$req, n0)
  # Fichier tronqué : redemandé (et lui seul).
  f1 <- file.path(cd, fich[1])
  writeBin(readBin(f1, "raw", 200L), f1)
  nemeton:::.rsen_era5_assurer(data.frame(lon = 4.8, lat = 47.3), 2023L, cd,
    source = "timeseries", acces_ts = acces, pause = function(...) NULL)
  expect_length(acces$appels$req, n0 + 1L)
  expect_true(nemeton:::.rsen_era5_nc_complet(f1))
  # Le cache timeseries n'est pas un cache classique, ni l'inverse.
  expect_true(is.na(nemeton:::.rsen_era5_src(cd, 2023L, 4.8, 47.3)))
  expect_false(nemeton:::.rsen_era5_nom_combine(cd, 2023L, 4.8, 47.3) %in%
                 file.path(cd, fich))
})

test_that("cas 10 : timeseries par défaut, classique par option ou argument", {
  withr::local_options(nemeton.era5_source = NULL)
  expect_identical(nemeton:::.rsen_era5_source(), "timeseries")
  expect_identical(nemeton:::.rsen_era5_source("mcera5"), "classique")
  expect_identical(nemeton:::.rsen_era5_source("classique"), "classique")
  withr::local_options(nemeton.era5_source = "classique")
  expect_identical(nemeton:::.rsen_era5_source(), "classique")
  expect_identical(nemeton:::.rsen_era5_source("timeseries"), "timeseries")
  expect_error(nemeton:::.rsen_era5_source("autre"))
})

test_that("cas 11 : timeseries en échec -> ancien chemin, avec message", {
  cd <- withr::local_tempdir()
  echec <- structure(class = c("rsen_era5_echec", "error", "condition"),
                     list(message = "CDS job failed: boom", call = NULL))
  acces <- .acces_ts_faux(echec = echec)
  appele <- NULL
  ncs <- NULL
  expect_warning(
    nemeton:::.rsen_era5_assurer(data.frame(lon = 6, lat = 48), 2019L, cd,
      source = "timeseries", acces_ts = acces, max_tries = 1L,
      pause = function(...) NULL,
      construire = function(lon, lat, annee) .req_mois(annee, 2),
      requete = function(reqs, cache_dir) {
        appele <<- TRUE
        for (r in reqs) .nc_ok(file.path(cache_dir, sub("\\.zip$", ".nc", r$target)))
      },
      combiner = function(fichiers, cible) .nc_ok(cible)),
    "falling back to the classic")
  expect_true(appele)
  expect_true(file.exists(nemeton:::.rsen_era5_nom_combine(cd, 2019L, 6, 48)))
})

test_that("cas 11 bis : un refus pour limite garde le comportement d'attente puis nouvel essai", {
  cd <- withr::local_tempdir()
  limite <- structure(class = c("rsen_era5_limite", "error", "condition"),
                      list(message = "queued requests", call = NULL))
  acces <- .acces_ts_faux()
  base <- acces$soumettre; n <- 0L
  acces$soumettre <- function(req_k, cache_dir) {
    n <<- n + 1L
    if (n == 1L) stop(limite)
    base(req_k, cache_dir)
  }
  acces$sonder <- function(h) "pret"
  expect_no_warning(
    nemeton:::.rsen_era5_assurer(data.frame(lon = 4.75, lat = 47.25), 2023L, cd,
      source = "timeseries", acces_ts = acces, pause = function(...) NULL,
      attente_limite = 0))
  expect_true(nemeton:::.rsen_era5ts_en_cache(cd, 4.75, 47.25, 2023L))
})

test_that("cas 12 : .rsen_forcage_era5 rend le data.frame microclimf via timeseries", {
  cd <- withr::local_tempdir()
  acces <- .acces_ts_faux()
  acces$soumettre <- function(req_k, cache_dir) list(req = req_k, cache = cache_dir)
  d <- nemeton:::.rsen_forcage_era5(4.8, 47.3, 2023L, cd, source = "timeseries",
                                    acces_ts = acces, pause = function(...) NULL)
  expect_identical(names(d), .COLS_MICROCLIMF)
  expect_equal(nrow(d), 8760L)
  # Jours entiers de 24 h, comme l'exige microclimf::checkinputs().
  expect_equal(as.integer(table(as.Date(d$obs_time))[1]), 24L)
  expect_true(all(d$difrad <= d$swdown))
})
