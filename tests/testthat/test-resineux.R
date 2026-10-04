# Source unique de la notion « résineux » (audit 1.0) : is_conifer(), P3 et
# .ifn_groupe_espar() consomment tous .est_resineux().

test_that(".est_resineux handles 4-letter codes, espar codes and NA", {
  expect_identical(
    .est_resineux(c("PIAB", "psme", "FASY", "QURO", NA, "", "ZZZZ")),
    c(TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE)
  )
  # Codes espar IFN : règle 51-79 de l'IGN, inchangée.
  expect_identical(.est_resineux(c("51", "64", "79", "80", "09", "9", "02")),
                   c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE))
  expect_identical(.est_resineux(c(64L, 3L)), c(TRUE, FALSE))
  expect_identical(.est_resineux(character(0)), logical(0))
})

test_that("conifers missing from the old site-index list are now recognised", {
  # PIHA, PILA et LAKA tombaient sur la courbe feuillue.
  expect_true(all(is_conifer(c("PIHA", "PILA", "LAKA"))))
  expect_identical(resolve_species_code("LAKA", c("CONIFER_GENUS",
                                                  "BROADLEAF_GENUS")),
                   "CONIFER_GENUS")
})

test_that(".ifn_groupe_espar keeps the IGN 51-79 rule", {
  expect_identical(.ifn_groupe_espar(c("51", "64", "09", "02", NA)),
                   c("resineux", "resineux", "feuillus", "feuillus",
                     "feuillus"))
})

test_that("the 4-letter list agrees with the IGN espar rule on the bridge", {
  d <- ifn_espar_correspondance()
  d <- d[!is.na(d$code_p1) & nzchar(d$code_p1), ]
  expect_identical(.est_resineux(d$code_p1), .est_resineux(d$espar),
                   info = paste(d$code_p1, d$espar))
})

test_that("P3 applies conifer thresholds to ABAL, PSME, LADE and CEAT", {
  skip_if_not_installed("sf")
  sp <- c("ABAL", "PSME", "LADE", "CEAT", "PLAC", "FASY")
  geom <- lapply(seq_along(sp), function(i) sf::st_polygon(list(matrix(
    c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0) + c(i, 0), ncol = 2, byrow = TRUE))))
  u <- sf::st_sf(species = sp, dbh = 32, form_score = 70, defects = 85,
                 geometry = sf::st_sfc(geom, crs = 2154))
  res <- suppressMessages(indicateur_p3_qualite_bois(u))
  # DBH 32 cm : au-dessus du seuil sciage résineux (30), sous le seuil feuillu
  # (40). Avant : ABAL, PSME, LADE, CEAT traités en feuillus, PLAC (platane)
  # en résineux.
  expect_true(all(res$P3[1:4] > res$P3[6]))
  expect_equal(res$P3[5], res$P3[6])
  expect_equal(length(unique(res$P3[1:4])), 1L)
})
