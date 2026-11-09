# Tests de calibrer_finn() / predire_finn() (spec 068, etape 3).
# La preparation des tables FINN est en R de base : testee sans FINN. Le
# passage par FINN n'est teste que si FINN et libtorch sont installes.

arbres_finn_demo <- function(n_pla = 6) {
  set.seed(1)
  do.call(rbind, lapply(seq_len(n_pla), function(p) {
    n <- 8
    d1 <- round(runif(n, 10, 50), 1)
    statut <- c(rep("vivant", 5), "mort", "coupe", "vivant")
    d2 <- ifelse(statut == "vivant", d1 + runif(n, 0, 2), NA)
    rec <- data.frame(placette = paste0("P", p), essence = "09", d1 = NA,
                      d2 = 8, poids = 88.4, statut = "recrute")
    rbind(data.frame(placette = paste0("P", p),
                     essence = c("09", "09", "03", "03", "62", "09", "03", "51"),
                     d1 = d1, d2 = d2, poids = 14.1, statut = statut), rec)
  }))
}
env_finn_demo <- function(n_pla = 6) {
  data.frame(placette = paste0("P", seq_len(n_pla)), tx_ete = 22 + seq_len(n_pla) / 10,
             rr_an = 900 + 10 * seq_len(n_pla))
}

test_that(".finn_preparer builds consistent FINN tables", {
  a <- arbres_finn_demo(); e <- env_finn_demo()
  p <- nemeton:::.finn_preparer(a, e, surface_placette = 0.7, min_arbres_essence = 1L)
  expect_equal(nrow(p$sites), 6)
  expect_equal(p$variables_env, c("tx_ete", "rr_an"))
  expect_equal(tail(p$essences, 1), "other")
  # etat initial : vivants et morts, sans coupes ni recrues
  expect_equal(nrow(p$init), 6 * 7)
  expect_equal(sum(p$init$trees), 6 * 7 * 14.1 * 0.7)
  # observations : grille complete site x essence
  expect_equal(nrow(p$obs), 6 * length(p$essences))
  expect_equal(sum(p$obs$n_died), 6)
  expect_equal(sum(p$obs$reg), 6 * 88.4)
  g_obs <- sum(with(a[a$statut %in% c("vivant", "recrute"), ], poids * pi * (d2 / 200)^2)) * 0.7
  expect_equal(sum(p$obs$ba), g_obs)
  expect_equal(p$recruits_dbh, 8)
  expect_equal(sort(unique(p$env$year)), 0:1)
  # G initiale apres l'arrondi des effectifs (14,1 x 0,7 = 9,87 -> 10)
  g0 <- tapply(10 * pi * (p$init$dbh / 200)^2, p$init$siteID, sum) / 0.7
  expect_equal(p$sites$g0, as.numeric(g0))
})

test_that(".finn_preparer pools rare species and drops plots without environment", {
  a <- arbres_finn_demo(); e <- env_finn_demo()
  e$rr_an[2] <- NA
  p <- nemeton:::.finn_preparer(a, e, surface_placette = 0.7, part_essences = 0.5,
                                min_arbres_essence = 1L)
  expect_equal(nrow(p$sites), 5)
  expect_false("P2" %in% p$sites$placette)
  expect_true(length(p$essences) < 5)
  p2 <- nemeton:::.finn_preparer(a, e, 0.7, essences = c("09", "other"),
                                 variables_env = "tx_ete", observations = FALSE)
  expect_null(p2$obs)
  expect_true(all(p2$init$species %in% 1:2))
  expect_equal(nrow(p2$sites), 6)
})

test_that(".finn_preparer pools species with too few trees in other", {
  a <- arbres_finn_demo(); e <- env_finn_demo()
  n <- table(a$essence[a$statut %in% c("vivant", "mort")])
  p_tous <- nemeton:::.finn_preparer(a, e, 0.7, part_essences = 1, min_arbres_essence = 1L)
  expect_setequal(p_tous$essences, c(names(n), "other"))
  seuil <- max(n[names(n) != names(which.max(n))]) + 1L
  p <- nemeton:::.finn_preparer(a, e, 0.7, part_essences = 1, min_arbres_essence = seuil)
  expect_equal(p$essences, c(names(which.max(n)), "other"))
  expect_equal(nrow(p$init), nrow(p_tous$init))
  expect_equal(sum(p$obs$ba), sum(p_tous$obs$ba))
  # defaut 300 : aucune essence de la demo ne passe
  expect_equal(nemeton:::.finn_preparer(a, e, 0.7)$essences, "other")
})

test_that(".finn_preparer validates its inputs", {
  a <- arbres_finn_demo(); e <- env_finn_demo()
  expect_error(nemeton:::.finn_preparer(a[, -1], e, 0.7), "placette")
  a2 <- a; a2$statut[1] <- "chablis"
  expect_error(nemeton:::.finn_preparer(a2, e, 0.7), "chablis")
  expect_error(nemeton:::.finn_preparer(a, e, 0), "surface_placette")
  expect_error(nemeton:::.finn_preparer(a, e["placette"], 0.7), "numeric")
  expect_error(nemeton:::.finn_preparer(a[a$statut != "recrute", ], e, 0.7), "recruit")
})

test_that("calibrer_finn refuses neural processes and predire_finn a foreign object", {
  expect_error(calibrer_finn(arbres_finn_demo(), env_finn_demo(), processus = "neuronal"),
               "D-3")
  expect_error(predire_finn(list(), arbres_finn_demo(), env_finn_demo()), "calibrer_finn")
})

test_that("calibrer_finn and predire_finn run end to end with FINN", {
  skip_on_cran()
  skip_if_not_installed("FINN")
  skip_if_not_installed("data.table")
  skip_if_not(torch::torch_is_installed(), "libtorch not installed")
  a <- arbres_finn_demo(); e <- env_finn_demo()
  cal <- calibrer_finn(a, e, epoques = 2L)
  expect_s3_class(cal, "finn_calibration")
  expect_equal(cal$n_placettes, 6)
  expect_output(print(cal), "finn_calibration")
  p <- predire_finn(cal, a, e, n_tirages = 2L)
  expect_equal(nrow(p), 6)
  expect_true(all(is.finite(p$g_predite)))
  expect_true(all(p$g_q05 <= p$g_q95))
})
