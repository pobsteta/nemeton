# Tests d'effet_gestion() (spec 068, etape 1)

.eg_sim <- function(n = 200, effet = 8, graine = 1, niveaux = c("irregulier", "regulier"),
                    pente_ps = 1.5) {
  set.seed(graine)
  d <- data.frame(P2 = runif(n, 2, 10), altitude = runif(n, 200, 900),
                  ser = sample(c("A", "B"), n, TRUE))
  d$type_sylviculture <- ifelse(runif(n) < plogis((d$P2 - 6) / pente_ps), niveaux[1], niveaux[2])
  d$famille_biodiversite <- 30 + 4 * d$P2 + effet * (d$type_sylviculture == niveaux[1]) +
    stats::rnorm(n, 0, 3)
  d$famille_production <- 50 + 2 * d$P2 + stats::rnorm(n, 0, 3)
  d
}

test_that("effet_gestion recovers a known effect and a null one", {
  skip_if_not_installed("ranger")
  d <- .eg_sim()
  naif <- diff(rev(tapply(d$famille_biodiversite, d$type_sylviculture, mean)))
  e <- effet_gestion(d, reference = "regulier", n_boot = 5)
  expect_s3_class(e, "effet_gestion")
  expect_equal(e$apprenant, "ranger")
  expect_equal(e$covariables, c("P2", "altitude", "ser"))
  r <- e$resume
  expect_equal(r$statut, c("calcule", "calcule"))
  bio <- r[r$resultat == "famille_biodiversite", ]
  prod <- r[r$resultat == "famille_production", ]
  expect_gt(naif, 12)                                 # confusion par P2
  expect_true(bio$ic_bas <= 8 + 1.5 && bio$ic_haut >= 8 - 1.5)
  expect_gt(bio$ic_bas, 0)
  expect_true(prod$ic_bas <= 0 && prod$ic_haut >= 0)
  expect_gte(bio$part_support, 0.7)
  # table par unite
  u <- e$unites
  expect_true(all(c("unite", "traitement", "resultat", "effet", "ic_bas", "ic_haut",
                    "support") %in% names(u)))
  expect_true(all(is.na(u$effet[!u$support])))
  expect_true(all(!is.na(u$effet[u$support])))
  expect_output(print(e), "not a proven causal effect")
})

test_that("effet_gestion refuses without overlap or with too few units", {
  d <- .eg_sim(pente_ps = 0.01)                       # traitement = P2 > 6
  e <- effet_gestion(d, reference = "regulier", n_boot = 2)
  expect_equal(unique(e$resume$statut), "recouvrement_insuffisant")
  expect_true(all(is.na(e$resume$effet_moyen)))
  expect_equal(nrow(e$unites), 0)

  petit <- .eg_sim(n = 30)
  e2 <- effet_gestion(petit, reference = "regulier", min_par_traitement = 20, n_boot = 2)
  expect_equal(unique(e2$resume$statut), "trop_peu_unites")
})

test_that("effet_gestion handles several levels, sf input and the lm fallback", {
  d <- .eg_sim(n = 240)
  d$type_sylviculture[seq(1, 240, by = 3)] <- "libre_evolution"
  pts <- sf::st_as_sf(cbind(d, x = seq_len(nrow(d)), y = 0), coords = c("x", "y"), crs = 2154)
  local_mocked_bindings(.eg_ranger_ok = function() FALSE, .package = "nemeton")
  e <- effet_gestion(pts, reference = "regulier", n_boot = 3, methode = "t_learner")
  expect_equal(e$apprenant, "lm")
  expect_equal(e$methode, "t_learner")
  expect_setequal(unique(e$resume$traitement), c("irregulier", "libre_evolution"))
  expect_equal(nrow(e$resume), 4)                     # 2 contrastes x 2 familles
  bio <- e$resume[e$resume$traitement == "irregulier" & e$resume$resultat == "famille_biodiversite", ]
  expect_equal(bio$statut, "calcule")
  expect_lt(abs(bio$effet_moyen - 8), 3)
  # reference par defaut : le niveau le plus frequent
  e_def <- effet_gestion(d, resultats = "famille_production", n_boot = 2)
  expect_equal(e_def$reference, names(sort(table(d$type_sylviculture), decreasing = TRUE))[1])
})

test_that("effet_gestion validates its arguments", {
  d <- .eg_sim(n = 60)
  expect_error(effet_gestion(d, traitement = "absent"), "not found")
  expect_error(effet_gestion(d, resultats = "absent"), "missing")
  expect_error(effet_gestion(d[, c("type_sylviculture", "famille_production")]), "covariates")
  expect_error(effet_gestion(d, reference = "taillis"), "not a level")
  d1 <- d; d1$type_sylviculture <- "regulier"
  expect_error(effet_gestion(d1), "two levels")
  expect_error(effet_gestion(d, support_min = 2), "\\[0, 1\\]")
  expect_error(effet_gestion(d, n_boot = 1), "at least 2")
})
