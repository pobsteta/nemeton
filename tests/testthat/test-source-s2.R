# Source Sentinel-2 des methodes de suivi sanitaire (mission 096). Aucun reseau.

make_con <- function() structure(list(), class = c("FakeConnection", "DBIConnection"))
make_aoi <- function() {
  sf::st_sf(geometry = sf::st_as_sfc(sf::st_bbox(
    c(xmin = 1000000, ymin = 6800000, xmax = 1001000, ymax = 6801000), crs = 2154)))
}
make_scenes <- function(src = "pc") {
  data.frame(scene_id = c("S2A_X_1", "S2A_X_2"),
             obs_date = as.Date("2020-01-01") + 1:2, cloud_pct = 5,
             source = src, stringsAsFactors = FALSE)
}

test_that("le defaut est propre a chaque methode", {
  expect_equal(s2_source_resoudre("reconfort")$source_s2, "theia")
  for (m in c("fast", "fordead", "icd")) {
    expect_equal(s2_source_resoudre(m)$source_s2, "sen2cor")
    expect_true(is.na(s2_source_resoudre(m)$mention))
  }
})

test_that("un choix global s'applique aux quatre methodes et marque la hors-calage", {
  r <- s2_source_resoudre("fast", "theia")
  expect_equal(r$source_s2, "theia")
  expect_equal(r$calee_sur, "sen2cor")
  expect_false(is.na(r$mention))
  # plus de champ `validee` : on compare `calee_sur` et la source effective
  expect_false("validee" %in% names(r))
  expect_false(is.na(s2_source_resoudre("reconfort", "sen2cor")$mention))
  expect_true(is.na(s2_source_resoudre("reconfort", "theia")$mention))
  expect_true(is.na(s2_source_resoudre("icd", "sen2cor")$mention))
})

test_that("la mention est ecrite en anglais, en ASCII", {
  m <- s2_source_resoudre("fordead", "theia")$mention
  expect_false(is.na(m))
  expect_true(all(utf8ToInt(m) < 128L))
  expect_match(m, "calibrated on sen2cor but ran on theia")
})

test_that("une source inconnue est refusee (classe dediee)", {
  expect_error(s2_source_resoudre("fast", "peps"), class = "nemeton_s2_source_invalide")
  expect_error(s2_source_resoudre("fast", c("theia", "sen2cor")),
               class = "nemeton_s2_source_invalide")
})

test_that("l'avertissement hors-calage a sa classe, et se tait sur la source de calage", {
  expect_warning(.s2_avertir_non_calee("fordead", "theia"),
                 class = "nemeton_s2_source_non_calee")
  expect_no_warning(.s2_avertir_non_calee("fordead", "sen2cor"))
  expect_no_warning(.s2_avertir_non_calee("reconfort", "theia"))
})

test_that("l'avertissement avec cle n'est donne qu'une fois par session et par cle", {
  rm(list = ls(.s2_avertis), envir = .s2_avertis)
  expect_warning(.s2_avertir_non_calee("fast", "theia", cle = "/c1"),
                 class = "nemeton_s2_source_non_calee")
  expect_no_warning(.s2_avertir_non_calee("fast", "theia", cle = "/c1"))
  expect_warning(.s2_avertir_non_calee("fast", "theia", cle = "/c2"),
                 class = "nemeton_s2_source_non_calee")
  # sans cle : toujours
  expect_warning(.s2_avertir_non_calee("fast", "theia"),
                 class = "nemeton_s2_source_non_calee")
  expect_warning(.s2_avertir_non_calee("fast", "theia"),
                 class = "nemeton_s2_source_non_calee")
})

test_that("un cache par source, le cache Sen2Cor ne bouge pas", {
  expect_identical(.s2_cache_dir_source("/p/cache/sentinel2", "sen2cor"), "/p/cache/sentinel2")
  th <- .s2_cache_dir_source("/p/cache/sentinel2/", "theia")
  expect_identical(th, "/p/cache/sentinel2_theia")
  expect_identical(.s2_cache_dir_source(th, "theia"), th)   # idempotent
})

test_that("choix de source : THEIA joignable, indisponible, refuse, sans cles", {
  ok <- function() list(etat = "ok", hote = "h", cause = NA_character_)
  ko <- function() list(etat = "indisponible", hote = "h", cause = "HTTP 503")
  no <- function() list(etat = "refuse", hote = "h", cause = "HTTP 401")
  cles <- function() TRUE
  expect_equal(.s2_choisir_source("reconfort", NULL, ok, cles)$effective, "theia")
  expect_warning(
    s <- .s2_choisir_source("reconfort", NULL, ko, cles),
    class = "nemeton_s2_repli_sen2cor")
  expect_equal(s$effective, "sen2cor"); expect_true(s$repli)
  expect_equal(s$demandee, "theia")
  expect_error(.s2_choisir_source("fast", "theia", no, cles),
               class = "nemeton_s2_theia_refuse")
  expect_error(.s2_choisir_source("fast", "theia", ok, function() FALSE),
               class = "nemeton_s2_theia_sans_cles")
  # Sen2Cor : ni sonde ni cles
  boom <- function() stop("la sonde ne doit pas etre appelee")
  expect_equal(.s2_choisir_source("fast", NULL, boom, boom)$effective, "sen2cor")
})

test_that("panne THEIA en cours de serie : la serie ENTIERE est refaite sur Sen2Cor", {
  appels <- character(0)
  f <- function(src) {
    appels <<- c(appels, src)
    if (src == "theia") {
      .s2_signaler_panne_theia(simpleError("curl: Connection timed out"))
    }
    paste("serie", src)
  }
  expect_warning(r <- .s2_avec_repli("fast", "theia", f),
                 class = "nemeton_s2_repli_sen2cor")
  expect_equal(appels, c("theia", "sen2cor"))
  expect_equal(r$valeur, "serie sen2cor")
  # la passe de repli sait qu'elle est un repli (pour des metadonnees vraies)
  infos <- list()
  g <- function(src, info) {
    infos[[length(infos) + 1L]] <<- info
    if (src == "theia") .s2_signaler_panne_theia(simpleError("HTTP error 503"))
    src
  }
  suppressWarnings(.s2_avec_repli("icd", "theia", g))
  expect_false(infos[[1]]$repli)
  expect_true(infos[[2]]$repli)
  expect_match(infos[[2]]$cause, "503")
  expect_equal(r$source, "sen2cor"); expect_true(r$repli)
  # sans panne : une seule passe, jamais de melange
  appels <- character(0)
  r2 <- .s2_avec_repli("fast", "sen2cor", f)
  expect_equal(appels, "sen2cor"); expect_false(r2$repli)
})

test_that("classification des erreurs de lecture THEIA : pannes, refus, autres (>= 15 messages)", {
  cl <- function(m) .s2_classer_erreur_theia(simpleError(m))
  # pannes
  expect_equal(cl("HTTP response code on https://api.stac.teledetection.fr/a/b.tif: 503"), "panne")
  expect_equal(cl("cannot open: HTTP response code: 502"), "panne")
  expect_equal(cl("CPLE_AppDefined: HTTP response code on /vsicurl/https://x/y.tif: 504"), "panne")
  expect_equal(cl("HTTP error 503"), "panne")
  expect_equal(cl("Request failed [500]; status code 500"), "panne")
  expect_equal(cl("HTTP/1.1 429 Too Many Requests"), "panne")
  expect_equal(cl("server answered with status 408"), "panne")
  expect_equal(cl("502 Bad Gateway"), "panne")
  expect_equal(cl("Gateway Time-out"), "panne")
  expect_equal(cl("Service Unavailable"), "panne")
  expect_equal(cl("Network is unreachable"), "panne")
  expect_equal(cl("SSL connect error"), "panne")
  expect_equal(cl("Failed to connect to host port 443"), "panne")
  expect_equal(cl("curl: Connection timed out after 10001 milliseconds"), "panne")
  expect_equal(cl("Timeout was reached"), "panne")
  expect_equal(cl("Operation timed out"), "panne")
  expect_equal(cl("Could not resolve host: api.stac.teledetection.fr"), "panne")
  # refus : erreur de cles, jamais de repli
  expect_equal(cl("HTTP response code on https://x/y.tif: 403"), "refuse")
  expect_equal(cl("HTTP error 401"), "refuse")
  expect_equal(cl("403 Forbidden"), "refuse")
  # ni panne ni refus : donnee, bug, phrases anodines
  expect_equal(cl("HTTP 5030"), "autre")
  expect_equal(cl("HTTP error 4030"), "autre")
  expect_equal(cl("scene 5032 of 6000 has no usable band"), "autre")
  expect_equal(cl("Increase the timeout parameter to wait longer"), "autre")
  expect_equal(cl("the timeout option must be positive"), "autre")
  expect_equal(cl("Scene has no asset for band B12"), "autre")
  expect_equal(cl("classless object passed"), "autre")   # contient « ssl », pas « SSL »
  expect_true(.s2_erreur_panne_theia(simpleError("HTTP error 503")))
  expect_false(.s2_erreur_panne_theia(simpleError("HTTP error 403")))
})

test_that("401/403 en cours de serie : erreur nemeton_s2_theia_refuse, pas de repli", {
  e403 <- simpleError("HTTP response code on https://x/y.tif: 403")
  expect_error(.s2_traiter_erreur_serie(e403, "theia"), class = "nemeton_s2_theia_refuse")
  expect_error(.s2_traiter_erreur_serie(simpleError("HTTP error 503"), "theia"),
               class = "nemeton_s2_theia_panne")
  expect_null(.s2_traiter_erreur_serie(simpleError("no asset for B12"), "theia"))
  # ailleurs que sur THEIA : rien
  expect_null(.s2_traiter_erreur_serie(e403, "sen2cor"))
  expect_null(.s2_traiter_erreur_serie(e403, NULL))
  # et `.s2_avec_repli` ne rattrape pas le refus
  f <- function(src) .s2_traiter_erreur_serie(e403, src)
  expect_error(.s2_avec_repli("fast", "theia", f), class = "nemeton_s2_theia_refuse")
})

test_that("le masque MAJA CLM devient une SCL lisible par l'ICD", {
  skip_if_not_installed("terra")
  r <- terra::rast(nrows = 1, ncols = 4, vals = c(0, 1, 32, NA))
  expect_equal(as.numeric(terra::values(.s2_clm_vers_scl(r))), c(4, 9, 9, 0))
  expect_true(all(c(0L, 9L) %in% .ICD_SCL_MASQUE))
})

test_that("une scene MAJA expose son masque CLM_R2 comme SCL", {
  ft <- list(id = "SENTINEL2A_20240101-X", assets = list(
    B04 = list(href = "https://x/SENTINEL2A_FRE_B4.tif"),
    CLM_R2 = list(href = "https://x/SENTINEL2A_CLM_R2.tif")))
  # Option posee par la recherche THEIA du suivi sanitaire seulement.
  withr::with_options(list(nemeton.s2_muscate_clm = TRUE), {
    out <- .muscate_remap_feature(ft)
    expect_true(nzchar(out$assets$SCL$href))
    expect_match(out$assets$SCL$href, "CLM_R2")
  })
  # Sans l'option (repli MUSCATE historique de stac_search_s2()) : SCL absent comme avant.
  expect_false(nzchar(.muscate_remap_feature(ft)$assets$SCL$href))
})

test_that("ingestion brute sur THEIA : panne -> classe dediee ; sur Sen2Cor : scene sautee", {
  testthat::skip_if_not_installed("sf")
  testthat::local_mocked_bindings(
    .get_zone_aoi = function(con, zone_id) make_aoi(),
    stac_search_s2 = function(...) make_scenes("muscate"),
    .get_s2_band_raster = function(...) stop("curl: Connection timed out"),
    .package = "nemeton")
  d <- tempfile("c-"); dir.create(d)
  expect_error(
    ingest_s2_raw_bands_to_cache(make_con(), 1L, "B04", "2020-01-01", "2020-12-31",
                                 d, source_effective = "theia"),
    class = "nemeton_s2_theia_panne")
  # Sen2Cor : la scene est sautee (un avertissement), la serie continue
  expect_warning(
    r <- ingest_s2_raw_bands_to_cache(make_con(), 1L, "B04", "2020-01-01", "2020-12-31",
                                      d, source_effective = "sen2cor"))
  expect_equal(r$n_scenes_skipped, 2L)
})

test_that("ingestion brute sur THEIA : 401/403 en cours de serie -> nemeton_s2_theia_refuse", {
  testthat::skip_if_not_installed("sf")
  testthat::local_mocked_bindings(
    .get_zone_aoi = function(con, zone_id) make_aoi(),
    stac_search_s2 = function(...) make_scenes("muscate"),
    .get_s2_band_raster = function(...) stop("HTTP response code on https://x/y.tif: 403"),
    .package = "nemeton")
  d <- tempfile("c-"); dir.create(d)
  expect_error(
    ingest_s2_raw_bands_to_cache(make_con(), 1L, "B04", "2020-01-01", "2020-12-31",
                                 d, source_effective = "theia"),
    class = "nemeton_s2_theia_refuse")
})

test_that("ingestion brute sans source : l'appel historique de stac_search_s2(), sans argument `source`", {
  testthat::skip_if_not_installed("sf")
  vu <- new.env()
  testthat::local_mocked_bindings(
    .get_zone_aoi = function(con, zone_id) make_aoi(),
    stac_search_s2 = function(zone, start, end, max_cloud = 20, source = NULL, ...) {
      vu$source <- source; vu$appels <- (vu$appels %||% 0L) + 1L
      make_scenes()
    },
    .get_s2_band_raster = function(...) NULL,
    .package = "nemeton")
  d <- tempfile("c-"); dir.create(d)
  r <- ingest_s2_raw_bands_to_cache(make_con(), 1L, "B04", "2020-01-01", "2020-12-31", d)
  expect_null(vu$source)                 # sources par defaut : cdse, pc, muscate
  expect_false("source_s2" %in% names(r))
  expect_named(r, c("cancelled", "scenes_df", "n_scenes", "n_bands_fetched",
                    "n_bands_cached", "n_scenes_skipped"))
  # `sen2cor` choisi : CDSE et PC seulement ; `theia` : MUSCATE seul
  r2 <- ingest_s2_raw_bands_to_cache(make_con(), 1L, "B04", "2020-01-01", "2020-12-31",
                                     d, source_effective = "sen2cor")
  expect_equal(vu$source, c("cdse", "pc")); expect_equal(r2$source_s2, "sen2cor")
  ingest_s2_raw_bands_to_cache(make_con(), 1L, "B04", "2020-01-01", "2020-12-31", d,
                               source_effective = "theia")
  expect_equal(vu$source, "muscate")
})

test_that("recherche THEIA qui echoue : panne (repli de la serie), pas 'aucune scene' ; autres appelants inchanges", {
  testthat::skip_if_not_installed("sf")
  testthat::skip_if_not_installed("httr2")
  bb <- sf::st_as_sfc(sf::st_bbox(c(xmin = 5, ymin = 47, xmax = 5.1, ymax = 47.1), crs = 4326))
  # Un autre appelant de stac_search_s2() : l'echec reste un avertissement + table vide.
  testthat::local_mocked_bindings(
    stac_search_s2_theia_muscate = function(...) stop("HTTP error 503"),
    .package = "nemeton")
  expect_warning(vide <- stac_search_s2(bb, "2020-01-01", "2020-02-01", source = "muscate"))
  expect_equal(nrow(vide), 0L)
  # Source THEIA du suivi sanitaire : la meme panne declenche le repli.
  expect_error(.s2_chercher_scenes("theia", bb, "2020-01-01", "2020-02-01"),
               class = "nemeton_s2_theia_panne")
  # 403 : erreur de cles, pas de repli
  testthat::local_mocked_bindings(
    stac_search_s2_theia_muscate = function(...) stop("HTTP error 403"),
    .package = "nemeton")
  expect_error(.s2_chercher_scenes("theia", bb, "2020-01-01", "2020-02-01"),
               class = "nemeton_s2_theia_refuse")
  # Recherche reussie mais vide : une vraie absence de scene, pas une panne.
  testthat::local_mocked_bindings(
    stac_search_s2_theia_muscate = function(...) nemeton:::.empty_scene_tibble(),
    .package = "nemeton")
  expect_equal(nrow(.s2_chercher_scenes("theia", bb, "2020-01-01", "2020-02-01")), 0L)
})

test_that("serie THEIA dont la RECHERCHE echoue : la serie entiere est refaite sur Sen2Cor", {
  testthat::skip_if_not_installed("sf")
  testthat::skip_if_not_installed("httr2")
  lus <- character(0)
  testthat::local_mocked_bindings(
    .get_zone_aoi = function(con, zone_id) make_aoi(),
    stac_search_s2_theia_muscate = function(...) stop("HTTP response code on https://x: 502"),
    stac_search_s2_cdse = function(...) make_scenes("cdse"),
    .get_s2_band_raster = function(scene, band, buf, cache_dir, emit) {
      lus <<- c(lus, cache_dir); NULL
    },
    .package = "nemeton")
  base <- tempfile("s2-"); dir.create(base)
  expect_warning(
    r <- .s2_avec_repli("fordead", "theia", function(src) {
      ingest_s2_raw_bands_to_cache(make_con(), 1L, "B04", "2020-01-01", "2020-12-31",
                                   .s2_cache_dir_source(base, src),
                                   source_effective = src)
    }), class = "nemeton_s2_repli_sen2cor")
  expect_equal(r$source, "sen2cor")
  expect_true(r$repli)
  expect_equal(r$valeur$n_scenes, 2L)           # les scenes Sen2Cor, pas « No scene found »
  expect_true(all(lus == base))
})

test_that("serie complete sur THEIA en panne : une seule source dans le cache final", {
  testthat::skip_if_not_installed("sf")
  recherches <- list(); lus <- character(0)
  testthat::local_mocked_bindings(
    .get_zone_aoi = function(con, zone_id) make_aoi(),
    stac_search_s2 = function(zone, start, end, max_cloud = 20, source = NULL, ...) {
      recherches[[length(recherches) + 1L]] <<- source
      make_scenes(if (identical(source, "muscate")) "muscate" else "pc")
    },
    .get_s2_band_raster = function(scene, band, buf, cache_dir, emit) {
      lus <<- c(lus, cache_dir)
      if (identical(scene$source[1], "muscate")) stop("HTTP error 503")
      NULL
    },
    .package = "nemeton")
  base <- tempfile("s2-"); dir.create(base)
  expect_warning(
    r <- .s2_avec_repli("fordead", "theia", function(src) {
      ingest_s2_raw_bands_to_cache(make_con(), 1L, "B04", "2020-01-01", "2020-12-31",
                                   .s2_cache_dir_source(base, src),
                                   source_effective = src)
    }), class = "nemeton_s2_repli_sen2cor")
  expect_equal(r$source, "sen2cor")
  expect_equal(recherches[[1]], "muscate")
  expect_equal(recherches[[2]], c("cdse", "pc"))
  expect_equal(r$valeur$source_s2, "sen2cor")
  # le dernier passage n'a touche que le cache Sen2Cor
  expect_true(all(tail(lus, 2) == base))
})

test_that("FAST sans source_s2 : meme resume qu'avant, aucune sonde, cache inchange", {
  testthat::skip_if_not_installed("sf")
  vu <- list()
  boom <- function(...) stop("ne doit pas etre appelee")
  testthat::local_mocked_bindings(
    .assert_db_pkgs = function() invisible(TRUE),
    .fetch_plots_sf = function(con, zone_id) sf::st_sf(id = 1L, radius_m = 15,
      geometry = sf::st_sfc(sf::st_point(c(7.75, 48.55)), crs = 4326)),
    .get_zone_aoi = function(con, zone_id) make_aoi(),
    stac_search_s2 = function(zone, start, end, max_cloud = 20, source = NULL, ...) {
      vu$source <<- source; vu$appels <<- (vu$appels %||% 0L) + 1L; make_scenes()
    },
    .get_s2_band_raster = function(scene, band, buf, cache_dir, emit) {
      vu$cache <<- cache_dir; NULL
    },
    .reconfort_stac_sonde = boom,
    .package = "nemeton")
  d <- tempfile("fast-"); dir.create(d)
  r <- suppressMessages(ingest_sentinel2_timeseries(make_con(), 1L, "2020-01-01", "2020-12-31",
                                                   cache_dir = d))
  expect_equal(vu$cache, d)
  expect_null(vu$source)      # appel historique : sources par defaut, MUSCATE compris
  expect_equal(r$n_scenes, 2L)
  expect_false("source_s2" %in% names(r))
  expect_false("repli_sen2cor" %in% names(r))
  expect_equal(names(r), names(.ingest_summary(2L, 0L, 1L, "NDVI", "success")))
  # demande explicite : source inscrite
  r2 <- suppressMessages(ingest_sentinel2_timeseries(make_con(), 1L, "2020-01-01",
                                                    "2020-12-31", cache_dir = d,
                                                    source_s2 = "sen2cor"))
  expect_equal(r2$source_s2, "sen2cor"); expect_false(r2$repli_sen2cor)
  expect_equal(vu$cache, d)
  expect_equal(vu$source, c("cdse", "pc"))
})

test_that("RECONFORT : source_s2 contradictoire avec acquisition = erreur de classe dediee", {
  expect_error(
    run_reconfort_dieback(con = make_con(), zone_id = 1L, cache_dir = tempdir(),
                          acquisition = "fenetre", source_s2 = "sen2cor"),
    class = "nemeton_s2_source_incoherente")
  expect_error(
    run_reconfort_dieback(con = make_con(), zone_id = 1L, cache_dir = tempdir(),
                          acquisition = "sen2cor", source_s2 = "theia"),
    class = "nemeton_s2_source_incoherente")
})

test_that("metadonnees de source : source effective, calage, repli", {
  m <- .s2_meta_source("fast", "theia", demandee = "theia")
  expect_equal(m$source_s2, "theia"); expect_equal(m$calee_sur, "sen2cor")
  expect_false("validee" %in% names(m)); expect_false(is.null(m$mention_source))
  m2 <- .s2_meta_source("reconfort", "sen2cor", demandee = "theia", repli = TRUE,
                        cause = "503")
  expect_true(m2$repli_sen2cor); expect_equal(m2$cause_repli, "503")
  m3 <- .s2_meta_source("fast", "sen2cor")
  expect_false("validee" %in% names(m3)); expect_null(m3$mention_source)
  expect_identical(m3$source_s2_demandee, "sen2cor")
})

test_that("les tags du COG FAST portent la source", {
  skip_if_not_installed("terra")
  skip_if_terra_write_broken()
  r <- terra::rast(nrows = 2, ncols = 2, vals = 1:4)
  p <- file.path(tempfile("fz-"), "x.tif"); dir.create(dirname(p))
  .fast_raster_cache_write(r, p, source_s2 = "theia")
  mt <- terra::metags(terra::rast(p))
  v <- if (is.data.frame(mt)) mt$value[mt$name == "source_s2"] else mt["source_s2"]
  expect_equal(unname(v), "theia")
})

test_that("sans source_s2, le COG FAST n'a pas de tag source", {
  skip_if_not_installed("terra")
  skip_if_terra_write_broken()
  r <- terra::rast(nrows = 2, ncols = 2, vals = 1:4)
  p <- file.path(tempfile("fz-"), "x.tif"); dir.create(dirname(p))
  .fast_raster_cache_write(r, p)
  mt <- terra::metags(terra::rast(p))
  noms <- if (is.data.frame(mt)) mt$name else names(mt)
  expect_false("source_s2" %in% tolower(noms))
})
