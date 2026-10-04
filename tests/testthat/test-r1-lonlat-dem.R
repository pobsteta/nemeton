# R1, chemin fireexposuR sur un MNT en coordonnées géographiques.
#
# Contexte : le 2026-10-04 (projets Couchey et Aumur, NDP 1), le MNT de repli
# IGN arrivait en EPSG:4326 à 2,5e-4 degré. La borne métrique de 30 m était
# ignorée sur une grille lon/lat et `fire_exp(hazard, t_dist = 500)` construisait
# une fenêtre de 500 / 2,5e-4 cellules de rayon : « cannot allocate vector of
# size 59622.1 Gb ». Le repli prenait la main à chaque calcul, sans trace dans
# le résultat. Le chemin n'avait abouti sur aucun projet journalisé.

skip_if_not_installed("terra")
skip_if_not_installed("sf")

# Emprise ~1,6 x 1,1 km autour de Couchey (Côte-d'Or), en EPSG:4326.
make_lonlat_dem <- function(res = 2.5e-4) {
  r <- terra::rast(
    xmin = 4.950, xmax = 4.970, ymin = 47.260, ymax = 47.270,
    resolution = res, crs = "EPSG:4326"
  )
  terra::values(r) <- 300 + seq_len(terra::ncell(r)) %% 50
  r
}

make_lonlat_polys <- function(n = 3) {
  polys <- lapply(seq_len(n), function(i) {
    x0 <- 4.952 + (i - 1) * 0.005
    sf::st_polygon(list(matrix(
      c(x0, 47.262, x0 + 0.004, 47.262, x0 + 0.004, 47.268,
        x0, 47.268, x0, 47.262),
      ncol = 2, byrow = TRUE
    )))
  })
  sf::st_sf(id = seq_len(n), geometry = sf::st_sfc(polys, crs = 4326))
}

test_that(".fire_exp_working_dem projects a lon/lat DEM to a metric grid", {
  out <- NULL
  expect_message(
    out <- .fire_exp_working_dem(make_lonlat_dem(), crs = "EPSG:2154"),
    "lon/lat DEM .* projected to a metric grid"
  )
  expect_false(terra::is.lonlat(out))
  # 2,5e-4 degré ~ 19 x 28 m : grille >= 30 m après la borne, jamais en degrés.
  expect_gte(terra::res(out)[1], 18)
  expect_lt(terra::res(out)[1], 100)
  # La fenêtre de fire_exp() reste raisonnable sur cette grille.
  expect_lt(.fire_exp_check_grid(out, t_dist = 500), 1e4)
})

test_that(".fire_exp_metric_crs prefers projected units, else EPSG:3035", {
  polys <- make_lonlat_polys()
  expect_equal(.fire_exp_metric_crs(polys), "EPSG:3035")
  expect_equal(.fire_exp_metric_crs(NULL), "EPSG:3035")
  l93 <- sf::st_transform(polys, 2154)
  expect_equal(.fire_exp_metric_crs(l93), sf::st_crs(2154)$wkt)
})

test_that(".fire_exp_check_grid rejects degrees and oversized windows", {
  expect_error(
    .fire_exp_check_grid(make_lonlat_dem(), t_dist = 500),
    "geographic coordinates"
  )
  fine <- terra::rast(xmin = 0, xmax = 100, ymin = 0, ymax = 100,
                      resolution = 0.5, crs = "EPSG:2154")
  # (1000 / 0,5)^2 = 4e6 poids > 1e6.
  expect_error(.fire_exp_check_grid(fine, t_dist = 500), "window too large")
  ok <- terra::rast(xmin = 0, xmax = 300, ymin = 0, ymax = 300,
                    resolution = 30, crs = "EPSG:2154")
  expect_equal(.fire_exp_check_grid(ok, t_dist = 500), (1000 / 30)^2)
  # L'échappatoire fire_exp_res = NULL (2 m) reste permise.
  two <- terra::rast(xmin = 0, xmax = 100, ymin = 0, ymax = 100,
                     resolution = 2, crs = "EPSG:2154")
  expect_equal(.fire_exp_check_grid(two, t_dist = 500), 250000)
})

test_that("indicateur_r1_feu runs fire_exp on a metric grid from a lon/lat DEM", {
  skip_if_not_installed("fireexposuR")
  skip_if_terra_write_broken()

  units <- make_lonlat_polys(3)
  bdforet <- make_lonlat_polys(2)
  dem <- make_lonlat_dem()

  seen <- new.env(parent = emptyenv())
  testthat::local_mocked_bindings(
    fire_exp = function(hazard, t_dist, ...) {
      seen$lonlat <- terra::is.lonlat(hazard)
      seen$res <- terra::res(hazard)[1]
      hazard
    },
    .package = "fireexposuR"
  )

  result <- suppressMessages(indicateur_r1_feu(units, dem = dem, bdforet = bdforet))
  expect_false(seen$lonlat)
  expect_gte(seen$res, 18)
  expect_equal(result$r1_status, rep("fire_exp", 3))
  expect_true(all(is.na(result$r1_fallback_reason)))
  expect_true(all(result$R1 >= 0 & result$R1 <= 100))
})

test_that("indicateur_r1_feu records the fallback reason in the result", {
  skip_if_terra_write_broken()

  units <- create_test_units(n_features = 3)
  units$species <- rep("Pinus", 3)
  dem <- create_test_raster(res = 5)

  # Sans BD Forêt : repli, motif dans le résultat.
  res_nobd <- suppressMessages(
    indicateur_r1_feu(units, dem = dem, species_field = "species")
  )
  expect_true(all(res_nobd$r1_status %in% c("fallback_no_bdforet", "fallback_no_fireexposur")))
  expect_true(all(!is.na(res_nobd$r1_fallback_reason)))

  # fire_exp() en échec : le message d'erreur est porté par le résultat.
  skip_if_not_installed("fireexposuR")
  bdforet <- create_test_units(n_features = 2)
  testthat::local_mocked_bindings(
    fire_exp = function(...) stop("boom"),
    .package = "fireexposuR"
  )
  res_err <- suppressMessages(
    indicateur_r1_feu(units, dem = dem, bdforet = bdforet, species_field = "species")
  )
  expect_equal(res_err$r1_status, rep("fallback_fire_exp_failed", 3))
  expect_true(all(grepl("fireexposuR failed: boom", res_err$r1_fallback_reason)))
})

test_that("indicateur_r1_feu without DEM says so in r1_status", {
  units <- create_test_units(n_features = 2)
  result <- suppressMessages(indicateur_r1_feu(units, dem = NULL))
  expect_true(all(is.na(result$R1)))
  expect_equal(result$r1_status, rep("skipped_no_dem", 2))
  expect_equal(result$r1_fallback_reason, rep("no DEM", 2))
})

test_that(".fire_exp_hazard_template widens the grid by t_dist within BD Foret", {
  dem <- terra::rast(xmin = 0, xmax = 600, ymin = 0, ymax = 600,
                     resolution = 30, crs = "EPSG:2154")
  terra::values(dem) <- 1
  # BD Forêt débordant de 1 km de chaque côté : élargissement plein (t_dist).
  big <- sf::st_sf(geometry = sf::st_sfc(sf::st_polygon(list(matrix(
    c(-1000, -1000, 1600, -1000, 1600, 1600, -1000, 1600, -1000, -1000),
    ncol = 2, byrow = TRUE))), crs = 2154))
  tmpl <- .fire_exp_hazard_template(dem, big, t_dist = 500)
  e <- as.vector(terra::ext(tmpl))
  expect_equal(unname(e), c(-510, 1110, -510, 1110))
  expect_equal(terra::res(tmpl), terra::res(dem))
  # BD Forêt limitée à l'emprise du MNT : pas d'élargissement inventé.
  small <- sf::st_sf(geometry = sf::st_sfc(sf::st_polygon(list(matrix(
    c(100, 100, 500, 100, 500, 500, 100, 500, 100, 100),
    ncol = 2, byrow = TRUE))), crs = 2154))
  expect_equal(as.vector(terra::ext(.fire_exp_hazard_template(dem, small, 500))),
               as.vector(terra::ext(dem)))
})
