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
  expect_setequal(unique(d$attribut), c("pg", "pv"))
  expect_true(all(d$nature %in% c("fay_herriot", "synthetique", "direct")))
  expect_true(any(d$nature == "fay_herriot"))
  expect_true(all(d$nature[d$niveau != "ser"] == "direct"))
})

test_that("national production sits in the IGN order of magnitude", {
  # Reference IGN flux2024 : 5,4 m3/ha/an (2014-2022, campagnes 2019-2023),
  # arbres coupes compris. Voie (a) mesuree a 78 % au lot 1 (spec 054 §3.a) :
  # sous 70 %, une regression (IR5 mal lu, imputation perdue) ; au-dessus de
  # 100 %, la voie (a) ne peut pas depasser la reference.
  n <- ifn_production_ser(niveau = "national", groupe = "tous")
  pv <- n[n$attribut == "pv" & n$campagne %in% 2019:2023, ]
  ratio <- weighted.mean(pv$direct, pv$n_plac) / 5.4
  expect_gt(ratio, 0.70)
  expect_lt(ratio, 1.00)
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
