# Tests de accroissement_hdom_finn() et de l'allometrie IFN (spec 068, T4).
# Sans FINN : le pas FINN est remplace par un pas ou chaque tige gagne 2 cm.

calib_hdom <- function() {
  structure(list(modele = list(eval = function() invisible(NULL)),
                 essences = c("09", "other"), variables_env = "x",
                 surface_placette = 0.5, pas_annees = 5),
            class = "finn_calibration")
}

plus_deux <- function(m, coh, env1, sp, n_sp) {
  out <- coh
  out$dbh <- coh$dbh + 2
  attr(out, "dbh_entree") <- coh$dbh
  attr(out, "morts") <- coh[0, ]
  out
}

test_that(".hauteur_ifn uses the SER curve, then the species, then other", {
  tab <- .allometrie_hauteur()
  c09 <- tab[tab$essence == "09" & tab$ser == "", ]
  c09s <- tab[tab$essence == "09" & tab$ser != "", ][1, ]
  oth <- tab[tab$essence == "other" & tab$ser == "", ]
  mm <- function(cf, d) 1.3 + cf$a * d / (cf$b + d)
  expect_equal(.hauteur_ifn(30, "09"), mm(c09, 30))
  expect_equal(.hauteur_ifn(30, "09", c09s$ser), mm(c09s, 30))
  expect_equal(.hauteur_ifn(30, "09", "ZZZ"), mm(c09, 30))
  expect_equal(.hauteur_ifn(30, "inconnue"), mm(oth, 30))
  # croissante avec le diametre
  expect_true(all(diff(.hauteur_ifn(c(10, 20, 40, 80), "03")) > 0))
})

test_that(".h_dominante_cohortes averages the 100 largest trees per hectare", {
  # placette de 0,07 ha : 7 tiges dominantes
  coh <- data.frame(siteID = c(1, 1, 2), species = c(1, 2, 1), dbh = c(40, 20, 30),
                    trees = c(5, 10, 3))
  h <- .h_dominante_cohortes(coh, 3, 0.07, c("03", "other"), rep("C20", 3))
  h40 <- .hauteur_ifn(40, "03", "C20")
  h20 <- .hauteur_ifn(20, "other", "C20")
  expect_equal(h[1], (5 * h40 + 2 * h20) / 7)
  expect_equal(h[2], .hauteur_ifn(30, "03", "C20"))
  expect_true(is.na(h[3]))
  expect_true(all(is.na(.h_dominante_cohortes(coh[0, ], 2, 0.07, "03", c(NA, NA)))))
})

test_that("accroissement_hdom_finn gives the dominant-height increment (FINN mocked)", {
  local_mocked_bindings(.finn_verifier_installation = function() invisible(TRUE),
                        .itin_un_pas = plus_deux)
  a <- data.frame(placette = c("A", "A", "B"), essence = c("09", "02", "09"),
                  d1 = c(40, 20, 30), poids = c(100, 200, 100))
  e <- data.frame(placette = c("A", "B"), x = 1)
  r <- accroissement_hdom_finn(calib_hdom(), a, e, ser = c(A = "C20", B = "E10"),
                               n_tirages = 2L)
  expect_named(r, c("placette", "ser", "essence", "g0", "h_dom", "tirage", "accroissement"))
  expect_equal(nrow(r), 4L)
  expect_equal(r$tirage, c(1L, 1L, 2L, 2L))
  expect_equal(r$ser, c("C20", "E10", "C20", "E10"))
  # essence dominante en G, code d'origine
  expect_equal(r$essence[1:2], c("09", "09"))
  # A : 50 tiges de 40 cm sur 0,5 ha = les 100/ha dominantes
  expect_equal(r$h_dom[1], .hauteur_ifn(40, "09", "C20"))
  expect_equal(r$accroissement[1], .hauteur_ifn(42, "09", "C20") - .hauteur_ifn(40, "09", "C20"))
  expect_equal(r$accroissement[2], .hauteur_ifn(32, "09", "E10") - .hauteur_ifn(30, "09", "E10"))
  expect_true(all(r$accroissement > 0))

  # SER en data.frame ; sans SER : courbes toutes SER
  r2 <- accroissement_hdom_finn(calib_hdom(), a, e,
                                ser = data.frame(placette = "A", ser = "C20"), n_tirages = 1L)
  expect_equal(r2$ser, c("C20", NA))
  r3 <- accroissement_hdom_finn(calib_hdom(), a, e, n_tirages = 1L)
  expect_equal(r3$h_dom[2], .hauteur_ifn(30, "09"))
})

test_that("accroissement_hdom_finn checks its inputs", {
  a <- data.frame(placette = "A", essence = "09", d1 = 30, poids = 100)
  e <- data.frame(placette = "A", x = 1)
  expect_error(accroissement_hdom_finn(list(), a, e), "calibrer_finn")
  expect_error(accroissement_hdom_finn(calib_hdom(), a, e, n_tirages = 0), "n_tirages")
  local_mocked_bindings(.finn_verifier_installation = function() invisible(TRUE),
                        .itin_un_pas = plus_deux)
  expect_error(accroissement_hdom_finn(calib_hdom(), a[, -4], e), "poids")
  expect_error(accroissement_hdom_finn(calib_hdom(), a, e, ser = "C20"), "named by plot")
  expect_error(accroissement_hdom_finn(calib_hdom(), a, e, ser = data.frame(p = "A")),
               "placette")
})

test_that("accroissement_hdom_finn runs with FINN", {
  skip_on_cran()
  skip_if_not_installed("FINN")
  skip_if_not_installed("data.table")
  skip_if_not(torch::torch_is_installed(), "libtorch not installed")
  a <- arbres_finn_demo(); e <- env_finn_demo()
  a$statut[a$statut == "coupe"] <- "vivant"
  a$d2[a$statut == "vivant" & is.na(a$d2)] <- a$d1[a$statut == "vivant" & is.na(a$d2)] + 1
  cal <- calibrer_finn(a, e, epoques = 2L, min_arbres_essence = 1L)
  r <- suppressWarnings(suppressMessages(accroissement_hdom_finn(cal, a, e, n_tirages = 2L)))
  expect_equal(nrow(r), 2L * length(unique(r$placette)))
  expect_true(all(is.finite(r$h_dom) & r$h_dom > 1.3))
  expect_true(all(is.finite(r$accroissement)))
})
