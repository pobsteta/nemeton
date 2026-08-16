# Pondération du chemin fireexposuR de R1 (exposition x pente x climat).
#
# Contexte : le 2026-08-16, une fois la BD Forêt correctement rasterisée, R1
# valait 98,7 à 100 sur les 30 unités du projet Fordead. Mécaniquement juste —
# `fire_exp()` mesure la part de combustible dans un rayon de 500 m, et la BD
# Forêt couvre 93 % de l'emprise — mais l'indicateur ne classait plus rien : sur
# un massif continu, toutes les unités ont tout leur voisinage combustible.
# L'exposition est donc modulée par la pente et la sécheresse climatique, comme
# le fait le repli.

# Pas de `skip_if_not_installed("terra")` au niveau fichier : le helper maison de
# ce dépôt sonde aussi l'anomalie terra des runners GitHub, et un appel en tête
# de fichier y fait sauter le fichier ENTIER — y compris l'algèbre des poids,
# qui ne touche pas un raster. Le garde-fou est donc posé test par test.

# MNT en pente régulière ouest -> est, sur l'emprise des unités de test.
make_sloped_dem <- function(res = 10) {
  r <- terra::rast(
    xmin = 566400, xmax = 567000, ymin = 6615100, ymax = 6615500,
    resolution = res, crs = "EPSG:2154"
  )
  # 0 m a l'ouest, 300 m a l'est : la pente croit avec x.
  xy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
  terra::values(r) <- ((xy[, 1] - 566400) / 600)^2 * 300
  r
}

mock_fire_exp_identity <- function() {
  testthat::local_mocked_bindings(
    fire_exp = function(hazard, ...) hazard,
    .package = "fireexposuR",
    .env = parent.frame()
  )
}

# --- .r1_weighted_score : l'algèbre des composantes --------------------------

test_that(".r1_weighted_score drops missing components and renormalizes", {
  comps <- list(exposure = c(100, 100), slope = c(0, 60), climate = NULL)
  out <- .r1_weighted_score(comps, c(exposure = 0.5, slope = 0.25, climate = 0.25))

  # Le poids du climat absent est redistribué au prorata : 2/3 - 1/3.
  expect_equal(unname(out$weights[["exposure"]]), 2 / 3)
  expect_equal(unname(out$weights[["slope"]]), 1 / 3)
  expect_equal(out$score, c(100 * 2 / 3, 100 * 2 / 3 + 60 / 3))
})

test_that(".r1_weighted_score clamps to [0, 100] and handles a single component", {
  out <- .r1_weighted_score(list(exposure = c(-10, 250)), c(exposure = 1))
  expect_equal(out$score, c(0, 100))

  # Aucune composante calculable : NULL, l'appelant décide quoi faire.
  expect_null(.r1_weighted_score(list(exposure = NULL), c(exposure = 1)))
  expect_null(.r1_weighted_score(list(exposure = c(1, 2)), c(exposure = 0)))
})

# --- Le chemin fireexposuR pondéré ------------------------------------------

test_that("weighting makes R1 discriminate on a fully forested massif", {
  skip_if_not_installed("terra")
  skip_if_not_installed("fireexposuR")
  skip_if_terra_write_broken()
  mock_fire_exp_identity()

  dem <- make_sloped_dem()
  units <- create_test_units(n_features = 3)
  # Massif continu : tout est combustible, l'exposition sature à 100 partout.
  bdforet <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(
      sf::st_buffer(sf::st_as_sfc(sf::st_bbox(dem)), 500)[[1]],
      crs = 2154
    )
  )

  brut <- indicateur_r1_feu(units, dem = dem, bdforet = bdforet,
                            fire_exp_weights = c(exposure = 1))
  pondere <- indicateur_r1_feu(units, dem = dem, bdforet = bdforet)

  # Exposition seule : saturée, donc plate — elle ne classe rien.
  expect_equal(unique(round(brut$R1)), 100)
  # Pondérée : les unités se séparent, et le score reste sous l'exposition brute.
  expect_gt(stats::sd(pondere$R1), 1)
  expect_true(all(pondere$R1 < 100))
  expect_true(all(pondere$R1 >= 0))
})

test_that("the fireexposuR path reports the weights it actually used", {
  skip_if_not_installed("terra")
  skip_if_not_installed("fireexposuR")
  skip_if_terra_write_broken()
  mock_fire_exp_identity()

  dem <- make_sloped_dem()
  units <- create_test_units(n_features = 2)
  bdforet <- create_test_units(n_features = 2)

  msgs <- testthat::capture_messages(
    indicateur_r1_feu(units, dem = dem, bdforet = bdforet)
  )
  # Sans raster climatique, le poids du climat est redistribué : le log doit le
  # dire, c'est ce qui rend la lecture d'un score possible a posteriori.
  expect_true(any(grepl("fire_exp score = 0\\.67 x exposure \\+ 0\\.33 x slope", msgs)))
  expect_false(any(grepl("climate", msgs)))
})

test_that("a climate raster enters the fireexposuR score as a third component", {
  skip_if_not_installed("terra")
  skip_if_not_installed("fireexposuR")
  skip_if_terra_write_broken()
  mock_fire_exp_identity()

  dem <- make_sloped_dem()
  units <- create_test_units(n_features = 3)
  bdforet <- create_test_units(n_features = 3)
  climate <- list(
    temperature = create_test_raster(values = "constant"),    # 50 -> chaud, sature
    precipitation = create_test_raster(values = "constant")   # 50 mm -> tres sec
  )

  msgs <- testthat::capture_messages(
    result <- indicateur_r1_feu(units, dem = dem, bdforet = bdforet, climate = climate)
  )
  expect_true(any(grepl("0\\.50 x exposure \\+ 0\\.25 x slope \\+ 0\\.25 x climate", msgs)))
  expect_true(all(result$R1 >= 0 & result$R1 <= 100))
})

test_that("custom fire_exp_weights shift the balance", {
  skip_if_not_installed("terra")
  skip_if_not_installed("fireexposuR")
  skip_if_terra_write_broken()
  mock_fire_exp_identity()

  dem <- make_sloped_dem()
  units <- create_test_units(n_features = 3)
  bdforet <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(
      sf::st_buffer(sf::st_as_sfc(sf::st_bbox(dem)), 500)[[1]],
      crs = 2154
    )
  )

  slope_lourd <- indicateur_r1_feu(units, dem = dem, bdforet = bdforet,
                                   fire_exp_weights = c(exposure = 0.2, slope = 0.8))
  expo_lourd <- indicateur_r1_feu(units, dem = dem, bdforet = bdforet,
                                  fire_exp_weights = c(exposure = 0.8, slope = 0.2))

  # Sur un massif sature, plus la pente pese, plus le score s'ecarte de 100.
  expect_lt(mean(slope_lourd$R1), mean(expo_lourd$R1))
  # ... et plus il discrimine.
  expect_gt(stats::sd(slope_lourd$R1), stats::sd(expo_lourd$R1))
})

# --- Le repli garde son comportement -----------------------------------------

test_that("the fallback path is unchanged by the fire_exp weighting", {
  skip_if_not_installed("terra")
  skip_if_terra_write_broken()

  dem <- make_sloped_dem()
  units <- create_test_units(n_features = 3)
  units$species <- c("Pinus", "Quercus", "Fagus")

  # Pas de bdforet -> repli : `fire_exp_weights` n'a aucun effet ici.
  a <- indicateur_r1_feu(units, dem = dem, species_field = "species")
  b <- indicateur_r1_feu(units, dem = dem, species_field = "species",
                         fire_exp_weights = c(exposure = 1))
  expect_equal(a$R1, b$R1)
  expect_true(all(a$R1 >= 0 & a$R1 <= 100))
})

# --- Contrats des helpers sans raster (exécutables sur tout runner) ----------

test_that("component helpers return NULL when their input is missing", {
  units <- data.frame(id = 1:2)

  # Pas de MNT : pas de pente. NULL, pas un 50 de complaisance — c'est
  # `.r1_weighted_score` qui décide ensuite de redistribuer le poids.
  expect_null(.r1_slope_factor(NULL, units))
  expect_null(.r1_slope_factor("pas un raster", units))

  # Climat absent ou incomplet : pas de composante climatique.
  expect_null(.r1_climate_factor(NULL, units))
  expect_null(.r1_climate_factor(list(temperature = 1), units))
  expect_null(.r1_climate_factor(list(foo = 1, bar = 2), units))
})

test_that(".fire_exp_working_dem passes through a missing DEM", {
  expect_null(.fire_exp_working_dem(NULL))
  expect_identical(.fire_exp_working_dem("pas un raster"), "pas un raster")
})
