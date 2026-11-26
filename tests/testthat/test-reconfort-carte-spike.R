# Carte de classes du spike RECONFORT (mission 076) : scenes MUSCATE `synth_`
# ecrites sur disque, aucun reseau.

# Ecrit des scenes tous les 10 jours de `annee` dans <dir>/extracted/T31TCN/.
# Pixel (ligne l, colonne c) : classe ((c - 1) %% 3) + 1, comme les placettes de
# synth_reconfort_serie (B11 monte avec la classe apres le jour 150).
# `nuage` : cellules couvertes par un nuage CLM a toutes les dates.
synth_scenes_carte <- function(dir, annee = 2022L, nr = 6L, nc = 9L,
                               x0 = 500000, y0 = 6500000, res = 10,
                               nuage = integer(), bande_20m = FALSE) {
  withr::local_seed(5L)
  gabarit <- terra::rast(nrows = nr, ncols = nc, xmin = x0, xmax = x0 + nc * res,
                         ymin = y0, ymax = y0 + nr * res, crs = "EPSG:2154")
  cl <- ((seq_len(nr * nc) - 1L) %% nc) %% 3L + 1L
  dates <- seq(as.Date(sprintf("%d-01-05", annee)), as.Date(sprintf("%d-12-25", annee)),
               by = "10 days")
  for (d in as.character(dates)) {
    nom <- sprintf("SENTINEL2A_%s-103000-000_L2A_T31TCN_D", format(as.Date(d), "%Y%m%d"))
    sc <- file.path(dir, "extracted", "T31TCN", nom)
    dir.create(file.path(sc, "MASKS"), recursive = TRUE)
    doy <- as.integer(format(as.Date(d), "%j"))
    saison <- sin(pi * pmin(doy, 300) / 300)
    n <- nr * nc
    vals <- list(B4 = 0.05 + 0.01 * runif(n), B5 = 0.08 + 0.01 * runif(n),
                 B6 = 0.20 + 0.05 * saison + 0.01 * runif(n),
                 B8A = 0.35 + 0.1 * saison + 0.01 * runif(n),
                 B11 = 0.20 + 0.04 * runif(n) + (doy > 150) * 0.08 * (cl - 1),
                 B12 = 0.12 + 0.01 * runif(n))
    for (b in names(vals)) {
      r <- terra::setValues(gabarit, vals[[b]])
      if (bande_20m && b == "B5") {
        r <- terra::aggregate(r, 3L, fun = "mean")
      }
      terra::writeRaster(r, file.path(sc, sprintf("%s_FRE_%s.tif", nom, b)))
    }
    clm <- rep(0, n)
    clm[nuage] <- 1
    terra::writeRaster(terra::setValues(gabarit, clm),
                       file.path(sc, "MASKS", sprintf("%s_CLM_R1.tif", nom)))
  }
  gabarit
}

# Meme chose que la carte, mais en table : serie des bandes lues dans les fichiers.
synth_serie_table <- function(dir, gabarit) {
  scenes <- .enumerate_reconfort_s2_scenes(dir)
  do.call(rbind, lapply(scenes, function(s) {
    b <- lapply(s[c("B04", "B05", "B06", "B8A", "B11", "B12")],
                function(f) terra::values(terra::rast(f), mat = FALSE))
    names(b) <- c("B4", "B5", "B6", "B8A", "B11", "B12")
    clm <- terra::values(terra::rast(s$clm), mat = FALSE)
    d <- data.frame(id_unique = as.character(seq_len(terra::ncell(gabarit))),
                    date = s$obs_date, as.data.frame(b))
    d[clm != 0, c("B4", "B5", "B6", "B8A", "B11", "B12")] <- NA_real_
    d
  }))
}

synth_modele_carte <- function() {
  pl <- synth_reconfort_placettes()
  reconfort_entrainer(synth_reconfort_serie(pl), reconfort_etiquettes(pl),
                      k = 4L, taille_bloc = 1000, seed = 11L, num_arbres = 60L)
}

test_that("cas 1 : la carte est alignee sur le gabarit, un gabarit decale d'un demi-pixel est refuse", {
  skip_if_not_installed("ranger")
  dir <- withr::local_tempdir()
  gab <- synth_scenes_carte(dir)
  m <- synth_modele_carte()
  sortie <- file.path(dir, "carte.tif")
  reconfort_carte_spike(m, dir, 2022L, gab, sortie, quiet = TRUE)
  carte <- terra::rast(sortie)
  expect_true(terra::compareGeom(carte, gab, crs = TRUE, ext = TRUE, rowcol = TRUE,
                                 res = TRUE, stopOnError = FALSE))
  expect_equal(as.vector(terra::ext(carte)), as.vector(terra::ext(gab)))
  expect_equal(terra::res(carte), terra::res(gab))
  expect_true(terra::same.crs(carte, gab))
  v <- terra::values(carte, mat = FALSE)
  expect_true(all(v[!is.na(v)] %in% 1:3))
  expect_gt(sum(!is.na(v)), 0L)

  decale <- terra::shift(gab, dx = 5, dy = 0)
  expect_error(reconfort_carte_spike(m, dir, 2022L, decale, file.path(dir, "x.tif"), quiet = TRUE),
               class = "reconfort_carte_alignement")
  expect_false(file.exists(file.path(dir, "x.tif")))
})

test_that("cas 2 : la classe de la carte est celle de reconfort_predire sur la serie du meme pixel", {
  skip_if_not_installed("ranger")
  dir <- withr::local_tempdir()
  gab <- synth_scenes_carte(dir)
  m <- synth_modele_carte()
  sortie <- file.path(dir, "carte.tif")
  reconfort_carte_spike(m, dir, 2022L, gab, sortie, quiet = TRUE)
  v <- terra::values(terra::rast(sortie), mat = FALSE)

  tab <- synth_serie_table(dir, gab)
  cib <- data.frame(id_unique = as.character(seq_len(terra::ncell(gab))), annee = 2022L)
  ref <- reconfort_predire(m, tab, cib)
  expect_equal(as.integer(v), as.integer(ref$classe))
  # le signal synthetique est net : la carte retrouve la classe de la colonne
  attendu <- ((seq_len(terra::ncell(gab)) - 1L) %% terra::ncol(gab)) %% 3L + 1L
  expect_gt(mean(v == attendu, na.rm = TRUE), 0.8)
})

test_that("cas 3 : pixel sous nuage, hors chenaie ou coupe avant l'annee -> NA", {
  skip_if_not_installed("ranger")
  dir <- withr::local_tempdir()
  gab <- synth_scenes_carte(dir, nuage = 2L)
  m <- synth_modele_carte()
  nc <- terra::ncol(gab)
  chenaie <- terra::setValues(gab, 1)
  chenaie[4L] <- 0
  coupes <- terra::setValues(gab, 0)
  coupes[6L] <- 21100   # coupee en 2021 : retiree pour 2022
  coupes[7L] <- 23100   # coupee en 2023 : encore valable en 2022
  sortie <- file.path(dir, "carte.tif")
  reconfort_carte_spike(m, dir, 2022L, gab, sortie, chenaie = chenaie,
                        coupes = coupes, quiet = TRUE)
  v <- terra::values(terra::rast(sortie), mat = FALSE)
  expect_true(is.na(v[2L]))   # nuage a toutes les dates
  expect_true(is.na(v[4L]))   # hors chenaie
  expect_true(is.na(v[6L]))   # coupe rase
  expect_false(is.na(v[1L]))
  expect_false(is.na(v[7L]))
  expect_equal(sum(is.na(v)), 3L)
})

test_that("cas 4 : plusieurs blocs donnent la meme carte qu'un seul", {
  skip_if_not_installed("ranger")
  dir <- withr::local_tempdir()
  gab <- synth_scenes_carte(dir, nuage = c(5L, 20L))
  m <- synth_modele_carte()
  nc <- terra::ncol(gab)
  un <- file.path(dir, "un.tif")
  deux <- file.path(dir, "plusieurs.tif")
  reconfort_carte_spike(m, dir, 2022L, gab, un, px_par_bloc = 1e6, quiet = TRUE)
  expect_message(
    reconfort_carte_spike(m, dir, 2022L, gab, deux, px_par_bloc = 2 * nc),
    "3\\s+blocks\\s+of\\s+2\\s+rows")
  expect_identical(terra::values(terra::rast(deux), mat = FALSE),
                   terra::values(terra::rast(un), mat = FALSE))
  # un budget memoire minuscule (en octets) force aussi des blocs d'une ligne
  trois <- file.path(dir, "budget.tif")
  expect_message(reconfort_carte_spike(m, dir, 2022L, gab, trois, memory_max = "1M"),
                 "blocks?\\s+of")
  expect_identical(terra::values(terra::rast(trois), mat = FALSE),
                   terra::values(terra::rast(un), mat = FALSE))
})

test_that("cas 5 : modele absent ou d'une autre classe, annee sans scene -> erreur claire", {
  dir <- withr::local_tempdir()
  gab <- synth_scenes_carte(dir)
  expect_error(reconfort_carte_spike(NULL, dir, 2022L, gab, file.path(dir, "c.tif")),
               class = "reconfort_carte_modele")
  expect_error(reconfort_carte_spike(list(modele = 1), dir, 2022L, gab, file.path(dir, "c.tif")),
               class = "reconfort_carte_modele")
  skip_if_not_installed("ranger")
  m <- synth_modele_carte()
  expect_error(reconfort_carte_spike(m, dir, 2019L, gab, file.path(dir, "c.tif")),
               class = "reconfort_carte_sans_scene")
  expect_error(reconfort_carte_spike(m, dir, 2022L, "pas_un_raster.tif", file.path(dir, "c.tif")),
               class = "reconfort_carte_gabarit")
  expect_error(reconfort_carte_spike(m, dir, "2022", gab, file.path(dir, "c.tif")),
               class = "reconfort_carte_annee")
})

test_that("une bande a 20 m (B5) est reechantillonnee sur la grille 10 m sans erreur", {
  skip_if_not_installed("ranger")
  dir <- withr::local_tempdir()
  gab <- synth_scenes_carte(dir, nr = 6L, nc = 9L, bande_20m = TRUE)
  m <- synth_modele_carte()
  sortie <- file.path(dir, "carte.tif")
  reconfort_carte_spike(m, dir, 2022L, gab, sortie, quiet = TRUE)
  v <- terra::values(terra::rast(sortie), mat = FALSE)
  expect_gt(sum(!is.na(v)), 0L)
})

test_that("A/B : un CRS ou une resolution differents sont refuses, acceptes avec reprojeter = TRUE et un avertissement", {
  skip_if_not_installed("ranger")
  dir <- withr::local_tempdir()
  gab <- synth_scenes_carte(dir)
  m <- synth_modele_carte()
  sortie <- file.path(dir, "c.tif")

  autre_crs <- terra::project(gab, "EPSG:32631")
  expect_error(reconfort_carte_spike(m, dir, 2022L, autre_crs, sortie, quiet = TRUE),
               class = "reconfort_carte_crs")
  expect_false(file.exists(sortie))
  expect_warning(
    reconfort_carte_spike(m, dir, 2022L, autre_crs, sortie, reprojeter = TRUE, quiet = TRUE),
    class = "reconfort_carte_reprojection")
  carte <- terra::rast(sortie)
  expect_true(terra::same.crs(carte, autre_crs))
  expect_gt(sum(!is.na(terra::values(carte, mat = FALSE))), 0L)

  gros <- terra::aggregate(gab, 3L)   # 30 m, emboite dans la grille 10 m
  expect_error(reconfort_carte_spike(m, dir, 2022L, gros, sortie, quiet = TRUE),
               class = "reconfort_carte_resolution")
  expect_warning(
    reconfort_carte_spike(m, dir, 2022L, gros, sortie, reprojeter = TRUE, quiet = TRUE),
    class = "reconfort_carte_reprojection")
  expect_equal(terra::res(terra::rast(sortie)), terra::res(gros))
})

test_that("B : une bande d'une grille non emboitee dans celle de B04 est refusee", {
  skip_if_not_installed("ranger")
  dir <- withr::local_tempdir()
  gab <- synth_scenes_carte(dir)
  m <- synth_modele_carte()
  # B11 de toutes les scenes decalee d'un demi-pixel : sa grille n'est plus emboitee
  for (f in list.files(dir, "_FRE_B11\\.tif$", recursive = TRUE, full.names = TRUE)) {
    r <- terra::shift(terra::rast(f) * 1, dx = 5)
    unlink(f)
    terra::writeRaster(r, f, overwrite = TRUE)
  }
  expect_error(reconfort_carte_spike(m, dir, 2022L, gab, file.path(dir, "c.tif"), quiet = TRUE),
               class = "reconfort_carte_resolution")
})

test_that("C/D : le bloc se divise par le nombre de scenes ; l'avertissement SCL est unique", {
  skip_if_not_installed("ranger")
  dir <- withr::local_tempdir()
  gab <- synth_scenes_carte(dir)
  m <- synth_modele_carte()
  nc <- terra::ncol(gab)
  # 37 scenes : plafond (7.2e6 px x scenes) / 37 = 194 594 px, donc tout tient en un bloc ;
  # un plafond de memoire minuscule, divise par 37, force des blocs d'une ligne
  expect_message(reconfort_carte_spike(m, dir, 2022L, gab, file.path(dir, "a.tif")),
                 "1\\s+blocks?\\s+of")
  expect_message(reconfort_carte_spike(m, dir, 2022L, gab, file.path(dir, "b.tif"), memory_max = "1M"),
                 "6\\s+blocks\\s+of\\s+1\\s+row")
  # scenes sans CLM mais avec SCL : un seul avertissement pour toutes
  for (f in list.files(dir, "_CLM_R1\\.tif$", recursive = TRUE, full.names = TRUE)) {
    file.rename(f, sub("_CLM_R1", "_SCL", f))
  }
  n <- 0L
  withCallingHandlers(
    reconfort_carte_spike(m, dir, 2022L, gab, file.path(dir, "c.tif"), quiet = TRUE),
    reconfort_carte_scl = function(w) {
      n <<- n + 1L
      invokeRestart("muffleWarning")
    })
  expect_equal(n, 1L)
})
