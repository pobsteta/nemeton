# Spec 066 : probe_indicator(). UGF de 100 m sur une grille de 2 x 2 km
# (400 UGF), embedding synthetique de 6 bandes constant par UGF.

.probe_cas <- function(n_cote = 20, seed = 11) {
  set.seed(seed)
  cote <- 100
  carres <- lapply(seq_len(n_cote^2) - 1L, function(i) {
    x0 <- (i %% n_cote) * cote
    y0 <- (i %/% n_cote) * cote
    sf::st_polygon(list(rbind(c(x0, y0), c(x0 + cote, y0), c(x0 + cote, y0 + cote),
                              c(x0, y0 + cote), c(x0, y0))))
  })
  u <- sf::st_sf(id = seq_along(carres), geometry = sf::st_sfc(carres, crs = 2154))
  v <- matrix(stats::rnorm(nrow(u) * 6), ncol = 6)
  r <- terra::rast(xmin = 0, xmax = n_cote * cote, ymin = 0, ymax = n_cote * cote,
                   resolution = 10, nlyrs = 6, crs = "EPSG:2154")
  xy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
  ugf <- (xy[, 2] %/% cote) * n_cote + (xy[, 1] %/% cote) + 1
  terra::values(r) <- v[ugf, ]
  names(r) <- sprintf("A%02d", 0:5)
  # N1 lineaire en l'embedding (0-100 natif), N2 aleatoire, N3 constant
  u$N1 <- pmin(100, pmax(0, 50 + 12 * v[, 1] - 8 * v[, 2] + stats::rnorm(nrow(u), 0, 1)))
  u$N2 <- stats::runif(nrow(u), 0, 100)
  u$N3 <- 40
  u$C2 <- u$N1
  list(u = u, r = r)
}

test_that("an indicator built from the embedding is seen, a random one is a blind spot", {
  skip_if_not_installed("exactextractr")
  cas <- .probe_cas()
  p <- suppressMessages(probe_indicator(cas$u, cas$r, indicateurs = c("N1", "N2"),
                                        taille_bloc_m = 500))
  expect_s3_class(p, "data.frame")
  n1 <- p[p$code == "N1", ]
  n2 <- p[p$code == "N2", ]
  expect_gt(n1$r2, 0.8)
  expect_equal(n1$lecture, "voit")
  expect_lt(n2$r2, 0.1)
  expect_equal(n2$lecture, "angle_mort")
  expect_equal(p$code[1], "N1")          # trie par R2 decroissant
  expect_true(all(p$statut == "ok"))
  expect_equal(n1$famille, "N")
  expect_equal(n1$n, 400L)
  expect_equal(unique(p$source_embedding), "aef")
})

test_that("no variance, too few units and missing column have their status", {
  skip_if_not_installed("exactextractr")
  cas <- .probe_cas()
  p <- suppressMessages(probe_indicator(cas$u, cas$r, indicateurs = c("N3", "P1"),
                                        taille_bloc_m = 500))
  expect_equal(p$statut[p$code == "N3"], "variance_nulle")
  expect_equal(p$statut[p$code == "P1"], "indicateur_absent")
  expect_true(all(is.na(p$r2)))

  petit <- .probe_cas(n_cote = 5)        # 25 UGF
  q <- suppressMessages(probe_indicator(petit$u, petit$r, indicateurs = "N1",
                                        taille_bloc_m = 200))
  expect_equal(q$statut, "trop_peu_unites")
  expect_equal(q$n, 25L)
})

test_that("indicators fed by Sentinel-2 are flagged as a shared source", {
  skip_if_not_installed("exactextractr")
  cas <- .probe_cas()
  p <- suppressMessages(probe_indicator(cas$u, cas$r, indicateurs = c("C2", "N1"),
                                        taille_bloc_m = 500))
  expect_true(p$source_commune[p$code == "C2"])
  expect_false(p$source_commune[p$code == "N1"])
})

test_that("indicateurs = NULL probes every indicator column present", {
  skip_if_not_installed("exactextractr")
  cas <- .probe_cas()
  p <- suppressMessages(probe_indicator(cas$u, cas$r, taille_bloc_m = 500))
  expect_setequal(p$code, c("C2", "N1", "N2", "N3"))
})

test_that("reading thresholds follow the spec", {
  expect_equal(nemeton:::.lecture_sonde(c(0.7, 0.5, 0.3, 0.2, 0.1, NA)),
               c("voit", "voit", "partiel", "partiel", "angle_mort", NA))
})

test_that("probe_indicator checks its inputs", {
  cas <- .probe_cas(n_cote = 5)
  expect_error(probe_indicator(data.frame(N1 = 1), cas$r), "sf")
  u <- cas$u[, "id"]
  expect_error(probe_indicator(u, cas$r), "No indicator column")
})
