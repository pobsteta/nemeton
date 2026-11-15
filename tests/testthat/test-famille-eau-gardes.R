# Garde du cache TWI : un TWI vide n'est ni ecrit ni relu, et la cle porte le
# contenu du MNT (brief victor 2026-11-15, Couchey : famille Eau a 0).

vider_cache_twi <- function() {
  rm(list = ls(envir = .twi_cache, all.names = TRUE), envir = .twi_cache)
}

mnt_test <- function(valeurs = NULL) {
  r <- terra::rast(nrows = 40, ncols = 40, xmin = 843000, xmax = 843080,
                   ymin = 6685000, ymax = 6685080, crs = "EPSG:2154")
  if (is.null(valeurs)) {
    xy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
    valeurs <- 300 + 0.05 * (xy[, 1] - 843000) + 0.02 * (xy[, 2] - 6685000) +
      2 * sin(xy[, 1] / 7)
  }
  terra::values(r) <- valeurs
  r
}

test_that("an all-NA DEM yields no TWI cache file, with a warning", {
  vider_cache_twi()
  cache <- withr::local_tempdir()
  vide <- mnt_test(rep(NA_real_, 1600))
  expect_warning(twi <- get_or_compute_twi(vide, cache_dir = cache, twi_target_res = 2),
                 "not cached")
  expect_length(list.files(cache, pattern = "^twi_"), 0L)
  expect_length(ls(envir = .twi_cache), 0L)
})

test_that("an all-NA TWI file in cache is ignored, deleted and recomputed", {
  skip_if_terra_write_broken()
  vider_cache_twi()
  cache <- withr::local_tempdir()
  dem <- mnt_test()
  twi <- get_or_compute_twi(dem, cache_dir = cache, twi_target_res = 2)
  f <- list.files(cache, pattern = "^twi_", full.names = TRUE)
  expect_length(f, 1L)
  expect_gt(.part_valide(twi), 0.5)

  # On remplace le fichier par un TWI entierement vide, meme nom, meme grille.
  pourri <- terra::rast(twi)
  terra::values(pourri) <- NA_real_
  terra::writeRaster(pourri, f, overwrite = TRUE)
  vider_cache_twi()

  expect_warning(twi2 <- get_or_compute_twi(dem, cache_dir = cache, twi_target_res = 2),
                 "ignored")
  expect_gt(.part_valide(twi2), 0.5)
  expect_gt(.part_valide(terra::rast(f)), 0.5)
})

test_that("two DEMs on the same grid with different content get different keys", {
  a <- mnt_test()
  b <- mnt_test(terra::values(a)[, 1] + 1)
  vide <- mnt_test(rep(NA_real_, 1600))
  expect_true(terra::compareGeom(a, b))
  expect_false(identical(.dem_empreinte_contenu(a), .dem_empreinte_contenu(b)))
  expect_false(identical(.dem_empreinte_contenu(a), .dem_empreinte_contenu(vide)))
  expect_identical(.dem_empreinte_contenu(a), .dem_empreinte_contenu(a))

  vider_cache_twi()
  cache <- withr::local_tempdir()
  get_or_compute_twi(a, cache_dir = cache, twi_target_res = 2)
  get_or_compute_twi(b, cache_dir = cache, twi_target_res = 2)
  expect_length(list.files(cache, pattern = "^twi_"), 2L)
})

test_that(".twi_valide compares the TWI coverage with the DEM's", {
  dem <- mnt_test()
  plein <- dem
  moitie <- dem
  terra::values(moitie)[1:1200] <- NA  # 30 lignes sur 40
  expect_true(.twi_valide(plein, dem))
  expect_false(.twi_valide(moitie, dem))
  # MNT lui-meme a moitie vide : un TWI a moitie vide est normal
  expect_true(.twi_valide(moitie, moitie))
  expect_false(.twi_valide(mnt_test(rep(NA_real_, 1600)), dem))
})

test_that("a coarse TWI on a tiny grid is not rejected for its border ring", {
  dem <- mnt_test()
  petit <- terra::aggregate(dem, 8)   # 5 x 5
  twi <- petit
  terra::values(twi) <- NA_real_
  twi[2:4, 2:4] <- 5                  # seul l'interieur est defini
  expect_true(.twi_valide(twi, petit))
})

# W1 : une couche de cours d'eau fournie mais vide (reponse WFS vide) est une
# mesure, W1 = 0, sans avertissement (brief victor 2026-11-15, Couchey).
test_that("an empty watercourse layer gives W1 = 0 without warnings", {
  d <- withr::local_tempfile(fileext = ".gpkg")
  sf::st_write(sf::st_sf(geometry = sf::st_sfc(crs = 2154)), d, quiet = TRUE)
  carre <- function(x0) sf::st_polygon(list(rbind(c(x0, 0), c(x0 + 100, 0), c(x0 + 100, 100),
                                                  c(x0, 100), c(x0, 0))))
  u <- sf::st_sf(id = 1:2, geometry = sf::st_sfc(carre(0), carre(200), crs = 2154))
  l <- suppressMessages(nemeton_layers(vectors = list(water_network = d)))
  expect_no_warning(r <- suppressMessages(indicateur_w1_reseau(u, l)))
  expect_equal(r$W1, c(0, 0))
})
