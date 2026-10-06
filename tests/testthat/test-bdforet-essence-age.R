# enrich_parcels_bdforet() : essence et âge (spec 056, constat 3).
#
# Avant 1.0.0, l'âge valait 60 partout et l'essence était un genre latin
# (« Abies », « Pinus »…) que ni resolve_species_code() ni is_conifer() ne
# reconnaissaient : toutes les UGF tombaient sur la courbe du chêne sessile
# (BROADLEAF_GENUS) et sous les seuils de diamètre P3 feuillus.

skip_if_not_installed("sf")

carre <- function(i, crs = 2154) {
  x0 <- 850000 + i * 200
  sf::st_polygon(list(cbind(c(x0, x0 + 100, x0 + 100, x0, x0),
                            c(6650000, 6650000, 6650100, 6650100, 6650000))))
}

essences <- c("Sapin, épicéa", "Pin sylvestre", "Chênes décidus",
              "Hêtre", "Douglas", "Conifères", "Feuillus", "Mixte",
              "NC", "Pin laricio, pin noir")

make_case <- function() {
  geoms <- sf::st_sfc(lapply(seq_along(essences), carre), crs = 2154)
  list(
    parcels = sf::st_sf(id = seq_along(essences), geometry = geoms),
    bdforet = sf::st_sf(essence = essences, geometry = geoms)
  )
}

test_that("BD Foret essences map to species codes the package recognises", {
  k <- make_case()
  out <- enrich_parcels_bdforet(k$parcels, k$bdforet)
  expect_identical(out$species,
                   c("ABAL", "PISY", "QUPE", "FASY", "PSME", "CONIFER_GENUS",
                     "BROADLEAF_GENUS", NA, NA, "PINI"))
  # Les résineux sont reconnus (seuils P3, courbes, tarifs)...
  expect_identical(is_conifer(out$species),
                   c(TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, FALSE, FALSE,
                     FALSE, TRUE))
  # ...et chaque essence a sa courbe de station (ou le repli de son genre).
  avail <- list_site_index_species()
  resolu <- vapply(out$species, resolve_species_code, character(1),
                   available = avail, USE.NAMES = FALSE)
  expect_identical(resolu,
                   c("ABAL", "PISY", "QUPE", "FASY", "PSME", "CONIFER_GENUS",
                     "BROADLEAF_GENUS", NA, NA, "CONIFER_GENUS"))
})

test_that("BD Foret carries no age: age is NA, never an invented 60", {
  k <- make_case()
  out <- enrich_parcels_bdforet(k$parcels, k$bdforet)
  expect_true(all(is.na(out$age)))
})

test_that("effect on P2: no site index without a measured age", {
  skip_if_not_installed("terra")
  k <- make_case()
  enr <- enrich_parcels_bdforet(k$parcels, k$bdforet)
  u <- k$parcels; u$species <- enr$species; u$age <- enr$age
  chm <- terra::rast(terra::ext(terra::vect(u)) + 50, resolution = 2,
                     crs = "EPSG:2154")
  terra::values(chm) <- 25
  p2 <- suppressMessages(indicateur_p2_station(u, chm = chm))
  # Avant : 20,71 m ou 10,90 m (classes 1 / 5 du chêne à 50 ans) partout.
  expect_true(all(is.na(p2$P2)))
  # Avec un âge mesuré, le sapin est jugé sur la courbe du sapin.
  u$age <- 60
  p2 <- suppressMessages(indicateur_p2_station(u, chm = chm))
  expect_equal(p2$P2[1], compute_site_index(25, 60, "ABAL"))
  expect_false(isTRUE(all.equal(p2$P2[1], compute_site_index(25, 60, "QUPE"))))
})

test_that("effect on P3: conifer diameter thresholds for BD Foret conifers", {
  k <- make_case()
  enr <- enrich_parcels_bdforet(k$parcels, k$bdforet)
  u <- k$parcels; u$species <- enr$species; u$dbh <- 32
  p3 <- suppressMessages(indicateur_p3_qualite_bois(u))
  # DBH 32 cm : au-dessus du seuil sciage résineux (30), sous le feuillu (40).
  expect_true(p3$P3[1] > p3$P3[3])                    # sapin > chêne
  expect_equal(p3$P3[1], p3$P3[2])                    # sapin = pin sylvestre
})

test_that("effect on C1: no allometric biomass from an invented age", {
  skip_if_not_installed("terra")
  k <- make_case()
  ndvi <- terra::rast(terra::ext(terra::vect(k$parcels)) + 50, resolution = 10,
                      crs = "EPSG:2154")
  terra::values(ndvi) <- 0.8
  f <- withr::local_tempfile(fileext = ".tif")
  terra::writeRaster(ndvi, f)
  gp <- withr::local_tempfile(fileext = ".gpkg")
  sf::st_write(k$bdforet, gp, quiet = TRUE)
  layers <- nemeton_layers(rasters = list(ndvi = f), vectors = list(bdforet = gp))
  c1 <- suppressMessages(indicateur_c1_biomasse(k$parcels, layers))$C1
  # Sans âge, le chemin BD Forêt (allométrie âge × densité) est sauté : repli
  # NDVI, 0,8 × 150 = 120 tC/ha. Avant : biomasse allométrique à 60 ans.
  expect_equal(c1, rep(120, length(essences)), tolerance = 1e-6)
})

test_that("effect on T1: a missing BD Foret age leaves T1 to the TFV", {
  k <- make_case()
  enr <- enrich_parcels_bdforet(k$parcels, k$bdforet)
  u <- k$parcels; u$age <- enr$age
  bd <- k$bdforet
  bd$tfv <- "Forêt fermée de conifères purs"
  t1 <- suppressMessages(indicateur_t1_anciennete(u, bdforet = bd))$T1
  # Avant : l'âge inventé (60) passait pour un âge MESURÉ et masquait le TFV.
  expect_equal(t1, rep(80, length(essences)))
})
