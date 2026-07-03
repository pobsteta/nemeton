# test-foret-ancienne-mask.R — build_foret_ancienne_mask() (spec 031)
#
# Source-agnostic helper that builds the `foret_ancienne` polygon layer
# consumed by indicateur_n2_continuite(). In-memory rasters/sf, no network.

# 10x10 grid, 10 m cells, EPSG:2154, extent [0,100] x [0,100].
.fa_grid <- function() {
  terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 100,
              ymin = 0, ymax = 100, crs = "EPSG:2154")
}

.fa_unit <- function(xmin = 0, xmax = 50, ymin = 0, ymax = 100) {
  g <- sf::st_as_sfc(sf::st_bbox(c(xmin = xmin, ymin = ymin,
                                   xmax = xmax, ymax = ymax), crs = 2154))
  sf::st_sf(id = 1L, geometry = g)
}


test_that("raster + forest_class yields an ancient-forest polygon layer", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  # Left half (cols 1-5) = class 1 (forest), right half = class 2.
  r <- .fa_grid()
  v <- rep(2L, 100)
  m <- matrix(v, nrow = 10, byrow = TRUE)
  m[, 1:5] <- 1L
  terra::values(r) <- as.integer(t(m))
  fa <- build_foret_ancienne_mask(r, forest_class = 1L)
  expect_s3_class(fa, "sf")
  expect_true(all(fa$foret_ancienne))
  expect_gt(nrow(fa), 0L)
  # Forest area ~ left half = 50x100 = 5000 m2.
  expect_equal(sum(as.numeric(sf::st_area(fa))), 5000, tolerance = 1)
})

test_that("raster + threshold selects values >= threshold", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  r <- .fa_grid()
  # Continuous "forest probability": top 3 rows high (0.9), rest low (0.1).
  m <- matrix(0.1, nrow = 10, ncol = 10)
  m[1:3, ] <- 0.9
  terra::values(r) <- as.numeric(t(m))
  fa <- build_foret_ancienne_mask(r, threshold = 0.5)
  # 3 rows of 10 cells x 100 m2 = 3000 m2.
  expect_equal(sum(as.numeric(sf::st_area(fa))), 3000, tolerance = 1)
})

test_that("vector source is validated and returned with the marker column", {
  skip_if_not_installed("sf")
  poly <- sf::st_as_sfc(sf::st_bbox(c(xmin = 0, ymin = 0,
                                      xmax = 30, ymax = 30), crs = 2154))
  fa <- build_foret_ancienne_mask(sf::st_sf(geometry = poly))
  expect_s3_class(fa, "sf")
  expect_identical(names(fa)[1], "foret_ancienne")
  expect_true(all(fa$foret_ancienne))
  expect_equal(as.numeric(sf::st_area(fa)), 900, tolerance = 1)
})

test_that("min_area_m2 drops small patches", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  r <- .fa_grid()
  # One big block (rows 1-5, cols 1-5 = 50x50 = 2500 m2) + a 1-cell speckle.
  m <- matrix(NA_integer_, nrow = 10, ncol = 10)
  m[1:5, 1:5] <- 1L
  m[10, 10]  <- 1L          # isolated 10x10 = 100 m2 patch
  terra::values(r) <- as.integer(t(m))
  fa <- build_foret_ancienne_mask(r, forest_class = 1L, min_area_m2 = 200)
  # The 100 m2 speckle is dropped, the 2500 m2 block kept.
  expect_true(all(as.numeric(sf::st_area(fa)) >= 200))
  expect_equal(sum(as.numeric(sf::st_area(fa))), 2500, tolerance = 1)
})

test_that("output feeds indicateur_n2_continuite (ancient forest -> high score)", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  r <- .fa_grid()
  terra::values(r) <- rep(1L, 100)             # whole grid = forest
  fa <- build_foret_ancienne_mask(r, forest_class = 1L)
  unit <- .fa_unit()                            # unit inside the grid
  res <- indicateur_n2_continuite(unit, foret_ancienne = fa)
  # N2: taux_ancienne = 1 -> score 60 + 1*40 = 100.
  expect_equal(res$N2[[1]], 100, tolerance = 1e-6)
})

test_that("unsupported source type errors", {
  expect_error(build_foret_ancienne_mask(42), "sf/sfc.*SpatRaster")
})


# --- Consolidation multi-époques (paliers d'ancienneté, spec 031) ---

.fa_box <- function(xmin, ymin, xmax, ymax) {
  sf::st_sf(geometry = sf::st_as_sfc(sf::st_bbox(
    c(xmin = xmin, ymin = ymin, xmax = xmax, ymax = ymax), crs = 2154)))
}

test_that("a named list of epochs builds a tiered ancienneté layer", {
  skip_if_not_installed("sf")
  cassini <- .fa_box(0, 0, 60, 60)      # forêt ~1750
  etatmaj <- .fa_box(40, 40, 100, 100)  # forêt ~1850, recouvre partiellement
  fa <- build_foret_ancienne_mask(list(cassini = cassini, etatmajor = etatmaj))
  expect_s3_class(fa, "sf")
  expect_true(all(c("foret_ancienne", "anciennete", "epoques") %in% names(fa)))
  expect_setequal(unique(fa$anciennete), c(1L, 2L))
  # Non-recouvrant : somme des aires = aire de l'union.
  tot <- sum(as.numeric(sf::st_area(fa)))
  uni <- as.numeric(sf::st_area(sf::st_union(rbind(cassini, etatmaj))))
  expect_equal(tot, uni, tolerance = 1)
  # Le palier 2 = intersection (20x20 = 400 m²) ; libellé "cassini+etatmajor".
  t2 <- fa[fa$anciennete == 2L, ]
  expect_equal(sum(as.numeric(sf::st_area(t2))), 400, tolerance = 1)
  expect_true(grepl("cassini", t2$epoques[[1]]) && grepl("etatmajor", t2$epoques[[1]]))
})

test_that("a single-element list yields anciennete = 1 everywhere", {
  skip_if_not_installed("sf")
  fa <- build_foret_ancienne_mask(list(etatmajor = .fa_box(0, 0, 50, 50)))
  expect_true(all(fa$anciennete == 1L))
})

test_that("N2 weights ancient-forest coverage by tier depth", {
  skip_if_not_installed("sf")
  cassini <- .fa_box(0, 0, 60, 60)
  etatmaj <- .fa_box(40, 40, 100, 100)
  fa <- build_foret_ancienne_mask(list(cassini = cassini, etatmajor = etatmaj))

  # Unité entièrement dans le palier 2 (intersection 40..60 x 40..60) -> taux 1.
  u_old <- .fa_unit(40, 60, 40, 60)
  expect_equal(indicateur_n2_continuite(u_old, foret_ancienne = fa)$N2[[1]],
               100, tolerance = 1e-6)

  # Unité entièrement en palier 1 seul (0..40 x 0..40, Cassini uniquement) ->
  # pondérée 1/2 -> taux 0.5 -> score 60 + 0.5*40 = 80.
  u_mid <- .fa_unit(0, 40, 0, 40)
  expect_equal(indicateur_n2_continuite(u_mid, foret_ancienne = fa)$N2[[1]],
               80, tolerance = 1e-6)

  # weight_anciennete = FALSE -> couverture binaire -> palier 1 compte plein -> 100.
  expect_equal(
    indicateur_n2_continuite(u_mid, foret_ancienne = fa,
                             weight_anciennete = FALSE)$N2[[1]],
    100, tolerance = 1e-6)
})

test_that("N2 stays backward-compatible with a single-epoch layer (no anciennete)", {
  skip_if_not_installed("sf")
  fa <- build_foret_ancienne_mask(.fa_box(0, 0, 100, 100))   # pas de colonne anciennete
  expect_false("anciennete" %in% names(fa))
  u <- .fa_unit(0, 50, 0, 50)
  expect_equal(indicateur_n2_continuite(u, foret_ancienne = fa)$N2[[1]],
               100, tolerance = 1e-6)
})
