# test-regen-species-choices.R — sélecteur essence cible reGénération (spec 027 §10.1)

test_that("without units: the 11 scorable classes, ordered by heat tolerance", {
  ch <- regen_species_choices()
  expect_s3_class(ch, "data.frame")
  expect_setequal(names(ch),
                  c("code", "label", "tmax_tol_c", "vpd_tol_kpa", "present", "groupe"))
  expect_equal(nrow(ch), nrow(regeneration_tolerances()))
  expect_false(any(ch$present))
  expect_true(all(ch$groupe == "adaptation"))
  # Trié tolérance chaleur croissante : mésophile d'abord, thermophile en dernier.
  expect_false(is.unsorted(ch$tmax_tol_c))
  expect_equal(ch$code[1], "essence_pessiere_sapiniere")   # 27 °C
  expect_equal(ch$code[nrow(ch)], "essence_chene_vert")    # 38 °C
})

test_that("options are exactly the scorable classes (tol ∩ species_classes)", {
  ch <- regen_species_choices()
  scorable <- intersect(regeneration_tolerances()$code, list_species_classes()$code)
  expect_setequal(ch$code, scorable)
})

test_that("units flag present species and list them first", {
  u <- data.frame(
    id = 1:3,
    essence_dominante = c("essence_hetraie", "essence_chenaie", "essence_hetraie"))
  ch <- regen_species_choices(u)
  present <- ch$code[ch$present]
  expect_setequal(present, c("essence_hetraie", "essence_chenaie"))
  # Le groupe présent est en tête.
  expect_true(all(ch$present[seq_along(present)]))
  expect_equal(ch$groupe[ch$present], rep("present", length(present)))
})

test_that("explicit species_col is honoured", {
  u <- data.frame(id = 1:2, ma_colonne = c("essence_pinede", "essence_pinede"))
  ch <- regen_species_choices(u, species_col = "ma_colonne")
  expect_true(ch$present[ch$code == "essence_pinede"])
  expect_equal(sum(ch$present), 1L)
})

test_that("BD Forêt codes (not class codes) mark nothing present", {
  # massif_demo_units$species holds BD Forêt codes like "03" — not essence_* codes.
  u <- data.frame(id = 1:2, species = c("03", "09"))
  ch <- regen_species_choices(u)   # auto-detects `species`, no code matches
  expect_false(any(ch$present))
})

test_that("localised English labels when lang = 'en'", {
  fr <- regen_species_choices(lang = "fr")
  en <- regen_species_choices(lang = "en")
  expect_equal(nrow(fr), nrow(en))
  # Les codes sont stables quelle que soit la langue.
  expect_setequal(fr$code, en$code)
})
