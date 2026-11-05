# Spec 064 : embedding_summary(), distance_reference(), N5. Embeddings
# synthetiques, aucun reseau.

# 20 UGF de 100 x 100 m (10 colonnes x 2 rangees) sur un raster de 10 m :
# chaque UGF couvre exactement 100 pixels.
.emb_units <- function() {
  carres <- lapply(0:19, function(i) {
    x0 <- (i %% 10) * 100
    y0 <- (i %/% 10) * 100
    sf::st_polygon(list(rbind(c(x0, y0), c(x0 + 100, y0), c(x0 + 100, y0 + 100),
                              c(x0, y0 + 100), c(x0, y0))))
  })
  sf::st_sf(id = 1:20, geometry = sf::st_sfc(carres, crs = 2154))
}

# Raster d bandes dont chaque pixel vaut le vecteur `v[ugf, ]` (+ bruit).
.emb_raster <- function(v, bruit = 0, seed = 1) {
  set.seed(seed)
  d <- ncol(v)
  r <- terra::rast(terra::ext(0, 1000, 0, 200), resolution = 10, nlyrs = d,
                   crs = "EPSG:2154")
  xy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
  ugf <- (xy[, 2] %/% 100) * 10 + (xy[, 1] %/% 100) + 1
  vals <- v[ugf, , drop = FALSE]
  if (bruit > 0) vals <- vals + matrix(stats::rnorm(length(vals), 0, bruit), nrow(vals))
  terra::values(r) <- vals
  names(r) <- sprintf("A%02d", seq_len(d) - 1L)
  r
}

# Reference = UGF 1 a 15 (nuage autour de 0) ; UGF 16 a 20 de plus en plus loin.
.emb_vecteurs <- function(d = 4, seed = 2) {
  set.seed(seed)
  v <- matrix(stats::rnorm(20 * d, 0, 0.1), 20, d)
  v[16:20, 1] <- c(0.5, 1, 2, 4, 8)
  v
}

# ── embedding_summary() ─────────────────────────────────────────────────

test_that("embedding_summary returns the per-unit mean, sd and pixel count", {
  skip_if_not_installed("exactextractr")
  v <- .emb_vecteurs()
  r <- .emb_raster(v)
  s <- embedding_summary(.emb_units(), r)

  expect_equal(dim(s$mean), c(20L, 4L))
  expect_equal(unname(s$mean), v, tolerance = 1e-6)
  expect_true(all(abs(s$sd) < 1e-6))
  expect_equal(s$n_pixels, rep(100, 20), tolerance = 1e-6)
  expect_equal(colnames(s$mean), names(r))
  expect_equal(s$meta$dimension, 4L)
})

test_that("embedding_summary leaves NA below min_pixels and outside the raster", {
  skip_if_not_installed("exactextractr")
  r <- .emb_raster(.emb_vecteurs())
  u <- .emb_units()
  dehors <- sf::st_sf(id = 21, geometry = sf::st_sfc(sf::st_polygon(list(rbind(
    c(5000, 5000), c(5100, 5000), c(5100, 5100), c(5000, 5100), c(5000, 5000)
  ))), crs = 2154))
  # moitie dedans, moitie dehors : 50 pixels
  moitie <- sf::st_sf(id = 22, geometry = sf::st_sfc(sf::st_polygon(list(rbind(
    c(950, 0), c(1050, 0), c(1050, 100), c(950, 100), c(950, 0)
  ))), crs = 2154))
  s <- embedding_summary(rbind(u, dehors, moitie), r, min_pixels = 60)
  expect_true(all(is.na(s$mean[21, ])))
  expect_equal(s$n_pixels[21], 0)
  expect_equal(s$n_pixels[22], 50, tolerance = 1e-6)
  expect_true(all(is.na(s$mean[22, ])))
  expect_false(anyNA(s$mean[1:20, ]))
})

test_that("embedding_summary rejects non-sf units and non-raster layers", {
  expect_error(embedding_summary(data.frame(x = 1), terra::rast()), "sf")
  expect_error(embedding_summary(.emb_units(), matrix(1)), "SpatRaster")
})

# ── distance_reference() ────────────────────────────────────────────────

test_that("distance_reference recovers a known Mahalanobis distance", {
  set.seed(3)
  ref <- cbind(stats::rnorm(4000, 0, 1), stats::rnorm(4000, 0, 2))
  d <- distance_reference(rbind(c(2, 0), c(0, 4), c(0, 0)), ref)
  expect_equal(d$distance, c(2, 2, 0), tolerance = 0.06)
  expect_lt(d$shrinkage, 0.05)
  expect_length(d$distance_loo, 4000)
  expect_equal(d$n_reference, 4000L)
})

test_that("distance_reference euclidean is the plain distance to the centroid", {
  ref <- rbind(c(-1, 0), c(1, 0), c(0, 1), c(0, -1))
  d <- distance_reference(rbind(c(3, 4)), ref, method = "euclidean")
  expect_equal(d$distance, 5)
  expect_true(is.na(d$shrinkage))
})

test_that("Ledoit-Wolf keeps 15 references in 64 dimensions invertible", {
  set.seed(4)
  ref <- matrix(stats::rnorm(15 * 64), 15, 64)
  x <- rbind(rep(0, 64), rep(3, 64))
  d <- distance_reference(x, ref)
  expect_true(all(is.finite(d$distance)))
  expect_gt(d$shrinkage, 0)
  expect_lte(d$shrinkage, 1)
  expect_lt(d$distance[1], d$distance[2])
  expect_true(all(is.finite(d$distance_loo)))
})

test_that("a reference without spread falls back on the identity", {
  ref <- matrix(1, 5, 3)
  d <- distance_reference(rbind(c(1, 1, 1)), ref)
  expect_equal(d$shrinkage, 1)
  expect_equal(d$distance, 0)
})

test_that("distance_reference checks its inputs", {
  expect_error(distance_reference(matrix(0, 1, 2), matrix(0, 5, 3)), "same number")
  expect_error(distance_reference(matrix(0, 1, 2), matrix(0, 2, 2)), "At least 3")
  # lignes non finies de la reference ecartees, ligne NA de x rendue NA
  ref <- rbind(diag(2), -diag(2), c(NA, 1))
  d <- distance_reference(rbind(c(0, 0), c(NA, 0)), ref, method = "euclidean")
  expect_equal(d$n_reference, 4L)
  expect_true(is.na(d$distance[2]))
})

# ── N5 ──────────────────────────────────────────────────────────────────

test_that("N5 without embedding is NA with status skipped_no_embedding", {
  res <- suppressMessages(indicateur_n5_distance_reference(.emb_units()))
  expect_true(all(is.na(res$N5)))
  expect_true(all(res$n5_status == "skipped_no_embedding"))
  expect_s3_class(res, "sf")
  expect_equal(nrow(res), 20L)
})

test_that("N5 with the default reference needs foret_ancienne and N1", {
  skip_if_not_installed("exactextractr")
  r <- .emb_raster(.emb_vecteurs())
  res <- suppressMessages(indicateur_n5_distance_reference(.emb_units(), r))
  expect_true(all(is.na(res$N5)))
  expect_true(all(res$n5_status == "skipped_no_reference"))
  expect_true(all(res$n5_reference == "defaut"))
})

test_that("N5 scores against a user reference: far units score low", {
  skip_if_not_installed("exactextractr")
  u <- .emb_units()
  r <- .emb_raster(.emb_vecteurs(), bruit = 0.01)
  res <- suppressMessages(
    indicateur_n5_distance_reference(u, r, reference = u[1:15, ])
  )
  expect_true(all(res$n5_status == "calculated"))
  expect_true(all(res$n5_reference == "utilisateur"))
  expect_true(all(res$n5_source == "aef"))
  expect_true(all(res$N5 >= 0 & res$N5 <= 100))
  # 16 a 20 s'eloignent : N5 decroit, et les plus lointaines valent 0
  expect_true(all(diff(res$N5[16:20]) <= 0))
  expect_equal(res$N5[19:20], c(0, 0))
  expect_true(all(diff(res$n5_distance[16:20]) > 0))
})

test_that("N5 projet score spreads the project from 100 (closest) to 0", {
  skip_if_not_installed("exactextractr")
  u <- .emb_units()
  r <- .emb_raster(.emb_vecteurs(), bruit = 0.01)
  res <- suppressMessages(
    indicateur_n5_distance_reference(u, r, reference = u[1:15, ], score = "projet")
  )
  expect_equal(max(res$N5), 100)
  expect_equal(res$N5[20], 0)
})

test_that("N5 refuses a reference below min_reference", {
  skip_if_not_installed("exactextractr")
  u <- .emb_units()
  r <- .emb_raster(.emb_vecteurs(), bruit = 0.01)
  trop_peu <- suppressMessages(indicateur_n5_distance_reference(u, r, reference = u[1:14, ]))
  expect_true(all(trop_peu$n5_status == "skipped_reference_too_small"))
  expect_true(all(is.na(trop_peu$N5)))
  assez <- suppressMessages(indicateur_n5_distance_reference(u, r, reference = u[1:15, ]))
  expect_true(all(assez$n5_status == "calculated"))
})

test_that("N5 default reference = top ancient-forest tier and N1 >= n1_min", {
  skip_if_not_installed("exactextractr")
  u <- .emb_units()
  u$N1 <- c(rep(90, 15), rep(50, 5))
  r <- .emb_raster(.emb_vecteurs(), bruit = 0.01)
  # palier 2 sur la rangee du bas (UGF 1-10) et sur UGF 11-15 ; palier 1 partout
  fa <- sf::st_sf(
    anciennete = c(2L, 2L, 1L),
    geometry = sf::st_sfc(
      sf::st_polygon(list(rbind(c(0, 0), c(1000, 0), c(1000, 100), c(0, 100), c(0, 0)))),
      sf::st_polygon(list(rbind(c(0, 100), c(500, 100), c(500, 200), c(0, 200), c(0, 100)))),
      sf::st_polygon(list(rbind(c(0, 0), c(1000, 0), c(1000, 200), c(0, 200), c(0, 0)))),
      crs = 2154
    )
  )
  dans <- nemeton:::.n5_reference_defaut(u, fa, n1_min = 80, couverture_min = 0.5)
  expect_equal(which(dans), 1:15)

  res <- suppressMessages(indicateur_n5_distance_reference(u, r, foret_ancienne = fa))
  expect_true(all(res$n5_status == "calculated"))
  expect_true(all(res$n5_reference == "defaut"))
  expect_equal(res$N5[19:20], c(0, 0))

  # N1 sous le seuil : la reference fond sous 15
  u$N1[1] <- 70
  res2 <- suppressMessages(indicateur_n5_distance_reference(u, r, foret_ancienne = fa))
  expect_true(all(res2$n5_status == "skipped_reference_too_small"))
})

test_that("N5 resolves the embedding and foret_ancienne from layers", {
  skip_if_not_installed("exactextractr")
  u <- .emb_units()
  u$N1 <- 90
  r <- .emb_raster(.emb_vecteurs(), bruit = 0.01)
  withr::with_tempdir({
    terra::writeRaster(r, "aef.tif")
    fa <- sf::st_sf(geometry = sf::st_as_sfc(sf::st_bbox(u)))
    sf::st_write(fa, "fa.gpkg", quiet = TRUE)
    layers <- nemeton_layers(rasters = list(aef_embedding = "aef.tif"),
                             vectors = list(foret_ancienne = "fa.gpkg"))
    res <- suppressMessages(indicateur_n5_distance_reference(u, layers = layers))
  })
  # toutes les UGF sont dans la reference : chacune notee sur sa distance LOO
  expect_true(all(res$n5_status == "calculated"))
  expect_false(anyNA(res$N5))
})

test_that("N5 picks the most recent year of a list, or the one asked", {
  skip_if_not_installed("exactextractr")
  u <- .emb_units()
  emb <- list("2023" = .emb_raster(.emb_vecteurs(seed = 5), bruit = 0.01),
              "2024" = .emb_raster(.emb_vecteurs(seed = 6), bruit = 0.01))
  res <- suppressMessages(indicateur_n5_distance_reference(u, emb, reference = u[1:15, ]))
  expect_true(all(res$n5_annee == 2024L))
  res23 <- suppressMessages(
    indicateur_n5_distance_reference(u, emb, reference = u[1:15, ], annee = 2023)
  )
  expect_true(all(res23$n5_annee == 2023L))
  expect_error(
    suppressMessages(indicateur_n5_distance_reference(u, emb, reference = u[1:15, ], annee = 2020)),
    "not in"
  )
})

test_that("N5 marks a unit outside the embedding as skipped_no_coverage", {
  skip_if_not_installed("exactextractr")
  u <- .emb_units()
  dehors <- sf::st_sf(id = 21, geometry = sf::st_sfc(sf::st_polygon(list(rbind(
    c(5000, 5000), c(5100, 5000), c(5100, 5100), c(5000, 5100), c(5000, 5000)
  ))), crs = 2154))
  r <- .emb_raster(.emb_vecteurs(), bruit = 0.01)
  res <- suppressMessages(
    indicateur_n5_distance_reference(rbind(u, dehors), r, reference = u[1:15, ])
  )
  expect_equal(res$n5_status[21], "skipped_no_coverage")
  expect_true(is.na(res$N5[21]))
  expect_true(all(res$n5_status[1:20] == "calculated"))
})

test_that("N5 is registered as a conditional N indicator, native 0-100", {
  lab <- indicator_labels()
  expect_true("N5" %in% lab$code)
  expect_equal(lab$family[lab$code == "N5"], "N")
  det <- list_indicators(return_type = "details")
  expect_true(det$conditionnel[det$code == "N5"])
  expect_equal(det$source_conditionnelle[det$code == "N5"], "embedding")
  expect_equal(as.numeric(normalize_indicator("N5", c(0, 42, 100))), c(0, 42, 100))
})

test_that("detect_ndp flags embedding_ml without changing the level", {
  df <- data.frame(x = 1)
  attr(df, "embedding_source") <- "aef"
  r <- detect_ndp(df)
  expect_equal(r$level, 0L)
  expect_true("embedding_ml" %in% r$augmented)
  expect_true("aef_embedding" %in% r$sources)
  expect_false("embedding_ml" %in% detect_ndp(data.frame(x = 1))$augmented)
})
