# Trois calculs métier rapatriés de nemetonshiny (audit 1.0 de l'app,
# constats n° 64-66 ; brief 2026-10-05-logique-metier-a-rapatrier.md).

skip_if_not_installed("terra")

# ---- n° 64 : composite NDVI de saison ---------------------------------------

# Cache synthétique : une scène par date, B04/B08 constantes. Identifiants
# Planetary Computer traités avant 2022 (pas d'offset L2A).
write_scene <- function(cache, date, b04, b08, na_cell = FALSE) {
  ymd <- format(as.Date(date), "%Y%m%d")
  sid <- sprintf("S2A_MSIL2A_%sT103021_R108_T31TFN_20210101T120000", ymd)
  d <- file.path(cache, sid)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  mk <- function(v) {
    r <- terra::rast(nrows = 3, ncols = 3, xmin = 600000, xmax = 600030,
                     ymin = 5300000, ymax = 5300030, crs = "EPSG:32631")
    terra::values(r) <- v
    if (na_cell) r[5] <- NA
    r
  }
  terra::writeRaster(mk(b04), file.path(d, "B04.tif"), overwrite = TRUE)
  terra::writeRaster(mk(b08), file.path(d, "B08.tif"), overwrite = TRUE)
  sid
}
ndvi_of <- function(b04, b08) (b08 - b04) / (b08 + b04)

test_that("build_ndvi_season_composite takes the per-pixel median, NA-tolerant", {
  cache <- withr::local_tempdir()
  write_scene(cache, "2021-06-10", 300, 3500)
  write_scene(cache, "2021-07-10", 500, 3000, na_cell = TRUE)
  write_scene(cache, "2021-08-10", 400, 4000)
  out <- suppressWarnings(build_ndvi_season_composite(cache))
  expect_s4_class(out, "SpatRaster")
  expect_identical(names(out), "ndvi")
  v <- terra::values(out)[, 1]
  ndvis <- c(ndvi_of(300, 3500), ndvi_of(500, 3000), ndvi_of(400, 4000))
  expect_equal(v[1], stats::median(ndvis), tolerance = 1e-6)
  # Cellule NA dans une scène : médiane des deux autres.
  expect_equal(v[5], stats::median(ndvis[-2]), tolerance = 1e-6)
  expect_equal(nrow(attr(out, "scenes")), 3L)
})

test_that("a single scene passes through and values are clamped to [0, 1]", {
  cache <- withr::local_tempdir()
  # Eau : NDVI négatif, borné à 0.
  write_scene(cache, "2021-07-01", 3000, 1000)
  out <- suppressWarnings(build_ndvi_season_composite(cache))
  expect_equal(unique(terra::values(out)[, 1]), 0)
  out2 <- suppressWarnings(build_ndvi_season_composite(cache, clamp = NULL))
  expect_equal(unique(terra::values(out2)[, 1]), ndvi_of(3000, 1000),
               tolerance = 1e-6)
})

test_that("season window and max_scenes select the scenes like the app did", {
  cache <- withr::local_tempdir()
  write_scene(cache, "2021-01-15", 2000, 2500)        # hiver : écarté
  for (m in 6:9) write_scene(cache, sprintf("2021-%02d-15", m), 300, 3500)
  out <- suppressWarnings(build_ndvi_season_composite(cache, max_scenes = 2))
  sc <- attr(out, "scenes")
  expect_equal(nrow(sc), 2L)
  expect_equal(as.character(sc$obs_date), c("2021-08-15", "2021-09-15"))
  # Aucune scène de saison : toutes les scènes servent.
  cache2 <- withr::local_tempdir()
  write_scene(cache2, "2021-01-15", 300, 3500)
  expect_s4_class(suppressWarnings(build_ndvi_season_composite(cache2)), "SpatRaster")
})

test_that("build_ndvi_season_composite returns NULL on an empty cache", {
  expect_null(build_ndvi_season_composite(withr::local_tempdir()))
  expect_error(build_ndvi_season_composite(withr::local_tempdir(),
                                           season_doy = c(273, 152)))
})

# ---- n° 65 : indices ombrothermiques ----------------------------------------

test_that("a Mediterranean climate has 3 to 4 dry months", {
  # Climat de type Montpellier (normales arrondies).
  rr <- data.frame(month = 1:12,
                   value = c(55, 50, 40, 55, 45, 30, 15, 25, 70, 95, 70, 60))
  tt <- data.frame(month = 1:12,
                   value = c(7, 8, 11, 13, 17, 21, 24, 24, 20, 16, 11, 8))
  res <- climate_ombrothermic_indices(rr, tt)
  expect_true(res$dry_months >= 3 && res$dry_months <= 4)
  expect_true(all(res$dry_idx %in% 6:8))
})

test_that("De Martonne is exact on a fixed set", {
  rr <- data.frame(month = 1:12, value = rep(60, 12))   # 720 mm
  tt <- data.frame(month = 1:12, value = rep(10, 12))   # 10 °C
  res <- climate_ombrothermic_indices(rr, tt)
  expect_equal(res$demartonne, 720 / 20)
  expect_identical(res$dry_months, 0L)
  expect_identical(res$dry_idx, integer(0))
})

test_that("NA months are never dry and an empty join gives NA", {
  rr <- data.frame(month = 1:3, value = c(5, NA, 5))
  tt <- data.frame(month = 1:3, value = c(20, 20, NA))
  res <- climate_ombrothermic_indices(rr, tt)
  expect_identical(res$dry_idx, 1L)
  expect_identical(res$dry_months, 1L)
  empty <- climate_ombrothermic_indices(data.frame(month = 1, value = 1),
                                        data.frame(month = 2, value = 1))
  expect_true(is.na(empty$dry_months))
  expect_true(is.na(empty$demartonne))
  expect_true(is.na(climate_ombrothermic_indices(NULL, tt)$demartonne))
})

# ---- n° 66 : agrégation des familles ----------------------------------------

test_that("aggregate_family_scores weights by area by default", {
  u <- data.frame(famille_carbone = c(80, 20), famille_eau = c(10, 90),
                  surface_m2 = c(450000, 5000))
  res <- aggregate_family_scores(u)
  expect_equal(as.numeric(res["famille_carbone"]),
               (80 * 450000 + 20 * 5000) / 455000)
  expect_identical(attr(res, "weighting"), "surface")
  plain <- aggregate_family_scores(u, weights = "none")
  expect_equal(as.numeric(plain), c(50, 50))
  expect_identical(attr(plain, "weighting"), "none")
})

test_that("NA scores are left out and weights renormalised per family", {
  u <- data.frame(famille_carbone = c(80, NA, 20),
                  surface_m2 = c(1, 100, 3))
  res <- aggregate_family_scores(u)
  expect_equal(as.numeric(res), (80 * 1 + 20 * 3) / 4)
  u$famille_carbone <- NA_real_
  expect_true(is.na(aggregate_family_scores(u)))
})

test_that("without a usable area the simple mean is used, with a warning", {
  u <- data.frame(famille_carbone = c(80, 20), surface_m2 = c(10, NA))
  expect_warning(res <- aggregate_family_scores(u), "simple mean")
  expect_equal(as.numeric(res), 50)
  expect_identical(attr(res, "weighting"), "none")
  expect_warning(aggregate_family_scores(data.frame(famille_carbone = 1:2)),
                 "simple mean")
})

test_that("an sf object without the area column is weighted by its geometry", {
  skip_if_not_installed("sf")
  sq <- function(x0, side) sf::st_polygon(list(matrix(
    c(x0, 0, x0 + side, 0, x0 + side, side, x0, side, x0, 0),
    ncol = 2, byrow = TRUE)))
  u <- sf::st_sf(famille_carbone = c(80, 20),
                 geometry = sf::st_sfc(sq(0, 30), sq(100, 10), crs = 2154))
  res <- aggregate_family_scores(u)
  expect_equal(as.numeric(res), (80 * 900 + 20 * 100) / 1000)
  expect_identical(attr(res, "weighting"), "surface")
  expect_identical(aggregate_family_scores(data.frame(x = 1)), numeric(0))
})
