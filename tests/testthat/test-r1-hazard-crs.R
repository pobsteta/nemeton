# Alignement du CRS de la couche de combustible de R1 (safe_rasterize).
#
# Contexte : le 2026-08-16, une fois R1 débloqué (borne `fire_exp_res`), le
# projet Fordead rendait `indicateur_r1_feu` = **0 sur les 30 unités**. La BD
# Forêt y arrive en EPSG:4326 (WFS IGN) alors que le MNT LiDAR HD est en
# Lambert-93. `terra::rasterize()` ne reprojette pas — et, contrairement à la
# plupart des opérations terra, il n'échoue pas non plus sur un CRS discordant :
# il rend un raster entièrement rempli de `background`. Le `tryCatch` du chemin
# fireexposuR ne voyait donc rien, aucun repli n'était déclenché, et un
# « risque feu nul » était affiché à la place d'une absence de donnée.

skip_if_not_installed("terra")

test_that("terra::rasterize() ne signale PAS un CRS discordant (le piège)", {
  # Ce test documente le comportement amont sur lequel repose safe_rasterize.
  # S'il venait à échouer, c'est que terra a changé d'avis — et que le garde-fou
  # peut être réexaminé.
  template <- terra::rast(
    xmin = 840999.75, xmax = 845999.75, ymin = 6901000.25, ymax = 6905000.25,
    resolution = 30, crs = "EPSG:2154"
  )
  poly_4326 <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(
      sf::st_buffer(sf::st_point(c(4.96, 49.21)), 0.02),
      crs = 4326
    )
  )

  brut <- terra::rasterize(terra::vect(poly_4326), template, field = 1, background = 0)
  expect_equal(unname(terra::minmax(brut)[2, 1]), 0)  # tout background, sans erreur
})

test_that("safe_rasterize aligns the CRS before rasterizing", {
  template <- terra::rast(
    xmin = 840999.75, xmax = 845999.75, ymin = 6901000.25, ymax = 6905000.25,
    resolution = 30, crs = "EPSG:2154"
  )
  # Même polygone, en degrés : recouvre l'emprise du template une fois projeté.
  poly_4326 <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(
      sf::st_buffer(sf::st_point(c(4.96, 49.21)), 0.02),
      crs = 4326
    )
  )

  out <- safe_rasterize(poly_4326, template, field = 1, background = 0)
  expect_equal(unname(terra::minmax(out)[2, 1]), 1)
  expect_gt(sum(terra::values(out) == 1, na.rm = TRUE), 100)
  # La grille de sortie est bien celle du template.
  expect_equal(terra::res(out), terra::res(template))
  expect_true(terra::same.crs(out, template))
})

test_that("safe_rasterize is a no-op on an already-aligned vector", {
  template <- terra::rast(
    xmin = 0, xmax = 3000, ymin = 0, ymax = 3000,
    resolution = 30, crs = "EPSG:2154"
  )
  poly <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(sf::st_buffer(sf::st_point(c(1500, 1500)), 500), crs = 2154)
  )
  out <- safe_rasterize(poly, template, field = 1, background = 0)
  expect_equal(unname(terra::minmax(out)[2, 1]), 1)
})

test_that("indicateur_r1_feu handles a BD Foret served in EPSG:4326", {
  skip_if_not_installed("fireexposuR")
  skip_if_terra_write_broken()

  # Reproduction fidèle de Fordead, en réduit : MNT Lambert-93, BD Forêt en
  # degrés, unités en degrés.
  dem <- terra::rast(
    xmin = 840999.75, xmax = 845999.75, ymin = 6901000.25, ymax = 6905000.25,
    resolution = 10, crs = "EPSG:2154"
  )
  terra::values(dem) <- seq_len(terra::ncell(dem))

  bdforet <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(sf::st_buffer(sf::st_point(c(4.96, 49.21)), 0.02), crs = 4326)
  )
  units <- sf::st_sf(
    id = 1:2,
    species = c("Pinus", "Fagus"),
    geometry = sf::st_sfc(
      sf::st_buffer(sf::st_point(c(4.955, 49.208)), 0.002),
      sf::st_buffer(sf::st_point(c(4.965, 49.212)), 0.002),
      crs = 4326
    )
  )

  seen <- new.env(parent = emptyenv())
  testthat::local_mocked_bindings(
    fire_exp = function(hazard, ...) {
      seen$max <- unname(terra::minmax(hazard)[2, 1])
      hazard
    },
    .package = "fireexposuR"
  )

  result <- indicateur_r1_feu(units, dem = dem, bdforet = bdforet)

  # Le combustible atteint bien la grille : c'est ce qui manquait sur Fordead.
  expect_equal(seen$max, 1)
  expect_true(all(result$R1 > 0))
  expect_true(all(result$R1 <= 100))
})

test_that("a hazard without a single fuel cell falls back instead of scoring 0", {
  skip_if_not_installed("fireexposuR")
  skip_if_terra_write_broken()

  dem <- create_test_raster(res = 10)
  units <- create_test_units(n_features = 3)
  units$species <- rep("Pinus", 3)
  # BD Forêt réelle mais totalement disjointe de l'emprise du MNT : « aucun
  # combustible ici » n'est pas « risque nul », c'est une absence de donnée.
  bdforet <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(sf::st_buffer(sf::st_point(c(200000, 6000000)), 500), crs = 2154)
  )

  result <- NULL
  msgs <- testthat::capture_messages(
    result <- indicateur_r1_feu(units, dem = dem, bdforet = bdforet,
                                species_field = "species")
  )

  expect_true(any(grepl("no fuel cell", msgs)))
  expect_true(all(result$R1 > 0))
  expect_true(all(result$R1 <= 100))
})
