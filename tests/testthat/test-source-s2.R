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
    expect_true(s2_source_resoudre(m)$validee)
  }
})

test_that("un choix global s'applique aux quatre methodes et marque la hors-calage", {
  r <- s2_source_resoudre("fast", "theia")
  expect_equal(r$source_s2, "theia")
  expect_false(r$validee)
  expect_equal(r$calee_sur, "sen2cor")
  expect_false(is.na(r$mention))
  expect_false(s2_source_resoudre("reconfort", "sen2cor")$validee)
  expect_true(s2_source_resoudre("reconfort", "theia")$validee)
  expect_true(is.na(s2_source_resoudre("icd", "sen2cor")$mention))
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

test_that("un cache par source, le cache Sen2Cor ne bouge pas", {
  expect_identical(.s2_cache_dir_source("/p/cache/sentinel2", "sen2cor"), "/p/cache/sentinel2")
  th <- .s2_cache_dir_source("/p/cache/sentinel2/", "theia")
  expect_identical(th, "/p/cache/sentinel2_theia")
  expect_identical(.s2_cache_dir_source(th, "theia"), th)   # idempotent
  expect_identical(.s2_source_du_cache(th), "theia")
  expect_identical(.s2_source_du_cache("/p/cache/sentinel2"), "sen2cor")
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
  expect_equal(r$source, "sen2cor"); expect_true(r$repli)
  # sans panne : une seule passe, jamais de melange
  appels <- character(0)
  r2 <- .s2_avec_repli("fast", "sen2cor", f)
  expect_equal(appels, "sen2cor"); expect_false(r2$repli)
})

test_that("une panne se reconnait, une erreur de donnees non", {
  expect_true(.s2_erreur_panne_theia(simpleError("Timeout was reached")))
  expect_true(.s2_erreur_panne_theia(simpleError("HTTP error 503")))
  expect_false(.s2_erreur_panne_theia(simpleError("Scene has no asset for band B12")))
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
  out <- .muscate_remap_feature(ft)
  expect_true(nzchar(out$assets$SCL$href))
  expect_match(out$assets$SCL$href, "CLM_R2")
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
  expect_warning(
    r <- ingest_s2_raw_bands_to_cache(make_con(), 1L, "B04", "2020-01-01", "2020-12-31",
                                      d, source_effective = "sen2cor"),
    "skipped")
  expect_equal(r$n_scenes_skipped, 2L)
})

test_that("serie complete sur THEIA en panne : une seule source dans le cache final", {
  testthat::skip_if_not_installed("sf")
  recherches <- list(); lus <- character(0)
  testthat::local_mocked_bindings(
    .get_zone_aoi = function(con, zone_id) make_aoi(),
    stac_search_s2 = function(zone, start, end, max_cloud = 20, source, ...) {
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
    stac_search_s2 = function(zone, start, end, max_cloud = 20, source, ...) {
      vu$source <<- source; make_scenes()
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
  expect_equal(r$n_scenes, 2L)
  expect_false("source_s2" %in% names(r))
  expect_equal(names(r), names(.ingest_summary(2L, 0L, 1L, "NDVI", "success")))
  # demande explicite : source inscrite
  r2 <- suppressMessages(ingest_sentinel2_timeseries(make_con(), 1L, "2020-01-01",
                                                    "2020-12-31", cache_dir = d,
                                                    source_s2 = "sen2cor"))
  expect_equal(r2$source_s2, "sen2cor"); expect_false(r2$repli_sen2cor)
  expect_equal(vu$cache, d)
})

test_that("ICD sur THEIA : avertit, inscrit la source, resultats dans un dossier THEIA", {
  testthat::skip_if_not_installed("sf")
  d <- tempfile("icd-"); dir.create(d)
  res <- NULL
  expect_warning(
    res <- run_icd_decoloration(con = NULL, zone_id = 1L, cache_dir = d,
                                result_dir = d, ingest = FALSE,
                                source_s2 = "theia"),
    class = "nemeton_s2_source_non_calee")
  expect_equal(res$source_s2, "theia")
  # sans source_s2 : aucun champ nouveau, aucun avertissement
  res0 <- run_icd_decoloration(con = NULL, zone_id = 1L, cache_dir = d,
                               result_dir = d, ingest = FALSE)
  expect_false("source_s2" %in% names(res0))
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
  expect_false(m$validee); expect_false(is.null(m$mention_source))
  m2 <- .s2_meta_source("reconfort", "sen2cor", demandee = "theia", repli = TRUE,
                        cause = "503")
  expect_true(m2$repli_sen2cor); expect_equal(m2$cause_repli, "503")
  m3 <- .s2_meta_source("fast", "sen2cor")
  expect_true(m3$validee); expect_null(m3$mention_source)
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
