# Missions 056 et 059 : segmentation des houppiers en parallèle (PSOCK, jamais de fork),
# rasters ouverts une fois dans la boucle des placettes, progression par étape,
# .qgz sans recompression des GeoTIFF. Données synthétiques minuscules, sans
# réseau. Le parallèle est sauté sur CRAN ; 2 workers au plus.

ir_pl <- function(ids = c("P1", "P2"), x = c(925000, 925200), y = 6700000) {
  sf::st_sf(plot_id = ids, wgt = 10, stratum = "s1",
            geometry = sf::st_sfc(lapply(seq_along(ids), function(i) sf::st_point(c(x[i], y))),
                                  crs = 2154))
}
ir_mnt <- function(ext = terra::ext(924950, 925250, 6699950, 6700050)) {
  r <- terra::rast(ext, resolution = 1, crs = "EPSG:2154")
  xy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
  terra::values(r) <- 300 + 0.1 * (xy[, 2] - 6699950)
  r
}
ir_mnh <- function(ext = terra::ext(924950, 925250, 6699950, 6700050)) {
  r <- terra::rast(ext, resolution = 0.5, crs = "EPSG:2154")
  xy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
  terra::values(r) <- 25 * exp(-((xy[, 1] %% 8 - 4)^2 + (xy[, 2] %% 8 - 4)^2) / 6)
  r
}
# Emprise de 60 m centrée sur le coin de 4 dalles de 1 km : 2 x 2 dalles.
ir_emprise_2x2 <- function() {
  sf::st_sfc(sf::st_polygon(list(rbind(
    c(924970, 6699970), c(925030, 6699970), c(925030, 6700030),
    c(924970, 6700030), c(924970, 6699970)))), crs = 2154)
}
# Rassemble les appels du rappel de progression.
ir_collecteur <- function() {
  env <- new.env()
  env$appels <- list()
  list(f = function(p) { env$appels[[length(env$appels) + 1L]] <- p; invisible(NULL) },
       appels = function() env$appels)
}
ir_df <- function(appels) {
  data.frame(etape = vapply(appels, `[[`, "", "etape"),
             i = vapply(appels, `[[`, 0L, "i"),
             n = vapply(appels, `[[`, 0L, "n"),
             secondes = vapply(appels, `[[`, 0, "secondes"))
}

# ---- Cas 1 : houppiers en parallèle == séquentiel ----------------------

test_that("houppiers : 2 workers identiques au séquentiel, MNH de 2 x 2 dalles sur disque (cas 1)", {
  skip_on_cran()
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    terra::writeRaster(ir_mnh(terra::ext(924940, 925060, 6699940, 6700060)), "mnh.tif")
    e <- ir_emprise_2x2()
    expect_equal(nrow(nemeton:::.iv_dalles_km(e)), 4L)
    pl <- ir_pl("P1", x = 925000)
    seq1 <- nemeton:::.iv_houppiers_emprise("mnh.tif", e, pl, 25, n_workers = 1L)
    col <- ir_collecteur()
    emit <- nemeton:::.iv_emetteur(col$f)
    par2 <- nemeton:::.iv_houppiers_emprise("mnh.tif", e, pl, 25, n_workers = 2L, emit = emit)
    expect_gt(nrow(seq1), 0L)
    # les quatre dalles ont chacune des houppiers (sommets des 4 côtés du coin)
    dalle <- paste(floor(seq1$x_sommet / 1000), floor(seq1$y_sommet / 1000))
    expect_equal(length(unique(dalle)), 4L)
    # même lignes, même ordre, mêmes houppier_id, mêmes géométries
    expect_equal(par2, seq1)
    expect_identical(par2$houppier_id, seq1$houppier_id)
    expect_identical(sf::st_as_text(sf::st_geometry(par2)), sf::st_as_text(sf::st_geometry(seq1)))
    # la voie parallèle a bien servi : compteur par lot de 2 dalles (2 puis 4),
    # le séquentiel compterait 1, 2, 3, 4
    d <- ir_df(col$appels())
    expect_identical(d$i[d$etape == "houppiers"], c(0L, 2L, 4L))
  })
})

test_that("houppiers : SpatRaster adossé à un fichier -> parallèle, identique", {
  skip_on_cran()
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    terra::writeRaster(ir_mnh(terra::ext(924940, 925060, 6699940, 6700060)), "mnh.tif")
    e <- ir_emprise_2x2()
    pl <- ir_pl("P1", x = 925000)
    seq1 <- nemeton:::.iv_houppiers_emprise(terra::rast("mnh.tif"), e, pl, 25, n_workers = 1L)
    col <- ir_collecteur()
    par2 <- nemeton:::.iv_houppiers_emprise(terra::rast("mnh.tif"), e, pl, 25, n_workers = 2L,
                                            emit = nemeton:::.iv_emetteur(col$f))
    expect_equal(par2, seq1)
    d <- ir_df(col$appels())
    expect_identical(d$i[d$etape == "houppiers"], c(0L, 2L, 4L))
  })
})

# ---- Cas 2 : MNH en mémoire -> séquentiel ------------------------------

test_that("houppiers : MNH en mémoire avec n_workers = 2 -> séquentiel, sans erreur (cas 2)", {
  skip_if_not_installed("lidR")
  e <- ir_emprise_2x2()
  pl <- ir_pl("P1", x = 925000)
  mnh <- ir_mnh(terra::ext(924940, 925060, 6699940, 6700060))
  expect_true(terra::inMemory(mnh))
  seq1 <- nemeton:::.iv_houppiers_emprise(mnh, e, pl, 25, n_workers = 1L)
  col <- ir_collecteur()
  # un cluster ne doit pas être créé : on le ferait échouer
  testthat::local_mocked_bindings(.iv_houppiers_paralleles = function(...) stop("cluster interdit"))
  res <- expect_no_error(nemeton:::.iv_houppiers_emprise(mnh, e, pl, 25, n_workers = 2L,
                                                         emit = nemeton:::.iv_emetteur(col$f)))
  expect_equal(res, seq1)
  d <- ir_df(col$appels())
  expect_identical(d$i[d$etape == "houppiers"], 0:4)   # une dalle à la fois
})

test_that("houppiers : voie parallèle en échec -> avertissement et repli séquentiel", {
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    terra::writeRaster(ir_mnh(terra::ext(924940, 925060, 6699940, 6700060)), "mnh.tif")
    e <- ir_emprise_2x2()
    pl <- ir_pl("P1", x = 925000)
    seq1 <- nemeton:::.iv_houppiers_emprise("mnh.tif", e, pl, 25, n_workers = 1L)
    testthat::local_mocked_bindings(.iv_houppiers_paralleles = function(...) stop("pas de cluster"))
    expect_warning(res <- nemeton:::.iv_houppiers_emprise("mnh.tif", e, pl, 25, n_workers = 2L),
                   "running sequentially")
    expect_equal(res, seq1)
  })
})

test_that("n_workers invalide ou progress_callback non fonction -> erreur claire", {
  pl <- ir_pl()
  expect_error(creer_projet_inventaire_video(pl, output_dir = tempfile(), n_workers = 0),
               "n_workers")
  expect_error(creer_projet_inventaire_video(pl, output_dir = tempfile(), n_workers = NA),
               "n_workers")
  expect_error(creer_projet_inventaire_video(pl, output_dir = tempfile(), progress_callback = "x"),
               "progress_callback")
})

# ---- Cas 3 : rappel de progression -------------------------------------

ir_creer <- function(sortie, ..., pl = ir_pl(), dem = ir_mnt(), chm = ir_mnh()) {
  suppressWarnings(creer_projet_inventaire_video(
    pl, dem = dem, chm = chm, output_dir = sortie, ...))
}

test_that("progress_callback : étapes dans l'ordre, secondes >= 0, placettes finit à n (cas 3)", {
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    terra::writeRaster(ir_mnh(terra::ext(924950, 925250, 6699950, 6700050)) / 25, "cvat_src.tif")
    col <- ir_collecteur()
    ir_creer("sortie", cvat_path = "cvat_src.tif", n_workers = 1L, progress_callback = col$f)
    appels <- col$appels()
    expect_true(all(vapply(appels, function(p) identical(names(p), c("etape", "i", "n", "secondes")),
                           logical(1))))
    d <- ir_df(appels)
    expect_true(all(is.finite(d$secondes)) && all(d$secondes >= 0))
    # ordre des étapes (première apparition) : contrat avec nemetonshiny
    expect_identical(unique(d$etape),
                     c("sources", "placettes", "dalles_mnt", "houppiers", "cvat", "geopackage", "qgz"))
    # étapes contiguës, jamais entrelacées
    expect_identical(rle(d$etape)$values, unique(d$etape))
    pl <- d[d$etape == "placettes", ]
    expect_identical(pl$i, 0:2)
    expect_true(all(pl$n == 2L))
    expect_identical(tail(pl$i, 1L), tail(pl$n, 1L))
    # chaque étape finit à i == n
    fin <- vapply(split(d, factor(d$etape, unique(d$etape))), function(x) tail(x$i, 1L) == tail(x$n, 1L),
                  logical(1))
    expect_true(all(fin))
    # les secondes ne décroissent pas à l'intérieur d'une étape
    expect_true(all(vapply(split(d$secondes, factor(d$etape, unique(d$etape))),
                           function(s) !is.unsorted(s), logical(1))))
  })
})

test_that("progress_callback : sans cvat_path pas d'étape cvat ; sans LiDAR pas d'étape raster", {
  skip_if_not_installed("RSQLite")
  withr::with_tempdir({
    col <- ir_collecteur()
    creer_projet_inventaire_video(ir_pl(), avec_lidar = FALSE, output_dir = "sortie",
                                  progress_callback = col$f)
    expect_identical(unique(ir_df(col$appels())$etape), c("sources", "geopackage", "qgz"))
  })
})

test_that("progress_callback qui lève une erreur : le projet est créé quand même (cas 3)", {
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    n <- 0L
    qgz <- ir_creer("sortie", n_workers = 1L,
                    progress_callback = function(p) { n <<- n + 1L; stop("boum") })
    expect_true(file.exists(qgz))
    expect_gt(n, 5L)
    expect_true(file.exists(file.path("sortie", "inventaire_video", "inventaire_video.gpkg")))
  })
})

test_that("projet complet : n_workers = 2 sur MNH fichier == n_workers = 1 (houppiers du GeoPackage)", {
  skip_on_cran()
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    terra::writeRaster(ir_mnh(), "mnh.tif")
    lire <- function(qgz, rep) {
      utils::unzip(qgz, exdir = rep)
      sf::st_read(file.path(rep, "inventaire_video.gpkg"), layer = "houppiers", quiet = TRUE)
    }
    h1 <- lire(ir_creer("s1", chm = "mnh.tif", n_workers = 1L), "x1")
    h2 <- lire(ir_creer("s2", chm = "mnh.tif", n_workers = 2L), "x2")
    expect_gt(nrow(h1), 0L)
    expect_equal(h2, h1)
  })
})

# ---- Cas 4 : boucle des placettes, rasters ouverts une fois -------------

test_that("placettes : mêmes rasters par placette qu'avec une ouverture par placette (cas 4)", {
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    terra::writeRaster(ir_mnt(), "mnt.tif")
    terra::writeRaster(ir_mnh(), "mnh.tif")
    # MNT en EPSG:4326 : la reprojection n'est plus refaite à chaque placette,
    # elle doit donner les mêmes valeurs que la reprojection par placette.
    terra::writeRaster(terra::project(ir_mnt(), "EPSG:4326"), "mnt4326.tif")
    pl <- ir_pl()
    for (dem in c("mnt.tif", "mnt4326.tif")) {
      sortie <- paste0("s_", tools::file_path_sans_ext(dem))
      qgz <- ir_creer(sortie, dem = dem, chm = "mnh.tif", n_workers = 1L)
      rep <- paste0("x_", tools::file_path_sans_ext(dem))
      utils::unzip(qgz, exdir = rep)
      for (k in seq_len(nrow(pl))) {
        pid <- pl$plot_id[k]
        zone <- sf::st_buffer(sf::st_geometry(pl[k, ]), 15 + 10)
        for (cas in list(c("mnt", dem), c("mnh", "mnh.tif"))) {
          ref <- nemeton:::.iv_decouper(cas[2], zone)      # ouverture à chaque appel (ancien chemin)
          f <- paste0("ref_", pid, "_", cas[1], ".tif")
          nemeton:::.iv_ecrire_tif(ref, f)
          got <- terra::rast(file.path(rep, "rasters", paste0(pid, "_", cas[1], ".tif")))
          expect_identical(terra::values(got, mat = FALSE),
                           terra::values(terra::rast(f), mat = FALSE),
                           info = paste(dem, pid, cas[1]))
          expect_true(terra::compareGeom(got, terra::rast(f), stopOnError = FALSE))
        }
      }
    }
  })
})

test_that("placettes : MNT et MNH sont ouverts une seule fois avant la boucle (cas 4)", {
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    terra::writeRaster(ir_mnt(), "mnt.tif")
    terra::writeRaster(ir_mnh(), "mnh.tif")
    vu <- character(0)
    orig <- nemeton:::.iv_decouper
    testthat::local_mocked_bindings(.iv_decouper = function(r, zone, resolution = 0.5) {
      vu <<- c(vu, if (is.character(r)) "chemin" else "raster")
      orig(r, zone, resolution)
    })
    ir_creer("sortie", dem = "mnt.tif", chm = "mnh.tif", n_workers = 1L)
    expect_gt(length(vu), 4L)
    expect_false("chemin" %in% vu)   # jamais un chemin à rouvrir à chaque appel
  })
})

# ---- Cas 5 : .qgz identique en contenu ----------------------------------

test_that(".qgz : mêmes fichiers et mêmes octets que le dossier du projet, GeoTIFF sans recompression (cas 5)", {
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  skip_if(!nzchar(Sys.which("unzip")), "unzip absent")
  withr::with_tempdir({
    qgz <- ir_creer("sortie", n_workers = 1L)
    dossier <- file.path("sortie", "inventaire_video")
    attendu <- setdiff(list.files(dossier, recursive = TRUE), "inventaire_video.qml")
    contenu <- utils::unzip(qgz, list = TRUE)$Name
    expect_setequal(contenu, attendu)
    utils::unzip(qgz, exdir = "x")
    for (f in contenu) {
      expect_identical(unname(tools::md5sum(file.path("x", f))),
                       unname(tools::md5sum(file.path(dossier, f))), info = f)
    }
    # GeoTIFF stockés tels quels (déjà DEFLATE) ; GeoPackage et .qgs compressés
    v <- system2("unzip", c("-v", shQuote(qgz)), stdout = TRUE)
    tif <- grep("\\.tif$", v, value = TRUE)
    expect_gt(length(tif), 0L)
    expect_true(all(grepl("Stored", tif)))
    expect_false(any(grepl("Stored", grep("\\.(gpkg|qgs)$", v, value = TRUE))))
  })
})

# ---- Relecture de la PR #700 : quatre mineurs ---------------------------

test_that("n_workers par défaut : detectCores() NA -> 1 (séquentiel), sinon min(4, coeurs - 1)", {
  withr::local_options(nemeton.iv_workers = NULL)
  testthat::local_mocked_bindings(detectCores = function(...) NA_integer_, .package = "parallel")
  expect_identical(nemeton:::.iv_workers_defaut(), 1L)
  testthat::local_mocked_bindings(detectCores = function(...) 16L, .package = "parallel")
  expect_identical(nemeton:::.iv_workers_defaut(), 4L)
  testthat::local_mocked_bindings(detectCores = function(...) 1L, .package = "parallel")
  expect_identical(nemeton:::.iv_workers_defaut(), 1L)
  withr::local_options(nemeton.iv_workers = 2)
  expect_equal(nemeton:::.iv_workers_defaut(), 2)
})

test_that("workers PSOCK : le .libPaths() du parent est celui du worker, posé avant le chargement", {
  skip_on_cran()
  lib <- withr::local_tempdir()
  withr::local_libpaths(lib, action = "prefix")
  cl <- parallel::makePSOCKcluster(1)
  on.exit(parallel::stopCluster(cl), add = TRUE)
  nemeton:::.iv_cluster_init(cl)
  lp <- parallel::clusterCall(cl, function() .libPaths())[[1]]
  expect_identical(normalizePath(lp[1]), normalizePath(lib))
  expect_true(parallel::clusterCall(cl, function() "nemeton" %in% loadedNamespaces())[[1]])
})

test_that("repli séquentiel après un échec en cours de route : l'étape houppiers recommence à i = 0", {
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    terra::writeRaster(ir_mnh(terra::ext(924940, 925060, 6699940, 6700060)), "mnh.tif")
    e <- ir_emprise_2x2()
    pl <- ir_pl("P1", x = 925000)
    testthat::local_mocked_bindings(.iv_houppiers_paralleles = function(src, zones, x0, y0, nw, progres, pool = NULL) {
      progres(2L)
      stop("worker perdu")
    })
    col <- ir_collecteur()
    expect_warning(nemeton:::.iv_houppiers_emprise("mnh.tif", e, pl, 25, n_workers = 2L,
                                                   emit = nemeton:::.iv_emetteur(col$f)),
                   "running sequentially")
    d <- ir_df(col$appels())
    expect_identical(d$i[d$etape == "houppiers"], c(0L, 2L, 0L, 1L, 2L, 3L, 4L))
  })
})

test_that("binaire zip introuvable : erreur claire avant tout calcul", {
  withr::local_envvar(R_ZIPCMD = file.path(tempdir(), "zip_inexistant"))
  withr::with_tempdir({
    expect_error(
      suppressWarnings(creer_projet_inventaire_video(ir_pl(), avec_lidar = FALSE, output_dir = "sortie")),
      "zip.*not found")
    expect_error(
      suppressWarnings(creer_projet_inventaire_video(ir_pl(), avec_lidar = FALSE, output_dir = "sortie")),
      "Rtools")
    expect_false(dir.exists("sortie"))   # rien d'écrit
  })
})

# ---- Mission 059 : placettes et dalles MNT sur le même cluster -----------

# Lit un .qgz : fichiers, couche placettes, couche houppiers.
iv59_lire <- function(qgz, rep) {
  utils::unzip(qgz, exdir = rep)
  list(
    fichiers = sort(list.files(rep, recursive = TRUE)),
    placettes = sf::st_read(file.path(rep, "inventaire_video.gpkg"), layer = "placettes", quiet = TRUE),
    houppiers = sf::st_read(file.path(rep, "inventaire_video.gpkg"), layer = "houppiers", quiet = TRUE))
}
# Mêmes valeurs et même géométrie pour chaque raster du dossier `a` et du dossier `b`.
iv59_memes_rasters <- function(a, b, fichiers) {
  for (f in fichiers[grepl("\\.tif$", fichiers)]) {
    ra <- terra::rast(file.path(a, f)); rb <- terra::rast(file.path(b, f))
    expect_true(terra::compareGeom(ra, rb, stopOnError = FALSE), info = f)
    expect_identical(terra::values(ra, mat = FALSE), terra::values(rb, mat = FALSE), info = f)
  }
}
iv59_fichiers <- function() {
  terra::writeRaster(ir_mnt(), "mnt.tif")
  terra::writeRaster(ir_mnh(), "mnh.tif")
}

test_that("placettes et dalles MNT : 2 workers identiques au séquentiel (cas 1 et 2)", {
  skip_on_cran()
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    iv59_fichiers()
    s1 <- iv59_lire(ir_creer("s1", dem = "mnt.tif", chm = "mnh.tif", n_workers = 1L), "x1")
    col <- ir_collecteur()
    s2 <- iv59_lire(ir_creer("s2", dem = "mnt.tif", chm = "mnh.tif", n_workers = 2L,
                             progress_callback = col$f), "x2")
    # mêmes fichiers (rasters par placette et dalles MNT), mêmes valeurs
    expect_identical(s2$fichiers, s1$fichiers)
    expect_true(any(grepl("^rasters/P1_mnt\\.tif$", s1$fichiers)))
    expect_equal(sum(grepl("^rasters/mnt_", s1$fichiers)), 4L)
    iv59_memes_rasters("x1", "x2", s1$fichiers)
    # mêmes attributs topographiques (pente, exposition, recouvrement) et même ordre
    expect_false(all(is.na(s1$placettes$pente_pct)))
    expect_equal(s2$placettes, s1$placettes)
    expect_equal(s2$houppiers, s1$houppiers)
    # les deux étapes ont bien tourné en parallèle : compteur par lot de 2
    d <- ir_df(col$appels())
    expect_identical(d$i[d$etape == "placettes"], c(0L, 2L))
    expect_identical(d$i[d$etape == "dalles_mnt"], c(0L, 2L, 4L))
    expect_identical(d$i[d$etape == "houppiers"], c(0L, 2L, 4L))
  })
})

test_that("un seul cluster PSOCK par création, pour placettes, dalles et houppiers (cas 3)", {
  skip_on_cran()
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    iv59_fichiers()
    n_cluster <- 0L; n_init <- 0L; n_stop <- 0L
    orig_make <- parallel::makePSOCKcluster
    orig_stop <- parallel::stopCluster
    orig_init <- nemeton:::.iv_cluster_init
    testthat::local_mocked_bindings(
      makePSOCKcluster = function(...) { n_cluster <<- n_cluster + 1L; orig_make(...) },
      stopCluster = function(cl) { n_stop <<- n_stop + 1L; orig_stop(cl) },
      .package = "parallel")
    testthat::local_mocked_bindings(
      .iv_cluster_init = function(cl) { n_init <<- n_init + 1L; orig_init(cl) })
    col <- ir_collecteur()
    ir_creer("s", dem = "mnt.tif", chm = "mnh.tif", n_workers = 2L, progress_callback = col$f)
    d <- ir_df(col$appels())
    # les trois étapes ont utilisé les workers (compteurs par lot)...
    expect_identical(d$i[d$etape == "placettes"], c(0L, 2L))
    expect_identical(d$i[d$etape == "dalles_mnt"], c(0L, 2L, 4L))
    expect_identical(d$i[d$etape == "houppiers"], c(0L, 2L, 4L))
    # ... sur un seul cluster, initialisé une fois et fermé une fois
    expect_identical(n_cluster, 1L)
    expect_identical(n_init, 1L)
    expect_identical(n_stop, 1L)
  })
})

test_that("cluster fermé aussi quand la création échoue après son démarrage", {
  skip_on_cran()
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    iv59_fichiers()
    n_cluster <- 0L; n_stop <- 0L
    orig_make <- parallel::makePSOCKcluster
    orig_stop <- parallel::stopCluster
    testthat::local_mocked_bindings(
      makePSOCKcluster = function(...) { n_cluster <<- n_cluster + 1L; orig_make(...) },
      stopCluster = function(cl) { n_stop <<- n_stop + 1L; orig_stop(cl) },
      .package = "parallel")
    testthat::local_mocked_bindings(
      .iv_houppiers_emprise = function(...) stop("boum après les placettes"))
    expect_error(ir_creer("s", dem = "mnt.tif", chm = "mnh.tif", n_workers = 2L), "boum")
    expect_identical(n_cluster, 1L)
    expect_identical(n_stop, 1L)
  })
})

test_that("rasters en mémoire avec n_workers = 2 : séquentiel, aucun cluster, sans erreur (cas 4)", {
  skip_on_cran()
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    s1 <- iv59_lire(ir_creer("s1", n_workers = 1L), "x1")
    n_cluster <- 0L
    orig_make <- parallel::makePSOCKcluster
    testthat::local_mocked_bindings(
      makePSOCKcluster = function(...) { n_cluster <<- n_cluster + 1L; orig_make(...) },
      .package = "parallel")
    col <- ir_collecteur()
    s2 <- NULL
    expect_no_error(s2 <- iv59_lire(ir_creer("s2", n_workers = 2L, progress_callback = col$f), "x2"))
    expect_identical(n_cluster, 0L)
    expect_identical(s2$fichiers, s1$fichiers)
    iv59_memes_rasters("x1", "x2", s1$fichiers)
    expect_equal(s2$placettes, s1$placettes)
    expect_equal(s2$houppiers, s1$houppiers)
    d <- ir_df(col$appels())
    expect_identical(d$i[d$etape == "placettes"], 0:2)            # une placette à la fois
    expect_identical(d$i[d$etape == "dalles_mnt"], 0:4)
  })
})

test_that("MNT fichier mais MNH en mémoire : placettes séquentielles, dalles MNT parallèles, résultat identique", {
  skip_on_cran()
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    terra::writeRaster(ir_mnt(), "mnt.tif")
    s1 <- iv59_lire(ir_creer("s1", dem = "mnt.tif", n_workers = 1L), "x1")
    col <- ir_collecteur()
    s2 <- iv59_lire(ir_creer("s2", dem = "mnt.tif", n_workers = 2L, progress_callback = col$f), "x2")
    iv59_memes_rasters("x1", "x2", s1$fichiers)
    expect_equal(s2$placettes, s1$placettes)
    d <- ir_df(col$appels())
    expect_identical(d$i[d$etape == "placettes"], 0:2)
    expect_identical(d$i[d$etape == "dalles_mnt"], c(0L, 2L, 4L))
  })
})

test_that("progression parallèle : étapes dans l'ordre, chacune finit à i == n (cas 5)", {
  skip_on_cran()
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    iv59_fichiers()
    col <- ir_collecteur()
    ir_creer("s", dem = "mnt.tif", chm = "mnh.tif", n_workers = 2L, progress_callback = col$f)
    d <- ir_df(col$appels())
    expect_identical(unique(d$etape),
                     c("sources", "placettes", "dalles_mnt", "houppiers", "geopackage", "qgz"))
    expect_identical(rle(d$etape)$values, unique(d$etape))
    for (e in unique(d$etape)) {
      x <- d[d$etape == e, ]
      expect_identical(x$i[1], 0L, info = e)
      expect_identical(tail(x$i, 1L), tail(x$n, 1L), info = e)
      expect_false(is.unsorted(x$i), info = e)
      expect_false(is.unsorted(x$secondes), info = e)
    }
    expect_identical(d$n[d$etape == "placettes"][1], 2L)
    expect_identical(d$n[d$etape == "dalles_mnt"][1], 4L)
  })
})

test_that("placettes en échec dans les workers : avertissement, étape refaite en séquentiel dès i = 0", {
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    iv59_fichiers()
    s1 <- iv59_lire(ir_creer("s1", dem = "mnt.tif", chm = "mnh.tif", n_workers = 1L), "x1")
    testthat::local_mocked_bindings(.iv_pool_cl = function(pool) stop("pas de cluster"))
    col <- ir_collecteur()
    out <- NULL
    expect_warning(
      out <- suppressMessages(creer_projet_inventaire_video(
        ir_pl(), dem = "mnt.tif", chm = "mnh.tif", output_dir = "s2", n_workers = 2L,
        progress_callback = col$f)),
      "running sequentially")
    s2 <- iv59_lire(out, "x2")
    expect_equal(s2$placettes, s1$placettes)
    iv59_memes_rasters("x1", "x2", s1$fichiers)
    d <- ir_df(col$appels())
    expect_identical(d$i[d$etape == "placettes"], c(0L, 0L, 1L, 2L))
    expect_identical(tail(d$i[d$etape == "dalles_mnt"], 1L), 4L)
  })
})

test_that("cluster impossible à démarrer : un seul avertissement, tout le projet en séquentiel", {
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    iv59_fichiers()
    testthat::local_mocked_bindings(
      makePSOCKcluster = function(...) stop("pas de socket"), .package = "parallel")
    avis <- character(0)
    out <- withCallingHandlers(
      suppressMessages(creer_projet_inventaire_video(
        ir_pl(), dem = "mnt.tif", chm = "mnh.tif", output_dir = "s", n_workers = 2L)),
      warning = function(w) { avis <<- c(avis, conditionMessage(w)); invokeRestart("muffleWarning") })
    expect_true(file.exists(out))
    expect_identical(sum(grepl("could not start", avis)), 1L)
  })
})
