# Tests infradensite_espar() — infradensite par essence IFN (spec 068)

test_that("infradensite_espar returns the whole table with a level for each row", {
  d <- infradensite_espar()
  expect_true(all(c("espar", "lib_espar", "nom_latin", "groupe", "infradensite_g_cm3",
                    "niveau", "n_valeurs", "source") %in% names(d)))
  # toutes les essences de la correspondance IFN + 2 lignes de groupe
  expect_equal(nrow(d), nrow(ifn_espar_correspondance()) + 2L)
  expect_true(all(d$niveau %in% c("espece_europe", "espece", "genre", "groupe")))
  expect_false(anyNA(d$infradensite_g_cm3))
  # bornes physiques d'une infradensite de bois tempere
  expect_true(all(d$infradensite_g_cm3 > 0.2 & d$infradensite_g_cm3 < 1))
  expect_false(anyDuplicated(d$espar) > 0)
})

test_that("infradensite_espar resolves any nomenclature and keeps the input order", {
  x <- infradensite_espar(c("62", "QUPE", "Fagus sylvatica", "Hêtre"))
  expect_equal(x$code, c("62", "QUPE", "Fagus sylvatica", "Hêtre"))
  expect_equal(x$espar, c("62", "03", "09", "09"))
  expect_equal(x$infradensite_g_cm3[1], 0.37)
  expect_equal(x$niveau[1], "espece_europe")
})

test_that("infradensite_espar falls back to the broadleaved / coniferous group", {
  x <- infradensite_espar(c("CONIFER_GENUS", "BROADLEAF_GENUS", "inconnue"))
  expect_equal(x$espar, c("RESINEUX", "FEUILLU", "FEUILLU"))
  expect_true(all(x$niveau == "groupe"))
  d <- infradensite_espar()
  expect_lt(d$infradensite_g_cm3[d$espar == "RESINEUX"],
            d$infradensite_g_cm3[d$espar == "FEUILLU"])
})

test_that("infradensite_espar keeps NA for a NA code", {
  x <- infradensite_espar(c("09", NA))
  expect_true(is.na(x$infradensite_g_cm3[2]))
  expect_true(is.na(x$code[2]))
})

test_that("infradensity is below the air-dry density of wood_density.csv", {
  # l'infradensite (anhydre / volume frais) est 15 a 25 % sous la densite a
  # l'air sec : c'est le biais que corrige le C1 (spec 068)
  w <- utils::read.csv(system.file("extdata", "wood_density.csv", package = "nemeton"))
  x <- infradensite_espar(w$species_code)
  r <- x$infradensite_g_cm3 / (w$density_kg_m3 / 1000)
  expect_true(stats::median(r) > 0.75 && stats::median(r) < 0.9)
})
