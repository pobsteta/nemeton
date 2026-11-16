# Convention libellé BD Forêt -> ESPAR (brief nemetonshiny 2026-11-16, T4
# Couchey ; voie (b) retenue par Pascal) : un groupe prend l'essence
# majoritaire en volume IFN de la SER, puis GRECO, puis France.

test_that("single-species and generic labels", {
  x <- c("Hêtre", "Châtaignier", "Robinier", "Douglas", "Pin d'Alep",
         "Feuillus", "Conifères", "Mixte", "Pins mélangés", "NC", "NR", NA)
  expect_identical(resoudre_espar_bdforet(x),
                   c("09", "10", "14", "64", "57A", rep(NA_character_, 7)))
})

test_that("group labels take the IFN majority species, SER first", {
  # France : sapin (61) devant l'épicéa, comme l'ancienne convention de l'app.
  expect_identical(resoudre_espar_bdforet("Sapin, épicéa"), "61")
  # Couchey (SER C20) : chêne sessile, pin noir d'Autriche.
  expect_identical(resoudre_espar_bdforet(c("Chênes décidus",
                                            "Pin laricio, pin noir"), ser = "C20"),
                   c("03", "54"))
  # Le même libellé change de code avec la SER : la règle lit les volumes.
  fr <- resoudre_espar_bdforet("Chênes décidus")
  expect_true(fr %in% c("02", "03", "05", "07"))
})

test_that("the chosen member is the largest volume per hectare of the level", {
  v <- nemeton:::.bdforet_volumes()
  s <- v[v$niveau == "ser" & v$ser == "C20" & v$espar %in% c("02", "03", "05", "07"), ]
  expect_identical(resoudre_espar_bdforet("Chênes décidus", ser = "C20"),
                   s$espar[which.max(s$vol_ha_maille)])
})

test_that("unknown SER falls back to France; ser is recycled and checked", {
  expect_identical(resoudre_espar_bdforet("Sapin, épicéa", ser = "ZZZ"),
                   resoudre_espar_bdforet("Sapin, épicéa"))
  expect_length(resoudre_espar_bdforet(c("Mélèze", "Peuplier"), ser = "C20"), 2)
  expect_error(resoudre_espar_bdforet(c("a", "b", "c"), ser = c("C20", "C30")), "ser")
  expect_identical(resoudre_espar_bdforet(character(0)), character(0))
})

test_that("case, accents and labels outside the table", {
  expect_identical(resoudre_espar_bdforet("  CHENES DECIDUS ", ser = "C20"), "03")
  # Hors table : repli sur resoudre_espar().
  expect_identical(resoudre_espar_bdforet("Chêne sessile"), "03")
  expect_identical(resoudre_espar_bdforet("QUPE"), "03")
})

test_that("every group member is a known ESPAR code", {
  tab <- nemeton:::.bdforet_essence_table()
  codes <- ifn_espar_correspondance()$espar
  expect_true(all(unlist(tab$membres) %in% codes))
})
