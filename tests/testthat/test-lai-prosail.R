# test-lai-prosail.R — repli LAI Sentinel-2/PROSAIL (spec 033)
#
# L'inversion réelle (train/apply PROSAIL + scènes S2) n'est pas jouée en CI :
# on teste le chemin `precomputed` pur (réduction temporelle), la SRF, la
# dégradation, le flag NDP et l'injection `pai` dans regen_sensibilite.

.lai_stack <- function(vals) {
  # une couche par date, valeur constante par couche (moyenne = la valeur).
  r <- terra::rast(nrows = 4, ncols = 4, xmin = 0, xmax = 4, ymin = 0, ymax = 4,
                   nlyrs = length(vals), crs = "EPSG:2154")
  for (i in seq_along(vals)) terra::values(r[[i]]) <- rep(vals[i], terra::ncell(r))
  r
}

test_that("precomputed single-layer LAI passes through as `lai`", {
  skip_if_not_installed("terra")
  r <- .lai_stack(3.2)
  out <- lai_sentinel2(precomputed = r)
  expect_true(inherits(out, "SpatRaster"))
  expect_identical(names(out), "lai")
  expect_equal(terra::nlyr(out), 1L)
})

test_that("temporal reducers collapse a multi-date LAI stack", {
  skip_if_not_installed("terra")
  st <- .lai_stack(c(1, 2, 3, 4, 100))     # p90 ~ 4 ; max = 100 ; median = 3
  p90 <- terra::global(lai_sentinel2(precomputed = st, reducer = "p90"), "mean")[[1]]
  mx  <- terra::global(lai_sentinel2(precomputed = st, reducer = "max"), "mean")[[1]]
  med <- terra::global(lai_sentinel2(precomputed = st, reducer = "median"), "mean")[[1]]
  expect_lt(p90, mx)
  expect_equal(mx, 100)
  expect_equal(med, 3)
})

test_that("an unknown reducer errors", {
  skip_if_not_installed("terra")
  expect_error(lai_sentinel2(precomputed = .lai_stack(c(1, 2)), reducer = "zzz"),
               "reducer")
})

test_that("a non-raster precomputed errors", {
  expect_error(lai_sentinel2(precomputed = 42), "SpatRaster")
})

test_that("engine degrades to NULL with no scene (no train)", {
  skip_if_not_installed("terra")
  skip_if_not_installed("prosail")
  # Ni refl ni aoi -> abort interne 'Provide refl' -> tryCatch -> NULL, sans
  # déclencher l'entraînement (coûteux).
  expect_warning(res <- lai_sentinel2(), "returning NULL")
  expect_null(res)
})

test_that("prosail S2 SRF carries the required $sensor field", {
  skip_if_not_installed("prosail")
  srf <- .lai_s2_srf("Sentinel_2A")
  expect_true(is.list(srf))
  expect_identical(srf$sensor, "Sentinel_2A")
  expect_true(all(c("spectral_response", "spectral_bands") %in% names(srf)))
})

test_that("detect_ndp flags lai_ml for a PROSAIL S2 LAI source", {
  df <- data.frame(x = 1)
  attr(df, "lai_source") <- "prosail_s2"
  expect_true("lai_ml" %in% detect_ndp(df)$augmented)
  # Base NDP unchanged (flag is separate).
  expect_false("lai_ml" %in% detect_ndp(data.frame(x = 1))$augmented)
})

test_that("prosail band names map to the nemeton S2 pipeline names", {
  expect_identical(.lai_band_to_nemeton("B4"), "B04")
  expect_identical(.lai_band_to_nemeton("B5"), "B05")
  expect_identical(.lai_band_to_nemeton("B8"), "B08")
  expect_identical(.lai_band_to_nemeton("B8A"), "B8A")   # suffixe conservé
  expect_identical(.lai_band_to_nemeton("B11"), "B11")   # 2 chiffres inchangé
  expect_identical(.lai_band_to_nemeton("B12"), "B12")
})

test_that("the shipped pre-trained LAI model loads and predicts (spec 033 D3)", {
  skip_if_not_installed("prosail")
  f <- system.file("extdata", "prosail_lai_Sentinel_2A_B4-B5-B8.rds",
                   package = "nemeton")
  expect_true(nzchar(f) && file.exists(f))
  model <- readRDS(f)
  expect_true("lai" %in% names(model))
  # Prédiction sur 3 bandes (B4,B5,B8) x quelques pixels -> LAI finis.
  refl <- matrix(stats::runif(3 * 8, 0.02, 0.4), nrow = 3)
  pred <- prosail::prosail_hybrid_apply(model$lai, refl)
  vals <- suppressWarnings(as.numeric(unlist(pred)))
  expect_true(any(is.finite(vals)))
})

test_that("regen_sensibilite accepts a `pai` fallback (no LiDAR required)", {
  skip_if_not_installed("terra")
  # Sans microclimf -> abort paquet ; avec microclimf mais sans mnt/mnh -> abort
  # entrées. Dans les deux cas, fournir `pai` sans `las` NE doit PAS réclamer las.
  u <- sf::st_sf(id = 1, geometry = sf::st_sfc(
    sf::st_polygon(list(rbind(c(0, 0), c(5, 0), c(5, 5), c(0, 5), c(0, 0)))),
    crs = 2154))
  lai <- .lai_stack(3)[[1]]
  err <- tryCatch(
    regen_sensibilite(u, mnt = "x", mnh = "y", pai = lai,
                      annees_moy = 2014, annees_canic = 2018),
    error = function(e) conditionMessage(e))
  # L'erreur ne doit PAS être « needs ... las » manquant : `pai` couvre le besoin.
  expect_false(grepl("either .*las.* or .*pai", err) &&
                 grepl("engine path needs", err))
})

test_that(".lai_s2_reflectance_muscate assemble + rééchantillonne les bandes (contrat corrigé)", {
  skip_if_not_installed("terra")
  # Fausse scène MUSCATE (colonnes href_* comme la vraie recherche STAC).
  scene <- data.frame(
    scene_id = "FAKE_MUSCATE_T31TFK", cloud_pct = 3,
    href_B04 = "/vsis3/x/B4.tif", href_B05 = "/vsis3/x/B5.tif",
    href_B08 = "/vsis3/x/B8.tif", source = "muscate",
    stringsAsFactors = FALSE)
  mk <- function(res, v) {
    r <- terra::rast(xmin = 0, xmax = 100, ymin = 0, ymax = 100,
                     resolution = res, crs = "EPSG:2154")
    terra::values(r) <- v; r
  }
  # B04/B08 à 10 m, B05 à 20 m -> résolutions différentes (cas réel MUSCATE).
  band_r <- list(B04 = mk(10, 0.1), B05 = mk(20, 0.2), B08 = mk(10, 0.5))
  testthat::local_mocked_bindings(
    stac_search_s2      = function(...) scene,
    theia_configure_s3  = function(...) invisible(TRUE),
    .get_s2_band_raster = function(scene, band, ...) band_r[[band]])
  aoi <- sf::st_as_sf(sf::st_sfc(sf::st_polygon(list(rbind(
    c(5.45, 45.05), c(5.50, 45.05), c(5.50, 45.09),
    c(5.45, 45.09), c(5.45, 45.05)))), crs = 4326))
  cache <- withr::local_tempdir()
  out <- .lai_s2_reflectance_muscate(
    aoi, "2022-07-01", "2022-07-31",
    selected_bands = c("B4", "B5", "B8"), max_cloud = 40, cache_dir = cache)
  expect_length(out, 1L)
  st <- terra::rast(out[[1]])
  expect_identical(names(st), c("B4", "B5", "B8"))   # 3 bandes empilées
  expect_equal(terra::res(st), c(10, 10))            # aligné sur B04 (10 m)
})

test_that(".lai_s2_reflectance_muscate dégrade en NULL sans identifiants THEIA S3", {
  skip_if_not_installed("terra")
  scene <- data.frame(scene_id = "FAKE", cloud_pct = 3,
                      href_B04 = "/vsis3/x/B4.tif", source = "muscate",
                      stringsAsFactors = FALSE)
  testthat::local_mocked_bindings(
    stac_search_s2     = function(...) scene,
    theia_configure_s3 = function(...) stop("THEIA S3 credentials not found."))
  aoi <- sf::st_as_sf(sf::st_sfc(sf::st_polygon(list(rbind(
    c(5.45, 45.05), c(5.50, 45.05), c(5.50, 45.09),
    c(5.45, 45.09), c(5.45, 45.05)))), crs = 4326))
  expect_warning(
    res <- .lai_s2_reflectance_muscate(
      aoi, "2022-07-01", "2022-07-31",
      selected_bands = c("B4"), max_cloud = 40,
      cache_dir = withr::local_tempdir()),
    "THEIA S3 credentials")
  expect_null(res)
})
