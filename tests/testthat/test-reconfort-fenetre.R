# Mission 071 : acquisition RECONFORT par lecture fenetree. Aucun reseau :
# les "scenes" sont de petits GeoTIFF fabriques en UTM 31N ; l'URL signee est
# remplacee par le chemin local.

.fen_nom <- "SENTINEL2A_20230614-105805-472_L2A_T31TCN_C_V4-0"

# Fabrique une scene "archive" (dossier extrait) : FRE (10 m ou 20 m),
# ATB, masques, XML ; plus une copie "COG" compressee/tuilee des memes valeurs,
# referencee par un item STAC fabrique. Renvoie list(archive, feature, aoi).
.fen_decor <- function(env = parent.frame(), sans = character(0)) {
  root <- withr::local_tempdir(.local_envir = env)
  arc  <- file.path(root, "archive", .fen_nom)
  cog  <- file.path(root, "cog")
  dir.create(file.path(arc, "MASKS"), recursive = TRUE)
  dir.create(cog)
  mk <- function(res, tipo, seed) {
    n <- as.integer(2000 / res)
    r <- terra::rast(nrows = n, ncols = n, xmin = 500000, xmax = 502000,
                     ymin = 5400000, ymax = 5402000, crs = "EPSG:32631")
    set.seed(seed)
    terra::values(r) <- if (tipo == "int") sample(0:9000, n * n, TRUE) else
      sample(0:3, n * n, TRUE)
    r
  }
  cles <- c(.RECONFORT_FENETRE_BANDES, .RECONFORT_FENETRE_MASQUES,
            .RECONFORT_FENETRE_OPTIONNELS)
  assets <- list(); k <- 0L
  for (cle in cles) {
    k <- k + 1L
    r10 <- grepl("_R1$", cle) || cle %in% c("B02", "B03", "B04", "B08")
    r <- mk(if (r10) 10 else 20, if (grepl("^B", cle)) "int" else "msk", k)
    suf <- if (grepl("^B", cle)) paste0("FRE_B", sub("^B0?", "", cle)) else cle
    nom <- sprintf("%s_%s.tif", .fen_nom, suf)
    dt <- if (grepl("^B", cle)) "INT2S" else "INT1U"
    rel <- if (cle %in% .RECONFORT_FENETRE_MASQUES) file.path("MASKS", nom) else nom
    terra::writeRaster(r, file.path(arc, rel), datatype = dt)
    terra::writeRaster(r, file.path(cog, nom), datatype = dt,
                       gdal = c("COMPRESS=DEFLATE", "TILED=YES"))
    if (!cle %in% sans) assets[[cle]] <- list(href = file.path(cog, nom))
  }
  xml <- sprintf("%s_MTD_ALL.xml", .fen_nom)
  writeLines("<meta/>", file.path(arc, xml))
  writeLines("<meta/>", file.path(cog, xml))
  assets$MD <- list(href = file.path(cog, xml))
  # Verite terrain de l'AOI : un carre de 400 m autour de (501000, 5401000).
  pt <- sf::st_sfc(sf::st_point(c(501000, 5401000)), crs = 32631)
  aoi <- sf::st_buffer(sf::st_transform(pt, 2154), 200)
  list(root = root, archive = arc,
       feature = list(id = .fen_nom, assets = assets,
                      properties = list(datetime = "2023-06-14T10:58:05.472000Z",
                                        `grid:code` = "MGRS-31TCN")),
       aoi = aoi)
}

test_that("fenetre ecrit les memes fichiers que la voie archive (cas 1)", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  d <- .fen_decor()
  win <- .reconfort_aoi_window(d$aoi, 2154, 0)
  # Voie archive : recadrage de l'archive extraite.
  ref <- file.path(d$root, "ref")
  .reconfort_crop_scene_to_aoi(d$archive, file.path(ref, .fen_nom), win, 2154)
  # Voie fenetre.
  fen <- file.path(d$root, "fen")
  sc <- .reconfort_fenetre_ecrire_scene(d$feature, fen, win, 2154)
  expect_identical(sc, .fen_nom)
  cmp <- .reconfort_comparer_acquisitions(ref, fen)
  expect_length(cmp$resume$seulement_archive, 0L)
  expect_length(cmp$resume$seulement_fenetre, 0L)
  expect_gt(cmp$resume$n_communs, 20L)
  expect_true(cmp$resume$conforme)
  expect_equal(cmp$resume$ecart_max, 0)
  expect_equal(cmp$resume$n_meme_type, cmp$resume$n_communs)
  expect_true(all(cmp$fichiers$meme_type[grepl("tif$", cmp$fichiers$fichier)]))
  expect_true(all(cmp$fichiers$meme_grille[cmp$fichiers$archive & cmp$fichiers$fenetre &
                                             grepl("tif$", cmp$fichiers$fichier)]))
  # Arborescence : masques sous MASKS/, bandes a la racine.
  expect_true(file.exists(file.path(fen, .fen_nom, "MASKS",
                                    paste0(.fen_nom, "_CLM_R1.tif"))))
  expect_true(file.exists(file.path(fen, .fen_nom,
                                    paste0(.fen_nom, "_FRE_B8A.tif"))))
  # Grille : la fenetre est bien plus petite que la source (2000 m).
  r <- terra::rast(file.path(fen, .fen_nom, paste0(.fen_nom, "_FRE_B4.tif")))
  expect_lt(terra::ncol(r), 100)
  expect_identical(terra::res(r), c(10, 10))
})

test_that("la comparaison detecte une difference de valeur et un fichier en trop", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  d <- .fen_decor()
  win <- .reconfort_aoi_window(d$aoi, 2154, 0)
  a <- file.path(d$root, "a"); b <- file.path(d$root, "b")
  .reconfort_crop_scene_to_aoi(d$archive, file.path(a, .fen_nom), win, 2154)
  .reconfort_crop_scene_to_aoi(d$archive, file.path(b, .fen_nom), win, 2154)
  f <- file.path(b, .fen_nom, paste0(.fen_nom, "_FRE_B4.tif"))
  r <- terra::rast(f); r <- r + 3
  terra::writeRaster(r, f, overwrite = TRUE, datatype = "INT2S")
  file.create(file.path(b, .fen_nom, "extra.tif"))
  cmp <- .reconfort_comparer_acquisitions(a, b)
  expect_false(cmp$resume$conforme)
  expect_equal(cmp$resume$ecart_max, 3)
  expect_match(cmp$resume$seulement_fenetre, "extra.tif")
})

test_that("un type de donnees different rend la comparaison non conforme", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  d <- .fen_decor()
  win <- .reconfort_aoi_window(d$aoi, 2154, 0)
  a <- file.path(d$root, "a"); b <- file.path(d$root, "b")
  .reconfort_crop_scene_to_aoi(d$archive, file.path(a, .fen_nom), win, 2154)
  .reconfort_crop_scene_to_aoi(d$archive, file.path(b, .fen_nom), win, 2154)
  f <- file.path(b, .fen_nom, paste0(.fen_nom, "_FRE_B4.tif"))
  tmp <- file.path(d$root, "flt.tif")
  terra::writeRaster(terra::rast(f), tmp, datatype = "FLT4S")  # memes valeurs
  file.copy(tmp, f, overwrite = TRUE)
  cmp <- .reconfort_comparer_acquisitions(a, b)
  expect_equal(cmp$resume$ecart_max, 0)
  expect_false(cmp$resume$conforme)
})

test_that("un asset absent est nomme et rien n'est ecrit (cas 2)", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  d <- .fen_decor(sans = c("B06", "MG2_R2"))
  win <- .reconfort_aoi_window(d$aoi, 2154, 0)
  fen <- file.path(d$root, "fen")
  expect_error(.reconfort_fenetre_ecrire_scene(d$feature, fen, win, 2154),
               "B06.*MG2_R2|MG2_R2.*B06", class = "reconfort_fenetre_asset_absent")
  expect_length(list.files(fen, recursive = TRUE), 0L)
})

test_that("lecture qui echoue puis reussit : reprise ; echec durable : erreur (cas 3)", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  d <- .fen_decor()
  win <- .reconfort_aoi_window(d$aoi, 2154, 0)
  src <- d$feature$assets$B04$href
  dst <- file.path(d$root, "out", "b.tif")
  n <- 0L; dormi <- numeric(0)
  fn <- function(essai) {
    n <<- n + 1L
    if (essai < 3L) "/vsicurl/https://exemple.invalid/x.tif?X-Amz-Signature=secret" else src
  }
  suppressWarnings(.reconfort_fenetre_lire(fn, dst, win, 2154, "B04", max_tries = 3L,
                          sleep = function(s) dormi <<- c(dormi, s)))
  expect_equal(n, 3L)
  expect_equal(dormi, c(2, 4))
  expect_true(file.exists(dst))
  # Echec durable : message nomme la bande, sans la signature.
  e <- tryCatch(suppressWarnings(.reconfort_fenetre_lire(
    function(i) "/vsicurl/https://exemple.invalid/x.tif?X-Amz-Signature=secret",
    file.path(d$root, "out", "c.tif"), win, 2154, "B05", max_tries = 2L,
    sleep = function(s) NULL)), error = function(e) e)
  expect_s3_class(e, "reconfort_fenetre_lecture")
  expect_match(conditionMessage(e), "B05")
  expect_false(grepl("secret", conditionMessage(e)))
})

test_that("la tuile : scene en echec sautee et dite, bonne scene promue, idempotence", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  d <- .fen_decor()
  mauvaise <- d$feature; mauvaise$id <- "BAD"; mauvaise$assets$B05 <- NULL
  appels <- 0L
  testthat::local_mocked_bindings(
    .reconfort_fenetre_lister = function(...) {
      appels <<- appels + 1L
      list(mauvaise, d$feature)
    })
  s2 <- file.path(d$root, "s2"); out <- file.path(s2, "extracted", "T31TCN")
  dir.create(out, recursive = TRUE)
  ev <- character(0)
  run <- function() .reconfort_ingest_tile_fenetre(
    "T31TCN", "31TCN", d$aoi, "2023-01-01", "2023-12-31", s2, out, 2154, 0,
    quiet = TRUE, progress_callback = function(p) ev <<- c(ev, p$step %||% ""))
  run()
  expect_true(dir.exists(file.path(out, .fen_nom)))
  expect_length(list.dirs(out, recursive = FALSE), 1L)
  expect_true("failed" %in% ev); expect_true("done" %in% ev)
  expect_length(list.files(file.path(s2, "ingested", "T31TCN")), 1L)
  expect_false(dir.exists(file.path(s2, "scratch", "T31TCN")))
  ev <- character(0); run()
  expect_true("cached" %in% ev)
  # Aucune scene lue : erreur.
  out2 <- file.path(d$root, "s2b", "extracted", "T31TCN"); dir.create(out2, recursive = TRUE)
  testthat::local_mocked_bindings(.reconfort_fenetre_lister = function(...) list(mauvaise))
  expect_error(.reconfort_ingest_tile_fenetre(
    "T31TCN", "31TCN", d$aoi, "2023-01-01", "2023-12-31",
    file.path(d$root, "s2b"), out2, 2154, 0, quiet = TRUE), "no scene read")
})

test_that("reconfort_ingest_s2(acquisition = 'fenetre') n'appelle ni conda ni GEODES", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  d <- .fen_decor()
  testthat::local_mocked_bindings(
    .reconfort_fenetre_verifier_acces = function() invisible(TRUE),
    .reconfort_fenetre_lister = function(...) list(d$feature),
    .ensure_reconfort_python = function(...) stop("conda appele"),
    .reconfort_geodes_config = function(...) stop("GEODES appele"))
  res <- reconfort_ingest_s2(aoi = d$aoi, tiles = "T31TCN",
                             date_from = "2023-01-01", date_to = "2023-12-31",
                             s2_root = file.path(d$root, "s2"), buffer_m = 0,
                             quiet = TRUE, acquisition = "fenetre")
  expect_identical(res$acquisition, "fenetre")
  expect_true(dir.exists(file.path(res$extracted, .fen_nom)))
  expect_error(reconfort_ingest_s2(tiles = "T31TCN", date_from = "2023-01-01",
                                   date_to = "2023-12-31", s2_root = d$root,
                                   quiet = TRUE, acquisition = "fenetre"),
               "needs an")
})

test_that("sans cles THEIA, 'fenetre' explicite est refuse", {
  withr::local_envvar(TLD_ACCESS_KEY = "", TLD_SECRET_KEY = "")
  expect_error(.reconfort_fenetre_verifier_acces(), class = "reconfort_fenetre_sans_cles")
  expect_false(.reconfort_fenetre_cles_presentes())
})

test_that("recherche STAC : ne garde que la tuile demandee", {
  testthat::local_mocked_bindings(
    .assert_httr2 = function() invisible(TRUE),
    .theia_stac_api = function(...) "https://stac.invalid",
    .muscate_collection = function(...) "c",
    .stac_search_paginate = function(initial_url, initial_body, ...) {
      expect_equal(initial_body$query[["grid:code"]]$eq, "MGRS-31TCN")
      list(list(id = "a", properties = list(`grid:code` = "MGRS-31TCN")),
           list(id = "b", properties = list(`grid:code` = "MGRS-31TDN")))
    })
  f <- .reconfort_fenetre_lister("31TCN", "2023-01-01", "2023-12-31")
  expect_length(f, 1L); expect_equal(f[[1]]$id, "a")
})

test_that("tests vivants THEIA : le catalogue repond (saute sans reseau)", {
  skip_on_cran()
  skip_if(!nzchar(Sys.getenv("NEMETON_TEST_THEIA_LIVE")), "live THEIA test not requested")
  f <- tryCatch(.reconfort_fenetre_lister("31TCN", "2023-06-10", "2023-06-20"),
                error = function(e) { .tss_sauter_si_reseau(e); stop(e) })
  expect_gt(length(f), 0L)
  expect_silent(.reconfort_fenetre_plan(f[[1]]))
})

# --- Comparaison 4b : carte IOTA2 contre carte du spike (cas 5) -------------

.carte_classes <- function(v, n = 4L) {
  r <- terra::rast(nrows = n, ncols = n, xmin = 900000, xmax = 900000 + 10 * n,
                   ymin = 6500000, ymax = 6500000 + 10 * n, crs = "EPSG:2154")
  terra::values(r) <- v
  r
}

test_that("accord entre cartes : matrice, accord, kappa et surfaces justes (cas 5)", {
  skip_if_not_installed("terra")
  # 16 pixels. IOTA2 : 8 x classe 1, 4 x 2, 4 x 3. Spike identique sauf 4 pixels.
  iota <- c(rep(1, 8), rep(2, 4), rep(3, 4))
  spk  <- iota
  spk[1:2] <- 2   # 2 pixels 1 -> 2
  spk[9]   <- 1   # 1 pixel 2 -> 1
  spk[13]  <- 2   # 1 pixel 3 -> 2
  a <- .reconfort_accord_cartes(.carte_classes(iota), .carte_classes(spk))
  expect_equal(a$n, 16)
  expect_equal(unname(a$confusion["1", ]), c(6, 2, 0))
  expect_equal(unname(a$confusion["2", ]), c(1, 3, 0))
  expect_equal(unname(a$confusion["3", ]), c(0, 1, 3))
  expect_equal(a$accord, 12 / 16)
  # kappa a la main : po = 0.75 ; marges IOTA2 (8,4,4), spike (7,6,3)
  pe <- (8 * 7 + 4 * 6 + 4 * 3) / 256
  expect_equal(a$kappa, (0.75 - pe) / (1 - pe))
  # 100 m2 par pixel = 0.01 ha
  expect_equal(a$par_classe$surface_iota2_ha, c(8, 4, 4) * 0.01)
  expect_equal(a$par_classe$surface_spike_ha, c(7, 6, 3) * 0.01)
  expect_equal(a$par_classe$rappel, c(6 / 8, 3 / 4, 3 / 4))
  expect_equal(a$par_classe$precision, c(6 / 7, 3 / 6, 3 / 3))
  expect_equal(a$surface_comparee_ha, 0.16)
})

test_that("le script comparer_cartes.R tourne sur deux petites cartes et ecrit ses sorties", {
  skip_if_not_installed("terra")
  script <- testthat::test_path("..", "..", "data-raw", "comparaison_reconfort",
                                "comparer_cartes.R")
  skip_if_not(file.exists(script), "data-raw absent (paquet installe)")
  env <- new.env()
  sys.source(script, envir = env)
  d <- withr::local_tempdir()
  f1 <- file.path(d, "iota2.tif"); f2 <- file.path(d, "spike.tif")
  terra::writeRaster(.carte_classes(rep(1:3, length.out = 16)), f1)
  terra::writeRaster(.carte_classes(rep(c(1, 1, 3), length.out = 16)), f2)
  out <- file.path(d, "sortie")
  res <- utils::capture.output(
    r <- env$comparer_cartes(f1, f2, out, duree_iota2 = 600, duree_spike = 30))
  expect_true(all(file.exists(file.path(out, c("confusion.csv", "par_classe.csv", "resume.csv")))))
  expect_equal(r$resume$duree_iota2_s, 600)
  expect_equal(r$n, 16)
  expect_equal(r$accord, mean(rep(1:3, length.out = 16) == rep(c(1, 1, 3), length.out = 16)))
})
