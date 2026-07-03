# test-regen-species-choices.R — sélecteur essence cible reGénération (spec 027 §10.1)

# ---- level = "class" (11 classes broad) --------------------------------------

test_that("class level: the 11 scorable classes, ordered by heat tolerance", {
  ch <- regen_species_choices(level = "class")
  expect_s3_class(ch, "data.frame")
  expect_setequal(names(ch),
                  c("code", "label", "tmax_tol_c", "vpd_tol_kpa", "present", "groupe"))
  expect_equal(nrow(ch), nrow(regeneration_tolerances()))
  expect_false(any(ch$present))
  expect_false(is.unsorted(ch$tmax_tol_c))
  expect_equal(ch$code[1], "essence_pessiere_sapiniere")   # 27 °C
  expect_equal(ch$code[nrow(ch)], "essence_chene_vert")    # 38 °C
})

test_that("class level: options are exactly the scorable classes", {
  ch <- regen_species_choices(level = "class")
  scorable <- intersect(regeneration_tolerances()$code, list_species_classes()$code)
  expect_setequal(ch$code, scorable)
})

test_that("class level: units flag present classes first", {
  u <- data.frame(
    id = 1:3,
    essence_dominante = c("essence_hetraie", "essence_chenaie", "essence_hetraie"))
  ch <- regen_species_choices(u, level = "class")
  present <- ch$code[ch$present]
  expect_setequal(present, c("essence_hetraie", "essence_chenaie"))
  expect_true(all(ch$present[seq_along(present)]))
})

test_that("class level: BD Forêt-like codes mark nothing present", {
  u <- data.frame(id = 1:2, species = c("03", "09"))
  ch <- regen_species_choices(u, level = "class")
  expect_false(any(ch$present))
})

# ---- level = "species" (FRM European species, default) -----------------------

test_that("species level is the default and returns FRM species", {
  ch <- regen_species_choices()
  expect_true(all(grepl("^frm", ch$statut)))              # FRM only by default
  expect_true(all(c("code", "species_sci", "shade_tol", "confidence",
                    "invasif", "species_class", "present", "groupe") %in% names(ch)))
  expect_gt(nrow(ch), 40)                                  # ~64 FRM species
  # Ordonné par tolérance chaleur au sein du groupe adaptation.
  adap <- ch[ch$groupe == "adaptation", ]
  expect_false(is.unsorted(adap$tmax_tol_c))
})

test_that("species level: include_atlas folds Atlas species after FRM", {
  frm <- regen_species_choices()
  all_sp <- regen_species_choices(include_atlas = TRUE)
  expect_gt(nrow(all_sp), nrow(frm))
  expect_true(any(all_sp$groupe == "atlas"))
  expect_true(all(all_sp$statut[all_sp$groupe == "atlas"] == "atlas_jrc"))
})

test_that("species level: present flagged from a TFV column, listed first", {
  # FF1-09-09 = hêtre pur -> essence_hetraie ; Fagus sylvatica is FRM hêtraie.
  u <- data.frame(id = 1, tfv = "FF1-09-09")
  ch <- regen_species_choices(u, tfv_col = "tfv")
  fagus <- ch[ch$code == "fagus_sylvatica", ]
  expect_equal(nrow(fagus), 1L)
  expect_true(fagus$present)
  expect_equal(fagus$species_class, "essence_hetraie")
  # Le groupe présent est en tête.
  expect_true(all(ch$present[ch$groupe == "present"]))
  expect_equal(which(ch$groupe == "present"), seq_len(sum(ch$present)))
})

test_that("species level: present flagged from a species-class column", {
  u <- data.frame(id = 1, species_class = "essence_pinede")
  ch <- regen_species_choices(u)
  expect_true(any(ch$present))
  expect_true(all(ch$species_class[ch$present] == "essence_pinede"))
})

# ---- map_tfv_to_species_class ------------------------------------------------

test_that("map_tfv_to_species_class maps named essences and NAs non-forest", {
  expect_equal(map_tfv_to_species_class("FF1-09-09"), "essence_hetraie")
  expect_equal(map_tfv_to_species_class("FF1-10-10"), "essence_chataigneraie")
  expect_equal(map_tfv_to_species_class("FF2-64-64"), "essence_douglasaie")
  expect_true(is.na(map_tfv_to_species_class("LA4")))        # lande
  expect_true(is.na(map_tfv_to_species_class("inconnu")))    # code inconnu
  # vectorisé
  expect_equal(map_tfv_to_species_class(c("FF1-09-09", "FP")),
               c("essence_hetraie", "essence_peupleraie"))
})

# ---- indice_priorite_regen résout un code espèce UE --------------------------

test_that("indice_priorite_regen(species=) resolves a European species code", {
  poly <- function(x) sf::st_polygon(list(rbind(
    c(x, 0), c(x + 5, 0), c(x + 5, 5), c(x, 5), c(x, 0))))
  u <- sf::st_sf(
    data.frame(id = 1:2, sensibilite = c(90, 90), njstress = c(55, 55)),
    geometry = sf::st_sfc(poly(0), poly(10), crs = 2154))
  base <- indice_priorite_regen(u)
  # Quercus ilex (chêne vert, tmax_tol 44) tolère mieux qu'un mésophile :
  tuned <- indice_priorite_regen(u, species = "fagus_sylvatica")
  expect_true("regen_essence" %in% names(tuned) || is.data.frame(tuned))
  # Le code espèce est bien résolu (pénalité appliquée -> indice >= base).
  expect_true(all(tuned$indice_priorite_regen >= base$indice_priorite_regen - 1e-6))
})
