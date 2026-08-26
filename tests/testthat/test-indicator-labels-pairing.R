# Appariement code <-> colonne <-> libelle dans INDICATOR_FAMILIES
#
# Une colonne porte le nom de la fonction qui la remplit (`compute_indicator()`
# resout la fonction par le nom de l'indicateur). Quand ce nom ment, le libelle
# ne peut plus suivre le slug sans mentir a son tour.
#
# La famille L etait dans ce cas jusqu'en 0.176.0 : les deux fonctions portaient
# chacune le nom de la metrique de l'autre. Elles ont ete RENOMMEES (spec 045)
# plutot que les libelles echanges — L n'est donc plus croisee, et ses deux
# anciens slugs sont retires definitivement.
#
# La famille F etait le dernier croisement, tranche en 0.182.0 (spec 049) :
# F1 = fertilite, F2 = erosion, comme le disaient deja le nom des deux
# fonctions, `.normalize_resolve_alias()` et CLAUDE.md. Seule la table des
# familles disait l'inverse, avec `column_names` croise pour compenser -- si
# bien que le MEME code « F1 » designait la fertilite par le resolveur d'alias
# et l'erosion par la table.
#
# Il n'y a donc PLUS aucune ligne croisee, et ce test l'exige desormais : toute
# reapparition d'un croisement le fera echouer.

test_that("aucun code ne contredit le slug de sa colonne (CA-3)", {
  ind <- indicator_labels()

  expect_equal(nrow(ind), 41L)

  slug_ok <- startsWith(
    ind$column_name,
    paste0("indicateur_", tolower(ind$code), "_")
  )

  expect_equal(ind$code[!slug_ok], character(0))
  expect_equal(ind$column_name[!slug_ok], character(0))

  # Les deux slugs retires en 0.176.0 ne reviennent pas par une porte derobee.
  expect_false(any(
    c("indicateur_l2_fragmentation", "indicateur_l1_sylvosphere") %in%
      ind$column_name
  ))
})

test_that("le libelle decrit la grandeur portee par la colonne (CA-1)", {
  ind <- indicator_labels()
  by_code <- function(code) ind[ind$code == code, , drop = FALSE]

  # F1 : colonne au slug "fertilite", valeurs de fertilite, libelle de fertilite.
  f1 <- by_code("F1")
  expect_equal(f1$column_name, "indicateur_f1_fertilite")
  expect_match(f1$label_fr, "ertilit")
  expect_match(f1$label_en, "Fertility")

  f2 <- by_code("F2")
  expect_equal(f2$column_name, "indicateur_f2_erosion")
  expect_match(f2$label_fr, "rosion")
  expect_match(f2$label_en, "Erosion")

  # L1 : depuis le renommage, le slug, le code et les valeurs concordent.
  l1 <- by_code("L1")
  expect_equal(l1$column_name, "indicateur_l1_effet_lisiere")
  expect_match(l1$label_fr, "ylvosph")
  expect_match(l1$label_en, "Sylvosphere")
  expect_false(grepl("ragmentation", l1$label_fr))

  l2 <- by_code("L2")
  expect_equal(l2$column_name, "indicateur_l2_morcellement")
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

  expect_match(by_code("F1")$tooltip_fr, "ertilit")
  expect_match(by_code("F2")$tooltip_fr, "rosion")
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

test_that("le tooltip de S3 decrit la grandeur qu'il porte", {
  # Brief `briefs/vers-nemeton/2026-08-26-tooltip-s3-faux.md`. Deux erreurs,
  # dont une ANTERIEURE au changement de grandeur : le tooltip annoncait
  # « Population dans un rayon de 10 km » alors que le code utilisait deja
  # `pop_5km`, et que S3 porte une DENSITE depuis la v0.189.0.
  #
  # L'app lit ce texte tel quel depuis `INDICATOR_FAMILIES` : le corriger
  # la-bas creerait une seconde verite sur une donnee qui n'en a qu'une —
  # exactement le fork que le de-fork de v0.127.0 a supprime.
  s <- indicator_labels("S")
  i <- which(s$code == "S3")
  expect_length(i, 1L)

  for (tt in c(s$tooltip_fr[i], s$tooltip_en[i])) {
    expect_false(grepl("10 km", tt, fixed = TRUE), info = tt)
    expect_match(tt, "5 km")
  }
  # La grandeur est nommee, et son echelle avec — un score de 82 sur une
  # echelle log ne se lit pas comme un pourcentage.
  expect_match(s$tooltip_fr[i], "[Dd]ensit")
  expect_match(s$tooltip_en[i], "densit")
  expect_match(s$tooltip_fr[i], "logarithmique")
  expect_match(s$tooltip_en[i], "log scale")
})
