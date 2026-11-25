# Mission 056 : segmentation des houppiers en parallèle (PSOCK, jamais de fork),
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
