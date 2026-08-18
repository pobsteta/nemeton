# Renommage de la famille L (spec 045)
#
# Les deux fonctions portaient chacune le nom de la metrique de l'autre. Elles
# ont ete renommees ; le calcul, lui, n'a pas bouge d'un centieme. Ces tests
# verrouillent les trois promesses faites : memes valeurs, anciens noms encore
# appelables, et donnees deja ecrites migrables sans perte.

test_that("le nouveau nom rend exactement ce que rendait l'ancien (CA-3)", {
  skip_if_not_installed("terra")
  data(massif_demo_units)
  units <- massif_demo_units[1:3, ]

  expect_identical(
    suppressWarnings(indicateur_l2_fragmentation(units)),
    indicateur_l1_effet_lisiere(units)
  )
  expect_identical(
    suppressWarnings(indicateur_l1_sylvosphere(units)),
    indicateur_l2_morcellement(units)
  )
})

test_that("les anciens noms avertissent et nomment leur remplacant", {
  skip_if_not_installed("terra")
  data(massif_demo_units)
  units <- massif_demo_units[1:2, ]

  expect_warning(
    indicateur_l2_fragmentation(units),
    "indicateur_l1_effet_lisiere"
  )
  expect_warning(
    indicateur_l1_sylvosphere(units),
    "indicateur_l2_morcellement"
  )
})

test_that("l1_effet_lisiere calcule bien la sylvosphere, pas la fragmentation", {
  skip_if_not_installed("terra")
  data(massif_demo_units)
  units <- massif_demo_units[1:3, ]

  # Discriminant : la sylvosphere se calcule sur la seule geometrie (indice de
  # forme + exposition), la fragmentation paysagere exige une couche
  # d'occupation du sol. Ce qui passe sans `layers` est donc la sylvosphere.
  score <- indicateur_l1_effet_lisiere(units)

  expect_length(score, 3)
  expect_true(all(!is.na(score)))
  expect_true(all(score >= 0 & score <= 100))
})

test_that("migrer_colonnes_l renomme sans toucher aux valeurs (CA-4)", {
  df <- data.frame(
    id = 1:2,
    indicateur_l2_fragmentation = c(36.4, 34.5),
    indicateur_l1_sylvosphere = c(71.2, 68.0),
    indicateur_l2_fragmentation_norm = c(36.4, 34.5),
    stringsAsFactors = FALSE
  )

  out <- migrer_colonnes_l(df, quiet = TRUE)

  expect_named(
    out,
    c(
      "id", "indicateur_l1_effet_lisiere", "indicateur_l2_morcellement",
      "indicateur_l1_effet_lisiere_norm"
    )
  )
  expect_equal(out$indicateur_l1_effet_lisiere, c(36.4, 34.5))
  expect_equal(out$indicateur_l2_morcellement, c(71.2, 68.0))
  expect_equal(out$id, 1:2)
})

test_that("migrer_colonnes_l est un no-op sur un jeu deja migre ou etranger", {
  already <- data.frame(
    indicateur_l1_effet_lisiere = 1, indicateur_l2_morcellement = 2
  )
  expect_identical(migrer_colonnes_l(already, quiet = TRUE), already)

  foreign <- data.frame(a = 1, b = 2)
  expect_identical(migrer_colonnes_l(foreign, quiet = TRUE), foreign)
})

test_that("migrer_colonnes_l avertit au lieu d'ecraser en cas de conflit", {
  both <- data.frame(
    indicateur_l2_fragmentation = 10,   # ancienne
    indicateur_l1_effet_lisiere = 99    # nouvelle, deja presente
  )

  expect_warning(out <- migrer_colonnes_l(both), "indicateur_l1_effet_lisiere")
  expect_named(out, "indicateur_l1_effet_lisiere")
  expect_equal(out$indicateur_l1_effet_lisiere, 99)
})

test_that("migrer_colonnes_l refuse ce qui n'est pas un data.frame", {
  expect_error(migrer_colonnes_l(1:3), "data.frame")
})

test_that("le code court resout vers le nouveau slug (CA-5)", {
  expect_equal(
    nemeton:::.normalize_resolve_alias("L1"), "indicateur_l1_effet_lisiere"
  )
  expect_equal(
    nemeton:::.normalize_resolve_alias("L2"), "indicateur_l2_morcellement"
  )
})

test_that("les deux nouveaux noms sont dans la liste canonique (CA-6)", {
  inds <- list_indicators()

  expect_true("indicateur_l1_effet_lisiere" %in% inds)
  expect_true("indicateur_l2_morcellement" %in% inds)
  expect_false("indicateur_l2_fragmentation" %in% inds)
  expect_false("indicateur_l1_sylvosphere" %in% inds)
})

test_that("les deux slugs retires restent normalisables pour les jeux anciens", {
  # Une donnee non migree doit continuer a se normaliser correctement : sinon
  # la migration devient obligatoire au lieu d'etre recommandee.
  expect_true(nemeton:::.normalize_has_rule("indicateur_l2_fragmentation"))
  expect_true(nemeton:::.normalize_has_rule("indicateur_l1_sylvosphere"))
  expect_true(nemeton:::.normalize_has_rule("indicateur_l1_effet_lisiere"))
  expect_true(nemeton:::.normalize_has_rule("indicateur_l2_morcellement"))
})
