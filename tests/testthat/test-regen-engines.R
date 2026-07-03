# test-regen-engines.R — scaffolds moteurs reGénération (spec 027 L1/L2)
#
# Teste le contrat : chemin `precomputed` pur (rattachement + dérivations) et
# dégradation propre sans moteur. Aucune dépendance lourde exécutée.

.re_units <- function(n = 3L) {
  g <- lapply(seq_len(n), function(i) {
    x <- (i - 1) * 10
    sf::st_polygon(list(rbind(c(x, 0), c(x + 5, 0),
                              c(x + 5, 5), c(x, 5), c(x, 0))))
  })
  sf::st_sf(id = seq_len(n), geometry = sf::st_sfc(g, crs = 2154))
}


test_that("regen_bilan_hydrique attaches precomputed BILJOU columns", {
  u <- .re_units(3)
  out <- regen_bilan_hydrique(u, precomputed = list(
    njstress = c(10, 30, 55), rew_min = c(0.8, 0.5, 0.1), deb_stress = 180))
  expect_s3_class(out, "sf")
  expect_equal(out$njstress, c(10, 30, 55))
  expect_equal(out$deb_stress, rep(180, 3))          # recycled scalar
  expect_true(all(c("njstress", "rew_min", "deb_stress") %in% names(out)))
})

test_that("regen_bilan_hydrique feeds r3 enrichment end-to-end (precomputed)", {
  skip_if_not_installed("terra")
  u <- .re_units(2)
  u <- regen_bilan_hydrique(u, precomputed = list(njstress = c(60, 0)))
  r3 <- indicateur_r3_secheresse(u, dem = NULL)   # reads njstress column
  expect_equal(r3$R3[[1]], 100, tolerance = 1e-6)
  expect_equal(r3$R3[[2]], 0, tolerance = 1e-6)
})

test_that("regen_bilan_hydrique fails cleanly without engine nor precomputed", {
  u <- .re_units(1)
  # Selon que biljouR est installé (Remotes) ou non, l'échec propre tombe soit
  # sur le paquet manquant, soit sur les entrées moteur manquantes.
  expect_error(regen_bilan_hydrique(u), "biljouR|engine path")
})

test_that("regen_bilan_hydrique engine path validates missing forcing inputs", {
  skip_if_not_installed("biljouR")
  u <- .re_units(1)
  expect_error(regen_bilan_hydrique(u, meteo = data.frame(x = 1)),
               "engine path needs")
})

test_that("regen_bilan_hydrique rejects an unknown forest_type", {
  skip_if_not_installed("biljouR")
  u <- .re_units(1)
  expect_error(
    regen_bilan_hydrique(u, meteo = data.frame(x = 1), sol = list(), lai_max = 5,
                         forest_type = "banane"),
    "forest_type")
})

test_that("regen_bilan_hydrique runs BILJOU and maps indices per unit (real, offline)", {
  skip_if_not_installed("biljouR")
  utils::data("meteo_hesse", package = "biljouR")
  soil <- biljouR::biljou_soil(ewm = 150)
  u <- .re_units(2)
  # Résineux (persistant) : pas de phénologie requise.
  out <- regen_bilan_hydrique(u, meteo = meteo_hesse, sol = soil,
                              lai_max = 5, forest_type = "resineux")
  expect_s3_class(out, "sf")
  expect_true(all(c("njstress", "istress", "rew_min", "deb_stress") %in% names(out)))
  expect_equal(nrow(out), 2L)
  expect_true(is.numeric(out$njstress) && all(is.finite(out$njstress)))
  # Forçage uniforme -> les 2 unités partagent les mêmes valeurs.
  expect_equal(out$njstress[[1]], out$njstress[[2]])
  expect_equal(out$rew_min[[1]], out$rew_min[[2]])
})

test_that("regen_bilan_hydrique forwards phenology args to biljou_run via ...", {
  skip_if_not_installed("biljouR")
  utils::data("meteo_hesse", package = "biljouR")
  soil <- biljouR::biljou_soil(ewm = 150)
  u <- .re_units(1)
  # Feuillu SANS budburst/leaf_fall -> biljou échoue par point -> NA (dégradation).
  na_out <- regen_bilan_hydrique(u, meteo = meteo_hesse, sol = soil,
                                 lai_max = 5, forest_type = "feuillu")
  expect_true(is.na(na_out$njstress[[1]]))
  # AVEC budburst/leaf_fall passés par ... -> valeur réelle.
  ok_out <- regen_bilan_hydrique(u, meteo = meteo_hesse, sol = soil,
                                 lai_max = 5, forest_type = "feuillu",
                                 budburst = 105L, leaf_fall = 300L)
  expect_true(is.finite(ok_out$njstress[[1]]))
})

test_that("regen_bilan_hydrique output feeds indicateur_r3_secheresse", {
  skip_if_not_installed("biljouR")
  utils::data("meteo_hesse", package = "biljouR")
  soil <- biljouR::biljou_soil(ewm = 150)
  u <- regen_bilan_hydrique(.re_units(2), meteo = meteo_hesse, sol = soil,
                            lai_max = 5, forest_type = "resineux")
  expect_no_error(indicateur_r3_secheresse(u, dem = NULL))   # lit la colonne njstress
})

test_that("regen_sensibilite attaches precomputed exposure + derives d_tmax", {
  u <- .re_units(3)
  out <- regen_sensibilite(u, precomputed = list(
    tmax_moyenne = c(26, 28, 30), tmax_canicule = c(30, 34, 39),
    vpd_moyenne = c(1.0, 1.2, 1.5), vpd_canicule = c(1.8, 2.4, 3.2),
    sensibilite = c(40, 70, 90)))
  expect_equal(out$d_tmax, c(4, 6, 9))              # canicule - moyenne
  expect_equal(out$d_vpd, c(0.8, 1.2, 1.7), tolerance = 1e-6)
  expect_equal(out$rang_sensibilite, c(3, 2, 1))    # 1 = most sensitive
})

test_that("regen_sensibilite keeps an explicit d_tmax over the derived one", {
  u <- .re_units(2)
  out <- regen_sensibilite(u, precomputed = list(
    tmax_moyenne = c(26, 28), tmax_canicule = c(30, 34), d_tmax = c(99, 99)))
  expect_equal(out$d_tmax, c(99, 99))
})

test_that("regen_sensibilite output feeds indice_priorite_regen", {
  u <- .re_units(2)
  u <- regen_sensibilite(u, precomputed = list(sensibilite = c(80, 20)))
  u <- regen_bilan_hydrique(u, precomputed = list(njstress = c(60, 0), rew_min = c(0, 1)))
  out <- indice_priorite_regen(u)
  expect_gt(out$indice_priorite_regen[[1]], out$indice_priorite_regen[[2]])
})

test_that("regen_sensibilite fails cleanly without engine nor precomputed", {
  u <- .re_units(1)
  # Selon que microclimf est installé (Remotes) ou non, l'échec propre tombe
  # soit sur le paquet manquant, soit sur les entrées moteur manquantes.
  expect_error(regen_sensibilite(u), "microclimf|engine path")
})

test_that("regen_sensibilite engine path validates missing LiDAR inputs", {
  skip_if_not_installed("microclimf")
  u <- .re_units(1)
  expect_error(regen_sensibilite(u, annees_moy = 2014, annees_canic = 2018),
               "engine path needs")
})

test_that("pai_depuis_nuage passes a precomputed SpatRaster through", {
  skip_if_not_installed("terra")
  r <- terra::rast(nrows = 5, ncols = 5, vals = 3)
  expect_true(inherits(pai_depuis_nuage(precomputed = r), "SpatRaster"))
})

test_that("pai_depuis_nuage validates inputs before the engine (env-independent)", {
  skip_if_not_installed("terra")
  expect_error(pai_depuis_nuage(precomputed = 42), "SpatRaster")
  expect_error(pai_depuis_nuage(), "LiDAR")                          # no inputs
  expect_error(pai_depuis_nuage(dossier_las = "x", grille = 42), "SpatRaster")
})

test_that("precomputed with no expected column errors", {
  u <- .re_units(1)
  expect_error(regen_bilan_hydrique(u, precomputed = list(foo = 1)),
               "none of the expected")
})

test_that("precomputed with a wrong length errors", {
  u <- .re_units(3)
  expect_error(regen_bilan_hydrique(u, precomputed = list(njstress = c(1, 2))),
               "length")
})
