# Borne de résolution du chemin `fireexposuR` de R1 (.fire_exp_working_dem).
#
# Contexte : le 2026-08-16, le calcul des 31 indicateurs du projet Fordead est
# resté plus de 75 min sur `indicateur_r1_feu`, à 51 % d'un cœur, sans I/O ni
# pression mémoire. `fire_exp()` matérialise sa fenêtre annulaire en cellules :
# sur la mosaïque lidar_mnt ramenée à 2 m (5 M cellules), la fenêtre t_dist =
# 500 m fait 501 x 501 = 251 000 poids, soit ~1,25e12 opérations mono-thread.
# Le chemin fireexposuR travaille désormais à 30 m au plus fin ; les indicateurs
# topographiques (R2, R3, W3) gardent, eux, le `.topo_target_res()` à 2 m.

skip_if_not_installed("terra")

make_dem <- function(res, crs = "EPSG:2154", ncol = 100, nrow = 100) {
  r <- terra::rast(
    nrows = nrow, ncols = ncol,
    xmin = 0, xmax = ncol * res, ymin = 0, ymax = nrow * res,
    crs = crs
  )
  terra::values(r) <- seq_len(terra::ncell(r))
  r
}

# --- CA-2 / CA-3 : la borne sur la grille de travail --------------------------

test_that(".fire_exp_working_dem bounds a LiDAR DEM to 30 m", {
  for (res in c(0.5, 1, 2)) {
    out <- .fire_exp_working_dem(make_dem(res = res), fire_exp_res = 30)
    expect_equal(terra::res(out)[1], 30)
  }
  # 0,5 m -> 30 m : 3 600x moins de cellules, et une fenêtre annulaire 231x plus
  # petite (33 x 33 au lieu de 2001 x 2001).
  dem <- make_dem(res = 0.5, ncol = 600, nrow = 600)
  expect_equal(terra::ncell(.fire_exp_working_dem(dem)) / terra::ncell(dem), 1 / 3600)
})

test_that(".fire_exp_working_dem keeps the extent so extractions stay comparable", {
  dem <- make_dem(res = 0.5, ncol = 600, nrow = 600)
  out <- .fire_exp_working_dem(dem)
  expect_equal(as.vector(terra::ext(out)), as.vector(terra::ext(dem)))
  expect_equal(terra::crs(out), terra::crs(dem))
})

test_that(".fire_exp_working_dem never touches a DEM already coarser (CA-3)", {
  # BD ALTI 25 m (NDP 0) : le `max()` évite de le ré-agréger pour 5 m de gain.
  dem25 <- make_dem(res = 25)
  expect_equal(terra::res(.fire_exp_working_dem(dem25))[1], 25)
  expect_equal(terra::ncell(.fire_exp_working_dem(dem25)), terra::ncell(dem25))

  # 100 m : jamais affiné à 30 m.
  dem100 <- make_dem(res = 100)
  expect_equal(terra::res(.fire_exp_working_dem(dem100))[1], 100)
})

test_that(".fire_exp_working_dem falls back to dem_target_res without a bound", {
  dem <- make_dem(res = 0.5)
  # Sans borne feu, la grille du hazard retombe sur la résolution topographique
  # de travail : le comportement d'avant le correctif, conservé comme
  # échappatoire explicite.
  for (fer in list(NULL, NA_real_, 0, -30)) {
    expect_equal(
      terra::res(.fire_exp_working_dem(dem, fire_exp_res = fer, dem_target_res = 2))[1],
      2
    )
    # Les deux bornes levées : résolution native.
    expect_equal(
      terra::res(.fire_exp_working_dem(dem, fire_exp_res = fer, dem_target_res = NULL))[1],
      0.5
    )
  }
  # Un DEM en degrés : la borne est métrique, l'agrégation n'a pas de sens.
  lonlat <- make_dem(res = 0.001, crs = "EPSG:4326")
  expect_equal(terra::res(.fire_exp_working_dem(lonlat))[1], 0.001)
  # Pas de DEM du tout : passe-plat.
  expect_null(.fire_exp_working_dem(NULL))
})

# --- CA-5 : le contexte lisible dans les logs --------------------------------

test_that(".fire_exp_working_dem logs the R1/fire_exp context", {
  expect_message(
    .fire_exp_working_dem(make_dem(res = 0.5)),
    "R1/fire_exp.*0\\.5m -> 30m"
  )
})

# --- CA-2 de bout en bout : la grille réellement passée à fire_exp() ---------

test_that("indicateur_r1_feu hands fire_exp a hazard raster bounded to 30 m", {
  skip_if_not_installed("fireexposuR")
  skip_if_terra_write_broken()

  units <- create_test_units(n_features = 3)
  bdforet <- create_test_units(n_features = 2)
  # MNT « LiDAR HD » 0,5 m sur l'emprise des unités de test (600 x 400 m).
  dem <- create_test_raster(res = 0.5)

  seen <- new.env(parent = emptyenv())
  testthat::local_mocked_bindings(
    fire_exp = function(hazard, ...) {
      seen$res <- terra::res(hazard)[1]
      seen$ncell <- terra::ncell(hazard)
      hazard
    },
    .package = "fireexposuR"
  )

  result <- NULL
  msgs <- testthat::capture_messages(
    result <- indicateur_r1_feu(units, dem = dem, bdforet = bdforet)
  )

  # CA-2 : la grille du hazard est bien >= 30 m, pas le 2 m topographique.
  expect_gte(seen$res, 30)
  expect_equal(seen$res, 30)
  # CA-5 : le contexte est lisible dans les logs, et le MNT est agrégé UNE fois,
  # du natif vers 30 m — pas de passage intermédiaire à 2 m payé pour rien.
  expect_true(any(grepl("R1/fire_exp: DEM aggregated 0\\.5m -> 30m", msgs)))
  expect_false(any(grepl("R1: DEM aggregated", msgs)))
  # 600 x 400 m à 0,5 m = 1200 x 800 cellules -> 20 x 14 à 30 m (dernière ligne
  # partielle), soit 3 400x moins de cellules dans le focal.
  expect_equal(seen$ncell, 20 * 14)
  # CA-4 (bornes) : le score reste dans [0, 100].
  expect_true(all(result$R1 >= 0 & result$R1 <= 100, na.rm = TRUE))
})

test_that("indicateur_r1_feu leaves the fallback path at the topographic res", {
  skip_if_terra_write_broken()

  units <- create_test_units(n_features = 3)
  units$species <- rep("Pinus", 3)
  dem <- create_test_raster(res = 0.5)

  # Pas de bdforet -> repli slope + species + climate : son coût est linéaire en
  # cellules, il n'a aucune raison d'être bridé à 30 m.
  result <- NULL
  msgs <- testthat::capture_messages(
    result <- indicateur_r1_feu(units, dem = dem, species_field = "species")
  )
  expect_false(any(grepl("R1/fire_exp", msgs)))
  expect_true(any(grepl("R1: DEM aggregated .* -> 2m", msgs)))
  expect_true(all(result$R1 >= 0 & result$R1 <= 100, na.rm = TRUE))
})

test_that("fire_exp_res = NULL restores the unbounded (slow) grid", {
  skip_if_not_installed("fireexposuR")
  skip_if_terra_write_broken()

  units <- create_test_units(n_features = 2)
  bdforet <- create_test_units(n_features = 2)
  dem <- create_test_raster(res = 0.5)

  seen <- new.env(parent = emptyenv())
  testthat::local_mocked_bindings(
    fire_exp = function(hazard, ...) {
      seen$res <- terra::res(hazard)[1]
      hazard
    },
    .package = "fireexposuR"
  )

  indicateur_r1_feu(units, dem = dem, bdforet = bdforet, fire_exp_res = NULL)
  # La grille retombe sur `dem_target_res` (2 m par défaut) : c'est le
  # comportement d'avant la borne, conservé comme échappatoire explicite.
  expect_equal(seen$res, 2)
})

# --- CA-4 : la borne change le temps, pas le classement ----------------------

test_that("bounding the grid preserves the R1 ranking of units", {
  skip_if_not_installed("fireexposuR")
  skip_on_cran()
  skip_if_terra_write_broken()

  # Emprise de 4 km : assez large pour que le noyau de 500 m discrimine les
  # unités, assez petite pour que la référence non bornée (15 m) reste tenable.
  x0 <- 900000
  y0 <- 6500000
  dem <- terra::rast(
    xmin = x0, xmax = x0 + 4000, ymin = y0, ymax = y0 + 4000,
    resolution = 15, crs = "EPSG:2154"
  )
  terra::values(dem) <- seq_len(terra::ncell(dem))

  set.seed(42)
  # Massif forestier hétérogène : des patches de taille et de densité variables.
  centres <- expand.grid(
    x = seq(x0 + 400, x0 + 3600, length.out = 5),
    y = seq(y0 + 400, y0 + 3600, length.out = 5)
  )
  keep <- as.logical(stats::rbinom(nrow(centres), 1, 0.6))
  centres <- centres[keep, , drop = FALSE]
  rayons <- stats::runif(nrow(centres), 150, 400)
  bdforet <- sf::st_sf(
    id = seq_len(nrow(centres)),
    geometry = sf::st_sfc(
      lapply(seq_len(nrow(centres)), function(i) {
        sf::st_buffer(sf::st_point(c(centres$x[i], centres$y[i])), rayons[i])
      }),
      crs = 2154
    )
  )

  # Unités de gestion : une grille de 4 x 4 carrés de 500 m.
  grille <- expand.grid(
    x = seq(x0 + 500, x0 + 3000, length.out = 4),
    y = seq(y0 + 500, y0 + 3000, length.out = 4)
  )
  units <- sf::st_sf(
    id = seq_len(nrow(grille)),
    geometry = sf::st_sfc(
      lapply(seq_len(nrow(grille)), function(i) {
        sf::st_polygon(list(matrix(
          c(
            grille$x[i], grille$y[i],
            grille$x[i] + 500, grille$y[i],
            grille$x[i] + 500, grille$y[i] + 500,
            grille$x[i], grille$y[i] + 500,
            grille$x[i], grille$y[i]
          ),
          ncol = 2, byrow = TRUE
        )))
      }),
      crs = 2154
    )
  )

  borne <- indicateur_r1_feu(units, dem = dem, bdforet = bdforet,
                             dem_target_res = NULL, fire_exp_res = 30)
  reference <- indicateur_r1_feu(units, dem = dem, bdforet = bdforet,
                                 dem_target_res = NULL, fire_exp_res = NULL)

  expect_true(all(borne$R1 >= 0 & borne$R1 <= 100, na.rm = TRUE))
  # Le classement des unités est conservé : la borne joue sur le temps, pas sur
  # la lecture qu'un gestionnaire fait de la carte.
  expect_gt(stats::cor(borne$R1, reference$R1, use = "complete.obs"), 0.95)
  expect_gt(
    stats::cor(borne$R1, reference$R1, method = "spearman", use = "complete.obs"),
    0.9
  )
})
