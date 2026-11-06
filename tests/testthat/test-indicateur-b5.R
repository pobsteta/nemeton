# Tests de B5, stratification verticale depuis le nuage LiDAR (spec 067)

.b5_units <- function() {
  carre <- function(x0, y0, cote = 20) {
    sf::st_polygon(list(rbind(c(x0, y0), c(x0 + cote, y0), c(x0 + cote, y0 + cote),
                              c(x0, y0 + cote), c(x0, y0))))
  }
  sf::st_sf(id = 1:3,
            geometry = sf::st_sfc(carre(0, 0), carre(20, 0), carre(100, 100),
                                  crs = 2154))
}

# Nuage synthetique : UGF 1 = une seule strate haute, UGF 2 = retours repartis
# egalement entre les cinq strates (et du sol), UGF 3 = aucun retour.
.b5_nuage <- function(n = 5000, graine = 1) {
  set.seed(graine)
  x1 <- runif(n, 0, 20); y1 <- runif(n, 0, 20)
  z1 <- c(runif(n * 0.8, 22, 30), runif(n * 0.2, 0, 0.3))
  milieux <- c(1.2, 3.5, 7.5, 15, 25)
  z2 <- c(rep(milieux, each = n / 5 * 0.9), runif(n * 0.1, 0, 0.3))
  data.frame(X = c(x1, runif(n, 20, 40)), Y = c(y1, runif(n, 0, 20)), Z = c(z1, z2))
}

test_that("B5 is 0 for a single stratum and 100 for an even profile", {
  r <- indicateur_b5_stratification(.b5_units(), .b5_nuage())
  expect_s3_class(r, "sf")
  expect_equal(nrow(r), 3L)
  expect_equal(r$B5[1], 0)
  expect_equal(r$B5[2], 100)
  expect_equal(r$b5_status, c("calculated", "calculated", "skipped_no_coverage"))
  expect_true(is.na(r$B5[3]))
  expect_equal(r$b5_profil, rep("points", 3))
  # parts de strate : somme 1, la strate haute porte tout pour l'UGF 1
  parts <- as.matrix(sf::st_drop_geometry(r)[1:2, paste0("b5_s", 1:5)])
  expect_equal(unname(rowSums(parts)), c(1, 1))
  expect_equal(unname(parts[1, 5]), 1)
  expect_equal(unname(parts[2, ]), rep(0.2, 5))
  # densite = retours / surface (400 m2), sol compris
  expect_equal(r$b5_points[1:2], c(5000, 5000))
  expect_equal(r$b5_densite[1:2], c(12.5, 12.5))
})

test_that("without a cloud B5 is NA with status skipped_no_lidar", {
  r <- indicateur_b5_stratification(.b5_units())
  expect_true(all(is.na(r$B5)))
  expect_equal(unique(r$b5_status), "skipped_no_lidar")
  expect_true(all(c("b5_s1", "b5_s5", "b5_points", "b5_densite") %in% names(r)))
})

test_that("too few returns gives skipped_low_density", {
  nuage <- .b5_nuage(n = 50)
  r <- indicateur_b5_stratification(.b5_units(), nuage, min_points = 100)
  expect_equal(r$b5_status[1:2], rep("skipped_low_density", 2))
  expect_true(all(is.na(r$B5[1:2])))
  r <- indicateur_b5_stratification(.b5_units(), nuage, min_points = 10)
  expect_equal(r$b5_status[1:2], rep("calculated", 2))
})

test_that("a unit without vegetation above the ground threshold scores 0", {
  u <- .b5_units()[1, ]
  sol <- data.frame(X = runif(500, 0, 20), Y = runif(500, 0, 20), Z = runif(500, 0, 0.4))
  r <- indicateur_b5_stratification(u, sol)
  expect_equal(r$b5_status, "calculated")
  expect_equal(r$B5, 0)
})

test_that("noise, buildings and out-of-range heights are dropped", {
  u <- .b5_units()[1, ]
  set.seed(2)
  veg <- data.frame(X = runif(400, 0, 20), Y = runif(400, 0, 20), Z = runif(400, 22, 28),
                    Classification = 5L)
  bati <- data.frame(X = runif(400, 0, 20), Y = runif(400, 0, 20), Z = runif(400, 3, 8),
                     Classification = 6L)
  bruit <- data.frame(X = runif(50, 0, 20), Y = runif(50, 0, 20), Z = c(rep(80, 25), rep(-5, 25)),
                      Classification = 1L)
  r <- indicateur_b5_stratification(u, rbind(veg, bati, bruit))
  expect_equal(r$b5_points, 400)
  expect_equal(r$B5, 0)
  # sans colonne Classification, le bati compte
  r2 <- indicateur_b5_stratification(u, rbind(veg, bati)[, c("X", "Y", "Z")])
  expect_gt(r2$B5, 0)
})

test_that("altitudes are refused rather than read as heights", {
  u <- .b5_units()[1, ]
  alt <- data.frame(X = runif(200, 0, 20), Y = runif(200, 0, 20), Z = runif(200, 400, 430))
  expect_error(indicateur_b5_stratification(u, alt), "altitudes")
  expect_error(indicateur_b5_stratification(u, alt, normaliser = TRUE), "LAS object")
})

test_that("densite_foliaire raises the lower strata hidden under a canopy", {
  u <- .b5_units()[1, ]
  set.seed(3)
  n <- 4000
  # couvert dense : 70 % des retours dans la strate haute, peu sous lui
  z <- c(runif(n * 0.70, 20, 30), runif(n * 0.05, 10, 20), runif(n * 0.05, 5, 10),
         runif(n * 0.05, 2, 5), runif(n * 0.05, 0.5, 2), runif(n * 0.10, 0, 0.4))
  nuage <- data.frame(X = runif(n, 0, 20), Y = runif(n, 0, 20), Z = z)
  pts <- indicateur_b5_stratification(u, nuage)
  lad <- indicateur_b5_stratification(u, nuage, profil = "densite_foliaire")
  expect_equal(lad$b5_profil, "densite_foliaire")
  expect_gt(lad$b5_s1, pts$b5_s1)
  expect_gt(lad$B5, pts$B5)
  expect_equal(sum(unlist(sf::st_drop_geometry(lad)[, paste0("b5_s", 1:5)])), 1)
  # sans retour sol, le plancher garde un resultat fini
  lad0 <- indicateur_b5_stratification(u, nuage[nuage$Z >= 0.5, ], profil = "densite_foliaire")
  expect_true(is.finite(lad0$B5))
})

test_that("custom strata change the number of share columns", {
  r <- indicateur_b5_stratification(.b5_units(), .b5_nuage(), strates = c(0, 5, 20))
  expect_true(all(paste0("b5_s", 1:3) %in% names(r)))
  expect_false("b5_s4" %in% names(r))
  expect_error(indicateur_b5_stratification(.b5_units(), .b5_nuage(), strates = c(1, 5)),
               "starting at 0")
  expect_error(indicateur_b5_stratification(.b5_units(), .b5_nuage(), hauteur_sol = 3),
               "second stratum")
})

test_that("LAZ files without lidR give a clear error", {
  skip_if(requireNamespace("lidR", quietly = TRUE), "lidR installed")
  withr::with_tempdir({
    file.create("dalle.laz")
    expect_error(indicateur_b5_stratification(.b5_units(), getwd()), "lidR")
  })
  expect_error(indicateur_b5_stratification(.b5_units(), tempfile()), "No")
})

test_that("B5 reads LAZ tiles and LAS objects with lidR", {
  skip_if_not_installed("lidR")
  f <- system.file("extdata", "aba.model", "ALS", "plots.norm.laz", "Verc-01-1.laz",
                   package = "nemeton")
  skip_if(!nzchar(f), "example plot cloud not installed")
  las <- lidR::readLAS(f, select = "xyzc")
  centre <- sf::st_sfc(sf::st_point(c(mean(range(las@data$X)), mean(range(las@data$Y)))),
                       crs = 2154)
  u <- sf::st_sf(id = 1, geometry = sf::st_buffer(centre, 15))
  r_fichier <- indicateur_b5_stratification(u, f)
  r_las <- indicateur_b5_stratification(u, las)
  r_table <- indicateur_b5_stratification(u, as.data.frame(las@data))
  expect_equal(r_fichier$b5_status, "calculated")
  expect_equal(r_fichier$B5, r_las$B5)
  expect_equal(r_las$B5, r_table$B5)
})

test_that("nemeton_compute passes the cloud to B5 and normalisation is passthrough", {
  u <- .b5_units()[1:2, ]
  layers <- structure(list(rasters = list(), vectors = list()), class = "nemeton_layers")
  r <- suppressMessages(nemeton_compute(u, layers, indicators = "indicateur_b5_stratification",
                                        preprocess = FALSE, nuage = .b5_nuage()))
  expect_equal(r$indicateur_b5_stratification, c(0, 100))
  expect_equal(r$b5_status, c("calculated", "calculated"))
  expect_equal(as.numeric(normalize_indicator("B5", c(0, 55, 100, 120))),
               c(0, 55, 100, 100))
})

test_that("LAZ tiles are read tile by tile and summed (lidR simulated)", {
  u <- .b5_units()[1:2, ]
  nuage <- .b5_nuage()
  moities <- split(nuage, nuage$X < 20)
  withr::with_tempdir({
    dir.create("dalles")
    file.create(file.path("dalles", c("a.laz", "b.laz", "vide.laz")))
    lues <- character(0)
    local_mocked_bindings(
      .b5_lidr_ok = function() TRUE,
      .b5_lire_dalle = function(fichier, filtre, normaliser) {
        lues <<- c(lues, basename(fichier))
        expect_match(filtre, "^-keep_xy ")
        switch(basename(fichier), a.laz = moities[["TRUE"]], b.laz = moities[["FALSE"]],
               vide.laz = NULL)
      },
      .package = "nemeton"
    )
    r <- indicateur_b5_stratification(u, "dalles")
    expect_setequal(lues, c("a.laz", "b.laz", "vide.laz"))
    expect_equal(r$B5, indicateur_b5_stratification(u, nuage)$B5)
    expect_equal(r$b5_points, c(5000, 5000))
    # dalles toutes vides : aucune couverture, pas d'erreur
    local_mocked_bindings(.b5_lire_dalle = function(...) NULL, .package = "nemeton")
    expect_equal(unique(indicateur_b5_stratification(u, "dalles")$b5_status),
                 "skipped_no_coverage")
  })
})

# ---- simulate_density_sensitivity() ------------------------------------------

test_that("simulate_density_sensitivity thins below the current density only", {
  u <- .b5_units()[1:2, ]
  s <- simulate_density_sensitivity(u, .b5_nuage(), densites = c(20, 10, 5, 1),
                                    repetitions = 3)
  expect_s3_class(s, "sensibilite_densite")
  expect_equal(s$densite_actuelle, 12.5)
  expect_equal(s$eclaircie, "retours")
  expect_equal(s$resume$densite, c(10, 5, 1))          # 20 >= 12,5 : non simulee
  expect_equal(s$resume$proportion, round(c(10, 5, 1) / 12.5, 4))
  expect_equal(s$reference$B5, c(0, 100))
  expect_equal(nrow(s$detail), 3 * 3 * 2)
  expect_true(all(s$detail$ecart >= 0, na.rm = TRUE))
  # profils tranches : une strate seule reste a 0, l'equilibre reste pres de 100
  expect_true(all(s$detail$B5[s$detail$unite == 1] == 0))
  expect_lt(max(s$resume$ecart_p90), 5)
  expect_true(all(s$resume$stable))
  expect_equal(s$conclusion, "densite_suffisante")
  expect_output(print(s), "Conclusion: densite_suffisante")
})

test_that("simulate_density_sensitivity is reproducible and thins by pulse", {
  u <- .b5_units()[1:2, ]
  nuage <- .b5_nuage()
  a <- simulate_density_sensitivity(u, nuage, densites = 5, repetitions = 2, graine = 7)
  b <- simulate_density_sensitivity(u, nuage, densites = 5, repetitions = 2, graine = 7)
  expect_identical(a$detail, b$detail)
  # deux retours par impulsion : une impulsion gardee garde ses deux retours
  nuage$gpstime <- rep(seq_len(nrow(nuage) / 2), each = 2)
  p <- simulate_density_sensitivity(u, nuage, densites = 5, repetitions = 1)
  expect_equal(p$eclaircie, "impulsions")
  expect_true(all(p$detail$B5 >= 0))
})

test_that("simulate_density_sensitivity reports units lost and unstable profiles", {
  u <- .b5_units()[1, ]
  set.seed(4)
  # 400 retours repartis sur deux strates : a 0,1 retour/m2 il en reste ~40
  nuage <- data.frame(X = runif(400, 0, 20), Y = runif(400, 0, 20),
                      Z = c(runif(200, 1, 1.9), runif(200, 25, 28)))
  s <- simulate_density_sensitivity(u, nuage, densites = c(0.5, 0.1), repetitions = 4,
                                    min_points = 30)
  expect_true(all(c("part_perdue", "part_stable") %in% names(s$resume)))
  expect_gte(s$resume$part_perdue[2], 0)
  # tolerance nulle : tout ecart rend instable
  s0 <- simulate_density_sensitivity(u, nuage, densites = 0.5, repetitions = 4,
                                     tolerance = 0, min_points = 30)
  expect_false(s0$resume$stable)
  expect_equal(s0$conclusion, "densite_limite")
  # rien sous la densite actuelle
  s1 <- simulate_density_sensitivity(u, nuage, densites = 50)
  expect_equal(s1$conclusion, "non_simule")
  expect_equal(nrow(s1$resume), 0)
  expect_output(print(s1), "non_simule")
})

test_that("simulate_density_sensitivity validates its arguments", {
  u <- .b5_units()[1, ]
  n <- .b5_nuage()
  expect_error(simulate_density_sensitivity(u, n, indicateurs = "N4"), "B5")
  expect_error(simulate_density_sensitivity(u, NULL), "required")
  expect_error(simulate_density_sensitivity(u, n, densites = -1), "positive")
  expect_error(simulate_density_sensitivity(u, n, repetitions = 0), "at least 1")
  expect_error(simulate_density_sensitivity(u, n, strates = c(1, 5)), "starting at 0")
  expect_error(simulate_density_sensitivity(sf::st_drop_geometry(u), n), "sf")
})
