# Tests de surmortalite_finn() (spec 069). Sans FINN : le pas FINN est
# remplace par un pas ou toutes les tiges meurent, la mortalite attendue est
# alors la G initiale.

calib_surm <- function(conforme = NULL, placettes = "Z0") {
  structure(list(modele = list(eval = function() invisible(NULL)),
                 essences = c("09", "other"), variables_env = "x",
                 surface_placette = 0.5, pas_annees = 5, placettes = placettes,
                 conforme = conforme), class = "finn_calibration")
}

tout_meurt <- function(m, coh, env1, sp, n_sp) {
  out <- coh[0, ]
  attr(out, "dbh_entree") <- numeric(0)
  attr(out, "morts") <- coh
  out
}

# une tige vivante de 30 cm (2 tiges/ha) et une morte de 20 cm (4 tiges/ha)
# par placette : attendu = G initiale, observe = G de la morte
arbres_surm <- function(pla) {
  do.call(rbind, lapply(pla, function(p) data.frame(
    placette = p, essence = "09", d1 = c(30, 20), d2 = c(31, NA), poids = c(2, 4),
    statut = c("vivant", "mort"))))
}
g_arbre <- function(d) pi * (d / 200)^2

test_that(".finn_mortalite gives observed and expected dead basal area (FINN mocked)", {
  local_mocked_bindings(.finn_verifier_installation = function() invisible(TRUE),
                        .itin_un_pas = tout_meurt)
  pla <- c("A", "B")
  m <- .finn_mortalite(calib_surm(), arbres_surm(pla), data.frame(placette = pla, x = 1),
                       n_tirages = 2L)
  expect_equal(m$placette, pla)
  expect_equal(m$mort_observee, rep(4 * g_arbre(20), 2))
  expect_equal(m$g_initiale, rep(2 * g_arbre(30) + 4 * g_arbre(20), 2))
  # tiges arrondies par cohorte (2 x 0.5 = 1, 4 x 0.5 = 2) puis rapportees a l'ha
  expect_equal(m$mort_attendue, rep((1 * g_arbre(30) + 2 * g_arbre(20)) / 0.5, 2))
})

test_that("surmortalite_finn reports plots and units against the threshold (FINN mocked)", {
  local_mocked_bindings(.finn_verifier_installation = function() invisible(TRUE),
                        .itin_un_pas = tout_meurt)
  pla <- paste0("P", 1:4)
  a <- arbres_surm(pla)
  # deux tiges mortes de plus sur P4
  a <- rbind(a, data.frame(placette = "P4", essence = "09", d1 = 40, d2 = NA, poids = 10,
                           statut = "mort"))
  e <- data.frame(placette = pla, x = 1)
  set.seed(3)
  conf <- list(niveau = 0.9, demi_largeur = 4, residus = rnorm(200),
               mortalite = list(residus = rnorm(200, 0, 0.5), n_placettes = 200))
  cal <- calib_surm(conf)

  # par placette : avertissement de bruit
  expect_warning(p <- surmortalite_finn(cal, a, e, n_tirages = 1L), "noisy")
  expect_named(p, c("placette", "g_initiale", "mort_observee", "mort_attendue",
                    "surmortalite", "surmortalite_pct", "seuil", "anormale"))
  expect_equal(p$surmortalite, p$mort_observee - p$mort_attendue)
  expect_equal(p$surmortalite_pct, 100 * p$surmortalite / p$g_initiale)
  r <- conf$mortalite$residus
  expect_equal(unique(p$seuil), unname(stats::quantile(r, 0.95 * (1 + 1 / 200))))
  expect_equal(p$anormale, p$surmortalite > p$seuil)
  expect_equal(attr(p, "niveau"), 0.95)

  # par unite : moyennes des placettes, seuil des groupes de k placettes
  u <- data.frame(placette = pla, unite = c("U1", "U1", "U1", "U2"))
  s <- surmortalite_finn(cal, a, e, unites = u, n_tirages = 1L)
  expect_equal(s$unite, c("U1", "U2"))
  expect_equal(s$n_placettes, c(3L, 1L))
  expect_equal(s$mort_observee[1], mean(p$mort_observee[1:3]))
  expect_equal(s$surmortalite[2], p$surmortalite[4])
  expect_equal(s$seuil[2], p$seuil[1])
  expect_equal(s$seuil[1], .finn_seuil_mortalite(conf, 3L, 0.95))
  expect_lt(s$seuil[1], s$seuil[2])

  # unite trop grande pour les residus : seuil NA, avertissement
  big <- data.frame(placette = pla, unite = "U")
  conf_petit <- conf; conf_petit$mortalite$residus <- r[1:100]
  expect_warning(b <- surmortalite_finn(calib_surm(conf_petit), a, e, unites = big,
                                        n_tirages = 1L), "30 needed")
  expect_true(is.na(b$seuil) && is.na(b$anormale))

  # sans residus de mortalite : seuil NA et message
  expect_message(n <- surmortalite_finn(calib_surm(), a, e, unites = u, n_tirages = 1L),
                 "conformer_finn")
  expect_true(all(is.na(n$seuil)))

  # placette coupee : ecartee ; placette de calibration : avertie
  a2 <- rbind(a, data.frame(placette = "P2", essence = "09", d1 = 25, d2 = NA, poids = 2,
                            statut = "coupe"))
  expect_message(c2 <- suppressWarnings(surmortalite_finn(cal, a2, e, n_tirages = 1L)),
                 "cut between the visits")
  expect_equal(c2$placette, c("P1", "P3", "P4"))
  expect_warning(surmortalite_finn(calib_surm(conf, placettes = "P1"), a, e, unites = u,
                                   n_tirages = 1L), "used in the calibration")
})

test_that("surmortalite_finn checks its inputs", {
  a <- arbres_surm("A"); e <- data.frame(placette = "A", x = 1)
  expect_error(surmortalite_finn(list(), a, e), "calibrer_finn")
  expect_error(surmortalite_finn(calib_surm(), a, e, niveau = 1), "niveau")
  expect_error(surmortalite_finn(calib_surm(), a, e, n_tirages = 0), "n_tirages")
  expect_error(surmortalite_finn(calib_surm(), a[, -6], e), "statut")
  expect_error(surmortalite_finn(calib_surm(), a, e, unites = data.frame(placette = "A")),
               "unite")
  expect_error(surmortalite_finn(calib_surm(), a, e,
                                 unites = data.frame(placette = c("A", "A"), unite = 1:2)),
               "one unit only")
  local_mocked_bindings(.finn_verifier_installation = function() invisible(TRUE),
                        .itin_un_pas = tout_meurt)
  expect_error(suppressWarnings(surmortalite_finn(calib_surm(), a, e,
                                 unites = data.frame(placette = "B", unite = "U"))),
               "without a unit")
})

test_that(".finn_seuil_mortalite takes one-sided quantiles of plots and groups", {
  set.seed(8)
  n <- 300
  conf <- list(mortalite = list(residus = c(rnorm(n), NA)),
               x = c(runif(n, 0, 1e5), 0), y = c(runif(n, 0, 1e5), 0))
  r <- conf$mortalite$residus[1:n]
  expect_equal(.finn_seuil_mortalite(conf, 1L, 0.95),
               unname(stats::quantile(r, 0.95 * (1 + 1 / n))))
  # groupes de 4 voisines : la moyenne de 4 residus est moins dispersee
  expect_lt(.finn_seuil_mortalite(conf, 4L, 0.95), .finn_seuil_mortalite(conf, 1L, 0.95))
  expect_true(is.na(.finn_seuil_mortalite(list(), 1L, 0.95)))
  expect_warning(v <- .finn_seuil_mortalite(conf, 20L, 0.95), "30 needed")
  expect_true(is.na(v))
})

test_that("surmortalite_finn runs with FINN", {
  skip_on_cran()
  skip_if_not_installed("FINN")
  skip_if_not_installed("data.table")
  skip_if_not(torch::torch_is_installed(), "libtorch not installed")
  a <- arbres_finn_demo(); e <- env_finn_demo()
  a$statut[a$statut == "coupe"] <- "vivant"
  a$d2[a$statut == "vivant" & is.na(a$d2)] <- a$d1[a$statut == "vivant" & is.na(a$d2)] + 1
  cal <- calibrer_finn(a, e, epoques = 2L, min_arbres_essence = 1L)
  u <- data.frame(placette = paste0("P", 1:6), unite = rep(c("U1", "U2"), each = 3))
  s <- suppressWarnings(suppressMessages(
    surmortalite_finn(cal, a, e, unites = u, n_tirages = 2L)))
  expect_equal(s$unite, c("U1", "U2"))
  expect_true(all(s$mort_attendue >= 0 & s$mort_observee >= 0))
  expect_true(all(is.na(s$seuil)))
})
