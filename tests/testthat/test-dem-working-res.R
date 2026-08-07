# Garde-fou de résolution du MNT de travail (.dem_working_res).
#
# Contexte : le 2026-08-06, le calcul des indicateurs du projet Dabo (NDP 1,
# MNT LiDAR HD 12000 x 10000 à 0,5 m) a fait monter la session R à 21,2 Go et
# systemd-oomd a tué le scope RStudio pendant R2 ; le 2026-08-07 R3 est mort de
# la même façon. Les indicateurs dérivés du terrain ramènent désormais le MNT à
# une résolution de travail commune avant tout calcul, TWI compris.

skip_if_not_installed("terra")

make_dem <- function(res, crs = "EPSG:2154", nrow = 100, ncol = 100) {
  r <- terra::rast(
    nrows = nrow, ncols = ncol,
    xmin = 0, xmax = ncol * res, ymin = 0, ymax = nrow * res,
    crs = crs
  )
  terra::values(r) <- seq_len(terra::ncell(r))
  r
}

test_that(".dem_working_res aggregates a fine DEM to the target resolution", {
  dem <- make_dem(res = 1)
  out <- .dem_working_res(dem, target_res = 10)

  expect_equal(terra::res(out)[1], 10)
  # 100 x 100 cellules à 1 m -> 10 x 10 à 10 m : 100x moins de mémoire.
  expect_equal(terra::ncell(out), 100)
  # L'emprise est conservée : les extractions par unité restent comparables.
  expect_equal(as.vector(terra::ext(out)), as.vector(terra::ext(dem)))
})

test_that(".dem_working_res never upsamples a DEM already coarser than target", {
  dem <- make_dem(res = 25)
  out <- .dem_working_res(dem, target_res = 10)

  expect_equal(terra::res(out)[1], 25)
  expect_equal(terra::ncell(out), terra::ncell(dem))
})

test_that(".dem_working_res is a no-op below a factor of 2", {
  # 6 m vers 10 m -> facteur 1 : agréger dégraderait sans gain notable.
  dem <- make_dem(res = 6)
  expect_equal(terra::res(.dem_working_res(dem, target_res = 10))[1], 6)
})

test_that(".dem_working_res leaves lon/lat DEMs alone (degrees, not metres)", {
  dem <- make_dem(res = 0.001, crs = "EPSG:4326")
  out <- .dem_working_res(dem, target_res = 10)

  expect_true(terra::is.lonlat(out))
  expect_equal(terra::res(out)[1], terra::res(dem)[1])
})

test_that(".dem_working_res opts out on NULL / invalid target_res", {
  dem <- make_dem(res = 1)
  for (tr in list(NULL, NA_real_, 0, -5)) {
    expect_equal(terra::res(.dem_working_res(dem, target_res = tr))[1], 1)
  }
})

test_that(".dem_working_res passes non-raster inputs through untouched", {
  expect_null(.dem_working_res(NULL))
  expect_identical(.dem_working_res("not a raster"), "not a raster")
})

test_that(".dem_working_res announces the aggregation only when given a context", {
  dem <- make_dem(res = 1)
  expect_message(.dem_working_res(dem, target_res = 10, context = "R2"), "R2")
  expect_silent(.dem_working_res(dem, target_res = 10))
})

test_that(".twi_aggregate_dem keeps its historical behaviour via the shared helper", {
  dem <- make_dem(res = 1)
  expect_equal(terra::res(.twi_aggregate_dem(dem))[1], .topo_target_res())
  expect_equal(terra::res(.twi_aggregate_dem(dem, target_res = 5))[1], 5)
  expect_equal(terra::res(.twi_aggregate_dem(make_dem(res = 25)))[1], 25)
})

test_that("terrain indicators share one settable working resolution", {
  targets <- c(
    "indicateur_r1_feu", "indicateur_r2_tempete", "indicateur_r3_secheresse",
    "indicateur_w2_zones_humides", "indicateur_w3_humidite",
    "indicateur_f2_erosion", "indicateur_s1_routes", "indicateur_s2_bati"
  )
  for (fn in targets) {
    fmls <- formals(get(fn, envir = asNamespace("nemeton")))
    expect_true("dem_target_res" %in% names(fmls), info = fn)
    # Le défaut est l'appel au réglage paquet, pas une constante recopiée huit
    # fois : une seule valeur à changer, et l'app peut l'ajuster sans release.
    expect_identical(fmls$dem_target_res, quote(.topo_target_res()), info = fn)
  }
})

# --------------------------------------------------------------------------
# Réglage paquet (.topo_target_res)
# --------------------------------------------------------------------------

test_that(".topo_target_res defaults to 2 m and reads option then environment", {
  withr::local_options(nemeton.topo_target_res = NULL)
  withr::local_envvar(NEMETON_TOPO_TARGET_RES = NA)
  expect_equal(.topo_target_res(), 2)

  withr::local_envvar(NEMETON_TOPO_TARGET_RES = "5")
  expect_equal(.topo_target_res(), 5)

  # L'option prime sur l'environnement.
  withr::local_options(nemeton.topo_target_res = 4)
  expect_equal(.topo_target_res(), 4)
})

test_that(".topo_target_res falls back to the default on an unreadable setting", {
  # Un réglage illisible ne doit pas désactiver le garde-fou en silence :
  # pour la résolution native on passe dem_target_res = NULL explicitement.
  withr::local_envvar(NEMETON_TOPO_TARGET_RES = NA)
  for (v in list("dix", NA, -1, 0)) {
    withr::local_options(nemeton.topo_target_res = v)
    expect_equal(.topo_target_res(), 2, info = format(v))
  }
})

test_that("the package setting drives the indicators' working grid", {
  withr::local_options(nemeton.topo_target_res = 5)
  expect_equal(terra::res(.dem_working_res(make_dem(res = 1)))[1], 5)
  expect_equal(formals(indicateur_r3_secheresse)$dem_target_res |> eval(), 5)
})

# --------------------------------------------------------------------------
# Résolution effective (clé de cache TWI)
# --------------------------------------------------------------------------

test_that(".dem_working_res_value predicts the working grid without building it", {
  fine <- make_dem(res = 1)
  expect_equal(.dem_working_res_value(fine, 2), 2)
  expect_equal(.dem_working_res_value(fine, 2), terra::res(.dem_working_res(fine, 2))[1])

  # Sur un BD ALTI 25 m, toute cible plus fine est un no-op : 2 m et 10 m
  # aboutissent à la même grille, donc à la même entrée de cache TWI.
  coarse <- make_dem(res = 25)
  expect_equal(.dem_working_res_value(coarse, 2), 25)
  expect_equal(.dem_working_res_value(coarse, 10), 25)
  expect_equal(.dem_working_res_value(coarse, NULL), 25)
  expect_true(is.na(.dem_working_res_value(NULL, 2)))
})

test_that("R2 bounds its working grid before deriving terrain layers", {
  # Le chemin réel : un MNT fin passe par le garde-fou, l'indicateur reste
  # calculable et les valeurs restent dans [0, 100].
  units <- sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(10, 40, 40, 10, 10), c(10, 10, 40, 40, 10)))),
      sf::st_polygon(list(cbind(c(50, 90, 90, 50, 50), c(50, 50, 90, 90, 50)))),
      crs = 2154
    )
  )
  dem <- make_dem(res = 1)
  terra::values(dem) <- as.numeric(terra::init(dem, "y")[] / 10)

  res <- indicateur_r2_tempete(units, dem = dem, dem_target_res = 10)
  expect_true("R2" %in% names(res))
  expect_true(all(is.na(res$R2) | (res$R2 >= 0 & res$R2 <= 100)))
})

# --------------------------------------------------------------------------
# Alignement des grilles terrain / TWI
#
# Le point de fond du hand-off app du 2026-08-07 : plafonner le terrain sans
# propager la résolution au TWI laisse en place un `resample` d'un TWI grossier
# vers la grille fine — coûteux, et sans aucune information ajoutée.
# --------------------------------------------------------------------------

clear_twi_cache <- function() {
  rm(list = ls(envir = .twi_cache, all.names = TRUE), envir = .twi_cache)
}

test_that("the TWI lands on the terrain grid when twi_target_res follows it", {
  clear_twi_cache()
  cache <- withr::local_tempdir()
  dem <- make_dem(res = 0.5)

  work <- .dem_working_res(dem, target_res = 2)
  aspect <- terra::terrain(work, v = "aspect", unit = "degrees")
  twi <- get_or_compute_twi(work, cache_dir = cache, twi_target_res = 2)

  expect_true(terra::compareGeom(twi, aspect, stopOnError = FALSE))
})

test_that("a TWI left at the old fixed 10 m would NOT match the terrain grid", {
  # Rend le test précédent non-vacant : sans la propagation, les deux grilles
  # divergent et R3 rééchantillonne le TWI vers du plus fin.
  clear_twi_cache()
  cache <- withr::local_tempdir()
  work <- .dem_working_res(make_dem(res = 0.5), target_res = 2)
  aspect <- terra::terrain(work, v = "aspect", unit = "degrees")

  twi_10 <- get_or_compute_twi(work, cache_dir = cache, twi_target_res = 10)

  expect_false(terra::compareGeom(twi_10, aspect, stopOnError = FALSE))
})

test_that("R3 computes without ever resampling the TWI", {
  clear_twi_cache()
  cache <- withr::local_tempdir()
  units <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(5, 40, 40, 5, 5), c(5, 5, 40, 40, 5)))),
      crs = 2154
    )
  )
  dem <- make_dem(res = 0.5)
  terra::values(dem) <- as.numeric(terra::init(dem, "y")[]) / 10

  # Le moyen le plus direct de rendre le test non-vacant : toute entrée dans la
  # branche `resample` fait échouer le calcul.
  local_mocked_bindings(
    resample = function(...) stop("TWI resampled onto the fine grid"),
    .package = "terra"
  )

  res <- indicateur_r3_secheresse(units, dem = dem,
                                  layers = list(cache_dir = cache),
                                  dem_target_res = 2)

  expect_true("R3" %in% names(res))
  expect_true(is.na(res$R3) || (res$R3 >= 0 && res$R3 <= 100))
})

test_that("W3 and R3 share one TWI cache entry on a coarse DEM", {
  # Sur un BD ALTI 25 m, toute cible plus fine est un no-op : deux indicateurs
  # réglés différemment doivent retomber sur le même fichier, pas recalculer.
  clear_twi_cache()
  cache <- withr::local_tempdir()
  dem <- make_dem(res = 25)

  get_or_compute_twi(dem, cache_dir = cache, twi_target_res = 2)
  clear_twi_cache()  # force le passage par le cache fichier
  get_or_compute_twi(dem, cache_dir = cache, twi_target_res = 10)

  expect_length(list.files(cache, pattern = "^twi_.*\\.tif$"), 1)
})
