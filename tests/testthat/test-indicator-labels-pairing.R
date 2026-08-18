# Appariement code <-> colonne <-> libelle dans INDICATOR_FAMILIES
#
# Quatre lignes sur 41 sont croisees : le nom court et le slug de la colonne
# ne se correspondent pas. Le croisement vient du **nom des fonctions**, pas
# de l'appariement — une colonne porte le nom de la fonction qui la remplit
# (`compute_indicator()` resout la fonction par le nom de l'indicateur), et
# pour ces quatre-la le nom contredit ce que la fonction calcule :
#
#   indicateur_l2_fragmentation()  ->  sylvosphere / effet lisiere
#                                      (indice de forme, contraste, exposition)
#   indicateur_l1_sylvosphere()    ->  fragmentation paysagere
#                                      (landscapemetrics COHESION + AI)
#
# Les libelles suivent donc le code **et** les valeurs portees par la colonne.
# Les echanger pour coller au slug retitrerait les cartes a faux : c'est
# exactement ce que ces tests empechent.

test_that("les lignes croisees sont exactement les quatre documentees (CA-3)", {
  ind <- indicator_labels()

  expect_equal(nrow(ind), 41L)

  slug_ok <- startsWith(
    ind$column_name,
    paste0("indicateur_", tolower(ind$code), "_")
  )

  expect_equal(ind$code[!slug_ok], c("F1", "F2", "L1", "L2"))
  expect_equal(
    ind$column_name[!slug_ok],
    c(
      "indicateur_f2_erosion", "indicateur_f1_fertilite",
      "indicateur_l2_fragmentation", "indicateur_l1_sylvosphere"
    )
  )
})

test_that("le libelle decrit la grandeur portee par la colonne (CA-1)", {
  ind <- indicator_labels()
  by_code <- function(code) ind[ind$code == code, , drop = FALSE]

  # F1 : colonne au slug "erosion", valeurs d'erosion, libelle d'erosion.
  f1 <- by_code("F1")
  expect_equal(f1$column_name, "indicateur_f2_erosion")
  expect_match(f1$label_fr, "rosion")
  expect_match(f1$label_en, "Erosion")

  f2 <- by_code("F2")
  expect_equal(f2$column_name, "indicateur_f1_fertilite")
  expect_match(f2$label_fr, "ertilit")
  expect_match(f2$label_en, "Fertility")

  # L1 : la colonne s'appelle "fragmentation" mais porte les valeurs de
  # sylvosphere — le libelle suit les valeurs, pas le slug.
  l1 <- by_code("L1")
  expect_equal(l1$column_name, "indicateur_l2_fragmentation")
  expect_match(l1$label_fr, "ylvosph")
  expect_match(l1$label_en, "Sylvosphere")
  expect_false(grepl("ragmentation", l1$label_fr))

  l2 <- by_code("L2")
  expect_equal(l2$column_name, "indicateur_l1_sylvosphere")
  expect_match(l2$label_fr, "ragmentation")
  expect_match(l2$label_en, "Fragmentation")
  expect_false(grepl("ylvosph", l2$label_fr))
})

test_that("les infobulles suivent le meme appariement que les libelles", {
  ind <- indicator_labels()
  by_code <- function(code) ind[ind$code == code, , drop = FALSE]

  # L1 = sylvosphere : l'infobulle parle de lisieres.
  expect_match(by_code("L1")$tooltip_fr, "lisi")
  expect_match(by_code("L1")$tooltip_en, "[Ee]dge")

  # L2 = fragmentation : l'infobulle parle de fragmentation.
  expect_match(by_code("L2")$tooltip_fr, "ragmentation")
  expect_match(by_code("L2")$tooltip_en, "ragmentation")

  expect_match(by_code("F1")$tooltip_fr, "rosion")
  expect_match(by_code("F2")$tooltip_fr, "ertilit")
})

test_that("indicator_families() et indicator_labels() ne se contredisent pas (CA-2)", {
  fams <- indicator_families()
  ind <- indicator_labels()

  for (i in seq_len(nrow(fams))) {
    codes <- fams$indicators[[i]]
    rows <- ind[ind$family == fams$code[i], , drop = FALSE]

    expect_equal(rows$code, codes)
    expect_equal(rows$column_name, fams$column_names[[i]])

    for (lg in c("fr", "en")) {
      expect_equal(
        unname(fams[[paste0("labels_", lg)]][[i]]),
        rows[[paste0("label_", lg)]]
      )
      expect_equal(
        unname(fams[[paste0("tooltips_", lg)]][[i]]),
        rows[[paste0("tooltip_", lg)]]
      )
      expect_equal(
        names(fams[[paste0("labels_", lg)]][[i]]),
        codes
      )
    }
  }
})

test_that("la table des libelles est complete et sans doublon de colonne", {
  ind <- indicator_labels()

  expect_false(any(is.na(ind$label_fr)))
  expect_false(any(is.na(ind$label_en)))
  expect_false(any(is.na(ind$tooltip_fr)))
  expect_false(any(is.na(ind$tooltip_en)))

  # Une colonne appartient a un seul code, et reciproquement.
  expect_equal(anyDuplicated(ind$column_name), 0L)
  expect_equal(anyDuplicated(ind$code), 0L)
})
