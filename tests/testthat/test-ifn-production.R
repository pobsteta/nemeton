# Tests production IFN (spec 054 lot 1) : calcul par arbre/placette et table.

arbres_jouet <- function() {
  data.frame(
    CAMPAGNE = "2020", IDP = c(rep("P1", 4), rep("P2", 2)),
    ESPAR = c("09", "09", "62", "62", "09", "02"),
    C13 = c(1.00, 1.05, 0.80, 0.30, 0.50, 0.40),
    # IR5 en metres. Arbre 2 : hetre simplifie, meme categorie que l'arbre 1.
    # Arbre 4 : epicea PB sans IR5, impute au niveau placette x essence.
    IR5 = c(0.010, NA, 0.008, NA, 0.006, 0.004),
    V = c(1.2, 1.3, 0.8, 0.05, 0.3, 0.2),
    W = c(14.15, 14.15, 14.15, 39.3, 14.15, 14.15),
    stringsAsFactors = FALSE
  )
}

test_that("conifer / broadleaf split follows the IFN numeric prefix", {
  expect_equal(.ifn_groupe_espar(c("09", "9", "02", "5", "6", "7", "51",
                                   "62", "64", "70SE", "74H", "77", "29MI")),
               c("feuillus", "feuillus", "feuillus", "feuillus", "feuillus",
                 "feuillus", "resineux", "resineux", "resineux", "resineux",
                 "resineux", "resineux", "feuillus"))
})

test_that("basal-area production is exact for a cored tree", {
  a <- .ifn_production_arbres(arbres_jouet())
  c_p <- 1.00 - 2 * pi * 0.010
  g <- function(c) c^2 / (4 * pi)
  expect_equal(a$pg[1], (g(1.00) - g(c_p)) / 5)
  expect_false(a$ir5_impute[1])
})

test_that("an imputed tree keeps its production (the C_passe trap)", {
  a <- .ifn_production_arbres(arbres_jouet())
  # Arbre 2 : rg emprunte a l'arbre 1 (meme placette x essence x categorie).
  expect_true(a$ir5_impute[2])
  expect_equal(a$rg[2], a$rg[1])
  # Sans recalcul de C_passe depuis rg, recrute vaudrait NA et pv/pg aussi.
  expect_false(is.na(a$c_passe[2]))
  expect_false(is.na(a$recrute[2]))
  expect_gt(a$pv[2], 0)
  # Arbre 4 (PB, seul de sa categorie) : repli placette x essence.
  expect_true(a$ir5_impute[4])
  expect_equal(a$rg[4], a$rg[3])
  expect_false(anyNA(a$pv))
})

test_that("beta = 0 is the constant-height path, beta > 0 adds height growth", {
  a0 <- .ifn_production_arbres(arbres_jouet())
  expect_equal(a0$rv, a0$rg)
  a5 <- .ifn_production_arbres(arbres_jouet(), beta = 0.5)
  expect_equal(a5$rv, 1 - (1 - a5$rg)^1.25)
  nr <- !a5$recrute
  expect_true(all(a5$pv[nr] > a0$pv[nr]))
  expect_equal(a5$pg, a0$pg)   # la surface terriere ne depend pas de beta
  # Table groupe x categorie ; cellule absente -> 0 (voie (a)).
  tb <- data.frame(groupe = "feuillus", cat = "BM", beta = 0.4)
  ab <- .ifn_production_arbres(arbres_jouet(), beta = tb)
  expect_equal(ab$beta, ifelse(ab$groupe == "feuillus" & ab$cat == "BM", 0.4, 0))
})

test_that("the height-diameter exponent is estimated within plot x species", {
  set.seed(7)
  d <- do.call(rbind, lapply(1:40, function(p) {
    c13 <- runif(6, 0.3, 1.2)
    # Effet station par placette, pente commune 0,45.
    data.frame(CAMPAGNE = "2020", IDP = paste0("P", p), ESPAR = "09", C13 = c13,
               HTOT = exp(rnorm(1, 2.5, 0.3) + 0.45 * log(c13) + rnorm(6, 0, 0.02)))
  }))
  b <- .ifn_beta_hauteur(d)
  expect_equal(nrow(b), 2L)   # PB et BM, feuillus
  expect_true(all(abs(b$beta - 0.45) < 0.05))
  expect_true(all(b$groupe == "feuillus"))
})

test_that("cut trees bring their pre-harvest growth and the updated harvest", {
  a <- .ifn_production_arbres(cbind(arbres_jouet(), A = as.character(1:6)), beta = 0.5)
  cp <- data.frame(CAMPAGNE = "2025", IDP = c("P1", "P1", "P9"),
                   A = c("1", "3", "1"), VEGET5 = c("6", "7", "6"))
  x <- .ifn_production_coupes(a, cp)
  expect_equal(nrow(x), 2L)   # l'arbre de P9 n'a pas de 1er passage connu
  expect_equal(x$CAMPAGNE, c("2025", "2025"))
  expect_equal(x$pv_coupe, x$V * x$rv * 0.5 / 5)
  expect_equal(x$prel, x$V * (1 + x$rv / 2) / 5)
  # Code 7 (non vidange) : preleve au sens IGN, pas au sens desserte.
  expect_equal(x$prel_vidange, c(x$prel[1], 0))
})

test_that("a tree below 7.5 cm five years ago counts as recruited, in full", {
  d <- arbres_jouet()[6, ]
  d$C13 <- 0.25
  d$IR5 <- 0.004   # C_passe = 0,25 - 0,025 < 0,2356
  a <- .ifn_production_arbres(d)
  expect_true(a$recrute)
  expect_equal(a$pv, d$V / 5)
  expect_equal(a$pg, d$C13^2 / (4 * pi) / 5)
})

test_that("plots without trees count as zero, groups add up to the total", {
  a <- .ifn_production_arbres(arbres_jouet())
  pl <- data.frame(CAMPAGNE = "2020", IDP = c("P1", "P2", "P3"), SER = "C30")
  p <- .ifn_production_placettes(a, pl)
  expect_equal(nrow(p), 9L)
  vide <- p[p$IDP == "P3", ]
  expect_true(all(vide$pv == 0 & vide$pg == 0))
  for (idp in c("P1", "P2")) {
    s <- p[p$IDP == idp, ]
    expect_equal(s$pv[s$groupe == "tous"],
                 s$pv[s$groupe == "feuillus"] + s$pv[s$groupe == "resineux"])
  }
  expect_equal(p$pv[p$IDP == "P1" & p$groupe == "tous"],
               sum(a$W[a$IDP == "P1"] * a$pv[a$IDP == "P1"]))
})

test_that("direct estimate is the plot mean with psi = var / n", {
  d <- .ifn_production_direct(c(1, 2, 3, 10), c("a", "a", "a", "b"))
  expect_equal(d$direct, c(2, 10))
  expect_equal(d$psi[1], 1 / 3)
  expect_true(is.na(d$psi[2]))   # une placette : psi incalculable
})

# --- La table embarquee ------------------------------------------------------

test_that("the bundled table carries the expected schema and levels", {
  d <- ifn_production_ser()
  expect_true(all(c("niveau", "ser", "greco", "campagne", "attribut", "groupe",
                    "n_plac", "direct", "psi", "estimation", "mse", "rse",
                    "gamma", "nature", "methode_pv", "covariables",
                    "part_g_imputee", "millesime", "source") %in% names(d)))
  expect_setequal(unique(d$niveau), c("ser", "greco", "national"))
  expect_setequal(unique(d$attribut), c("pg", "pv", "prel", "prel_vidange"))
  expect_true(all(d$methode_pv[d$attribut == "pv"] == "allometrie_hauteur_diametre"))
  expect_true(all(d$nature[d$attribut %in% c("prel", "prel_vidange")] == "direct"))
  expect_true(all(d$nature %in% c("fay_herriot", "synthetique", "direct")))
  expect_true(any(d$nature == "fay_herriot"))
  expect_true(all(d$nature[d$niveau != "ser"] == "direct"))
})

test_that("national production and harvest sit at the IGN figures", {
  # Reference IGN flux2024, periode 2014-2022 (campagnes 2019-2023) :
  # production 5,4 m3/ha/an, prelevement 3,3. Mesure au lot 1-bis (voie (b)
  # + arbres coupes) : 97 % et 107 %. La voie (a) du lot 1 donnait 78 % : un
  # retour sous 85 % signale une regression (beta perdu, coupes perdues, IR5
  # mal lu, imputation perdue).
  n <- ifn_production_ser(niveau = "national", groupe = "tous")
  pv <- n[n$attribut == "pv" & n$campagne %in% 2019:2023, ]
  ratio <- weighted.mean(pv$direct, pv$n_plac) / 5.4
  expect_gt(ratio, 0.85)
  expect_lt(ratio, 1.10)
  pr <- n[n$attribut == "prel" & n$campagne %in% 2019:2023, ]
  ratio_p <- weighted.mean(pr$direct, pr$n_plac) / 3.3
  expect_gt(ratio_p, 0.85)
  expect_lt(ratio_p, 1.20)
  pv_m <- n[n$attribut == "prel_vidange" & n$campagne %in% 2019:2023, ]
  expect_true(all(pv_m$direct <= pr$direct[match(pv_m$campagne, pr$campagne)] + 1e-9))
  pg <- n[n$attribut == "pg" & n$campagne %in% 2019:2023, ]
  expect_gt(weighted.mean(pg$direct, pg$n_plac), 0.45)
  expect_lt(weighted.mean(pg$direct, pg$n_plac), 0.80)
})

test_that("Fay-Herriot narrows the uncertainty of SER estimates", {
  s <- ifn_production_ser(niveau = "ser", attribut = "pv", groupe = "tous")
  fh <- s[s$nature == "fay_herriot", ]
  expect_gt(nrow(fh), 100)
  expect_true(all(fh$mse <= fh$psi + 1e-9))
  expect_true(all(fh$gamma >= 0 & fh$gamma <= 1))
})

test_that("the reference walks SER -> GRECO -> national and says so", {
  r <- ifn_production_reference("C30")
  expect_equal(r$niveau_utilise, "ser")
  expect_equal(r$n_campagnes, 5L)
  expect_gt(r$valeur, 0)
  expect_true(is.finite(r$rse))
  r2 <- ifn_production_reference("C99")   # SER inconnue, GRECO C connue
  expect_equal(r2$niveau_utilise, "greco")
  r3 <- ifn_production_reference(NULL)
  expect_equal(r3$niveau_utilise, "national")
  expect_error(ifn_production_reference(c("C30", "C20")), "single SER")
})

test_that("a direct estimate on too few plots does not qualify its level", {
  # F13 (marais littoraux) : 2-3 placettes revisitees par campagne.
  r <- ifn_production_reference("F13", "prel", "tous")
  expect_equal(r$niveau_utilise, "greco")
  r0 <- ifn_production_reference("F13", "prel", "tous", min_plac = 0)
  expect_equal(r0$niveau_utilise, "ser")
  # Le Fay-Herriot n'est pas soumis au seuil.
  expect_equal(ifn_production_reference("F13", "pv", "tous")$niveau_utilise, "ser")
  # niveaux epingle un echelon.
  expect_equal(ifn_production_reference("C30", niveaux = "national")$niveau_utilise,
               "national")
})

test_that("harvest / production ratio aligns both flows and sits near the IGN", {
  n <- ifn_taux_prelevement_production(NULL)
  # IGN 2014-2022 : 53,1 / 87,9 = 0,60 ; mesure lot 2 : 0,68 (biais documente).
  expect_gt(n$ratio, 0.55)
  expect_lt(n$ratio, 0.80)
  expect_equal(n$niveau_utilise, "national")
  r <- ifn_taux_prelevement_production("C30")
  expect_equal(r$ratio, r$prelevement / r$production)
  expect_equal(r$production,
               ifn_production_reference("C30", "pv",
                                        campagnes = as.integer(strsplit(r$campagnes, ",")[[1]]))$valeur)
  v <- ifn_taux_prelevement_production("C30", definition = "vidange")
  expect_lte(v$prelevement, r$prelevement)
  # F13 : le prelevement remonte a la GRECO, la production le suit.
  f <- ifn_taux_prelevement_production("F13")
  expect_equal(f$niveau_utilise, "greco")
  expect_lt(f$ratio, 2)
  expect_true(is.finite(f$rse))
})
