# Tables Charru (dérive du BAI 2017, auto-éclaircie 2012) — exports qui
# n'avaient aucun test (audit 1.0).

test_that("charru_bai_drift_table expose les 8 essences et leur habitat", {
  tab <- charru_bai_drift_table()
  expect_s3_class(tab, "data.frame")
  expect_named(tab, c("species", "habitat", "bai_chg"))
  expect_setequal(tab$species,
                  c("PIAB", "ABAL", "PISY", "FASY", "QURO", "QUPE", "QUPU", "PIHA"))
  expect_true(all(tab$habitat %in% c("mountain", "generalist", "lowland", "mediterranean")))
  expect_true(all(tab$bai_chg > 0))
})

test_that("bai_drift_factor lit la table, retombe sur l'habitat, sinon 1", {
  expect_equal(bai_drift_factor(c("PIAB", "piha")), c(1.25, 0.72))
  # Essence hors panel : moyenne de l'habitat fourni
  expect_equal(bai_drift_factor("ACPS", habitat = "lowland"), mean(c(1.00, 0.97)))
  # Ni essence connue ni habitat : pas de dérive
  expect_equal(bai_drift_factor("ACPS"), 1)
  expect_equal(bai_drift_factor("ACPS", habitat = "inconnu"), 1)
  # NA reste NA (pas de valeur inventée)
  expect_true(is.na(bai_drift_factor(NA_character_)))
  expect_identical(bai_drift_factor(character(0)), numeric(0))
})

test_that("charru_selfthinning_table porte les coefficients de n_max_selfthinning", {
  tab <- charru_selfthinning_table()
  expect_s3_class(tab, "data.frame")
  expect_true(all(c("species", "model", "a", "b", "c", "dg_min", "dg_max") %in% names(tab)))
  expect_false(anyDuplicated(tab$species) > 0)
  expect_true(all(tab$dg_min < tab$dg_max))
  # Cohérence avec n_max_selfthinning() au centre du domaine de validité
  r <- tab[1, ]
  dg <- (r$dg_min + r$dg_max) / 2
  attendu <- exp(r$a + r$b * log(dg) + r$c * log(dg)^2)
  expect_equal(as.numeric(n_max_selfthinning(dg, r$species)), attendu,
               tolerance = 1e-6)
})
