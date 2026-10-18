# Spec 063 — contexte climatique estival sur un cercle autour du projet.
# Rasters synthétiques, aucun réseau.

# Projet ponctuel près de Dijon (EPSG:2154).
.cc_aoi <- function() {
  sf::st_sf(id = 1, geometry = sf::st_sfc(
    sf::st_buffer(sf::st_point(c(853000, 6694000)), 500), crs = 2154))
}

# Mensuel synthétique EPSG:4326 sur l'emprise France, valeurs = f(an, mois).
.cc_mensuel <- function(annees, f, res = 0.5) {
  g <- terra::rast(xmin = -5.5, xmax = 10, ymin = 41, ymax = 51.5,
                   resolution = res, crs = "EPSG:4326")
  grille <- expand.grid(mo = 1:12, an = annees)
  r <- terra::rast(lapply(seq_len(nrow(grille)), function(i) {
    x <- g; terra::values(x) <- f(grille$an[i], grille$mo[i]); x
  }))
  names(r) <- sprintf("%d-%02d", grille$an, grille$mo)
  r
}

.cc_series <- function(annees, ftx, frr, res = 0.1) {
  g <- terra::rast(xmin = 4.5, xmax = 5.5, ymin = 47, ymax = 47.6,
                   resolution = res, crs = "EPSG:4326")
  mk <- function(f) {
    r <- terra::rast(lapply(annees, function(a) {
      x <- g; terra::values(x) <- f(a, seq_len(terra::ncell(g))); x
    }))
    names(r) <- as.character(annees)
    r
  }
  list(tx = mk(ftx), rr = mk(frr), cercle = NULL,
       meta = list(status = "ok", source = "eobs", resolution_native = "0.1deg",
                   mois = 5:9, crs = "4326", attribution = "test"))
}

test_that("été annuel : seules les années aux mois complets, moyenne et cumul", {
  m <- .cc_mensuel(2000:2001, function(an, mo) an - 2000 + mo)
  m <- m[[-which(names(m) == "2001-07")]]
  tx <- nemeton:::.climat_ete_annuel(m, 5:9, "mean")
  rr <- nemeton:::.climat_ete_annuel(m, 5:9, "sum")
  expect_equal(names(tx), "2000")
  expect_equal(unname(terra::values(tx)[1, 1]), mean(5:9))
  expect_equal(unname(terra::values(rr)[1, 1]), sum(5:9))
})

test_that("un mois NA rend la maille NA pour l'été (na.rm = FALSE)", {
  m <- .cc_mensuel(2000, function(an, mo) mo)
  v <- terra::values(m[["2000-06"]]); v[1] <- NA; terra::values(m[["2000-06"]]) <- v
  e <- nemeton:::.climat_ete_annuel(m, 5:9, "mean")
  expect_true(is.na(terra::values(e)[1, 1]))
  expect_false(is.na(terra::values(e)[2, 1]))
})

test_that("tendance = pente MCO × durée (variation totale) ; règle des 80 %", {
  s <- .cc_series(1990:2019, function(a, i) 0.05 * a + 0 * i, function(a, i) -2 * a + 0 * i)
  dt <- nemeton:::.climat_tendance(s$tx)
  dp <- nemeton:::.climat_tendance(s$rr, 2000, 2010)
  expect_equal(unname(terra::values(dt)[1, 1]), 0.05 * 29, tolerance = 1e-8)
  expect_equal(unname(terra::values(dp)[1, 1]), -2 * 10, tolerance = 1e-8)
  Y <- matrix(c(1:10, c(1, rep(NA, 9))), nrow = 2, byrow = TRUE)
  p <- nemeton:::.climat_pente_mat(Y, 1:10)
  expect_equal(p[1], 1)
  expect_true(is.na(p[2]))
})

test_that("palette IF49 10 × 10 : coins de la Figure 1", {
  col <- nemeton:::.climat_palette("if49_10x10", 10L)
  expect_length(col, 100)
  expect_equal(col[(10 - 1) * 10 + 1], "#E52521")   # chaud & sec
  expect_equal(col[1], "#F3E600")                   # frais & sec
  expect_equal(col[10], "#2B4C9B")                  # frais & humide
  expect_equal(col[100], "#C688BA")                 # chaud & humide
  expect_error(nemeton:::.climat_palette("if49_10x10", 9L))
  co <- nemeton:::.climat_palette("coins", 9L)
  expect_length(co, 81)
  expect_equal(co[c(1, 9, 73, 81)], c("#F2E01E", "#2B3F9C", "#E3171C", "#C893C6"))
})

test_that("bivariée if49 : bornes fixes, période 2006-2020, classe attendue", {
  # Tmax +4 °C / 14 ans (borne haute) et précip -270 mm (borne basse) -> chaud & sec.
  s <- .cc_series(1990:2024, function(a, i) 4 / 14 * a + 0 * i,
                  function(a, i) -270 / 14 * a + 0 * i)
  b <- climat_tendance_bivariee(s, periode = "if49")
  expect_equal(b$meta$status, "ok")
  expect_equal(b$meta$periode, c(2006L, 2020L))
  expect_equal(b$meta$bornes$mode, "if49")
  expect_equal(b$meta$bornes$tmax, c(-0.7, 4))
  expect_equal(unique(terra::values(b$raster)[, 1]), 91L)
  expect_equal(b$meta$palette$colors[91], "#E52521")
  expect_equal(b$meta$palette$ncol, 10L)
  expect_equal(b$meta$palette$zero$tmax, 0.7 / 4.7)
  expect_equal(names(b$tendances), c("tendance_tmax", "tendance_precip"))
  expect_equal(unname(terra::values(b$tendances)[1, 1]), 4, tolerance = 1e-8)
})

test_that("bivariée : bornes emprise, explicites et repli france sans cache", {
  s <- .cc_series(1990:2020, function(a, i) 0.02 * a + 0.001 * i * (a - 1990),
                  function(a, i) -1 * a + 0 * i)
  withr::local_envvar(NEMETON_CACHE_DIR = withr::local_tempdir())
  b <- climat_tendance_bivariee(s, periode = "complete")
  expect_equal(b$meta$bornes$mode, "emprise")
  expect_equal(b$meta$bornes$reason, "france_eobs_cache_missing")
  expect_lte(b$meta$bornes$tmax[1], 0)
  e <- climat_tendance_bivariee(s, bornes = list(tmax = c(0, 1), precip = c(-100, 0)))
  expect_equal(e$meta$bornes$mode, "explicite")
  expect_true(all(terra::values(e$raster)[, 1] %in% 1:100))
  expect_equal(climat_tendance_bivariee(s, periode = c(2018, 2020))$meta$status,
               "donnees_insuffisantes")
})

test_that("bivariée : bornes france lues dans le cache E-OBS machine", {
  dir <- withr::local_tempdir()
  m <- .cc_mensuel(1990:2020, function(an, mo) 0.03 * an + mo)
  terra::writeRaster(m, file.path(dir, "eobs_tx_mensuel_france_v33.0e.tif"))
  # Contour fourni hors réseau (toute l'emprise).
  fr <- sf::st_sf(geometry = sf::st_as_sfc(sf::st_bbox(c(xmin = -5.5, ymin = 41, xmax = 10,
                                                        ymax = 51.5), crs = 4326)))
  sf::st_write(fr, file.path(dir, "france_metropole_ser.gpkg"), quiet = TRUE)
  rr <- .cc_mensuel(1990:2020, function(an, mo) -0.5 * an)
  terra::writeRaster(rr, file.path(dir, "eobs_rr_mensuel_france_v33.0e.tif"))
  s <- .cc_series(1990:2020, function(a, i) 0.1 * a + 0 * i, function(a, i) 0 * a + 0 * i)
  b <- climat_tendance_bivariee(s, eobs_cache_dir = dir)
  expect_equal(b$meta$bornes$mode, "france")
  expect_equal(b$meta$bornes$reference, "eobs_france_metropole")
  expect_equal(b$meta$bornes$tmax, c(0, 0.03 * 30), tolerance = 1e-6)
  expect_equal(b$meta$bornes$precip, c(-2.5 * 30, 0), tolerance = 1e-6)
  expect_true(file.exists(file.path(dir, "bornes_france_1990_2020_m5-6-7-8-9_v33.0e.json")))
})

test_that("bivariée : cache disque tif + tendances + meta.json", {
  s <- .cc_series(2000:2020, function(a, i) 0.1 * a + 0 * i, function(a, i) -a + 0 * i)
  p <- file.path(withr::local_tempdir(), "biv.tif")
  b <- climat_tendance_bivariee(s, periode = "if49", cache_path = p)
  expect_true(all(file.exists(unlist(b$meta$fichiers))))
  m <- jsonlite::read_json(b$meta$fichiers$meta)
  expect_equal(m$palette$ncol, 10)
  expect_equal(terra::values(terra::rast(p))[, 1], terra::values(b$raster)[, 1])
})

test_that("bivariée propage le statut d'une série en échec", {
  b <- climat_tendance_bivariee(list(meta = list(status = "hors_couverture",
                                                 reason = "safran_france_only")))
  expect_equal(b$meta$status, "hors_couverture")
  expect_null(b$raster)
})

test_that("nuages : anomalie à la référence, moyennes et limites communes", {
  s <- .cc_series(1981:2020, function(a, i) (a - 1995.5) * 0.1 + 0 * i,
                  function(a, i) 100 + 0 * i)
  n <- climat_nuages_annuels(s, mode = "anomalie")
  expect_equal(n$meta$status, "ok")
  expect_equal(sort(unique(n$points$annee)), 1981:2020)
  expect_equal(n$moyennes$y[n$moyennes$annee == 2020], (2020 - 1995.5) * 0.1, tolerance = 1e-8)
  expect_equal(unique(n$points$x), 0)
  expect_lte(n$limites$x[1], 0); expect_gte(n$limites$x[2], 0)
  expect_equal(climat_nuages_annuels(s, reference = 1950:1960)$meta$status,
               "donnees_insuffisantes")
})

test_that("nuages : tendance cumulée à partir de recul_min ans, échantillonnage", {
  s <- .cc_series(1981:2000, function(a, i) 0.2 * a + 0 * i, function(a, i) 0 * a + i)
  n <- climat_nuages_annuels(s, mode = "tendance_cumulee", recul_min = 10, n_points = 5)
  expect_equal(sort(unique(n$points$annee)), 1990:2000)
  expect_equal(n$moyennes$y[n$moyennes$annee == 2000], 0.2 * 19, tolerance = 1e-8)
  expect_true(all(table(n$points$annee) == 5))
  n2 <- climat_nuages_annuels(s, mode = "tendance_cumulee", n_points = 5)
  expect_equal(n$points, n2$points)
})

test_that("série E-OBS depuis le cache machine : cercle, mailles natives, cache projet", {
  eobs <- withr::local_tempdir(); proj <- withr::local_tempdir()
  tx <- .cc_mensuel(2000:2004, function(an, mo) an - 2000 + mo, res = 0.1)
  rr <- .cc_mensuel(2000:2004, function(an, mo) 10, res = 0.1)
  terra::writeRaster(tx, file.path(eobs, "eobs_tx_mensuel_france_v33.0e.tif"))
  terra::writeRaster(rr, file.path(eobs, "eobs_rr_mensuel_france_v33.0e.tif"))
  etapes <- character(0)
  s <- climat_ete_series(.cc_aoi(), "eobs", rayon_km = 10, cache_dir = proj,
                         eobs_cache_dir = eobs,
                         progress_callback = function(p) etapes <<- c(etapes, p$current))
  expect_equal(s$meta$status, "ok")
  expect_equal(s$meta$annees, 2000:2004)
  expect_equal(terra::res(s$tx), c(0.1, 0.1))
  expect_equal(unname(terra::values(s$rr, mat = TRUE)[which(!is.na(terra::values(s$rr)[, 1]))[1], 1]), 50)
  # Rayon 10 km : quelques mailles entières (touches = TRUE).
  nval <- sum(!is.na(terra::values(s$tx)[, 1]))
  expect_gt(nval, 2); expect_lt(nval, 20)
  expect_true("climat:complete" %in% etapes)
  expect_true(all(file.exists(unlist(s$meta$fichiers))))
  s2 <- climat_ete_series(.cc_aoi(), "eobs", rayon_km = 10, cache_dir = proj,
                          eobs_cache_dir = eobs,
                          progress_callback = function(p) etapes <<- c(etapes, p$current))
  expect_equal(utils::tail(etapes, 1), "climat:cache_hit")
  expect_equal(terra::values(s2$tx), terra::values(s$tx))
  expect_s3_class(s$cercle, "sf")
})

test_that("série E-OBS sans réseau ni cache : statut indisponible, pas d'erreur", {
  local_mocked_bindings(.eobs_knmi_fetch = function(...) stop("offline"),
                        .eobs_cds_fetch = function(...) stop("no CDS"))
  s <- suppressWarnings(climat_ete_series(.cc_aoi(), "eobs",
                                          eobs_cache_dir = withr::local_tempdir()))
  expect_equal(s$meta$status, "indisponible")
  expect_match(s$meta$message, "no CDS")
})

test_that("mensualisation E-OBS France depuis un quotidien daté", {
  g <- terra::rast(xmin = -5.5, xmax = 10, ymin = 41, ymax = 51.5, resolution = 1,
                   crs = "EPSG:4326")
  d <- seq(as.Date("2001-01-01"), as.Date("2002-12-31"), by = "day")
  r <- terra::rast(g, nlyrs = length(d))
  terra::values(r) <- matrix(rep(as.integer(format(d, "%m")), each = terra::ncell(g)),
                             terra::ncell(g))
  terra::time(r) <- d
  dest <- file.path(withr::local_tempdir(), "m.tif")
  m <- nemeton:::.eobs_mensuel_france(r, "rr", "sum", dest, function(p) NULL)
  expect_equal(terra::nlyr(m), 24)
  expect_equal(names(m)[2], "2001-02")
  expect_equal(unname(terra::values(m[["2001-02"]])[1, 1]), 2 * 28)
})

test_that("SAFRAN : hors couverture hors métropole", {
  aoi <- sf::st_sf(geometry = sf::st_sfc(sf::st_point(c(-3.7, 40.4)), crs = 4326))
  s <- climat_ete_series(aoi, "safran")
  expect_equal(s$meta$status, "hors_couverture")
  expect_null(s$tx)
})

test_that("SAFRAN : grille reconstruite, été incomplet écarté (API mockée)", {
  local_mocked_bindings(.safran_mois = function(an, mois, bbox) {
    xs <- seq(845000, 861000, by = 8000); ys <- seq(6686000, 6702000, by = 8000)
    j <- seq(as.Date(sprintf("%d-%02d-01", an, mois)), by = "day",
             length.out = nemeton:::.eobs_jours_attendus(an, mois))
    d <- expand.grid(x = xs, y = ys, time = as.character(j), stringsAsFactors = FALSE)
    d$TSUP_H_Q <- 20 + (an - 2000) * 0.1
    d$PRELIQ_Q <- 1; d$PRENEI_Q <- 0
    # 2003 : une maille perd un jour -> écartée cette année-là.
    if (an == 2003 && mois == 7) d <- d[-1, ]
    d
  })
  s <- climat_ete_series(.cc_aoi(), "safran", rayon_km = 10, annees = 2000:2005,
                         cache_dir = withr::local_tempdir())
  expect_equal(s$meta$status, "ok")
  expect_equal(s$meta$crs, "2154")
  expect_equal(terra::res(s$tx), c(8000, 8000))
  v <- terra::values(s$tx, mat = TRUE)
  ok <- which(!is.na(v[, "2000"]))
  expect_equal(unname(v[ok[1], "2005"]), 20.5)
  expect_equal(sum(is.na(v[ok, "2003"])), 1)
  expect_equal(unname(terra::values(s$rr, mat = TRUE)[ok[1], "2000"]),
               nemeton:::.eobs_jours_attendus(2000, 5:9))
})

test_that("CHELSA : lecture distante mockée, conversions d'unités", {
  local_mocked_bindings(.chelsa_ouvrir = function(url) {
    if (!grepl("unil", url)) return(NULL)
    g <- terra::rast(xmin = 4, xmax = 6, ymin = 46.5, ymax = 48, resolution = 1 / 120,
                     crs = "EPSG:4326")
    an <- as.integer(sub(".*_(\\d{4})_V\\.2\\.1\\.tif$", "\\1", url))
    terra::values(g) <- if (grepl("tasmax", url)) 2931.5 + (an - 1979) else 300
    g
  })
  s <- climat_ete_series(.cc_aoi(), "chelsa", rayon_km = 5, annees = 1979:1983,
                         cache_dir = withr::local_tempdir())
  expect_equal(s$meta$status, "ok")
  v <- terra::values(s$tx, mat = TRUE)
  ok <- which(!is.na(v[, 1]))
  expect_equal(unname(v[ok[1], "1980"]), 2932.5 * 0.1 - 273.15, tolerance = 1e-4)
  expect_equal(unname(terra::values(s$rr, mat = TRUE)[ok[1], 1]), 1500)
  expect_equal(terra::res(s$tx), c(1 / 120, 1 / 120), tolerance = 1e-9)
})
